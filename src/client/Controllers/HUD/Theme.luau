--!strict
--[[
	Theme: asset id, bảng cấu hình, và các factory helper dựng UI (Fusion).
	Không giữ state — chỉ trả về Instance khi gọi.

	⚠️ HẰNG SỐ DÙNG CHUNG KHÔNG CÒN Ở ĐÂY. Chúng đã dọn sang `Tokens.luau` (2026-08-16) — font,
	độ dày viền, bán kính bo góc, tầng Z, nhịp tween, số đo khuôn modal, màu dùng chung. Phần
	dưới đây chỉ XUẤT LẠI chúng dưới tên cũ (`Theme.FONT`, `Theme.BORDER`…) để ~40 file đang gọi
	không phải sửa một dòng nào.

	Code MỚI nên `require` thẳng `Tokens` thay vì đi vòng qua `Theme`: `Tokens` không require gì
	cả nên nạp nó không kéo theo cả nghìn dòng factory này.
]]

-- ⚠️ `GuiService` / `Workspace` / `UserInputService` đã BỎ khỏi file này (2026-08-17): việc đọc
-- viewport, topbar và loại thiết bị giờ nằm trọn trong `HUD/Responsive`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Responsive = require(script.Parent.Responsive)
local State = require(script.Parent.State)
local Tokens = require(script.Parent.Tokens)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Out = Fusion.Out
local Tween = Fusion.Tween
local Value = Fusion.Value

local Theme = {}

--[[
	Hiệu ứng rê chuột + BẤM cho button. Trả về UIScale, đặt vào `[Children]` của nút.

	── THÊM PHẢN HỒI KHI BẤM (2026-08-14, theo "UI Animation Pack - by JakeDev") ────────────
	Pack đó dùng ba mức: thường 1.0 → rê chuột 1.1 → bấm 0.9 rồi bật lại 1.0, tween 0.2s Quad.
	Cái game này trước giờ CHỈ có mức rê chuột; bấm xong không có gì nhúc nhích, nên trên điện
	thoại (không hề có trạng thái "rê chuột") mọi nút đều hoàn toàn câm khi chạm — người chơi
	không biết cú chạm đã ăn hay chưa. Đó là lý do phần "bấm" quan trọng hơn phần "rê" ở đây.

	⚠️ Co giãn bằng `UIScale`, KHÔNG tween `Size` như script trong pack. Nút trong game này
	nằm trong `UIGridLayout`/`UIListLayout`; đổi `Size` là cả lưới nhảy theo mỗi lần rê chuột.
	`UIScale` chỉ ảnh hưởng lúc VẼ nên bố cục đứng yên.

	⚠️ `TweenInfo` phải là giá trị THƯỜNG, không được truyền `Computed` vào — `Fusion.Tween`
	của Fusion 0.2 chỉ nhận TweenInfo tĩnh. Nên dùng một nhịp duy nhất cho cả rê lẫn bấm;
	`Back` lúc thu nhỏ vọt nhẹ xuống dưới 0.9 rồi bật lại, và đó chính là cảm giác "nhấn lún"
	mong muốn.
]]
Theme.PRESS_SCALE = Tokens.PRESS_SCALE

--[[
	══ KHUNG BỌC CHO HIỆU ỨNG PHÓNG — NỞ ĐỀU RA CẢ 4 GÓC ════════════════════════════════════

	Dùng cho những khối KHÔNG dựng bằng `MakeSurface` (tile menu, thẻ tự dựng…). Khối nào đi qua
	`MakeSurface` thì truyền `Zoom` cho nó, đừng gọi hàm này.

	Vì sao cần khung bọc thay vì gắn thẳng `UIScale`: `UIScale` phóng quanh `AnchorPoint` của
	chính khối. Nút trong game gần như luôn có `AnchorPoint = (0, 0)` nên nó nở sang PHẢI và
	XUỐNG DƯỚI — góc trái-trên đứng yên (user báo 2026-08-16: "zoom to ở 3 góc"). Mà cũng không
	đặt thẳng `AnchorPoint = (0.5, 0.5)` lên nó được: phần lớn nút nằm trong `UIListLayout` /
	`UIGridLayout`, và layout Roblox ghi `Position` mà KHÔNG bù `AnchorPoint` ⇒ nút lệch nửa thân.

	    host   (trong suốt, giữ đúng ô layout cấp — không bao giờ nhúc nhích)
	     └─ visual  (AnchorPoint 0.5/0.5, ở giữa host, lấp đầy host)
	          ├─ UIScale  ← phóng quanh TÂM ⇒ đều 4 góc
	          └─ Children (mọi thứ nhìn thấy)
]]
function Theme.MakeZoomHost(props: {
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	Visible: any?,
	Zoom: { Hovered: any, Scale: number?, Pressed: any? },
	Children: { any },
})
	local visualChildren: { any } = { Theme.HoverZoom(props.Zoom.Hovered, props.Zoom.Scale, props.Zoom.Pressed) }
	for _, child in props.Children do
		table.insert(visualChildren, child)
	end

	return New("Frame")({
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		Position = props.Position,
		Size = props.Size,
		Visible = props.Visible,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
		[Children] = {
			New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = props.ZIndex,
				[Children] = visualChildren,
			}),
		},
	})
end

--[[
	Giá trị 0..1.1 của hiệu ứng phóng, TÁCH RIÊNG khỏi `UIScale`.

	Cần tách vì hai thứ khác nhau phải cùng đọc nó: `UIScale` (phóng hình) và trần cỡ chữ
	`UITextSizeConstraint` (phóng CHỮ). Xem `Theme.MakeTextSizeConstraint`.
]]
local function makeZoomScale(hovered: any, maxScale: number?, pressed: any?)
	local target = maxScale or Tokens.HOVER_SCALE
	return Tween(
		Computed(function()
			if pressed and pressed:get() then
				return Tokens.PRESS_SCALE
			end
			return if hovered:get() then target else 1
		end),
		Tokens.HOVER_TWEEN
	)
end

function Theme.HoverZoom(hovered: any, maxScale: number?, pressed: any?)
	return New("UIScale")({ Scale = makeZoomScale(hovered, maxScale, pressed) })
end

--[[
	══ XUẤT LẠI TOKEN DƯỚI TÊN CŨ ═══════════════════════════════════════════════════════════

	Định nghĩa THẬT của những giá trị này nằm ở `Tokens.luau`, kèm toàn bộ lý do vì sao chọn
	con số đó. Ở đây chỉ là bí danh để code cũ không phải sửa.

	⚠️ ĐỪNG gán giá trị mới cho các dòng dưới đây. Sửa trong `Tokens.luau` — nếu không, một nửa
	game đọc `Theme.X` sẽ thấy số mới còn nửa đọc `Tokens.X` vẫn thấy số cũ, và đó đúng là kiểu
	lệch pha mà cả đợt dọn này sinh ra để diệt.
]]
Theme.FONT = Tokens.FONT
Theme.BORDER = Tokens.BORDER
Theme.BORDER_INNER = Tokens.BORDER_INNER
Theme.TEXT_STROKE = Tokens.TEXT_STROKE

Theme.DESIGN_WIDTH = Tokens.DESIGN_WIDTH
Theme.DESIGN_HEIGHT = Tokens.DESIGN_HEIGHT
Theme.MIN_SCALE = Tokens.MIN_SCALE
Theme.MAX_SCALE = Tokens.MAX_SCALE

-- ⚠️ `MOBILE_BOOST` / `BOOST_FIT_*` đã BỎ (2026-08-17). Tỉ lệ không còn là "contain × một đường
-- cong đoán bằng mắt" mà suy ra từ luật ngón tay — xem `Tokens.TOUCH` và `HUD/Responsive`.
Theme.TOUCH = Tokens.TOUCH
Theme.SAFE_CONTENT_WIDTH = Tokens.SAFE_CONTENT_WIDTH
Theme.SAFE_CONTENT_HEIGHT = Tokens.SAFE_CONTENT_HEIGHT

-- Toast sống NGOÀI hệ modal (ScreenGui riêng, DisplayOrder riêng) nên tầng Z của nó không nằm
-- chung bảng `Tokens.Z` — nó không bao giờ phải xếp lớp với modal.
Theme.TOAST_Z_INDEX = 220

Theme.UI_ASSETS = {
	Trophy = "rbxassetid://106462244220051",
	Lightning = "rbxassetid://94953097483502",
	Rebirth = "rbxassetid://103236589125008",
	-- Dùng ở CẢ thẻ Shop lẫn hàng Auto-Rebirth trong RebirthModal — cùng một món thì phải
	-- cùng một hình, nên để một chỗ duy nhất thay vì chép số vào hai file.
	AutoRebirth = "rbxassetid://82096179394611",
	Shop = "rbxassetid://80843877229491",
	Shoe = "rbxassetid://93408043939834",
	Cosmetics = "rbxassetid://100080362113682",
	Trail = "rbxassetid://115065552017670",
	Teleport = "rbxassetid://112885468301298",
	Aura = "rbxassetid://82712548408854",
	Code = "rbxassetid://87201095513293",
	Daily = "rbxassetid://112157950151947",
	Spin = "rbxassetid://115585087379442",
	-- Icon gói Starter Pack "Rookie Rocket" (upload 2026-08-11).
	StarterPack = "rbxassetid://139598685571792",
	-- Icon riêng của 3 Server Boost (upload 2026-08-07). Trước đây 3 món này mượn tạm
	-- Lightning/Trophy/Sunburst nên trùng icon với gamepass tốc độ và banner rebirth.
	BoostSpeed = "rbxassetid://79122550480905",
	BoostWins = "rbxassetid://99513694252408",
	BoostMega = "rbxassetid://77898277931791",
	Robux = "rbxasset://textures/ui/common/robux.png",
	Sunburst = "rbxassetid://87577740080014",
	Studs = "rbxassetid://6372755229",
	LevelUpSound = "rbxassetid://89481514209130",
	-- 2026-08-12 (user): âm "rebirth thành công" giờ là âm CHÚC MỪNG CHUNG cho mọi hệ thống
	-- ăn mừng (nhận Wins, mở pad, trúng roulette, boost server, pháo hoa cuối zone, toast
	-- success). CHỈ popup Level Up (LevelUp.luau + Toast.ShowLevelUp) giữ nguyên LevelUpSound
	-- — đó là tiếng riêng của việc lên cấp, dùng chung sẽ mất dấu hiệu nhận biết.
	CelebrationSound = "rbxassetid://4612383790",
	--[[
		ÂM "MỞ KHOÁ" — 2026-08-14 (user: tiếng báo pad mở đang TRÙNG âm chúc mừng).

		Mở pad không phải là ăn mừng: người chơi chưa nhận gì cả, tin nhắn chỉ nói "bạn đủ điều
		kiện rồi, ra pad mà lấy" (xem khối lý do trong MultiplierPadVisualController). Dùng chung
		fanfare rebirth 1.71s làm hai việc khác hẳn nhau kêu y hệt nhau — nghe tiếng thắng xong
		nhìn quanh không thấy mình được gì.

		Chọn `rbxasset://` chứ không phải một ID thư viện: file này nằm SẴN trong client Roblox
		nên không bao giờ hỏng vì kiểm duyệt, đổi quyền, hay xoá tài khoản người upload — đúng
		lớp bảo hiểm mà cả một trang known-quirks về asset ID sai loại đang cần. Đã đo trong
		Studio 2026-08-14: IsLoaded = true, 0.72s.

		Cách dùng là HAI NỐT ĐI LÊN (xem `playUnlockChime`) — một ping đơn nghe như tin nhắn
		chat, hai nốt lên mới ra nghĩa "vừa mở ra một thứ".
	]]
	UnlockSound = "rbxasset://sounds/electronicpingshort.wav",
	-- Chuông THÔNG BÁO HỆ THỐNG của toast (Tone Clusters 23 — 0.40s, đo 2026-08-12
	-- IsLoaded=true). Trung tính có chủ ý: cùng một kênh toast vừa báo tin vui vừa báo bị
	-- từ chối, nên nó không được mang sắc thái nào. Xem khối lý do trong Toast.playToastSound.
	NotifySound = "rbxassetid://9120150515",
	ClickSound = "rbxassetid://5852470908",
	-- 2026-08-05: tách khỏi ClickSound (trước đây dùng chung 5852470908 nên rê chuột và
	-- bấm nghe y hệt nhau). ID này đã đo: load OK, 0.20s.
	HoverSound = "rbxassetid://10066931761",
}

Theme.SHOP_TABS = {
	{
		id = "boosts",
		label = "SERVER BOOSTS — 10 MIN, WHOLE SERVER!",
		colorA = Color3.fromRGB(90, 240, 220),
		colorB = Color3.fromRGB(30, 130, 190),
	},
	{
		id = "utility",
		label = "UTILITY & VIP MEMBERSHIP",
		colorA = Color3.fromRGB(255, 205, 70),
		colorB = Color3.fromRGB(240, 92, 62),
	},
	{
		id = "products",
		label = "INSTANT WINS PACKS",
		colorA = Color3.fromRGB(75, 221, 255),
		colorB = Color3.fromRGB(34, 113, 230),
	},
	{
		id = "treadmills",
		label = "TREADMILLS",
		colorA = Color3.fromRGB(104, 234, 95),
		colorB = Color3.fromRGB(40, 143, 69),
	},
}

-- Màu + icon nhận diện 3 speed pass (dùng chung cho Shop card, promo RightPanel và banner
-- chúc mừng khi mua). Icon riêng từng bậc upload 2026-08-08 — trước đó cả ba dùng chung
-- `UI_ASSETS.Shoe` nên mua x8 xong banner vẫn hiện y hệt lúc mua x2.
Theme.SPEED_PASS_TIERS = {
	-- Nhãn "x2" (không phải "2x") — theo ảnh tham chiếu của user 2026-07-28.
	{
		id = "speed_x2",
		label = "x2 Speed",
		passId = 1900262644,
		priceRobux = 3,
		icon = "rbxassetid://137328765527756",
		colorA = Color3.fromRGB(255, 186, 69),
		colorB = Color3.fromRGB(255, 128, 38),
	}, -- cam-vàng
	{
		id = "speed_x4",
		label = "x4 Speed",
		passId = 1900160603,
		priceRobux = 9,
		icon = "rbxassetid://137892906025365",
		colorA = Color3.fromRGB(210, 130, 255),
		colorB = Color3.fromRGB(110, 40, 220),
	}, -- tím
	{
		id = "speed_x8",
		label = "x8 Speed",
		passId = 1898810606,
		priceRobux = 27,
		icon = "rbxassetid://135357984448018",
		colorA = Color3.fromRGB(255, 92, 78),
		colorB = Color3.fromRGB(178, 10, 40),
	}, -- đỏ
}

