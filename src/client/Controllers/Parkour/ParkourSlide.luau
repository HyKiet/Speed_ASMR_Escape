--!strict
--[[
	ParkourSlide.luau — POWER SLIDE (trượt gia tốc) — bản chống văng toàn diện.

	Input: phím [C] khi đang di chuyển trên mặt đất.
	- Phát anim "Slide", hạ HipHeight để thu nhỏ hồ sơ va chạm (chui cổng/laser thấp).
	- Vật lý: LinearVelocity đẩy theo hướng di chuyển, vận tốc khởi điểm tỷ lệ WalkSpeed,
	  giảm dần theo ma sát → quãng đường trượt cũng tỷ lệ WalkSpeed.

	4 LỚP CHỐNG VĂNG (fix lỗi "trúng khối vật lý → player bay tứ tung"):
	  1. LỰC HỮU HẠN: MaxAxesForce = m × MaxSlideAccel thay vì vô cực — khi cấn vật cản,
	     constraint không ủi xuyên với lực vô hạn (nguồn văng chính).
	  2. BLOCKCAST: quét khối bằng đúng thân người (thay raycast tâm) → bắt được vật cản
	     nhỏ, lệch tâm, cạnh khối trước khi đâm vào → ngắt trượt + triệt tiêu vận tốc.
	  3. KẸP TRỤC Y + DIỆT XOÁY mỗi frame: cấn dốc làm vận tốc chuyển thành bay lên →
	     kẹp Y ≤ MaxUpwardVelocity; AssemblyAngularVelocity = 0 chống lộn vòng.
	  4. PHÁT HIỆN NGHẼN: vận tốc thực tế tụt sâu dưới vận tốc lệnh (sau grace) nghĩa là
	     đang bị kẹt vào vật thể → dừng cứng ngay thay vì rung lắc giữa constraint và va chạm.
]]

local Workspace = game:GetService("Workspace")

local ParkourConfig = require(script.Parent.ParkourConfig)
local ParkourTypes = require(script.Parent.ParkourTypes)
local ParkourUtil = require(script.Parent.ParkourUtil)
local ParkourAnimator = require(script.Parent.ParkourAnimator)

type Session = ParkourTypes.Session

local States = ParkourConfig.States

local ParkourSlide = {}

-- Tạo trước các đối tượng vật lý + particle cho slide (gọi 1 lần khi setup session).
function ParkourSlide.Setup(session: Session)
	local cfg = ParkourConfig.Slide

	-- LinearVelocity điều khiển vận tốc ngang khi trượt. Lực HỮU HẠN (xem header).
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ParkourSlideVelocity"
	lv.Attachment0 = session.attachment
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.zero -- set theo khối lượng thật lúc Begin
	lv.VectorVelocity = Vector3.zero
	lv.Enabled = false
	lv.Parent = session.root
	session.slideVelocity = lv
	session.janitor:Add(lv, "Destroy")

	-- Particle ma sát: gắn lên 1 attachment sát chân.
	local footAtt = Instance.new("Attachment")
	footAtt.Name = "ParkourSlideFoot"
	footAtt.Position = Vector3.new(0, -2.6, 0) -- sát mặt đất dưới root
	footAtt.Parent = session.root
	session.janitor:Add(footAtt, "Destroy")

	local particle = Instance.new("ParticleEmitter")
	particle.Name = "ParkourSlideDust"
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
	session.janitor:Add(particle, "Destroy")

	session.lastSlideClock = -math.huge
end

-- Đủ điều kiện để bắt đầu trượt?
function ParkourSlide.CanStart(session: Session): boolean
	local grounded = ParkourUtil.IsGrounded(session.humanoid)
	local moving = session.humanoid.MoveDirection.Magnitude > 0.05
		or ParkourUtil.HorizontalSpeed(session.root) > 6
	local cooldownOk = (os.clock() - session.lastSlideClock) >= ParkourConfig.Slide.Cooldown
	if session.state ~= States.Grounded then
		return false
	end
	if not grounded then
		return false
	end
	if not moving then
		return false
	end
	return cooldownOk
end

-- Blockcast quét vật cản phía trước bằng khối cỡ thân người (đang cúi).
local function obstacleAhead(session: Session, dir: Vector3, distance: number): boolean
	if dir.Magnitude < 1e-3 then
		return false
	end
	local cfg = ParkourConfig.Slide
	local params = ParkourUtil.MakeRaycastParams(session.character)
	local castCFrame = CFrame.lookAlong(session.root.Position, dir.Unit)
	local result = Workspace:Blockcast(castCFrame, cfg.BlockcastSize, dir.Unit * distance, params)
	-- Chỉ tính vật cản ĐỨNG (tường/khối); dốc thoải & mặt đất bỏ qua để trượt lên dốc được.
	return result ~= nil and ParkourUtil.IsVerticalWall(result.Normal)
end

