-- SqueakyDuck — 🦆 Sàn Vịt Cao Su Chít Chít: đĩa cao su vàng bóng lún sâu 55% + phình 25%,
-- nảy lại nhanh như bóp đồ chơi. Mỗi bước = tiếng squeeze toy CHÍT CHÍT (ProSoundEffects
-- Squeaks) pitch đảo 0.9–1.12 — trigger gây nghiện kinh điển, binaural đảo tai L/R
-- liên hồi khi chạy nhanh = dàn vịt kêu vòng quanh đầu "Clean Your Brain".

local SquishFloor = require(script.Parent.Parent.Engine.SquishFloor)

return SquishFloor.make({
	name = "SqueakyDuck",
	-- Squeeze Toy Squeaky Rubber Noisemaker Hits 2/10/11/12/13 + Doll Squeaks 7
	-- Mix ASMR: 5 squeeze toy + doll squeak + mouth pop/suction pop — cao su đa chất liệu phê tai
	soundIds = { 9125994313, 9125994570, 9125994773, 9125994778, 9125994785, 9114123168, 9117848644, 9119669295 },
	radius = 4.4, -- bán kính sát chân hơn (mặc định 5.6)
	radiusRef = 3.9, -- 4.4 được chỉnh cho đĩa cỡ 3.9 → tự giãn khi vịt to lên (Z8/Z11 = 6.2)
	maxSquish = 0.62,
	bulge = 0.38, -- dãn ngang đã mắt hơn
	pressRate = 20,
	recoverRate = 3.0,
	jiggle = { amp = 0.5, freq = 18, decay = 5 }, -- nảy cao su rung 2-3 nhịp khi chân rời
	-- Zone 8/11 dùng MeshPart Duck (mỏng theo Y), bản test lobby vẫn là cylinder (mỏng theo X)
	-- → để engine tự dò trục cao cho từng sàn thay vì ép cứng.
	heightAxis = "auto",
	pitchMin = 0.9,
	pitchMax = 1.12,
	volumeEnter = 0.7,
	volumeStep = 0.6,
})
