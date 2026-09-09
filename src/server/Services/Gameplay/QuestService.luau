--!strict
-- Server: đọc tiến trình từ DataService để chạy chuỗi nhiệm vụ rồi chuyển sang nhiệm vụ ngày.
-- Sự kiện gameplay cập nhật mục tiêu; ByteNet chỉ nhận yêu cầu lĩnh thưởng đã được server xác nhận.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local QuestConfig = require(ReplicatedStorage.Shared.Config.Quests)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local CHAIN = QuestConfig.CHAIN
local QuestService = {}
local DataService: any
local ProgressionService: any
local RouletteService: any
local TelemetryService: any
local accumulator = 0
local lastSent: { [Player]: string } = {}
local lastDailySent: { [Player]: string } = {}
local telemetryDay: { [Player]: number } = {}

local function utcDay(): number
	return math.floor(os.time() / 86_400)
end

local function emoteCount(data: any): number
	local count = 0
	for _, owned in data.UnlockedEmotes do
		if owned then
			count += 1
		end
	end
	return count
end

local function progressFor(data: any, quest: any): number
	if quest.kind == "stage" then
		return math.max(0, tonumber(data.HighestCompletedStage) or 0)
	elseif quest.kind == "level" then
		return math.max(0, tonumber(data.Level) or 1)
	elseif quest.kind == "pad" then
		return math.max(0, tonumber(data.HighestPadIndex) or 1)
	elseif quest.kind == "emote" then
		return emoteCount(data)
	elseif quest.kind == "rebirth" then
		return math.max(0, tonumber(data.Rebirths) or 0)
	end
	return 0
end

local function chainRewardText(quest: any): string
	if quest.rewardText then
		return quest.rewardText
	end
	local parts = {}
	if quest.rewardSpeed > 0 then
		table.insert(parts, `+{Constants.FormatNumber(quest.rewardSpeed)} Speed`)
	end
	if quest.rewardSpins > 0 then
		table.insert(parts, `+{quest.rewardSpins} Spin`)
	end
	if quest.badgeId and quest.badgeId > 0 then
		table.insert(parts, "Badge")
	end
	return table.concat(parts, "  •  ")
end

local function dailyRewardText(data: any): string
	return `+{Constants.FormatNumber(data.DailyQuestRewardSpeed)} Speed  •  +{Constants.FormatNumber(
		data.DailyQuestRewardWins
	)} Wins`
end

local function sendChainState(player: Player, active: boolean, index: number, quest: any?, progress: number?)
	local payload = {
		active = active,
		index = math.clamp(index, 0, 255),
		title = if quest then quest.title else "",
		progress = progress or 0,
		target = if quest then quest.target else 0,
		rewardText = if quest then chainRewardText(quest) else "",
		rewardSpeed = if quest then quest.rewardSpeed or 0 else 0,
		rewardSpins = if quest then quest.rewardSpins or 0 else 0,
	}
	local signature = `{payload.active}|{payload.index}|{payload.title}|{payload.progress}|{payload.target}`
	if lastSent[player] ~= signature then
		lastSent[player] = signature
		GamePackets.questState.sendTo(payload, player)
	end
end

local function initializeChainIndex(data: any): number
	for index, quest in CHAIN do
		if progressFor(data, quest) < quest.target then
			data.QuestIndex = index
			data.QuestProgress = progressFor(data, quest)
			return index
		end
	end
	data.QuestIndex = #CHAIN + 1
	data.QuestProgress = 0
	return data.QuestIndex
end

local function grantChainReward(player: Player, quest: any, completedIndex: number)
	if quest.rewardSpeed > 0 then
		ProgressionService.GrantSpeed(player, quest.rewardSpeed)
	end
	if quest.rewardSpins > 0 then
		RouletteService.GrantTickets(player, quest.rewardSpins, true)
	end
	if quest.badgeId and quest.badgeId > 0 then
		task.spawn(function()
			local ok, err = pcall(BadgeService.AwardBadgeAsync, BadgeService, player.UserId, quest.badgeId)
			if not ok then
				warn(`[QuestService] Could not award badge {quest.badgeId}: {err}`)
			end
		end)
	end
	if TelemetryService then
		TelemetryService.QuestChain(player, completedIndex)
	end
	GamePackets.purchaseCelebration.sendTo({
		itemName = `QUEST {completedIndex} COMPLETE!`,
		subtitle = chainRewardText(quest),
	}, player)
end

