-- Orbeez — 🫧 Hồ Hạt Nước (water beads): thảm sphere mesh bóng ướt nhiều màu pastel
-- (ProgramSquidMeshPackV2, mesh 119645107654187, chìm nửa thân). Chân dậm hạt LÚN 45%,
-- phình mọng 40%, nảy rung tắt dần như gel — kèm SÁNG BỪNG trắng rồi nguội dần.
-- Âm "brain massage": bloop nước + squish ướt đầm, binaural đảo tai L/R mỗi bước
-- (Clean Your Brain), pitch rộng 0.90–1.12 → lách tách như vốc cả nắm orbeez.
-- Toàn bộ sound đã dùng ở CrystalDrop/SlimeJelly (vet sẵn, preload chung, 0 id mới).

local SquishFloor = require(script.Parent.Parent.Engine.SquishFloor)

return SquishFloor.make({
	name = "Orbeez",
	-- Mix ASMR: Bubble Bloop + Drip Plop + Mouth Pop + Suction Pop + slime ướt + Wood Bowl
	-- Blip — hạt nước lách tách đa chất liệu phê tai
	soundIds = { 9112751536, 9114175929, 9117019900, 9119669295, 133222321566847, 9120519525 },
	radius = 4.6,
	-- hạt chìm nửa thân trong đảo: lún 45% ≈ đỉnh hạt tụt xuống ngang mặt sàn
	maxSquish = 0.45,
	bulge = 0.45,
	pressRate = 16,
	recoverRate = 2.0,
	jiggle = { amp = 0.45, freq = 18, decay = 5 }, -- gel nảy ướt khi chân rời
	litColor = Color3.fromRGB(255, 255, 255), -- hạt loé sáng theo độ lún (mọi màu → trắng)
	pitchMin = 0.92,
	pitchMax = 1.1,
	volumeEnter = 0.7,
	volumeStep = 0.6,
})
