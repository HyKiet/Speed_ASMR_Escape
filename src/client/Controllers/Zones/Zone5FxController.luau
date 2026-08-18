--!strict
-- Hiệu ứng client cho Stage 5 (nổ banh + pháo hoa khi Victory).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Zone5FxController = {}

local zone5Event = ReplicatedStorage:WaitForChild("Zone5Event", 5) :: RemoteEvent?
local localPlayer = Players.LocalPlayer

--[[
	⚠️ 3 ID audio trong file này ĐỀU SAI LOẠI ASSET (phát hiện 2026-07-30), không phải lỗi
	quyền — chúng câm lặng suốt, không log gì tới khi thật sự Play():
	  • 9114223164 (ball explode) → MeshPart (mảnh bản đồ, còn riêng tư)
	  • 9086154674 (victory)      → Place của người khác
	  • 9113693356 (launch)       → Lua script
	Thay bằng 2 ID trong bộ POP đã dùng ở BoostCelebration.FIREWORK_POPS — cùng bộ
	ProSoundEffects, đã xác nhận IsA Audio và đang phát tốt trong chính game này.
]]
local POP_SOUND = "rbxassetid://9117848644"
local LAUNCH_SOUND = "rbxassetid://9119669295"

local function spawnBallExplode(position: Vector3)
	local sound = Instance.new("Sound")
	sound.SoundId = POP_SOUND
	sound.Volume = 0.5
	sound.Pitch = 1.2 + (math.random(-15, 15) / 100)

	local soundPart = Instance.new("Part")
	soundPart.Size = Vector3.new(1, 1, 1)
	soundPart.Position = position
	soundPart.Transparency = 1
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.CanQuery = false
	soundPart.CanTouch = false
	soundPart.Parent = Workspace

	sound.Parent = soundPart
	sound:Play()

	local attachment = Instance.new("Attachment")
	attachment.Parent = soundPart

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxassetid://242268630"
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(231, 76, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(46, 204, 113)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 235, 59)),
	})
	particles.Speed = NumberRange.new(8, 20)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Lifetime = NumberRange.new(0.8, 1.5)
	particles.Rate = 180
	particles.Enabled = true
	particles.Parent = attachment

	task.delay(0.2, function()
		particles.Enabled = false
		task.delay(1.6, function()
			soundPart:Destroy()
		end)
	end)
end

local function spawnVictoryFireworks(position: Vector3)
	local victorySound = Instance.new("Sound")
	-- 2026-08-12: dùng âm chúc mừng chung (âm rebirth) — xem Theme.UI_ASSETS.CelebrationSound.
	victorySound.SoundId = "rbxassetid://4612383790"
	victorySound.Volume = 0.6
	victorySound.Parent = localPlayer:WaitForChild("PlayerGui", 5) or Workspace
	victorySound:Play()

	task.delay(5, function()
		victorySound:Destroy()
	end)

	task.spawn(function()
		for _ = 1, 4 do
			local offset = Vector3.new(math.random(-4, 4), math.random(0, 2), math.random(-4, 4))
			local fireworkPosition = position + offset

			local fireworkPart = Instance.new("Part")
			fireworkPart.Size = Vector3.new(1, 1, 1)
			fireworkPart.Position = fireworkPosition
			fireworkPart.Transparency = 1
			fireworkPart.Anchored = true
			fireworkPart.CanCollide = false
			fireworkPart.CanQuery = false
			fireworkPart.CanTouch = false
			fireworkPart.Parent = Workspace

			local attachment = Instance.new("Attachment")
			attachment.Parent = fireworkPart

			local launchSound = Instance.new("Sound")
			launchSound.SoundId = LAUNCH_SOUND
			launchSound.Volume = 0.4
			launchSound.Parent = fireworkPart
			launchSound:Play()

			local particles = Instance.new("ParticleEmitter")
			particles.Texture = "rbxassetid://242268630"
			particles.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.8),
				NumberSequenceKeypoint.new(1, 0),
			})

			local randomColors = {
				Color3.fromRGB(255, 50, 50),
				Color3.fromRGB(50, 255, 50),
				Color3.fromRGB(50, 50, 255),
				Color3.fromRGB(255, 255, 50),
			}
			particles.Color = ColorSequence.new(randomColors[math.random(1, #randomColors)])
			particles.Speed = NumberRange.new(15, 30)
			particles.SpreadAngle = Vector2.new(60, 60)
			particles.Acceleration = Vector3.new(0, -10, 0)
			particles.Lifetime = NumberRange.new(1.0, 1.8)
			particles.Rate = 220
			particles.Enabled = true
			particles.Parent = attachment

			task.delay(0.15, function()
				particles.Enabled = false
				task.delay(2, function()
					fireworkPart:Destroy()
				end)
			end)

			task.wait(0.25)
		end
	end)
end

function Zone5FxController.Init() end

function Zone5FxController.Start()
	if not zone5Event then
		warn("[Zone5FxController] Zone5Event không tìm thấy")
		return
	end

	zone5Event.OnClientEvent:Connect(function(action: string, data: any)
		if action == "BallExplode" then
			spawnBallExplode(data :: Vector3)
		elseif action == "Victory" then
			spawnVictoryFireworks(data :: Vector3)
		end
	end)
end

return Zone5FxController
