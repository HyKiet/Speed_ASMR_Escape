--!strict
-- Client: tăng tiếng gió theo WalkSpeed và phát sonic boom khi vượt ngưỡng tốc độ.
-- Nối các audio node trong SoundService; camera hiện tại nhận rung ngắn lúc sonic boom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SpeedWindAudioController = {}

local localPlayer = Players.LocalPlayer
local windPlayer: AudioPlayer? = nil
local windFader: AudioFader? = nil
local windPitchShifter: AudioPitchShifter? = nil
local audioJanitor = Janitor.new()
local started = false
local AudioMixController: any

local sonicBoomPlayer: AudioPlayer? = nil

-- Sonic boom control state
local hasSonicBoomed = false
local lastBoomTime = 0
local SONIC_BOOM_COOLDOWN = 10 -- 10 seconds between booms

local function initAudioAPI()
	-- 1. Create Nodes
	local playerNode = Instance.new("AudioPlayer")
	audioJanitor:Add(playerNode, "Destroy")
	playerNode.Name = "WindLoopPlayer"
	playerNode.Asset = "rbxassetid://687874741"
	playerNode.Looping = true
	playerNode.Parent = SoundService
	windPlayer = playerNode

	local faderNode = Instance.new("AudioFader")
	audioJanitor:Add(faderNode, "Destroy")
	faderNode.Name = "WindFader"
	faderNode.Volume = 0 -- Start at 0 volume
	faderNode.Parent = SoundService
	windFader = faderNode

	local pitchNode = Instance.new("AudioPitchShifter")
	audioJanitor:Add(pitchNode, "Destroy")
	pitchNode.Name = "WindPitchShifter"
	pitchNode.Pitch = 1.0
	pitchNode.Parent = SoundService
	windPitchShifter = pitchNode

	local outputNode = Instance.new("AudioDeviceOutput")
	audioJanitor:Add(outputNode, "Destroy")
	outputNode.Name = "WindDeviceOutput"
	outputNode.Parent = SoundService

	-- 2. Wire nodes: Player -> Fader -> PitchShifter -> DeviceOutput
	local wire1 = Instance.new("Wire")
	audioJanitor:Add(wire1, "Destroy")
	wire1.Name = "WirePlayerToFader"
	wire1.SourceInstance = playerNode
	wire1.TargetInstance = faderNode
	wire1.Parent = SoundService

	local wire2 = Instance.new("Wire")
	audioJanitor:Add(wire2, "Destroy")
	wire2.Name = "WireFaderToPitch"
	wire2.SourceInstance = faderNode
	wire2.TargetInstance = pitchNode
	wire2.Parent = SoundService

	local wire3 = Instance.new("Wire")
	audioJanitor:Add(wire3, "Destroy")
	wire3.Name = "WirePitchToOutput"
	wire3.SourceInstance = pitchNode
	wire3.TargetInstance = outputNode
	wire3.Parent = SoundService

	-- One-shot Sonic Boom AudioPlayer
	local boomPlayer = Instance.new("AudioPlayer")
	audioJanitor:Add(boomPlayer, "Destroy")
	boomPlayer.Name = "SonicBoomPlayer"
	boomPlayer.Asset = "rbxassetid://9120769331"
	boomPlayer.Looping = false
	boomPlayer.Parent = SoundService
	sonicBoomPlayer = boomPlayer

	local boomWire = Instance.new("Wire")
	audioJanitor:Add(boomWire, "Destroy")
	boomWire.Name = "WireBoomToOutput"
	boomWire.SourceInstance = boomPlayer
	boomWire.TargetInstance = outputNode
	boomWire.Parent = SoundService

	-- Start playing the loop
	playerNode:Play()
	return true
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
		for _ = 1, 15 do
			if Workspace.CurrentCamera ~= camera then
				return
			end
			local offset =
				Vector3.new(math.random(-50, 50) / 100, math.random(-50, 50) / 100, math.random(-50, 50) / 100)
			camera.CFrame = camera.CFrame * CFrame.new(offset)
			task.wait(0.02)
		end
	end)
end

function SpeedWindAudioController.Init()
	AudioMixController = ServiceLocator.Get("AudioMixController")
	audioJanitor:Sweep()
	windPlayer = nil
	windFader, windPitchShifter, sonicBoomPlayer = nil, nil, nil
	local ok, err = pcall(initAudioAPI)
	if not ok then
		-- Lỗi giữa chừng không được để lại nửa chuỗi audio trong SoundService.
		audioJanitor:Sweep()
		windPlayer = nil
		windFader, windPitchShifter, sonicBoomPlayer = nil, nil, nil
		warn("[SpeedWindAudioController] Audio initialization failed:", err)
	end
end

function SpeedWindAudioController.Start()
	if started then
		return
	end
	started = true

	RunService.RenderStepped:Connect(function()
		-- AudioPlayer không đi qua SoundGroup của mixer; áp cùng Master/SFX tại nguồn.
		local gain = AudioMixController.GetVolume("master") * AudioMixController.GetVolume("sfx")
		if windPlayer then
			windPlayer.Volume = gain
		end
		if sonicBoomPlayer then
			sonicBoomPlayer.Volume = gain
		end
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
			windPitchShifter.Pitch = windPitchShifter.Pitch + (targetPitch - windPitchShifter.Pitch) * 0.1
		end

		-- Sonic Boom trigger: speed exceeds 200 studs/s
		if speed >= 200 then
			local camera = Workspace.CurrentCamera
			if not hasSonicBoomed and camera then
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
