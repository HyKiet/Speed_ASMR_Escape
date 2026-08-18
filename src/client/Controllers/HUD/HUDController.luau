--!strict
-- HUD orchestrator: dựng ScreenGui, subscribe GamePackets, vòng lặp treadmill animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local GroupChestConfig = require(ReplicatedStorage.Shared.Config.GroupChest)
local Responsive = require(script.Parent.Responsive)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local LevelUp = require(script.Parent.LevelUp)
local BoostCelebration = require(script.Parent.BoostCelebration)
local WinsFlight = require(script.Parent.WinsFlight)
local Manager = require(script.Parent.Modals.Manager)
local LeftMenu = require(script.Parent.Hud.LeftMenu)
local RightPanel = require(script.Parent.Hud.RightPanel)
local BottomHud = require(script.Parent.Hud.BottomHud)
local BoostHud = require(script.Parent.Hud.BoostHud)
local StarterPackCard = require(script.Parent.Hud.StarterPackCard)
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
local SettingsModal = require(script.Parent.Modals.SettingsModal)
local StarterPackModal = require(script.Parent.Modals.StarterPackModal)

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
				--[[
					Khung bản vẽ 1920×1080 neo TÂM màn hình, co bằng `UIScale`.

					Cụm HUD nào bám mép màn hình sẽ nhận toạ độ NẰM NGOÀI khung này (số âm, hoặc lớn
					hơn 1920) — bình thường và đúng ý: khung không `ClipsDescendants` nên con vẫn vẽ
					ra ngoài, và mép màn hình thật là thứ chúng cần bám (xem `Responsive.Screen`).
				]]
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
					StarterPackCard.Build(),
					FriendsHud.Build(),
					RebirthModal.Build(),
					ShopModal.Build(),
					CosmeticModal.Build(),
					TeleportModal.Build(),
					CodeModal.Build(),
					DailyModal.Build(),
					GroupChestModal.Build(),
					RouletteModal.Build(),
					SettingsModal.Build(),
					StarterPackModal.Build(),
					BoostCelebration.Build(),
					WinsFlight.Build(),
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
	--[[
		⚠️ THỨ TỰ: tính tỉ lệ TRƯỚC khi dựng GUI.

		Mọi `Computed` vị trí chạy ngay lúc dựng; chạy lúc `viewportScale` còn là giá trị mặc
		định 1 thì cả HUD chốt bố cục của màn hình PC rồi mới nhảy về đúng chỗ ở frame sau —
		trên điện thoại nhìn ra rất rõ thành một cú giật lúc vào game.

		Bốn tín hiệu làm tỉ lệ đổi (viewport, camera bị thay, topbar nạp muộn, xoay máy) đều do
		`Responsive.Connect` lo — xem khối lý do ở đó.
	]]
	Responsive.Connect()
	buildGui()
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
		-- Nhận Wins ở bệ cuối zone có màn ăn mừng riêng (thẻ giữa màn hình bay về huy hiệu
		-- Wins). KHÔNG hiện thêm toast: hai thông báo cùng một sự kiện chỉ làm loãng, mà
		-- thẻ đã ghi rõ con số to hơn nhiều.
		if data.kind == "wins_collected" then
			WinsFlight.Trigger(data.amount)
			return
		end
		--[[
			Group Chest: cũng là "vừa nhận được quà" nên dùng ĐÚNG màn ăn mừng của Wins thay
			vì một dòng toast trôi qua trong 2 giây (user 2026-08-10). Chỉ lần NHẬN THẬT mới
			có `amount > 0`; các toast từ chối ("Join the group first!") vẫn đi đường toast.
		]]
		if data.kind == "groupChest" then
			if data.amount > 0 then
				WinsFlight.TriggerReward({
					icons = { Theme.UI_ASSETS.Shoe, Theme.UI_ASSETS.Trophy },
					headline = `+{Theme.FormatInteger(data.amount)} Speed`,
					-- Wins trao ngay + buff vĩnh viễn: cả hai đều là thứ vừa nhận, thẻ phải kể
					-- đủ. Số lấy từ config nên không lệch với thẻ trong modal.
					detail = `+{GroupChestConfig.INSTANT_WINS_REWARD} Wins  •  +{math.floor(
						(GroupChestConfig.WINS_MULTIPLIER - 1) * 100 + 0.5
					)}% Wins forever`,
					caption = "GROUP CHEST!",
					accent = Color3.fromRGB(120, 255, 170),
					toWinsBadge = false, -- món to nhất là Speed ⇒ bay về dòng Speed dưới đáy
				})
			else
				Toast.Show(data.message, data.kind)
			end
			return
		end
		Toast.Show(
			if data.amount > 0 then `+{Theme.FormatInteger(data.amount)} {data.message}` else data.message,
			data.kind
		)
	end)

	--[[
		Ăn mừng Daily: server KHÔNG gửi gói tin riêng lúc claim, nhưng `dailyState` sau claim
		luôn có `canClaim` lật true → false. Bắt đúng cú lật đó là biết vừa nhận thưởng, khỏi
		phải đổi schema packet.

		Ngày vừa nhận = `streakDay` MỚI (server ghi `DailyStreakDay = nextDay` trước khi gửi),
		và danh sách quà lấy thẳng từ `DailyModal` nên thẻ chúc mừng không bao giờ lệch với
		bảng 7 ngày người chơi vừa nhìn.

		Lúc mới vào game gói đầu tiên thường là canClaim=false; `wasClaimable` khởi tạo false
		nên không có màn ăn mừng ma nào bật ra.
	]]
	local wasClaimable = false
	local dailyStateListener = GamePackets.dailyState.listen(function(data)
		local justClaimed = wasClaimable and not data.canClaim
		wasClaimable = data.canClaim

		State.dailyStreakDay:set(data.streakDay)
		State.dailyCanClaim:set(data.canClaim)
		State.dailyNextDay:set(data.nextDay)

		if not justClaimed then
			return
		end

		local parts = DailyModal.GetRewardParts(data.streakDay)
		if not parts or #parts == 0 then
			return
		end

		local icons, labels, hasWins = {}, {}, false
		for _, part in parts do
			table.insert(icons, part.icon)
			table.insert(labels, part.label)
			if string.find(part.label, "Wins") then
				hasWins = true
			end
		end

		WinsFlight.TriggerReward({
			icons = icons,
			-- Món ĐẦU tiên là món chính (bảng quà đã xếp theo thứ tự đó), phần còn lại xuống
			-- dòng nhỏ — nhồi cả ba vào một dòng to thì chữ co lại còn bằng dòng phụ.
			headline = labels[1],
			detail = if #labels > 1 then table.concat(labels, "  •  ", 2, #labels) else "",
			caption = `DAILY REWARD — DAY {data.streakDay}`,
			accent = Color3.fromRGB(255, 168, 236),
			toWinsBadge = hasWins,
		})
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

	-- Starter Pack: server gửi SỐ GIÂY CÒN LẠI, client quy ra mốc `os.clock()` cục bộ rồi tự
	-- đếm lùi (cùng cách với boost chips).
	local starterPackListener = GamePackets.starterPackState.listen(function(data)
		State.starterPackDeadline:set(os.clock() + data.secondsLeft)
		State.starterPackBought:set(data.bought)
		State.starterPackConfigured:set(data.configured)
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
		GamePackets.starterPackState.disconnect(starterPackListener)
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
