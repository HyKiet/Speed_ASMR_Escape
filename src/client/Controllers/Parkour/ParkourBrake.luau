--!strict
--[[
	ParkourBrake.luau — ACTIVE BRAKING (phanh chủ động / custom friction).

	Vấn đề: WalkSpeed trong game lên tới 250 studs/s; khi thả phím WASD, Humanoid mặc định
	để nhân vật trượt dài theo quán tính vật lý → cảm giác "trơn băng", khó canh điểm đáp obby.

	Cơ chế: LinearVelocity (chỉ trục X-Z, VectorVelocity = 0) với MaxAxesForce HỮU HẠN
	= khối lượng × BrakeAccel → giảm tốc ĐỀU với gia tốc cấu hình được, thay vì dừng
	cứng tức thì (vẫn giữ chút "trọng lượng" cho game feel). Chỉ kích hoạt khi:
	  • Đang Grounded (state machine) + đứng trên mặt đất thật,
	  • KHÔNG có input di chuyển,
	  • Tốc độ ngang > MinSpeedToBrake.
	Tốc độ tụt dưới StopSpeedThreshold → triệt tiêu hẳn về 0 rồi tắt constraint.

	Không phanh khi trên không → không phá cơ chế văng hợp lệ (Zone 13 spring, wind, nhảy).

	v2 (2026-07-25) — thêm 3 lớp "dễ kiểm soát ở tốc độ cao":
	  • TURN ASSIST: xoay vector vận tốc ngang theo phím khi chạy trên đất → cua gắt @250.
	  • ANTI-FLING: kẹp vận tốc góc (chống xoay tít văng loạn khi va đập).
	  • Phanh ĐỘNG: gia tốc phanh tỉ lệ tốc độ → quãng dừng ổn định mọi WalkSpeed.
	(Chống văng do player khác: CollisionGroupService đã tắt va chạm player-player;
	 ParkourUtil.MakeRaycastParams loại nhân vật khác khỏi blockcast slide.)
]]

local ParkourConfig = require(script.Parent.ParkourConfig)
local ParkourTypes = require(script.Parent.ParkourTypes)
local ParkourUtil = require(script.Parent.ParkourUtil)

type Session = ParkourTypes.Session

local States = ParkourConfig.States

local ParkourBrake = {}

function ParkourBrake.Setup(session: Session)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ParkourBrakeVelocity"
	lv.Attachment0 = session.attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.zero -- set theo khối lượng thật lúc kích hoạt
	lv.VectorVelocity = Vector3.zero
	lv.Enabled = false
	lv.Parent = session.root
	session.brakeVelocity = lv
	session.janitor:Add(lv, "Destroy")
end

local function setBrakeEnabled(session: Session, enabled: boolean)
	local lv = session.brakeVelocity
	if lv.Enabled == enabled then
		return
	end
	if enabled then
		-- Lực = m × a, cập nhật mỗi lần bật (khối lượng đổi khi thay accessory/mount).
		-- Gia tốc ĐỘNG theo tốc độ hiện tại: speed cao phanh gắt tương ứng → quãng trượt
		-- khi thả phím gần như không đổi dù WalkSpeed 20 hay 250.
		local cfg = ParkourConfig.Braking
		local speed = ParkourUtil.HorizontalSpeed(session.root)
		local accel = math.max(cfg.BrakeAccel, speed * (cfg.BrakeAccelPerSpeed or 0))
		local force = session.root.AssemblyMass * accel
		lv.MaxAxesForce = Vector3.new(force, 0, force) -- trục Y bỏ trống cho trọng lực
	end
	lv.Enabled = enabled
end

-- TURN ASSIST: xoay vector vận tốc ngang về hướng phím bấm (giữ độ lớn) khi chạy trên đất
-- → cua gắt không bị quán tính kéo thành vòng rộng ở tốc độ cao.
local function updateTurnAssist(session: Session, dt: number)
	local cfg = ParkourConfig.TurnAssist
	if not (cfg and cfg.Enabled) then
		return
	end
	if session.state ~= States.Grounded or not ParkourUtil.IsGrounded(session.humanoid) then
		return
	end
	local move = session.humanoid.MoveDirection
	if move.Magnitude < 0.05 then
		return -- không bấm gì → để Active Braking xử
	end
	local root = session.root
	local v = root.AssemblyLinearVelocity
	local h = Vector3.new(v.X, 0, v.Z)
	local speed = h.Magnitude
	if speed < cfg.MinSpeed then
		return
	end
	local target = Vector3.new(move.X, 0, move.Z).Unit
	local alpha = 1 - math.exp(-cfg.Rate * dt)
	local newDir = h.Unit:Lerp(target, alpha)
	if newDir.Magnitude > 1e-4 then
		newDir = newDir.Unit
		root.AssemblyLinearVelocity = Vector3.new(newDir.X * speed, v.Y, newDir.Z * speed)
	end
end

