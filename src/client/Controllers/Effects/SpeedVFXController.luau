--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SpeedVFXController = {}

-- Các thông số tinh chỉnh
local MIN_SPEED = 25    -- Tốc độ bắt đầu zoom FOV
local MAX_SPEED = 120   -- Tốc độ đạt mốc FOV cao nhất
local MIN_FOV = 70      -- FOV mặc định
local MAX_FOV = 110     -- FOV tối đa (Zoom góc rộng ra)

local speedAttachment = nil
local speedParticles = nil

function SpeedVFXController.SetupVFX()
	local camera = Workspace.CurrentCamera
	
	-- 1. Tạo Attachment đặt xa 60 stud ở phía trước Camera
	speedAttachment = Instance.new("Attachment")
	speedAttachment.Name = "SpeedVFXAttachment"
	speedAttachment.CFrame = CFrame.new(0, 0, -60) 
	speedAttachment.Parent = camera
	
	-- 2. Cấu hình ParticleEmitter (Hạt Gió / Speed Lines)
	local particle = Instance.new("ParticleEmitter")
	particle.Name = "SpeedLines"
	particle.Texture = "rbxassetid://7335687298" -- ID Texture tia sáng (có thể đổi)
	
	-- Bắn ngược hạt từ Attachment về phía Camera với tốc độ cực nhanh
	particle.EmissionDirection = Enum.NormalId.Back 
	particle.Speed = NumberRange.new(200, 300)
	particle.Lifetime = NumberRange.new(0.3, 0.5)
	particle.Rate = 0 -- Bắt đầu bằng 0, chỉ tăng khi chạy nhanh
	
	-- Mờ ở đầu và cuối để hạt gió xuất hiện/biến mất tự nhiên
	particle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(0.9, 0.8),
		NumberSequenceKeypoint.new(1, 1)
	})
	
	-- Dùng hình dáng xi lanh tỏa ra để tạo thành ống gió bao quanh màn hình
	particle.Shape = Enum.ParticleEmitterShape.Cylinder
	particle.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	particle.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	
	-- Kéo dẹt hạt để trông giống Sợi/Tia (Lines) thay vì hình vuông
	particle.Size = NumberSequence.new(0.6)
	particle.Squash = NumberSequence.new(-5) 
	particle.Orientation = Enum.ParticleOrientation.VelocityParallel
	
	-- Màu sắc và hiệu ứng sáng
	particle.Color = ColorSequence.new(Color3.fromRGB(200, 255, 255))
	particle.LightEmission = 0.8
	particle.ZOffset = -1 -- Tránh che lấp UI
	
	particle.Parent = speedAttachment
	speedParticles = particle
end

function SpeedVFXController.Start()
	SpeedVFXController.SetupVFX()
	
	local player = Players.LocalPlayer
	player.CameraMaxZoomDistance = 35
	player.CameraMinZoomDistance = 5
	
	RunService.RenderStepped:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local character = player.Character
		
		-- Gắn chặt Attachment vào Camera (phòng khi Camera bị thay đổi)
		if speedAttachment and speedAttachment.Parent ~= camera then
			speedAttachment.Parent = camera
		end
		if speedAttachment then
			speedAttachment.CFrame = CFrame.new(0, 0, -60)
		end
		
		-- Cố định FOV 70 (tắt hiệu ứng zoom màn hình / biến dạng góc nhìn khi chạy)
		camera.FieldOfView = MIN_FOV
		
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
		if not root then return end
		
		-- Lấy Vận Tốc Ngang (Horizontal Velocity)
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		
		-- ────────────────────────────────────────────────────────
		-- XỬ LÝ SỐ LƯỢNG HẠT GIÓ (SPEED LINES)
		-- ────────────────────────────────────────────────────────
		if speedParticles then
			if speed > 40 then
				local alpha = math.clamp((speed - 40) / (MAX_SPEED - 40), 0, 1)
				-- Khi chạy đạt max speed, bắn 150 vạch/giây
				speedParticles.Rate = alpha * 150 
			else
				speedParticles.Rate = 0
			end
		end
	end)
	
	print("[SpeedVFX] Camera Max Zoom (35) & Steady FOV Initialized.")
end


return SpeedVFXController
