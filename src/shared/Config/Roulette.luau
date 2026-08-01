--!strict
-- Cấu hình Vòng quay May mắn (Speed Roulette) — 8 ô, tỷ lệ theo GDD_v2.
-- Thứ tự SLOTS xếp theo GIÁ TRỊ TĂNG DẦN: Extra Spin gamepass chọn slot index cao hơn.

export type RouletteSlot = {
	id: string,
	label: string,
	kind: "speed" | "wins" | "boostSpeed" | "boostWins" | "aura",
	-- speed/wins: lượng cộng thẳng; boost: số giây buff; aura: Wins đền bù nếu đã sở hữu
	amount: number,
	auraId: string?,
	weight: number,
	rarity: string,
	color: Color3,
}

local Roulette = {}

Roulette.FREE_TICKET_INTERVAL_SECONDS = 15 * 60 -- 15 phút online = 1 vé
Roulette.FREE_TICKET_STOCK_CAP = 3 -- vé miễn phí chỉ tích trữ tối đa 3
Roulette.MAX_TICKETS = 99 -- trần tuyệt đối (mua Robux/daily vẫn bị kẹp)

Roulette.SLOTS = {
	{ id = "wins_500", label = "+500 Wins", kind = "wins", amount = 500, weight = 25, rarity = "25%", color = Color3.fromRGB(255, 205, 46) },
	{ id = "speed_5k", label = "+5K Speed", kind = "speed", amount = 5_000, weight = 25, rarity = "25%", color = Color3.fromRGB(120, 200, 255) },
	{ id = "wins_2500", label = "+2.5K Wins", kind = "wins", amount = 2_500, weight = 15, rarity = "15%", color = Color3.fromRGB(104, 234, 95) },
	{ id = "boost_speed", label = "x2 Speed 10m", kind = "boostSpeed", amount = 600, weight = 15, rarity = "15%", color = Color3.fromRGB(72, 220, 200) },
	{ id = "boost_wins", label = "x2 Wins 10m", kind = "boostWins", amount = 600, weight = 10, rarity = "10%", color = Color3.fromRGB(90, 130, 255) },
	{ id = "wins_15k", label = "+15K Wins", kind = "wins", amount = 15_000, weight = 6, rarity = "6%", color = Color3.fromRGB(186, 90, 255) },
	{ id = "speed_100k", label = "+100K Speed", kind = "speed", amount = 100_000, weight = 3, rarity = "3%", color = Color3.fromRGB(255, 110, 80) },
	{ id = "aura_frozen_bloom", label = "FROZEN BLOOM", kind = "aura", auraId = "aura_frozen_bloom", amount = 50_000, weight = 1, rarity = "1%", color = Color3.fromRGB(255, 60, 180) },

} :: { RouletteSlot }



return Roulette
