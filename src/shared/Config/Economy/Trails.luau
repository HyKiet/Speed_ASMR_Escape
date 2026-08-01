--!strict

local Gamepass = require(script.Parent.Gamepass)

export type TrailConfig = {
	id: string,
	name: string,
	multiplier: number,
	priceWins: number,
	priceRobux: number,
	-- Gamepass bán trail này. 0 = không bán bằng Robux.
	gamepassId: number,
	-- true = CHỈ mua bằng Robux (server từ chối mua bằng Wins, UI ẩn nút Wins).
	robuxOnly: boolean,
	-- Ảnh riêng của trail trong CosmeticModal. nil = dùng icon chung Theme.UI_ASSETS.Trail.
	icon: string?,
}

local Trails: { TrailConfig } = {
	-- Giá Robux + gamepassId khớp Creator Dashboard 2026-07-28. `priceRobux` chỉ là fallback
	-- khi fetch giá live lỗi — số hiển thị thật lấy từ MarketplaceService theo vùng.
	{ id = "trail_green",   name = "Green Trail",   multiplier = 1.5,  priceWins = 500,    priceRobux = 19,  gamepassId = Gamepass.GreenTrail,   robuxOnly = false, icon = "rbxassetid://111936705345914" },
	{ id = "trail_blue",    name = "Blue Trail",    multiplier = 2.0,  priceWins = 1500,   priceRobux = 39,  gamepassId = Gamepass.BlueTrail,    robuxOnly = false, icon = "rbxassetid://130967571306430" },
	{ id = "trail_purple",  name = "Purple Trail",  multiplier = 3.0,  priceWins = 5000,   priceRobux = 79,  gamepassId = Gamepass.PurpleTrail,  robuxOnly = false, icon = "rbxassetid://121735437317524" },
	{ id = "trail_red",     name = "Red Trail",     multiplier = 4.0,  priceWins = 25000,  priceRobux = 129, gamepassId = Gamepass.RedTrail,     robuxOnly = false, icon = "rbxassetid://96298714277525" },
	{ id = "trail_rainbow", name = "Rainbow Trail", multiplier = 5.0,  priceWins = 100000, priceRobux = 199, gamepassId = Gamepass.RainbowTrail, robuxOnly = false, icon = "rbxassetid://135589691416097" },
	{ id = "trail_galaxy",  name = "Galaxy Trail",  multiplier = 10.0, priceWins = 500000, priceRobux = 299, gamepassId = Gamepass.GalaxyTrail,  robuxOnly = false, icon = "rbxassetid://75951946143733" },

	-- Premium trails (Workspace.Lobby.TrailBase) — CHỈ mua bằng Robux (đồng bộ với Premium
	-- Auras, 2026-07-28). `priceWins` giữ nguyên làm lớp phòng thủ thứ 2 cho server, UI ẩn
	-- nút Wins nhờ `robuxOnly`.
	-- `id` khớp CHÍNH XÁC tên Folder trong TrailBase để PriceTagController map được billboard.
	{ id = "Mystic Violet Trail", name = "Mystic Violet Trail", multiplier = 15.0, priceWins = 1000000, priceRobux = 399, gamepassId = Gamepass.MysticVioletTrail, robuxOnly = true, icon = "rbxassetid://77136364491261" },
	{ id = "Golden Ray Trail",    name = "Golden Ray Trail",    multiplier = 22.0, priceWins = 2500000, priceRobux = 599, gamepassId = Gamepass.GoldenRayTrail,    robuxOnly = true, icon = "rbxassetid://97434068900616" },
	{ id = "Crimson Fury Trail",  name = "Crimson Fury Trail",  multiplier = 30.0, priceWins = 7500000, priceRobux = 899, gamepassId = Gamepass.CrimsonFuryTrail,  robuxOnly = true, icon = "rbxassetid://109080391627505" },
}

return Trails
