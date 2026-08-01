--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local FriendsHud = {}

function FriendsHud.Build()
	local hoveredFriends = Value(false)

	return New("Frame")({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = Computed(function()
			local left, _, _, bottom, scale = Theme.GetVisibleDesignBounds()
			local x = left + (14 / scale)
			local y = bottom - (14 / scale)
			return UDim2.fromOffset(x, y)
		end),
		Size = UDim2.fromOffset(70, 70),
		ZIndex = 10,
		[Children] = {
			New("ImageButton")({
				BackgroundTransparency = 1,
				Image = "rbxassetid://85786506345593",
				Position = UDim2.fromOffset(10, -5),
				Size = UDim2.fromOffset(50, 50),
				[OnEvent("Activated")] = function()
					local SocialService = game:GetService("SocialService")
					pcall(function()
						SocialService:PromptGameInvite(Players.LocalPlayer)
					end)
				end,
				[OnEvent("MouseEnter")] = function()
					hoveredFriends:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					hoveredFriends:set(false)
				end,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 35),
				Size = UDim2.fromOffset(70, 20),
				Text = "Friends",
				MaxTextSize = 14,
				ZIndex = 5,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 50),
				Size = UDim2.fromOffset(70, 20),
				Text = Computed(function()
					local mult = State.GetSnapshot().friendsMultiplier or 1
					return "Boost: x" .. mult
				end),
				MaxTextSize = 13,
				ZIndex = 5,
			}),
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.25,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromOffset(80, 70),
				Size = UDim2.fromOffset(420, 160),
				Visible = hoveredFriends,
				ZIndex = 50,
				[Children] = {
					Theme.MakeCorner(12),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 3),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(16, 16),
						Size = UDim2.fromOffset(388, 64),
						Text = "Invite friends to get up to x1.5 Speed and x1.25 Wins! (+10% Speed per friend)",
						MaxTextSize = 22,
						TextWrapped = true,
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 51,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(16, 86),
						Size = UDim2.fromOffset(388, 28),
						Text = Computed(function()
							return "Friends in server: " .. (State.GetSnapshot().friendsInServer or 0) .. "/5"
						end),
						TextColor3 = Color3.fromRGB(255, 222, 62),
						MaxTextSize = 26,
						ZIndex = 51,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(16, 118),
						Size = UDim2.fromOffset(388, 28),
						Text = Computed(function()
							local mult = State.GetSnapshot().friendsMultiplier or 1
							return "Speed Boost: x" .. mult
						end),
						TextColor3 = Color3.fromRGB(255, 222, 62),
						MaxTextSize = 26,
						ZIndex = 51,
					}),
				},
			}),
		},
	})
end

return FriendsHud