Theme.SHOP_CATALOG = {
	boosts = {
		{
			id = "boost_speed",
			title = "Server x2 Speed",
			subtitle = "Everyone farms double for 10 min",
			valueText = "x2 Speed — whole server",
			priceRobux = 99,
			purchaseKind = "product",
			purchaseId = 3608407713,
			accentColor = Color3.fromRGB(72, 220, 200),
			icon = Theme.UI_ASSETS.BoostSpeed,
			sortOrder = 1,
		},
		{
			id = "boost_wins",
			title = "Server x2 Wins",
			subtitle = "Everyone earns double for 10 min",
			valueText = "x2 Wins — whole server",
			priceRobux = 99,
			purchaseKind = "product",
			purchaseId = 3608407843,
			accentColor = Color3.fromRGB(255, 190, 72),
			icon = Theme.UI_ASSETS.BoostWins,
			sortOrder = 2,
		},
		{
			id = "boost_mega",
			title = "MEGA Boost (x2 Both)",
			subtitle = "Speed + Wins boost, 10 min",
			valueText = "x2 EVERYTHING — whole server",
			priceRobux = 149,
			purchaseKind = "product",
			purchaseId = 3608407916,
			accentColor = Color3.fromRGB(255, 91, 200),
			icon = Theme.UI_ASSETS.BoostMega,
			sortOrder = 3,
		},
	},
	utility = {
		{
			id = "vip_membership",
			title = "VIP Membership",
			--[[
				⚠️ HAI DÒNG NÀY PHẢI KHỚP CODE — kiểm lại mỗi lần đổi quyền lợi VIP.

				Bản trước quảng cáo "x1.2 Wins + VIP Trail + VIP Aura" trong khi game KHÔNG hề
				có ba thứ đó (chỉ có x1.5 Speed + tag chat) — người mua 399 R$ không nhận được
				thứ họ đọc trên thẻ. Gói VIP đã dựng đủ ngày 2026-08-12; nguồn của từng con số:
				  x1.5 Speed      → ProgressionService.computeVipMultiplier
				  x1.25 Wins      → ProgressionService.AwardWins (chỉ reason stage)
				  Trail + Aura    → Config/Economy/Trails|Auras (`trail_vip` / `aura_vip`)
				  Vé quay 2x      → Config/Roulette VIP_TICKET_* (8 phút, trần 5)
				  Teleport FREE   → TeleportService.tryPayWins
			]]
			subtitle = "Gold Trail x6 + Gold Aura x6 · 2x spins · [VIP]",
			valueText = "x1.5 Speed · x1.25 Wins · FREE Teleport",
			priceRobux = 399,
			purchaseKind = "gamepass",
			purchaseId = 1899686706,
			accentColor = Color3.fromRGB(255, 204, 61),
			icon = "rbxassetid://105776222512667",
			sortOrder = 1,
		},
		{
			id = "auto_rebirth",
			title = "Auto-Rebirth",
			subtitle = "Auto rebirth at required level",
			valueText = "AFK rebirth helper",
			priceRobux = 99,
			purchaseKind = "gamepass",
			purchaseId = 1899434608,
			accentColor = Color3.fromRGB(255, 112, 89),
			icon = Theme.UI_ASSETS.AutoRebirth,
			sortOrder = 2,
		},
		{
			id = "infinite_revives",
			title = "Infinite Revives",
			subtitle = "Revive on the spot, unlimited",
			valueText = "Never restart a stage again",
			priceRobux = 249,
			purchaseKind = "gamepass",
			purchaseId = 1930442093,
			accentColor = Color3.fromRGB(255, 90, 120),
			-- Angel Heart (upload 2026-08-09). Trước đây mượn tạm icon Rebirth nên trong Shop
			-- nó trùng hệt nút Rebirth ở menu trái.
			icon = "rbxassetid://137270710466090",
			sortOrder = 3,
		},
	},
	products = {
		{
			id = "wins_small",
			title = "Small Wins Pack",
			subtitle = "Open early pads faster",
			valueText = "+1,000 Wins",
			priceRobux = 99,
			purchaseKind = "product",
			purchaseId = 3608400621,
			accentColor = Color3.fromRGB(85, 205, 255),
			icon = "rbxassetid://131686958279369",
			sortOrder = 1,
		},
		{
			id = "wins_medium",
			title = "Medium Wins Pack",
			subtitle = "Fast Pad 5-6 progress",
			valueText = "+10,000 Wins",
			priceRobux = 299,
			purchaseKind = "product",
			purchaseId = 3608400807,
			accentColor = Color3.fromRGB(84, 176, 255),
			icon = "rbxassetid://119911459960204",
			sortOrder = 2,
		},
		{
			id = "wins_large",
			title = "Large Wins Pack",
			subtitle = "Jump into late-game pads",
			valueText = "+100,000 Wins",
			priceRobux = 699,
			purchaseKind = "product",
			purchaseId = 3608401003,
			accentColor = Color3.fromRGB(145, 103, 255),
			icon = "rbxassetid://133004632727402",
			sortOrder = 3,
		},
		{
			id = "wins_ultra",
			title = "Ultra Wins Pack",
			subtitle = "Whale instant economy push",
			valueText = "+1,000,000 Wins",
			priceRobux = 1299,
			purchaseKind = "product",
			purchaseId = 3608401110,
			accentColor = Color3.fromRGB(255, 91, 172),
			icon = "rbxassetid://135507450226013",
			sortOrder = 4,
		},
	},
	treadmills = {
		{
			id = "treadmill_2",
			title = "Purple Treadmill",
			subtitle = "Permanent treadmill unlock",
			valueText = "x3 Speed",
			priceRobux = 99,
			purchaseKind = "gamepass",
			purchaseId = 1899470645,
			accentColor = Color3.fromRGB(186, 90, 255),
			icon = "rbxassetid://135635489009529",
			sortOrder = 1,
		},
		{
			id = "treadmill_3",
			title = "Blue Treadmill",
			subtitle = "Permanent treadmill unlock",
			valueText = "x9 Speed",
			priceRobux = 249,
			purchaseKind = "gamepass",
			purchaseId = 1898588703,
			accentColor = Color3.fromRGB(85, 170, 255),
			icon = "rbxassetid://120071147013773",
			sortOrder = 2,
		},
		{
			id = "treadmill_4",
			title = "Gold Treadmill",
			subtitle = "Permanent treadmill unlock",
			valueText = "x25 Speed",
			priceRobux = 699,
			purchaseKind = "gamepass",
			purchaseId = 1898528586,
			accentColor = Color3.fromRGB(255, 215, 71),
			icon = "rbxassetid://137611735467502",
			sortOrder = 3,
		},
		{
			id = "treadmill_5",
			title = "Red Admin Treadmill",
			subtitle = "Top whale treadmill",
			valueText = "x100 Speed",
			priceRobux = 1299,
			purchaseKind = "gamepass",
			purchaseId = 1900262663,
			accentColor = Color3.fromRGB(255, 79, 73),
			--[[
				Ảnh MÁY CHẠY BỘ đỏ (user chốt 2026-08-12, quay lại ID cũ 139907590369911).
				Bản 2026-08-09 đổi sang "Lighting Red" 112969212387917 — một tia sét trần, không
				có cái máy chạy bộ nào trong hình: trong thẻ shop nó không đọc ra là treadmill,
				còn trên banner chúc mừng thì trùng luôn với icon tia sét dùng làm FALLBACK của
				món không tra được (xem `iconForTitle` trong BoostCelebration), nên mua món đắt
				nhất game lại nhận đúng cái icon "không biết đây là gì".
				⚠️ Banner chúc mừng đọc icon TỪ ĐÂY — sửa chỗ này là cả hai màn cùng đổi.
			]]
			icon = "rbxassetid://139907590369911",
			sortOrder = 4,
		},
	},
} :: State.ShopCatalog

function Theme.MakeCorner(radius: number)
	return New("UICorner")({
		CornerRadius = UDim.new(0, radius),
	})
end

--[[
	══ ĐỘ DÀY VIỀN PHẢI LÀ SỐ NGUYÊN PIXEL THẬT ═════════════════════════════════════════════

	Đây là lời giải cho "viền trên mobile không đều nhau" (user 2026-08-17, đo được 210/247 khối
	bị lệch — 85%).

	── VÌ SAO LỆCH ────────────────────────────────────────────────────────────────────────────
	Viền khai 4 design px, ở tỉ lệ 0.363 thành 1.45 px THẬT. Roblox rasterize mỗi mép về lưới
	pixel một cách độc lập, nên tuỳ phần thập phân của toạ độ mà cạnh này làm tròn thành 1 px còn
	cạnh kia thành 2 px. Đo thật trên máy: 2/2/2/1 · 1/2/1/1 · 2/1/2/1 — cùng MỘT khối.

	⚠️ Phép trừ toạ độ của `MakeSurface` ("bốn cạnh bằng nhau tuyệt đối") chỉ đúng trong hệ
	DESIGN. Sau khi nhân `UIScale` và snap về pixel thì nó KHÔNG còn đúng — đó là chỗ khối chú
	thích cũ ở `MakeSurface` nói thiếu.

	── CÁCH CHỮA ──────────────────────────────────────────────────────────────────────────────
	Ép độ dày ra ĐÚNG SỐ NGUYÊN pixel thật, rồi quy ngược về design px. Khi ấy, với k nguyên:

	    snap(x + k) − snap(x) = k   với MỌI x và MỌI kiểu snap (round/floor/ceil)

	nên cả bốn cạnh đều ra đúng k pixel, bất kể khối nằm ở toạ độ lẻ nào. PC (scale 1) không đổi:
	4 × 1 = 4, vốn đã nguyên.

	Sàn `MIN_BORDER_PX` vẫn áp dụng TRƯỚC khi làm tròn, và sàn tuyệt đối là 1 px — viền 0 px là
	viền biến mất.
]]
-- Số pixel THẬT mà viền nên chiếm ở tỉ lệ hiện tại. Luôn là số nguyên ≥ 1.
local function targetBorderPx(designValue: number, scale: number): number
	return math.max(1, math.round(math.max(designValue * scale, Tokens.MIN_BORDER_PX)))
end

--[[
	Dành cho `UIStroke`: thuộc tính `Thickness` giữ được SỐ THỰC (đã đo: đặt 1.089 đọc lại đúng
	1.089), nên chia ngược cho `scale` là ra đúng số nguyên pixel thật.
]]
local function pixelSnappedThickness(designValue: number)
	return Computed(function()
		local scale = math.max(0.01, State.viewportScale:get())
		return targetBorderPx(designValue, scale) / scale
	end)
end

--[[
	`thickness` là design px. Độ dày thật được snap về số nguyên pixel giống hệt viền của
	`MakeSurface` — nếu không, một khối dùng `UIStroke` đứng cạnh một khối `MakeSurface` sẽ có
	viền nặng nhẹ khác nhau (1.45 px mờ so với 1 px đặc), và mắt đọc ra ngay là "không đều".
]]
function Theme.MakeStroke(color: Color3, thickness: number, transparency: number?)
	return New("UIStroke")({
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = pixelSnappedThickness(thickness),
		Transparency = transparency or 0,
	})
end

function Theme.MakeGradient(colorA: Color3, colorB: Color3, rotation: number?)
	return New("UIGradient")({
		Color = ColorSequence.new(colorA, colorB),
		Rotation = rotation or 90,
	})
end

-- Gradient động: colorA/colorB có thể là Color3 hoặc Fusion state (Value/Computed).
local function resolveColor(value: any): Color3
	if typeof(value) == "Color3" then
		return value
	end
	return value:get()
end

function Theme.MakeGradientDynamic(colorA: any, colorB: any, rotation: number?)
	return New("UIGradient")({
		Color = Computed(function()
			return ColorSequence.new(resolveColor(colorA), resolveColor(colorB))
		end),
		Rotation = rotation or 90,
	})
end

--[[
	⚠️ `cornerRadius` KHÔNG được để trống nữa — đây là nguyên nhân của "nền bị hở viền".

	Lớp studs là một ImageLabel `ScaleType = Tile` phủ kín ô (`Size = fromScale(1, 1)`). Ảnh
	tile luôn có bốn góc VUÔNG. Cha thì bo góc (UICorner) và có viền đen vẽ ở PHÍA NGOÀI
	(`ApplyStrokeMode.Border`). Không cắt góc cho lớp studs ⇒ bốn cái mấu vuông của nó thò ra
	đúng chỗ cha đã bo tròn, đè lên viền đen — nhìn ra thành "nền không ăn khớp với viền, bị
	hở ở bốn góc". (Đo 2026-08-15: 6 chỗ mắc lỗi này, gồm cả thanh XP dưới đáy màn hình.)

	Mặc định 18 = bán kính chuẩn của header/panel trong game. Ô nào bo bán kính khác thì PHẢI
	truyền đúng số của cha, nếu không góc sẽ lệch theo chiều ngược lại (nền thụt vào).
]]
--[[
	══ Ô HOA VĂN LUÔN CHIA HẾT CHO Ô CHỨA — SỬA "NỀN HỞ VIỀN" TẬN GỐC ══════════════════════

	ĐÂY LÀ NGUYÊN NHÂN CHÍNH, và nó là lỗi TOÀN CỤC: mọi nút, panel, header, modal trong game
	đều dính (đo 2026-08-15: 229 lớp studs). User báo ba lượt liền "nền vẫn hở" là vì hai lần
	trước tôi chỉ chữa được hai triệu chứng phụ (bo góc, vạch khử răng cưa của thanh tiến độ)
	chứ chưa chạm vào cái này.

	CƠ CHẾ: hoa văn được LÁT từ góc trái-trên với ô cố định 30px. Nút menu cao 103px = 3,43 ô
	⇒ hàng cuối cùng chỉ còn 0,43 ô, tức là một VỆT MỎNG khác độ sáng bám dính vào viền đen.
	Cột bên phải cũng thế. Mắt đọc vệt đó thành "màu nền bị dư/thiếu, không đầy ra chạm viền".
	Kích thước ô càng lệch với kích thước nút thì vệt càng rõ — nên chỗ thì trông như thừa,
	chỗ thì trông như hụt, đúng như user mô tả.

	CHỮA: thay vì ép ô 30px, LÀM TRÒN số ô cho vừa khít rồi chia lại — hoa văn luôn kết thúc
	đúng mép, không bao giờ còn hàng/cột dở. Đối chứng trong Studio (2026-08-15): bỏ hẳn lớp
	studs thì vệt mất, cho ô chia hết thì vệt cũng mất mà vẫn giữ được hoa văn.

	Đọc `AbsoluteSize` của chính lớp studs qua `Fusion.Out` (nó `fromScale(1, 1)` nên bằng đúng
	ô chứa). Không có vòng lặp: `TileSize` không ảnh hưởng ngược lại `AbsoluteSize`.

	`AbsoluteSize` là PIXEL THẬT (đã nhân `UIScale`), nên cách này cũng tự lo luôn việc giữ mật
	độ hoa văn không đổi giữa các cỡ màn hình — thứ mà bản trước phải nhân `viewportScale` bằng
	tay. Ô có thể hơi chữ nhật (nút 113×103 ⇒ 28,2×34,3) nhưng hoa văn chỉ mờ 14% nên không ai
	nhận ra; đổi lại là không còn vệt nào ở viền.

	⚠️ `cornerRadius` vẫn BẮT BUỘC đúng bằng bán kính của cha: ảnh tile có bốn góc VUÔNG, mà
	`ClipsDescendants` của cha thì cắt theo HÌNH CHỮ NHẬT chứ không theo góc bo (đã đo). Thiếu
	nó là bốn mấu vuông thò ra đè lên viền đen.
]]
local STUD_TARGET_SIZE = 30

