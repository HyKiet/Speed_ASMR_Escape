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

Zone2Lasers.Defaults = {
	LaserSweeper1 = { rpm = 18, dir = 1 },
	LaserSweeper2 = { rpm = 22, dir = -1 },
	Laser2_1 = { rpm = 28, dir = 1 },
	Laser2_2 = { rpm = 32, dir = -1 },
	Laser2_3 = { rpm = 38, dir = 1 },
} :: { [string]: LaserDefault }

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
