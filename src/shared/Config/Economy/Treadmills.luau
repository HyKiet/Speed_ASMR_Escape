--!strict

export type TreadmillConfig = {
	id: string,
	name: string,
	multiplier: number,
	priceRobux: number,
	gamepassId: number, -- 0 = không bán (treadmill free)
}

-- Tên/giá/passId khớp Creator Dashboard (2026-07-06).
local Treadmills: { TreadmillConfig } = {
	{ id = "treadmill_1", name = "Wood Treadmill",       multiplier = 1.0,   priceRobux = 0,    gamepassId = 0 },
	{ id = "treadmill_2", name = "Purple Treadmill",     multiplier = 3.0,   priceRobux = 99,   gamepassId = 1899470645 },
	{ id = "treadmill_3", name = "Blue Treadmill",       multiplier = 9.0,   priceRobux = 249,  gamepassId = 1898588703 },
	{ id = "treadmill_4", name = "Gold Treadmill",       multiplier = 25.0,  priceRobux = 699,  gamepassId = 1898528586 },
	{ id = "treadmill_5", name = "Red Admin Treadmill",  multiplier = 100.0, priceRobux = 1299, gamepassId = 1900262663 },
}

return Treadmills
