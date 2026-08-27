--!strict
--[[
	Zone8SweeperService.luau — cánh tay quét Sweeper Arm, Stage 8.

	THAY THẾ script inline `Workspace.Zones.Zone8.Mechanics.SweeperScript` (2026-08-27).

	Kiến trúc (v3, giữ nguyên): đồng hồ tất định, zero-replication. Server KHÔNG dời arm. Góc
	quay suy ra từ `workspace:GetServerTimeNow()` → `Zone8SweeperController` render local,
	server chỉ chạy toán va chạm trên CFrame ẢO.

	===== v5 (2026-08-07) — ĐỘ CHÍNH XÁC =====
	User: "walkspeed cao hoặc gắn aura/trail thì bẫy không giết player". Hai lỗ hổng độc lập:

	1) LẤY MẪU RỜI RẠC. Bản cũ mỗi Heartbeat thử ĐÚNG MỘT lần, tại vị trí hiện tại của người
	   chơi và góc arm hiện tại. Nhưng arm chỉ DÀY 1.5 studs:
	     • người chơi 250 WS đi 4.2 studs/frame — nhảy cách qua cả bề dày arm giữa 2 frame
	     • đầu mút arm (r=70, 135°/s) đi 165 studs/s = 2.75 studs/frame — người ĐỨNG YÊN cũng
	       bị arm quét lọt qua giữa 2 frame khi server tụt xuống 30fps
	   ⇒ Quét cả ĐOẠN đường player đi trong frame, VÀ nội suy góc arm tại đúng thời điểm của
	     từng mẫu (`TrapSweep.segment` lấy số mẫu theo cái lớn hơn giữa hai chuyển động).

	2) CỔNG STAGE BẰNG Touched. Bản cũ đòi ActiveStage/CurrentStage == 8, chỉ được gán khi
	   Stage8Start.Touched nổ. Chạy nhanh thì bước physics nhảy qua hẳn tấm pad ⇒ Touched
	   KHÔNG nổ ⇒ người chơi vào arena mà server coi như không ở stage 8 và KHÔNG BAO GIỜ giết.
	   ⇒ Cổng VỊ TRÍ: ai đang thực sự đứng trong arena đều bị phán xử, bất kể attribute.

	===== v6 (2026-08-27) — BÙ TRỄ MẠNG =====
	Ping thật của game 350–400ms (user đo). `root.Position` là ảnh chụp cách đây một chiều trễ,
	còn `GetServerTimeNow()` là bây giờ ⇒ server phán xử arm-hiện-tại với vị-trí-quá-khứ. Ở
	đầu mút (r=70, ω=2.36 rad/s), 195ms trễ = **32 studs** lệch, trong khi arm dày có 1.5.
	Ở mức đó phép phán xử gần như ngẫu nhiên: né sạch vẫn chết, chạy xuyên qua lại không sao.
	⇒ Dựng arm tại `now - LagComp.Delay(player)`. Xem Shared/Util/LagComp.

	⚠️ Hệ quả: truy vấn hộp giờ chạy THEO TỪNG NGƯỜI thay vì một lần chung, vì mỗi người có
	một độ trễ khác nhau nên arm của họ ở một góc khác nhau. Đắt hơn, nhưng arena hiếm khi có
	quá vài người và filter chỉ gồm đúng một nhân vật. Giữ truy vấn hộp (không thay bằng phép
	thử điểm) vì nó là thứ DUY NHẤT thấy tay/chân thò ra ngoài tầm root.

	===== v7 (2026-08-27) — VÀO GIT =====
	Chuyển sang service Rojo. Bỏ handler `Stage8Start.Touched` gán ActiveStage/CurrentStage:
	`StageCheckpointService` đã sở hữu việc đó (có cả kiểm tra khoảng cách và vòng dò theo vị
	trí cho walkspeed cao), bản inline chỉ là bản sao thô ghi đè thẳng attribute.

	KHÔNG đụng DEG_PER_SEC/kích thước arm ⇒ độ khó và gate tốc độ của zone giữ nguyên.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Bộ quét RIÊNG của bẫy này. KHÔNG dùng chung với bẫy khác: mỗi bẫy đều reset() những player
-- ngoài vùng của nó mỗi frame, chung bảng là xoá dấu vết của nhau => đoạn quét luôn rỗng và
-- swept âm thầm thoái hoá về đúng phép thử điểm mà nó đang chữa.
local TrapSweep = require(ReplicatedStorage.Shared.Util.TrapSweep).new("Zone8Sweeper")
local LagComp = require(ReplicatedStorage.Shared.Util.LagComp)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone8SweeperService = {}

local DEG_PER_SEC = 135
local KILL_CD = 0.5
local ARENA_RADIUS = 78
local ARENA_RADIUS_SQ = ARENA_RADIUS * ARENA_RADIUS

local BODY_HALF_WIDTH = 1.5
local BODY_HALF_HEIGHT = 2.5
local SWEEP_STEP = 1.0
local RAD_PER_SEC = math.rad(DEG_PER_SEC)
local RESOLVE_RETRY = 1

