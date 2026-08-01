--!strict
-- Theme: kích thước thiết kế, asset id, các factory helper dựng UI (Fusion).
-- Không giữ state — chỉ trả về Instance khi gọi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.State)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Tween = Fusion.Tween
local Value = Fusion.Value

local Theme = {}

-- Hiệu ứng zoom khi rê chuột: trả về UIScale phóng to mượt theo `hovered` Value.
-- Dùng cho mọi button (đặt vào [Children], button tự set hovered qua MouseEnter/Leave).
function Theme.HoverZoom(hovered: any, maxScale: number?)
	local target = maxScale or 1.08
	return New("UIScale")({
		-- Back easing → bật nảy nhẹ (pop) khi rê chuột, cảm giác "đã tay" hơn.
		Scale = Tween(
			Computed(function()
				return if hovered:get() then target else 1
			end),
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		),
	})
end

Theme.DESIGN_WIDTH = 1920
Theme.DESIGN_HEIGHT = 1080
Theme.MIN_SCALE = 0.12
Theme.MAX_SCALE = 1
Theme.TOAST_Z_INDEX = 220

Theme.UI_ASSETS = {
	Trophy = "rbxassetid://106462244220051",
	Lightning = "rbxassetid://94953097483502",
	Rebirth = "rbxassetid://103236589125008",
	Shop = "rbxassetid://80843877229491",
	Shoe = "rbxassetid://93408043939834",
	Cosmetics = "rbxassetid://100080362113682",
	Trail = "rbxassetid://115065552017670",
	Teleport = "rbxassetid://112885468301298",
	Aura = "rbxassetid://82712548408854",
	Code = "rbxassetid://87201095513293",
	Daily = "rbxassetid://112157950151947",
	Spin = "rbxassetid://115585087379442",
	Robux = "rbxasset://textures/ui/common/robux.png",
	Sunburst = "rbxassetid://87577740080014",
	Studs = "rbxassetid://6372755229",
	LevelUpSound = "rbxassetid://89481514209130",
	ClickSound = "rbxassetid://5852470908",
	HoverSound = "rbxassetid://5852470908",
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
		label = "UTILITY GAMEPASS & VIP MEMBERSHIP",
		colorA = Color3.fromRGB(255, 205, 70),
		colorB = Color3.fromRGB(240, 92, 62),
	},
	{
		id = "products",
		label = "INSTANT WINS PACKS (DEVELOPER PRODUCTS)",
		colorA = Color3.fromRGB(75, 221, 255),
		colorB = Color3.fromRGB(34, 113, 230),
	},
	{
		id = "treadmills",
		label = "TREADMILL GAMEPASS",
		colorA = Color3.fromRGB(104, 234, 95),
		colorB = Color3.fromRGB(40, 143, 69),
	},
}

