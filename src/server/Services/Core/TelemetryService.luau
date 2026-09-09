--!strict
-- Server ghi funnel, kinh tế và lỗi từ các service; nhận cờ chẩn đoán giới hạn từ client.
--
-- Ba thứ được ghi:
--   1. Onboarding funnel — người chơi MỚI đi được tới đâu trong 4 bước đầu.
--      Đây là chỉ số quan trọng nhất của một game simulator: chỗ nào tụt mạnh
--      giữa 2 bước chính là chỗ cần sửa trước tiên.
--   2. Economy — mọi lần Wins vào/ra, kèm lý do. Dùng để biết nguồn Wins nào
--      đang lạm phát và sink nào không ai dùng.
--   3. Lỗi runtime — gom theo script, in định kỳ, không spam từng dòng.
--
-- Tất cả đều bọc pcall và không bao giờ yield trên đường chạy nóng: telemetry
-- hỏng thì im lặng chịu mất số liệu, tuyệt đối không được kéo gameplay chết theo.
--
-- Số liệu xem ở Creator Dashboard → Analytics (funnel hiện sau ~24h có dữ liệu).

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local Env = require(ReplicatedStorage.Shared.Util.Env)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)

-- 4 bước đầu của người chơi mới. Đổi thứ tự = làm gãy dữ liệu lịch sử, chỉ
-- được THÊM bước vào cuối.
local ONBOARDING_STEPS = {
	Join = { index = 1, name = "Join" },
	FirstSpeed = { index = 2, name = "FirstSpeedGain" },
	FirstStage = { index = 3, name = "FirstStageClear" },
	FirstRebirth = { index = 4, name = "FirstRebirth" },
}

local ERROR_REPORT_INTERVAL = 300

local TelemetryService = {}

-- Bước onboarding đã ghi của từng player trong phiên này (chống ghi trùng).
local loggedSteps: { [Player]: { [string]: boolean } } = {}
local errorCounts: { [string]: number } = {}
local errorTotal = 0

-- ============================================================================
-- API công khai
-- ============================================================================

-- stepKey lấy từ ONBOARDING_STEPS. Gọi bao nhiêu lần cũng được — chỉ lần đầu
-- trong phiên là thật sự gửi đi.
function TelemetryService.Onboarding(player: Player, stepKey: string)
	local step = ONBOARDING_STEPS[stepKey]
	if not step then
		warn(`[Telemetry] Bước onboarding không tồn tại: {stepKey}`)
		return
	end

	local logged = loggedSteps[player]
	if not logged then
		return
	end
	if logged[stepKey] then
		return
	end
	logged[stepKey] = true

	-- Không tự lọc "người chơi mới": funnel onboarding phía Roblox chỉ tính
	-- người vào experience lần đầu, gửi thừa cũng không làm bẩn số liệu.
	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step.index, step.name)
		end)
		if not ok and Env.IsStudio() then
			warn(`[Telemetry] Onboarding {stepKey} lỗi: {err}`)
		end
	end)
end

-- flow: "Source" khi Wins chảy VÀO tay người chơi, "Sink" khi chảy ra.
function TelemetryService.Economy(
	player: Player,
	flow: "Source" | "Sink",
	amount: number,
	endingBalance: number,
	reason: string
)
	if amount <= 0 then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogEconomyEvent(
				player,
				if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
				"Wins",
				amount,
				endingBalance,
				reason
			)
		end)
		if not ok and Env.IsStudio() then
			warn(`[Telemetry] Economy {reason} lỗi: {err}`)
		end
	end)
end

function TelemetryService.Custom(player: Player, eventName: string, value: number?)
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogCustomEvent(player, eventName, value or 1)
		end)
	end)
end

