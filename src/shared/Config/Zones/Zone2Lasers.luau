--!strict
--[[
	Zone2Lasers.luau — nhịp quay của dàn laser Stage 2 (nguồn sự thật chung server+client).

	Mỗi laser là một thanh dài hàn vào Pivot, xoay quanh trục đứng. Góc quay suy ra từ
	`workspace:GetServerTimeNow()` nên server và client ra CÙNG kết quả:
	  • Client xoay Pivot cục bộ (beam hàn theo) → 0 byte replicate CFrame.
	  • Server tính góc ảo để phân xử sát thương, KHÔNG dời part.

	rpm/dir mặc định để server ghi lên model nếu map chưa đặt attribute; client chỉ ĐỌC lại.
]]

local Zone2Lasers = {}

Zone2Lasers.ZoneName = "Zone2"
Zone2Lasers.ReadyAttribute = "LasersReady"

type LaserDefault = { rpm: number, dir: number }

--[[
	── HẠ TỐC 2026-08-27 (user: "laser Zone 2 quay nhanh quá, làm khó người chơi") ─────────
	Cũ 18 / 22 / 28 rpm → mới 9 / 11 / 13. Chậm hơn ~2,2 lần.

	Vì sao đúng con số này, chứ không phải "giảm cho có". Beam dài 70 studs, tâm ở Pivot nên
	bán kính 35. Cửa sổ TRÚNG theo phương quét chỉ rộng `halfThick 0.75 + thân người 1.5`
	= 2.25 studs mỗi bên. Quãng beam quét được trong MỘT frame phán xử ở bán kính r là
	`r × ω × dt`:

	    rpm   ω (rad/s)   tip (studs/s)   quét/frame @60Hz   @30Hz (server đông người)
	     28     2.93          102.6           1.71               3.42   ← VƯỢT cửa sổ 2.25
	     13     1.36           47.6            0.79               1.59   ← nằm gọn trong

	Tức là tốc độ cũ không chỉ khó chơi, nó còn khiến chính phép phán xử THỦNG ngay khi
	server tụt xuống 30Hz — đúng triệu chứng "lag server nên laser không chính xác".
	Hạ tốc là một nửa cách chữa; nửa còn lại là bù trễ mạng trong Zone2LaserService.

	Stage 2 là stage thứ hai của game (WalkSpeed người chơi lúc này còn 20–60): laser ở đây
	đóng vai dạy người chơi ĐỌC nhịp, không phải chốt chặn tốc độ. Zone 8/11 mới là gate.
]]
Zone2Lasers.Defaults = {
	LaserSweeper1 = { rpm = 9, dir = 1 },
	LaserSweeper2 = { rpm = 11, dir = -1 },
	Laser2_1 = { rpm = 13, dir = 1 },
	Laser2_2 = { rpm = 15, dir = -1 },
	Laser2_3 = { rpm = 17, dir = 1 },
} :: { [string]: LaserDefault }

-- Tốc độ góc (rad/s). Dùng để tính quãng beam quét trong một frame ở bán kính r: `r * ω * dt`.
function Zone2Lasers.AngularSpeed(rpm: number): number
	return rpm / 60 * math.pi * 2
end

-- Góc quay (độ) tại thời điểm `now`. Khớp tuyệt đối giữa mọi client vì cùng đọc GetServerTimeNow.
--
-- BẮT BUỘC modulo theo chu kỳ 1 vòng (60/rpm giây): `GetServerTimeNow()` cỡ 1.78e9, nhân lên
-- ~3e11 độ. `CFrame.Angles` KHÔNG range-reduce chính xác ở cỡ vài tỷ radian → góc ĐÓNG BĂNG
-- (float64 không biểu diễn nổi bước tăng 8°/frame ở magnitude đó). Giữ góc trong [0,360) là hết.
-- (math.sin thì tự range-reduce nên các zone dùng sin — vd Zone 15 — không dính lỗi này.)
function Zone2Lasers.AngleDeg(now: number, rpm: number, dir: number): number
	local period = 60 / rpm -- giây cho 1 vòng
	return dir * 360 * ((now % period) / period)
end

-- Một part có phải là thanh laser (để bật/tắt sát thương) không.
function Zone2Lasers.IsBeam(part: BasePart, pivot: BasePart): boolean
	if part == pivot then
		return false
	end
	local lower = string.lower(part.Name)
	return string.find(lower, "beam", 1, true) ~= nil or string.find(lower, "laser", 1, true) ~= nil
end

return Zone2Lasers
