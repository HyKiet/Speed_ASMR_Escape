-- CrystalDrop — 💧 Sàn Pha Lê Giọt Nước "Clean Your Brain": ô glass lún nhẹ 18%,
-- nảy lại nhanh, ô SÁNG BỪNG màu cyan băng theo độ lún rồi tắt dần (Color lerp).
-- Âm: giọt nước rơi vào bát sứ/bát gỗ + bubble bloop (ProSoundEffects Water-Drips)
-- — chính là bộ âm trend TikTok, binaural đảo tai L/R, pitch rộng 0.92–1.14 lấp lánh.

local SquishFloor = require(script.Parent.Parent.Engine.SquishFloor)

return SquishFloor.make({
	name = "CrystalDrop",
	-- Mix ASMR: Ceramic Bowl Pings 32/23, Wood Bowl Blip 6, Bubble Bloop Cute, Drip Plop 5
	-- + Mouth Pop PSE — lấp lánh đa chất liệu phê tai
	soundIds = { 9120518531, 9120517888, 9120519525, 9112751536, 9114175929, 9117020299 },
	radius = 4.2, -- bán kính sát chân hơn
	maxSquish = 0.18,
	bulge = 0.04,
	pressRate = 22,
	recoverRate = 3.2,
	jiggle = { amp = 0.35, freq = 26, decay = 7 }, -- rung pha lê tinh khi chân rời
	litColor = Color3.fromRGB(190, 255, 255),
	pitchMin = 0.92,
	pitchMax = 1.14,
	volumeEnter = 0.6,
	volumeStep = 0.55,
})
