--!strict
-- Modal Group Chest: hiển thị quyền lợi group, yêu cầu like + join group, và claim reward.

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local GroupChestConfig = require(ReplicatedStorage.Shared.Config.GroupChest)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Tween = Fusion.Tween

local CHEST_ICON = "rbxassetid://76987123050422"
local FAN_TAG_ICON = "rbxassetid://139927899217214"

local GroupChestModal = {}

local function makeStatusPill(text: string, doneValue: any, position: UDim2)
	local colorA = Computed(function()
		return if doneValue:get() then Color3.fromRGB(80, 218, 110) else Color3.fromRGB(255, 186, 55)
	end)
	local colorB = Computed(function()
		return colorA:get():Lerp(Color3.fromRGB(0, 0, 0), 0.32)
	end)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(300, 62),
		ZIndex = 44,
		[Children] = {
			Theme.MakeCorner(14),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradientDynamic(colorA, colorB),
			Theme.MakeStandardStuds(14, 46),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(16, 6),
				Size = UDim2.fromOffset(52, 50),
				Text = Computed(function()
					return if doneValue:get() then "✓" else "!"
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				MaxTextSize = 34,
				ZIndex = 47,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(76, 8),
				Size = UDim2.fromOffset(208, 46),
				Text = text,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 26,
				ZIndex = 47,
			}),
		},
	})
end

local function makeRewardCard(position: UDim2, icon: string, title: string, subtitle: string, colorA: Color3, colorB: Color3)
	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(214, 144),
		ZIndex = 43,
		[Children] = {
			Theme.MakeCorner(16),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			Theme.MakeStandardStuds(16, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(76, 12),
				Size = UDim2.fromOffset(62, 62),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(10, 74),
				Size = UDim2.fromOffset(194, 34),
				Text = title,
				TextColor3 = Color3.fromRGB(255, 245, 128),
				MaxTextSize = 27,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(10, 108),
				Size = UDim2.fromOffset(194, 24),
				Text = subtitle,
				TextColor3 = Color3.fromRGB(220, 255, 235),
				MaxTextSize = 18,
				ZIndex = 46,
			}),
		},
	})
end

local function confirmLike()
	GamePackets.requestGroupChestLikeConfirm.send({})
end

local function runJoinLikeClaim()
	if State.groupChestHasClaimed:get() then
		Toast.Show("Group chest already claimed")
		return
	end

	confirmLike()

	task.spawn(function()
		if not State.groupChestIsGroupMember:get() then
			local ok = pcall(function()
				GroupService:PromptJoinAsync(GroupChestConfig.GROUP_ID)
			end)
			if not ok then
				Toast.Show("Open the group page from Roblox")
			end
		end

		task.wait(1.5)
		GamePackets.requestGroupChestState.send({})
		task.wait(0.6)
		GamePackets.requestGroupChestClaim.send({})
	end)
end

local function buildPanel()
	local closeHovered = State.groupChestCloseHovered
	local claimHovered = State.groupChestClaimHovered

	local canClaim = Computed(function()
		return State.groupChestIsGroupMember:get()
			and State.groupChestHasConfirmedLike:get()
			and not State.groupChestHasClaimed:get()
	end)

	return New("CanvasGroup")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(54, 16, 18),
		BackgroundTransparency = 0.18,
		ClipsDescendants = true,
		GroupTransparency = Computed(function()
			return 1 - State.groupChestModalAnimation:get()
		end),
		Position = Computed(function()
			return UDim2.fromOffset(960, 492 - (18 * State.groupChestModalAnimation:get()))
		end),
		Size = UDim2.fromOffset(760, 548),
		ZIndex = 40,
		[Children] = {
			Theme.MakeCorner(18),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(235, 55, 60),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(760, 96),
				ZIndex = 45,
				[Children] = {
					Theme.MakeCorner(18),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(255, 91, 84), Color3.fromRGB(171, 18, 34), 0),
					Theme.MakeStandardStuds(18, 47),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = CHEST_ICON,
						Position = UDim2.fromOffset(20, 11),
						Size = UDim2.fromOffset(68, 68),
						ZIndex = 47,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(100, 8),
						Size = UDim2.fromOffset(548, 74),
						Text = "Group Chest",
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 54,
						ZIndex = 47,
					}),
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return if closeHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
						end),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(680, 12),
						Size = UDim2.fromOffset(66, 66),
						Text = "X",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						ZIndex = 48,
						[OnEvent("Activated")] = Manager.CloseGroupChest,
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

			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(34, 108),
				Size = UDim2.fromOffset(692, 34),
				Text = "One tap starts the group join prompt, confirms like, then claims your reward.",
				TextColor3 = Color3.fromRGB(255, 226, 226),
				MaxTextSize = 24,
				ZIndex = 42,
			}),

			makeRewardCard(UDim2.fromOffset(36, 158), CHEST_ICON, "+5,000 Speed", "one-time starter gift", Color3.fromRGB(255, 118, 68), Color3.fromRGB(190, 36, 24)),
			makeRewardCard(UDim2.fromOffset(273, 158), Theme.UI_ASSETS.Trophy, "+10% Wins", "permanent group buff", Color3.fromRGB(255, 72, 88), Color3.fromRGB(150, 18, 42)),
			makeRewardCard(UDim2.fromOffset(510, 158), FAN_TAG_ICON, "[Fan] Tag", "green chat prefix", Color3.fromRGB(255, 93, 128), Color3.fromRGB(138, 22, 74)),

			makeStatusPill("Join Group", State.groupChestIsGroupMember, UDim2.fromOffset(64, 322)),
			makeStatusPill("Like Game", State.groupChestHasConfirmedLike, UDim2.fromOffset(396, 322)),

			New("TextButton")({
				AnchorPoint = Vector2.new(0.5, 0),
				AutoButtonColor = false,
				BackgroundColor3 = Computed(function()
					if State.groupChestHasClaimed:get() then
						return Color3.fromRGB(70, 110, 80)
					end
					if not canClaim:get() then
						return Color3.fromRGB(210, 54, 46)
					end
					return if claimHovered:get() then Color3.fromRGB(255, 104, 86) else Color3.fromRGB(230, 55, 48)
				end),
				ClipsDescendants = true,
				Position = UDim2.fromOffset(380, 404),
				Size = UDim2.fromOffset(560, 76),
				Text = "",
				ZIndex = 45,
				[OnEvent("Activated")] = runJoinLikeClaim,
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
							if State.groupChestHasClaimed:get() then
								return Color3.fromRGB(80, 132, 86)
							end
							return if claimHovered:get() then Color3.fromRGB(255, 118, 92) else Color3.fromRGB(235, 62, 54)
						end),
						Computed(function()
							if State.groupChestHasClaimed:get() then
								return Color3.fromRGB(34, 82, 42)
							end
							return Color3.fromRGB(150, 18, 28)
						end)
					),
					Theme.MakeStandardStuds(16, 47),
					Theme.HoverZoom(claimHovered, 1.06),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							if State.groupChestHasClaimed:get() then
								return "CLAIMED"
							end
							return if canClaim:get() then "CLAIM GROUP CHEST" else "JOIN + LIKE + CLAIM"
						end),
						MaxTextSize = 32,
						ZIndex = 48,
					}),
				},
			}),
		},
	})
end

function GroupChestModal.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		Visible = State.groupChestModalMounted,
		ZIndex = 38,
		[Children] = {
			buildPanel(),
		},
	})
end

return GroupChestModal