--[[
	`snapToWholeTiles = false` cho những khối mà BỀ RỘNG THAY ĐỔI liên tục lúc chạy (miếng chạy
	của thanh tiến độ). Ở đó lưới ô phải chốt theo một bề rộng nào đó, mà bề rộng thì đang chạy
	⇒ ô sẽ bị kéo giãn. Những khối này có mép phải nằm GIỮA thanh (đã bo tròn, không giáp viền)
	nên ô dở ở đó không ai thấy — dùng ô cố định là đúng.
]]
function Theme.MakeStudsPattern(
	transparency: number?,
	zIndex: number?,
	cornerRadius: number?,
	snapToWholeTiles: boolean?
)
	local absoluteSize = Value(Vector2.zero)

	--[[
		⚠️ LƯỚI Ô ĐƯỢC CHỐT MỘT LẦN RỒI GIỮ NGUYÊN VĨNH VIỄN.

		Bản trước tính lại lưới mỗi khi `AbsoluteSize` đổi. Hậu quả (user báo 2026-08-15): rê
		chuột vào nút, `HoverZoom` phóng 1.08× ⇒ chiều cao 103 → 111 px, mà lưới tính bằng
		`round(size / 30)` thì `round(3.43) = 3` còn `round(3.70) = 4` — SỐ Ô NHẢY từ 3 sang 4
		ngay giữa lúc hover, hoa văn đổi cỡ giật một cái.

		Không thể chữa bằng ngưỡng trễ: hover tới 12% thì mọi ngưỡng an toàn đều lớn hơn 0.5,
		tức là không bao giờ đổi được nữa. Nên chốt hẳn: đo MỘT LẦN lúc layout xong (khi đó
		chưa ai hover), suy ra lưới, rồi không đụng vào nữa.

		Vì `TileSize` dùng SCALE, lưới đã chốt vẫn tự co giãn đúng tỉ lệ khi cả HUD đổi cỡ theo
		màn hình — giữ nguyên bố cục thiết kế mà không bao giờ nhảy số ô.

		Memo trong `Computed` là cố ý: sau khi chốt, hàm trả về cùng một giá trị nên Fusion
		không phát sinh cập nhật thừa.
	]]
	local latchedTile: UDim2? = nil

	return New("ImageLabel")({
		BackgroundTransparency = 1,
		Image = Theme.UI_ASSETS.Studs,
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ImageTransparency = transparency or 0.76,
		Position = UDim2.fromScale(0, 0),
		ScaleType = Enum.ScaleType.Tile,
		Size = UDim2.fromScale(1, 1),
		[Out("AbsoluteSize")] = absoluteSize,
		--[[
			⚠️ PHẢI dùng SCALE, không được dùng Offset.

			`UDim.Offset` là SỐ NGUYÊN. Bản đầu tính `size.X / columns` rồi nhét vào
			`UDim2.fromOffset` — 113,9 / 4 = 28,475 bị làm tròn thành 28, thế là 4 ô chỉ phủ
			112/113,9 và hàng dở lại xuất hiện y như cũ (đo được: 227/228 lớp vẫn còn dư).

			`TileSize` theo Scale thì tính tương đối với chính ô chứa, nên `1/columns` chia hết
			TUYỆT ĐỐI ở mọi kích thước, mọi tỉ lệ màn hình — không còn phép làm tròn nào.
		]]
		TileSize = Computed(function()
			local scale = State.viewportScale:get()
			if snapToWholeTiles == false then
				--[[
					⚠️ PHẢI `math.round`, không được để `UDim2.fromOffset` tự cắt.

					`UDim.Offset` CẮT xuống số nguyên (đã đo: đặt 2.755 đọc ra 2). Ở tỉ lệ 0.363
					thì 30 × 0.363 = 10.89 bị cắt còn **10**, trong khi rãnh phía sau — vốn chốt
					lưới theo Scale — có ô ≈ 10.9. Hai lưới lệch pha dần theo chiều dài thanh, mắt
					đọc ra là "hoa văn miếng chạy lệch khỏi thanh phía sau" (user 2026-08-17).

					Làm tròn thì hai bên chỉ chênh ~1%, và ô không bao giờ nhỏ hơn 1px.
				]]
				local fixed = math.max(1, math.round(STUD_TARGET_SIZE * scale))
				return UDim2.fromOffset(fixed, fixed)
			end
			if latchedTile then
				return latchedTile
			end
			local size = absoluteSize:get()
			local target = STUD_TARGET_SIZE * scale
			-- Nhịp đầu tiên `AbsoluteSize` còn là 0 (chưa vào cây) — trả ô mặc định, Fusion sẽ
			-- gọi lại ngay khi layout xong và lúc đó mới chốt.
			if size.X < 1 or size.Y < 1 or target < 1 then
				return UDim2.fromOffset(STUD_TARGET_SIZE, STUD_TARGET_SIZE)
			end
			local columns = math.max(1, math.round(size.X / target))
			local rows = math.max(1, math.round(size.Y / target))
			latchedTile = UDim2.fromScale(1 / columns, 1 / rows)
			return latchedTile
		end),
		ZIndex = zIndex or 11,
		[Children] = { Theme.MakeCorner(cornerRadius or 18) },
	})
end

-- Hệ thống texture chuẩn: đồng bộ độ mờ tinh tế (0.86) và hỗ trợ bo góc, dễ dàng tái sử dụng cho mọi panel/button
function Theme.MakeStandardStuds(cornerRadius: number?, zIndex: number?)
	return Theme.MakeStudsPattern(0.86, zIndex, cornerRadius)
end

--[[
	══ MIẾNG CHẠY CỦA THANH TIẾN ĐỘ — VÌ SAO NÓ KHÔNG CHẠM ĐƯỢC ĐÁY RÃNH ════════════════════

	Lỗi user báo bốn lượt (2026-08-15 → 2026-08-18): ở thanh XP, phần sáng chạm sát viền đen ở
	CẠNH TRÊN nhưng CẠNH DƯỚI lại có một dải màu rãnh chen vào giữa; và có lúc phần sáng trông
	như đè lên chính viền đen.

	── NGUYÊN NHÂN THẬT, ĐO ĐƯỢC 2026-08-18 ───────────────────────────────────────────────────
	Đo bằng `CaptureService` + kính lúp nearest-neighbour (cột rộng 1 px phóng 30×), tô miếng
	chạy màu HỒNG và rãnh màu XANH LÁ để đọc từng hàng pixel:

	    con của một khung `ClipsDescendants` KHÔNG VẼ ĐƯỢC ~1.6 px SÁT MÉP TRONG của khung đó.

	Hai thí nghiệm đối chứng chốt lại nguyên nhân:
	    • tắt `ClipsDescendants` của rãnh  → màu hồng chạy xuống hết, tràn cả ra ngoài viền
	    • giữ clip, bỏ `UICorner` = 0      → VẪN hụt y nguyên ⇒ KHÔNG phải do bo góc

	Nên mọi cách "cho miếng chạy tràn ra rồi để rãnh cắt" đều vô nghĩa: chính cái cắt ấy mới là
	thủ phạm. Phần tràn không bao giờ tới được hàng pixel cuối, còn hàng cuối thì mãi mãi mang
	màu của rãnh — đúng cái khe hở user khoanh đỏ.

	── CÁCH CHỮA ──────────────────────────────────────────────────────────────────────────────
	  1. Rãnh KHÔNG cắt con nữa (`ClipContent = false` của `MakeSurface`). Miếng chạy bo góc
	     sẵn rồi, nó không có gì thò ra ngoài để mà phải cắt.
	  2. Miếng chạy nằm trong `Theme.MakeBarTrack` — khung bám ĐÚNG LƯỚI PIXEL THẬT. Không còn
	     clip thì mép dưới của miếng chạy tự khử răng cưa với thứ nằm dưới nó; snap về số nguyên
	     pixel làm hàng pixel pha màu đó biến mất hẳn, ở MỌI tỉ lệ màn hình (chứ không chỉ ở tỉ
	     lệ may mắn của một cái máy).
	  3. `BAR_FILL_BLEED = 0` — không tràn, không mẹo. Hai đầu giữ trọn cung tròn.

	Cách cũ đã LOẠI, ghi lại để không ai thử lại:
	    ✗ `UIStroke` cùng màu phủ vạch sẫm → viền bò theo cung tròn, lòi màu ở hai góc.
	    ✗ Nới tràn theo tỉ lệ (5 design px) → clip cắt theo hình chữ nhật, vạt phẳng 41% cung
	      tròn bán kính 4.36 px ⇒ miếng chạy hoá khối vuông ("vị trí bị sai").
	    ✗ Lớp tràn riêng thụt vào hai đầu → vẫn là CON của khung clip, nên vẫn hụt 1.6 px.
]]
Theme.BAR_FILL_BLEED = 0
Theme.BAR_FILL_POSITION = UDim2.fromOffset(0, 0)

function Theme.BarFillSize(progress: number): UDim2
	return UDim2.new(progress, 0, 1, 0)
end

--[[
	Khung chứa miếng chạy, BÁM ĐÚNG LƯỚI PIXEL THẬT của màn hình.

	Vì sao cần: mép trên/dưới của rãnh hầu như luôn rơi vào toạ độ lẻ (đo thật: đáy ruột ở
	y = 313.037). Miếng chạy cao đúng bằng rãnh thì mép dưới của nó cũng ở 313.037, và hàng
	pixel 313→314 chỉ được phủ 3.7% ⇒ Roblox vẽ ra một hàng PHA MÀU giữa màu sáng và thứ nằm
	dưới. Ở tỉ lệ máy này pha 3.7% nên không ai thấy, nhưng ở tỉ lệ khác phần lẻ có thể là 0.5 —
	lúc đó là một vạch sẫm rõ mồn một. Đó chính là kiểu lỗi "máy này thì đẹp, máy kia thì xấu".

	Snap về số nguyên: mép trên = `round(đỉnh rãnh)`, mép dưới = `round(đáy rãnh)`. Hình chữ nhật
	nằm trọn trên lưới pixel thì KHÔNG có hàng nào bị pha màu — cạnh sắc tuyệt đối.

	Ghi bằng đơn vị SCALE (không phải Offset) vì chỉ Scale mới giữ được số thực — cùng lý do với
	`bindPixelBorder`. Hàm tự hội tụ: viết `Size` làm `AbsoluteSize` đổi, gọi lại chính nó, nhưng
	lần hai tính ra đúng giá trị cũ nên dừng.
]]
function Theme.MakeBarTrack(props: { ZIndex: number?, Children: { any } })
	local host: Frame = New("Frame")({
		Name = "BarTrack",
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex or 3,
		[Children] = props.Children,
	}) :: any

	local function refresh()
		local parent = host.Parent
		if not parent or not parent:IsA("GuiObject") then
			return
		end
		local top, height = parent.AbsolutePosition.Y, parent.AbsoluteSize.Y
		if height < 3 then
			return
		end
		local snapTop = math.round(top)
		local snapHeight = math.max(1, math.round(top + height) - snapTop)
		host.Position = UDim2.new(0, 0, (snapTop - top) / height, 0)
		host.Size = UDim2.new(1, 0, snapHeight / height, 0)
	end

	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	host:GetPropertyChangedSignal("AbsolutePosition"):Connect(refresh)
	host.AncestryChanged:Connect(refresh)
	task.defer(refresh)

	return host
end

--[[
	══ HOA VĂN CỦA MIẾNG CHẠY — ĐI MƯỢN LƯỚI CỦA RÃNH, KHÔNG TỰ TÍNH ═══════════════════════

	User báo 2026-08-18: "texture thanh nâu sáng bị lỗi và không khớp với thanh nâu đậm phía
	sau". Đo thật trên máy giả lập (801×392, scale 0.363):

	    ô của RÃNH        = 10.78 × 9.01 px   (TileSize theo Scale: 1/39 × 1/3 của rãnh)
	    ô của MIẾNG CHẠY  = 11.00 × 11.00 px  (`round(30 × scale)`)

	Lệch 22% theo chiều DỌC — hàng hoa văn của miếng chạy không bao giờ nằm cùng hàng với rãnh;
	và lệch 2% theo chiều NGANG, cộng dồn qua 39 ô thành 8.6 px, tức gần trọn một ô ở đầu bên
	phải. Đúng hai triệu chứng user mô tả.

	Vì sao tính kiểu gì cũng không khớp: lưới của rãnh được CHỐT MỘT LẦN lúc layout xong (xem
	`MakeStudsPattern`), mà thời điểm ấy `viewportScale` có thể chưa ổn định — nên số ô thật của
	rãnh (3 hàng, chứ không phải 2 như công thức lý tưởng) chỉ biết được lúc chạy. Mọi cách suy
	ra lưới từ hằng số thiết kế đều sẽ trượt.

	CÁCH CHỮA: ĐỌC THẲNG ô của rãnh lúc chạy rồi quy về `Scale` của chính mình:

	    tileScale = ô_của_rãnh(px) / bề_rộng_miếng_chạy(px)

	`Scale` giữ được SỐ THỰC (khác `Offset` vốn bị cắt xuống số nguyên — chính chỗ sinh ra 2% ở
	trên), nên hai lưới trùng khít tuyệt đối ở mọi tỉ lệ. Bề rộng miếng chạy đổi liên tục theo
	tiến độ, nhưng vì tính lại mỗi lần `AbsoluteSize` đổi nên ô vẫn đứng yên đúng px.

	Lớp hoa văn còn được THỤT VÀO đúng phần tràn (`BAR_FILL_BLEED`) ở trên và dưới, để nó phủ
	trùng khít rãnh theo chiều dọc — nếu không, hàng ô sẽ lệch pha đúng bằng phần tràn.
]]
function Theme.MakeBarFillStuds(transparency: number?, zIndex: number?, cornerRadius: number?): ImageLabel
	local img: ImageLabel = New("ImageLabel")({
		Name = "BarFillStuds",
		BackgroundTransparency = 1,
		Image = Theme.UI_ASSETS.Studs,
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ImageTransparency = transparency or 0.86,
		ScaleType = Enum.ScaleType.Tile,
		Position = UDim2.fromOffset(0, Theme.BAR_FILL_BLEED),
		Size = UDim2.new(1, 0, 1, -Theme.BAR_FILL_BLEED * 2),
		TileSize = UDim2.fromOffset(STUD_TARGET_SIZE, STUD_TARGET_SIZE),
		ZIndex = zIndex or 11,
		[Children] = { Theme.MakeCorner(cornerRadius or 18) },
	}) :: any

	-- Lớp hoa văn của rãnh: ImageLabel lát gạch nằm cùng cấp với miếng chạy (do `MakeSurface`
	-- dựng). `nil` khi miếng chạy chưa vào cây, hoặc khi rãnh được khai `Studs = false`.
	local troughStuds: ImageLabel? = nil
	local troughConns: { RBXScriptConnection } = {}

	local function apply()
		local own = img.AbsoluteSize
		-- Tiến độ 0 ⇒ bề rộng 0 ⇒ chia cho 0. Bỏ qua; `AbsoluteSize` đổi sẽ gọi lại.
		if own.X < 1 or own.Y < 1 then
			return
		end

		local ref = troughStuds
		if not ref or ref.Parent == nil then
			-- Không mượn được thì quay về cách cũ: ô cố định theo tỉ lệ. Vẫn hơn là để nguyên
			-- ô 30px của bản vẽ (to gấp ba lần ô thật trên điện thoại).
			local fixed = math.max(1, math.round(STUD_TARGET_SIZE * State.viewportScale:get()))
			img.TileSize = UDim2.fromOffset(fixed, fixed)
			return
		end

		local refSize = ref.AbsoluteSize
		local tileX = ref.TileSize.X.Scale * refSize.X + ref.TileSize.X.Offset
		local tileY = ref.TileSize.Y.Scale * refSize.Y + ref.TileSize.Y.Offset
		if tileX < 1 or tileY < 1 then
			return
		end
		img.TileSize = UDim2.fromScale(tileX / own.X, tileY / own.Y)
	end

	local function rebind()
		for _, conn in troughConns do
			conn:Disconnect()
		end
		table.clear(troughConns)

		--[[
			Trèo NGƯỢC lên tìm lớp hoa văn của rãnh, chứ không giả định "ông nội là rãnh": giữa
			miếng chạy và rãnh còn có `BarTrack` (khung bám lưới pixel), và mai này có thể thêm
			lớp khác nữa. Dừng ở tổ tiên đầu tiên có một lớp lát gạch không nằm trên đường đi lên.
		]]
		troughStuds = nil
		local child: Instance? = img.Parent
		for _ = 1, 4 do
			local ancestor = child and child.Parent
			if not ancestor or not ancestor:IsA("GuiObject") then
				break
			end
			for _, sibling in ancestor:GetChildren() do
				if sibling ~= child and sibling:IsA("ImageLabel") and sibling.ScaleType == Enum.ScaleType.Tile then
					troughStuds = sibling
					break
				end
			end
			if troughStuds then
				break
			end
			child = ancestor
		end

		local ref = troughStuds
		if ref then
			-- Lưới của rãnh chốt MUỘN hơn frame đầu (xem `MakeStudsPattern`), nên phải nghe
			-- `TileSize` chứ không chỉ đo một lần — không thì ta mượn nhầm lưới tạm.
			table.insert(troughConns, ref:GetPropertyChangedSignal("TileSize"):Connect(apply))
			table.insert(troughConns, ref:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply))
		end
		apply()
	end

	img:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	img.AncestryChanged:Connect(rebind)
	task.defer(rebind)

	return img