local BODY = {
	HumanoidRootPart = true,
	Head = true,
	Torso = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftArm = true,
	RightArm = true,
	LeftLeg = true,
	RightLeg = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local arm: BasePart? = nil
local center = Vector3.zero
local baseRot = CFrame.identity
local armSize = Vector3.zero
local armHalf = Vector3.zero

local lastKill: { [Player]: number } = {}

-- ===== Zero-GC scratch =====
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = false
local oneCharacter: { Instance } = { nil :: any }
local inArena: { Player } = {}

local function armCFrameAt(now: number): CFrame
	local angle = -(now * RAD_PER_SEC) % (math.pi * 2)
	return CFrame.new(center) * CFrame.Angles(0, angle, 0) * baseRot
end

local function playerFromPart(part: BasePart): (Player?, Humanoid?)
	if not BODY[part.Name] then
		return nil, nil
	end
	local character = part:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return Players:GetPlayerFromCharacter(character), humanoid
end

local function kill(player: Player, humanoid: Humanoid)
	local now = os.clock()
	if now - (lastKill[player] or 0) < KILL_CD then
		return
	end
	lastKill[player] = now
	humanoid.Health = 0
	TrapSweep.reset(player)
end

local function pointInArm(cf: CFrame, pos: Vector3): boolean
	local lp = cf:PointToObjectSpace(pos)
	return math.abs(lp.X) <= armHalf.X + BODY_HALF_WIDTH
		and math.abs(lp.Y) <= armHalf.Y + BODY_HALF_HEIGHT
		and math.abs(lp.Z) <= armHalf.Z + BODY_HALF_WIDTH
end

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone8 = zones and zones:FindFirstChild("Zone8")
	local mechanics = zone8 and zone8:FindFirstChild("Mechanics")
	local ground = zone8 and zone8:FindFirstChild("Ground")
	local arenaFloor = ground and ground:FindFirstChild("ArenaFloor")
	local sweeperArm = mechanics and mechanics:FindFirstChild("SweeperArm")
	if not zone8 or not arenaFloor or not arenaFloor:IsA("BasePart") then
		return false
	end
	if not sweeperArm or not sweeperArm:IsA("BasePart") then
		return false
	end

	arm = sweeperArm
	sweeperArm.Anchored = true
	sweeperArm.Size = Vector3.new(140, 18, 1.5)
	sweeperArm.Material = Enum.Material.Neon
	sweeperArm.Color = Color3.fromRGB(255, 67, 67)
	-- Server không dời arm; client mới vẽ. Part gây sát thương thì BẮT BUỘC tắt va chạm/truy
	-- vấn, nếu không vị trí physics phía server sẽ lệch với hình client thấy.
	sweeperArm.CanCollide = false
	sweeperArm.CanTouch = false
	sweeperArm.CanQuery = false

	center = Vector3.new(arenaFloor.Position.X, sweeperArm.Position.Y, arenaFloor.Position.Z)
	baseRot = sweeperArm.CFrame.Rotation
	armSize = sweeperArm.Size
	armHalf = armSize * 0.5

	-- Hợp đồng với Zone8SweeperController.
	zone8:SetAttribute("SweepDegPerSec", DEG_PER_SEC)
	zone8:SetAttribute("SweepCenter", center)
	sweeperArm:SetAttribute("Zone8Arm", true)
	return true
end

local function tick(dt: number)
	local sweeperArm = arm
	if not sweeperArm then
		return
	end
	if not sweeperArm:IsDescendantOf(Workspace) then
		arm = nil
		return
	end

	table.clear(inArena)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local dx, dz = root.Position.X - center.X, root.Position.Z - center.Z
			if dx * dx + dz * dz <= ARENA_RADIUS_SQ then
				table.insert(inArena, player)
			else
				TrapSweep.reset(player)
			end
		end
	end
	if #inArena == 0 then
		return -- SLEEP: arena trống
	end

	local now = Workspace:GetServerTimeNow()

	for _, player in inArena do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			--[[
				BÙ TRỄ (v6): `root.Position` là ảnh chụp cách đây `delay` giây, nên phải so với
				arm của `now - delay` — đúng khung hình người chơi đã nhìn thấy khi họ ở đó.
			]]
			local tEnd = now - LagComp.Delay(player)
			local tStart = tEnd - dt

			-- (a) Truy vấn hộp tại thời điểm đã bù. Đây là thứ DUY NHẤT thấy tay/chân thò ra
			--     ngoài tầm root và tư thế ragdoll — phép thử giải tích bên dưới chỉ thấy root.
			--     Chạy theo TỪNG người vì mỗi người có một độ trễ, tức một góc arm khác nhau.
			oneCharacter[1] = character :: Instance
			params.FilterDescendantsInstances = oneCharacter
			local killed = false
			for _, overlap in Workspace:GetPartBoundsInBox(armCFrameAt(tEnd), armSize, params) do
				local hitPlayer, hitHumanoid = playerFromPart(overlap)
				if hitPlayer == player and hitHumanoid then
					kill(player, hitHumanoid)
					killed = true
					break
				end
			end

			-- (b) Quét SWEPT: đoạn đường người chơi đi trong frame so với arm nội suy tại đúng
			--     thời điểm của từng mẫu. Số mẫu lấy theo bên nào đi nhanh hơn.
			if not killed then
				local pos = root.Position
				local dx, dz = pos.X - center.X, pos.Z - center.Z
				local radius = math.sqrt(dx * dx + dz * dz)
				local armTravel = RAD_PER_SEC * radius * dt

				local from, steps = TrapSweep.segment(player, pos, SWEEP_STEP, armTravel)
				local delta = pos - from
				for i = 0, steps do
					local alpha = i / steps
					if pointInArm(armCFrameAt(tStart + dt * alpha), from + delta * alpha) then
						kill(player, humanoid)
						break
					end
				end
			end
		end
	end
end

function Zone8SweeperService.Init() end

function Zone8SweeperService.Start()
	task.spawn(function()
		while not resolve() do
			task.wait(RESOLVE_RETRY)
		end
		RunService.Heartbeat:Connect(tick)
		Log.Boot(`[Zone8SweeperService] arm {DEG_PER_SEC}°/s — client render, server phán xử swept + bù trễ`)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKill[player] = nil
	end)
end

return Zone8SweeperService
