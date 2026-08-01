--!strict
-- Modal Rebirth: tăng Rebirths cố định khi đủ Level.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Products = require(ReplicatedStorage.Shared.Config.Economy.Products)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local localPlayer = Players.LocalPlayer


local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Tween = Fusion.Tween
local Value = Fusion.Value

local RebirthModal = {}

-- Giá Auto-Rebirth phải là giá THEO VÙNG của người đang xem (xem RobuxPrice.luau), nên
-- fetch một lần lúc load rồi bơm vào Value; trong lúc chờ hiện giá config làm tạm.
local AUTO_REBIRTH_PASS_ID = Constants.GAMEPASS_IDS.AutoRebirth or 0
local autoRebirthPriceText = Value(RobuxPrice.FormatPrefixed(99))
if AUTO_REBIRTH_PASS_ID > 0 then
	task.spawn(function()
		local price = RobuxPrice.GetAsync(AUTO_REBIRTH_PASS_ID)
		if price then
			autoRebirthPriceText:set(RobuxPrice.FormatPrefixed(price))
		end
	end)
end

local function makeSpeedCard(position: UDim2, speedText: any)
	return New("Frame")({
		BackgroundColor3 = Color3.fromRGB(220, 40, 50),
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(390, 116),
		ZIndex = 42,
		[Children] = {
			Theme.MakeCorner(14),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(Color3.fromRGB(250, 70, 80), Color3.fromRGB(180, 20, 30)),
			Theme.MakeStandardStuds(14, 44),
			-- icon giày chìm dưới text, xoay nhẹ
			New("ImageLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Shoe,
				Position = UDim2.fromScale(0.5, 0.52),
				Rotation = 12,
				Size = UDim2.fromOffset(80, 80),
				ZIndex = 45,
			}),
			-- text đè lên icon giày
			Theme.MakeOutlineLabel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Text = speedText,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				MaxTextSize = 44,
				ZIndex = 46,
			}),
		},
	})
end

