--!strict
--[[
	MovementStabilizer.luau — GIẢM NHẸ CÚ VĂNG + BÁM ĐƯỜNG + PHANH + BẺ LÁI.

	Toàn bộ chạy SAU bước physics (Heartbeat). Thứ tự khung hình của Roblox là
	    RenderStepped → Stepped → [bước physics] → Heartbeat
	nên Heartbeat là chỗ DUY NHẤT đọc được kết quả va chạm thật và sửa lại được.

	KHÔNG CÓ pha trước-physics nào nữa. Bản trước có bước quét khối theo hướng vận tốc
	để cắt đà trước khi đâm tường — đúng vật lý nhưng sai cảm giác: chạy gần vật thể là
	bị ghì chậm. Đã gỡ; giờ va chạm cứ xảy ra tự nhiên, chỉ cú văng SAU đó bị hạ xuống
	mức nhẹ.

	Mỗi frame đọc-sửa-ghi vận tốc đúng một lần theo thứ tự cố định, không có hai hệ nào
	giành quyền ghi (đó là lỗi của thư mục Parkour cũ).
]]

local MovementConfig = require(script.Parent.MovementConfig)
local MovementMath = require(script.Parent.MovementMath)
local MovementTypes = require(script.Parent.MovementTypes)
local MovementUtil = require(script.Parent.MovementUtil)

type Session = MovementTypes.Session

local States = MovementConfig.States

local MovementStabilizer = {}

-- Trần tốc độ ngang khi đang bám đất.
local function speedCeiling(session: Session): number
	return MovementMath.SpeedCeiling(session.humanoid.WalkSpeed)
end

--[[
	KẸP VẬN TỐC GÓC.

	Đây mới là thứ tạo cảm giác "văng tứ tung": cú va đập bơm angular velocity rất lớn,
	nhân vật xoay tít rồi bay theo quỹ đạo loạn. Cắt xoáy là hết loạn mà không đụng một
	chút nào tới tốc độ chạy — nên để luôn bật ở mọi trạng thái.
]]
local function clampSpin(session: Session)
	local cfg = MovementConfig.AntiFling
	if not cfg.Enabled then
		return
	end
	local root = session.root
	local w = root.AssemblyAngularVelocity
	if w.Magnitude > cfg.MaxAngularSpeed then
		root.AssemblyAngularVelocity = Vector3.new(0, math.clamp(w.Y, -cfg.MaxAngularSpeed, cfg.MaxAngularSpeed), 0)
	end
end

--[[
	GIẢM NHẸ CÚ VĂNG.

	Nhận biết xung va chạm bằng độ đổi vận tốc trong MỘT bước physics: trọng lực và gia
	tốc thường của humanoid chỉ đổi vài studs/s mỗi bước, nên vượt ImpactDeltaSpeed thì
	chắc chắn là engine vừa giải một cú đâm.

	Rồi xác nhận đúng là đụng TƯỜNG ĐỨNG bằng tia ngắn. Bước xác nhận này quan trọng: nếu
	thiếu nó thì lò xo Zone 13, gió Zone 12, quạt Zone 14 — những cơ chế CỐ Ý văng người —
	cũng bị hạ xuống mức nhẹ và hỏng hết. Tia chỉ bắn đúng lúc va chạm (hiếm) nên không
	tốn gì, và không bao giờ làm chậm player lúc đang tới gần.

	Bắn theo HAI hướng vì một hướng không đủ:
	  • hướng vận tốc CŨ — bắt cú đâm trực diện (xung hất chủ yếu lên trên, hướng cũ vẫn
	    chỉ thẳng vào tường);
	  • hướng NGƯỢC với xung — xung luôn đẩy RA khỏi mặt va chạm, nên −delta chỉ thẳng
	    VÀO mặt đó; đây là cách duy nhất bắt được cú va chạm sượt/lệch hông, lúc vận tốc
	    cũ không còn chỉ vào vật cản nữa.
]]
local function hitsVerticalWall(session: Session, dir: Vector3): boolean
	if dir.Magnitude < 1e-3 then
		return false
	end
	local hit = workspace:Raycast(
		session.root.Position,
		dir.Unit * MovementConfig.AntiFling.ImpactProbeDistance,
		MovementUtil.GetRayParams(session)
	)
	return hit ~= nil and MovementUtil.IsVerticalWall(hit.Normal)
end

