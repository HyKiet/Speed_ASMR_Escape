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
	-- true = KHÔNG bán bằng bất cứ đường nào; chỉ rơi từ chuỗi điểm danh 7 ngày.
	dailyOnly: boolean?,
	-- Ảnh riêng của trail trong CosmeticModal. nil = dùng icon chung Theme.UI_ASSETS.Trail.
	icon: string?,
	--[[
		Nhãn NGUỒN GỐC hiện trong CosmeticModal khi món chưa sở hữu và không bán được
		(`dailyOnly`/`spinOnly`). Bỏ trống thì modal tự suy: dailyOnly ⇒ "DAY 7 STREAK".
		Phải điền cho món dùng `dailyOnly` mà KHÔNG đến từ chuỗi điểm danh — cờ đó chỉ có
		nghĩa "không bán, chỉ được trao".
	]]
	sourceLabel: string?,
	sourceIcon: string?,
}

local Trails: { TrailConfig } = {
	-- Giá Robux + gamepassId khớp Creator Dashboard 2026-07-28. `priceRobux` chỉ là fallback
	-- khi fetch giá live lỗi — số hiển thị thật lấy từ MarketplaceService theo vùng.
	{
		id = "trail_green",
		name = "Green Trail",
		multiplier = 1.5,
		priceWins = 500,
		priceRobux = 19,
		gamepassId = Gamepass.GreenTrail,
		robuxOnly = false,
		icon = "rbxassetid://111936705345914",
	},
	{
		id = "trail_blue",
		name = "Blue Trail",
		multiplier = 2.0,
		priceWins = 1500,
		priceRobux = 39,
		gamepassId = Gamepass.BlueTrail,
		robuxOnly = false,
		icon = "rbxassetid://130967571306430",
	},
	{
		id = "trail_purple",
		name = "Purple Trail",
		multiplier = 3.0,
		priceWins = 5000,
		priceRobux = 79,
		gamepassId = Gamepass.PurpleTrail,
		robuxOnly = false,
		icon = "rbxassetid://121735437317524",
	},
	{
		id = "trail_red",
		name = "Red Trail",
		multiplier = 4.0,
		priceWins = 25000,
		priceRobux = 129,
		gamepassId = Gamepass.RedTrail,
		robuxOnly = false,
		icon = "rbxassetid://96298714277525",
	},
	{
		id = "trail_rainbow",
		name = "Rainbow Trail",
		multiplier = 5.0,
		priceWins = 100000,
		priceRobux = 199,
		gamepassId = Gamepass.RainbowTrail,
		robuxOnly = false,
		icon = "rbxassetid://135589691416097",
	},
	{
		id = "trail_galaxy",
		name = "Galaxy Trail",
		multiplier = 10.0,
		priceWins = 500000,
		priceRobux = 299,
		gamepassId = Gamepass.GalaxyTrail,
		robuxOnly = false,
		icon = "rbxassetid://75951946143733",
	},

	--[[
		TRAIL ĐỘC QUYỀN ĐIỂM DANH — không bán, không bao giờ.

		Phần thưởng Ngày 7 của chuỗi hardcore (lỡ một ngày là reset về Ngày 1). Đây là món
		duy nhất trong game không mua được bằng Wins lẫn Robux, nên nó làm đúng một việc:
		cho người chơi một lý do quay lại bảy hôm liền.

		HỆ SỐ 5.0 — nâng từ 2.5 (2026-08-10). Mức 2.5 đặt nó giữa Blue (2.0) và Purple (3.0),
		mà Purple chỉ tốn 5.000 Wins: tới ngày thứ 7 thì gần như người chơi nào cũng đã mua
		nổi Purple, nên phần thưởng của bảy ngày kiên trì hoá ra là một món YẾU HƠN thứ họ
		đang đeo. Phần thưởng dưới mức kỳ vọng còn hại hơn không có phần thưởng.

		5.0 ngang Rainbow Trail (100.000 Wins / 199 R$) — đọc ra là "món 199 R$", xứng với
		bảy ngày đăng nhập liên tục. Trần vẫn còn nguyên: Galaxy 10.0 và ba trail Robux-only
		15.0/22.0/30.0 không bị đụng tới, nên đường bán hàng cao cấp không suy chuyển.

		Đánh đổi đã cân nhắc: người đáng lẽ mua Rainbow 199 R$ giờ có thể nhận không. Chấp
		nhận, vì nhóm đi trọn 7 ngày chính là nhóm gắn bó nhất — giữ được họ đáng giá hơn
		vài lần bán lẻ, và họ vẫn còn Galaxy + premium để tiêu tiền.

		`priceWins`/`priceRobux` = 0 chỉ là giá trị trống; chốt chặn thật là `dailyOnly` được
		kiểm tường minh ở ProgressionService (đừng bao giờ dựa vào con số giá).
	]]
	{
		id = "trail_streak_aurora",
		name = "Streak Aurora",
		multiplier = 5.0,
		priceWins = 0,
		priceRobux = 0,
		gamepassId = 0,
		robuxOnly = false,
		dailyOnly = true,
		-- Icon riêng của trail, upload 2026-08-20 (asset "Streak Auora Trail" 75078805622702).
		-- Đây là nguồn DUY NHẤT cho icon món này: CosmeticModal đọc thẳng từ đây, và DailyModal
		-- cũng lấy từ đây thay vì icon trail chung — đổi một chỗ là cả hai nơi theo.
		icon = "rbxassetid://75078805622702",
	},

	--[[
		ROOKIE ROCKET — trail độc quyền của Starter Pack, KHÔNG bán ở bất cứ đâu khác. Đây là
		thứ duy nhất trong gói không mua lại được bằng đường nào, nên nó gánh phần "sợ bỏ lỡ"
		của cả gói mà không tốn một đồng nào của nền kinh tế (cosmetic không sinh Wins/Speed
		ngoài hệ số của chính nó).

		`multiplier` 2.5 đặt NGANG tầm trail hạng trung (Purple 2.5) chứ không phải hạng cao:
		gói 99 R$ mà cho hệ số mạnh hơn trail bán 79-199 R$ thì mọi trail trong shop thành vô
		nghĩa với người mua gói.

		Dùng lại `dailyOnly = true` — cờ này ở ProgressionService nghĩa là "KHÔNG bán bằng Wins
		lẫn Robux, chỉ được trao", đúng luật cần cho trail này. Đổi tên cờ thì phải sửa cả chỗ
		kiểm ở ProgressionService lẫn Streak Aurora, nên giữ nguyên.
	]]
	{
		id = "trail_rookie",
		name = "Rookie Rocket",
		multiplier = 2.5,
		priceWins = 0,
		priceRobux = 0,
		gamepassId = 0,
		robuxOnly = false,
		dailyOnly = true,
		-- Icon riêng (upload 2026-08-11). Trước đó mượn tạm `UI_ASSETS.Trail` nên trong menu
		-- Cosmetics nó trùng icon với mọi trail thường — món độc quyền mà không có mặt riêng.
		icon = "rbxassetid://111904416531019",
		-- Nguồn thật của món này là Starter Pack, không phải chuỗi điểm danh (xem ghi chú ở
		-- `sourceLabel` trong type). Icon = ảnh gói, cùng ảnh đang hiện trên HUD.
		sourceLabel = "STARTER PACK",
		sourceIcon = "rbxassetid://139598685571792",
	},

	--[[
		VIP GOLD — trail độc quyền của VIP Membership (399 R$). KHÔNG bán rời ở bất cứ đâu.

		HỆ SỐ 6.0 nằm lọt đúng khe giữa hai tầng đang bán, và cả hai mép đều có lý do:
		  • TRÊN Rainbow x5.0 (100.000 Wins / 199 R$) — người bỏ 399 R$ phải nhận được thứ
		    mạnh hơn món 199 R$, nếu không gói VIP tự nó vô nghĩa.
		  • DƯỚI Galaxy x10.0 (299 R$) và cả ba trail premium x15/x22/x30 — đường bán hàng
		    cao cấp không bị đụng tới một chút nào.

		Cosmetic KHÔNG sinh Wins/Speed ngoài hệ số của chính nó, nên đây là quyền lợi có giá
		trị khoe cao nhất mà tốn của nền kinh tế ít nhất — đúng vai trò Rookie Rocket đang
		gánh cho Starter Pack.

		`dailyOnly = true` ở đây KHÔNG có nghĩa "chuỗi điểm danh" — cờ này ở ProgressionService
		nghĩa là "không bán bằng Wins lẫn Robux, chỉ được trao" (xem chú thích ở `sourceLabel`).
		Đường trao duy nhất: `GamepassService.grantVipCosmetics` khi xác nhận sở hữu pass VIP.
	]]
	{
		id = "trail_vip",
		name = "VIP Gold Trail",
		multiplier = 6.0,
		priceWins = 0,
		priceRobux = 0,
		gamepassId = 0,
		robuxOnly = false,
		dailyOnly = true,
		icon = "rbxassetid://105776222512667",
		sourceLabel = "VIP MEMBERSHIP",
		sourceIcon = "rbxassetid://105776222512667",
	},

	-- Premium trails (Workspace.Lobby.TrailBase) — CHỈ mua bằng Robux (đồng bộ với Premium
	-- Auras, 2026-07-28). `priceWins` giữ nguyên làm lớp phòng thủ thứ 2 cho server, UI ẩn
	-- nút Wins nhờ `robuxOnly`.
	-- `id` khớp CHÍNH XÁC tên Folder trong TrailBase để PriceTagController map được billboard.
	{
		id = "Mystic Violet Trail",
		name = "Mystic Violet Trail",
		multiplier = 15.0,
		priceWins = 1000000,
		priceRobux = 399,
		gamepassId = Gamepass.MysticVioletTrail,
		robuxOnly = true,
		icon = "rbxassetid://77136364491261",
	},
	{
		id = "Golden Ray Trail",
		name = "Golden Ray Trail",
		multiplier = 22.0,
		priceWins = 2500000,
		priceRobux = 599,
		gamepassId = Gamepass.GoldenRayTrail,
		robuxOnly = true,
		icon = "rbxassetid://97434068900616",
	},
	{
		id = "Crimson Fury Trail",
		name = "Crimson Fury Trail",
		multiplier = 30.0,
		priceWins = 7500000,
		priceRobux = 899,
		gamepassId = Gamepass.CrimsonFuryTrail,
		robuxOnly = true,
		icon = "rbxassetid://109080391627505",
	},
}

return Trails
