--!strict
--[[
	Zone2LaserService.luau — Server cho dàn laser quét Stage 2.

	THAY THẾ script inline Zone2LaserScript (xoay Pivot mỗi Heartbeat → replicate CFrame liên
	tục) + các Touched-kill trên từng beam.

	Mô hình mới "render ở client, phán xử ở server":
	  • Server KHÔNG xoay Pivot. Chỉ chuẩn hoá part (anchor pivot, tắt Touch beam), ghi rpm/dir
	    lên model rồi bật cờ LasersReady cho client dựng.
	  • Sát thương phân xử mỗi Heartbeat: tính góc ảo từ đồng hồ, dựng lại đoạn thẳng của từng
	    beam và kiểm tra người chơi nằm trong hộp beam. Không dùng Touched → 0 chi phí va chạm
	    engine. (Bản đầu chạy 20Hz + thử điểm; xem khối "ĐỘ CHÍNH XÁC v3" bên dưới.)
	  • Mỗi player thoát sớm bằng 1 phép so hộp bao dàn laser (đa số người không ở Stage 2).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
-- Bộ quét RIÊNG của Zone 2. Không dùng chung với bẫy khác: mỗi bẫy đều reset() những
-- player ngoài vùng của nó mỗi frame, chung bảng là xoá dấu vết của nhau (xem TrapSweep).
local sweep = require(ReplicatedStorage.Shared.Util.TrapSweep).new("Zone2Laser")
local Zone2Lasers = require(ReplicatedStorage.Shared.Config.Zones.Zone2Lasers)
local LagComp = require(ReplicatedStorage.Shared.Util.LagComp)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone2LaserService = {}

-- ĐỘ CHÍNH XÁC (2026-08-07) — user: "walkspeed cao hoặc gắn aura/trail thì laser không giết".
-- Nguyên nhân đo được: bản cũ phán xử ở 20Hz và chỉ thử ĐIỂM tại vị trí hiện tại. Ở 250 WS
-- người chơi đi 12.5 studs giữa hai lần thử, trong khi beam chỉ dày ~3 studs (halfThick +
-- BODY_HALF_WIDTH) ⇒ chưa chạm ở lần thử này, đã qua hẳn ở lần sau: không lần nào thấy trùng.
-- Aura/trail render client-side nên server không thấy thêm part nào; cái chúng làm là hạ FPS
-- của client — mà client là network owner của nhân vật — nên mỗi bước vị trí replicate về
-- server dài hơn, tức đúng lỗi trên nhưng nặng hơn.
--
-- Chữa bằng 2 việc, KHÔNG đụng tới hình học/nhịp quay nên độ khó của zone không đổi:
--   1) Chạy trên Heartbeat thay vì 20Hz.
--   2) Quét cả ĐOẠN đường player vừa đi trong frame (TrapSweep), và tại mỗi mẫu dựng lại
--      góc laser ĐÚNG thời điểm đó — beam cũng đang quay, so với góc cuối frame là lệch.
local KILL_COOLDOWN = 0.85
-- Bước rải mẫu: nửa bề dày mỏng nhất của một beam. Beam mỏng nhất trong Zone 2 dày 1.4
-- studs (halfThick 0.7) + thân người 1.5 ⇒ cửa sổ 2.2; lấy 1.0 cho chắc tay.
local SWEEP_STEP = 1.0
local BODY_HALF_HEIGHT = 2.5 -- nửa thân người
local BODY_HALF_WIDTH = 1.5
local WAKE_PAD = 40

