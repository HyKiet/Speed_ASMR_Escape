--!strict
-- Quản lý dữ liệu profile của mỗi người chơi qua ProfileStore + leaderstats.
-- Khi CoreLoopVersion ở profile cũ hơn Constants.CORE_LOOP_VERSION,
-- chạy migration (hiện chỉ reset CustomSpeedLimit theo công thức mới).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Env = require(ReplicatedStorage.Shared.Util.Env)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

type PlayerData = typeof(Constants.DATA_TEMPLATE)
type Profile = any

local DATA_STORE_NAME = Env.StoreName("SpeedEscape_Player_v1")
local STUDIO_TEST_TOTAL_WINS = 1_000_000
local STUDIO_TEST_SPEED = 500_000
local STUDIO_TEST_LEVEL = 120

local playerStore = ProfileStore.New(DATA_STORE_NAME, Constants.DATA_TEMPLATE)
if RunService:IsStudio() then
	playerStore = playerStore.Mock
end

local profiles: { [Player]: Profile } = {}
local leaderstatsByPlayer: { [Player]: Folder } = {}

local DataService = {}

local function createValue(parent: Instance, className: string, name: string, value: any): Instance
	local instance = Instance.new(className)
	instance.Name = name
	;(instance :: any).Value = value
	instance.Parent = parent
	return instance
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	createValue(leaderstats, "NumberValue", "Speed", 0)
	createValue(leaderstats, "NumberValue", "Wins", 0)
	createValue(leaderstats, "IntValue", "Level", 1)
	createValue(leaderstats, "IntValue", "Rebirths", 0)

	leaderstatsByPlayer[player] = leaderstats
end

local function readNumber(data: { [string]: any }, key: string, fallback: number): number
	local value = data[key]
	if typeof(value) == "number" and value == value then
		return value
	end
	data[key] = fallback
	return fallback
end

local function normalizeData(data: { [string]: any })
	readNumber(data, "Speed", 0)
	readNumber(data, "TotalWins", 0)
	readNumber(data, "CurrentRunWins", 0)
	readNumber(data, "Streak", 0)
	readNumber(data, "PersonalBestDistance", 0)
	readNumber(data, "PersonalBestRunWins", 0)
	readNumber(data, "TotalRuns", 0)
	readNumber(data, "TotalDonatedRobux", 0)
	if typeof(data.hasClaimedGroupReward) ~= "boolean" then
		data.hasClaimedGroupReward = false
	end
	if typeof(data.hasConfirmedLikeGroupReward) ~= "boolean" then
		data.hasConfirmedLikeGroupReward = false
	end
	local coreLoopVersion = readNumber(data, "CoreLoopVersion", 0)
	readNumber(data, "HighestCompletedStage", 0)
	readNumber(data, "Rebirths", 0)
	local level = readNumber(data, "Level", 1)
	readNumber(data, "XP", 0)
	readNumber(data, "CustomSpeedLimit", Constants.GetMaxWalkSpeed(level))

	if typeof(data.EquippedTreadmill) ~= "string" then
		data.EquippedTreadmill = "treadmill_1"
	end
	if typeof(data.EquippedTrail) ~= "string" then
		data.EquippedTrail = "none"
	end
	if typeof(data.EquippedAura) ~= "string" then
		data.EquippedAura = "none"
	end
	if typeof(data.UnlockedTreadmills) ~= "table" then
		data.UnlockedTreadmills = { treadmill_1 = true }
	end
	if typeof(data.UnlockedTrails) ~= "table" then
		data.UnlockedTrails = { none = true }
	end
	if typeof(data.UnlockedAuras) ~= "table" then
		data.UnlockedAuras = { none = true }
	end

	if coreLoopVersion < Constants.CORE_LOOP_VERSION then
		data.CustomSpeedLimit = Constants.GetMaxWalkSpeed(level)
		data.CoreLoopVersion = Constants.CORE_LOOP_VERSION
	end

	if RunService:IsStudio() then
		data.TotalWins = math.max(data.TotalWins, STUDIO_TEST_TOTAL_WINS)
		data.Speed = STUDIO_TEST_SPEED
		data.Level = STUDIO_TEST_LEVEL
		data.XP = 0
		data.CustomSpeedLimit = Constants.GetMaxWalkSpeed(STUDIO_TEST_LEVEL)
		data.UnlockedTreadmills = { treadmill_1 = true }
		data.UnlockedTrails = { none = true }
		data.UnlockedAuras = { none = true }
		data.EquippedTreadmill = "treadmill_1"
		data.EquippedTrail = "none"
		data.EquippedAura = "none"
	end

end

local function updateLeaderstats(player: Player, data: PlayerData)
	local leaderstats = leaderstatsByPlayer[player]
	if not leaderstats then
		return
	end

	local speed = leaderstats:FindFirstChild("Speed") :: NumberValue?
	local wins = leaderstats:FindFirstChild("Wins") :: NumberValue?
	local level = leaderstats:FindFirstChild("Level") :: IntValue?
	local rebirths = leaderstats:FindFirstChild("Rebirths") :: IntValue?

	if speed then
		speed.Value = math.floor(data.Speed)
	end
	if wins then
		wins.Value = math.floor(data.TotalWins)
	end
	if level then
		level.Value = math.floor(data.Level)
	end
	if rebirths then
		rebirths.Value = math.floor(data.Rebirths)
	end
end

local function loadPlayer(player: Player)
	createLeaderstats(player)

	local profile = playerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	normalizeData(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	updateLeaderstats(player, profile.Data)
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("HighestCompletedStage", math.floor(readNumber(profile.Data, "HighestCompletedStage", 0)))
end

function DataService.Init() end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("ProfileLoaded", false)
		leaderstatsByPlayer[player] = nil

		local profile = profiles[player]
		if profile then
			profiles[player] = nil
			profile:EndSession()
		end
	end)
end

function DataService.GetData(player: Player): PlayerData?
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return nil
	end
	return profile.Data
end

function DataService.IsLoaded(player: Player): boolean
	return DataService.GetData(player) ~= nil
end

function DataService.UpdateLeaderstats(player: Player)
	local data = DataService.GetData(player)
	if data then
		updateLeaderstats(player, data)
	end
end

return DataService