end

-- Hào quang xoay. `props` tuỳ chọn để đặt lại vị trí/cỡ/lớp — mặc định giữ nguyên số cũ
-- cho mọi chỗ gọi không truyền gì.
--
-- `Pulse = true` thêm nhịp thở (UIScale 1 ↔ 1.12) chồng lên vòng xoay: xoay đều một tốc độ
-- rất dễ bị mắt lọc mất như một hoạ tiết nền, còn thứ PHỒNG LÊN thì luôn bị nhìn. Dùng cho
-- nút cần bán hàng (Shop).
export type SunburstProps = {
	Position: UDim2?,
	Size: UDim2?,
	ZIndex: number?,
	ImageColor3: Color3?,
	ImageTransparency: number?,
	Pulse: boolean?,
	SpinSeconds: number?,
}

function Theme.MakeSunburst(props: SunburstProps?)
	--[[
		⚠️ PHẢI chú thích kiểu — xem khối lý do dài ở `Responsive.AttachHitArea`.

		Để Luau tự suy `props or {}` thì kiểu ra là `SunburstProps | {| |}`, và MỌI lần đọc
		`p.Position` / `p.Pulse` … bên dưới đều thành lỗi "Key is missing from '{| |}'".
		Riêng dòng này sinh ~112 lỗi type.

		Kiểu inline cũ cũng được đặt tên luôn: không có tên thì không chú thích được cho local,
		và mỗi chỗ gọi lại phải chép lại cả khối field.
	]]
	local p: SunburstProps = props or {}
	local sunburst = New("ImageLabel")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Theme.UI_ASSETS.Sunburst,
		-- ⚠️ Mặc định TRẮNG. Hào quang trắng đặt trên nền panel tối thì rõ, nhưng đặt thẳng
		-- lên thế giới 3D (nền cát sáng của Lobby) thì tàng hình — phải truyền màu.
		ImageColor3 = p.ImageColor3 or Color3.fromRGB(255, 255, 255),
		ImageTransparency = p.ImageTransparency or 0.08,
		Position = p.Position or UDim2.fromOffset(49, 51),
		Size = p.Size or UDim2.fromOffset(148, 148),
		ZIndex = p.ZIndex or 2,
	})
	local tween = TweenService:Create(
		sunburst,
		TweenInfo.new(p.SpinSeconds or 7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 }
	)
	tween:Play()
	State.sweeper:Add(function()
		tween:Cancel()
	end)

	if p.Pulse then
		local scale = Instance.new("UIScale")
		scale.Scale = 0.92
		scale.Parent = sunburst
		local pulseTween = TweenService:Create(
			scale,
			TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.12 }
		)
		pulseTween:Play()
		State.sweeper:Add(function()
			pulseTween:Cancel()
		end)
	end

	return sunburst
end

--[[
	══ RÀNG BUỘC CỠ CHỮ — ĐƠN VỊ LÀ DESIGN PX, KHÔNG PHẢI PIXEL THẬT ═══════════════════════

	ĐÂY LÀ NGUYÊN NHÂN GỐC của "chữ vỡ trên điện thoại" (đo 2026-08-14: 132 nhãn có
	`TextFits = false` ở viewport 735×413, trên PC thì 0 nhãn).

	`UITextSizeConstraint` làm việc trên PIXEL THẬT, còn `TextScaled` cũng co giãn theo
	`AbsoluteSize` tính bằng PIXEL THẬT — mà `AbsoluteSize` đã bị `UIScale` nhân vào rồi. Nên
	một hằng `MinTextSize = 10` viết ra với ý "10 px trong bản thiết kế 1920×1080" thật ra là
	"không bao giờ nhỏ hơn 10 px THẬT trên màn hình".

	Hậu quả: nhãn "Cosmetics" có ô 118×34 design. Trên PC (scale 1) ô là 118×34 px thật, chữ
	vừa ở ~21 px. Trên điện thoại (scale 0.38) ô chỉ còn 45×13 px thật, chữ CẦN ~8 px mới vừa
	— nhưng sàn 10 px chặn lại, nên chữ tràn ra và bị cắt thành "Cosmeti". Càng máy nhỏ càng
	cắt nhiều, và nó cắt đúng những nhãn dài nhất.

	Sửa: nhân cả hai cận với `viewportScale`, tức là khai báo bằng design px và để hệ thống
	quy đổi. Ở scale = 1 (PC) giá trị không đổi một chút nào — chính là ràng buộc "PC làm chuẩn".
]]
--[[
	`zoomScale` (tuỳ chọn): trần cỡ chữ nhân thêm hệ số phóng của nút đang chứa nhãn.

	── LỖI ĐÃ SỬA 2026-08-16 (user: "stroke đã phóng theo nút nhưng text thì chưa") ───────────
	`UIScale` phóng khung nút, và `AbsoluteSize` của nhãn cũng to theo — nhưng `TextScaled` rồi
	lại bị `UITextSizeConstraint.MaxTextSize` KẸP TRẦN, mà trần đó là pixel tuyệt đối. Đo được ở
	nút CLAIM: `TextBounds.Y` = 41.0 đúng bằng `MaxTextSize` = 41.0, tức là chữ đã chạm trần từ
	trước khi hover ⇒ nút phình 8% mà chữ đứng nguyên.

	Nhân trần với cùng hệ số phóng thì chữ và khung to lên cùng nhịp.
]]
function Theme.MakeTextSizeConstraint(maxDesign: number, minDesign: number?, zoomScale: any?)
	local minValue = minDesign or 1
	return New("UITextSizeConstraint")({
		MaxTextSize = Computed(function()
			local zoom = if zoomScale then zoomScale:get() else 1
			-- Trần không bao giờ được xuống dưới 1: MaxTextSize = 0 là chữ biến mất hoàn toàn.
			return math.max(1, maxDesign * State.viewportScale:get() * zoom)
		end),
		MinTextSize = Computed(function()
			return math.max(1, minValue * State.viewportScale:get())
		end),
	})
end

function Theme.MakeOutlineLabel(props: { [string]: any })
	-- Trần cỡ chữ nhân `Tokens.TEXT_SCALE` — một chỗ duy nhất điều khiển độ to chữ cả HUD.
	local maxTextSize = (props.MaxTextSize or 48) * Tokens.TEXT_SCALE
	--[[
		Sàn mặc định 1 (trước đây là 10). Sàn chỉ có ý nghĩa khi ta CỐ Ý muốn chữ tràn ra ngoài
		ô hơn là bé đi — gần như không bao giờ đúng với HUD này, và chính con số 10 đã cắt cụt
		132 nhãn trên điện thoại. Chỗ nào thật sự cần sàn thì truyền `MinTextSize` (design px),
		nó vẫn được quy đổi đúng qua `MakeTextSizeConstraint`.
	]]
	local minTextSize = props.MinTextSize or 1

	local defaults: { [any]: any } = {
		BackgroundTransparency = 1,
		Font = Theme.FONT,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
	}

	local strokeColor = props.TextStrokeColor3 or Color3.fromRGB(0, 0, 0)
	local strokeTransparency = props.TextStrokeTransparency or 0
	-- ⚠️ CỐ Ý bỏ qua `props.TextStrokeThickness`: viền chữ phải đồng bộ tuyệt đối trên toàn
	-- HUD (xem chú thích ở `Theme.TEXT_STROKE`). Prop này vẫn được nhận rồi vứt đi để code cũ
	-- không vỡ, nhưng ĐỪNG truyền nó ở chỗ mới.
	local strokeThickness = Theme.TEXT_STROKE

	for key, value in props do
		if
			key ~= "MaxTextSize"
			and key ~= "MinTextSize"
			and key ~= "TextStrokeColor3"
			and key ~= "TextStrokeTransparency"
			and key ~= "TextStrokeThickness"
			and key ~= "Zoom"
		then
			defaults[key] = value
		end
	end

	local childrenList = defaults[Children] or {}
	-- `Zoom`: hệ số phóng của nút đang chứa nhãn, để CHỮ to lên cùng nhịp với khung.
	-- `MakeSurface` truyền xuống qua `Content` dạng hàm — xem khối lý do ở `MakeTextSizeConstraint`.
	table.insert(childrenList, Theme.MakeTextSizeConstraint(maxTextSize, minTextSize, props.Zoom))
	table.insert(
		childrenList,
		New("UIStroke")({
			Color = strokeColor,
			Transparency = strokeTransparency,
			Thickness = strokeThickness,
		})
	)
	defaults[Children] = childrenList

	return New("TextLabel")(defaults)
end

--[[
	NHÃN GIÁ ROBUX — chữ xanh Robux, ĐỨNG YÊN HOÀN TOÀN (user chốt 2026-08-12).

	Badge giá của Revive và promo x2/x4/x8 Speed từng là chữ TRẮNG như mọi nhãn khác trong HUD,
	nên nó chìm nghỉm giữa một màn hình đầy chữ trắng viền đen. Cách chữa là MÀU, không phải
	chuyển động: người chơi Roblox đã học sẵn "xanh này = tiền/mua được".

	── LỊCH SỬ, để đời sau đừng làm lại ──────────────────────────────────────────────────
	Đã thử hai đời hiệu ứng, cả hai đều bị bác:
	  1. Đổi MÀU theo nhịp — con số trông như đang lỗi render chứ không nổi hơn (bác 08-11).
	  2. PULSE phóng to/thu nhỏ bằng `UIScale` — badge nằm nhô ra ngoài mép nút nên lúc phình
	     ra nó kéo cả con số trượt ngang qua lại (bác 08-12).
	Nhãn giá nằm ngay cạnh nút bấm, tức là thứ người chơi đang NHÌN THẲNG chứ không phải thứ
	cần vẫy tay ở đuôi mắt — thêm chuyển động vào đó chỉ làm khó đọc. Giữ nó đứng yên.
]]
local PRICE_GREEN = Tokens.COLOR.PRICE

function Theme.MakePriceLabel(props: { [string]: any })
	local merged: { [string]: any } = {}
	for key, value in props do
		merged[key] = value
	end
	merged.TextColor3 = PRICE_GREEN
	-- Trước đây nhãn giá cố tình dày hơn nhãn thường (4 so với 3). Bỏ: viền chữ giờ đồng bộ
	-- tuyệt đối cả HUD ở `Theme.TEXT_STROKE` = 4, tức là nhãn giá vẫn đúng độ dày cũ mà không
	-- còn là ngoại lệ. Cái phân biệt nhãn giá là MÀU, không phải nét viền.
	return Theme.MakeOutlineLabel(merged)
end

