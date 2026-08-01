--!strict
-- Modal Cosmetic: tab Trails / Auras, danh sách dọc từng hàng, mua/trang bị bằng Wins.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local CosmeticModal = {}

local TRAIL_COLORS = {
	{ Color3.fromRGB(84, 224, 113), Color3.fromRGB(27, 133, 75) },
	{ Color3.fromRGB(84, 176, 255), Color3.fromRGB(45, 86, 203) },
	{ Color3.fromRGB(183, 98, 255), Color3.fromRGB(101, 49, 196) },
	{ Color3.fromRGB(255, 91, 91), Color3.fromRGB(185, 31, 48) },
	{ Color3.fromRGB(255, 201, 75), Color3.fromRGB(210, 61, 157) },
	{ Color3.fromRGB(108, 76, 255), Color3.fromRGB(32, 22, 102) },
}

local AURA_COLORS = {
	{ Color3.fromRGB(255, 223, 92), Color3.fromRGB(221, 118, 34) },
	{ Color3.fromRGB(255, 104, 64), Color3.fromRGB(179, 30, 31) },
	{ Color3.fromRGB(92, 205, 255), Color3.fromRGB(52, 84, 211) },
	{ Color3.fromRGB(153, 93, 255), Color3.fromRGB(55, 23, 126) },
	{ Color3.fromRGB(255, 100, 212), Color3.fromRGB(68, 49, 178) },
}

