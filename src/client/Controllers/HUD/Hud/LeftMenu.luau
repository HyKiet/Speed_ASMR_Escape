--!strict
-- Cụm nút menu trái (Wins counter + Rebirth/Shop/Cosmetics/Teleport).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Manager = require(script.Parent.Parent.Modals.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local LeftMenu = {}

local winsScaleGoal = Value(1)

local winsScale = Fusion.Tween(winsScaleGoal, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
local winsContainer: Frame? = nil

local lastWins = 0
local function setupWinsObserver()
	Fusion.Observer(Computed(function()
		return State.GetSnapshot().totalWins
	end)):onChange(function()
		local currentWins = State.GetSnapshot().totalWins
		if lastWins > 0 and currentWins > lastWins and winsContainer and winsContainer.Parent then
			local delta = currentWins - lastWins

			-- 1. Scale pulse
			winsScaleGoal:set(1.22)
			task.delay(0.2, function()
				winsScaleGoal:set(1)
			end)

			-- 2. Chime sound
			-- ⚠️ ID cũ 131686958279369 KHÔNG PHẢI Audio — chính là ảnh icon "Small Wins Pack"
			-- trong Theme.SHOP_CATALOG.products (copy nhầm), sound câm suốt không log lỗi.
			-- Dùng lại Theme.UI_ASSETS.LevelUpSound cho nhất quán với BoostCelebration.
			task.spawn(function()
				local sound = Instance.new("Sound")
				sound.SoundId = Theme.UI_ASSETS.LevelUpSound
				sound.Volume = 0.55
				sound.PlaybackSpeed = 1.25
				sound.Parent = SoundService
				sound.PlayOnRemove = true
				sound:Destroy()
			end)

			-- 3. Floating +Wins popup
			local popup = Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(62, -10),
				Size = UDim2.fromOffset(200, 30),
				Text = `+{Theme.FormatInteger(delta)} Wins!`,
				TextColor3 = Color3.fromRGB(255, 235, 70),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 28,
				ZIndex = 30,
			})
			popup.Parent = winsContainer

			local tween = TweenService:Create(popup, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(62, -45),
				TextTransparency = 1,
			})
			tween.Completed:Once(function()
				popup:Destroy()
			end)
			tween:Play()
		end
		lastWins = currentWins
	end)
end

local function makeWinsDisplay()
	local frame = New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(264, 62),
		ZIndex = 12,
		[Children] = {
			New("UIScale")({
				Scale = winsScale,
			}),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Trophy,
				Position = UDim2.fromOffset(0, 3),
				Size = UDim2.fromOffset(56, 56),
				ZIndex = 12,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(62, 4),
				Size = UDim2.fromOffset(192, 54),
				Text = Computed(function()
					return Theme.FormatInteger(State.GetSnapshot().totalWins)
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 40,
				ZIndex = 13,
			}),
		},
	})
	winsContainer = frame
	setupWinsObserver()
	return frame
end


local function makeRebirthsDisplay()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.fromOffset(264, 62),
		[Children] = {
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = "rbxassetid://103236589125008",
				Position = UDim2.fromOffset(0, 3),
				Size = UDim2.fromOffset(56, 56),
				ZIndex = 12,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(62, 4),
				Size = UDim2.fromOffset(192, 54),
				Text = Computed(function()
					return Theme.FormatInteger(State.GetSnapshot().rebirths)
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 40,
				ZIndex = 13,
			}),
		},
	})
end

function LeftMenu.Build()
	local hoveredFriends = Value(false)
	return New("Frame")({
		BackgroundTransparency = 1,
		ZIndex = 10,
		Position = Computed(function()
			local left, top, _, bottom, scale = Theme.GetVisibleDesignBounds()
			local x = if scale < 0.75 then left + (14 / scale) else 28
			local y = if scale < 0.75 then top + ((bottom - top - 610) * 0.5) else 236
			return UDim2.fromOffset(x, y)
		end),
		Size = UDim2.fromOffset(272, 610),
		[Children] = {
			makeWinsDisplay(),
			makeRebirthsDisplay(),
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 136),
				Size = UDim2.fromOffset(272, 464),
				ZIndex = 10,
				[Children] = {
					New("UIGridLayout")({
						CellPadding = UDim2.fromOffset(12, 12),
						CellSize = UDim2.fromOffset(130, 130),
						FillDirectionMaxCells = 2,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Theme.MakeMenuButton("Daily", Theme.UI_ASSETS.Daily, Color3.fromRGB(255, 120, 196), Color3.fromRGB(204, 40, 140), Manager.ToggleDaily),
						Theme.MakeMenuButton("Rebirth", Theme.UI_ASSETS.Rebirth, Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 150, 10), Manager.ToggleRebirth),
					Theme.MakeMenuButton("Shop", Theme.UI_ASSETS.Shop, Color3.fromRGB(255, 110, 80), Color3.fromRGB(255, 195, 55), Manager.ToggleShop),
					Theme.MakeMenuButton("Cosmetics", Theme.UI_ASSETS.Cosmetics, Color3.fromRGB(186, 90, 255), Color3.fromRGB(100, 50, 210), function()
						Manager.ToggleCosmetic("trail")
					end),
					Theme.MakeMenuButton("Teleport", Theme.UI_ASSETS.Teleport, Color3.fromRGB(68, 210, 255), Color3.fromRGB(30, 120, 210), Manager.ToggleTeleport),
					Theme.MakeMenuButton("Codes", Theme.UI_ASSETS.Code, Color3.fromRGB(72, 220, 130), Color3.fromRGB(26, 140, 72), Manager.ToggleCode),
				},
			}),
		},
	})
end

return LeftMenu
