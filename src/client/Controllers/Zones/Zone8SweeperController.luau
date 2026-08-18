--!strict
--[[
	Zone8SweeperController.luau — render local cánh tay quét Stage 8.

	Server không còn move SweeperArm (xem Workspace.Zones.Zone8.Mechanics.SweeperScript):
	góc quay suy ra từ workspace:GetServerTimeNow() nên client tự dựng lại y hệt
	→ 0 byte CFrame replication, 60 FPS mượt, không micro-stutter.

	Zero-GC: không tạo bảng/Vector3/CFrame tạm ngoài phép toán bắt buộc mỗi frame.
	Early-out: ra khỏi tầm nhìn (RENDER_RADIUS) là ngừng cập nhật.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ZoneLod = require(script.Parent.ZoneLod)

-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed — xem ZoneLod.
local RENDER_RADIUS = 320

local Zone8SweeperController = {}

local player = Players.LocalPlayer
local arm: BasePart? = nil
local center = Vector3.zero
local baseRot = CFrame.identity
local radPerSec = 0
local ready = false
local nextFarStep = 0
local connection: RBXScriptConnection? = nil

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone8")
	local mech = zone and zone:FindFirstChild("Mechanics")
	local found = mech and mech:FindFirstChild("SweeperArm")
	if not (zone and found and found:IsA("BasePart")) then
		return false
	end

	local degPerSec = zone:GetAttribute("SweepDegPerSec")
	local storedCenter = zone:GetAttribute("SweepCenter")
	if typeof(degPerSec) ~= "number" or typeof(storedCenter) ~= "Vector3" then
		return false
	end

	arm = found
	center = storedCenter
	baseRot = found.CFrame.Rotation
	radPerSec = math.rad(degPerSec)
	return true
end

local function step()
	local part = arm
	-- StreamingEnabled=true: zone có thể bị dỡ khi người chơi đi xa.
	-- Mất tham chiếu -> đánh dấu resolve lại thay vì chết vĩnh viễn.
	if not part or not part:IsDescendantOf(Workspace) then
		arm = nil
		ready = false
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local dx = root.Position.X - center.X
	local dz = root.Position.Z - center.Z
	local distSq = dx * dx + dz * dz
	if distSq > ZoneLod.RadiusSq(RENDER_RADIUS) then
		return -- SLEEP: quá xa, không cần render
	end

	local now = Workspace:GetServerTimeNow()
	local shouldStep: boolean
	shouldStep, nextFarStep = ZoneLod.ShouldStepFar(distSq, now, nextFarStep)
	if not shouldStep then
		return
	end

	local angle = -(now * radPerSec) % (math.pi * 2)
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, angle, 0) * baseRot
end

function Zone8SweeperController.Start()
	connection = RunService.RenderStepped:Connect(step)
	task.spawn(function()
		-- Zone/attribute do server inline script dựng lúc runtime, và streaming có thể
		-- dỡ/nạp lại zone bất cứ lúc nào → poll nhẹ 0.5s để bám lại tham chiếu.
		while true do
			if not ready then
				ready = resolve()
			end
			task.wait(0.5)
		end
	end)
end

function Zone8SweeperController.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Zone8SweeperController
