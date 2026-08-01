--!strict
--[[
	CameraFaceController.luau — snap camera ra sau lưng player sau khi server teleport.

	Server xoay CFrame của character được, nhưng CAMERA thuộc về client — sau teleport
	camera vẫn giữ góc quay cũ nên người chơi nhìn ngược hướng chạy dù nhân vật đã quay
	đúng. Server gửi packet `snapCamera {lookX, lookZ}` ngay sau mỗi teleport/hồi sinh;
	controller này đặt camera ra SAU lưng, nhìn xuôi theo hướng đó.

	Chờ 2 nhịp Heartbeat trước khi snap: CFrame mới của root do server set cần 1 nhịp
	replication mới tới client; snap sớm quá sẽ đặt camera quanh VỊ TRÍ CŨ.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)

local CameraFaceController = {}

-- Khớp offset camera mặc định của Roblox (zoom ~12.5, hơi cao hơn đầu).
local CAMERA_DISTANCE = 12
local CAMERA_HEIGHT = 5
local FOCUS_HEIGHT = 2

local function snapTo(direction: Vector3)
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local focus = root.Position + Vector3.new(0, FOCUS_HEIGHT, 0)
	local eye = focus - (direction * CAMERA_DISTANCE) + Vector3.new(0, CAMERA_HEIGHT, 0)
	-- CameraType Custom: set CFrame một lần là engine nhận góc quay mới rồi tự follow tiếp.
	camera.CFrame = CFrame.lookAt(eye, focus)
end

function CameraFaceController.Start()
	GamePackets.snapCamera.listen(function(data)
		local direction = Vector3.new(data.lookX, 0, data.lookZ)
		if direction.Magnitude < 0.01 then
			return
		end
		direction = direction.Unit

		task.spawn(function()
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			snapTo(direction)
		end)
	end)
end

return CameraFaceController
