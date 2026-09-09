--!strict
-- Client giữ FOV ổn định, cộng bù từ Modal Manager và phát vạch gió theo vận tốc nhân vật.
-- Dựng lại hiệu ứng khi Roblox thay camera để không giữ Attachment đã bị huỷ.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SpeedVFXController = {}

-- Các thông số tinh chỉnh
local MAX_SPEED = 120 -- Tốc độ đạt mật độ vạch gió cao nhất
local MIN_FOV = 70 -- FOV mặc định

-- Vạch tốc độ bay ở đâu so với camera (60 studs phía trước) — cố định, xem vòng RenderStepped.
local ATTACH_OFFSET = Vector3.new(0, 0, -60)

local speedAttachment: Attachment? = nil
local speedParticles: ParticleEmitter? = nil

function SpeedVFXController.SetupVFX()
	if speedAttachment then
		speedAttachment:Destroy()
		speedAttachment = nil
		speedParticles = nil
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	-- 1. Tạo Attachment đặt xa 60 stud ở phía trước Camera
	local attachment = Instance.new("Attachment")
	attachment.Name = "SpeedVFXAttachment"
	attachment.CFrame = CFrame.new(ATTACH_OFFSET)
	attachment.Parent = camera
	speedAttachment = attachment

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
		NumberSequenceKeypoint.new(1, 1),
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

	particle.Parent = attachment
	speedParticles = particle
end

function SpeedVFXController.Start()
	SpeedVFXController.SetupVFX()

	local player = Players.LocalPlayer
	player.CameraMaxZoomDistance = 35
	-- 0.5 = cho zoom vào TẬN góc nhìn thứ nhất (nhập vai avatar). Bản cũ kẹp 5 stud nên
	-- người chơi xoay con lăn hết cỡ vẫn thấy lưng nhân vật — tưởng là bug của Roblox.
	-- ⚠️ Đây là dòng DUY NHẤT trong dự án ghi đè CameraMinZoomDistance; StarterPlayer đã
	-- để 0.5 sẵn, nên sửa ở StarterPlayer thôi là vô ích, controller sẽ đè lại lúc Start().
	player.CameraMinZoomDistance = 0.5

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		local character = player.Character
		if not camera then
			return
		end

		-- Camera cũ bị huỷ cùng con cháu; không thể reparent Attachment của nó.
		if not speedAttachment or speedAttachment.Parent ~= camera then
			SpeedVFXController.SetupVFX()
		end
		-- GHI KHI KHÁC, không ghi mù mỗi frame: Attachment này không bao giờ đổi chỗ (offset
		-- cố định trong không gian camera), nên 60 lượt ghi/giây chỉ để đặt lại đúng giá trị
		-- cũ — mỗi lượt vẫn làm bẩn transform của camera và bắn signal thay đổi.
		if speedAttachment and speedAttachment.Position ~= ATTACH_OFFSET then
			speedAttachment.CFrame = CFrame.new(ATTACH_OFFSET)
		end

		--[[
			Cố định FOV 70 (tắt hiệu ứng zoom màn hình / biến dạng góc nhìn khi chạy), CỘNG thêm
			lượng bù khi có modal đang mở.

			⚠️ Dòng này ghi đè `FieldOfView` MỖI FRAME, nên bất cứ ai muốn đổi FOV đều phải đi
			qua đây — tween thẳng từ chỗ khác sẽ bị xoá ngay frame sau. `ModalFovBoost` là kênh
			cho việc đó (xem hiệu ứng mở modal trong `HUD/Modals/Manager`).
		]]
		local modalFovBoost = tonumber(Workspace:GetAttribute("ModalFovBoost")) or 0
		local wantFov = MIN_FOV + modalFovBoost
		-- Cũng chỉ ghi khi lệch. `FieldOfView` là thuộc tính làm hỏng ma trận chiếu: ghi lại
		-- nó mỗi frame buộc engine dựng lại frustum + tính lại culling, và đây là vòng chạy
		-- TRƯỚC bước camera của Roblox mỗi khung hình — chỗ tệ nhất để thêm việc thừa.
		if camera.FieldOfView ~= wantFov then
			camera.FieldOfView = wantFov
		end

		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			if speedParticles then
				speedParticles.Rate = 0
			end
			return
		end

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

	Log.Boot("[SpeedVFX] Camera Max Zoom (35) & Steady FOV Initialized.")
end

return SpeedVFXController