-- WALL GUARD: chống văng khi tông tường ở tốc độ cao.
-- (1) Raycast theo HƯỚNG VẬN TỐC — thấy tường đứng trong tầm nhìn-trước thì cắt ngay thành
-- phần vận tốc lao vào tường (engine không còn xuyên thấu để sinh xung hất).
-- (2) Mở cửa sổ hậu va chạm: trong PostHitWindow giây, kẹp vận tốc bật lên + trần ngang
-- KỂ CẢ TRÊN KHÔNG (Grip thường chỉ chạy khi Grounded nên bó tay với cú hất lên trời).
local function updateWallGuard(session: Session)
	local cfg = ParkourConfig.AntiFling and ParkourConfig.AntiFling.WallGuard
	if not (cfg and cfg.Enabled) then
		return
	end
	-- Slide có blockcast chống văng riêng (ngắt trượt) — không dò chồng.
	if session.state == States.Sliding then
		return
	end

	local root = session.root
	local v = root.AssemblyLinearVelocity
	local h = Vector3.new(v.X, 0, v.Z)
	local speed = h.Magnitude

	if speed >= cfg.MinSpeed then
		local dist = math.max(3, speed * cfg.ProbeAhead)
		local params = ParkourUtil.MakeRaycastParams(session.character)
		local hit = workspace:Raycast(root.Position, h.Unit * dist, params)
		if hit and ParkourUtil.IsVerticalWall(hit.Normal) then
			session.wallGuardUntil = os.clock() + cfg.PostHitWindow
			local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
			if n.Magnitude > 1e-3 then
				n = n.Unit
				local into = -h:Dot(n) -- > 0 khi đang lao VÀO tường
				if into > 0 then
					local nh = h + n * into -- triệt tiêu đúng thành phần đâm tường, giữ phần trượt dọc
					root.AssemblyLinearVelocity = Vector3.new(nh.X, v.Y, nh.Z)
				end
			end
		end
	end

	-- Cửa sổ hậu va chạm: khóa nảy (kể cả khi đã rời mặt đất vì cú hất).
	if os.clock() < session.wallGuardUntil then
		local v2 = root.AssemblyLinearVelocity
		local vy = math.min(v2.Y, cfg.MaxBounceUp)
		local h2 = Vector3.new(v2.X, 0, v2.Z)
		local grip = ParkourConfig.Grip
		local ceiling = math.max(session.humanoid.WalkSpeed * grip.MaxSpeedFactor, grip.MinCeiling)
		local hspeed = h2.Magnitude
		if hspeed > ceiling then
			h2 = h2 * (ceiling / hspeed)
		end
		if vy ~= v2.Y or hspeed > ceiling then
			root.AssemblyLinearVelocity = Vector3.new(h2.X, vy, h2.Z)
		end
	end
end

-- ANTI-FLING: kẹp vận tốc góc — va đập mạnh bơm angular velocity khổng lồ làm nhân vật
-- xoay tít + bay quỹ đạo loạn. Áp mọi trạng thái (kể cả trên không: đang xoáy là đang văng).
local function updateAntiSpin(session: Session)
	local cfg = ParkourConfig.AntiFling
	if not (cfg and cfg.Enabled) then
		return
	end
	local root = session.root
	local w = root.AssemblyAngularVelocity
	if w.Magnitude > cfg.MaxAngularSpeed then
		root.AssemblyAngularVelocity =
			Vector3.new(0, math.clamp(w.Y, -cfg.MaxAngularSpeed, cfg.MaxAngularSpeed), 0)
	end
end

-- GRIP: ghì vận tốc ngang ≤ WalkSpeed×factor khi chạy trên đất — hết trôi quá đà + chống văng.
local function updateGrip(session: Session)
	local grip = ParkourConfig.Grip
	if not (grip and grip.Enabled) then
		return
	end
	-- Chỉ khi Grounded (state) + thực sự trên mặt đất → không đụng slide/wall-run/trên không.
	if session.state ~= States.Grounded or not ParkourUtil.IsGrounded(session.humanoid) then
		return
	end
	local ceiling = math.max(session.humanoid.WalkSpeed * grip.MaxSpeedFactor, grip.MinCeiling)
	local v = session.root.AssemblyLinearVelocity
	local hx, hz = v.X, v.Z
	local hspeed = math.sqrt(hx * hx + hz * hz)
	if hspeed > ceiling and hspeed > 0.01 then
		local scale = ceiling / hspeed
		session.root.AssemblyLinearVelocity = Vector3.new(hx * scale, v.Y, hz * scale)
	end
end

-- Gọi mỗi frame từ orchestrator.
function ParkourBrake.Update(session: Session, dt: number)
	updateAntiSpin(session)
	updateWallGuard(session)
	updateGrip(session)
	updateTurnAssist(session, dt)

	local cfg = ParkourConfig.Braking
	if not cfg.Enabled then
		setBrakeEnabled(session, false)
		return
	end

	-- Chỉ phanh khi: Grounded (không slide/wall-run), trên mặt đất, KHÔNG bấm di chuyển.
	local shouldBrake = session.state == States.Grounded
		and ParkourUtil.IsGrounded(session.humanoid)
		and session.humanoid.MoveDirection.Magnitude < 0.05

	if not shouldBrake then
		setBrakeEnabled(session, false)
		return
	end

	local speed = ParkourUtil.HorizontalSpeed(session.root)

	if session.brakeVelocity.Enabled then
		-- Đã phanh gần dừng → triệt tiêu hẳn phần trượt còn lại rồi nhả constraint.
		if speed <= cfg.StopSpeedThreshold then
			local velocity = session.root.AssemblyLinearVelocity
			session.root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
			setBrakeEnabled(session, false)
		end
	elseif speed > cfg.MinSpeedToBrake then
		setBrakeEnabled(session, true)
	end
end

return ParkourBrake
