--!strict
--[[
	MovementSlide.luau — SLIDE [C].

	Vẫn dùng LinearVelocity (không ghi thẳng vận tốc) vì trong lúc slide người chơi VẪN
	giữ phím, nên Humanoid vẫn chủ động ghi vận tốc mỗi bước physics và sẽ đè mất mọi
	giá trị mình ghi tay. Constraint là cách duy nhất thắng được nó một cách ổn định.

	MaxAxesForce HỮU HẠN (m × MaxAccel) chứ không vô hạn: khi cấn vật cản, constraint
	không ủi xuyên hình học — đó chính là nguồn văng của bản cũ.

	MỚI: ấn LÙI thì dừng trượt ngay lập tức (xem checkBackwardInput).
]]

local MovementConfig = require(script.Parent.MovementConfig)
local MovementTypes = require(script.Parent.MovementTypes)
local MovementUtil = require(script.Parent.MovementUtil)
local MovementMath = require(script.Parent.MovementMath)
local MovementAnimator = require(script.Parent.MovementAnimator)

type Session = MovementTypes.Session

local States = MovementConfig.States

local MovementSlide = {}

function MovementSlide.Setup(session: Session)
	local cfg = MovementConfig.Slide

	local lv = Instance.new("LinearVelocity")
	lv.Name = "MovementSlideVelocity"
	lv.Attachment0 = session.attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.zero -- set theo khối lượng thật lúc Begin
	lv.VectorVelocity = Vector3.zero
	lv.Enabled = false
	lv.Parent = session.root
	session.slideVelocity = lv
	session.sweeper:Add(lv, "Destroy")

	local footAtt = Instance.new("Attachment")
	footAtt.Name = "MovementSlideFoot"
	footAtt.Position = Vector3.new(0, -2.6, 0)
	footAtt.Parent = session.root
	session.sweeper:Add(footAtt, "Destroy")

	local particle = Instance.new("ParticleEmitter")
	particle.Name = "MovementSlideDust"
	particle.Rate = cfg.Particle.Rate
	particle.Lifetime = cfg.Particle.Lifetime
	particle.Speed = cfg.Particle.Speed
	particle.Size = NumberSequence.new(cfg.Particle.SizeStud)
	particle.Color = ColorSequence.new(cfg.Particle.Color)
	particle.SpreadAngle = Vector2.new(cfg.Particle.SpreadDeg, cfg.Particle.SpreadDeg)
	particle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	particle.LightEmission = 0.4
	particle.Enabled = false
	particle.Parent = footAtt
	session.slideParticles = particle
	session.sweeper:Add(particle, "Destroy")

	session.lastSlideClock = -math.huge
end

function MovementSlide.CanStart(session: Session): boolean
	if session.state ~= States.Grounded then
		return false
	end
	if not MovementUtil.IsGrounded(session.humanoid) then
		return false
	end
	local moving = session.humanoid.MoveDirection.Magnitude > 0.05 or MovementUtil.HorizontalSpeed(session.root) > 6
	if not moving then
		return false
	end
	return (os.clock() - session.lastSlideClock) >= MovementConfig.Slide.Cooldown
end

--[[
	DỪNG KHI ẤN LÙI.

	So hướng phím đang bấm với hướng đang trượt. Bấm ngược quá BackwardStopDot nghĩa là
	người chơi rõ ràng muốn phanh lại → dừng CỨNG (triệt tiêu vận tốc ngang) chứ không
	để trượt nốt quán tính, vì cảm giác mong đợi khi bấm lùi là dừng khựng ngay.

	Có grace vài phần giây đầu: nếu không, cú bấm S còn sót lại từ trước lúc nhấn C sẽ
	cắt luôn slide vừa mở.

	Quyết định nằm ở MovementMath.ShouldStopForBackward — hàm thuần, có unit test trong
	tests/run.luau (suite "Slide — dừng khi ấn lùi").
]]
local function pressingBackward(session: Session): boolean
	return MovementMath.ShouldStopForBackward(
		session.slideDir,
		session.humanoid.MoveDirection,
		os.clock() - session.slideStartClock
	)
end

function MovementSlide.Begin(session: Session)
	local cfg = MovementConfig.Slide

	session.state = States.Sliding
	session.slideStartClock = os.clock()
	session.slideEndClock = os.clock() + cfg.MaxDuration
	session.slideDir = MovementUtil.DesiredMoveDir(session)
	if session.slideDir.Magnitude < 1e-3 then
		session.state = States.Grounded
		return
	end

	local baseSpeed = session.humanoid.WalkSpeed * cfg.InitialSpeedMultiplier
	session.slideSpeed = math.clamp(baseSpeed, cfg.MinInitialSpeed, cfg.MaxInitialSpeed)
	session.slideInitialSpeed = session.slideSpeed

	-- Hạ HipHeight để thu nhỏ hồ sơ va chạm (chui cổng/laser thấp).
	-- ⚠️ Zone5SlideController nhận biết "đang slide" qua HipHeight < 1.6 — xem MovementConfig.
	session.originalHipHeight = session.humanoid.HipHeight
	session.humanoid.HipHeight = session.originalHipHeight * cfg.HipHeightFactor

	local maxForce = session.root.AssemblyMass * cfg.MaxAccel
	session.slideVelocity.MaxAxesForce = Vector3.new(maxForce, 0, maxForce) -- Y bỏ trống cho trọng lực
	session.slideVelocity.VectorVelocity = session.slideDir * session.slideSpeed
	session.slideVelocity.Enabled = true
	session.slideParticles.Enabled = true

	MovementAnimator.PlayAction(session, "Slide")
