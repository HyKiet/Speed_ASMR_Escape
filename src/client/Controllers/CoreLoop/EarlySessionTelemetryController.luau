--!strict
-- Gửi một cờ chẩn đoán khi người chơi chạm điều khiển lần đầu; không ảnh hưởng gameplay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)

local EarlySessionTelemetryController = {}

function EarlySessionTelemetryController.Init() end

function EarlySessionTelemetryController.Start()
	local connection: RBXScriptConnection?
	connection = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local isControl = input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.W
			or input.KeyCode == Enum.KeyCode.A
			or input.KeyCode == Enum.KeyCode.S
			or input.KeyCode == Enum.KeyCode.D
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.Thumbstick1
		if not isControl then
			return
		end
		if connection then
			connection:Disconnect()
			connection = nil
		end
		GamePackets.earlySessionState.send({
			assetsLoaded = false,
			controlsTouched = true,
		})
	end)
end

return EarlySessionTelemetryController
