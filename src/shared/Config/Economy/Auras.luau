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
	-- true = KHÔNG bán bằng bất cứ đường nào, chỉ được TRAO (đối xứng với TrailConfig).
	-- Server kiểm tường minh ở ProgressionService; đừng dựa vào con số giá.
	dailyOnly: boolean?,
	-- Ảnh riêng của aura trong CosmeticModal. nil = dùng icon chung Theme.UI_ASSETS.Aura.
	icon: string?,
	-- Nhãn NGUỒN GỐC hiện trong CosmeticModal khi món chưa sở hữu và không bán được.
	-- Bỏ trống thì modal tự suy: dailyOnly ⇒ "DAY 7 STREAK", còn lại ⇒ "SPIN ONLY". Món nào
	-- không đến từ hai nguồn đó thì BẮT BUỘC tự khai, nếu không UI chỉ sai người chơi đi cày
	-- nhầm chỗ (xem chú thích cùng tên trong Trails.luau).
	sourceLabel: string?,
	sourceIcon: string?,
}

local Auras: { AuraConfig } = {
	-- Giá Robux + gamepassId khớp Creator Dashboard 2026-07-28. `priceRobux` chỉ là fallback
	-- khi fetch giá live lỗi — số hiển thị thật lấy từ MarketplaceService theo vùng.
	{
		id = "aura_sparkle",
		name = "Blue Aura",
		multiplier = 1.2,
		priceWins = 200,
		priceRobux = 19,
		gamepassId = Gamepass.BlueAura,
		robuxOnly = false,
		icon = "rbxassetid://107552777272624",
	},
	{
		id = "aura_fire",
		name = "Red Aura",
		multiplier = 1.8,
		priceWins = 2000,
		priceRobux = 39,
		gamepassId = Gamepass.RedAura,
		robuxOnly = false,
		icon = "rbxassetid://113845846916391",
	},
	{
		id = "aura_lightning",
		name = "Cyan Aura",
		multiplier = 2.5,
		priceWins = 8000,
		priceRobux = 69,
		gamepassId = Gamepass.CyanAura,
		robuxOnly = false,
		icon = "rbxassetid://102006106200647",
	},
	{
		id = "aura_void",
		name = "Purple Aura",
		multiplier = 4.5,
		priceWins = 40000,
		priceRobux = 119,
		gamepassId = Gamepass.PurpleAura,
		robuxOnly = false,
		icon = "rbxassetid://114605089289156",
	},
	{
		id = "aura_cosmic",
		name = "Pink Aura",
		multiplier = 8.0,
		priceWins = 200000,
		priceRobux = 199,
		gamepassId = Gamepass.PinkAura,
		robuxOnly = false,
		icon = "rbxassetid://122735408670566",
	},
	--[[
		ĐỘC QUYỀN SPEED ROULETTE (Legendary 1%) — KHÔNG bán bằng Wins lẫn Robux.
		`priceWins` 999999999 là chốt chặn để server từ chối lệnh mua bằng Wins; `priceRobux`
		và `gamepassId` đều 0 nên PriceTagController cũng không dựng billboard giá cho nó.

		x3.5 → x10.0 (2026-08-09). GDD ghi x3.5, tức là YẾU HƠN Purple Aura (x4.5, mua thẳng
		bằng 40.000 Wins) — một món rơi 1% mà thua món ai cũng cày được thì phần thưởng
		jackpot hoá ra là phần thưởng an ủi.

		Vì sao chốt đúng 10.0 chứ không cao hơn — nó phải lọt vào ĐÚNG khe giữa hai tầng:
		  • TRÊN mọi aura mua được bằng Wins (mạnh nhất là Pink x8.0) ⇒ đây là aura mạnh nhất
		    mà người chơi F2P có thể sở hữu, đúng cảm giác "trúng số".
		  • DƯỚI tầng premium bán bằng Robux (Dark x12 / Flame x18 / Red Heart x25) ⇒ không
		    ăn vào doanh thu. Đẩy lên 12 là ngang Dark Aura 299 R$, tức tự tay phá giá
		    gamepass rẻ nhất của tầng đó.
		Trung bình cần ~100 lượt quay mới ra, nên x10 không hề rẻ.
	]]
	{
		id = "aura_frozen_bloom",
		name = "Frozen Bloom",
		multiplier = 10.0,
		priceWins = 999999999,
		priceRobux = 0,
		gamepassId = 0,
		robuxOnly = false,
		spinOnly = true,
		icon = "rbxassetid://108748255826046",
	},

	--[[
		VIP GOLD AURA — độc quyền VIP Membership (399 R$), KHÔNG bán rời.

		HỆ SỐ 6.0, và ở đây nó cố ý THẤP HƠN Pink Aura x8.0 (200.000 Wins / 199 R$) — khác
		với trail VIP vốn nhỉnh hơn Rainbow. Lý do: người mua VIP nhận CẢ trail lẫn aura, tức
		xô Cosmetic của họ đã là 1 + 5 + 5 = x11 khi tay trắng. Nếu aura VIP còn vượt luôn
		Pink thì aura mạnh nhất mà người F2P cày được trở thành vô nghĩa với mọi người mua
		VIP, và cái đích 200.000 Wins — một trong những sink Wins lớn nhất game — mất người
		theo đuổi. x6.0 vẫn trên Purple x4.5 nên vẫn là món đáng khoe.

		Trần premium (Dark x12 / Flame x18 / Red Heart x25) không bị đụng tới.

		Rig VFX riêng `Aura_Vip` nằm trong ReplicatedStorage.CosmeticTemplates — dựng từ model
		`Aura_SusanooArms`, đã gỡ hai cánh tay (10 Beam + 2 cụm lửa gốc tay) và nhuộm vàng ròng
		trên nền tím hoàng gia.
		⚠️ Rig riêng thì KHÔNG được rơi về aura standard khi thiếu rig — xem nhánh RIG_AURAS
		trong CosmeticVisualController và bài học Frozen Bloom ghi ngay tại đó.
	]]
	{
		id = "aura_vip",
		name = "VIP Gold Aura",
		multiplier = 6.0,
		priceWins = 999999999,
		priceRobux = 0,
		gamepassId = 0,
		robuxOnly = false,
		dailyOnly = true,
		icon = "rbxassetid://105776222512667",
		sourceLabel = "VIP MEMBERSHIP",
		sourceIcon = "rbxassetid://105776222512667",
	},

	-- Premium auras (Workspace.Lobby.AuraBase) — CHỈ mua bằng Robux.
	-- `id` khớp CHÍNH XÁC tên Folder trong AuraBase để PriceTagController map được billboard.
	-- `icon` lấy từ billboard tương ứng trong Workspace.Lobby.AuraBase để UI và biển ngoài
	-- lobby dùng CHUNG một ảnh (trước đây 3 món này không có icon nên banner chúc mừng rơi về
	-- icon tia sét chung — xem BoostCelebration).
	{
		id = "RedHeart",
		name = "Red Heart Aura",
		multiplier = 25.0,
		priceWins = 5000000,
		priceRobux = 799,
		gamepassId = Gamepass.RedHeartAura,
		robuxOnly = true,
		icon = "rbxassetid://137619666833331",
	},
	{
		id = "Flame",
		name = "Flame Aura",
		multiplier = 18.0,
		priceWins = 1500000,
		priceRobux = 499,
		gamepassId = Gamepass.FlameAura,
		robuxOnly = true,
		icon = "rbxassetid://115012781363807",
	},
	{
		id = "Dark",
		name = "Dark Aura",
		multiplier = 12.0,
		priceWins = 500000,
		priceRobux = 299,
		gamepassId = Gamepass.DarkAura,
		robuxOnly = true,
		icon = "rbxassetid://128551455361742",
	},
}

return Auras