local function getCardColors(category: string, index: number): (Color3, Color3)
	local colors = if category == "trail" then TRAIL_COLORS else AURA_COLORS
	local selected = colors[(index - 1) % #colors + 1]
	return selected[1], selected[2]
end

local function makeRow(category: string, config: any, index: number)
	local colorA, colorB = getCardColors(category, index)
	-- Ảnh riêng của từng món (Trails.luau / Auras.luau). Món chưa có ảnh riêng (Frozen Bloom
	-- và 3 aura premium) rơi về icon chung để không bao giờ hiện ô trống.
	local fallbackIcon = if category == "trail" then Theme.UI_ASSETS.Trail else Theme.UI_ASSETS.Aura
	local icon: string = config.icon or fallbackIcon
	local btnWinsHovered = Value(false)
	local btnRobuxHovered = Value(false)
	local btnEquipHovered = Value(false)

	local gamepassId: number = config.gamepassId or 0
	local robuxOnly: boolean = config.robuxOnly == true
	-- Món chỉ rơi từ Speed Roulette (Frozen Bloom): không có đường mua nào. Trước đây nó
	-- vẫn hiện nút Wins với giá 999.00M — con số chốt chặn của server bị lộ ra UI, người
	-- chơi tưởng là món cày được. Giờ ẩn cả hai nút, thay bằng nhãn "SPIN ONLY".
	local spinOnly: boolean = config.spinOnly == true

	-- Giá Robux hiển thị phải là giá THEO VÙNG của người đang xem. Trong lúc chờ fetch
	-- (hoặc khi chưa điền gamepassId) hiện tạm giá config — không bao giờ hiện "SOON".
	local fallbackPrice: number? = if (config.priceRobux or 0) > 0 then config.priceRobux else nil
	local robuxText = Value(RobuxPrice.FormatPrefixed(fallbackPrice))
	if gamepassId > 0 then
		task.spawn(function()
			local price = RobuxPrice.GetAsync(gamepassId)
			if price then
				robuxText:set(RobuxPrice.FormatPrefixed(price))
			end
		end)
	end
	-- Trạng thái nút: equipped / owned / locked
	local statusColorA = Computed(function()
		local state = State.GetSnapshot()
		local equippedId = if category == "trail" then state.equippedTrail else state.equippedAura
		local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
		if equippedId == config.id then
			return Color3.fromRGB(78, 212, 80)
		end
		return if unlocked[config.id] then Color3.fromRGB(71, 172, 255) else Color3.fromRGB(255, 196, 56)
	end)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		LayoutOrder = index,
		Size = UDim2.fromOffset(556, 150),
		ZIndex = 44,
		[Children] = {
			Theme.MakeCorner(18),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			Theme.MakeStandardStuds(18, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(16, 19),
				Size = UDim2.fromOffset(100, 100),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(130, 26),
				Size = UDim2.fromOffset(238, 44),
				Text = config.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 32,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(132, 76),
				Size = UDim2.fromOffset(236, 36),
				Text = `x{string.format("%.2f", config.multiplier)} Speed`,
				TextColor3 = Color3.fromRGB(255, 239, 112),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 26,
				ZIndex = 46,
			}),
			-- Container nút bên phải
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(372, 17),
				Size = UDim2.fromOffset(164, 116),
				ZIndex = 46,
				[Children] = {
					-- Căn giữa theo chiều dọc: hàng Standard có 2 nút xếp chồng lấp đầy ô, còn
					-- hàng Robux-only / Spin-only chỉ có 1 nút CÙNG CỠ nên phải canh giữa,
					-- không thì nó dính lên mép trên ô.
					New("UIListLayout")({
						Padding = UDim.new(0, 16),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
					-- Nút mua bằng Wins
					New("TextButton")({
						AutoButtonColor = false,
						BackgroundColor3 = Color3.fromRGB(110, 240, 130),
						Font = Enum.Font.GothamBlack,
						LayoutOrder = 1,
						Size = UDim2.fromOffset(164, 50),
						Text = "",
						Visible = Computed(function()
							-- Món Robux-only / Spin-only không có đường mua bằng Wins.
							if robuxOnly or spinOnly then
								return false
							end
							local state = State.GetSnapshot()
							local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
							return not unlocked[config.id]
						end),
						ZIndex = 46,
						[OnEvent("Activated")] = function()
							local state = State.GetSnapshot()
							if state.totalWins < config.priceWins then
								Toast.Show("Not enough Wins")
								return
							end
							GamePackets.requestCosmeticAction.send({
								category = category,
								itemId = config.id,
							})
						end,
						[OnEvent("MouseEnter")] = function() btnWinsHovered:set(true) end,
						[OnEvent("MouseLeave")] = function() btnWinsHovered:set(false) end,
						[Children] = {
							Theme.MakeCorner(10),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradientDynamic(Color3.fromRGB(110, 240, 130), Color3.fromRGB(34, 162, 64)),
							Theme.MakeStandardStuds(10, 47),
							Theme.HoverZoom(btnWinsHovered, 1.08),
							New("Frame")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0, 1),
								AutomaticSize = Enum.AutomaticSize.X,
								ZIndex = 48,
								[Children] = {
									New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, 6),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									New("ImageLabel")({
										BackgroundTransparency = 1,
										Image = Theme.UI_ASSETS.Trophy,
										LayoutOrder = 1,
										Size = UDim2.fromOffset(26, 26),
										ZIndex = 49,
									}),
									Theme.MakeOutlineLabel({
										AutomaticSize = Enum.AutomaticSize.X,
										LayoutOrder = 2,
										Position = UDim2.fromScale(0, 0),
										Size = UDim2.fromOffset(0, 46),
										Text = Theme.FormatInteger(config.priceWins),
										MaxTextSize = 22,
										ZIndex = 49,
									}),
								},
							}),
						},
					}),
					-- Nút mua bằng Robux
					New("TextButton")({
						AutoButtonColor = false,
						BackgroundColor3 = Color3.fromRGB(255, 110, 210),
						Font = Enum.Font.GothamBlack,
						LayoutOrder = 2,
						-- Cùng cỡ với nút của món Standard (164×50). Bản trước cho món
						-- Robux-only chiếm trọn ô 116 cao vì không có nút Wins phía trên —
						-- nhìn ra hai kích thước nút khác nhau giữa các hàng, mất đồng bộ.
						Size = UDim2.fromOffset(164, 50),
						Text = "",
						Visible = Computed(function()
							local state = State.GetSnapshot()
							local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
							return not unlocked[config.id] and (gamepassId > 0 or robuxOnly)
						end),
						ZIndex = 46,
						[OnEvent("Activated")] = function()
							if gamepassId <= 0 then
								Toast.Show("Coming soon!")
								return
							end
							MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, gamepassId)
						end,
						[OnEvent("MouseEnter")] = function() btnRobuxHovered:set(true) end,
						[OnEvent("MouseLeave")] = function() btnRobuxHovered:set(false) end,
						[Children] = {
							Theme.MakeCorner(10),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradientDynamic(Color3.fromRGB(255, 150, 214), Color3.fromRGB(236, 64, 156)),
							Theme.MakeStandardStuds(10, 47),
							Theme.HoverZoom(btnRobuxHovered, 1.08),
							New("Frame")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0, 1),
								AutomaticSize = Enum.AutomaticSize.X,
								ZIndex = 48,
								[Children] = {
									New("UIListLayout")({
										FillDirection = Enum.FillDirection.Horizontal,
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										VerticalAlignment = Enum.VerticalAlignment.Center,
										Padding = UDim.new(0, 6),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									Theme.MakeOutlineLabel({
										AutomaticSize = Enum.AutomaticSize.X,
										LayoutOrder = 2,
										Position = UDim2.fromScale(0, 0),
										Size = UDim2.fromOffset(0, 46),
										Text = robuxText,
										MaxTextSize = 22,
										ZIndex = 49,
									}),
								},
							}),
						},
					}),
					-- Nhãn SPIN ONLY (Frozen Bloom): không phải nút, chỉ báo nguồn duy nhất là
					-- Speed Roulette. Chiếm trọn ô vì hai nút mua đều bị ẩn.
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(120, 90, 220),
						LayoutOrder = 2,
						Size = UDim2.fromOffset(164, 50),
						Visible = Computed(function()
							local state = State.GetSnapshot()
							local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
							return spinOnly and not unlocked[config.id]
						end),
						ZIndex = 46,
						[Children] = {
							Theme.MakeCorner(10),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradientDynamic(Color3.fromRGB(168, 128, 255), Color3.fromRGB(96, 48, 200)),
							Theme.MakeStandardStuds(10, 47),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = Theme.UI_ASSETS.Spin,
								Position = UDim2.fromOffset(8, 9),
								Size = UDim2.fromOffset(32, 32),
								ZIndex = 48,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(44, 8),
								Size = UDim2.fromOffset(112, 34),
								Text = "SPIN ONLY",
								MaxTextSize = 22,
								ZIndex = 48,
							}),
						},
					}),
					-- Nút Equip / Equipped (khi đã sở hữu)
					New("TextButton")({
						AutoButtonColor = false,
						BackgroundColor3 = statusColorA,
						Font = Enum.Font.GothamBlack,
						LayoutOrder = 3,
						Size = UDim2.fromOffset(164, 116),
						Text = "",
						Visible = Computed(function()
							local state = State.GetSnapshot()
							local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
							return unlocked[config.id] == true
						end),
						ZIndex = 46,
						[OnEvent("Activated")] = function()
							GamePackets.requestCosmeticAction.send({
								category = category,
								itemId = config.id,
							})
						end,
						[OnEvent("MouseEnter")] = function() btnEquipHovered:set(true) end,
						[OnEvent("MouseLeave")] = function() btnEquipHovered:set(false) end,
						[Children] = {
							Theme.MakeCorner(14),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradientDynamic(
								statusColorA,
								Computed(function()
									return statusColorA:get():Lerp(Color3.fromRGB(0, 0, 0), 0.32)
								end)
							),
							Theme.HoverZoom(btnEquipHovered, 1.08),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = Computed(function()
									local state = State.GetSnapshot()
									local equippedId = if category == "trail" then state.equippedTrail else state.equippedAura
									return if equippedId == config.id then "EQUIPPED" else "EQUIP"
								end),
								MaxTextSize = 28,
								MinTextSize = 12,
								ZIndex = 49,
							}),
						},
					}),
				},
			}),
		},
	})