--[[
	══════════════════════════════════════════════════════════════════════════════════════════
	  MakeSurface — LỚP NỀN CHUẨN MỚI CHO TOÀN BỘ UI (2026-08-15)
	══════════════════════════════════════════════════════════════════════════════════════════

	── VÌ SAO PHẢI THAY, VÀ VÌ SAO CHỈNH THAM SỐ KHÔNG BAO GIỜ CHỮA ĐƯỢC ────────────────────

	Kiểu cũ: MỘT Frame + `UICorner` + `UIStroke(ApplyStrokeMode = Border)`.
	Đo trong Studio (phóng 22×, cùng một nút 113×103, viền khai báo 5): bề dày viền thật ra là
	    trên 68px · dưới 90px · trái 76px · phải 78px
	— lệch nhau tới 32%. `UIStroke` là một hình HÌNH HỌC RIÊNG do engine sinh quanh khối, được
	rasterize độc lập với cái nền bên trong; hai mép khử răng cưa gặp nhau ở một toạ độ lẻ
	(HUD luôn nằm ở toạ độ lẻ vì `UIScale` hiếm khi tròn) nên mỗi cạnh rơi vào một pha pixel
	khác nhau. Đó chính là "nền hở viền, cạnh dày cạnh mỏng" mà user báo suốt bốn lượt — và
	KHÔNG có tham số nào của `UIStroke` sửa được, vì lỗi nằm ở cách nó được vẽ.

	── KIỂU MỚI: VIỀN LÀ HÌNH KHỐI THẬT, KHÔNG PHẢI STROKE ──────────────────────────────────

	    ┌─ outer: Frame ĐEN, bo góc (Radius + Border)      ← chính là cái viền
	    │   └─ fill: Frame MÀU, thụt vào đúng `Border` mỗi bên, bo góc Radius
	    │        ├─ gradient + studs
	    │        └─ Content (icon, chữ…)
	    └─ Outside (badge tràn mép, hào quang…)

	Ba điều nó bảo đảm mà kiểu cũ không:
	  1. Bề dày viền = phép TRỪ toạ độ (`Position = B`, `Size = 1, -2B`). Là số học thuần, nên
	     bốn cạnh bằng nhau TUYỆT ĐỐI, không phụ thuộc pha pixel.
	  2. Mép khử răng cưa của phần màu nằm TRÊN NỀN ĐEN. Sai số nửa pixel chỉ làm mép đen mềm
	     đi một chút — không bao giờ thành khe sáng hay màu lòi ra ngoài viền.
	  3. Không còn `UIStroke` ⇒ engine bớt một lượt vẽ riêng cho mỗi khối. Đổi lại thêm một
	     Frame, nhưng Frame rẻ hơn stroke — tổng thể nhẹ hơn.

	`ClipsDescendants` đặt ở lớp FILL (không phải outer): outer phải cho `Outside` tràn ra.
	⚠️ Nhớ `ClipsDescendants` cắt theo HÌNH CHỮ NHẬT, không theo góc bo — nên lớp studs vẫn
	phải tự mang `UICorner` đúng bằng `Radius` (đã lo sẵn bên trong hàm này).

	── NGOẠI LỆ DUY NHẤT: KHỐI TRONG SUỐT MỘT PHẦN ─────────────────────────────────────────
	Vỏ ngoài các modal để `BackgroundTransparency ≈ 0.3` cho nhìn xuyên thấy cảnh game. Kiểu
	mới KHÔNG dùng được ở đó: viền là một khối ĐẶC nằm dưới, nên thân mờ sẽ hoà vào màu đen
	thay vì hoà vào cảnh — mất hẳn hiệu ứng kính mờ. Những khối đó giữ `UIStroke` là ĐÚNG.
	Đổi lại, viền lệch pha ở đó gần như không nhìn ra: 4px trên tấm 1032px, khác hẳn nút 113px
	nơi cùng độ lệch ấy chiếm một phần đáng kể của cạnh.
]]
export type SurfaceProps = {
	ClassName: string?,
	AnchorPoint: Vector2?,
	Position: any?,
	Size: any?,
	Visible: any?,
	ZIndex: number?,
	LayoutOrder: number?,
	Rotation: number?,
	Radius: number?,
	Border: number?,
	BorderColor: any?,
	Color: any?,
	ColorB: any?,
	-- Độ trong của phần MÀU (không phải của viền). Cần cho mấy ô nền tối mờ như đồng hồ đếm
	-- ngược Starter Pack hay bảng chú thích Playtime.
	FillTransparency: number?,
	--[[
		Độ trong của KHUNG VIỀN. Mặc định 0 = đặc, giữ nguyên mọi UI cũ.

		⚠️ Đây là thứ BẮT BUỘC phải chỉnh nếu muốn một ô THẬT SỰ nhìn xuyên được. Khung ngoài
		là một Frame có nền, và nó phủ TRỌN ô chứ không chỉ viền — lớp fill nằm đè lên trên nó.
		Nên đặt mỗi `FillTransparency` là vô ích: fill trong suốt 25% nhưng phía sau vẫn là
		khung đen đặc, mắt thấy y hệt ô đen kín (đúng bug bảng Playtime Boost, 2026-08-20).
		Muốn trong suốt thì phải hạ CẢ HAI.
	]]
	BorderTransparency: number?,
	GradientRotation: number?,
	Studs: boolean?,
	StudsTransparency: number?,
	--[[
		`false` = ruột KHÔNG cắt con. Chỉ dùng cho thanh tiến độ — xem khối "MIẾNG CHẠY" bên
		trên: con của một khung `ClipsDescendants` không vẽ được ~1.6 px sát mép, nên miếng chạy
		nằm trong rãnh thì luôn chừa lại một dải màu rãnh ở đáy.
	]]
	ClipContent: boolean?,
	-- Bảng thường, HOẶC hàm `(zoomScale) -> { any }` khi cần chữ phóng theo nút.
	Content: any?,
	Outside: { any }?,
	--[[
		Bật hiệu ứng phóng khi rê chuột / bấm. Truyền cái này THAY CHO việc tự nhét
		`Theme.HoverZoom` vào `Outside` — chỉ đường này mới nở đều 4 góc (xem khối lý do dài
		ở cuối `MakeSurface`).
	]]
	Zoom: { Hovered: any, Scale: number?, Pressed: any? }?,
	Activated: (() -> ())?,
	MouseEnter: (() -> ())?,
	MouseLeave: (() -> ())?,
	InputBegan: ((InputObject) -> ())?,
	InputEnded: ((InputObject) -> ())?,
}

--[[
	Đẩy vị trí khối NGOÀI sao cho phần MÀU rơi đúng vào ô mà caller khai báo.

	Nhờ hàm này `MakeSurface` là bản THAY THẾ NGUYÊN CHỖ cho cụm `UICorner + UIStroke` cũ:
	viền vẫn nằm PHÍA NGOÀI ô khai báo y như `ApplyStrokeMode.Border`, nên mọi toạ độ con bên
	trong giữ nguyên, không phải dịch một số nào. Đó là điều kiện để chuyển nốt ~50 chỗ còn lại
	(modal) mà không sợ xô lệch bố cục.

	Công thức: mép trái thật = Position − anchor × Size. Muốn mép trái của PHẦN MÀU không đổi
	khi khối ngoài phình thêm 2×border, phải dịch Position đi `border × (2 × anchor − 1)`:
	anchor 0 → −border · anchor 0.5 → 0 (phình đều hai bên, tâm giữ nguyên) · anchor 1 → +border.
]]
--[[
	`border` giờ là một STATE, không phải số — xem `borderFor`. Vì vậy hai helper này luôn trả về
	`Computed`: toạ độ/kích thước khối ngoài phải tính lại mỗi khi độ dày viền đổi (tức là mỗi khi
	người chơi đổi cỡ cửa sổ / xoay máy).
]]
local function shiftForBorder(position: any, anchor: Vector2, border: any)
	return Computed(function()
		local b = border:get()
		local base = if position == nil
			then UDim2.fromOffset(0, 0)
			elseif typeof(position) == "UDim2" then position
			else position:get()
		return base + UDim2.fromOffset(b * (2 * anchor.X - 1), b * (2 * anchor.Y - 1))
	end)
end

local function growForBorder(size: any, border: any)
	return Computed(function()
		local b = border:get()
		local base = if size == nil then UDim2.fromScale(1, 1) elseif typeof(size) == "UDim2" then size else size:get()
		return base + UDim2.fromOffset(b * 2, b * 2)
	end)
end

--[[
	══ VIỀN CỦA `MakeSurface` PHẢI LÀ SỐ NGUYÊN **DESIGN** PX ═══════════════════════════════

	⚠️ ĐO ĐƯỢC 2026-08-17, và đây là mấu chốt của cả lỗi "viền không đều":

	    `UDim.Offset` bị CẮT (truncate) xuống số nguyên — đặt 2.755 đọc lại ra 2; đặt 3.999 ra 3.

	Viền của `MakeSurface` là hình học, dựng bằng `Position = (0, b)` và `Size = (1, -2b)`, tức là
	đi qua `UDim.Offset`. Nên mọi phần thập phân của `b` BỊ VỨT — bản trước tính ra 2.755 design
	thì engine dùng 2, cho ra viền **0.726 px thật**. Con số đó nằm đúng giữa hai pixel, nên chỉ
	cần khối lệch một chút là cạnh này làm tròn thành 1 px còn cạnh kia thành 0 hoặc 2 — đo được
	210/247 khối lệch (85%).

	Cách chữa: chọn một số nguyên DESIGN px sao cho nhân `scale` ra GẦN NHẤT một số nguyên px
	thật. Sai số còn lại rất nhỏ (≈0.09 px) nên bốn cạnh cùng làm tròn về một giá trị.

	    scale 0.363 (cửa sổ nhỏ) : muốn 1 px → dùng 3 design → 1.089 px thật
	    scale 0.383 (iPhone XR)  : muốn 2 px → dùng 5 design → 1.915 px thật
	    scale 0.533 (iPad)       : muốn 2 px → dùng 4 design → 2.132 px thật
	    scale 1.000 (PC)         : muốn 4 px → dùng 4 design → 4.000 px thật (KHÔNG ĐỔI)

	⚠️ Đừng "tối ưu" thành số thực cho gọn — engine sẽ cắt nó và ta quay lại đúng lỗi cũ.
]]
local function borderFor(designValue: number)
	return Computed(function()
		local scale = math.max(0.01, State.viewportScale:get())
		return math.max(1, math.round(targetBorderPx(designValue, scale) / scale))
	end)
end

--[[
	══ CHỐT CUỐI: ÉP VÀNH VIỀN RA ĐÚNG SỐ NGUYÊN PIXEL, KHÔNG SAI MỘT LY ════════════════════

	`borderFor` ở trên đã kéo sai số xuống ~0.09 px, nhưng CHƯA đủ: đo lại vẫn còn 21% khối có
	một cạnh dày 2 px trong khi ba cạnh kia 1 px. Vì vành thật = 1.089 px, chỉ cần khối rơi vào
	toạ độ có phần thập phân ≥ 0.41 là cạnh đó làm tròn lên 2.

	Muốn TUYỆT ĐỐI đều thì vành phải là số nguyên px, vì khi k nguyên:
	    snap(x + k) − snap(x) = k   với mọi x
	Nhưng `UDim.Offset` bị cắt xuống số nguyên DESIGN px, mà số nguyên design × tỉ lệ lẻ thì
	không bao giờ ra số nguyên px thật. Bế tắc — trừ khi đổi đơn vị.

	── LỐI RA: DÙNG `Scale` THAY `Offset` ─────────────────────────────────────────────────────
	Thành phần `Scale` của `UDim` giữ nguyên SỐ THỰC (chỉ `Offset` mới bị cắt). Nên đặt

	    Position = fromScale(k / W, k / H)        với W, H = cỡ THẬT của khối ngoài (px)
	    Size     = fromScale(1 − 2k/W, 1 − 2k/H)

	thì vành thật = (k/W) × W = ĐÚNG k px, cả bốn cạnh, ở mọi tỉ lệ.

	Cái giá: phải biết `W`, `H` lúc CHẠY (`AbsoluteSize`) nên không bind qua Fusion được — đúng
	như `Responsive.AttachHitArea`. Đổi lại đây là lần duy nhất trong đời khối đó phải tính.

	⚠️ `k` bị kẹp trần theo cạnh ngắn: khối tí hon (badge 20 px) mà viền 2 px thì ruột còn 16 px,
	vẫn ổn; nhưng không kẹp thì có khối viền nuốt sạch phần màu.
]]
local function bindPixelBorder(host: GuiObject, fill: Frame, designBorder: number)
	local function refresh()
		local w, h = host.AbsoluteSize.X, host.AbsoluteSize.Y
		if w <= 2 or h <= 2 then
			return
		end
		local scale = math.max(0.01, State.viewportScale:get())
		local k = targetBorderPx(designBorder, scale)
		k = math.clamp(k, 1, math.floor(math.min(w, h) / 3))
		fill.Position = UDim2.fromScale(k / w, k / h)
		fill.Size = UDim2.fromScale(1 - (2 * k) / w, 1 - (2 * k) / h)
	end

	refresh()
	State.sweeper:Add(host:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh))
	State.sweeper:Add(Fusion.Observer(State.viewportScale):onChange(refresh))
end