local function buildPanel()
	return New("CanvasGroup")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(40, 0, 0),
		BackgroundTransparency = 0.3,
		ClipsDescendants = true,
		GroupTransparency = Computed(function()
			return 1 - State.rebirthModalAnimation:get()
		end),
		Position = Computed(function()
			return UDim2.fromOffset(960, 492 - (18 * State.rebirthModalAnimation:get()))
		end),
		Size = UDim2.fromOffset(920, 668), -- +88 cho hàng Auto-Rebirth ở đáy
		ZIndex = 40,
		[Children] = {
			Theme.MakeCorner(18),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),

			-- ── Header ──────────────────────────────────────────────────
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(255, 205, 40),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(920, 96),
				ZIndex = 45,
				[Children] = {
					Theme.MakeCorner(18),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 150, 10), 0),
					Theme.MakeStandardStuds(18, 47),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = Theme.UI_ASSETS.Lightning,
						Position = UDim2.fromOffset(20, 11),
						Size = UDim2.fromOffset(68, 68),
						ZIndex = 47,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(100, 8),
						Size = UDim2.fromOffset(716, 74),
						Text = "Rebirth",
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 54,
						ZIndex = 47,
					}),
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return if State.rebirthCloseHovered:get()
								then Color3.fromRGB(255, 76, 65)
								else Color3.fromRGB(211, 39, 29)
						end),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(840, 12),
						Size = UDim2.fromOffset(66, 66),
						Text = "X",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						ZIndex = 48,
						[OnEvent("Activated")] = Manager.CloseRebirth,
						[OnEvent("MouseEnter")] = function() State.rebirthCloseHovered:set(true) end,
						[OnEvent("MouseLeave")] = function() State.rebirthCloseHovered:set(false) end,
						[Children] = {
							Theme.MakeCorner(10),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							New("UIStroke")({
								Color = Color3.fromRGB(0, 0, 0),
								Thickness = 3,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							}),
						},
					}),
				},
			}),

			-- ── Before / After labels ────────────────────────────────────
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(44, 112),
				Size = UDim2.fromOffset(390, 44),
				Text = "Before",
				TextXAlignment = Enum.TextXAlignment.Center,
				MaxTextSize = 36,
				ZIndex = 42,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(486, 112),
				Size = UDim2.fromOffset(390, 44),
				Text = "After",
				TextXAlignment = Enum.TextXAlignment.Center,
				MaxTextSize = 36,
				ZIndex = 42,
			}),

			-- ── Speed cards ──────────────────────────────────────────────
			makeSpeedCard(UDim2.fromOffset(44, 164), Computed(function()
				return `Speed: x{string.format("%.1f", Constants.GetRebirthMultiplier(State.GetSnapshot().rebirths))}`
			end)),

			-- Big arrow between cards
			New("TextLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(461, 222),
				Size = UDim2.fromOffset(80, 80),
				Text = ">",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 44,
				[Children] = {
					New("UITextSizeConstraint")({ MaxTextSize = 72, MinTextSize = 20 }),
				},
			}),

			makeSpeedCard(UDim2.fromOffset(486, 164), Computed(function()
				return `Speed: x{string.format("%.1f", Constants.GetRebirthMultiplier(State.GetSnapshot().rebirths + 1))}`
			end)),

			-- ── Warning ──────────────────────────────────────────────────
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(44, 294),
				Size = UDim2.fromOffset(832, 38),
				Text = "Rebirth resets your speed level!",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				MaxTextSize = 28,
				ZIndex = 42,
			}),

			-- ── Progress bar ─────────────────────────────────────────────
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(44, 342),
				Size = UDim2.fromOffset(832, 82),
				[Children] = {
					-- Nền và thanh chạy
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(80, 10, 15),
						ClipsDescendants = true,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 42,
						[Children] = {
							Theme.MakeCorner(14),
							Theme.MakeStandardStuds(14, 44),
							New("Frame")({
								BackgroundColor3 = Color3.fromRGB(240, 200, 30),
								Size = Tween(Computed(function()
									local state = State.GetSnapshot()
									return UDim2.fromScale(math.clamp(state.level / state.requiredRebirthLevel, 0, 1), 1)
								end), TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)),
								ZIndex = 43,
								[Children] = {
									Theme.MakeCorner(14),
									Theme.MakeGradient(Color3.fromRGB(255, 232, 58), Color3.fromRGB(205, 152, 12), 0),
									Theme.MakeStandardStuds(14, 44),
								},
							}),
						},
					}),
					-- Viền nằm độc lập phía trên cùng
					New("Frame")({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 45,
						[Children] = {
							Theme.MakeCorner(14),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
						},
					}),
					-- Text
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							local s = State.GetSnapshot()
							return `Level {s.level} / {s.requiredRebirthLevel}`
						end),
						MaxTextSize = 44,
						ZIndex = 46,
					}),
				},
			}),

			-- ── REBIRTH button ────────────────────────────────────────────
			New("TextButton")({
				AutoButtonColor = false,
				BackgroundColor3 = Computed(function()
					if not State.GetSnapshot().canRebirth then
						return Color3.fromRGB(100, 30, 30)
					end
					return if State.rebirthConfirmHovered:get()
						then Color3.fromRGB(255, 230, 80)
						else Color3.fromRGB(255, 210, 40)
				end),
				ClipsDescendants = true,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(44, 440),
				Size = UDim2.fromOffset(430, 110),
				Text = "",
				ZIndex = 45,
				[OnEvent("Activated")] = function()
					local state = State.GetSnapshot()
					if state.canRebirth then
						GamePackets.requestRebirth.send({})
						Manager.CloseRebirth()
					else
						Toast.Show(`Need Level {state.requiredRebirthLevel}`)
					end
				end,
				[OnEvent("MouseEnter")] = function() State.rebirthConfirmHovered:set(true) end,
				[OnEvent("MouseLeave")] = function() State.rebirthConfirmHovered:set(false) end,
				[Children] = {
					Theme.MakeCorner(16),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(255, 240, 100), Color3.fromRGB(240, 150, 0)),
					Theme.MakeStandardStuds(16, 46),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							local state = State.GetSnapshot()
							return if state.canRebirth then "Rebirth" else `Need Level {state.requiredRebirthLevel}`
						end),
						MaxTextSize = 50,
						ZIndex = 47,
					}),
				},
			}),

			-- ── SKIP button ───────────────────────────────────────────────
			New("TextButton")({
				AutoButtonColor = false,
				BackgroundColor3 = Computed(function()
					return if State.rebirthSkipHovered:get()
						then Color3.fromRGB(255, 170, 60)
						else Color3.fromRGB(255, 140, 30)
				end),
				ClipsDescendants = true,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(490, 440),
				Size = UDim2.fromOffset(386, 110),
				Text = "",
				ZIndex = 45,
				[OnEvent("Activated")] = function()
					if Products.SKIP_REBIRTH_PRODUCT_ID <= 0 then
						Toast.Show("Set Skip Rebirth Product ID!")
						return
					end
					MarketplaceService:PromptProductPurchase(localPlayer, Products.SKIP_REBIRTH_PRODUCT_ID)
				end,
				[OnEvent("MouseEnter")] = function() State.rebirthSkipHovered:set(true) end,
				[OnEvent("MouseLeave")] = function() State.rebirthSkipHovered:set(false) end,
				[Children] = {
					Theme.MakeCorner(16),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(255, 190, 80), Color3.fromRGB(220, 100, 10)),
					Theme.MakeStandardStuds(16, 46),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = `Skip (\u{E002} 149)`,
						MaxTextSize = 44,
						ZIndex = 47,
					}),
				},

			}),

			-- ── AUTO-REBIRTH (gamepass) ───────────────────────────────────
			-- Đặt ở ĐÂY chứ không phải trong Shop: đây là nơi người chơi đang nhìn thanh
			-- "Level x / y" và nghĩ về việc trùng sinh — bán đúng lúc có nhu cầu.
			-- Ba trạng thái: CHƯA MUA (hiện giá, bấm = prompt) / ON / OFF.
			-- Công tắc ON-OFF là bắt buộc, không phải màu mè: người chơi cần dừng auto để
			-- giữ Level cao mà chạy obby, nếu không mua pass xong lại thành bất tiện.
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(70, 12, 16),
				ClipsDescendants = true,
				Position = UDim2.fromOffset(44, 562),
				Size = UDim2.fromOffset(832, 84),
				ZIndex = 42,
				[Children] = {
					Theme.MakeCorner(14),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeStandardStuds(14, 43),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = Theme.UI_ASSETS.Rebirth,
						Position = UDim2.fromOffset(12, 10),
						Size = UDim2.fromOffset(64, 64),
						ZIndex = 44,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(88, 8),
						Size = UDim2.fromOffset(440, 38),
						Text = "Auto-Rebirth",
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 34,
						ZIndex = 44,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(88, 44),
						Size = UDim2.fromOffset(440, 32),
						Text = Computed(function()
							local state = State.GetSnapshot()
							if not state.ownsAutoRebirth then
								return "Rebirth automatically at required level"
							end
							return if state.autoRebirthEnabled
								then "Active — rebirths the moment you qualify"
								else "Paused — keep your level for the obby"
						end),
						TextColor3 = Color3.fromRGB(255, 214, 120),
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 24,
						ZIndex = 44,
					}),
					New("TextButton")({
						AutoButtonColor = false,
						BackgroundColor3 = Computed(function()
							local state = State.GetSnapshot()
							if not state.ownsAutoRebirth then
								return Color3.fromRGB(236, 64, 156)
							end
							return if state.autoRebirthEnabled
								then Color3.fromRGB(64, 200, 96)
								else Color3.fromRGB(96, 96, 110)
						end),
						ClipsDescendants = true,
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(624, 12),
						Size = UDim2.fromOffset(194, 60),
						Text = "",
						ZIndex = 45,
						[OnEvent("Activated")] = function()
							local state = State.GetSnapshot()
							if not state.ownsAutoRebirth then
								if AUTO_REBIRTH_PASS_ID <= 0 then
									Toast.Show("Set Auto-Rebirth Pass ID!")
									return
								end
								MarketplaceService:PromptGamePassPurchase(localPlayer, AUTO_REBIRTH_PASS_ID)
								return
							end
							GamePackets.requestAutoRebirthToggle.send({
								enabled = not state.autoRebirthEnabled,
							})
						end,
						[OnEvent("MouseEnter")] = function() State.rebirthAutoHovered:set(true) end,
						[OnEvent("MouseLeave")] = function() State.rebirthAutoHovered:set(false) end,
						[Children] = {
							Theme.MakeCorner(12),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeStandardStuds(12, 46),
							Theme.HoverZoom(State.rebirthAutoHovered, 1.06),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = Computed(function()
									local state = State.GetSnapshot()
									if not state.ownsAutoRebirth then
										return autoRebirthPriceText:get()
									end
									return if state.autoRebirthEnabled then "ON" else "OFF"
								end),
								MaxTextSize = 34,
								ZIndex = 47,
							}),
						},
					}),
				},
			}),
		},
	})
end

function RebirthModal.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		Visible = State.rebirthModalMounted,
		ZIndex = 38,
		[Children] = {
			buildPanel(),
		},
	})
end

return RebirthModal