-- Stage CỐ Ý văng người (lò xo Zone 13, gió Zone 12, quạt Zone 14): mọi phép kẹp đều
-- phải tránh xa, nếu không cơ chế zone hỏng hết.
local function inLauncherStage(session: Session): boolean
	local activeStage = session.player:GetAttribute("ActiveStage")
	return typeof(activeStage) == "number" and MovementConfig.AntiFling.LauncherStages[activeStage] == true
end

local function dampImpact(session: Session, prev: Vector3)
	local cfg = MovementConfig.AntiFling
	if not cfg.Enabled then
		return
	end

	local root = session.root
	local v = root.AssemblyLinearVelocity

	if inLauncherStage(session) then
		return
	end

	local dvx, dvy, dvz = v.X - prev.X, v.Y - prev.Y, v.Z - prev.Z
	if math.sqrt(dvx * dvx + dvy * dvy + dvz * dvz) < cfg.ImpactDeltaSpeed then
		return -- không có xung nào
	end

	-- Trước cú đâm phải đang thực sự có đà; đi bộ đụng tường không văng nổi.
	local prevSpeed = math.sqrt(prev.X * prev.X + prev.Z * prev.Z)
	if prevSpeed < cfg.ImpactMinSpeed then
		return
	end

	local alongOldVelocity = Vector3.new(prev.X, 0, prev.Z)
	local intoImpactSurface = Vector3.new(-dvx, 0, -dvz)
	if not hitsVerticalWall(session, alongOldVelocity) and not hitsVerticalWall(session, intoImpactSurface) then
		return
	end

	-- Cho văng NHẸ: vẫn nảy ra một cái cho có phản hồi, nhưng không bay lên trời.
	local vy = math.min(v.Y, cfg.BounceMaxUp)
	local hx, hz = v.X, v.Z
	local speed = math.sqrt(hx * hx + hz * hz)
	if speed > cfg.BounceMaxSpeed and speed > 1e-3 then
		local scale = cfg.BounceMaxSpeed / speed
		hx, hz = hx * scale, hz * scale
	end
	root.AssemblyLinearVelocity = Vector3.new(hx, vy, hz)
end

--[[
	KẸP "BẬT CÓC" KHI ĐANG BÁM ĐẤT.

	Ca mà `dampImpact` không với tới: cán mép sàn / vạch Stage / khe giữa hai part ở
	100–250 WS thì engine đẩy nhân vật LÊN chứ không đẩy ngược, và tia xác nhận tường
	đứng bắn ngang không trúng gì cả nên `dampImpact` bỏ qua.

	Điều kiện kẹp (phải đủ CẢ BỐN, nên nó gần như không bao giờ chạm vào lối chơi bình thường):
	  1. Humanoid đang ở ĐÚNG trạng thái chạy trên đất (Running/RunningNoPhysics) — đang
	     bay thì không phải "bật cóc", đó là quỹ đạo bình thường.
	  2. vy tăng vọt > GroundPopDeltaUp trong ĐÚNG MỘT bước physics — chạy lên dốc thì vy
	     lớn nhưng lên từ từ, không bao giờ thoả điều kiện này.
	  3. Không phải zone cố ý văng người.
	  4. Không vừa bấm nhảy (nhảy chính là một xung đi lên hợp lệ).

	⚠️ Điều kiện 1 xét TRẠNG THÁI chứ không gọi `MovementUtil.IsGrounded`: hàm đó còn trả
	true khi `FloorMaterial ~= Air`, mà ngay khung hình bấm nhảy thì chân vẫn còn chạm sàn
	trong khi trạng thái đã là `Jumping` — đúng cái khung hình mang xung nhảy ~53 studs/s.
	Đi qua đường đó thì cú nhảy bị cắt cụt còn 16. Điều kiện 4 (grace theo sự kiện
	`Humanoid.Jumping`) là lớp chặn thứ hai cho cùng một ca.
]]
local function clampGroundPop(session: Session, prev: Vector3)
	local cfg = MovementConfig.AntiFling
	if not cfg.Enabled then
		return
	end
	local state = session.humanoid:GetState()
	if state ~= Enum.HumanoidStateType.Running and state ~= Enum.HumanoidStateType.RunningNoPhysics then
		return
	end
	if os.clock() - session.lastJumpClock < cfg.JumpGrace then
		return
	end
	if inLauncherStage(session) then
		return
	end

	local root = session.root
	local v = root.AssemblyLinearVelocity
	if v.Y - prev.Y < cfg.GroundPopDeltaUp or v.Y <= cfg.GroundPopMaxUp then
		return
	end
	root.AssemblyLinearVelocity = Vector3.new(v.X, cfg.GroundPopMaxUp, v.Z)
end