function Theme.MakeSurface(props: SurfaceProps)
	local radius = props.Radius or 10
	local border = borderFor(props.Border or Theme.BORDER)
	local zIndex = props.ZIndex or 12
	local anchor = props.AnchorPoint or Vector2.zero

	--[[
		Hệ số phóng phải dựng TRƯỚC nội dung: nhãn bên trong cần nó để nhân trần cỡ chữ, nếu không
		khung nút phình ra mà chữ đứng nguyên (xem `MakeTextSizeConstraint`).

		Vì vậy `Content` nhận được cả hai dạng:
		  • bảng thường          — nội dung tĩnh, chữ KHÔNG phóng theo;
		  • hàm `(zoom) -> {…}`  — truyền `zoom` xuống `MakeOutlineLabel` để chữ phóng cùng khung.
	]]
	local zoomScale = if props.Zoom
		then makeZoomScale(props.Zoom.Hovered, props.Zoom.Scale, props.Zoom.Pressed)
		else nil

	local fillChildren: { any } = {
		Theme.MakeCorner(radius),
	}
	if props.ColorB ~= nil then
		table.insert(fillChildren, Theme.MakeGradientDynamic(props.Color, props.ColorB, props.GradientRotation))
	end
	if props.Studs ~= false then
		table.insert(fillChildren, Theme.MakeStudsPattern(props.StudsTransparency or 0.86, zIndex + 2, radius))
	end
	local content = props.Content
	if typeof(content) == "function" then
		content = content(zoomScale)
	end
	for _, child in content or {} do
		table.insert(fillChildren, child)
	end

	--[[
		⚠️ `Position`/`Size` của ruột KHÔNG bind qua Fusion nữa — `bindPixelBorder` ghi chúng bằng
		tay mỗi khi cỡ khối hoặc tỉ lệ đổi. Lý do ở khối chú thích của `bindPixelBorder`: chỉ đơn
		vị SCALE mới giữ được số thực, mà giá trị Scale thì phải biết cỡ THẬT của khối — thứ chỉ
		có lúc chạy. Giá trị khai ở đây chỉ là trạng thái ban đầu cho frame đầu tiên.
	]]
	local fill = New("Frame")({
		BackgroundColor3 = props.Color or Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = props.FillTransparency,
		ClipsDescendants = props.ClipContent ~= false,
		Position = Computed(function()
			local b = border:get()
			return UDim2.fromOffset(b, b)
		end),
		Size = Computed(function()
			local b = border:get()
			return UDim2.new(1, -b * 2, 1, -b * 2)
		end),
		ZIndex = zIndex + 1,
		[Children] = fillChildren,
	})

	local outerChildren: { any } = {
		-- Bán kính ngoài = trong + viền, để hai đường cong SONG SONG. Dùng chung một số là
		-- viền bị bóp mỏng ở góc, đúng kiểu lỗi cũ nhưng ở chỗ khác.
		New("UICorner")({
			CornerRadius = Computed(function()
				return UDim.new(0, radius + border:get())
			end),
		}),
		fill,
	}
	for _, child in props.Outside or {} do
		table.insert(outerChildren, child)
	end

	local outer: { [any]: any } = {
		AnchorPoint = anchor,
		BackgroundColor3 = props.BorderColor or Color3.fromRGB(0, 0, 0),
		-- Xem `BorderTransparency` ở khai báo type: khung này phủ TRỌN ô, nên nó mới là thứ
		-- quyết định ô có nhìn xuyên được hay không.
		BackgroundTransparency = props.BorderTransparency,
		-- Khối ngoài phình ra 2×border và lùi lại tương ứng, để PHẦN MÀU trùng khít ô mà
		-- caller khai báo (xem `shiftForBorder`). `Radius` caller truyền cũng là bán kính của
		-- phần màu — giống hệt ý nghĩa `MakeCorner` ở kiểu cũ.
		Position = shiftForBorder(props.Position, anchor, border),
		Size = growForBorder(props.Size, border),
		Visible = props.Visible,
		ZIndex = zIndex,
		-- Hai thuộc tính này phải nằm ở lớp NGOÀI: `LayoutOrder` để UIListLayout/UIGridLayout
		-- xếp đúng chỗ, `Rotation` để nghiêng cả khối kể cả viền.
		LayoutOrder = props.LayoutOrder,
		Rotation = props.Rotation,
		[Children] = outerChildren,
	}

	local className = props.ClassName or "Frame"
	if className ~= "Frame" then
		outer.AutoButtonColor = false
		outer.Text = ""
	end
	if props.Activated then
		outer[OnEvent("Activated")] = props.Activated
	end
	if props.MouseEnter then
		outer[OnEvent("MouseEnter")] = props.MouseEnter
	end
	if props.MouseLeave then
		outer[OnEvent("MouseLeave")] = props.MouseLeave
	end
	if props.InputBegan then
		outer[OnEvent("InputBegan")] = props.InputBegan
	end
	if props.InputEnded then
		outer[OnEvent("InputEnded")] = props.InputEnded
	end

	--[[
		══ LUẬT NGÓN TAY — TỰ ĐỘNG, KHÔNG CẦN CALLER KHAI GÌ (2026-08-17) ═══════════════════

		Mọi khối `MakeSurface` CÓ `Activated` đều là một cái nút, và trên thiết bị cảm ứng nó phải
		đủ `Tokens.TOUCH.MIN_PX` px thật mỗi cạnh. `Responsive.AttachHitArea` đo cỡ THẬT lúc chạy
		rồi phủ thêm một lớp chạm trong suốt đúng bằng phần còn thiếu — hình vẽ không đổi một
		pixel nào, và nút vốn đã đủ to thì không phát sinh gì.

		Gắn vào lớp NGOÀI (`outer`), KHÔNG phải lớp ruột: chỉ ruột mới `ClipsDescendants = true`,
		gắn vào đó là lớp chạm bị cắt đúng bằng mép nút và vô tác dụng — đúng cái rào đã chặn
		helper cũ suốt ba tháng.
	]]
	local function finish(instance: any): any
		-- Ép vành viền ra đúng số nguyên pixel (xem `bindPixelBorder`). Phải gọi ở đây vì nó cần
		-- CHÍNH cái Instance ngoài — thứ chỉ tồn tại sau `New(className)`.
		bindPixelBorder(instance :: GuiObject, fill, props.Border or Theme.BORDER)
		if props.Activated then
			Responsive.AttachHitArea(instance :: GuiObject, props.Activated, {
				ZIndex = zIndex + 40,
				-- Chuyển tiếp state phóng/nhún, nếu không nút mất hẳn phản hồi khi chạm.
				Pressed = if props.Zoom then props.Zoom.Pressed else nil,
				Hovered = if props.Zoom then props.Zoom.Hovered else nil,
			})
		end
		return instance
	end

	if props.Zoom == nil then
		return finish(New(className)(outer))
	end

	--[[
		══ PHÓNG TO KHI RÊ / BẤM — NỞ ĐỀU RA CẢ 4 GÓC ═══════════════════════════════════════

		── LỖI ĐÃ SỬA 2026-08-16 (user: "zoom to ở 3 góc, góc trái trên đứng yên") ───────────
		`UIScale` phóng khối quanh chính `AnchorPoint` của nó. Gần như mọi nút trong game có
		`AnchorPoint = (0, 0)`, nên nó nở sang PHẢI và XUỐNG DƯỚI — góc trái-trên đứng yên, đúng
		hiện tượng user mô tả. Muốn nở đều thì khối được phóng phải có `AnchorPoint = (0.5, 0.5)`.

		Nhưng KHÔNG thể đặt thẳng (0.5, 0.5) lên chính cái nút: phần lớn nút nằm trong
		`UIListLayout`/`UIGridLayout`, mà layout của Roblox ghi `Position` và KHÔNG bù trừ
		`AnchorPoint` — đặt 0.5 là nút lệch đi nửa thân, vỡ cả lưới.

		Cách chữa: thêm một khung BỌC trong suốt (`host`) giữ đúng ô mà layout cấp, rồi treo
		phần nhìn thấy vào giữa nó:

		    host  (trong suốt, AnchorPoint của caller, giữ chỗ trong layout — KHÔNG BAO GIỜ nhúc nhích)
		     └─ outer  (AnchorPoint 0.5/0.5, Position 50%/50%, Size 100%/100%)
		          ├─ UIScale   ← phóng quanh TÂM ⇒ nở đều 4 góc
		          ├─ fill (màu) + Content
		          └─ Outside (badge tràn mép… phóng cùng)

		── ĐỒNG THỜI SỬA LUÔN "stroke không phóng theo nút" ─────────────────────────────────
		13 chỗ trước đây nhét `HoverZoom` vào `[Children]` của cái nút BÊN TRONG, nên chỉ ruột
		màu phình ra còn khung viền đen bọc ngoài đứng im — rê chuột là thấy ruột "trồi" ra khỏi
		viền. Ở đây `UIScale` nằm trên `outer`, mà `outer` CHÍNH LÀ cái viền, nên viền và ruột
		phóng như một khối duy nhất.
	]]
	table.insert(outerChildren, New("UIScale")({ Scale = zoomScale }))

	-- `host` nhận toạ độ/kích thước gốc; `outer` chuyển sang lấp đầy host và neo tâm.
	local hostPosition = outer.Position
	local hostSize = outer.Size
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.Position = UDim2.fromScale(0.5, 0.5)
	outer.Size = UDim2.fromScale(1, 1)
	outer.LayoutOrder = nil

	return New("Frame")({
		AnchorPoint = anchor,
		BackgroundTransparency = 1,
		Position = hostPosition,
		Size = hostSize,
		Visible = props.Visible,
		ZIndex = zIndex,
		LayoutOrder = props.LayoutOrder,
		[Children] = { finish(New(className)(outer)) },
	})
end

--[[
	══ THANH TIÊU ĐỀ MODAL — MỘT KHUÔN DÙNG CHUNG (2026-08-15) ══════════════════════════════

	User chốt: thanh tiêu đề phải KHỚP với khung modal, có lề đều bao quanh, không dán sát mép.
	Đo trong Studio trước khi sửa: cả 10 modal đều để header ở (0,0) rộng bằng đúng vỏ ⇒ lề
	0/0/0, viền của header chồng lên viền của vỏ và bị `CanvasGroup` cắt cụt — nhìn ra thành
	"lệch khung", mỗi modal lệch một kiểu tuỳ viền nào bị cắt trước.

	Khuôn mới: header thụt vào `HEADER_INSET` mỗi bên, nên phần nền của vỏ modal lộ ra thành
	một viền bao đều — đó chính là cái làm nó "khớp khung".

	  vỏ modal (rộng W)
	   └─ lề 12 ─ header rộng W − 24, cao 84 ─ lề 12 ─┘

	Bán kính 10: cộng viền 4 thành 14 ở mép ngoài — nhỏ hơn bán kính vỏ (18) đúng một nhịp, nên
	hai đường cong lồng vào nhau tự nhiên thay vì cắt nhau.

	Dùng `Theme.HeaderSlot(panelWidth)` để lấy Position/Size, đừng chép số bằng tay.
]]
-- Bí danh của `Tokens.MODAL.*` (xem khối "XUẤT LẠI TOKEN" ở đầu file). `ModalShell` đọc thẳng
-- từ `Tokens`; ba dòng này chỉ còn cho code cũ.
Theme.HEADER_INSET = Tokens.MODAL.HEADER_INSET
Theme.HEADER_HEIGHT = Tokens.MODAL.HEADER_HEIGHT
Theme.HEADER_RADIUS = Tokens.RADIUS.HEADER

function Theme.HeaderSlot(panelWidth: number): (UDim2, UDim2)
	local inset = Theme.HEADER_INSET
	return UDim2.fromOffset(inset, inset), UDim2.fromOffset(panelWidth - inset * 2, Theme.HEADER_HEIGHT)
end

--[[
	NÚT ĐÓNG "X" CỦA MODAL — MỘT KHUÔN DÙNG CHUNG (2026-08-15).

	Mười modal trước đây mỗi cái tự dựng lại nút này (cùng màu, cùng cỡ, cùng hover) và mỗi cái
	lệch một chút — user báo "UI shop chưa đồng bộ với các UI khác". Gom về một chỗ thì không
	còn cách nào lệch được nữa.

	Bản cũ chồng thêm một `UIStroke` Contextual để vá viền chữ "X"; giờ chữ đi qua
	`MakeOutlineLabel` nên đã có viền chuẩn `Theme.TEXT_STROKE`, bỏ được lớp vá đó.

	66×66 ở canvas 1080 = trên ngưỡng chạm tối thiểu của Roblox (0.06 × chiều cao) kể cả sau khi
	modal bị `UIScale` thu lại.
]]
function Theme.MakeCloseButton(props: { Position: UDim2, Hovered: any, Activated: () -> (), ZIndex: number? })
	local zIndex = props.ZIndex or Tokens.Z.MODAL_CLOSE
	return Theme.MakeSurface({
		ClassName = "TextButton",
		Position = props.Position,
		Size = UDim2.fromOffset(Tokens.MODAL.CLOSE_SIZE, Tokens.MODAL.CLOSE_SIZE),
		ZIndex = zIndex,
		-- Bán kính của NÚT, không phải của header: nút X là một cái nút, nên nó phải theo
		-- `RADIUS.BUTTON`. Trước đây nó mượn `RADIUS.HEADER`, nên lúc header đổi bo góc
		-- (10 → 14 ngày 2026-08-16) nút X tròn theo một cách không ai định.
		Radius = Tokens.RADIUS.BUTTON,
		Border = Tokens.MODAL.BORDER,
		Studs = false,
		Color = Computed(function()
			return if props.Hovered:get() then Tokens.COLOR.CLOSE_HOVER else Tokens.COLOR.CLOSE
		end),
		Activated = props.Activated,
		MouseEnter = function()
			props.Hovered:set(true)
		end,
		MouseLeave = function()
			props.Hovered:set(false)
		end,
		Zoom = { Hovered = props.Hovered, Scale = 1.1 },
		Content = function(zoom)
			return {
				Theme.MakeOutlineLabel({
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					Text = "X",
					Zoom = zoom,
					MaxTextSize = 48,
					ZIndex = zIndex + 1,
				}),
			}
		end,
	})
end

-- Bán kính TRONG của nút (user chốt 2026-08-15 "bo góc nhỏ lại"). `MakeSurface` tự suy bán kính
-- ngoài = bán kính này + viền. Định nghĩa thật ở `Tokens.RADIUS.BUTTON`.
Theme.BUTTON_RADIUS = Tokens.RADIUS.BUTTON

function Theme.MakeButton(label, colorA: Color3, colorB: Color3, activated: (() -> ())?, externalHovered: any?)
	local hovered = externalHovered or Value(false)
	--[[
		`pressed` sống ở ĐÂY dù `hovered` có thể do caller quản: cú lún khi bấm là chuyện riêng
		của cái nút này, còn `externalHovered` là để caller phóng to cả khối bao ngoài (vd tile
		menu gồm icon + nhãn + nền). Tách hai thứ ra thì nút nào cũng có phản hồi khi chạm, kể
		cả những nút mà caller đã tự lo phần rê chuột.

		⚠️ `InputEnded` chứ không chỉ `MouseButton1Up`: trên cảm ứng không có sự kiện chuột,
		mà mobile mới là nơi cú lún này cần nhất (không có trạng thái rê chuột nào cả).
	]]
	local pressed = Value(false)
	--[[
		Caller tự quản `hovered` (vd: phóng cả tile menu gồm icon + nhãn + nền) thì KHÔNG tự
		phóng ở đây nữa — nếu không cả tile phóng một lần và cái nút bên trong phóng thêm lần
		nữa, thành ra nhân đôi.

		Ngược lại thì `Zoom` lo cả rê chuột lẫn cú lún khi bấm, và nở đều 4 góc.
	]]
	local zoom = if externalHovered then nil else { Hovered = hovered, Pressed = pressed }

	return Theme.MakeSurface({
		ClassName = "TextButton",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 12,
		Radius = Theme.BUTTON_RADIUS,
		Color = colorA,
		ColorB = colorB,
		Zoom = zoom,
		Content = function(zoomScale)
			return {
				Theme.MakeOutlineLabel({
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					Text = label,
					Zoom = zoomScale,
					MaxTextSize = 34,
					MinTextSize = 10,
					ZIndex = 14,
				}),
			}
		end,
		Activated = function()
			if activated then
				activated()
			end
		end,
		InputBegan = function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				pressed:set(true)
			end
		end,
		InputEnded = function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				pressed:set(false)
			end
		end,
		MouseEnter = function()
			hovered:set(true)
		end,
		MouseLeave = function()
			hovered:set(false)
			-- Kéo ngón/chuột ra khỏi nút giữa chừng: không nhả cờ ở đây thì nút kẹt ở trạng
			-- thái lún vĩnh viễn (InputEnded bắn ở chỗ khác, không tới nút này).
			pressed:set(false)
		end,
	})
end

--[[
	RED DOT SYSTEM — chấm đỏ góc trên-phải tile menu, báo "có việc chưa làm".

	`badge` là một state Fusion trả boolean (Value hoặc Computed). Truyền nil = không có chấm.
	Dùng ở LeftMenu cho Daily (còn phần thưởng chưa nhận) và Rebirth (đã đủ điều kiện rebirth).

	── DỰNG BẰNG UI, KHÔNG DÙNG ẢNH (2026-08-08, user chốt) ──────────────────────────────
	Bản trước là một ImageLabel đơn (`rbxassetid://98240291643288`). User thấy không đẹp, và
	nó cũng không hợp ngôn ngữ hình ảnh của game: mọi thứ khác trong HUD đều là khối bo góc
	có viền đen dày + gradient + studs, riêng chấm đỏ là một ảnh phẳng.

	Bản này gồm 4 lớp, xếp từ ngoài vào:
	  1. QUẦNG SÁNG  — vòng đỏ mờ nở ra 1 → 1.55 rồi tan (như sóng radar). Đây là thứ kéo mắt
	     ở tầm nhìn ngoại vi; chấm đứng yên rất dễ bị bỏ qua khi HUD đông màu.
	  2. VIỀN ĐEN 4px — đúng độ dày viền của mọi nút trong game, để chấm "thuộc về" HUD.
	  3. GRADIENT đỏ tươi → đỏ sẫm (dọc) — cho chấm có khối, không bẹt.
	  4. CHẤM SÁNG trắng lệch trên-trái — highlight kiểu vẽ tay, đọc ra là "quả cầu bóng".
	Kèm dấu "!" ở giữa: chấm trơn chỉ nói "có gì đó", dấu chấm than nói "vào xem đi".

	Toàn bộ nhịp thở nằm trên `UIScale` của bọc ngoài (1 ↔ 1.12) — chậm và biên độ nhỏ hơn
	bản cũ (1.18) vì giờ đã có quầng sáng làm phần "động"; hai hiệu ứng cùng mạnh thì rối.

	ZIndex 20+ > icon (14) và nhãn (15) nên không bị che.
]]
local RED_DOT_SIZE = 40

