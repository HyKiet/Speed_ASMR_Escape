--!strict
--[[
	Zone12WindTunnelController.luau
	Client-side controller for Stage 12: Cyber Wind Tunnel.
	
	Features:
	1. Applies a physical VectorForce to HumanoidRootPart to push players back when jumping.
	2. Applies a continuous CFrame displacement of -180 studs/s along World X-axis to simulate wind velocity.
	3. Calculates tunnel X bounds dynamically based on Platform_12 workspace position/size.
	4. Triggers high-frequency camera shake when exposed to the wind.
	5. Modulates a localized howling wind sound dynamically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local State = require(script.Parent.Parent.HUD.State)

local Zone12WindTunnelController = {}

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Constants
local WIND_VELOCITY = 170 -- Wind velocity pushing player back (only WS > 170 can pass!)
local BASE_FORCE = 4500 -- Physical force to push back in air

local activeForce: VectorForce? = nil
local activeAttachment: Attachment? = nil
local windSound: Sound? = nil
local currentExposure = 0 -- Lerps between 0 (outside) and 1 (inside tunnel)

-- Dynamic bounds cached at startup/heartbeat
local cachedMinX = 1660
local cachedMaxX = 1860

local function updateTunnelBounds()
	local zone12 = Workspace:FindFirstChild("Zone12", true)
	local ground = zone12 and zone12:FindFirstChild("Ground")
	local tunnel = ground and ground:FindFirstChild("WindTunnel") :: Model?
	if tunnel then
		local cf, size = tunnel:GetBoundingBox()
		cachedMinX = cf.Position.X - size.X / 2
		cachedMaxX = cf.Position.X + size.X / 2
	end
end

local function cleanupWind()
	if activeForce then
		activeForce:Destroy()
		activeForce = nil
	end
	if activeAttachment then
		activeAttachment:Destroy()
		activeAttachment = nil
	end
	if windSound then
		windSound:Stop()
		windSound:Destroy()
		windSound = nil
	end
	currentExposure = 0
end

local function setupWind(root: BasePart)
	cleanupWind()

	-- Create attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "WindAttachment"
	attachment.Parent = root
	activeAttachment = attachment

	-- Create VectorForce
	local force = Instance.new("VectorForce")
	force.Name = "WindForce"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.new(0, 0, 0)
	force.Parent = root
	activeForce = force

	-- Create looping Wind Sound
	local sound = Instance.new("Sound")
	sound.Name = "WindTunnelHowl"
	sound.SoundId = "rbxassetid://687874741" -- 180155825 không phải asset Sound (không bao giờ load)
	sound.Volume = 0
	sound.Looped = true
	sound.PlayOnRemove = false
	sound.Parent = SoundService
	sound:Play()
	windSound = sound
end

local function getCharacterMass(char: Model): number
	local mass = 0
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			mass = mass + part:GetMass()
		end
	end
	return mass > 0 and mass or 120
end

function Zone12WindTunnelController.Init()
	updateTunnelBounds()
end

function Zone12WindTunnelController.Start()
	-- Periodic check in case map loads late or shifts
	task.spawn(function()
		while true do
			updateTunnelBounds()
			task.wait(2.0)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local char = localPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if not root or not hum or hum.Health <= 0 then
			cleanupWind()
			return
		end

		local pPos = root.Position
		-- Check if player is inside Stage 12 Wind Tunnel bounds
		local inTunnel = pPos.X >= cachedMinX
			and pPos.X <= cachedMaxX
			and pPos.Y >= 180
			and pPos.Y <= 300
			and pPos.Z >= 2990
			and pPos.Z <= 3070

		if not inTunnel then
			cleanupWind()
			return
		end

		-- Inside tunnel: Ensure VectorForce is set up
		if not activeForce or not activeAttachment or activeAttachment.Parent ~= root then
			setupWind(root)
		end

		-- Wind is continuous inside the tunnel
		local targetExposure = 1
		currentExposure = currentExposure + (targetExposure - currentExposure) * 0.15 -- Smooth transition

		-- 1. Apply CFrame pushback based on wind exposure (World X translation)
		if currentExposure > 0.01 then
			local pushback = -WIND_VELOCITY * currentExposure * dt
			root.CFrame = root.CFrame + Vector3.new(pushback, 0, 0)
		end

		-- 2. Apply physical force (mainly pushes player back in the air when jumping)
		local mass = getCharacterMass(char)
		local forceValue = -BASE_FORCE * (mass / 120) * currentExposure
		if activeForce then
			activeForce.Force = Vector3.new(forceValue, 0, 0)
		end

		-- 3. Camera Shake when exposed
		if currentExposure > 0.05 then
			camera = Workspace.CurrentCamera
			if camera then
				local shakeMultiplier = currentExposure * 0.08
				local shake = Vector3.new(
					math.random(-100, 100) / 1000 * shakeMultiplier,
					math.random(-100, 100) / 1000 * shakeMultiplier,
					math.random(-100, 100) / 1000 * shakeMultiplier
				)
				camera.CFrame = camera.CFrame * CFrame.new(shake)
			end
		end

		-- 4. Modulate looping Wind Sound
		if windSound then
			windSound.Volume = currentExposure * 1.5
			windSound.PlaybackSpeed = 0.85 + currentExposure * 0.45
		end
	end)

	Log.Boot("[Zone12WindTunnelController] Client-side Wind Tunnel controller successfully loaded!")
end

return Zone12WindTunnelController
