--!strict
-- Modal Teleport: danh sách dọc từng hàng, thanh toán Wins hoặc Robux.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
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

local TeleportModal = {}

type DestinationConfig = State.TeleportDestinationConfig

local function isDestinationVisible(destination: DestinationConfig): boolean
	return destination.targetPath ~= ""
end

local function requestWithWins(destination: DestinationConfig): boolean
	if State.GetSnapshot().totalWins < destination.priceWins then
		Toast.Show("Not enough Wins")
		return false
	end

	GamePackets.requestTeleport.send({
		destinationId = destination.id,
		paymentKind = "wins",
	})
	return true
end

local function promptWithRobux(destination: DestinationConfig): boolean
	if destination.productId <= 0 then
		Toast.Show("Set teleport product id before purchase")
		return false
	end

	MarketplaceService:PromptProductPurchase(localPlayer, destination.productId)
	return true
end

local function makeRow(destination: DestinationConfig)
	local colorA = destination.accentColor
	local colorB = colorA:Lerp(Color3.fromRGB(20, 30, 70), 0.5)
	local winsHovered = Value(false)
	local robuxHovered = Value(false)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		LayoutOrder = destination.sortOrder,
		Size = UDim2.fromOffset(556, 98),
		ZIndex = 44,
		[Children] = {
			Theme.MakeCorner(16),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			Theme.MakeStandardStuds(16, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Teleport,
				Position = UDim2.fromOffset(12, 19),
				Size = UDim2.fromOffset(60, 60),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(82, 12),
				Size = UDim2.fromOffset(210, 44),
				Text = destination.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 30,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(84, 56),
				Size = UDim2.fromOffset(208, 30),
				Text = destination.description,
				TextColor3 = Color3.fromRGB(255, 240, 130),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 20,
				ZIndex = 46,
			}),
			-- Nút Wins (xanh lá)
			New("TextButton")({
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(54, 200, 56),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(300, 19),
				Size = UDim2.fromOffset(122, 60),
				Text = "",
				ZIndex = 47,
				[OnEvent("Activated")] = function()
					if requestWithWins(destination) then
						Manager.CloseTeleport()
					end
				end,
				[OnEvent("MouseEnter")] = function()
					winsHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					winsHovered:set(false)
				end,
				[Children] = {
					Theme.MakeCorner(12),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(120, 240, 80), Color3.fromRGB(40, 160, 36), 0),
					Theme.MakeStandardStuds(12, 47),
					Theme.HoverZoom(winsHovered, 1.08),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = Theme.UI_ASSETS.Trophy,
						Position = UDim2.fromOffset(10, 14),
						Size = UDim2.fromOffset(32, 32),
						ZIndex = 49,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(44, 6),
						Size = UDim2.fromOffset(72, 48),
						Text = if destination.priceWins <= 0 then "FREE" else Theme.FormatInteger(destination.priceWins),
						TextXAlignment = Enum.TextXAlignment.Center,
						MaxTextSize = 28,
						MinTextSize = 12,
						ZIndex = 49,
					}),
				},
			}),
			-- Nút Robux (tím)
			New("TextButton")({
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(150, 70, 240),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(430, 19),
				Size = UDim2.fromOffset(114, 60),
				Text = "",
				ZIndex = 47,
				[OnEvent("Activated")] = function()
					if promptWithRobux(destination) then
						Manager.CloseTeleport()
					end
				end,
				[OnEvent("MouseEnter")] = function()
					robuxHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					robuxHovered:set(false)
				end,
				[Children] = {
					Theme.MakeCorner(12),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(186, 110, 255), Color3.fromRGB(120, 40, 210), 0),
					Theme.MakeStandardStuds(12, 47),
					Theme.HoverZoom(robuxHovered, 1.08),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = if destination.productId <= 0 then "--" else `\u{E002} {Theme.FormatInteger(destination.priceRobux)}`,
						TextXAlignment = Enum.TextXAlignment.Center,
						MaxTextSize = 26,
						MinTextSize = 12,
						ZIndex = 49,
					}),
				},
			}),
		},
	})
end

local function buildList()
	local rows = {}
	local visibleCount = 0
	for _, destination in Constants.TELEPORT_DESTINATIONS do
		if isDestinationVisible(destination) then
			visibleCount += 1
			table.insert(rows, makeRow(destination))
		end
	end
	table.insert(rows, New("UIListLayout")({
		Padding = UDim.new(0, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}))
	table.insert(rows, New("UIPadding")({
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}))

	return New("ScrollingFrame")({
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, visibleCount * 110 + 12),
		Position = UDim2.fromOffset(24, 110),
		ScrollBarImageColor3 = Color3.fromRGB(200, 222, 255),
		ScrollBarThickness = 10,
		Size = UDim2.fromOffset(584, 552),
		ZIndex = 44,
		[Children] = rows,
	})
end

function TeleportModal.Build()
	local closeHovered = State.teleportCloseHovered
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		Visible = State.teleportModalMounted,
		ZIndex = 38,
		[Children] = {
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(12, 35, 90),
				BackgroundTransparency = 0.3,
				ClipsDescendants = true,
				GroupTransparency = Computed(function()
					return 1 - State.teleportModalAnimation:get()
				end),
				Position = Computed(function()
					return UDim2.fromOffset(960, 492 - (18 * State.teleportModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(632, 680),
				ZIndex = 40,
				[Children] = {
					Theme.MakeCorner(18),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(60, 150, 255),
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromOffset(632, 96),
						ZIndex = 45,
						[Children] = {
							Theme.MakeCorner(18),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradient(Color3.fromRGB(94, 182, 255), Color3.fromRGB(28, 108, 226), 0),
							Theme.MakeStandardStuds(18, 47),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = Theme.UI_ASSETS.Teleport,
								Position = UDim2.fromOffset(20, 11),
								Size = UDim2.fromOffset(68, 68),
								ZIndex = 47,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(100, 8),
								Size = UDim2.fromOffset(430, 74),
								Text = "Teleport",
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
								[OnEvent("Activated")] = Manager.CloseTeleport,
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
					buildList(),
				},
			}),
		},
	})
end

return TeleportModal
