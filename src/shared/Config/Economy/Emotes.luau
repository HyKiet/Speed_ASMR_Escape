--!strict
-- ID sở hữu ổn định tách khỏi assetId: thay animation không làm mất món đã mua.

export type EmoteConfig = {
	id: string,
	displayName: string,
	assetId: number,
	priceWins: number,
}

local Catalog: { EmoteConfig } = {
	{ id = "inf_dab", displayName = "Inf Dab", assetId = 124025514802526, priceWins = 10 },
	{ id = "peter_parker", displayName = "Peter Parker", assetId = 84353557625484, priceWins = 250 },
	{ id = "kazotsky_kick", displayName = "Kazotsky Kick", assetId = 127417455814730, priceWins = 1_500 },
	{ id = "electro_shuffle", displayName = "Electro Shuffle", assetId = 139019092751385, priceWins = 7_500 },
	{ id = "electro_swing", displayName = "Electro Swing", assetId = 128276069142956, priceWins = 30_000 },
}

return {
	CATALOG = Catalog,
	RESERVED_PRICES = { 100_000, 400_000, 1_200_000, 3_000_000 },
}
