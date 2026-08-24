--!strict
--[[
	SpeedWindAudioController.luau
	Client controller that manages dynamic speed-based ambient wind sounds and sonic booms
	using Roblox's new node-based Audio API.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SpeedWindAudioController = {}

local localPlayer = Players.LocalPlayer
local windPlayer: AudioPlayer? = nil
local windFader: AudioFader? = nil
local windPitchShifter: AudioPitchShifter? = nil
local deviceOutput: AudioDeviceOutput? = nil

local sonicBoomPlayer: AudioPlayer? = nil

-- Sonic boom control state
local hasSonicBoomed = false
local lastBoomTime = 0
local SONIC_BOOM_COOLDOWN = 10 -- 10 seconds between booms

local function initAudioAPI()
	-- 1. Create Nodes
	local playerNode = Instance.new("AudioPlayer")
	playerNode.Name = "WindLoopPlayer"
	playerNode.AssetId = "rbxassetid://687874741"
	playerNode.Looping = true
	playerNode.Parent = SoundService
	windPlayer = playerNode

	local faderNode = Instance.new("AudioFader")
	faderNode.Name = "WindFader"
	faderNode.Volume = 0 -- Start at 0 volume
	faderNode.Parent = SoundService
	windFader = faderNode

	local pitchNode = Instance.new("AudioPitchShifter")
	pitchNode.Name = "WindPitchShifter"
	pitchNode.PitchRatio = 1.0
	pitchNode.Parent = SoundService
	windPitchShifter = pitchNode

	local outputNode = Instance.new("AudioDeviceOutput")
	outputNode.Name = "WindDeviceOutput"
	outputNode.Parent = SoundService
	deviceOutput = outputNode

	-- 2. Wire nodes: Player -> Fader -> PitchShifter -> DeviceOutput
	local wire1 = Instance.new("Wire")
	wire1.Name = "WirePlayerToFader"
	wire1.SourceInstance = playerNode
	wire1.TargetInstance = faderNode
	wire1.Parent = SoundService

	local wire2 = Instance.new("Wire")
	wire2.Name = "WireFaderToPitch"
	wire2.SourceInstance = faderNode
	wire2.TargetInstance = pitchNode
	wire2.Parent = SoundService

	local wire3 = Instance.new("Wire")
	wire3.Name = "WirePitchToOutput"
	wire3.SourceInstance = pitchNode
	wire3.TargetInstance = outputNode
	wire3.Parent = SoundService

	-- One-shot Sonic Boom AudioPlayer
	local boomPlayer = Instance.new("AudioPlayer")
	boomPlayer.Name = "SonicBoomPlayer"
	boomPlayer.AssetId = "rbxassetid://9120769331"
	boomPlayer.Looping = false
	boomPlayer.Parent = SoundService
	sonicBoomPlayer = boomPlayer

	local boomWire = Instance.new("Wire")
	boomWire.Name = "WireBoomToOutput"
	boomWire.SourceInstance = boomPlayer
	boomWire.TargetInstance = outputNode
	boomWire.Parent = SoundService

	-- Start playing the loop
	playerNode:Play()
end

local function triggerSonicBoom(camera: Camera)
	local now = os.clock()
	if now - lastBoomTime < SONIC_BOOM_COOLDOWN then
		return
	end
	lastBoomTime = now

	if sonicBoomPlayer then
		sonicBoomPlayer:Play()
	end

	-- Simple camera shake effect
	task.spawn(function()
		local originalCFrame = camera.CFrame
		for i = 1, 15 do
			local offset =
				Vector3.new(math.random(-50, 50) / 100, math.random(-50, 50) / 100, math.random(-50, 50) / 100)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			task.wait(0.02)
		end
	end)
end

function SpeedWindAudioController.Init()
	-- Initialize new Audio API nodes
	pcall(initAudioAPI)
end

function SpeedWindAudioController.Start()
	local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

	RunService.RenderStepped:Connect(function()
		local char = localPlayer.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")

		if not humanoid or not root or humanoid.Health <= 0 then
			-- Fade out sound when dead
			if windFader then
				windFader.Volume = math.max(0, windFader.Volume - 0.1)
			end
			return
		end

		-- Read physical WalkSpeed
		local speed = humanoid.WalkSpeed

		if windFader and windPitchShifter then
			-- Dynamic Volume based on Speed: starts at 50 speed, caps at 200 speed
			local targetVolume = 0
			local targetPitch = 1.0

			if speed > 50 then
				targetVolume = math.clamp((speed - 50) / 150, 0, 1.8)
				targetPitch = 0.8 + math.clamp((speed - 50) / 150, 0, 1.2)
			end

			-- Smooth interpolation
			windFader.Volume = windFader.Volume + (targetVolume - windFader.Volume) * 0.1
			windPitchShifter.PitchRatio = windPitchShifter.PitchRatio
				+ (targetPitch - windPitchShifter.PitchRatio) * 0.1
		end

		-- Sonic Boom trigger: speed exceeds 200 studs/s
		if speed >= 200 then
			if not hasSonicBoomed then
				hasSonicBoomed = true
				triggerSonicBoom(camera)
			end
		else
			hasSonicBoomed = false
		end
	end)

	Log.Boot("[SpeedWindAudioController] Dynamic wind sound and sonic boom loaded successfully!")
end

return SpeedWindAudioController
