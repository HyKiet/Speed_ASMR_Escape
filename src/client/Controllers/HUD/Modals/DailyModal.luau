--!strict
-- Modal Daily Login: điểm danh 7 ngày (hardcore streak). Theme hồng/magenta riêng biệt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")


local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent

local DailyModal = {}

-- Bảng Cấu hình Hiển thị 7 Ngày (Khớp với DAILY_REWARDS bên server)

local REWARD_CONFIGS = {
	{ primary = "+300 Wins", secondary = "+1 Spin Ticket", icon = Theme.UI_ASSETS.Trophy },
	{ primary = "+5.00K Speed", secondary = "x2 Speed 10m", icon = Theme.UI_ASSETS.Shoe },
	{ primary = "+1.00K Wins", secondary = "+1 Spin Ticket", icon = Theme.UI_ASSETS.Trophy },
	{ primary = "+15.00K Speed", secondary = "x2 Wins 10m", icon = Theme.UI_ASSETS.Shoe },
	{ primary = "+3.00K Wins", secondary = "+2 Spin Tickets", icon = Theme.UI_ASSETS.Trophy },
	{ primary = "+35.00K Speed", secondary = "+Server Boost", icon = Theme.UI_ASSETS.Shoe },
	{ primary = "+10.00K Wins", secondary = "+3 Spins & +50K Speed", icon = Theme.UI_ASSETS.Trophy },
}

-- Trạng thái 1 ngày: "claimed" | "claimable" | "locked"
local function dayStatus(day: number): string
	local streak = State.dailyStreakDay:get()
	local nextDay = State.dailyNextDay:get()
	local canClaim = State.dailyCanClaim:get()
	if day <= streak then
		return "claimed"
	end
	if canClaim and day == nextDay then
		return "claimable"
	end
	return "locked"
end

local function makeDayCard(day: number)
	local isDay7 = day == 7
	local cfg = REWARD_CONFIGS[day]

	local colorA = Computed(function()
		local status = dayStatus(day)
		if status == "claimed" then
			return Color3.fromRGB(86, 200, 110)
		elseif status == "claimable" then
			return if isDay7 then Color3.fromRGB(255, 222, 60) else Color3.fromRGB(255, 206, 64)
		end
		return if isDay7 then Color3.fromRGB(200, 60, 220) else Color3.fromRGB(150, 70, 165)
	end)
	local colorB = Computed(function()
		return colorA:get():Lerp(Color3.fromRGB(0, 0, 0), 0.34)
	end)

	local w = if isDay7 then 200 else 145
	local h = if isDay7 then 315 else 152

	local cardChildren: { any } = {
		Theme.MakeCorner(16),
		Theme.MakeStroke(if isDay7 then Color3.fromRGB(255, 235, 100) else Color3.fromRGB(0, 0, 0), if isDay7 then 5 else 4),
		Theme.MakeGradientDynamic(colorA, colorB),
		Theme.MakeStandardStuds(16, 44),
	}

	-- Nếu là Day 7: Thêm tia hào quang Sunburst xoay rực rỡ
	if isDay7 then
		local sunburst = New("ImageLabel")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.UI_ASSETS.Sunburst,
			ImageColor3 = Color3.fromRGB(255, 235, 110),
			ImageTransparency = 0.25,
			Position = UDim2.fromOffset(w / 2, h / 2 - 25),
			Size = UDim2.fromOffset(270, 270),
			ZIndex = 45,
		})
		local tween = TweenService:Create(
			sunburst,
			TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 360 }
		)
		tween:Play()
		table.insert(cardChildren, sunburst)
	end

	-- DAY n / GRAND JACKPOT
	table.insert(cardChildren, Theme.MakeOutlineLabel({
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromOffset(w, 24),
		Text = if isDay7 then "GRAND JACKPOT ★" else `DAY {day}`,
		TextColor3 = if isDay7 then Color3.fromRGB(255, 245, 120) else Color3.fromRGB(255, 255, 255),
		MaxTextSize = if isDay7 then 24 else 20,
		ZIndex = 46,
	}))

	-- Icon trung tâm (Cúp Vàng cho Wins, Đôi Giày cho Speed)
	table.insert(cardChildren, New("ImageLabel")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = cfg.icon,
		Position = UDim2.fromOffset(w / 2, if isDay7 then 125 else 66),
		Size = if isDay7 then UDim2.fromOffset(92, 92) else UDim2.fromOffset(50, 50),
		ZIndex = 46,
	}))

	-- Phần thưởng chính (+ Wins / + Speed)
	table.insert(cardChildren, Theme.MakeOutlineLabel({
		Position = UDim2.fromOffset(0, h - (if isDay7 then 62 else 48)),
		Size = UDim2.fromOffset(w, 24),
		Text = cfg.primary,
		TextColor3 = Color3.fromRGB(255, 244, 130),
		MaxTextSize = if isDay7 then 26 else 20,
		ZIndex = 46,
	}))

	-- Phần thưởng phụ (+ Spin Ticket / Buff x2)
	table.insert(cardChildren, Theme.MakeOutlineLabel({
		Position = UDim2.fromOffset(0, h - 24),
		Size = UDim2.fromOffset(w, 20),
		Text = cfg.secondary,
		TextColor3 = Color3.fromRGB(180, 255, 220),
		MaxTextSize = if isDay7 then 17 else 14,
		ZIndex = 46,
	}))

	-- Lớp phủ "CLAIMED" khi đã nhận
	table.insert(cardChildren, New("Frame")({
		BackgroundColor3 = Color3.fromRGB(8, 40, 16),
		BackgroundTransparency = 0.45,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		Visible = Computed(function()
			return dayStatus(day) == "claimed"
		end),
		ZIndex = 47,
		[Children] = {
			Theme.MakeCorner(16),
			Theme.MakeOutlineLabel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = -15,
				Size = UDim2.fromScale(0.9, 0.4),
				Text = "CLAIMED",
				TextColor3 = Color3.fromRGB(88, 255, 120),
				MaxTextSize = 28,
				ZIndex = 48,
			}),
		},
	}))

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		LayoutOrder = day,
		Size = UDim2.fromOffset(w, h),
		ZIndex = 43,
		[Children] = cardChildren,
	})
