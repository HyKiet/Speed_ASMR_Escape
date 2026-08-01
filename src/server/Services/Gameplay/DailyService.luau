--!strict
-- Hệ thống Điểm danh 7 ngày (Hardcore Streak).
-- Bỏ lỡ 1 ngày → reset chuỗi về Ngày 1. Phần thưởng tăng dần, Ngày 7 tặng 1 lượt quay Roulette.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local DailyService = {}

-- Cấu hình Phần thưởng Điểm danh 7 Ngày (Chuẩn Cân bằng Kinh tế + Đa dạng Phần thưởng)
local DAILY_REWARDS = {
	{ wins = 300, spin = 1 },
	{ speed = 5000, boostSpeed = 600 },
	{ wins = 1000, spin = 1 },
	{ speed = 15000, boostWins = 600 },
	{ wins = 3000, spin = 2 },
	{ speed = 35000, megaServerBoost = true },
	{ wins = 10000, speed = 50000, spin = 3 },
}

local SECONDS_PER_DAY = 86400

local DataService: any
local ProgressionService: any

local function todayNumber(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

-- Trả về: streakDayHiệnTại, canClaim, nextDay(1..7)
local function computeState(data: any): (number, boolean, number)
	local last = tonumber(data.DailyLastClaimDay) or 0
	local streak = tonumber(data.DailyStreakDay) or 0

	if last == 0 then
		return 0, true, 1
	end

	local diff = todayNumber() - last
	if diff <= 0 then
		-- Đã nhận hôm nay rồi
		return streak, false, math.clamp(streak + 1, 1, 7)
	elseif diff == 1 then
		-- Ngày kế tiếp liên tục
		local nextDay = if streak >= 7 then 1 else streak + 1
		return streak, true, nextDay
	else
		-- Bỏ lỡ → reset
		return 0, true, 1
	end
end

local function sendState(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	local streak, canClaim, nextDay = computeState(data)
	-- Khi chuẩn bị mở chuỗi mới (nextDay == 1) thì hiển thị 0 ngày đã nhận.
	local displayStreak = streak
	if canClaim and nextDay == 1 then
		displayStreak = 0
	end

	GamePackets.dailyState.sendTo({
		streakDay = math.clamp(displayStreak, 0, 7),
		canClaim = canClaim,
		nextDay = math.clamp(nextDay, 1, 7),
	}, player)
end

local function grantReward(player: Player, day: number)
	local reward = DAILY_REWARDS[day]
	if not reward then
		return
	end

	if reward.wins and reward.wins > 0 then
		ProgressionService.AwardWins(player, reward.wins, "daily")
	end

	if reward.speed and reward.speed > 0 then
		ProgressionService.GrantSpeed(player, reward.speed)
	end

	if reward.spin and reward.spin > 0 then
		local rouletteService = ServiceLocator.Find("RouletteService")
		if rouletteService then
			rouletteService.GrantTickets(player, reward.spin, true)
		end
	end

	local serverBoostService = ServiceLocator.Find("ServerBoostService")
	if reward.boostSpeed and serverBoostService then
		serverBoostService.ActivatePersonalBoost(player, "speed", reward.boostSpeed)
	end

	if reward.boostWins and serverBoostService then
		serverBoostService.ActivatePersonalBoost(player, "wins", reward.boostWins)
	end

	if reward.megaServerBoost and serverBoostService then
		serverBoostService.ActivateServerBoost(player, "both", 600)
	end
end


local function onClaim(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	local _, canClaim, nextDay = computeState(data)
	if not canClaim then
		sendState(player)
		return
	end

	grantReward(player, nextDay)
	data.DailyStreakDay = nextDay
	data.DailyLastClaimDay = todayNumber()

	sendState(player)
end

function DailyService.SendState(player: Player)
	sendState(player)
end

function DailyService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
end

function DailyService.Start()
	GamePackets.requestDailyClaim.listen(function(_data, player: Player)
		onClaim(player)
	end)

	local function pushWhenReady(player: Player)
		task.spawn(function()
			local tries = 0
			while not DataService.IsLoaded(player) and tries < 200 and player.Parent == Players do
				task.wait(0.1)
				tries += 1
			end
			if DataService.IsLoaded(player) then
				sendState(player)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		pushWhenReady(player)
	end
	Players.PlayerAdded:Connect(pushWhenReady)
end

return DailyService