-- ============================================================================
-- Phẽu tuỳ biến + mốc phiên chơi   (thêm 2026-08-28)
-- ============================================================================
--[[
	VÌ SAO CÓ PHẦN NÀY

	Phễu onboarding 4 bước ở trên nói: 96,5% nhận Speed đầu tiên, nhưng chỉ 52% vượt nổi
	stage 1. Một cái hố 44 điểm mà bên trong KHÔNG có gì để nhìn. Cùng lúc, đường cong
	`first session retention` cho thấy 2/3 người mới rời đi trong khoảng 50–100 giây.

	Hai phễu dưới đây xẻ cái hố đó thành hai câu hỏi trả lời được riêng:

	  • `FirstSession` — thuần THỜI GIAN (30s → 600s). Đơn điệu tuyệt đối nên số liệu sạch,
	    và hai mốc 60s/180s đặt trùng đúng hai rổ `first play bounce rate` mà thuật toán đề
	    xuất của Roblox cân nặng nhất.
	  • `CoreLoop` — thuần HÀNH ĐỘNG (chạm treadmill → rời treadmill → vượt stage). Cho biết
	    người chơi rời ở KHÂU nào, chứ không chỉ ở GIÂY thứ mấy.

	Giao hai phễu lại mới ra kết luận hành động được: rời trước hay sau khi chạm treadmill,
	trước hay sau khi bước vào obby.

	⚠️ Bước phễu BẮT BUỘC đơn điệu: ai đạt bước k thì phải đã đạt k−1. Bước mới chỉ được
	thêm vào CUỐI, y hệt luật của `ONBOARDING_STEPS`.
]]
local FIRST_SESSION_FUNNEL = "FirstSession"
-- Bước 1 là `Spawn`; mốc thứ n ứng với bước n+1.
local FIRST_SESSION_MARKS = { 30, 60, 120, 300, 600, 900, 1800 }

local CORE_LOOP_FUNNEL = "CoreLoop"
local CORE_LOOP_STEPS = {
	Spawn = { index = 1, name = "Spawn" },
	TreadmillStart = { index = 2, name = "TreadmillStart" },
	LeaveTreadmill = { index = 3, name = "LeaveTreadmill" },
	StageClear = { index = 4, name = "StageClear" },
}

local CORE_LOOP_V2_FUNNEL = "CoreLoopV2"
local CORE_LOOP_V2_STEPS = {
	Spawn = { index = 1, name = "Spawn" },
	Stage1Clear = { index = 2, name = "Stage1Clear" },
	Pad2 = { index = 3, name = "Pad2" },
	TreadmillStart = { index = 4, name = "TreadmillStart" },
}

local QUEST_CHAIN_FUNNEL = "QuestChain"
local DAILY_QUEST_FUNNEL = "DailyQuest"

-- 5s đủ mịn cho mốc nhỏ nhất (30s) mà chi phí gần như bằng 0.
local SESSION_TICK = 5

type Session = {
	funnelId: string,
	joinedAt: number,
	nextMark: number,
	deaths: number,
	markers: { [string]: boolean },
	spawned: boolean,
	assetsLoaded: boolean,
	controlsTouched: boolean,
	characterConnection: RBXScriptConnection?,
}

local sessions: { [Player]: Session } = {}

local function logFunnelStep(player: Player, funnelName: string, funnelId: string, index: number, name: string)
	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogFunnelStepEvent(player, funnelName, funnelId, index, name)
		end)
		if not ok and Env.IsStudio() then
			warn(`[Telemetry] Funnel {funnelName}/{name} lỗi: {err}`)
		end
	end)
end

-- Gửi thẳng, KHÔNG qua `task.spawn`. Dùng cho lúc `PlayerRemoving`: spawn sẽ chạy ở lần
-- resume sau, khi đó `player` có thể đã rời cây Instance và sự kiện mất trắng.
local function logCustomNow(player: Player, eventName: string, value: number)
	local ok, err = pcall(function()
		AnalyticsService:LogCustomEvent(player, eventName, value)
	end)
	if not ok and Env.IsStudio() then
		warn(`[Telemetry] Custom {eventName} lỗi: {err}`)
	end
end

-- Bước của phễu `CoreLoop`. Gọi bao nhiêu lần cũng được — chỉ lần đầu mỗi phiên gửi đi.
function TelemetryService.CoreLoop(player: Player, stepKey: string)
	local step = CORE_LOOP_STEPS[stepKey]
	local session = sessions[player]
	if not step or not session then
		return
	end
	local marker = `funnel:{stepKey}`
	if session.markers[marker] then
		return
	end
	session.markers[marker] = true
	logFunnelStep(player, CORE_LOOP_FUNNEL, session.funnelId, step.index, step.name)
end