-- BÁM ĐƯỜNG — cắt vận tốc ngang thừa khi đang chạy trên đất. Không liên quan tới va
-- chạm: đây chỉ là trần tốc độ theo WalkSpeed để không trôi quá đà.
local function clampGrip(session: Session)
	local grip = MovementConfig.Grip
	if not grip.Enabled then
		return
	end
	if session.state ~= States.Grounded or not MovementUtil.IsGrounded(session.humanoid) then
		return
	end
	local ceiling = speedCeiling(session)
	local root = session.root
	local v = root.AssemblyLinearVelocity
	local speed = math.sqrt(v.X * v.X + v.Z * v.Z)
	if speed > ceiling and speed > 0.01 then
		local scale = ceiling / speed
		root.AssemblyLinearVelocity = Vector3.new(v.X * scale, v.Y, v.Z * scale)
	end
end

--[[
	BẺ LÁI — xoay vector vận tốc về hướng phím, GIỮ NGUYÊN độ lớn (không mất đà).

	Ở 250 studs/s quán tính kéo cú cua thành vòng rộng, khó canh khe hẹp. Chạy sau bước
	physics nên humanoid đã ghi vận tốc của nó xong, mình chỉ xoay lại hướng.
]]
local function applySteering(session: Session, dt: number)
	local cfg = MovementConfig.Steering
	if not cfg.Enabled then
		return
	end
	local move = session.humanoid.MoveDirection
	if move.Magnitude < 0.05 then
		return -- không bấm gì → nhường cho phanh
	end

	local root = session.root
	local v = root.AssemblyLinearVelocity
	local hx, hz = v.X, v.Z
	local speed = math.sqrt(hx * hx + hz * hz)
	if speed < cfg.MinSpeed then
		return
	end

	local rate = if MovementUtil.IsGrounded(session.humanoid) then cfg.GroundRate else cfg.AirRate
	local alpha = 1 - math.exp(-rate * dt)
	local target = Vector3.new(move.X, 0, move.Z).Unit
	local newDir = Vector3.new(hx / speed, 0, hz / speed):Lerp(target, alpha)
	if newDir.Magnitude > 1e-4 then
		newDir = newDir.Unit
		root.AssemblyLinearVelocity = Vector3.new(newDir.X * speed, v.Y, newDir.Z * speed)
	end
end

--[[
	PHANH — hãm thẳng vào vận tốc, KHÔNG dùng constraint.

	Khi MoveDirection = 0 thì Humanoid không chủ động ghi vận tốc nữa, nên hãm trực tiếp
	sau bước physics là đủ: bớt một constraint, bớt một nguồn giằng co, và không bao giờ
	"ủi" nhân vật vào hình học như constraint lực lớn vẫn làm.
]]
local function applyBrake(session: Session, dt: number)
	local cfg = MovementConfig.Brake
	if not cfg.Enabled then
		return
	end
	if not MovementUtil.IsGrounded(session.humanoid) then
		return
	end
	if session.humanoid.MoveDirection.Magnitude >= 0.05 then
		return
	end

	local root = session.root
	local v = root.AssemblyLinearVelocity
	local hx, hz = v.X, v.Z
	local speed = math.sqrt(hx * hx + hz * hz)
	if speed < cfg.MinSpeed then
		return
	end

	if speed <= cfg.StopThreshold then
		root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
		return
	end

	local newSpeed = math.max(0, speed - MovementMath.BrakeAccelAt(speed) * dt)
	local scale = newSpeed / speed
	root.AssemblyLinearVelocity = Vector3.new(hx * scale, v.Y, hz * scale)
end

-- Gọi mỗi Heartbeat (sau bước physics). Không còn pha trước-physics nào.
function MovementStabilizer.PostStep(session: Session, dt: number)
	-- Chụp vận tốc TRƯỚC mọi phép sửa của frame này. `dampImpact` và `clampGroundPop`
	-- cùng so với một mốc `prev` duy nhất; mốc mới ghi lại NGAY SAU hai hàm đó và TRƯỚC
	-- grip/steer/brake — ba hàm sau là chỉnh sửa CỦA MÌNH, không phải xung của engine, đưa
	-- vào mốc thì frame kế tiếp sẽ đọc nhầm thành va chạm.
	local prev = session.lastVelocity

	clampSpin(session)
	dampImpact(session, prev)
	clampGroundPop(session, prev)
	session.lastVelocity = session.root.AssemblyLinearVelocity

	if session.state == States.Grounded then
		clampGrip(session)
		applySteering(session, dt)
		applyBrake(session, dt)
	end
end

return MovementStabilizer
