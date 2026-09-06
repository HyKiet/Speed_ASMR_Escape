--!strict
-- Hàng hành động góc phải-trên: Daily · Emotes · Spin, tất cả là icon không nền.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Responsive = require(script.Parent.Parent.Responsive)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Manager = require(script.Parent.Parent.Modals.Manager)
local UIAnchors = require(script.Parent.Parent.UIAnchors)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent

local TopRightRow = {}

local function makeIconButton(props: { [any]: any }, activated: () -> ())
	local button = New("ImageButton")(props)
	Responsive.AttachHitArea(button, activated)
	return button
end

local function makeAction(name: string, slot: string, icon: string, activated: () -> (), badgeVisible: any?)
	return New("Frame")({
		Name = `{name}Action`,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(Theme.TOP_ROW[slot], 0),
		Size = UDim2.fromOffset(104, 116),
		[Children] = {
			makeIconButton({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.fromOffset(84, 84),
				ZIndex = 4,
				[OnEvent("Activated")] = activated,
			}, activated),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 78),
				Size = UDim2.fromOffset(104, 28),
				Text = name,
				MaxTextSize = 22,
				ZIndex = 5,
			}),
			Theme.MakeSurface({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(88, 12),
				Size = UDim2.fromOffset(28, 28),
				Visible = badgeVisible or false,
				ZIndex = 6,
				Radius = 14,
				Border = 3,
				Studs = false,
				Color = Color3.fromRGB(226, 35, 55),
				Content = {
					Theme.MakeOutlineLabel({
						Size = UDim2.fromScale(1, 1),
						Text = "!",
						MaxTextSize = 20,
						ZIndex = 7,
					}),
				},
			}),
		},
	})
end

local function makeSpin()
	return New("Frame")({
		Name = "SpinAction",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(Theme.TOP_ROW.spin, 0),
		Size = UDim2.fromOffset(120, 130),
		[Children] = {
			UIAnchors.Keep(
				"spinButton",
				makeIconButton({
					BackgroundTransparency = 1,
					Image = Theme.UI_ASSETS.Spin,
					Position = UDim2.fromOffset(10, 0),
					Size = UDim2.fromOffset(100, 100),
					[OnEvent("Activated")] = Manager.ToggleRoulette,
				}, Manager.ToggleRoulette)
			),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 60),
				Size = UDim2.fromOffset(120, 25),
				Text = "Spin",
				MaxTextSize = 24,
				ZIndex = 5,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 85),
				Size = UDim2.fromOffset(120, 25),
				Text = Computed(function()
					local base = State.rouletteNextFreeSeconds:get()
					if base < 0 then
						return "FULL"
					end
					local elapsed = State.boostClockNow:get() - State.rouletteNextFreeReceivedAt:get()
					local left = math.max(0, math.floor(base - elapsed))
					return string.format("%d:%02d", left // 60, left % 60)
				end),
				TextColor3 = Color3.fromRGB(255, 222, 62),
				MaxTextSize = 22,
				ZIndex = 5,
			}),
			Theme.MakeSurface({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(102, 14),
				Size = UDim2.fromOffset(38, 38),
				ZIndex = 6,
				Radius = 19,
				Border = Tokens.BORDER,
				Studs = false,
				Color = Color3.fromRGB(226, 35, 55),
				Visible = Computed(function()
					return State.rouletteTickets:get() > 0
				end),
				Content = {
					Theme.MakeOutlineLabel({
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							return tostring(State.rouletteTickets:get())
						end),
						MaxTextSize = 24,
						ZIndex = 7,
					}),
				},
			}),
		},
	})
end

function TopRightRow.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = Computed(function()
			return Theme.TopRowSlotPosition("starterPack")
		end),
		Size = UDim2.fromOffset(Theme.TOP_ROW_WIDTH, Theme.TOP_ROW_HEIGHT),
		[Children] = {
			UIAnchors.Keep(
				"dailyButton",
				makeAction(
					"Daily",
					"daily",
					Theme.UI_ASSETS.Daily,
					Manager.ToggleDaily,
					Computed(function()
						return State.dailyCanClaim:get()
					end)
				)
			),
			makeAction("Emotes", "emote", Theme.UI_ASSETS.Emotes, Manager.ToggleEmote),
			makeSpin(),
		},
	})
end

return TopRightRow