function TelemetryService.CoreLoopV2(player: Player, stepKey: string)
	local step = CORE_LOOP_V2_STEPS[stepKey]
	local session = sessions[player]
	if not step or not session then
		return
	end
	local marker = `funnelV2:{stepKey}`
	if session.markers[marker] then
		return
	end
	session.markers[marker] = true
	logFunnelStep(player, CORE_LOOP_V2_FUNNEL, session.funnelId, step.index, step.name)
end

-- Bước 1 = chuỗi bắt đầu; bước 2..7 = Quest 1..6 hoàn thành.
function TelemetryService.QuestChain(player: Player, questIndex: number?)
	local session = sessions[player]
	if not session then
		return
	end
	if not session.markers.questChainStart then
		session.markers.questChainStart = true
		logFunnelStep(player, QUEST_CHAIN_FUNNEL, session.funnelId, 1, "QuestChainStart")
	end
	if questIndex and questIndex >= 1 and questIndex <= 6 then
		local marker = `questChain:{questIndex}`
		if not session.markers[marker] then
			session.markers[marker] = true
			logFunnelStep(player, QUEST_CHAIN_FUNNEL, session.funnelId, questIndex + 1, `Quest{questIndex}Complete`)
		end
	end
end

-- Each daily slot is its own two-step funnel so players may complete the three
-- quests in any order without violating Roblox's monotonic funnel requirement.
function TelemetryService.DailyQuest(player: Player, questIndex: number, completed: boolean)
	local session = sessions[player]
	if not session or questIndex < 1 or questIndex > 3 then
		return
	end
	local suffix = if completed then "complete" else "start"
	local marker = `dailyQuest:{questIndex}:{suffix}`
	if session.markers[marker] then
		return
	end
	session.markers[marker] = true
	logFunnelStep(
		player,
		DAILY_QUEST_FUNNEL,
		`{session.funnelId}:daily:{questIndex}`,
		if completed then 2 else 1,
		if completed then `DailyQuest{questIndex}Complete` else `DailyQuest{questIndex}Start`
	)
end

-- Như `Custom` nhưng chỉ đếm MỘT lần mỗi phiên. Dùng cho "lần đầu mở Shop", "lần đầu quay".
function TelemetryService.Once(player: Player, eventName: string, value: number?)
	local session = sessions[player]
	if not session or session.markers[eventName] then
		return
	end
	session.markers[eventName] = true
	TelemetryService.Custom(player, eventName, value)
end

-- Chết ở stage nào. `value` = số stage để Analytics Query API breakdown được theo giá trị.
function TelemetryService.Death(player: Player, stage: number)
	local session = sessions[player]
	if session then
		session.deaths += 1
	end
	TelemetryService.Custom(player, "Death", math.max(0, math.floor(stage)))
end

