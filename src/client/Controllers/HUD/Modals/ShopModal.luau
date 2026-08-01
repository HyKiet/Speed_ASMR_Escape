--!strict
-- Modal Shop: bán Gamepass + Developer Product (Robux).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Ownership = require(script.Parent.Parent.Ownership)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local localPlayer = Players.LocalPlayer

local ShopModal = {}

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

local function makeCard(item: State.ShopItemConfig)
	local colorA = item.accentColor
	local colorB = colorA:Lerp(Color3.fromRGB(33, 41, 113), 0.58)
	local btnHovered = Value(false)

	-- CHỈ gamepass mới có khái niệm "đã sở hữu". Developer product là hàng tiêu hao
	-- (gói Wins, server boost) — mua bao nhiêu lần cũng được nên luôn hiện giá.
	local owned = if item.purchaseKind == "gamepass"
		then Ownership.Owns(item.purchaseId)
		else Value(false)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		LayoutOrder = item.sortOrder,
		Size = UDim2.fromOffset(416, 166),
		ZIndex = 44,
		[Children] = {
			Theme.MakeCorner(18),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			Theme.MakeStandardStuds(18, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = item.icon,
				Position = UDim2.fromOffset(16, 16),
				Size = UDim2.fromOffset(92, 92),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(116, 14),
				Size = UDim2.fromOffset(278, 34),
				Text = item.title,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 28,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(118, 50),
				Size = UDim2.fromOffset(272, 28),
				Text = item.valueText,
				TextColor3 = Color3.fromRGB(255, 238, 111),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 23,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(118, 78),
				Size = UDim2.fromOffset(278, 28),
				Text = item.subtitle,
				TextColor3 = Color3.fromRGB(232, 251, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 18,
				ZIndex = 46,
			}),
			New("TextButton")({
				AutoButtonColor = false,
				BackgroundColor3 = Computed(function()
					return if owned:get() then Color3.fromRGB(96, 104, 128) else Color3.fromRGB(52, 199, 100)
				end),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(118, 108),
				Size = UDim2.fromOffset(278, 44),
				Text = "",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				ZIndex = 47,
				[OnEvent("Activated")] = function()
					-- Đã sở hữu thì KHÔNG mở prompt nữa. Trước đây bấm vào chỉ nhận được
					-- hộp thoại "You already own this item" của Roblox — trông như lỗi game.
					if owned:get() then
						Toast.Show(`You already own {item.title}`, "success")
						return
					end
					promptPurchase(item)
				end,
				[OnEvent("MouseEnter")] = function()
					btnHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					btnHovered:set(false)
				end,
				[Children] = {
					Theme.MakeCorner(12),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradientDynamic(
						Computed(function()
							return if owned:get() then Color3.fromRGB(138, 146, 170) else Color3.fromRGB(88, 230, 140)
						end),
						Computed(function()
							return if owned:get() then Color3.fromRGB(70, 76, 96) else Color3.fromRGB(30, 150, 72)
						end),
						0
					),
					Theme.MakeStandardStuds(12, 47),
					Theme.HoverZoom(btnHovered, 1.08),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							return if owned:get() then "OWNED ✓" else `\u{E002} {tostring(item.priceRobux)}`
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextXAlignment = Enum.TextXAlignment.Center,
						MaxTextSize = 30,
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
			CellPadding = UDim2.fromOffset(18, 18),
			CellSize = UDim2.fromOffset(416, 166),
			FillDirectionMaxCells = 2,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, item in items do
		table.insert(cardChildren, makeCard(item))
	end
	local children = {
		New("Frame")({
			BackgroundColor3 = sectionConfig.colorA,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(850, 58),
			ZIndex = 44,
			[Children] = {
				Theme.MakeCorner(14),
				Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
				Theme.MakeGradient(sectionConfig.colorA, sectionConfig.colorB, 0),
				Theme.MakeStandardStuds(14, 47),
				Theme.MakeOutlineLabel({
					Position = UDim2.fromOffset(22, 0),
					Size = UDim2.fromOffset(806, 58),
					Text = sectionConfig.label,
					MaxTextSize = 31,
					ZIndex = 46,
				}),
			},
		}),
		New("Frame")({
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromOffset(884, rowCount * 184),
			ZIndex = 44,
			[Children] = cardChildren,
		}),
	}

	return New("Frame")({
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Size = UDim2.fromOffset(884, 82 + (rowCount * 184)),
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
		totalHeight += 82 + (rowCount * 184) + 22
		table.insert(sections, makeSection(sectionConfig, index))
	end
	table.insert(sections, New("UIListLayout")({
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 22),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}))
	table.insert(sections, New("UIPadding")({
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}))

	return New("ScrollingFrame")({
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, totalHeight + 12),
		Position = UDim2.fromOffset(58, 134),
		ScrollBarImageColor3 = Color3.fromRGB(255, 185, 50),
		ScrollBarThickness = 8,
		Size = UDim2.fromOffset(916, 566),
		ZIndex = 44,
		[Children] = sections,
	})
end

function ShopModal.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		Visible = State.shopModalMounted,
		ZIndex = 38,
		[Children] = {
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(50, 20, 0),
				BackgroundTransparency = 0.3,
				ClipsDescendants = true,
				GroupTransparency = Computed(function()
					return 1 - State.shopModalAnimation:get()
				end),
				Position = Computed(function()
					return UDim2.fromOffset(960, 492 - (18 * State.shopModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(1032, 760),
				ZIndex = 40,
				[Children] = {
					Theme.MakeCorner(18),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(255, 150, 40),
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromOffset(1032, 96),
						ZIndex = 45,
						[Children] = {
							Theme.MakeCorner(18),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradient(Color3.fromRGB(255, 190, 72), Color3.fromRGB(240, 120, 18), 0),
							Theme.MakeStandardStuds(18, 47),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = Theme.UI_ASSETS.Shop,
								Position = UDim2.fromOffset(26, 16),
								Size = UDim2.fromOffset(68, 68),
								ZIndex = 47,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(108, 12),
								Size = UDim2.fromOffset(340, 72),
								Text = "Store",
								TextXAlignment = Enum.TextXAlignment.Left,
								MaxTextSize = 58,
								ZIndex = 47,
							}),
							New("TextButton")({
								BackgroundColor3 = Computed(function()
									return if State.shopCloseHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
								end),
								Font = Enum.Font.GothamBlack,
								Position = UDim2.fromOffset(940, 15),
								Size = UDim2.fromOffset(66, 66),
								Text = "X",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								ZIndex = 48,
								[OnEvent("Activated")] = Manager.CloseShop,
								[OnEvent("MouseEnter")] = function()
									State.shopCloseHovered:set(true)
								end,
								[OnEvent("MouseLeave")] = function()
									State.shopCloseHovered:set(false)
								end,
								[Children] = {
									Theme.MakeCorner(10),
									Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
									Theme.HoverZoom(State.shopCloseHovered, 1.1),
									New("UIStroke")({
										Color = Color3.fromRGB(0, 0, 0),
										Thickness = 3,
										ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
									}),
								},
							}),
						},
					}),
					makeScroll(),
				},
			}),
		},
	})
end

return ShopModal