function ParkourSlide.Begin(session: Session)
	local cfg = ParkourConfig.Slide

	session.state = States.Sliding
	session.slideStartClock = os.clock()
	session.slideEndClock = os.clock() + cfg.MaxDuration
	session.slideDir = ParkourUtil.DesiredMoveDir(session)

	-- Vận tốc khởi điểm tỷ lệ WalkSpeed (theo spec), kẹp trong [Min, Max].
	local baseSpeed = session.humanoid.WalkSpeed * cfg.InitialSpeedMultiplier
	session.slideSpeed = math.clamp(baseSpeed, cfg.MinInitialSpeed, cfg.MaxInitialSpeed)
	session.slideInitialSpeed = session.slideSpeed

	-- Hạ HipHeight → thu nhỏ hồ sơ va chạm (kết hợp anim nằm thấp để chui cổng laser).
	session.originalHipHeight = session.humanoid.HipHeight
	session.humanoid.HipHeight = session.originalHipHeight * cfg.HipHeightFactor

	-- Lực hữu hạn theo khối lượng thật (chống văng lớp 1). Trục Y bỏ trống cho trọng lực.
	local maxForce = session.root.AssemblyMass * cfg.MaxSlideAccel
	session.slideVelocity.MaxAxesForce = Vector3.new(maxForce, 0, maxForce)
	session.slideVelocity.VectorVelocity = session.slideDir * session.slideSpeed
	session.slideVelocity.Enabled = true
	session.slideParticles.Enabled = true

	ParkourAnimator.PlayAction(session, "Slide")
end

function ParkourSlide.Update(session: Session, dt: number)
	if session.state ~= States.Sliding then
		return
	end
	local cfg = ParkourConfig.Slide
	local root = session.root

	-- [CHỐNG VĂNG lớp 3] Kẹp vận tốc bay LÊN + diệt xoáy mỗi frame.
	local velocity = root.AssemblyLinearVelocity
	if velocity.Y > cfg.MaxUpwardVelocity then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, cfg.MaxUpwardVelocity, velocity.Z)
	end
	root.AssemblyAngularVelocity = Vector3.zero

	-- Giảm tốc theo ma sát (tuyến tính).
	session.slideSpeed -= cfg.Friction * dt

	-- Cho bẻ lái nhẹ: nội suy hướng trượt về phía input hiện tại.
	local steer = session.humanoid.MoveDirection
	if steer.Magnitude > 0.05 and cfg.SteerStrength > 0 then
		local steerDir = Vector3.new(steer.X, 0, steer.Z).Unit
		session.slideDir = session.slideDir:Lerp(steerDir, cfg.SteerStrength).Unit
	end

	session.slideVelocity.VectorVelocity = session.slideDir * session.slideSpeed

	-- Nâng DẦN HipHeight về gốc khi slide chậm lại → đứng dậy KHÔNG bị chìm xuống đất.
	local lowHip = session.originalHipHeight * cfg.HipHeightFactor
	local denom = math.max(session.slideInitialSpeed - cfg.EndSpeed, 1)
	local duck = math.clamp((session.slideSpeed - cfg.EndSpeed) / denom, 0, 1)
	session.humanoid.HipHeight = lowHip + (session.originalHipHeight - lowHip) * (1 - duck)

	-- [CHỐNG VĂNG lớp 2] Blockcast dò vật cản phía trước → ngắt + triệt tiêu vận tốc NGAY.
	if obstacleAhead(session, session.slideDir, cfg.CollisionLookAhead) then
		ParkourSlide.Stop(session, true)
		return
	end

	local elapsed = os.clock() - session.slideStartClock

	-- [CHỐNG VĂNG lớp 4] Bị nghẽn: vận tốc thực tụt sâu dưới vận tốc lệnh (đâm vào khối
	-- mà blockcast lỡ sót — vd. bị vật thể động ép ngang hông) → dừng cứng, khỏi rung lắc.
	if elapsed > cfg.ObstructionGrace then
		local actualSpeed = ParkourUtil.HorizontalVelocity(root):Dot(session.slideDir)
		if actualSpeed < session.slideSpeed * cfg.ObstructionSpeedFraction then
			ParkourSlide.Stop(session, true)
			return
		end
	end

	-- GRACE: trong MinDuration đầu KHÔNG cho slide kết thúc (để anim kịp hiện + bỏ qua
	-- vài frame "trên không" do hạ HipHeight làm nhân vật rơi nhẹ).
	if elapsed < cfg.MinDuration then
		return
	end

	-- Kiểm tra "rơi khỏi mép" bằng raycast XUỐNG có DUNG SAI, thay vì FloorMaterial
	-- (FloorMaterial chập chờn = Air khi trượt nhanh ở HipHeight thấp → cắt slide oan).
	local params = ParkourUtil.MakeRaycastParams(session.character)
	local groundHit = Workspace:Raycast(
		root.Position,
		Vector3.new(0, -(session.originalHipHeight + 4), 0),
		params
	)
	local fellOff = groundHit == nil

	-- Điều kiện kết thúc: hết đà / hết giờ / rơi khỏi mép.
	if session.slideSpeed <= cfg.EndSpeed or os.clock() >= session.slideEndClock or fellOff then
		ParkourSlide.Stop(session)
	end
end

-- hardStop = true: đụng vật cản → triệt tiêu sạch vận tốc ngang (chống văng người).
function ParkourSlide.Stop(session: Session, hardStop: boolean?)
	if session.state ~= States.Sliding then
		return
	end

	session.slideVelocity.Enabled = false
	session.slideParticles.Enabled = false
	session.humanoid.HipHeight = session.originalHipHeight
	session.lastSlideClock = os.clock()

	if hardStop then
		local current = session.root.AssemblyLinearVelocity
		-- Kẹp cả Y ≤ 0 khi dừng cứng: lực va chạm vừa nảy người lên cũng bị triệt.
		session.root.AssemblyLinearVelocity = Vector3.new(0, math.min(current.Y, 0), 0)
		session.root.AssemblyAngularVelocity = Vector3.zero -- diệt xoáy, chống lộn vòng
	end

	ParkourAnimator.StopAction(session, "Slide")
	session.state = States.Grounded
end

return ParkourSlide
