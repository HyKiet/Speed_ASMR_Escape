--!strict

local Gamepass = require(script.Parent.Gamepass)

export type AuraConfig = {
	id: string,
	name: string,
	multiplier: number,
	priceWins: number,
	priceRobux: number,
	-- Gamepass bán aura này. 0 = không bán bằng Robux.
	gamepassId: number,
	-- true = CHỈ mua bằng Robux (server từ chối mua bằng Wins, UI ẩn nút Wins).
	-- priceWins vẫn giữ giá trị cũ làm lớp phòng thủ thứ 2, không bao giờ dùng tới.
	robuxOnly: boolean,
	-- true = KHÔNG bán, chỉ rơi từ Speed Roulette. UI ẩn cả hai nút mua và hiện "SPIN ONLY".
	spinOnly: boolean?,
	-- Ảnh riêng của aura trong CosmeticModal. nil = dùng icon chung Theme.UI_ASSETS.Aura.
	icon: string?,
}

local Auras: { AuraConfig } = {
	-- Giá Robux + gamepassId khớp Creator Dashboard 2026-07-28. `priceRobux` chỉ là fallback
	-- khi fetch giá live lỗi — số hiển thị thật lấy từ MarketplaceService theo vùng.
	{ id = "aura_sparkle",   name = "Blue Aura",      multiplier = 1.2, priceWins = 200,    priceRobux = 19,  gamepassId = Gamepass.BlueAura,   robuxOnly = false, icon = "rbxassetid://107552777272624" },
	{ id = "aura_fire",      name = "Red Aura",       multiplier = 1.8, priceWins = 2000,   priceRobux = 39,  gamepassId = Gamepass.RedAura,    robuxOnly = false, icon = "rbxassetid://113845846916391" },
	{ id = "aura_lightning", name = "Cyan Aura",      multiplier = 2.5, priceWins = 8000,   priceRobux = 69,  gamepassId = Gamepass.CyanAura,   robuxOnly = false, icon = "rbxassetid://102006106200647" },
	{ id = "aura_void",      name = "Purple Aura",    multiplier = 4.5, priceWins = 40000,  priceRobux = 119, gamepassId = Gamepass.PurpleAura, robuxOnly = false, icon = "rbxassetid://114605089289156" },
	{ id = "aura_cosmic",    name = "Pink Aura",      multiplier = 8.0, priceWins = 200000, priceRobux = 199, gamepassId = Gamepass.PinkAura,   robuxOnly = false, icon = "rbxassetid://122735408670566" },
	-- ĐỘC QUYỀN SPEED ROULETTE (Legendary 1%) — KHÔNG bán bằng Wins lẫn Robux.
	-- `priceWins` 999999999 là chốt chặn để server từ chối lệnh mua bằng Wins; `priceRobux`
	-- và `gamepassId` đều 0 nên PriceTagController cũng không dựng billboard giá cho nó.
	{ id = "aura_frozen_bloom", name = "Frozen Bloom", multiplier = 3.5, priceWins = 999999999, priceRobux = 0, gamepassId = 0, robuxOnly = false, spinOnly = true },



	-- Premium auras (Workspace.Lobby.AuraBase) — CHỈ mua bằng Robux.
	-- `id` khớp CHÍNH XÁC tên Folder trong AuraBase để PriceTagController map được billboard.
	-- `icon` lấy từ billboard tương ứng trong Workspace.Lobby.AuraBase để UI và biển ngoài
	-- lobby dùng CHUNG một ảnh (trước đây 3 món này không có icon nên banner chúc mừng rơi về
	-- icon tia sét chung — xem BoostCelebration).
	{ id = "RedHeart",       name = "Red Heart Aura", multiplier = 25.0, priceWins = 5000000, priceRobux = 799, gamepassId = Gamepass.RedHeartAura,  robuxOnly = true, icon = "rbxassetid://137619666833331" },
	{ id = "Flame",          name = "Flame Aura",     multiplier = 18.0, priceWins = 1500000, priceRobux = 499, gamepassId = Gamepass.FlameAura,     robuxOnly = true, icon = "rbxassetid://115012781363807" },
	{ id = "Dark",           name = "Dark Aura",      multiplier = 12.0, priceWins = 500000,  priceRobux = 299, gamepassId = Gamepass.DarkAura,      robuxOnly = true, icon = "rbxassetid://128551455361742" },
}


return Auras
