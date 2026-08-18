--!strict
--[[
	Zone8 SweeperScript — Sweeper Arm (v5: swept collision)
	Đặt trực tiếp làm con của Workspace.Zones.Zone8.Mechanics (Script chạy trên Server).
	(Bản gốc để version-control; bản chạy nằm trong .rbxlx do map không được Rojo sync.)

	v3: deterministic clock, zero-replication. Server KHÔNG di chuyển arm. Góc quay suy ra
	từ workspace:GetServerTimeNow() → client render local 60Hz, server chỉ chạy toán va chạm
	trên CFrame ảo. Zero GC, early-out khi zone trống.

	===== v5 (2026-08-07) — ĐỘ CHÍNH XÁC =====
	User: "walkspeed cao hoặc gắn aura/trail thì bẫy không giết player". Hai lỗ hổng độc lập,
	sửa cả hai:

	1) LẤY MẪU RỜI RẠC (thủng theo tốc độ). Bản cũ mỗi Heartbeat thử ĐÚNG MỘT lần, tại vị trí
	   hiện tại của người chơi và góc arm hiện tại. Nhưng arm chỉ DÀY 1.5 studs:
	     • người chơi 250 WS đi 4.2 studs/frame — nhảy cách qua cả bề dày arm giữa 2 frame
	     • đầu mút arm (r=70, 135°/s) đi 165 studs/s = 2.75 studs/frame — người ĐỨNG YÊN
	       cũng bị arm quét qua lọt giữa 2 frame khi server tụt xuống 30fps
	   Aura/trail render client-side nên server không thấy thêm part nào; cái chúng làm là hạ
	   FPS client — mà client là network owner của nhân vật — nên mỗi bước vị trí replicate về
	   server dài hơn: cùng lỗi này, nặng hơn.
	   ⇒ Quét cả ĐOẠN đường player đi trong frame, VÀ nội suy góc arm tại đúng thời điểm của
	     từng mẫu (TrapSweep.segment lấy số mẫu theo cái lớn hơn giữa hai chuyển động).

	2) CỔNG STAGE BẰNG Touched (thủng hoàn toàn). Bản cũ đòi ActiveStage/CurrentStage == 8,
	   chỉ được gán khi Stage8Start.Touched nổ. Chạy nhanh (hoặc FPS thấp vì aura) thì bước
	   physics nhảy qua hẳn tấm pad mỏng ⇒ Touched KHÔNG nổ ⇒ người chơi vào arena mà server
	   coi như không ở stage 8 và KHÔNG BAO GIỜ giết. Đây là lý do bẫy "im hẳn" chứ không phải
	   thỉnh thoảng hụt.
	   ⇒ Thêm cổng VỊ TRÍ: ai đang thực sự đứng trong arena đều bị phán xử, bất kể attribute.
	     (Zone 11 vốn đã làm thế và không nằm trong danh sách user báo lỗi — đúng theo dự đoán.)

	KHÔNG đụng DEG_PER_SEC/kích thước arm ⇒ độ khó và gate tốc độ của zone giữ nguyên.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Bộ quét RIÊNG của bẫy này. KHÔNG dùng chung với bẫy khác: mỗi bẫy đều reset()
-- những player ngoài vùng của nó mỗi frame, chung bảng là xoá dấu vết của nhau
-- => đoạn quét luôn rỗng và swept thoái hoá về đúng phép thử điểm nó đang chữa.
local TrapSweep = require(ReplicatedStorage:WaitForChild("Shared").Util.TrapSweep).new("Zone8Sweeper")

local mech = script.Parent
local zone = mech.Parent
local ground = zone:FindFirstChild("Ground")
local arenaFloor = ground and ground:FindFirstChild("ArenaFloor")
local arm = mech:FindFirstChild("SweeperArm")
local stageStart = mech:FindFirstChild("Stage8Start")

local STAGE = 8
-- v4 (2026-07-27): 135°/s ⇒ cửa sổ an toàn 1.33s giữa hai lần arm quét. Arm dài 140 đi qua
-- tâm nên mỗi nửa vòng quét một lần ⇒ cửa sổ = 180/DEG_PER_SEC. Player phải vượt vùng nguy
-- hiểm ~140 studs: đủ Bảng Chỉ Số (122 WS) mất 1.15s · chậm 20% (98 WS) mất 1.43s.
-- Đủ chuẩn thì lọt qua, thiếu chuẩn bị arm bắt giữa đường.
local DEG_PER_SEC = 135
local KILL_CD = 0.5
local ARENA_RADIUS = 78

-- Hộp thân người quy ước quanh HumanoidRootPart (dùng cho các mẫu swept giữa 2 frame).
local BODY_HALF_WIDTH = 1.5
local BODY_HALF_HEIGHT = 2.5
-- Bước rải mẫu = nửa cửa sổ mỏng nhất (arm dày 1.5 ⇒ halfThick 0.75, + thân 1.5 = 2.25).
local SWEEP_STEP = 1.0

if not arenaFloor or not arm or not arm:IsA("BasePart") then
	warn("[Zone8] ArenaFloor/SweeperArm missing")
	return
end