-- Màu nhận diện 3 speed pass (dùng chung cho Shop card + promo RightPanel).
Theme.SPEED_PASS_TIERS = {
	-- Nhãn "x2" (không phải "2x") — theo ảnh tham chiếu của user 2026-07-28.
	{ id = "speed_x2", label = "x2 Speed", passId = 1900262644, priceRobux = 3,
		colorA = Color3.fromRGB(255, 186, 69), colorB = Color3.fromRGB(255, 128, 38) }, -- cam-vàng
	{ id = "speed_x4", label = "x4 Speed", passId = 1900160603, priceRobux = 9,
		colorA = Color3.fromRGB(210, 130, 255), colorB = Color3.fromRGB(110, 40, 220) }, -- tím
	{ id = "speed_x8", label = "x8 Speed", passId = 1898810606, priceRobux = 27,
		colorA = Color3.fromRGB(255, 92, 78), colorB = Color3.fromRGB(178, 10, 40) }, -- đỏ
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
			icon = Theme.UI_ASSETS.Lightning,
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
			icon = Theme.UI_ASSETS.Trophy,
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
			icon = Theme.UI_ASSETS.Sunburst,
			sortOrder = 3,
		},
	},
	utility = {
		{
			id = "vip_membership",
			title = "VIP Membership",
			subtitle = "[VIP] tag + VIP Trail + VIP Aura",
			valueText = "x1.5 Speed + x1.2 Wins",
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
			icon = "rbxassetid://82096179394611",
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
			icon = Theme.UI_ASSETS.Rebirth,
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

function Theme.MakeStroke(color: Color3, thickness: number, transparency: number?)
	return New("UIStroke")({
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness,
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

function Theme.MakeStudsPattern(transparency: number?, zIndex: number?, cornerRadius: number?)
	local children = if cornerRadius then { Theme.MakeCorner(cornerRadius) } else nil
	return New("ImageLabel")({
		BackgroundTransparency = 1,
		Image = Theme.UI_ASSETS.Studs,
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ImageTransparency = transparency or 0.76,
		Position = UDim2.fromScale(0, 0),
		ScaleType = Enum.ScaleType.Tile,
		Size = UDim2.fromScale(1, 1),
		TileSize = UDim2.fromOffset(30, 30),
		ZIndex = zIndex or 11,
		[Children] = children,
	})
end

-- Hệ thống texture chuẩn: đồng bộ độ mờ tinh tế (0.86) và hỗ trợ bo góc, dễ dàng tái sử dụng cho mọi panel/button
function Theme.MakeStandardStuds(cornerRadius: number?, zIndex: number?)
	return Theme.MakeStudsPattern(0.86, zIndex, cornerRadius)
end

-- Hào quang xoay. `props` tuỳ chọn để đặt lại vị trí/cỡ/lớp — mặc định giữ nguyên số cũ
-- cho mọi chỗ gọi không truyền gì.
function Theme.MakeSunburst(props: { Position: UDim2?, Size: UDim2?, ZIndex: number? }?)
	local p = props or {}
	local sunburst = New("ImageLabel")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Theme.UI_ASSETS.Sunburst,
		ImageTransparency = 0.08,
		Position = p.Position or UDim2.fromOffset(49, 51),
		Size = p.Size or UDim2.fromOffset(148, 148),
		ZIndex = p.ZIndex or 2,
	})
	local tween = TweenService:Create(
		sunburst,
		TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 }
	)
	tween:Play()
	State.sweeper:Add(function()
		tween:Cancel()
	end)

	return sunburst
end

function Theme.MakeOutlineLabel(props: { [string]: any })
	local maxTextSize = props.MaxTextSize or 48
	local minTextSize = props.MinTextSize or 10

	local defaults: { [any]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
	}

	local strokeColor = props.TextStrokeColor3 or Color3.fromRGB(0, 0, 0)
	local strokeTransparency = props.TextStrokeTransparency or 0
	local strokeThickness = props.TextStrokeThickness or 3

	for key, value in props do
		if key ~= "MaxTextSize" and key ~= "MinTextSize" and key ~= "TextStrokeColor3" and key ~= "TextStrokeTransparency" and key ~= "TextStrokeThickness" then
			defaults[key] = value
		end
	end

	local childrenList = defaults[Children] or {}
	table.insert(childrenList, New("UITextSizeConstraint")({
		MaxTextSize = maxTextSize,
		MinTextSize = minTextSize,
	}))
	table.insert(childrenList, New("UIStroke")({
		Color = strokeColor,
		Transparency = strokeTransparency,
		Thickness = strokeThickness,
	}))
	defaults[Children] = childrenList

	return New("TextLabel")(defaults)
end

function Theme.MakeButton(label, colorA: Color3, colorB: Color3, activated: (() -> ())?, externalHovered: any?)
	local hovered = externalHovered or Value(false)
	local childList: { any } = {
		Theme.MakeCorner(16),
		Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 5),
		Theme.MakeGradient(colorA, colorB),
		Theme.MakeStandardStuds(16, 13),
		Theme.MakeOutlineLabel({
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 1),
			Text = label,
			MaxTextSize = 34,
			MinTextSize = 10,
			ZIndex = 14,
		}),
	}
	-- Nếu caller tự quản hovered (vd: zoom cả tile), không tự thêm UIScale ở đây.
	if not externalHovered then
		table.insert(childList, Theme.HoverZoom(hovered))
	end

	return New("TextButton")({
		AutoButtonColor = false,
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 12,
		[OnEvent("Activated")] = function()
			if activated then
				activated()
			end
		end,
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
		end,
		[Children] = childList,
	})
end

function Theme.MakeMenuButton(label: string, icon: string, colorA: Color3, colorB: Color3, action: (() -> ())?)
	local hovered = Value(false)
	return New("Frame")({
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(126, 126),
		[Children] = {
			-- Zoom cả tile (icon + label + nền) khi rê chuột.
			Theme.HoverZoom(hovered, 1.08),
			Theme.MakeButton("", colorA, colorB, action, hovered),
			New("ImageLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromScale(0.5, 0.42),
				Size = UDim2.fromOffset(88, 88),
				ZIndex = 14,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(4, 84),
				Size = UDim2.fromOffset(118, 34),
				Text = label,
				MaxTextSize = 28,
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

function Theme.UpdateViewportScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local scale = math.min(viewport.X / Theme.DESIGN_WIDTH, viewport.Y / Theme.DESIGN_HEIGHT)
	State.viewportSize:set(viewport)
	State.viewportScale:set(math.clamp(scale, Theme.MIN_SCALE, Theme.MAX_SCALE))
end

function Theme.GetVisibleDesignBounds(): (number, number, number, number, number)
	local scale = State.viewportScale:get()
	local viewport = State.viewportSize:get()
	local visibleWidth = viewport.X / scale
	local visibleHeight = viewport.Y / scale
	local left = (Theme.DESIGN_WIDTH - visibleWidth) * 0.5
	local top = (Theme.DESIGN_HEIGHT - visibleHeight) * 0.5
	return left, top, left + visibleWidth, top + visibleHeight, scale
end

return Theme