end

function MovementSlide.Update(session: Session, dt: number)
	if session.state ~= States.Sliding then
		return
	end
	local cfg = MovementConfig.Slide
	local root = session.root

	-- Ấn lùi → dừng khựng ngay, ưu tiên trên mọi điều kiện khác.
	if pressingBackward(session) then
		MovementSlide.Stop(session, true)
		return
	end

	-- Kẹp vận tốc bay lên + diệt xoáy (cấn dốc/cạnh khối hay biến đà thành phóng lên trời).
	local velocity = root.AssemblyLinearVelocity
	if velocity.Y > cfg.MaxUpwardVelocity then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, cfg.MaxUpwardVelocity, velocity.Z)
	end
	root.AssemblyAngularVelocity = Vector3.zero

	session.slideSpeed -= cfg.Friction * dt

	-- Bẻ lái nhẹ trong lúc trượt.
	local steer = session.humanoid.MoveDirection
	if steer.Magnitude > 0.05 and cfg.SteerStrength > 0 then
		local steerDir = Vector3.new(steer.X, 0, steer.Z).Unit
		session.slideDir = session.slideDir:Lerp(steerDir, cfg.SteerStrength).Unit
	end

	session.slideVelocity.VectorVelocity = session.slideDir * session.slideSpeed

	-- Nâng DẦN HipHeight về gốc khi chậm lại → đứng dậy không bị chìm xuống đất.
	local lowHip = session.originalHipHeight * cfg.HipHeightFactor
	local denom = math.max(session.slideInitialSpeed - cfg.EndSpeed, 1)
	local duck = math.clamp((session.slideSpeed - cfg.EndSpeed) / denom, 0, 1)
	session.humanoid.HipHeight = lowHip + (session.originalHipHeight - lowHip) * (1 - duck)

	local elapsed = os.clock() - session.slideStartClock

	--[[
		PHÁT HIỆN NGHẼN — phản ứng, không phải dự đoán.

		Bản trước còn quét khối 5 studs phía trước để ngắt trượt sớm; đã gỡ vì đó đúng là
		kiểu "tới gần vật thể là bị chậm" mà game này không muốn. Thay vào đó cứ để trượt
		tới, khi vận tốc THỰC tụt sâu dưới vận tốc lệnh nghĩa là đã bị chặn thật → mới
		dừng. Nhờ vậy không mất một blockcast mỗi frame, và slide chỉ dừng khi đáng dừng.
	]]
	if elapsed > cfg.ObstructionGrace then
		local actual = MovementUtil.HorizontalVelocity(root):Dot(session.slideDir)
		if actual < session.slideSpeed * cfg.ObstructionSpeedFraction then
			MovementSlide.Stop(session, true)
			return
		end
	end

	if elapsed < cfg.MinDuration then
		return -- grace: đủ lâu để anim kịp hiện
	end

	-- "Rơi khỏi mép": raycast xuống có dung sai, KHÔNG dùng FloorMaterial (nó chập chờn
	-- thành Air khi trượt nhanh ở HipHeight thấp → cắt slide oan).
	local params = MovementUtil.GetRayParams(session)
	local groundHit = workspace:Raycast(root.Position, Vector3.new(0, -(session.originalHipHeight + 4), 0), params)

	if session.slideSpeed <= cfg.EndSpeed or os.clock() >= session.slideEndClock or groundHit == nil then
		MovementSlide.Stop(session)
	end
end

-- hardStop = true: triệt tiêu sạch vận tốc ngang (đụng vật cản hoặc người chơi bấm lùi).
function MovementSlide.Stop(session: Session, hardStop: boolean?)
	if session.state ~= States.Sliding then
		return
	end

	session.slideVelocity.Enabled = false
	session.slideParticles.Enabled = false
	session.humanoid.HipHeight = session.originalHipHeight
	session.lastSlideClock = os.clock()

	if hardStop then
		local current = session.root.AssemblyLinearVelocity
		-- Kẹp cả Y ≤ 0: lực va chạm vừa nảy người lên cũng bị triệt.
		session.root.AssemblyLinearVelocity = Vector3.new(0, math.min(current.Y, 0), 0)
		session.root.AssemblyAngularVelocity = Vector3.zero
	end

	MovementAnimator.StopAction(session, "Slide")
	session.state = States.Grounded
end

return MovementSlide