local BODY = {
	HumanoidRootPart = true, Head = true, Torso = true, UpperTorso = true, LowerTorso = true,
	LeftArm = true, RightArm = true, LeftLeg = true, RightLeg = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

arm.Anchored = true
arm.Size = Vector3.new(140, 18, 1.5)
arm.Material = Enum.Material.Neon
arm.Color = Color3.fromRGB(255, 67, 67)
-- Server không move part -> tắt collide/touch để client render local không lệch physics.
-- Sát thương do toán va chạm dưới đây quyết định (anti-cheat vẫn server-authoritative).
arm.CanCollide = false
arm.CanTouch = false
arm.CanQuery = false

local center = Vector3.new(arenaFloor.Position.X, arm.Position.Y, arenaFloor.Position.Z)
local baseRot = arm.CFrame.Rotation
local armSize = arm.Size
local armHalf = armSize * 0.5

-- Hợp đồng chia sẻ với client: cùng công thức, cùng đồng hồ server.
zone:SetAttribute("SweepDegPerSec", DEG_PER_SEC)
zone:SetAttribute("SweepCenter", center)
arm:SetAttribute("Zone8Arm", true)

local RAD_PER_SEC = math.rad(DEG_PER_SEC)
local function armCFrameAt(now: number): CFrame
	local angle = -(now * RAD_PER_SEC) % (math.pi * 2)
	return CFrame.new(center) * CFrame.Angles(0, angle, 0) * baseRot
end

-- ===== Zero-GC scratch =====
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = false
local charBuffer: { Instance } = {}
local lastKill: { [Player]: number } = {}

local function playerFromPart(part: BasePart): (Player?, Humanoid?)
	if not BODY[part.Name] then return nil, nil end
	local c = part:FindFirstAncestorOfClass("Model")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return nil, nil end
	return Players:GetPlayerFromCharacter(c), h
end

local function kill(plr: Player, h: Humanoid)
	local now = os.clock()
	if now - (lastKill[plr] or 0) < KILL_CD then return end
	lastKill[plr] = now
	h.Health = 0
	TrapSweep.reset(plr) -- đoạn kế tiếp không được nối từ chỗ chết sang chỗ respawn
end

if stageStart then
	stageStart.Touched:Connect(function(hit)
		local plr = (playerFromPart(hit))
		if plr then
			plr:SetAttribute("ActiveStage", STAGE)
			plr:SetAttribute("CurrentStage", STAGE)
		end
	end)
end

-- Điểm `pos` (tâm thân người) có nằm trong khối arm tại CFrame `cf` không?
local function pointInArm(cf: CFrame, pos: Vector3): boolean
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) <= armHalf.X + BODY_HALF_WIDTH
		and math.abs(lp.Y) <= armHalf.Y + BODY_HALF_HEIGHT
		and math.abs(lp.Z) <= armHalf.Z + BODY_HALF_WIDTH
end

RunService.Heartbeat:Connect(function(dt)
	-- Early-out guard: gom character đang thực sự ở trong arena stage 8.
	-- CỔNG VỊ TRÍ (v5): ở trong arena là đủ — KHÔNG còn bắt buộc có attribute stage, vì
	-- Stage8Start.Touched có thể bị bước physics nhảy qua khi chạy nhanh/FPS thấp.
	table.clear(charBuffer)
	local n = 0
	local inArena: { Player } = {}
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r and r:IsA("BasePart") then
			local dx, dz = r.Position.X - center.X, r.Position.Z - center.Z
			if dx * dx + dz * dz <= ARENA_RADIUS * ARENA_RADIUS then
				n += 1
				charBuffer[n] = c :: Instance
				table.insert(inArena, plr)
			else
				TrapSweep.reset(plr) -- ngoài arena: cắt dấu vết, khỏi quét đoạn dài vô nghĩa
			end
		end
	end
	if n == 0 then return end -- SLEEP: không ai trong zone -> 0 công việc

	local now = Workspace:GetServerTimeNow()
	local prevT = now - dt

	-- (a) Kiểm tra chính xác theo TƯ THẾ đầy đủ tại thời điểm hiện tại — như bản cũ.
	params.FilterDescendantsInstances = charBuffer
	local cfNow = armCFrameAt(now)
	for _, overlap in Workspace:GetPartBoundsInBox(cfNow, armSize, params) do
		local plr, h = playerFromPart(overlap)
		if plr and h then kill(plr, h) end
	end

	-- (b) SWEPT: lấp khoảng trống GIỮA hai frame — cả đường đi của người chơi lẫn của arm.
	for _, plr in inArena do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r and r:IsA("BasePart") then
			local pos = r.Position
			-- quãng đường đầu mút arm đi trong frame này, đo tại BÁN KÍNH của người chơi
			local dx, dz = pos.X - center.X, pos.Z - center.Z
			local radius = math.sqrt(dx * dx + dz * dz)
			local armTravel = RAD_PER_SEC * radius * dt

			local from, steps = TrapSweep.segment(plr, pos, SWEEP_STEP, armTravel)
			local delta = pos - from
			for i = 0, steps - 1 do -- alpha = 1 đã do nhánh (a) lo
				local alpha = i / steps
				if pointInArm(armCFrameAt(prevT + (now - prevT) * alpha), from + delta * alpha) then
					kill(plr, h)
					break
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastKill[plr] = nil
end)
