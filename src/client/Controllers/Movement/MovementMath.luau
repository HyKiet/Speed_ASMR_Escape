--!strict
--[[
	MovementMath.luau — phần TOÁN THUẦN của hệ di chuyển.

	Chỉ nhận số và Vector3, KHÔNG chạm Instance / service / os.clock. Nhờ vậy chạy được
	bằng Lune ngoài Roblox và có unit test trong tests/run.luau.

	Vì sao tách: các cơ chế này chỉ kéo dài khoảng 1 giây, mà mỗi lệnh điều khiển Studio
	từ xa mất vài giây khứ hồi — không thể quan sát đúng thời điểm. Đưa phần quyết định
	ra chỗ tất định thì kiểm chứng được chắc chắn, phần còn lại trong Studio chỉ còn là
	nối dây.
]]

local MovementConfig = require(script.Parent.MovementConfig)

local MovementMath = {}

--[[
	Có nên dừng slide vì người chơi đang ấn LÙI không?

	`elapsed` = số giây kể từ lúc bắt đầu trượt. Trong BackwardStopGrace giây đầu thì
	luôn trả false, nếu không cú bấm S còn sót từ trước lúc nhấn C sẽ cắt luôn slide
	vừa mở.
]]
function MovementMath.ShouldStopForBackward(slideDir: Vector3, moveDirection: Vector3, elapsed: number): boolean
	local cfg = MovementConfig.Slide
	if elapsed < cfg.BackwardStopGrace then
		return false
	end

	local flat = Vector3.new(moveDirection.X, 0, moveDirection.Z)
	if flat.Magnitude < 0.05 then
		return false -- không bấm hướng nào
	end
	if slideDir.Magnitude < 1e-3 then
		return false
	end

	return flat.Unit:Dot(slideDir.Unit) <= cfg.BackwardStopDot
end

--[[
	Gia tốc hãm thực tế ở một tốc độ cho trước.

	Quãng dừng = v²/(2·a). Muốn quãng dừng bị ghim quanh TargetStopDistance thì gia tốc
	phải tỉ lệ với v² chứ không phải với v — xem lời giải thích trong MovementConfig.
	Sàn `Accel` giữ cho tốc độ thấp vẫn dừng dứt khoát thay vì rề rà.
]]
function MovementMath.BrakeAccelAt(speed: number): number
	local cfg = MovementConfig.Brake
	return math.max(cfg.Accel, (speed * speed) / (2 * cfg.TargetStopDistance))
end

-- Quãng dừng thực tế ở tốc độ cho trước (studs) — dùng cho test và tinh chỉnh.
function MovementMath.StopDistanceAt(speed: number): number
	return (speed * speed) / (2 * MovementMath.BrakeAccelAt(speed))
end

-- Trần tốc độ ngang khi bám đất, theo WalkSpeed hiện tại.
function MovementMath.SpeedCeiling(walkSpeed: number): number
	local grip = MovementConfig.Grip
	return math.max(walkSpeed * grip.MaxSpeedFactor, grip.MinCeiling)
end

return MovementMath