--[[
	── ĐỘ CHÍNH XÁC v3 (2026-08-27) — BÙ TRỄ MẠNG + BEAM TỰ QUÉT ────────────────────────────
	User: "laser Zone 2 không chính xác, cảm giác lag server". Ping đo được 390ms (PC) /
	350ms (iPhone 13). Ở mức đó, v2 ở trên còn hở đúng hai chỗ, và cả hai đều là lỗi
	NGUYÊN TẮC chứ không phải chỉnh số:

	1) SO LỆCH THỜI GIAN. `root.Position` là ảnh chụp cách đây một chiều trễ mạng (client là
	   network owner), còn `GetServerTimeNow()` là bây giờ. Server đang so vị-trí-quá-khứ với
	   laser-hiện-tại. Ở 195ms một chiều và ω = 2.93 rad/s (rpm 28 cũ), laser server dùng để
	   phán xử lệch 0.57 rad so với laser người chơi nhìn thấy — tại bán kính 30 là **17
	   studs**, trong khi cửa sổ trúng rộng 4.5 studs. Hai cái laser khác hẳn nhau.
	   ⇒ Lùi đồng hồ laser về `now - LagComp.Delay(player)`. Xem Shared/Util/LagComp.

	2) BEAM CŨNG LÀ BÊN ĐI NHANH. v2 dùng `sweep.forEachStep`, mà hàm đó suy số mẫu CHỈ từ
	   quãng đường NGƯỜI CHƠI đi. Người đứng yên ⇒ đúng 1 mẫu/frame ⇒ thoái hoá về phép thử
	   điểm theo thời gian: beam quét qua giữa hai frame là không ai thấy. Đây chính xác là
	   lỗi mà `TrapSweep.segment` (Zone 8 cánh tay, Zone 10 khối lava) sinh ra để chữa, Zone 2
	   bị bỏ sót.
	   ⇒ Đổi sang `sweep.segment` với `trapTravel` = quãng beam quét TẠI BÁN KÍNH CỦA NGƯỜI
	     CHƠI (`r × ω × dt`) — không phải ở đầu mút, nếu không người đứng sát trục sẽ bị rải
	     thừa hàng chục mẫu vô ích.

	Hai việc này KHÔNG đổi hình học/nhịp quay, nên độ khó không đổi (phần hạ tốc nằm ở
	Shared/Config/Zones/Zone2Lasers).
]]
type Beam = { relCF: CFrame, halfLen: number, halfThick: number, halfHeight: number }
type Laser = {
	pivot: BasePart,
	base: CFrame,
	rpm: number,
	dir: number,
	beams: { Beam },
	-- Bán kính lớn nhất beam với tới. Kẹp trần cho `trapTravel`: ngoài mút beam thì dù người
	-- chơi đứng xa bao nhiêu, beam cũng không quét qua họ nhanh hơn ở đầu mút.
	maxRadius: number,
	omega: number,
}

local lasers: { Laser } = {}
local lastKill: { [Player]: number } = {}
local wakeMinX, wakeMaxX, wakeMinZ, wakeMaxZ = 0, 0, 0, 0
local ready = false

local function getNumberAttr(inst: Instance?, name: string, fallback: number): number
	if inst then
		local v = inst:GetAttribute(name)
		if type(v) == "number" then
			return v
		end
	end
	return fallback
end

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(Zone2Lasers.ZoneName)
	local mechanics = zone and zone:FindFirstChild("Mechanics")
	if not zone or not mechanics then
		return false
	end

	table.clear(lasers)
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	for _, model in mechanics:GetChildren() do
		local default = model:IsA("Model") and Zone2Lasers.Defaults[model.Name]
		local pivot = default and model:FindFirstChild("Pivot")
		if default and pivot and pivot:IsA("BasePart") then
			-- Ghi rpm/dir lên model để client đọc (ưu tiên attribute có sẵn trong map).
			local rpm = getNumberAttr(model, "RPM", default.rpm)
			local dir = getNumberAttr(model, "Dir", default.dir)
			model:SetAttribute("RPM", rpm)
			model:SetAttribute("Dir", dir)

			-- Tắt script legacy per-model (nếu còn).
			local legacy = model:FindFirstChildWhichIsA("Script")
			if legacy then
				legacy.Disabled = true
			end

			local base = pivot.CFrame
			pivot.Anchored = true
			-- Client dời pivot cục bộ nên KHÔNG đọc được góc gốc từ pivot.CFrame sau này.
			-- Ghi BaseCF cố định để client re-resolve bao nhiêu lần cũng ra đúng gốc.
			pivot:SetAttribute("BaseCF", base)

			local beams: { Beam } = {}
			local maxRadius = 0
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and Zone2Lasers.IsBeam(part, pivot) then
					part.CanTouch = false
					part.CanQuery = false
					part.CanCollide = false
					local relCF = base:ToObjectSpace(part.CFrame)
					local halfLen = part.Size.X * 0.5
					table.insert(beams, {
						relCF = relCF,
						halfLen = halfLen,
						halfThick = part.Size.Z * 0.5,
						halfHeight = part.Size.Y * 0.5,
					})
					-- Tâm beam có thể lệch khỏi trục (map tự do đặt): cộng cả độ lệch ngang.
					local off = relCF.Position
					maxRadius = math.max(maxRadius, math.sqrt(off.X * off.X + off.Z * off.Z) + halfLen)
				end
			end

			if #beams > 0 then
				table.insert(lasers, {
					pivot = pivot,
					base = base,
					rpm = rpm,
					dir = dir,
					beams = beams,
					maxRadius = maxRadius,
					omega = Zone2Lasers.AngularSpeed(rpm),
				})
				local p = pivot.Position
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
			end
		end
	end

	if #lasers == 0 then
		return false
	end

	wakeMinX, wakeMaxX = minX - WAKE_PAD, maxX + WAKE_PAD
	wakeMinZ, wakeMaxZ = minZ - WAKE_PAD, maxZ + WAKE_PAD
	zone:SetAttribute(Zone2Lasers.ReadyAttribute, true)
	return true
