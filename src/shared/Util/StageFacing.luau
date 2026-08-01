--!strict
--[[
	StageFacing.luau — quay mặt người chơi về phía zone phía trước khi teleport/hồi sinh.

	KHÔNG dùng được một phép xoay 180° cứng cho mọi nơi:
	  • Zone 1–9 chạy dọc +Z, các part đều có LookVector = -Z (ngược chiều đi) → cần xoay 180°.
	  • Zone 9–15 chạy dọc +X → xoay 180° từ LookVector -Z sẽ cho +Z, tức LỆCH 90° so với hành lang.
	  • Transition10To11 / 13To14 / 14To15 lại xoay khác 90° so với hàng xóm của chúng.

	Nên hướng được SUY TỪ HÌNH HỌC thay vì từ orientation của part:
	  1. Nhìn từ điểm đáp về phía Stage{N}Start (đúng cho mọi teleport tới cửa zone).
	  2. Nếu điểm đáp CHÍNH LÀ Start (hồi sinh) → nhìn từ Start về Stage{N}Finish.
	  3. Không tìm được part nào → quay về hành vi cũ: xoay 180° so với part đích.
]]

local Workspace = game:GetService("Workspace")

local StageFacing = {}

-- Dưới ngưỡng này coi như hai điểm trùng nhau → hướng không xác định.
local MIN_DIRECTION_STUDS = 5

local function findInZone(stage: number, name: string): BasePart?
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(`Zone{stage}`)
	if not zone then
		return nil
	end
	local part = zone:FindFirstChild(name, true)
	return if part and part:IsA("BasePart") then part :: BasePart else nil
end

-- Chỉ lấy yaw. Zone 10→11 chênh 220 studs độ cao; nếu không phẳng hoá trục Y thì
-- nhân vật sẽ bị đặt ngửa mặt lên trời.
local function flatDirection(from: Vector3, to: Vector3): Vector3?
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if delta.Magnitude < MIN_DIRECTION_STUDS then
		return nil
	end
	return delta.Unit
end

-- CFrame đặt tại `position`, mặt hướng về phía trước của stage `stage`.
function StageFacing.Orient(position: Vector3, stage: number, fallbackCFrame: CFrame): CFrame
	local startPart = findInZone(stage, `Stage{stage}Start`)
	local finishPart = findInZone(stage, `Stage{stage}Finish`)

	local direction: Vector3? = nil
	if startPart then
		direction = flatDirection(position, startPart.Position)
	end
	if not direction and startPart and finishPart then
		direction = flatDirection(startPart.Position, finishPart.Position)
	end
	if not direction and finishPart then
		direction = flatDirection(position, finishPart.Position)
	end

	if not direction then
		warn(`[StageFacing] Không suy được hướng cho Stage {stage} — dùng fallback xoay 180°`)
		local rotationOnly = fallbackCFrame - fallbackCFrame.Position
		return CFrame.new(position) * rotationOnly * CFrame.Angles(0, math.pi, 0)
	end

	return CFrame.lookAt(position, position + direction)
end

return StageFacing
