--!strict
-- HUD orchestrator: dựng ScreenGui, subscribe GamePackets, vòng lặp treadmill animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local ParkourConfig = require(script.Parent.Parent.Parkour.ParkourConfig)
local Toast = require(script.Parent.Toast)
local LevelUp = require(script.Parent.LevelUp)
local BoostCelebration = require(script.Parent.BoostCelebration)
local Manager = require(script.Parent.Modals.Manager)
local LeftMenu = require(script.Parent.Hud.LeftMenu)
local RightPanel = require(script.Parent.Hud.RightPanel)
local BottomHud = require(script.Parent.Hud.BottomHud)
local BoostHud = require(script.Parent.Hud.BoostHud)
local FriendsHud = require(script.Parent.Hud.FriendsHud)
local RebirthModal = require(script.Parent.Modals.RebirthModal)
local CosmeticModal = require(script.Parent.Modals.CosmeticModal)
local TeleportModal = require(script.Parent.Modals.TeleportModal)
local ReviveModal = require(script.Parent.Modals.ReviveModal)
local ShopModal = require(script.Parent.Modals.ShopModal)
local CodeModal = require(script.Parent.Modals.CodeModal)
local DailyModal = require(script.Parent.Modals.DailyModal)
local GroupChestModal = require(script.Parent.Modals.GroupChestModal)
local RouletteModal = require(script.Parent.Modals.RouletteModal)

local Children = Fusion.Children
local New = Fusion.New

local localPlayer = Players.LocalPlayer

local HUDController = {}

-- Hoạt ảnh chạy trên treadmill: xem TreadmillAnimController (attribute-driven,
-- đồng bộ cho mọi client — không còn xử lý trong HUD).

local function buildGui()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local gui = New("ScreenGui")({
		Name = "CoreLoopHUD",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		Parent = playerGui,
		[Children] = {
			New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
				[Children] = {
					New("UIScale")({
						Scale = State.viewportScale,
					}),
					LeftMenu.Build(),
					RightPanel.Build(),
					BottomHud.Build(),
					BoostHud.Build(),
					FriendsHud.Build(),
					RebirthModal.Build(),
					ShopModal.Build(),
					CosmeticModal.Build(),
					TeleportModal.Build(),
					CodeModal.Build(),
					DailyModal.Build(),
					GroupChestModal.Build(),
					RouletteModal.Build(),
					BoostCelebration.Build(),
					Toast.BuildCenterToast(),
				},
			}),
		},
	})


	State.sweeper:Add(gui)
	-- Revive: ScreenGui riêng (neo mép trên màn hình, IgnoreGuiInset).
	State.sweeper:Add(ReviveModal.Build())
end

function HUDController.Init()
	buildGui()
	Theme.UpdateViewportScale()

	local camera = Workspace.CurrentCamera
	if camera then
		State.sweeper:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(Theme.UpdateViewportScale))
	end
	State.sweeper:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(Theme.UpdateViewportScale))
end