end

local function buildGrid()
	local cards1to6 = {}
	for day = 1, 6 do
		table.insert(cards1to6, makeDayCard(day))
	end
	table.insert(cards1to6, New("UIGridLayout")({
		CellPadding = UDim2.fromOffset(10, 10),
		CellSize = UDim2.fromOffset(145, 152),
		FillDirectionMaxCells = 3,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}))

	local leftFrame = New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(455, 315),
		[Children] = cards1to6,
	})

	local day7Card = makeDayCard(7)
	day7Card.Position = UDim2.fromOffset(465, 0)

	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(17, 146),
		Size = UDim2.fromOffset(665, 315),
		ZIndex = 43,
		[Children] = {
			leftFrame,
			day7Card
		},
	})
end

local function buildPanel()

	local closeHovered = State.dailyCloseHovered
	local claimHovered = State.dailyClaimHovered

	return New("CanvasGroup")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(30, 0, 20),
		BackgroundTransparency = 0.3,
		ClipsDescendants = true,
		GroupTransparency = Computed(function()
			return 1 - State.dailyModalAnimation:get()
		end),
		Position = Computed(function()
			return UDim2.fromOffset(960, 492 - (18 * State.dailyModalAnimation:get()))
		end),
		Size = UDim2.fromOffset(700, 584),
		ZIndex = 40,
		[Children] = {
			Theme.MakeCorner(18),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),

			-- Header (hồng)
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(255, 110, 190),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(700, 96),
				ZIndex = 45,
				[Children] = {
					Theme.MakeCorner(18),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(255, 150, 214), Color3.fromRGB(236, 64, 156), 0),
					Theme.MakeStandardStuds(18, 47),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = Theme.UI_ASSETS.Daily,
						Position = UDim2.fromOffset(20, 11),
						Size = UDim2.fromOffset(68, 68),
						ZIndex = 47,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(100, 8),
						Size = UDim2.fromOffset(496, 74),
						Text = "Daily Rewards",
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 50,
						ZIndex = 47,
					}),
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return if closeHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
						end),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(620, 12),
						Size = UDim2.fromOffset(66, 66),
						Text = "X",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						ZIndex = 48,
						[OnEvent("Activated")] = Manager.CloseDaily,
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

			-- Subtitle
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(24, 106),
				Size = UDim2.fromOffset(652, 36),
				Text = "Log in every day! Miss a day and your streak resets.",
				TextColor3 = Color3.fromRGB(255, 226, 244),
				MaxTextSize = 22,
				ZIndex = 42,
			}),

			buildGrid(),

			-- Claim button
			New("TextButton")({
				AnchorPoint = Vector2.new(0.5, 0),
				AutoButtonColor = false,
				BackgroundColor3 = Computed(function()
					if not State.dailyCanClaim:get() then
						return Color3.fromRGB(96, 50, 86)
					end
					return if claimHovered:get() then Color3.fromRGB(110, 240, 130) else Color3.fromRGB(70, 210, 100)
				end),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(350, 500),
				Size = UDim2.fromOffset(440, 66),
				Text = "",
				ZIndex = 45,
				[OnEvent("Activated")] = function()
					if State.dailyCanClaim:get() then
						GamePackets.requestDailyClaim.send({})
					end
				end,
				[OnEvent("MouseEnter")] = function()
					claimHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					claimHovered:set(false)
				end,
				[Children] = {
					Theme.MakeCorner(16),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradientDynamic(
						Computed(function()
							return if State.dailyCanClaim:get() then Color3.fromRGB(108, 240, 130) else Color3.fromRGB(110, 64, 100)
						end),
						Computed(function()
							return if State.dailyCanClaim:get() then Color3.fromRGB(34, 162, 64) else Color3.fromRGB(70, 36, 64)
						end)
					),
					Theme.MakeStandardStuds(16, 46),
					Theme.HoverZoom(claimHovered, 1.08),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							if State.dailyCanClaim:get() then
								return `CLAIM DAY {State.dailyNextDay:get()}`
							end
							return "COME BACK TOMORROW"
						end),
						MaxTextSize = 36,
						ZIndex = 47,
					}),
				},
			}),
		},
	})
end

function DailyModal.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		Visible = State.dailyModalMounted,
		ZIndex = 38,
		[Children] = {
			buildPanel(),
		},
	})
end

return DailyModal
