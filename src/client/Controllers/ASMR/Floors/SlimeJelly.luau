-- SlimeJelly — 🧽 Slime Dẻo Quánh: khối slime bóng lún sụt sâu nhất 60%,
-- phình biến dạng ngang 25%, hồi phục dẻo (RECOVER 1.3). Âm wobble ướt + squish
-- đầm tay, binaural đảo tai L/R "Clean Your Brain" qua SquishFloor.

local SquishFloor = require(script.Parent.Parent.Engine.SquishFloor)

return SquishFloor.make({
	name = "SlimeJelly",
	-- Mix ASMR ÊM DỊU (user chê splat/pop sắc quá): slime chính (user chọn) + Slime 2
	-- + Gooshy Grab + Food Valley 11 — toàn âm ướt trầm, không splat/pop đanh
	soundIds = { 133222321566847, 76169806288463, 9114631918, 9114520014 },
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
	volumeEnter = 0.6,
	volumeStep = 0.5,
})