function HUDController.Start()
	local snapshotListener = GamePackets.profileSnapshot.listen(function(data: State.Snapshot)
		local previousSpeed = State.lastSpeed
		local previousSnapshot = State.snapshot:get(false)
		local wasLoaded = previousSnapshot.isLoaded
		State.snapshot:set(data)
		State.lastSpeed = data.speed
		if not State.isEditingCustomSpeed then
			State.SyncCustomSpeedDraft(data.customSpeedLimit)
		end

		if wasLoaded and data.speed > previousSpeed then
			Toast.ShowSpeedPopup(data.speed - previousSpeed)
		end
		if wasLoaded and data.level > previousSnapshot.level then
			LevelUp.Trigger(data.level, data.level - previousSnapshot.level)
		end
	end)

	local toastListener = GamePackets.toast.listen(function(data)
		Toast.Show(if data.amount > 0 then `+{Theme.FormatInteger(data.amount)} {data.message}` else data.message, data.kind)
	end)

	local dailyStateListener = GamePackets.dailyState.listen(function(data)
		State.dailyStreakDay:set(data.streakDay)
		State.dailyCanClaim:set(data.canClaim)
		State.dailyNextDay:set(data.nextDay)
	end)

	local groupChestStateListener = GamePackets.groupChestState.listen(function(data)
		State.groupChestIsGroupMember:set(data.isGroupMember)
		State.groupChestHasConfirmedLike:set(data.hasConfirmedLike)
		State.groupChestHasClaimed:set(data.hasClaimed)
		Manager.OpenGroupChest()
	end)

	local function updatePlaytime()
		State.sessionPlaytime:set(localPlayer:GetAttribute("SessionPlaytime") or 0)
	end
	updatePlaytime()
	local playtimeListener = localPlayer:GetAttributeChangedSignal("SessionPlaytime"):Connect(updatePlaytime)
	State.sweeper:Add(playtimeListener)

	-- Server Boosts: deadline = os.clock() + số giây server báo; BoostHud tự đếm ngược.
	local boostStateListener = GamePackets.boostState.listen(function(data)
		local now = os.clock()
		State.boostServerSpeedUntil:set(now + data.serverSpeedSecondsLeft)
		State.boostServerWinsUntil:set(now + data.serverWinsSecondsLeft)
		State.boostPersonalSpeedUntil:set(now + data.personalSpeedSecondsLeft)
		State.boostPersonalWinsUntil:set(now + data.personalWinsSecondsLeft)
	end)

	local boostCelebrationListener = GamePackets.boostCelebration.listen(function(data)
		BoostCelebration.Trigger(data.playerName, data.boostName)
	end)

	local purchaseCelebrationListener = GamePackets.purchaseCelebration.listen(function(data)
		BoostCelebration.TriggerPurchase(data.itemName, data.subtitle)
	end)

	local eventStateListener = GamePackets.eventState.listen(function(data)
		State.eventName:set(data.name)
		State.eventSpeedMultiplier:set(data.speedMultiplier)
		State.eventWinsMultiplier:set(data.winsMultiplier)
	end)

	local rouletteStateListener = GamePackets.rouletteState.listen(function(data)
		State.rouletteTickets:set(data.tickets)
		State.rouletteNextFreeSeconds:set(data.nextFreeTicketSeconds)
		State.rouletteNextFreeReceivedAt:set(os.clock())
	end)

	local spinResultListener = GamePackets.spinResult.listen(function(data)
		RouletteModal.OnSpinResult(data)
	end)

	-- Đồng hồ chung cho các Computed đếm ngược (boost chips + roulette timer).
	task.spawn(function()
		while localPlayer.Parent == Players do
			State.boostClockNow:set(os.clock())
			task.wait(0.25)
		end
	end)

	GamePackets.requestRouletteState.send({})

	local reviveOfferListener = GamePackets.reviveOffer.listen(function(data)
		Manager.OpenRevive(
			data.stage,
			data.durationSeconds,
			data.robuxProductId,
			data.robuxPrice,
			data.adRewardProductId,
			data.freeRevive
		)
	end)

	local reviveClosedListener = GamePackets.reviveClosed.listen(function(_data)
		Manager.CloseRevive()
	end)

	State.sweeper:Add(function()
		GamePackets.profileSnapshot.disconnect(snapshotListener)
		GamePackets.toast.disconnect(toastListener)
		GamePackets.dailyState.disconnect(dailyStateListener)
		GamePackets.groupChestState.disconnect(groupChestStateListener)
		GamePackets.reviveOffer.disconnect(reviveOfferListener)
		GamePackets.reviveClosed.disconnect(reviveClosedListener)
		GamePackets.boostState.disconnect(boostStateListener)
		GamePackets.boostCelebration.disconnect(boostCelebrationListener)
		GamePackets.purchaseCelebration.disconnect(purchaseCelebrationListener)
		GamePackets.eventState.disconnect(eventStateListener)
		GamePackets.rouletteState.disconnect(rouletteStateListener)
		GamePackets.spinResult.disconnect(spinResultListener)
	end)
	task.spawn(function()
		while localPlayer.Parent == Players do
			GamePackets.requestSnapshot.send({})
			task.wait(1.5)
		end
	end)
end

return HUDController