end

local function inWakeBox(pos: Vector3): boolean
	return pos.X >= wakeMinX and pos.X <= wakeMaxX and pos.Z >= wakeMinZ and pos.Z <= wakeMaxZ
end

-- Người chơi có chạm beam nào của laser này tại thời điểm `now` không?
local function hitByLaser(laser: Laser, pos: Vector3, now: number): boolean
	local angle = math.rad(Zone2Lasers.AngleDeg(now, laser.rpm, laser.dir))
	local pivotNow = laser.base * CFrame.Angles(0, angle, 0)
	for i = 1, #laser.beams do
		local beam = laser.beams[i]
		local lp = (pivotNow * beam.relCF):PointToObjectSpace(pos)
		if
			math.abs(lp.X) <= beam.halfLen
			and math.abs(lp.Z) <= beam.halfThick + BODY_HALF_WIDTH
			and math.abs(lp.Y) <= beam.halfHeight + BODY_HALF_HEIGHT
		then
			return true
		end
	end
	return false
end

-- Quãng đường beam quét được trong `dt` TẠI BÁN KÍNH của người chơi (studs).
-- Lấy ở bán kính người chơi chứ không ở đầu mút: người đứng sát trục thì beam gần như không
-- dịch chuyển quanh họ, rải mẫu theo đầu mút là tốn hàng chục mẫu cho không.
local function trapTravel(laser: Laser, pos: Vector3, dt: number): number
	local o = laser.base.Position
	local dx, dz = pos.X - o.X, pos.Z - o.Z
	local r = math.min(math.sqrt(dx * dx + dz * dz), laser.maxRadius)
	return r * laser.omega * dt
end

local function tick(dt: number)
	if not ready or #lasers == 0 then
		return
	end
	if not lasers[1].pivot:IsDescendantOf(Workspace) then
		ready = false
		return
	end

	local now = Workspace:GetServerTimeNow()

	for _, player in Players:GetPlayers() do
		local root = CharacterUtil.GetAliveRoot(player)
		if root and inWakeBox(root.Position) then
			local pos = root.Position

			--[[
				BÙ TRỄ: `pos` là ảnh chụp cách đây `delay` giây, nên phải so với laser của
				`now - delay` — đúng khung hình người chơi đã nhìn thấy khi họ ở đó.
			]]
			local tEnd = now - LagComp.Delay(player)
			local tStart = tEnd - dt

			-- Số mẫu lấy theo bên NÀO đi nhanh hơn: người chơi hay chính beam.
			local travel = 0
			for i = 1, #lasers do
				local v = trapTravel(lasers[i], pos, dt)
				if v > travel then
					travel = v
				end
			end

			local from, steps = sweep.segment(player, pos, SWEEP_STEP, travel)
			local delta = pos - from
			local hit = false
			-- Đi NGƯỢC từ hiện tại về quá khứ: trúng ở đâu cũng đúng, nhưng thứ tự này cho
			-- điểm chết gần chỗ người chơi nhìn thấy nhất khi dừng sớm (khớp forEachStep).
			for i = steps, 0, -1 do
				local alpha = i / steps
				local sp = from + delta * alpha
				local tAt = tStart + dt * alpha
				for j = 1, #lasers do
					if hitByLaser(lasers[j], sp, tAt) then
						hit = true
						break
					end
				end
				if hit then
					break
				end
			end

			if hit then
				local last = lastKill[player] or 0
				if now - last >= KILL_COOLDOWN then
					lastKill[player] = now
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = 0
					end
					-- chết rồi thì đoạn kế tiếp không được nối từ chỗ chết sang chỗ respawn
					sweep.reset(player)
				end
			end
		else
			-- ra khỏi vùng laser: cắt dấu vết để lần vào lại không quét một đoạn dài vô nghĩa
			sweep.reset(player)
		end
	end
end

function Zone2LaserService.Init() end

function Zone2LaserService.Start()
	task.spawn(function()
		while not resolve() do
			task.wait(1)
		end
		ready = true
		Log.Boot(`[Zone2LaserService] {#lasers} laser — render client, phán xử server swept/Heartbeat`)
		RunService.Heartbeat:Connect(tick)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKill[player] = nil
	end)
end

return Zone2LaserService
