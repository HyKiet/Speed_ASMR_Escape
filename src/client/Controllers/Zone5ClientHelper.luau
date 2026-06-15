--!strict
-- Client-side controller for Stage 5 presentation effects.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Zone5ClientHelper = {}

local zone5Event = ReplicatedStorage:WaitForChild("Zone5Event", 5) :: RemoteEvent?
local localPlayer = Players.LocalPlayer

function Zone5ClientHelper.Init()
	print("[CLIENT] Zone5ClientHelper Initializing...")
end

function Zone5ClientHelper.Start()
	print("[CLIENT] Zone5ClientHelper Starting...")

	if not zone5Event then
		warn("[CLIENT] Zone5Event not found!")
		return
	end

	zone5Event.OnClientEvent:Connect(function(action: string, data: any)
		if action == "BallExplode" then
			local position = data :: Vector3
			local sound = Instance.new("Sound")
			sound.SoundId = "rbxassetid://9114223164"
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
		elseif action == "Victory" then
			local position = data :: Vector3
			local victorySound = Instance.new("Sound")
			victorySound.SoundId = "rbxassetid://9086154674"
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
					launchSound.SoundId = "rbxassetid://9113693356"
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
	end)
end

return Zone5ClientHelper
