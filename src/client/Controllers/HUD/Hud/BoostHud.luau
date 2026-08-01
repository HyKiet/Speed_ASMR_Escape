--!strict
-- Thanh đếm ngược Boost đang hoạt động (GÓC DƯỚI PHẢI, xếp dọc): x2/x4 SPEED + x2/x4 WINS.
-- Server gửi số giây còn lại qua boostState; client tự đếm ngược theo State.boostClockNow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New

local BoostHud = {}

local function formatClock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

-- Trả về (multiplier, secondsLeft) gộp server + personal của 1 loại boost.
local function combine(serverUntil: number, personalUntil: number): (number, number)
	local now = State.boostClockNow:get()
	local serverLeft = math.max(0, serverUntil - now)
	local personalLeft = math.max(0, personalUntil - now)
	local multiplier = 1
	if serverLeft > 0 then
		multiplier *= 2
	end
	if personalLeft > 0 then
		multiplier *= 2
	end
	return multiplier, math.max(serverLeft, personalLeft)
end

local function makeChip(icon: string, label: string, colorA: Color3, colorB: Color3, serverValue: any, personalValue: any, order: number)
	local multiplier = Computed(function()
		local m = combine(serverValue:get(), personalValue:get())
		return m
	end)
	local secondsLeft = Computed(function()
		local _, left = combine(serverValue:get(), personalValue:get())
		return left
	end)

	return New("Frame")({
		BackgroundColor3 = colorA,
		LayoutOrder = order,
		Size = UDim2.fromOffset(250, 54),
		Visible = Computed(function()
			return secondsLeft:get() > 0
		end),
		ZIndex = 30,
		[Children] = {
			Theme.MakeCorner(14),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB, 0),
			Theme.MakeStandardStuds(14, 31),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(8, 7),
				Size = UDim2.fromOffset(40, 40),
				ZIndex = 33,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(52, 6),
				Size = UDim2.fromOffset(120, 42),
				Text = Computed(function()
					return `x{multiplier:get()} {label}`
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 26,
				ZIndex = 33,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(172, 6),
				Size = UDim2.fromOffset(70, 42),
				Text = Computed(function()
					return formatClock(secondsLeft:get())
				end),
				TextColor3 = Color3.fromRGB(255, 244, 130),
				TextXAlignment = Enum.TextXAlignment.Right,
				MaxTextSize = 26,
				ZIndex = 33,
			}),
		},
	})
end

function BoostHud.Build()
	return New("Frame")({
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = Computed(function()
			local _, _, right, bottom = Theme.GetVisibleDesignBounds()
			return UDim2.fromOffset(right - 14, bottom - 14)
		end),
		Size = UDim2.fromOffset(250, 122),
		ZIndex = 30,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			makeChip(Theme.UI_ASSETS.Lightning, "SPEED", Color3.fromRGB(72, 220, 200), Color3.fromRGB(20, 130, 150), State.boostServerSpeedUntil, State.boostPersonalSpeedUntil, 1),
			makeChip(Theme.UI_ASSETS.Trophy, "WINS", Color3.fromRGB(255, 190, 72), Color3.fromRGB(220, 110, 20), State.boostServerWinsUntil, State.boostPersonalWinsUntil, 2),
		},
	})
end

return BoostHud
