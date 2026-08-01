--!strict
-- Modal Code: players enter promo codes to receive rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local OnChange = Fusion.OnChange
local Tween = Fusion.Tween

local CodeModal = {}

local function submitCode()
	local code = string.upper(string.gsub(State.codeInput:get(), "%s+", ""))
	if #code == 0 then
		Toast.Show("Enter a code first!")
		return
	end
	GamePackets.requestRedeemCode.send({ code = code })
	State.codeInput:set("")
	Manager.CloseCode()
end

local function buildPanel()
	return New("CanvasGroup")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(22, 110, 58),
		BackgroundTransparency = 0.3,
		ClipsDescendants = true,
		GroupTransparency = Computed(function()
			return 1 - State.codeModalAnimation:get()
		end),
		Position = Computed(function()
			return UDim2.fromOffset(960, 492 - (18 * State.codeModalAnimation:get()))
		end),
		Size = UDim2.fromOffset(740, 380),
		ZIndex = 40,
		[Children] = {
			Theme.MakeCorner(18),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),

			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(64, 206, 116),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(740, 96),
				ZIndex = 42,
				[Children] = {
					Theme.MakeCorner(18),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(96, 226, 142), Color3.fromRGB(28, 162, 84), 0),
					Theme.MakeStandardStuds(18, 47),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = Theme.UI_ASSETS.Code,
						Position = UDim2.fromOffset(20, 11),
						Size = UDim2.fromOffset(68, 68),
						ZIndex = 44,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(100, 8),
						Size = UDim2.fromOffset(530, 74),
						Text = "Redeem Code",
						MaxTextSize = 54,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 45,
					}),
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return if State.codeCloseHovered:get()
								then Color3.fromRGB(255, 92, 84)
								else Color3.fromRGB(211, 39, 49)
							end),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(660, 12),
						Size = UDim2.fromOffset(66, 66),
						Text = "X",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						ZIndex = 45,
						[OnEvent("Activated")] = Manager.CloseCode,
						[OnEvent("MouseEnter")] = function()
							State.codeCloseHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							State.codeCloseHovered:set(false)
						end,
						[Children] = {
							Theme.MakeCorner(10),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.HoverZoom(State.codeCloseHovered, 1.1),
							New("UIStroke")({
								Color = Color3.fromRGB(0, 0, 0),
								Thickness = 3,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							}),
						},
					}),
				},
			}),

			-- Instruction label
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(40, 106),
				Size = UDim2.fromOffset(660, 34),
				Text = "Enter a promo code below to claim your reward!",
				TextColor3 = Color3.fromRGB(210, 255, 228),
				MaxTextSize = 24,
				ZIndex = 43,
			}),

			-- Input box
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(8, 52, 24),
				ClipsDescendants = true,
				Position = UDim2.fromOffset(40, 148),
				Size = UDim2.fromOffset(480, 72),
				ZIndex = 42,
				[Children] = {
					Theme.MakeCorner(14),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(16, 72, 36), Color3.fromRGB(4, 32, 14)),
					New("TextBox")({
						BackgroundTransparency = 1,
						ClearTextOnFocus = false,
						Font = Enum.Font.GothamBlack,
						PlaceholderColor3 = Color3.fromRGB(80, 140, 100),
						PlaceholderText = "TYPE CODE HERE...",
						Position = UDim2.fromOffset(12, 4),
						Size = UDim2.fromOffset(456, 64),
						Text = State.codeInput,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0,
						ZIndex = 44,
						[OnChange("Text")] = function(text: string)
							if not State.isEnteringCode then return end
							State.codeInput:set(text)
						end,
						[OnEvent("Focused")] = function()
							State.isEnteringCode = true
						end,
						[OnEvent("FocusLost")] = function(enterPressed: boolean)
							State.isEnteringCode = false
							if enterPressed then
								submitCode()
							end
						end,
						[Children] = {
							New("UITextSizeConstraint")({
								MaxTextSize = 36,
								MinTextSize = 14,
							}),
						},
					}),
				},
			}),

			-- REDEEM button
			New("TextButton")({
				AutoButtonColor = false,
				BackgroundColor3 = Computed(function()
					return if State.codeRedeemHovered:get()
						then Color3.fromRGB(90, 240, 150)
						else Color3.fromRGB(52, 199, 100)
					end),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(534, 148),
				Size = UDim2.fromOffset(166, 72),
				Text = "",
				ZIndex = 42,
				[OnEvent("Activated")] = submitCode,
				[OnEvent("MouseEnter")] = function()
					State.codeRedeemHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					State.codeRedeemHovered:set(false)
				end,
				[Children] = {
					Theme.MakeCorner(14),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(88, 230, 140), Color3.fromRGB(30, 150, 72)),
					Theme.MakeStandardStuds(14, 47),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = "REDEEM",
						MaxTextSize = 26,
						ZIndex = 44,
					}),
					New("UIScale")({
						Scale = Tween(Computed(function()
							return if State.codeRedeemHovered:get() then 1.05 else 1
						end), TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)),
					}),
				},
			}),

			-- Social hint
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(40, 234),
				Size = UDim2.fromOffset(660, 40),
				Text = "Follow our social media for new codes!",
				TextColor3 = Color3.fromRGB(180, 240, 210),
				MaxTextSize = 22,
				ZIndex = 43,
			}),

			-- Divider line
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 0.7,
				Position = UDim2.fromOffset(40, 284),
				Size = UDim2.fromOffset(660, 3),
				ZIndex = 42,
				[Children] = {
					Theme.MakeCorner(2),
				},
			}),

			-- Bottom hint
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(40, 296),
				Size = UDim2.fromOffset(660, 72),
				Text = "Join Discord & like on Roblox to stay updated!",
				TextColor3 = Color3.fromRGB(150, 220, 180),
				MaxTextSize = 20,
				ZIndex = 43,
			}),
		},
	})
end

function CodeModal.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		Visible = State.codeModalMounted,
		ZIndex = 38,
		[Children] = {
			buildPanel(),
		},
	})
end

return CodeModal