end

local function makeCatalog(category: string, catalog: { any })
	local cards = {}
	for index, config in catalog do
		table.insert(cards, makeRow(category, config, index))
	end
	table.insert(cards, New("UIListLayout")({
		Padding = UDim.new(0, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}))
	table.insert(cards, New("UIPadding")({
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}))

	return New("ScrollingFrame")({
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, #catalog * 164 + 12),
		Position = UDim2.fromOffset(24, 188),
		ScrollBarImageColor3 = Color3.fromRGB(236, 206, 255),
		ScrollBarThickness = 10,
		Size = UDim2.fromOffset(584, 470),
		Visible = Computed(function()
			return State.cosmeticCategory:get() == category
		end),
		ZIndex = 44,
		[Children] = cards,
	})
end

local function makeTab(category: string, label: string, position: UDim2, colorA: Color3, colorB: Color3)
	local hovered = Value(false)
	return New("TextButton")({
		AutoButtonColor = false,
		BackgroundColor3 = Computed(function()
			return if State.cosmeticCategory:get() == category then colorA else Color3.fromRGB(96, 64, 132)
		end),
		Position = position,
		Size = UDim2.fromOffset(286, 66),
		Text = "",
		ZIndex = 45,
		[OnEvent("Activated")] = function()
			State.cosmeticCategory:set(category)
		end,
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
		end,
		[Children] = {
			Theme.MakeCorner(14),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			Theme.MakeStandardStuds(14, 46),
			Theme.HoverZoom(hovered, 1.08),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				Text = label,
				MaxTextSize = 32,
				MinTextSize = 14,
				ZIndex = 47,
			}),
		},
	})
