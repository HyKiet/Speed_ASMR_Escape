--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ProgressionService = require(script.Parent.ProgressionService)

local FINISH_PAD_DISTANCE = 40

local finishCooldowns: { [Player]: number } = {}
local zone5Event: RemoteEvent

local RaceService = {}

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end

	return root
end

local function getPlayerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function connectTouched(part: BasePart, callback: (BasePart, BasePart) -> ())
	part.Touched:Connect(function(hit: BasePart)
		if hit:IsA("BasePart") then
			callback(part, hit)
		end
	end)
end

local function onFinishTouched(finishPart: BasePart, hit: BasePart)
	local player = getPlayerFromHit(hit)
	if not player then
		return
	end

	local now = os.clock()
	if now - (finishCooldowns[player] or 0) < Constants.FINISH_REWARD_COOLDOWN then
		return
	end

	local root = getCharacterRoot(player)
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
	-- Stage finish checkpoints and rewards are handled by StageCheckpointService.

	Players.PlayerRemoving:Connect(function(player: Player)
		finishCooldowns[player] = nil
	end)
end

return RaceService