local function makeRedDot(badge: any): Instance
	-- Quầng sáng: nở + tan liên tục. Không đảo chiều (`reverses = false`) vì sóng radar phải
	-- luôn đi RA — cho nó co ngược lại trông như đang thở, mất hẳn cảm giác "báo động".
	local halo = New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 68, 68),
		BackgroundTransparency = 0.45,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		[Children] = {
			New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
		},
	}) :: Frame

	local haloScale = Instance.new("UIScale")
	haloScale.Scale = 1
	haloScale.Parent = halo
	TweenService
		:Create(haloScale, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Scale = 1.55 })
		:Play()
	TweenService:Create(halo, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), {
		BackgroundTransparency = 1,
	}):Play()

	local body = New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(236, 40, 52),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 21,
		[Children] = {
			New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			Theme.MakeStroke(Color3.fromRGB(26, 4, 8), 4),
			Theme.MakeGradient(Color3.fromRGB(255, 96, 104), Color3.fromRGB(186, 12, 32)),
			-- Highlight trắng lệch trên-trái: mắt đọc ra khối cầu bóng thay vì hình tròn phẳng.
			-- Nhỏ và mờ — bản đầu để 0.34×0.24 / mờ 0.55 thì phóng to lên trông như vệt bẩn
			-- dán trên quả bóng chứ không ra ánh phản chiếu.
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.62,
				Position = UDim2.fromScale(0.23, 0.16),
				Size = UDim2.fromScale(0.26, 0.17),
				ZIndex = 22,
				[Children] = { New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				Text = "!",
				MaxTextSize = 26,
				TextStrokeThickness = 2,
				ZIndex = 23,
			}),
		},
	})

	local wrapper = New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		-- Góc trên-phải, nhô một chút ra ngoài viền tile cho nổi. Theo TỈ LỆ ô (giống icon và
		-- nhãn) để còn bám đúng góc khi `LeftMenu` đổi `CellSize`.
		Position = UDim2.fromScale(0.94, 0.12),
		Size = UDim2.fromOffset(RED_DOT_SIZE, RED_DOT_SIZE),
		Visible = badge,
		ZIndex = 20,
		[Children] = { halo, body },
	}) :: Frame

	local pulse = Instance.new("UIScale")
	pulse.Scale = 1
	pulse.Parent = wrapper
	TweenService
		:Create(
			pulse,
			TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.12 }
		)
		:Play()

	return wrapper
end

--[[
	`sunburst = true`: hào quang xoay TO HƠN Ô NÚT, đặt ở lớp dưới cùng nên chỉ phần tia
	thò ra ngoài mép tile là nhìn thấy — nút vẫn sạch, nhưng cả cụm menu có một điểm chuyển
	động duy nhất kéo mắt về. Dùng cho nút cần bán hàng (Shop).

	⚠️ Chỉ nên bật cho MỘT nút. Bật cho vài nút là mất tác dụng ngay: mắt không còn biết
	nhìn đâu, y như chuyện chấm đỏ đã ghi ở LeftMenu.
]]
function Theme.MakeMenuButton(
	label: string,
	icon: string,
	colorA: Color3,
	colorB: Color3,
	action: (() -> ())?,
	badge: any?,
	sunburst: boolean?
)
	local hovered = Value(false)
	--[[
		Ô lưới = khung BỌC trong suốt đứng yên; toàn bộ phần nhìn thấy nằm trong `Theme.MakeZoomHost`
		và phóng quanh TÂM. Bản cũ treo `HoverZoom` thẳng lên ô lưới (AnchorPoint 0,0) nên tile nở
		về phải + xuống dưới, góc trái-trên đứng im — xem khối lý do ở cuối `MakeSurface`.
	]]
	return Theme.MakeZoomHost({
		Size = UDim2.fromOffset(126, 126),
		Zoom = { Hovered = hovered, Scale = 1.08 },
		Children = {
			--[[
				Hào quang nằm TRONG ô nút, không tràn ra ngoài.

				Bản đầu để nó to 206px và ZIndex 0 cho "toả ra ngoài mép tile" — sai hai lần:
				ZIndex 0 đẩy nó xuống dưới MỌI thứ, mà phần thò ra lại rơi đúng vào ô của
				nút bên cạnh (lưới 2 cột, khe chỉ 12px) nên bị che gần hết; phần còn thấy thì
				màu trắng mặc định chìm nghỉm vào nền cát sáng của Lobby.

				⚠️ Bản thứ hai (ZIndex 12, cỡ 128) TÀNG HÌNH vì HAI lỗi chồng nhau, mất một vòng
				nghiệm thu mới tách ra được:
				  1. Nền nút `Theme.MakeButton` cũng đúng ZIndex 12 và là sibling ĐỨNG SAU trong
				     danh sách con ⇒ ZIndex hoà nhau thì cái vẽ sau đè lên. Phải là 13.
				  2. Ảnh sunburst có tia MẠNH ở giữa và MẢNH DẦN ra rìa. Đặt vừa ô nút thì đúng
				     phần giữa ấy nằm khuất sau icon 88px, chỉ còn mấy đầu tia mờ tịt lòi ra —
				     tô magenta đặc cũng gần như không thấy gì (đã thử).

				Bản thứ ba to GẤP ĐÔI ô nút (250px): vành sáng rơi đúng viền quanh icon, nhưng
				các tia thì chạy thẳng ra bốn góc và bị khung `ClipsDescendants` cắt cụt — nhìn
				thành một hoa văn bị xén chứ không phải một vầng hào quang.

				Bản thứ tư (2026-08-12 → 08-15): 150px nhốt trong khung `ClipsDescendants` bo góc
				16. ĐÂY LÀ BẢN GÂY LỖI "nền tràn ra khỏi stroke" mà user chỉ ra ở nút Shop, và
				lý do đã đo được bằng thí nghiệm đối chứng trong Studio (2026-08-15):

				  ⚠️⚠️ `ClipsDescendants` CẮT THEO HÌNH CHỮ NHẬT, KHÔNG THEO GÓC BO.
				  Đặt `UICorner` lên khung có `ClipsDescendants` KHÔNG làm vùng cắt tròn theo —
				  `UICorner` chỉ bo cái NỀN của chính khung đó (mà khung này trong suốt). Nên
				  bốn góc vuông của vùng cắt vẫn cho tia sáng lọt ra đúng chỗ nút đã bo tròn, đè
				  lên viền đen. `CanvasGroup` cũng KHÔNG cứu được (đã thử: nó còn không cắt gì cả).
				  Cách DUY NHẤT bo tròn một lớp phủ là đặt `UICorner` lên CHÍNH lớp đó — mà hào
				  quang thì to hơn ô nút nên không dùng được cách này.

				BẢN HIỆN TẠI: bỏ hẳn khung cắt, cho hào quang nằm DƯỚI nút (ZIndex 11 < 12) và
				toả tự do ra NGOÀI ô. Phần chồng lên nút bị nền đục của nút che hết, phần thò ra
				thành vầng sáng quanh tile — đúng như nút Shop trong ảnh tham chiếu của user.
				Không còn lớp nào cắt qua góc bo nên không thể hở viền nữa.

				ZIndex 11 (không phải 0): ScreenGui dùng `ZIndexBehavior = Global`, để 0 là chui
				xuống dưới cả nền thế giới lẫn mọi HUD khác — đã hỏng đúng như vậy ở bản đầu.
			]]
			if sunburst
				then Theme.MakeSunburst({
					-- `MakeSunburst` đã tự đặt AnchorPoint (0.5, 0.5) nên đây là TÂM ô nút.
					Position = UDim2.fromScale(0.5, 0.5),
					--[[
						⚠️ THEO TỈ LỆ Ô, KHÔNG PHẢI OFFSET CỨNG (sửa 2026-08-19).

						Bản cũ để `fromOffset(190, 190)` — con số đó chỉnh cho ô 122×112. Ngày
						2026-08-16 ô menu to thêm 10% (134×124, xem `CELL_W` trong `LeftMenu`)
						nhưng hào quang thì đứng yên, nên phần THÒ RA co từ 34 px xuống 28 px
						mỗi bên. Mà phần thò ra chính là toàn bộ thứ nhìn thấy được: khúc nằm
						trong ô đã bị nền đục của nút che kín. Kết quả đúng như user báo —
						"nút Shop thiếu hiệu ứng sunburst".

						Để theo Scale thì hào quang tự lớn theo ô mãi mãi, không còn cặp số nào
						phải nhớ đồng bộ tay. Đây đúng bài học mà chính `LeftMenu` đã rút ra cho
						năm con số bố cục của nó (xem khối "CỠ Ô MENU TRÁI — MỘT CHỖ DUY NHẤT").
					]]
					--[[
						VỪA Ô NÚT (user chốt 2026-08-19: "kích thước sunburst vừa với button thôi").

						1.28 là cỡ NỀN; `Pulse` gắn thêm một `UIScale` dao động 0.92 ↔ 1.12, nên
						hào quang thở trong khoảng 1.18× → 1.43× ô nút. Vì sao KHÔNG để đúng 1.0:
						ảnh sunburst có lõi sáng ở giữa và tia mảnh dần ra rìa — để vừa khít ô thì
						cái lõi ấy nằm gọn sau icon 61px, phần còn nhìn thấy chỉ là mấy đầu tia mờ
						nhất. 1.28 đẩy vành tia ra tới đúng mép tile, chỗ mắt đọc được là "quầng
						sáng quanh nút" chứ không phải một vệt loang sau icon.
					]]
					Size = UDim2.fromScale(1.28, 1.28),
					--[[
						⚠️ ZIndex 14, KHÔNG PHẢI 13 — và đây là lần THỨ BA cùng một cái bẫy.

						User chốt 2026-08-19: "nó phải nằm trên button shop và dưới icon". Bản đầu
						để 11 (dưới mặt nút) nên bị nền đục che kín. Bản sau nâng lên 13 vì tưởng
						mặt nút là ZIndex 12 — ĐO LẠI TRONG STUDIO 2026-08-19 thì không phải:

						    TextButton      Z=12   (nền ngoài)
						      └ Frame       Z=13   BackgroundTransparency=0  ← LỚP ĐỤC THẬT SỰ
						      └ ImageLabel  Z=14   (hoa văn studs)
						    ImageLabel      Z=14   (icon)
						    TextLabel       Z=15   (nhãn)

						Lớp mặt đục nằm ở 13, và nó là sibling ĐỨNG SAU hào quang ⇒ ZIndex hoà nhau
						thì cái duyệt sau vẽ đè lên. Kết quả: hào quang tồn tại, Visible=true,
						ImageTransparency=0.12, mà trên màn hình KHÔNG THẤY GÌ — đúng như user báo.

						14 thắng lớp đục (13). Icon cũng 14 nhưng là sibling ĐỨNG SAU nên vẫn nổi
						lên trên hào quang — chính cái luật hoà-thì-sau-thắng vừa gây lỗi giờ cho
						đúng thứ tự ta cần. Nhãn 15 thì luôn ở trên.

						Chỉ hoạt động vì ScreenGui đặt `ZIndexBehavior = Global`; ở chế độ
						Sibling thì con không bao giờ xen được vào giữa các lớp của cha.
					]]
					ZIndex = 14,
					--[[
						KEM SÁNG chứ không phải vàng (đổi 2026-08-19 cùng lúc với ZIndex).

						Hào quang giờ nằm TRÊN mặt nút, mà mặt nút Shop là gradient vàng-cam. Màu
						cũ 255,236,150 là vàng — vàng trên cam thì tương phản gần bằng 0, đó là lý
						do lần trước phải hạ độ mờ xuống 0.12 mà vẫn thấy "mờ quá". 255,252,226
						sáng hơn hẳn mọi điểm của gradient bên dưới nên tia đọc ra ngay ở 0.1.
					]]
					ImageColor3 = Color3.fromRGB(255, 252, 226),
					ImageTransparency = 0.1,
					Pulse = true,
					SpinSeconds = 9,
				})
				else nil,
			Theme.MakeButton("", colorA, colorB, action, hovered),
			if badge ~= nil then makeRedDot(badge) else nil,
			--[[
				⚠️ Icon và nhãn đo theo TỈ LỆ ô, không phải offset px.

				Cỡ ô do `UIGridLayout.CellSize` của `LeftMenu` quyết định — layout GHI ĐÈ `Size`
				của Frame này, nên con số 126×126 khai ở trên chỉ là giá trị lúc chưa vào lưới.
				Bản cũ đặt icon 88px và nhãn tại y = 84 bằng offset tuyệt đối: vừa khít ô 130,
				nhưng thu ô xuống 112 (theo ảnh tham chiếu) là nhãn tụt hẳn ra ngoài đáy nút.
				Dùng scale thì đổi `CellSize` một dòng là cả sáu nút tự cân lại.

				`UIAspectRatioConstraint` giữ icon VUÔNG cả khi ô hơi chữ nhật (ảnh tham chiếu
				rộng 122 × cao 112) — thiếu nó là icon bị bóp dẹt.
			]]
			New("ImageLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(0.78, 0.78),
				ZIndex = 14,
				[Children] = {
					New("UIAspectRatioConstraint")({ AspectRatio = 1 }),
				},
			}),
			Theme.MakeOutlineLabel({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(0.94, 0.28),
				Text = label,
				MaxTextSize = 26,
				ZIndex = 15,
			}),
			New("UIPadding")({
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
			}),
		},
	})
end

function Theme.FormatInteger(value: number): string
	return require(ReplicatedStorage.Shared.Constants).FormatNumber(math.max(0, value))
end

--[[
	⚠️ UỶ QUYỀN — logic thật nằm ở `HUD/Responsive` (hệ responsive v2, 2026-08-17).

	Giữ tên cũ vì `HUDController` và ~10 file khác đang gọi. Hệ boost cũ (`MOBILE_BOOST` +
	hai ngưỡng fit đoán bằng mắt) đã BỎ HẲN: tỉ lệ giờ suy ra từ luật ngón tay.
]]
function Theme.UpdateViewportScale()
	Responsive.Recompute()
end

