--!strict
--[[
	QuestTracker — DẢI NHẮC NHIỆM VỤ THU GỌN neo giữa mép trên, ngay dưới dải tutorial.

	Bảng nhiệm vụ đầy đủ KHÔNG còn ở đây: nó là `Modals/QuestModal`, nằm cùng chỗ với 12 modal
	kia (xem khối lý do trong file đó). File này chỉ còn đúng một việc — nhắc mục tiêu hiện tại
	mà không chiếm màn hình.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New

local QuestTracker = {}

local function trackerVisible(): boolean
	local dailyComplete = State.dailyQuestActive:get()
		and State.dailyQuest1Claimed:get()
		and State.dailyQuest2Claimed:get()
		and State.dailyQuest3Claimed:get()
	return State.questActive:get()
		and not dailyComplete
		and not State.tutorialBannerVisible:get()
		and not State.anyModalOpen:get()
end

local function makeCompactReward()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(282, 12),
		Size = UDim2.fromOffset(136, 34),
		ZIndex = 31,
		[Children] = {
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Computed(function()
					if State.dailyQuestActive:get() then
						return Theme.UI_ASSETS.Trophy
					end
					return if State.questRewardSpeed:get() > 0 then Theme.UI_ASSETS.Shoe else Theme.UI_ASSETS.Spin
				end),
				Size = UDim2.fromOffset(30, 30),
				ZIndex = 31,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(34, 0),
				Size = UDim2.fromOffset(100, 30),
				Text = Computed(function()
					if State.dailyQuestActive:get() then
						return `+{Theme.FormatInteger(State.dailyQuestRewardWins:get())}`
					end
					local amount = if State.questRewardSpeed:get() > 0
						then State.questRewardSpeed:get()
						else State.questRewardSpins:get()
					return `+{Theme.FormatInteger(amount)}`
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(255, 226, 95),
				MaxTextSize = 20,
				ZIndex = 32,
			}),
		},
	})
end

local function buildCompact()
	return Theme.MakeSurface({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(960, 112),
		Size = UDim2.fromOffset(440, 84),
		Visible = Computed(trackerVisible),
		ZIndex = 28,
		Radius = 16,
		Border = Tokens.BORDER,
		Studs = true,
		Color = Color3.fromRGB(55, 38, 112),
		Content = {
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Quest,
				Position = UDim2.fromOffset(12, 10),
				Size = UDim2.fromOffset(42, 42),
				ZIndex = 30,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(60, 7),
				Size = UDim2.fromOffset(218, 42),
				Text = Computed(function()
					return State.questTitle:get()
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 22,
				ZIndex = 30,
			}),
			makeCompactReward(),
			Theme.MakeSurface({
				Position = UDim2.fromOffset(14, 56),
				Size = UDim2.fromOffset(412, 18),
				ZIndex = 30,
				Radius = 9,
				Border = Tokens.BORDER,
				Studs = false,
				Color = Color3.fromRGB(20, 14, 46),
				Content = {
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(255, 203, 54),
						BorderSizePixel = 0,
						Size = Computed(function()
							local target = math.max(1, State.questTarget:get())
							return UDim2.fromScale(math.clamp(State.questProgress:get() / target, 0, 1), 1)
						end),
						ZIndex = 31,
						[Children] = { Theme.MakeCorner(9) },
					}),
					Theme.MakeOutlineLabel({
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							return `{math.floor(State.questProgress:get())}/{math.floor(State.questTarget:get())}`
						end),
						MaxTextSize = 15,
						ZIndex = 32,
					}),
				},
			}),
		},
	})
end

function QuestTracker.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1920, 1080),
		[Children] = { buildCompact() },
	})
end

return QuestTracker