end

function CosmeticModal.Build()
	local closeHovered = State.cosmeticCloseHovered
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		Visible = State.cosmeticModalMounted,
		ZIndex = 38,
		[Children] = {
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(30, 0, 40),
				BackgroundTransparency = 0.3,
				ClipsDescendants = true,
				GroupTransparency = Computed(function()
					return 1 - State.cosmeticModalAnimation:get()
				end),
				Position = Computed(function()
					return UDim2.fromOffset(960, 492 - (18 * State.cosmeticModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(632, 680),
				ZIndex = 40,
				[Children] = {
					Theme.MakeCorner(18),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(178, 92, 255),
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromOffset(632, 96),
						ZIndex = 45,
						[Children] = {
							Theme.MakeCorner(18),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradient(Color3.fromRGB(202, 124, 255), Color3.fromRGB(138, 46, 226), 0),
							Theme.MakeStandardStuds(18, 47),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = Theme.UI_ASSETS.Trail,
								Position = UDim2.fromOffset(20, 11),
								Size = UDim2.fromOffset(68, 68),
								ZIndex = 47,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(100, 8),
								Size = UDim2.fromOffset(430, 74),
								Text = "Cosmetics",
								TextXAlignment = Enum.TextXAlignment.Left,
								MaxTextSize = 50,
								ZIndex = 47,
							}),
							New("TextButton")({
								BackgroundColor3 = Computed(function()
									return if closeHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
								end),
								Font = Enum.Font.GothamBlack,
								Position = UDim2.fromOffset(552, 12),
								Size = UDim2.fromOffset(66, 66),
								Text = "X",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								ZIndex = 48,
								[OnEvent("Activated")] = Manager.CloseCosmetic,
								[OnEvent("MouseEnter")] = function()
									closeHovered:set(true)
								end,
								[OnEvent("MouseLeave")] = function()
									closeHovered:set(false)
								end,
								[Children] = {
									Theme.MakeCorner(10),
									Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
									Theme.HoverZoom(closeHovered, 1.1),
									New("UIStroke")({
										Color = Color3.fromRGB(0, 0, 0),
										Thickness = 3,
										ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
									}),
								},
							}),
						},
					}),
					makeTab("trail", "TRAILS", UDim2.fromOffset(24, 106), Color3.fromRGB(177, 106, 255), Color3.fromRGB(94, 55, 196)),
					makeTab("aura", "AURAS", UDim2.fromOffset(322, 106), Color3.fromRGB(255, 104, 79), Color3.fromRGB(184, 36, 47)),
					makeCatalog("trail", Constants.TRAILS),
					makeCatalog("aura", Constants.AURAS),
				},
			}),
		},
	})
end

return CosmeticModal
