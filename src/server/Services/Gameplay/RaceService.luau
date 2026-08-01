--!strict
-- Phần thưởng cũ (vạch đích Zone5). StageCheckpointService giờ xử lý đa số logic,
-- service này chỉ giữ Zone5Event và cooldown vạch đích lịch sử.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local FINISH_PAD_DISTANCE = 40

local finishCooldowns: { [Player]: number } = {}
local zone5Event: RemoteEvent

local ProgressionService

local RaceService = {}

local function onFinishTouched(finishPart: BasePart, hit: BasePart)
	local player = CharacterUtil.GetPlayerFromHit(hit)
	if not player then
		return
	end

	local now = os.clock()
	if now - (finishCooldowns[player] or 0) < Constants.FINISH_REWARD_COOLDOWN then
		return
	end

	local root = CharacterUtil.GetAliveRoot(player)
	if not root or (root.Position - finishPart.Position).Magnitude > FINISH_PAD_DISTANCE then
		return
	end

	finishCooldowns[player] = now
	local awarded = ProgressionService.AwardWins(player, Constants.FINISH_REWARD_WINS, "finish")
	if awarded then
		zone5Event:FireClient(player, "Victory", finishPart.Position)
	end
end

function RaceService.Init()
	ProgressionService = ServiceLocator.Get("ProgressionService")

	local existingEvent = ReplicatedStorage:FindFirstChild("Zone5Event")
	if existingEvent and existingEvent:IsA("RemoteEvent") then
		zone5Event = existingEvent
	else
		zone5Event = Instance.new("RemoteEvent")
		zone5Event.Name = "Zone5Event"
		zone5Event.Parent = ReplicatedStorage
	end
end

function RaceService.Start()
	-- StageCheckpointService xử lý chính. Service này dự phòng + giữ Zone5Event.
	Players.PlayerRemoving:Connect(function(player: Player)
		finishCooldowns[player] = nil
	end)
end

return RaceService