-- Mỗi quest = 2% quãng đường tới mốc kế tiếp. 3 quest/ngày ⇒ 6% một bậc trùng sinh.
local DAILY_QUEST_REWARD_FRACTION = 0.02
-- Sàn tuyệt đối cho người chơi mới: quãng đường của họ chỉ vài trăm XP nên 2% ra một con số
-- trông như lỗi. Không có sàn tương ứng cho Wins vì `stageHalf` đã tự làm việc đó.
local DAILY_QUEST_MIN_SPEED = 2_000

local function ensureDaily(data: any): number
	local day = utcDay()
	if data.DailyQuestSeed ~= day then
		data.DailyQuestSeed = day
		data.DailyQuestProgress = { 0, 0, 0 }
		data.DailyQuestClaimedAt = { 0, 0, 0 }
		--[[
			PHẦN THƯỞNG ĐO BẰNG % QUÃNG ĐƯỜNG, KHÔNG BẰNG SỐ TUYỆT ĐỐI (GDD 3.0 §7.3).

			Quãng đường tới lần trùng sinh kế tiếp trải từ 129 XP (R0) tới 1.247 tỉ XP (R15) —
			chênh nhau mười tỉ lần. Không con số cố định nào sống sót qua khoảng đó. Công thức
			cũ `25.000 × (1 + R×0,5)` đo được:

			    R0 → 19.380% quãng đường (một quest bằng 194 lần trùng sinh)
			    R8 →  0,001% quãng đường (bấm nhận không thấy thanh nhích)

			Hỏng ở CẢ HAI đầu. Giờ mỗi quest đẩy đúng 2% quãng đường tới mốc kế tiếp của chính
			người chơi đó; 3 quest/ngày = 6% một bậc trùng sinh, ở mọi cấp, mãi mãi.

			Hai cái sàn tuyệt đối là để người chơi mới — vốn có quãng đường rất ngắn — không nhận
			một con số bằng không.
		]]
		local rebirths = math.max(0, math.floor(tonumber(data.Rebirths) or 0))
		local nextLevel = Constants.GetRequiredLevelForRebirth(rebirths)
		local climb = math.max(0, Constants.GetCumulativeXP(nextLevel) - (tonumber(data.Speed) or 0))

		local highest =
			math.clamp(math.floor(tonumber(data.HighestCompletedStage) or 0), 1, Constants.MAX_CONFIGURED_STAGE)
		local stageHalf = (Constants.STAGE_WINS[highest] or 0) * 0.5
		local feeShare = Constants.GetRebirthWinsCost(rebirths + 1) * DAILY_QUEST_REWARD_FRACTION

		data.DailyQuestRewardWins = math.floor(math.max(stageHalf, feeShare))
		data.DailyQuestRewardSpeed = math.floor(math.max(DAILY_QUEST_MIN_SPEED, climb * DAILY_QUEST_REWARD_FRACTION))
	end
	return day
end

local function sendDailyState(player: Player, data: any)
	local day = ensureDaily(data)
	local quests = QuestConfig.BuildDailySet(day)
	local progress = data.DailyQuestProgress
	local claimed = data.DailyQuestClaimedAt
	local reward = dailyRewardText(data)
	local signature = `{day}|{progress[1]}|{progress[2]}|{progress[3]}|{claimed[1]}|{claimed[2]}|{claimed[3]}`
	if lastDailySent[player] ~= signature then
		lastDailySent[player] = signature
		GamePackets.dailyQuestState.sendTo({
			active = true,
			rewardText = reward,
			rewardSpeed = data.DailyQuestRewardSpeed,
			rewardWins = data.DailyQuestRewardWins,
			quest1Title = quests[1].title,
			quest1Progress = progress[1],
			quest1Target = quests[1].target,
			quest1Claimed = claimed[1] == day,
			quest2Title = quests[2].title,
			quest2Progress = progress[2],
			quest2Target = quests[2].target,
			quest2Claimed = claimed[2] == day,
			quest3Title = quests[3].title,
			quest3Progress = progress[3],
			quest3Target = quests[3].target,
			quest3Claimed = claimed[3] == day,
		}, player)
	end

	local visibleIndex = 0
	for index = 1, 3 do
		if claimed[index] ~= day then
			visibleIndex = index
			break
		end
	end
	if visibleIndex == 0 then
		-- Daily vẫn còn trong modal để xem lịch sử, nhưng tracker giữa màn hình phải biến mất.
		sendChainState(player, false, 3, {
			title = "Daily quests complete — come back tomorrow",
			target = 1,
			rewardSpeed = 0,
			rewardSpins = 0,
			rewardText = "Resets at 00:00 UTC",
		}, 1)
		return
	end
	local quest = quests[visibleIndex]
	sendChainState(player, true, visibleIndex, {
		title = `DAILY: {quest.title}`,
		target = quest.target,
		rewardSpeed = 0,
		rewardSpins = 0,
		rewardText = reward,
	}, math.min(quest.target, progress[visibleIndex]))
