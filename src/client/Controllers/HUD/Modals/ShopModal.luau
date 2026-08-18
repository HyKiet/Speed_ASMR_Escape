--!strict
-- Modal Shop: bán Gamepass + Developer Product (Robux).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local Ownership = require(script.Parent.Parent.Ownership)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local localPlayer = Players.LocalPlayer

local ShopModal = {}

-- Bề rộng vỏ SUY RA từ khung cuộn (khai ngay dưới) — xem khối "KÍCH THƯỚC SHOP".
--[[
	700 = CAO NHẤT còn lọt màn hình, đã đo chứ không đoán.

	Khoảng trống dọc thật của canvas 1080 chỉ có ~700px: dải nhắc tutorial chiếm 8..95, còn cụm
	HUD đáy (khối hệ số nhân + thanh XP) chiếm 795..1019. Thử 812 thì mép trên modal rơi xuống
	y = 39 — chui hẳn dưới dải nhắc, đồng thời đáy tràn qua khối hệ số nhân.

	So với bản cũ (760 × UIScale 0.86 = 654 px thật) thì 700 vẫn CAO HƠN 7%, và bỏ `UIScale` nên
	bề ngang nhảy từ 808 lên 1012 (+25%). Thẻ to lên tương ứng.
]]
local PANEL_HEIGHT = 700

local function promptPurchase(item: State.ShopItemConfig)
	if item.purchaseId <= 0 then
		Toast.Show(`Set {item.title} product id`)
		return
	end

	if item.purchaseKind == "gamepass" then
		MarketplaceService:PromptGamePassPurchase(localPlayer, item.purchaseId)
	else
		MarketplaceService:PromptProductPurchase(localPlayer, item.purchaseId)
	end
end

--[[
	══ KÍCH THƯỚC SHOP — MỘT NGUỒN SỰ THẬT (2026-08-15) ═════════════════════════════════════

	Trước đây bốn con số này bị chép rời ở sáu chỗ (ô lưới, khung chứa lưới, khung section, và
	phép cộng `totalHeight` trong `makeScroll`). Đổi cỡ thẻ mà quên một chỗ là thanh cuộn tính
	sai chiều cao rồi cắt cụt mục cuối — đã dính đúng lỗi đó khi nới thẻ lần này.

	`SHOP_GRID_WIDTH` = 2 thẻ + khe, và phải ≤ bề rộng ScrollingFrame.

	── 2026-08-16 (lượt 2): PHÓNG TO + BỎ HẲN `UIScale` ─────────────────────────────────────
	Lượt trước thu thẻ về 424 rồi giữ `UIScale = 0.86` cho modal. Hai vấn đề user chỉ ra:

	  1. "topbar của UI Shop khác so với các UI khác" — ĐÚNG, và nguyên nhân là chính cái
	     `UIScale`: nó co MỌI thứ bên trong kể cả độ dày viền, nên viền Shop render ra 4 × 0.86
	     = 3.44px trong khi mọi modal khác là 4.00px. Đo trong Studio thấy rõ: 3.44px ×34 phần
	     tử, toàn bộ đều thuộc Shop. Thanh tiêu đề vì thế trông mảnh hơn hẳn.
	  2. "chỉnh kích thước to hơn, thẻ to hơn, chiều dọc dài một chút" — chữ trong thẻ đang bé.

	Cả hai cùng một lời giải: BỎ `UIScale`, và bù lại bằng cách khai số đo thật nhỏ hơn. Modal
	giờ là 1012 × 812 vẽ ở tỉ lệ 1:1 — to hơn bản cũ (808 × 654 sau khi co) đúng 25%, và viền
	trở lại 4.00px bằng mọi modal khác.

	⚠️ CHỈ CẦN sửa `SHOP_CARD_WIDTH`/`_HEIGHT`: bề rộng lưới, khung cuộn, vỏ modal và mọi ô chữ
	trong thẻ đều SUY RA từ chúng.
	⚠️ Cao 812 vượt `Tokens.SAFE_CONTENT_HEIGHT` cũ (790) nên hằng đó đã được nới theo — quên là
	modal bị cắt mép trên máy màn hình nhỏ.
]]
local SHOP_CARD_WIDTH = 424
--[[
	236, không phải 214 (user 2026-08-16: "button nằm sát cạnh dưới trông rất xấu").

	Nút mua kết thúc ở y = 212, nên thẻ 214 chỉ chừa 2px dưới nút — nhìn như nút bị tràn khỏi
	thẻ. 236 cho ra lề đáy 24px, cân với lề trên 16 và lề hai bên 16.
]]
local SHOP_CARD_HEIGHT = 236
local SHOP_GRID_WIDTH = SHOP_CARD_WIDTH * 2 + 20
local SHOP_ROW_PITCH = SHOP_CARD_HEIGHT + 20 -- cao thẻ + khe dọc
local SHOP_SECTION_HEAD = 64 + 16 -- băng tiêu đề mục + khe của UIListLayout

