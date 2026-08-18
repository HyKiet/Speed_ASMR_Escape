--!strict
-- ID Developer Product (Creator Dashboard — cập nhật 2026-07-06).

export type SpinPack = {
	productId: number,
	spins: number,
	priceRobux: number,
}

local Products = {}

-- Wins Packs: productId → số Wins cộng thẳng
Products.WINS_PACKS = {
	[3608400621] = 1_000, -- Small Wins Pack (99 R$)
	[3608400807] = 10_000, -- Medium Wins Pack (299 R$)
	[3608401003] = 100_000, -- Large Wins Pack (699 R$)
	[3608401110] = 1_000_000, -- Ultra Wins Pack (1299 R$)
} :: { [number]: number }

-- Server Boosts (toàn máy chủ, 10 phút, cộng dồn khi mua chồng)
Products.SERVER_BOOST_SPEED_PRODUCT_ID = 3608407713 -- Server x2 Speed (99 R$)
Products.SERVER_BOOST_WINS_PRODUCT_ID = 3608407843 -- Server x2 Wins (99 R$)
Products.SERVER_BOOST_MEGA_PRODUCT_ID = 3608407916 -- MEGA Server Boost x2 Both (149 R$)
Products.SERVER_BOOST_DURATION_SECONDS = 600

-- Skip Rebirth (149 R$): trùng sinh ngay không cần đủ Level
Products.SKIP_REBIRTH_PRODUCT_ID = 3608406966

-- Gói lượt quay Roulette (Đã khởi tạo trên Creator Dashboard)
Products.SPIN_PACKS = {
	{ productId = 3610356888, spins = 1, priceRobux = 19 },
	{ productId = 3610357071, spins = 5, priceRobux = 79 },
	{ productId = 3610357149, spins = 10, priceRobux = 149 },
} :: { SpinPack }

return Products