end

local function scanPlayer(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local tutorialDone = ((tonumber(data.TutorialStep) or 0) >= 3 or data.TutorialSkipped == true)
		and data.TutorialRewarded == true
	if not tutorialDone then
		sendChainState(player, false, 0, nil, 0)
		return
	end

	local index = math.floor(tonumber(data.QuestIndex) or 0)
	if index <= 0 then
		index = initializeChainIndex(data)
	end
	if index <= #CHAIN then
		if TelemetryService then
			TelemetryService.QuestChain(player, nil)
		end
		local quest = CHAIN[index]
		local progress = math.min(quest.target, progressFor(data, quest))
		data.QuestProgress = progress
		if progress >= quest.target then
			data.QuestIndex = index + 1
			data.QuestProgress = 0
			lastSent[player] = nil
			grantChainReward(player, quest, index)
			return
		end
		sendChainState(player, true, index, quest, progress)
		return
	end

	local day = ensureDaily(data)
	if TelemetryService and telemetryDay[player] ~= day then
		telemetryDay[player] = day
		for dailyIndex = 1, 3 do
			TelemetryService.DailyQuest(player, dailyIndex, false)
		end
	end
	sendDailyState(player, data)
end

function QuestService.Record(player: Player, kind: string, amount: number?)
	local data = DataService.GetData(player)
	if not data or (tonumber(data.QuestIndex) or 0) <= #CHAIN then
		return
	end
	local day = ensureDaily(data)
	local quests = QuestConfig.BuildDailySet(day)
	local changed = false
	for index, quest in quests do
		if quest.kind == kind and data.DailyQuestClaimedAt[index] ~= day then
			local before = data.DailyQuestProgress[index]
			local after = math.min(quest.target, before + math.max(0, amount or 1))
			data.DailyQuestProgress[index] = after
			changed = changed or after ~= before
			if before < quest.target and after >= quest.target and TelemetryService then
				TelemetryService.DailyQuest(player, index, true)
			end
		end
	end
	if changed then
		lastDailySent[player] = nil
		lastSent[player] = nil
		sendDailyState(player, data)
	end
end

local function claimDaily(player: Player, index: number)
	local data = DataService.GetData(player)
	if not data or (tonumber(data.QuestIndex) or 0) <= #CHAIN or index < 1 or index > 3 then
		return
	end
	local day = ensureDaily(data)
	local quest = QuestConfig.BuildDailySet(day)[index]
	if data.DailyQuestClaimedAt[index] == day or data.DailyQuestProgress[index] < quest.target then
		return
	end
	-- Commit the claim before any reward helper can yield or throw: retry cannot duplicate rewards.
	data.DailyQuestClaimedAt[index] = day
	ProgressionService.GrantSpeed(player, data.DailyQuestRewardSpeed)
	ProgressionService.AwardWins(player, data.DailyQuestRewardWins, "daily_quest")
	DataService.UpdateLeaderstats(player)
	lastDailySent[player] = nil
	lastSent[player] = nil
	GamePackets.purchaseCelebration.sendTo({
		itemName = `DAILY QUEST {index} COMPLETE!`,
		subtitle = dailyRewardText(data),
	}, player)
	sendDailyState(player, data)
end

function QuestService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
	RouletteService = ServiceLocator.Get("RouletteService")
	TelemetryService = ServiceLocator.Find("TelemetryService")
end

function QuestService.Start()
	GamePackets.requestDailyQuestClaim.listen(function(payload, player)
		if player and not NetRateLimit.ShouldDrop(player, "dailyQuestClaim", 0.3) then
			claimDaily(player, payload.index)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
		lastDailySent[player] = nil
		telemetryDay[player] = nil
	end)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < 0.2 then
			return
		end
		accumulator = 0
		for _, player in Players:GetPlayers() do
			scanPlayer(player)
		end
	end)
end

return QuestService