--[[
	Bí danh cũ của `Responsive.Screen()` — mép MÀN HÌNH, tính bằng design px.

	Giữ tên và thứ tự trả về (left, top, right, bottom, scale) vì `FriendsHud`, `BoostHud`,
	`BoostCelebration`, `WinsFlight`, `SettingsModal`… đang gọi. Bốn cụm đó vốn đã neo theo MÉP
	nên chúng tự động chạy đúng luật mới, không phải sửa dòng nào.

	Trên máy 16:9 hàm trả về đúng (0, 36, 1920, 1080) — khung bản vẽ, chỉ khác `top` đã cộng
	topbar. Máy khác 16:9 thì khung NỚI RA, không bao giờ hẹp lại (xem `Responsive.Screen`).
]]
function Theme.GetVisibleDesignBounds(): (number, number, number, number, number)
	local s = Responsive.Screen()
	return s.Left, s.Top, s.Right, s.Bottom, s.Scale
end

--[[
	TÂM CỦA VÙNG NHÌN THẤY (không phải tâm canvas 1920×1080).

	Modal đang neo cứng ở (960, 492) — đúng trên PC vì vùng nhìn thấy CHÍNH LÀ canvas. Trên
	máy có tỉ lệ khác 16:9 thì vùng nhìn thấy lệch đi, và modal neo cứng sẽ lệch theo đúng
	chừng ấy: trên máy rộng-thấp nó bị đẩy lên chạm topbar.

	`offsetY = -48` giữ nguyên nét thiết kế cũ: modal nằm hơi cao hơn tâm (492 so với 540) để
	chừa chỗ cho thanh XP/Level dưới đáy.
]]
--[[
	══ TÂM MODAL ════════════════════════════════════════════════════════════════════════════

	Modal là thứ CĂN GIỮA MÀN HÌNH (không phải bám mép), nên nó lấy tâm màn hình rồi nhích lên
	`MODAL_RAISE` để chừa chỗ cho cụm HUD đáy — đúng nét thiết kế của bản vẽ.

	Trên máy 16:9: (36 + 1080)/2 − 48 = 510, trừ tiếp 18px trượt khi mở ⇒ **(960, 492)**, đúng
	bằng con số ghi trong tài liệu thiết kế. Máy khác 16:9 thì tâm đi theo tâm màn hình thật.

	── HAI CÁI SÀN, VÌ TOPBAR VÀ DẢI NHẮC LÀ VẬT CẢN THẬT ────────────────────────────────────
	Căn giữa thuần sẽ đẩy modal cao lên chui vào topbar trên điện thoại (topbar cao 58 px thật =
	151 design px ở tỉ lệ 0.38 — đo được mép trên modal rơi vào 53 px, tức NÚT X không bấm được).
	Nên tâm bị KẸP SÀN theo hai vật cản, tính cả 18px trượt lên khi mở:

	    sàn = mép trên khả dụng + (chiều cao dải nhắc nếu đang hiện) + nửa chiều cao modal + 8 + 18

	⚠️ Sàn dùng `math.max` chứ không phải kẹp hai đầu: khi màn hình quá chật để vừa cả modal lẫn
	cụm HUD đáy (điện thoại + modal cao nhất), modal ĐƯỢC PHÉP đè lên cụm đáy. Thứ tự ưu tiên là
	có chủ ý — thanh XP chỉ là thông tin thụ động, còn thanh tiêu đề + nút X của modal mà bị che
	thì người chơi kẹt luôn trong modal.
]]
Theme.MODAL_RAISE = 48
-- Chiều cao dải nhắc tutorial + khe hở, tính bằng design px (xem `TutorialController`).
Theme.MODAL_TUTORIAL_RESERVE = 108

function Theme.GetModalCenter(): (number, number)
	return Theme.ModalCenterFor(Tokens.SAFE_CONTENT_HEIGHT)
end

function Theme.ModalCenterFor(contentHeight: number): (number, number)
	local s = Responsive.Screen()
	local half = contentHeight * 0.5
	local slide = Tokens.MODAL.SLIDE

	local centerX = (s.Left + s.Right) * 0.5
	local centerY = (s.Top + s.Bottom) * 0.5 - Theme.MODAL_RAISE

	local reserve = if State.tutorialBannerVisible:get() then Theme.MODAL_TUTORIAL_RESERVE else 0
	local floorY = s.Top + reserve + half + 8 + slide

	return centerX, math.max(centerY, floorY)
end

--[[
	Nhích lên bao nhiêu thì vừa — dùng chung cho cụm nút trái và modal (user 2026-08-14:
	"chỉnh UI tab bên trái và UI khi bật các tab lên cao một chút").

	Không nhích bằng một hằng số cứng: chỗ trống trên/dưới mỗi máy một khác, mà nhích quá tay
	là mép trên chui vào topbar Roblox. Nên nhích theo PHẦN DƯ THẬT SỰ của chính khối đó:
	dư nhiều thì nhích nhiều, và luôn chừa `TOP_MARGIN` để không dán sát topbar.

	`contentHeight` = chiều cao khối (design px). Trả về số px design cần trừ vào tâm.
]]
--[[
	══ CỘT PHẢI — MỘT CHỒNG DỌC DUY NHẤT (2026-08-14) ══════════════════════════════════════

	Trước đây cột phải là BỐN CỤM RỜI, mỗi cụm tự neo một kiểu ở ba file khác nhau
	(`RightPanel`, `StarterPackCard`, `BoostHud`): Spin/Playtime treo lơ lửng phía trên bằng
	offset ÂM (-302, -160), nút x2 Speed ở giữa, Custom Speed bên dưới. Hệ quả là mỗi lần đổi
	kích thước một món phải chỉnh tay offset của những món còn lại, và trên máy tỉ lệ khác
	16:9 chúng trôi mỗi cái một hướng.

	Giờ tất cả ăn chung MỘT bảng slot: cùng một mép phải, cùng bề rộng cột, chỉ khác `y`.
	Đổi thứ tự hay chiều cao một món = sửa đúng một dòng ở đây.

	THỨ TỰ (user chốt 2026-08-15):
	    Starter Pack → Spin → Playtime Boost → Custom Speed → x2 Speed
	Ba món ĐỒNG HỒ nằm liền nhau ở trên (Starter Pack đếm lùi 48h, Spin đếm lùi vé free,
	Playtime đếm lên) — chúng là cùng một loại thông tin nên đứng chung một cụm, mắt đọc một
	lần là xong. Hai món BẤM ĐỂ MUA/CHỈNH (Custom Speed, x2 Speed) tách xuống dưới thành cụm
	thứ hai, và vì nằm thấp hơn nên ngón cái trên mobile với tới dễ nhất.

	Vì sao MỘT CHỒNG lại đúng chuẩn: trên mobile ngón cái phải với tới dải này dễ nhất, và mắt
	quét một cột thẳng nhanh hơn quét bốn cụm rải rác — đó là lý do gần như mọi simulator lớn
	đều xếp cột phải theo kiểu này.

	⚠️ Số ở đây là ĐỈNH của ô, tính từ đỉnh chồng. Muốn đổi thứ tự thì đổi ĐÚNG bảng này, đừng
	đổi thứ tự các khối trong `RightPanel.Build` — vị trí đọc từ bảng, không từ thứ tự khai báo.
	Chiều cao thực tế từng ô: starterPack 186, spin 130, playtime 110, customSpeed 118,
	speedPromo 70. Khe hở giữa các ô ≈ 10–14px.
]]
Theme.RIGHT_COLUMN_WIDTH = 286
-- Lề tính từ mép PHẢI của màn hình (bản vẽ: x = 1920 − 20 − 286 = 1614).
Theme.RIGHT_COLUMN_MARGIN = 20
--[[
	Lề TRÊN, hạ 20 → 10 ngày 2026-08-17 (user: "vướng nút nhảy").

	Cột phải vốn ĐÃ neo sát mép trên nên không còn chỗ kéo lên — cách duy nhất để nhấc ô cuối
	(nút x2 Speed) khỏi nút nhảy là rút ngắn chính cái chồng. Hạ lề trên 10 và siết ba khe hở
	trong `RIGHT_STACK` là tất cả những gì lấy được mà không đụng tới thiết kế của các ô.

	⚠️ Đo ở 801×392: nút nhảy chiếm y 244..314 px thật, ô x2 Speed nằm 260..283 — hai thứ này
	CHỒNG NHAU và phần rút ngắn ở đây chỉ kéo được ~7 px. Muốn tách hẳn thì phải bớt một ô khỏi
	cột (hoặc đổi thứ tự để ô cuối là ô ít bấm nhất) — đó là quyết định thiết kế, không phải
	chuyện của hệ responsive.
]]
Theme.RIGHT_COLUMN_TOP_MARGIN = 10

-- Khoảng cách từ ĐỈNH chồng tới đỉnh từng ô (design px).
-- 2026-08-17: siết ba khe 10 → 6 để ô cuối (x2 Speed) nhấc lên khỏi nút nhảy. Cộng với lề trên
-- hạ 20 → 10, cả chồng ngắn lại 22 design px.
Theme.RIGHT_STACK = {
	starterPack = 0, -- cao 186
	spin = 192, -- cao 130
	playtime = 328, -- cao 110
	customSpeed = 444, -- cao 118 (kết thúc ở 562)
	-- ⚠️ Khe trước ô này phải ≥ 22px: badge giá Robux của nút x2 nhô LÊN 22px trên mép nút
	-- (xem `MakePriceLabel` trong RightPanel). Hẹp hơn là badge đè lên đáy panel Custom Speed —
	-- hai ô này cùng rộng 214 và cùng mép trái nên chồng nhau rất rõ.
	speedPromo = 584, -- cao 70 (khe 22 giữ nguyên: 562 + 22 = 584)
}

-- Vị trí góc TRÁI-TRÊN của một ô trong chồng. Mọi ô dùng `AnchorPoint (0, 0)` và tự căn phải
-- bên trong bề rộng cột, nên ô hẹp hơn cột vẫn thẳng mép phải.
function Theme.RightSlotPosition(slot: string): UDim2
	--[[
		Bám GÓC PHẢI-TRÊN màn hình, cách mép 20 design px mỗi chiều.

		`Responsive.Screen().Top` đã cộng sẵn chiều cao topbar Roblox, nên trên PC (topbar 36) ra
		đúng y = 56 như bản vẽ, còn trên điện thoại (topbar 58) cột tự tụt xuống dưới topbar thay
		vì chui vào dưới nó. Đây chính là lý do lề và inset phải TÁCH RIÊNG: lề co theo `scale`,
		còn topbar là vật lý nên không co.
	]]
	local origin = Responsive.AnchorPos({
		X = "right",
		Y = "top",
		Width = Theme.RIGHT_COLUMN_WIDTH,
		Height = 688,
		MarginX = Theme.RIGHT_COLUMN_MARGIN,
		MarginY = Theme.RIGHT_COLUMN_TOP_MARGIN,
	})
	return UDim2.fromOffset(origin.X.Offset, origin.Y.Offset + (Theme.RIGHT_STACK[slot] or 0))
end

Theme.TOP_MARGIN = 16
--[[
	Nhích lên một khoảng CỐ ĐỊNH (design px), KHÔNG phải một tỉ lệ của chỗ trống.

	Bản đầu dùng tỉ lệ 0.42 × chỗ trống. Trên điện thoại chỗ trống hẹp nên nó ra ~48px, nhìn
	đúng ý. Nhưng trên TABLET (iPad 1024×768, tỉ lệ 4:3) vùng nhìn thấy cao tới ~1071 design px
	— chỗ trống gấp nhiều lần, nên cùng công thức đó nhích tới ~193px và đẩy cụm nút trái lên
	tận y = 85 trong khi PC để ở 236. Đó chính là "tablet bị cao quá" mà user báo.

	Khoảng cố định giữ ĐÚNG MỘT hành vi ở mọi máy: nhích một chút so với căn giữa, và trên máy
	rộng rãi thì kết quả gần trùng bố cục PC (PC: cụm trái tâm 541 ≈ tâm canvas 540).
]]
Theme.RAISE_OFFSET = 48

--[[
	══ VÙNG CHẠM TỐI THIỂU — GIỜ LÀ TỰ ĐỘNG ════════════════════════════════════════════════

	Đo ở viewport 735×413 (bản cũ): 83 nút có cạnh ngắn dưới 30 px thật, nhiều nút chỉ 20–22 px
	(nút X đóng modal, các nút nhỏ trong danh sách). Ngón tay cần ~44 px mới bấm chắc, nên phần
	lớn nút trong game đang "bấm mười lần trúng bảy".

	Bản cũ có helper `Theme.MakeTouchTarget` nhưng CHƯA BAO GIỜ được nối vào nút nào — nó bắt
	caller tự truyền cỡ nút bằng tay cho hàng trăm nút, nên trên thực tế không ai gọi.

	GIỜ: `Theme.MakeSurface` TỰ gắn vùng chạm cho mọi nút nó dựng (xem cuối `MakeSurface`), đo
	cỡ thật lúc chạy nên không cần khai báo gì. Gần như mọi nút trong game đi qua `MakeSurface`,
	nên đây là một chỗ sửa cho cả game. Nút dựng bằng `ImageButton` thô thì gọi tay
	`Responsive.AttachHitArea`.
]]
Theme.MIN_TOUCH_PX = Tokens.TOUCH.MIN_PX

-- Giữ tên cũ cho code ngoài; logic thật ở `Responsive`. `designSize` không còn cần (đo lúc chạy)
-- nhưng vẫn nhận để chữ ký cũ không vỡ.
function Theme.AttachTouchTarget(host: GuiObject, action: (() -> ())?, _designSize: number?)
	if action == nil then
		return nil
	end
	return Responsive.AttachHitArea(host, action)
end

function Theme.GetRaiseOffset(contentHeight: number): number
	local _, top, _, bottom = Theme.GetVisibleDesignBounds()
	local slack = (bottom - top) - contentHeight
	if slack <= 0 then
		return 0
	end
	-- Nửa phần dư là mức tối đa có thể nhích (nhích hơn = tràn mép trên).
	return math.clamp(Theme.RAISE_OFFSET, 0, math.max(0, slack * 0.5 - Theme.TOP_MARGIN))
end

-- Vị trí chuẩn của mọi modal: tâm vùng nhìn thấy + trượt lên 18px theo hoạt ảnh mở.
-- Dùng chung để 10 modal không mỗi cái chép một con số neo cứng.
-- `contentHeight`: chiều cao THẬT của modal (design px). Truyền vào thì modal được nhích lên
-- theo đúng chỗ trống của riêng nó; bỏ trống thì rơi về khối cao nhất (an toàn nhưng ít nhích).
--[[
	Vị trí chuẩn của MỌI modal. `animation` 0→1 là quãng trượt lên 18px khi mở.

	`contentHeight` = chiều cao THẬT của modal: cần nó để tính sàn tránh topbar/dải nhắc (modal
	càng cao thì tâm càng phải xuống thấp mới đủ chỗ cho mép trên). Bỏ trống thì rơi về khối cao
	nhất — an toàn, nhưng modal nhỏ sẽ bị đẩy xuống thấp hơn mức cần thiết.
]]
function Theme.ModalPosition(animation: number, contentHeight: number?): UDim2
	local centerX, centerY = Theme.ModalCenterFor(contentHeight or Tokens.SAFE_CONTENT_HEIGHT)
	return UDim2.fromOffset(centerX, centerY - (Tokens.MODAL.SLIDE * animation))
end

return Theme