-- Cột chữ trong thẻ: bắt đầu sau icon (16 lề + icon + 12 khe), chừa lề phải 16.
local CARD_ICON = 108
local CARD_TEXT_X = 16 + CARD_ICON + 12
local CARD_TEXT_WIDTH = SHOP_CARD_WIDTH - CARD_TEXT_X - 16
-- Khung cuộn + lề hai bên là thứ quyết định bề rộng vỏ modal. Chừa 20 cho thanh cuộn.
local SCROLL_MARGIN = 26
local SCROLL_WIDTH = SHOP_GRID_WIDTH + 20
local PANEL_WIDTH = SCROLL_WIDTH + SCROLL_MARGIN * 2

local function makeCard(item: State.ShopItemConfig)
	local colorA = item.accentColor
	local colorB = colorA:Lerp(Color3.fromRGB(33, 41, 113), 0.58)
	local btnHovered = Value(false)

	-- CHỈ gamepass mới có khái niệm "đã sở hữu". Developer product là hàng tiêu hao
	-- (gói Wins, server boost) — mua bao nhiêu lần cũng được nên luôn hiện giá.
	local owned = if item.purchaseKind == "gamepass" then Ownership.Owns(item.purchaseId) else Value(false)

	--[[
		THẺ SẢN PHẨM — CỠ CHỐT THEO CHUẨN SIMULATOR (2026-08-15).

		Cũ 416×166, chữ tiêu đề 28 / giá trị 23 / mô tả 18, nút mua cao 44. Ở tỉ lệ modal 0.86
		thì mô tả 18px design chỉ còn ~15px thật trên PC và ~6px trên điện thoại — không đọc nổi.

		Mới 472×190. Ba thay đổi theo đúng khuyến nghị của Roblox Creator Hub (UI/UX design):
		  • Vùng chạm: nút mua cao 52 (thay 44). Tài liệu Roblox yêu cầu nút ≥ 0.06 chiều cao màn
		    hình; ở canvas 1080 thì đó là 65px design — 52 × 1.25 (thẻ còn được `UIScale` modal
		    thu lại) là mức thấp nhất còn an toàn, và vẫn trên ngưỡng `Theme.MIN_TOUCH_PX`.
		  • Phân cấp chữ RÕ hơn: tiêu đề 34 > giá trị 27 > mô tả 22. Cũ chỉ chênh nhau 5px nên ba
		    dòng đọc ra như một khối; tài liệu Roblox nhấn mạnh tiêu đề phải lớn và đậm hơn hẳn.
		  • Icon 108 (thay 92) cho cân với thẻ rộng hơn.
	]]
	return Theme.MakeSurface({
		LayoutOrder = item.sortOrder,
		Size = UDim2.fromOffset(SHOP_CARD_WIDTH, SHOP_CARD_HEIGHT),
		ZIndex = 44,
		Radius = Tokens.RADIUS.MODAL,
		Border = Tokens.BORDER,
		Color = colorA,
		ColorB = colorB,
		Content = {
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = item.icon,
				Position = UDim2.fromOffset(16, 20),
				Size = UDim2.fromOffset(CARD_ICON, CARD_ICON),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(CARD_TEXT_X, 16),
				Size = UDim2.fromOffset(CARD_TEXT_WIDTH, 44),
				Text = item.title,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 36,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(CARD_TEXT_X, 62),
				Size = UDim2.fromOffset(CARD_TEXT_WIDTH, 36),
				Text = item.valueText,
				TextColor3 = Color3.fromRGB(255, 238, 111),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 29,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(CARD_TEXT_X, 100),
				Size = UDim2.fromOffset(CARD_TEXT_WIDTH, 34),
				Text = item.subtitle,
				TextColor3 = Color3.fromRGB(232, 251, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 23,
				ZIndex = 46,
			}),
			Theme.MakeSurface({
				ClassName = "TextButton",
				Position = UDim2.fromOffset(CARD_TEXT_X, 150),
				-- Trừ thêm 4 cho viền nút vẽ ra ngoài, để mép phải nút thẳng mép phải cột chữ.
				Size = UDim2.fromOffset(CARD_TEXT_WIDTH - 4, 62),
				ZIndex = 47,
				Radius = 12,
				Border = Tokens.BORDER,
				Color = Computed(function()
					return if owned:get() then Color3.fromRGB(138, 146, 170) else Color3.fromRGB(88, 230, 140)
				end),
				ColorB = Computed(function()
					return if owned:get() then Color3.fromRGB(70, 76, 96) else Color3.fromRGB(30, 150, 72)
				end),
				GradientRotation = 0,
				Activated = function()
					-- Đã sở hữu thì KHÔNG mở prompt nữa. Trước đây bấm vào chỉ nhận được
					-- hộp thoại "You already own this item" của Roblox — trông như lỗi game.
					if owned:get() then
						Toast.Show(`You already own {item.title}`, "success")
						return
					end
					promptPurchase(item)
				end,
				MouseEnter = function()
					btnHovered:set(true)
				end,
				MouseLeave = function()
					btnHovered:set(false)
				end,
				-- `Zoom` (không phải `Outside`): nó vừa phóng cả viền lẫn ruột như một khối, vừa
				-- neo tâm để nút nở ĐỀU ra bốn góc. Xem khối lý do ở cuối `Theme.MakeSurface`.
				Zoom = { Hovered = btnHovered, Scale = 1.08 },
				Content = {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							return if owned:get() then "OWNED ✓" else `\u{E002} {tostring(item.priceRobux)}`
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextXAlignment = Enum.TextXAlignment.Center,
						MaxTextSize = 34,
						ZIndex = 48,
					}),
				},
			}),
		},
	})
