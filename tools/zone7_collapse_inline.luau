-- Zone7JellyBridgeScript v2 — cầu sập jelly KÍCH HOẠT THEO NGƯỜI CHƠI.
-- Server chỉ toggle State attr + CanCollide; visual do client Zone7JellyBridgeController.
--
-- BẢN THAM CHIẾU của script inline `Workspace.Zones.Zone7.Zone7JellyBridgeScript`
-- (Rojo không quản Workspace — sửa ở đây thì phải dán lại vào Studio và ngược lại).
-- Bản CrumblingBlocks cũ trong file này đã lỗi thời từ Session 16 (cầu jelly thay hẳn).
--
-- v2 (2026-07-26, yêu cầu user): sóng sập KHÔNG còn chạy vô tận. Cầu chỉ bắt đầu sập khi
-- có người chơi ĐANG DI CHUYỂN trên mặt cầu (sàn ASMR jelly). Không ai trên cầu — hoặc
-- đứng yên — thì mọi segment giữ nguyên "up" (đi qua an toàn, nhìn cũng đỡ rối khi ngắm
-- từ zone khác). Đợt sóng đang chạy luôn được CHẠY HẾT rồi mới dừng, để không có segment
-- nào kẹt ở trạng thái "fall" (mất sàn vĩnh viễn).

local Players = game:GetService("Players")

local folder = script.Parent.Mechanics:WaitForChild("JellyBridge")

local MIN_WS = 106 -- tốc độ tối thiểu theo Bảng yêu cầu vượt ải
local WARN = 0.28 -- cảnh báo (chớp hồng)
local GONE = 0.95 -- thời gian mất sàn
local WAVE_GAP = 0.7 -- nghỉ giữa các đợt sóng
local MOVE_SPEED_MIN = 6 -- studs/s: dưới mức này coi như đứng yên → không kích hoạt
local IDLE_POLL = 0.15 -- nhịp kiểm tra khi cầu đang ngủ

local segs = {}
for _, s in folder:GetChildren() do
	table.insert(segs, s)
end
table.sort(segs, function(a, b)
	return a.Position.Z < b.Position.Z
end)
local SEQUENCE_GAP = 10 / MIN_WS -- sóng lan theo đúng nhịp player chạy chuẩn

-- Hộp bao mặt cầu (suy từ chính segment nên kéo/thêm segment trong Studio là tự cập nhật).
local minX, maxX = math.huge, -math.huge
local minZ, maxZ = math.huge, -math.huge
local topY = -math.huge
for _, s in segs do
	minX = math.min(minX, s.Position.X - s.Size.X * 0.5)
	maxX = math.max(maxX, s.Position.X + s.Size.X * 0.5)
	minZ = math.min(minZ, s.Position.Z - s.Size.Z * 0.5)
	maxZ = math.max(maxZ, s.Position.Z + s.Size.Z * 0.5)
	topY = math.max(topY, s.Position.Y + s.Size.Y * 0.5)
end
local PAD = 4
local Y_UP, Y_DOWN = 14, 4

-- Có ai đang DI CHUYỂN trên mặt cầu không?
local function runnerOnBridge(): boolean
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and hum.Health > 0 and root and root:IsA("BasePart") then
			local p = root.Position
			if
				p.X >= minX - PAD
				and p.X <= maxX + PAD
				and p.Z >= minZ - PAD
				and p.Z <= maxZ + PAD
				and p.Y >= topY - Y_DOWN
				and p.Y <= topY + Y_UP
			then
				local v = root.AssemblyLinearVelocity
				if math.sqrt(v.X * v.X + v.Z * v.Z) >= MOVE_SPEED_MIN then
					return true
				end
			end
		end
	end
	return false
end

local function collapse(seg)
	seg:SetAttribute("State", "warn")
	task.wait(WARN)
	seg.CanCollide = false
	seg:SetAttribute("State", "fall")
	task.wait(GONE)
	seg.CanCollide = true
	seg:SetAttribute("State", "up")
end

-- trạng thái nghỉ: mọi segment đứng vững
local function resetAll()
	for _, seg in segs do
		seg.CanCollide = true
		if seg:GetAttribute("State") ~= "up" then
			seg:SetAttribute("State", "up")
		end
	end
end

resetAll()
print(("[Zone7Bridge] %d segment — chỉ sập khi có người CHẠY trên cầu (>= %d studs/s)"):format(#segs, MOVE_SPEED_MIN))

while true do
	-- NGỦ tới khi có người chạy trên cầu
	while not runnerOnBridge() do
		task.wait(IDLE_POLL)
	end

	-- chạy TRỌN một đợt sóng (không cắt giữa chừng → không segment nào kẹt "fall")
	for _, seg in segs do
		task.spawn(collapse, seg)
		task.wait(SEQUENCE_GAP)
	end
	task.wait(WARN + GONE) -- chờ segment cuối hồi phục

	if runnerOnBridge() then
		task.wait(WAVE_GAP) -- còn người chạy → đợt kế tiếp
	else
		resetAll()
	end
end
