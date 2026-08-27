--!strict
--[[
	Zone7JellyBridgeService.luau — cầu jelly SẬP THEO SÓNG ĐUỔI SAU LƯNG, Stage 7.

	THAY THẾ script inline `Workspace.Zones.Zone7.Zone7JellyBridgeScript` (2026-08-27).
	Cơ chế giữ NGUYÊN 100% — chỉ đổi chỗ ở để Rojo/git quản lý được.

	Server chỉ toggle attribute `State` + `CanCollide` trên từng segment; phần nhìn (rung, rơi,
	xoay) do `Zone7JellyBridgeController` phía client vẽ.

	── VÌ SAO SÓNG ĐUỔI CHỨ KHÔNG PHẢI SÓNG LAN (v3, 2026-07-27) ───────────────────────────
	v2 cho sóng lan từ đầu cầu tới cuối rồi mỗi segment TỰ HỒI sau 1.23s. Người chạy CHẬM tụt
	lại phía sau sóng ⇒ luôn giẫm lên segment đã hồi phục ⇒ CÀNG CHẬM CÀNG AN TOÀN. Đúng ngược
	với ý đồ "phải đạt Bảng Chỉ Số mới qua được".

	v3: sóng sinh ra NGAY SAU LƯNG người chạy và đuổi theo với `WAVE_SPEED`. Segment bị nuốt
	thì SẬP VÀ Ở YÊN cho tới hết đợt — không có sàn để lùi lại. Chạy đủ nhanh thì giữ được
	khoảng cách và về đích; chậm hơn thì bị nuốt giữa cầu.
	    an toàn ⇔ BRIDGE_LEN / ws < (BRIDGE_LEN + GRACE) / WAVE_SPEED
	    300 studs, WAVE_SPEED 118, GRACE 35 ⇒ ngưỡng = 105.7 ≈ đúng Bảng Chỉ Số Stage 7 (106).

	⚠️ Đợt sóng phải chạy TRỌN rồi mới dừng. Cắt giữa chừng để segment kẹt ở "fall" = mất sàn
	vĩnh viễn.

	── VÌ SAO KHÔNG CẦN BÙ TRỄ MẠNG (LagComp) ──────────────────────────────────────────────
	Bẫy này không giết ai. Nó chỉ tắt `CanCollide`, và việc "rơi hay không" do CHÍNH client mô
	phỏng (client là network owner của nhân vật). Không có phép phán xử nào so vị-trí-quá-khứ
	với bẫy-hiện-tại, nên không có gì để bù. Khác hẳn Zone 8/9/11.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone7JellyBridgeService = {}

local MIN_WS = 106 -- Bảng Chỉ Số Stage 7 (chỉ để log)
local WAVE_SPEED = 118 -- studs/s sóng đuổi — hiệu chỉnh để ngưỡng sống sót = 106 WS
local GRACE = 35 -- sóng sinh ra cách sau lưng người chạy chừng này (studs)
local WARN_LEAD = 22 -- segment trong tầm này trước mặt sóng thì chớp cảnh báo
local WAVE_GAP = 0.6 -- nghỉ trước khi cho phép đợt kế tiếp
local MOVE_SPEED_MIN = 6 -- studs/s: dưới mức này coi như đứng yên → không kích hoạt
local IDLE_POLL = 0.15 -- nhịp kiểm tra khi cầu đang ngủ
local RESOLVE_RETRY = 1

local PAD = 4
local Y_UP, Y_DOWN = 14, 4

local segments: { BasePart } = {}
local minX, maxX = math.huge, -math.huge
local minZ, maxZ = math.huge, -math.huge
local topY = -math.huge

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone7 = zones and zones:FindFirstChild("Zone7")
	local mechanics = zone7 and zone7:FindFirstChild("Mechanics")
	local folder = mechanics and mechanics:FindFirstChild("JellyBridge")
	if not folder then
		return false
	end

	table.clear(segments)
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(segments, child)
		end
	end
	if #segments == 0 then
		return false
	end
	table.sort(segments, function(a, b)
		return a.Position.Z < b.Position.Z
	end)

	-- Hộp bao mặt cầu SUY TỪ CHÍNH SEGMENT (kéo/thêm segment trong Studio là tự cập nhật —
	-- đừng thay bằng toạ độ viết cứng).
	minX, maxX = math.huge, -math.huge
	minZ, maxZ = math.huge, -math.huge
	topY = -math.huge
	for _, seg in segments do
		minX = math.min(minX, seg.Position.X - seg.Size.X * 0.5)
		maxX = math.max(maxX, seg.Position.X + seg.Size.X * 0.5)
		minZ = math.min(minZ, seg.Position.Z - seg.Size.Z * 0.5)
		maxZ = math.max(maxZ, seg.Position.Z + seg.Size.Z * 0.5)
		topY = math.max(topY, seg.Position.Y + seg.Size.Y * 0.5)
	end
	return true
end

-- Ai đang ở trên mặt cầu? Trả về Z NHỎ NHẤT trong số người đang DI CHUYỂN (nil = không ai).
local function rearRunnerZ(): number?
	local rear: number? = nil
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
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
					if rear == nil or p.Z < rear then
						rear = p.Z
					end
				end
			end
		end
	end
	return rear
end

local function setState(seg: BasePart, state: string, collide: boolean)
	if seg:GetAttribute("State") ~= state then
		seg:SetAttribute("State", state)
	end
	if seg.CanCollide ~= collide then
		seg.CanCollide = collide
	end
end

-- trạng thái nghỉ: mọi segment đứng vững
local function resetAll()
	for _, seg in segments do
		seg.CanCollide = true
		if seg:GetAttribute("State") ~= "up" then
			seg:SetAttribute("State", "up")
		end
	end
end

local function run()
	resetAll()
	Log.Boot(
		("[Zone7JellyBridgeService] %d segment — sóng ĐUỔI %d studs/s, ân huệ %d studs (ngưỡng sống sót ~%d WS, Bảng %d)"):format(
			#segments,
			WAVE_SPEED,
			GRACE,
			math.floor((maxZ - minZ) * WAVE_SPEED / (maxZ - minZ + GRACE)),
			MIN_WS
		)
	)

	while true do
		-- NGỦ tới khi có người chạy trên cầu. Zone trống thì đứng yên: đỡ rối mắt khi nhìn từ
		-- zone khác, và tốn 0 chi phí.
		local rear = rearRunnerZ()
		while rear == nil do
			task.wait(IDLE_POLL)
			rear = rearRunnerZ()
		end

		-- Sóng sinh ngay sau lưng người ở xa nhất về phía sau, rồi đuổi tới cuối cầu.
		-- KHÔNG BAO GIỜ lùi: đứng lại đợi cũng không cứu được, phải chạy.
		local waveZ = math.max(rear - GRACE, minZ - GRACE)
		while waveZ < maxZ + WARN_LEAD do
			local dt = RunService.Heartbeat:Wait()
			waveZ += WAVE_SPEED * dt
			for _, seg in segments do
				local z = seg.Position.Z
				if z <= waveZ then
					setState(seg, "fall", false)
				elseif z <= waveZ + WARN_LEAD then
					setState(seg, "warn", true)
				end
			end
		end

		-- Hết đợt: dựng lại TOÀN BỘ cầu rồi mới cho đợt kế tiếp.
		resetAll()
		task.wait(WAVE_GAP)
	end
end

function Zone7JellyBridgeService.Init() end

function Zone7JellyBridgeService.Start()
	task.spawn(function()
		while not resolve() do
			task.wait(RESOLVE_RETRY)
		end
		run()
	end)
end

return Zone7JellyBridgeService
