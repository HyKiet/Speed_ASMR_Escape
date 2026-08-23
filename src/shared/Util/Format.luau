--!strict
-- Format số lớn cho UI.

local Format = {}

function Format.Number(value: number): string
	if value < 1000 then
		return tostring(math.floor(value))
	elseif value < 1_000_000 then
		return string.format("%.2fK", value / 1_000)
	elseif value < 1_000_000_000 then
		return string.format("%.2fM", value / 1_000_000)
	elseif value < 1_000_000_000_000 then
		return string.format("%.2fB", value / 1_000_000_000)
	else
		return string.format("%.2fT", value / 1_000_000_000_000)
	end
end

--[[
	HỆ SỐ NHÂN cho UI — "1.1", "1.25", "2", KHÔNG BAO GIỜ "1.100000023841858".

	⚠️ Bug user báo 2026-08-21 (bảng Friends Boost): `"x" .. mult` in ra
	`x1.100000023841858`. Không phải lỗi tính toán — server tính đúng 1.1, nhưng số đi qua
	ByteNet dưới dạng **float32**, mà 1.1 không biểu diễn chính xác được bằng float32. Client
	nhận về rồi nới lên float64 nên lòi ra đuôi rác, và `tostring` in đủ 16 chữ số.

	Vì vậy: MỌI hệ số nhân hiện lên UI phải đi qua hàm này. Nối chuỗi thẳng bằng `..` là sai
	ở mọi chỗ, không riêng Friends — cùng một cái bẫy đang chờ ở Playtime, VIP, Server Boost.

	Làm tròn 2 chữ số rồi CẮT số 0 thừa: 1.1 → "1.1" (không phải "1.10"), 2 → "2", 1.25 → "1.25".
]]
function Format.Multiplier(value: number): string
	local text = string.format("%.2f", value)
	-- Cắt "0" ở đuôi, rồi cắt luôn dấu chấm nếu không còn phần thập phân.
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

return Format