--[[
	Khép sổ một phiên. Ba con số này là thứ Creator Hub KHÔNG cho:

	  • `SessionSeconds` — độ dài phiên thật, không bị pha loãng bởi trung bình 28 ngày.
	  • `SessionDeaths` — chết bao nhiêu lần trước khi bỏ. Phân biệt "chán" với "ức chế".
	  • rổ thoát — đặt trùng hai mốc `<60s` / `61–180s` của Roblox để đối chiếu thẳng.
]]
local function finishSession(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	if not session then
		return
	end

	local seconds = math.max(0, os.clock() - session.joinedAt)
	if session.characterConnection then
		session.characterConnection:Disconnect()
	end
	logCustomNow(player, "SessionSeconds", math.floor(seconds))
	logCustomNow(player, "SessionDeaths", session.deaths)

	local bucket = if seconds < 60
		then "ExitUnder60"
		elseif seconds < 180 then "Exit60to180"
		elseif seconds < 600 then "Exit180to600"
		else "ExitOver600"
	logCustomNow(player, bucket, 1)
	if seconds < 30 then
		local earlyState = string.format(
			"EarlyExit_S%d_A%d_C%d",
			if session.spawned then 1 else 0,
			if session.assetsLoaded then 1 else 0,
			if session.controlsTouched then 1 else 0
		)
		logCustomNow(player, earlyState, math.floor(seconds))
	end
end

-- ============================================================================

function TelemetryService.Start()
	local function trackPlayer(player: Player)
		loggedSteps[player] = {}
		local session: Session = {
			funnelId = HttpService:GenerateGUID(false),
			joinedAt = os.clock(),
			nextMark = 1,
			deaths = 0,
			markers = {},
			spawned = player.Character ~= nil,
			assetsLoaded = false,
			controlsTouched = false,
			characterConnection = nil,
		}
		session.characterConnection = player.CharacterAdded:Connect(function()
			session.spawned = true
		end)
		sessions[player] = session
		TelemetryService.Onboarding(player, "Join")
		logFunnelStep(player, FIRST_SESSION_FUNNEL, session.funnelId, 1, "Spawn")
		TelemetryService.CoreLoop(player, "Spawn")
		TelemetryService.CoreLoopV2(player, "Spawn")
	end

	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
	Players.PlayerAdded:Connect(trackPlayer)
	Players.PlayerRemoving:Connect(function(player)
		loggedSteps[player] = nil
		finishSession(player)
	end)

	GamePackets.earlySessionState.listen(function(payload, player: Player?)
		if not player then
			return
		end
		local session = sessions[player]
		if not session or os.clock() - session.joinedAt > 30 then
			return
		end
		-- Hai cờ có thể đến cùng lúc từ hai controller; mỗi tổ hợp có hạn mức riêng.
		local key = `earlySession:{payload.assetsLoaded}:{payload.controlsTouched}`
		if NetRateLimit.ShouldDrop(player, key) then
			return
		end
		-- Cờ chỉ được tiến từ false → true; spam packet sau lần đầu không tạo thêm việc.
		session.assetsLoaded = session.assetsLoaded or payload.assetsLoaded
		session.controlsTouched = session.controlsTouched or payload.controlsTouched
	end)

	-- Vòng quét mốc thời gian của phễu `FirstSession`.
	task.spawn(function()
		while true do
			task.wait(SESSION_TICK)
			local now = os.clock()
			for player, session in sessions do
				while
					session.nextMark <= #FIRST_SESSION_MARKS
					and now - session.joinedAt >= FIRST_SESSION_MARKS[session.nextMark]
				do
					local seconds = FIRST_SESSION_MARKS[session.nextMark]
					logFunnelStep(
						player,
						FIRST_SESSION_FUNNEL,
						session.funnelId,
						session.nextMark + 1,
						`Alive{seconds}s`
					)
					session.nextMark += 1
				end
			end
		end
	end)

	-- Gom lỗi runtime theo script thay vì để chúng trôi trong Output. Roblox có
	-- trang Errors riêng, nhưng bản gom này cho biết NGAY trong log server là
	-- script nào đang hỏng liên tục.
	ScriptContext.Error:Connect(function(message: string, _stack: string, script: LuaSourceContainer?)
		local key = if script then script:GetFullName() else "unknown"
		errorCounts[key] = (errorCounts[key] or 0) + 1
		errorTotal += 1

		-- Lần đầu mỗi script thì in ngay, các lần sau chỉ đếm.
		if errorCounts[key] == 1 then
			warn(`[Telemetry] Lỗi đầu tiên ở {key}: {message}`)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(ERROR_REPORT_INTERVAL)
			if errorTotal > 0 then
				local lines = {}
				for key, count in errorCounts do
					table.insert(lines, `  {count}× {key}`)
				end
				table.sort(lines)
				warn(
					`[Telemetry] {errorTotal} lỗi trong {ERROR_REPORT_INTERVAL}s qua ({Env.Current}):\n{table.concat(
						lines,
						"\n"
					)}`
				)
				errorCounts = {}
				errorTotal = 0
			end
		end
	end)

	--[[
		`Log.Info` chứ KHÔNG phải `Log.Boot` (sửa 2026-08-24, ngay trước lần publish Live đầu).

		Đợt dọn Output hôm nay đã hạ dòng này xuống `Log.Boot` — tức im lặng theo mặc định.
		Sai: đây không phải một dòng "đã nạp xong", nó là **thứ duy nhất cho biết server đang
		ghi vào bể dữ liệu nào**. `Env` chọn store theo `game.PlaceId`; đoán nhầm hướng Live
		nghĩa là ghi đè lên dữ liệu thật của người chơi. Một dòng như vậy phải luôn in ra, và
		phải đọc được ngay ở dòng đầu log của server Live.
	]]
	Log.Info(`[Telemetry] Đang chạy ở môi trường {Env.Current}.`)
end

return TelemetryService