end

local function makeSection(sectionConfig: { [string]: any }, index: number)
	local items = Theme.SHOP_CATALOG[sectionConfig.id] or {}
	local rowCount = math.max(1, math.ceil(#items / 2))
	local cardChildren = {
		New("UIGridLayout")({
			CellPadding = UDim2.fromOffset(20, 20),
			CellSize = UDim2.fromOffset(SHOP_CARD_WIDTH, SHOP_CARD_HEIGHT),
			FillDirectionMaxCells = 2,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, item in items do
		table.insert(cardChildren, makeCard(item))
	end
	local children = {
		--[[
			Băng tiêu đề mục.

			── LỖI ĐÃ SỬA 2026-08-16 (user khoanh đỏ: "mất phần stroke của các tiêu đề") ────────
			Băng rộng ĐÚNG `SHOP_GRID_WIDTH`, mà `MakeSurface` vẽ viền RA NGOÀI ô khai báo — nên
			khối ngoài rộng `GRID + 2×BORDER` và tràn khỏi khung mục (chỉ rộng `GRID`). Phần tràn
			đó rơi ra ngoài `ScrollingFrame` và bị CẮT, mất hẳn nét viền trái.

			Chữa: khai băng HẸP ĐI đúng `2×BORDER` để khối ngoài (đã cộng viền) vừa khít bề rộng
			mục — giống hệt lý do header modal khai `Width − 2×BORDER`. Thẻ sản phẩm KHÔNG dính lỗi
			này vì chúng nằm trong `UIGridLayout`, mà layout ghi đè `Position` nên phần viền không
			bị đẩy sang toạ độ âm.
		]]
		Theme.MakeSurface({
			LayoutOrder = 1,
			Size = UDim2.fromOffset(SHOP_GRID_WIDTH - Tokens.BORDER * 2, 64),
			ZIndex = 44,
			Radius = 14,
			Border = Tokens.BORDER,
			Color = sectionConfig.colorA,
			ColorB = sectionConfig.colorB,
			GradientRotation = 0,
			Content = {
				Theme.MakeOutlineLabel({
					Position = UDim2.fromOffset(24, 0),
					Size = UDim2.fromOffset(SHOP_GRID_WIDTH - 48 - Tokens.BORDER * 2, 64),
					Text = sectionConfig.label,
					MaxTextSize = 36,
					ZIndex = 46,
				}),
			},
		}),
		New("Frame")({
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromOffset(SHOP_GRID_WIDTH, rowCount * SHOP_ROW_PITCH),
			ZIndex = 44,
			[Children] = cardChildren,
		}),
	}

	return New("Frame")({
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Size = UDim2.fromOffset(SHOP_GRID_WIDTH, SHOP_SECTION_HEAD + (rowCount * SHOP_ROW_PITCH)),
		ZIndex = 43,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 16),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			table.unpack(children),
		},
	})
end

local function makeScroll()
	local sections = {}
	local totalHeight = 0
	for index, sectionConfig in Theme.SHOP_TABS do
		local itemCount = #(Theme.SHOP_CATALOG[sectionConfig.id] or {})
		local rowCount = math.max(1, math.ceil(itemCount / 2))
		totalHeight += SHOP_SECTION_HEAD + (rowCount * SHOP_ROW_PITCH) + 22
		table.insert(sections, makeSection(sectionConfig, index))
	end
	table.insert(
		sections,
		New("UIListLayout")({
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 22),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	)
	table.insert(
		sections,
		New("UIPadding")({
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		})
	)

	return New("ScrollingFrame")({
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, totalHeight + 12),
		-- Lề hai bên 26 (rút từ 58 ngày 2026-08-15 để trả chỗ cho thẻ). Bề rộng suy từ lưới +
		-- chỗ cho thanh cuộn, nên đổi cỡ thẻ là khung cuộn tự theo.
		Position = UDim2.fromOffset(SCROLL_MARGIN, 130),
		ScrollBarImageColor3 = Color3.fromRGB(255, 185, 50),
		ScrollBarThickness = 10,
		Size = UDim2.fromOffset(SCROLL_WIDTH, PANEL_HEIGHT - 130 - 42),
		ZIndex = 44,
		[Children] = sections,
	})
end

function ShopModal.Build()
	return ModalShell.Build({
		Id = "shop",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		-- KHÔNG `Scale`: xem khối "KÍCH THƯỚC SHOP". `UIScale` co cả độ dày viền nên nó chính
		-- là thứ làm thanh tiêu đề Shop mảnh hơn mọi modal khác.
		PanelColor = Color3.fromRGB(50, 20, 0),
		HeaderColor = Color3.fromRGB(255, 190, 72),
		HeaderColorB = Color3.fromRGB(240, 120, 18),
		Icon = Theme.UI_ASSETS.Shop,
		Title = "Shop",
		TitleMaxTextSize = 58,
		OnClose = Manager.CloseShop,
		Content = { makeScroll() },
	})
end

return ShopModal
