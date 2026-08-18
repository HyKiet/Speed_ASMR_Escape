--!strict
-- SlimeJelly — 🧽 Slime Dẻo Quánh: khối slime bóng lún sụt sâu nhất 60%,
-- phình biến dạng ngang 25%, hồi phục dẻo (RECOVER 1.3). Âm wobble ướt + squish
-- đầm tay, binaural đảo tai L/R "Clean Your Brain" qua SquishFloor.

local SquishFloor = require(script.Parent.Parent.Engine.SquishFloor)

return SquishFloor.make({
	name = "SlimeJelly",
	-- ÂM THANH: HOÀN NGUYÊN HỆ CŨ (2026-08-07, yêu cầu user).
	-- Bản 2026-08-05 rút về MỘT mẫu duy nhất (uniformSound) + speedMix. User đối chiếu với
	-- các sàn còn giữ hệ cũ (Zone 5 PopIt, Zone 7 Jelly, Zone 8 SqueakyDuck, Zone 9 AquaRun)
	-- và chốt hệ CŨ hay hơn hẳn: bốc ngẫu nhiên trong palette + rung cao độ mỗi bước.
	-- ĐÃ BỎ 9114520014 "Food Valley 11" — mẫu splat mà user chê riêng, không nằm trong
	-- phần hoàn nguyên (giống cách SqueakyDuck vẫn bỏ "Suction Pop 2" sau khi hoàn nguyên).
	--
	-- Mix ASMR ÊM DỊU: slime chính (user chọn) + Slime 2 + Gooshy Grab — toàn âm ướt trầm,
	-- không splat/pop đanh. 3 mẫu × 4 giọng mặc định = 12 giọng thật, không cần khai `voices`.
	soundIds = { 133222321566847, 76169806288463, 9114631918 },
	-- 2026-07-24: user muốn squish/dẻo MẠNH và RÕ hơn. Khối cao 1.5, WalkSurface ở
	-- tileTop−0.52 ⇒ lún 0.76×1.5 = 1.14 studs, sâu hơn hẳn mặt chân đứng → thấy rõ
	-- hố slime dưới bàn chân. Bulge 0.45 = khối bè ra như slime thật khi bị đè.
	radius = 6.5, -- phủ gần trọn pitch 6.6 → cả cụm quanh chân cùng lún, không lẻ 1 ô
	-- 6.5 được chỉnh cho ô 6.4 (Zone 4). Zone 14 dùng pad slime to 12 studs → bán kính tự
	-- giãn theo cỡ ô, nếu không thì đứng giữa 2 pad là ngoài tầm, không pad nào lún.
	radiusRef = 6.4,
	maxSquish = 0.76,
	bulge = 0.45,
	pressRate = 13,
	recoverRate = 1.0, -- hồi chậm hơn: dai, quánh
	jiggle = { amp = 0.45, freq = 10, decay = 2.8 }, -- rung dư chấn lâu + biên độ gấp đôi
	pitchMin = 0.84,
	pitchMax = 1.0,
	-- ÂM LƯỢNG: giữ phần sửa 2026-08-05 (user: "sàn squish quá nhỏ, không tương đồng các
	-- sàn khác") — đó là phản hồi RIÊNG về độ to, không nằm trong phần hoàn nguyên.
	-- Bản cũ để 0.60/0.50, thấp nhất bảng. Chốt đúng bằng SqueakyDuck và Orbeez — chính
	-- hai sàn user lấy làm chuẩn "nghe hay". (Không còn speedMix ×1.6 nhân thêm nữa nên
	-- 0.78/0.70 của bản uniform sẽ thành to lố so với nhóm kia.)
	volumeEnter = 0.7,
	volumeStep = 0.6,
})
