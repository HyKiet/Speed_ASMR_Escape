--!strict
-- ID Gamepass (Creator Dashboard — cập nhật 2026-07-06). Đặt 0 nếu chưa thiết lập.

local Gamepass = {
	DoubleSpeed = 1900262644, -- X2 Speed (3 R$)
	QuadSpeed = 1900160603, -- X4 Speed (9 R$)
	OctaSpeed = 1898810606, -- X8 Speed (27 R$)
	VIPMembership = 1899686706, -- VIP Membership (399 R$)
	AutoRebirth = 1899434608, -- Auto-Rebirth (99 R$)
	-- ExtraSpin ĐÃ GỠ (2026-07-31): lượt quay bán bằng Dev Product 1/5/10 Spins
	-- (xem Products.SPIN_PACKS) — không dựng thêm pass "quay 2 lần" chồng lên nữa.
	InfiniteRevives = 1930442093, -- Infinite Revives (249 R$)
	PurpleTreadmill = 1899470645, -- Purple Treadmill x3 (99 R$)
	BlueTreadmill = 1898588703, -- Blue Treadmill x9 (249 R$)
	GoldTreadmill = 1898528586, -- Gold Treadmill x25 (699 R$)
	RedAdminTreadmill = 1900262663, -- Red Admin Treadmill x100 (1299 R$)

	-- Cosmetic passes (AuraBase / TrailBase trong Lobby).
	-- ID từ Creator Dashboard 2026-07-15. Giá hiển thị lấy LIVE qua regional pricing.
	DarkAura = 1912234503, -- Dark Aura (299 R$)
	FlameAura = 1909292663, -- Flame Aura (499 R$)
	RedHeartAura = 1912096528, -- Red Heart Aura (799 R$)
	MysticVioletTrail = 1911802508, -- Mystic Violet Trail (399 R$)
	GoldenRayTrail = 1912472263, -- Golden Ray Trail (599 R$)
	CrimsonFuryTrail = 1911958542, -- Crimson Fury Trail (899 R$)

	-- Standard Trails / Auras — pass bán song song với giá Wins ("mua bằng Wins HOẶC Robux").
	-- ID từ Creator Dashboard 2026-07-28. Trước đây các món này để gamepassId = 0 nên nút
	-- Robux không bấm được dù `priceRobux` đã có số; giờ đã đủ ID cho cả 11 món.
	GreenTrail = 1928360029, -- Green Trail (19 R$)
	BlueTrail = 1928000089, -- Blue Trail (39 R$)
	PurpleTrail = 1927832085, -- Purple Trail (79 R$)
	RedTrail = 1928300077, -- Red Trail (129 R$)
	RainbowTrail = 1928324050, -- Rainbow Trail (199 R$)
	GalaxyTrail = 1928756071, -- Galaxy Trail (299 R$)

	BlueAura = 1930543869, -- Blue Aura (19 R$)
	RedAura = 1928120079, -- Red Aura (39 R$)
	CyanAura = 1927712117, -- Cyan Aura (69 R$)
	PurpleAura = 1928156055, -- Purple Aura (119 R$)
	PinkAura = 1930698462, -- Pink Aura (199 R$)
	-- Frozen Bloom KHÔNG có pass: độc quyền Speed Roulette (1%), không bán bằng bất kỳ tiền nào.
}

return Gamepass
