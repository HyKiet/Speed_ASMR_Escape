--!strict
-- Quản lý đóng/mở 5 modal: đóng các modal khác khi mở 1 modal mới.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local State = require(script.Parent.Parent.State)

local Manager = {}

local function hideAll(except: string?)
	if except ~= "rebirth" then
		State.rebirthModalMounted:set(false)
		State.rebirthModalVisible:set(false)
		State.rebirthModalAnimationGoal:set(0)
	end
	if except ~= "cosmetic" then
		State.cosmeticModalMounted:set(false)
		State.cosmeticModalVisible:set(false)
		State.cosmeticModalAnimationGoal:set(0)
	end
	if except ~= "teleport" then
		State.teleportModalMounted:set(false)
		State.teleportModalVisible:set(false)
		State.teleportModalAnimationGoal:set(0)
	end
	if except ~= "shop" then
		State.shopModalMounted:set(false)
		State.shopModalVisible:set(false)
		State.shopModalAnimationGoal:set(0)
	end
	if except ~= "revive" then
		State.reviveModalMounted:set(false)
		State.reviveModalVisible:set(false)
		State.reviveModalAnimationGoal:set(0)
	end
	if except ~= "code" then
		State.codeModalMounted:set(false)
		State.codeModalVisible:set(false)
		State.codeModalAnimationGoal:set(0)
	end
	if except ~= "daily" then
		State.dailyModalMounted:set(false)
		State.dailyModalVisible:set(false)
		State.dailyModalAnimationGoal:set(0)
	end
	if except ~= "roulette" then
		State.rouletteModalMounted:set(false)
		State.rouletteModalVisible:set(false)
		State.rouletteModalAnimationGoal:set(0)
	end
	if except ~= "groupChest" then
		State.groupChestModalMounted:set(false)
		State.groupChestModalVisible:set(false)
		State.groupChestModalAnimationGoal:set(0)
	end
end

-- Feedback KHÔNG còn là modal của game: xem `CoreLoop/FeedbackPromptController`
-- (hộp thoại gốc của Roblox, đổ về Creator Dashboard).

function Manager.OpenRebirth()
	hideAll("rebirth")
	State.rebirthModalMounted:set(true)
	State.rebirthModalVisible:set(true)
	State.rebirthModalAnimationGoal:set(1)
end

function Manager.CloseRebirth()
	State.rebirthModalVisible:set(false)
	State.rebirthModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not State.rebirthModalVisible:get() then
			State.rebirthModalMounted:set(false)
		end
	end)
end

function Manager.ToggleRebirth()
	if State.rebirthModalVisible:get() then
		Manager.CloseRebirth()
	else
		Manager.OpenRebirth()
	end
end

function Manager.OpenCosmetic(category: string)
	hideAll("cosmetic")
	State.cosmeticCategory:set(category)
	State.cosmeticModalMounted:set(true)
	State.cosmeticModalVisible:set(true)
	State.cosmeticModalAnimationGoal:set(1)
end

function Manager.CloseCosmetic()
	State.cosmeticModalVisible:set(false)
	State.cosmeticModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not State.cosmeticModalVisible:get() then
			State.cosmeticModalMounted:set(false)
		end
	end)
end

function Manager.ToggleCosmetic(category: string)
	if State.cosmeticModalVisible:get() then
		Manager.CloseCosmetic()
	else
		Manager.OpenCosmetic(category)
	end
end

function Manager.OpenTeleport()
	hideAll("teleport")
	State.teleportModalMounted:set(true)
	State.teleportModalVisible:set(true)
	State.teleportModalAnimationGoal:set(1)
end

function Manager.CloseTeleport()
	State.teleportModalVisible:set(false)
	State.teleportModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not State.teleportModalVisible:get() then
			State.teleportModalMounted:set(false)
		end
	end)
end

function Manager.ToggleTeleport()
	if State.teleportModalVisible:get() then
		Manager.CloseTeleport()
	else
		Manager.OpenTeleport()
	end
end

function Manager.OpenShop()
	hideAll("shop")
	State.shopModalMounted:set(true)
	State.shopModalVisible:set(true)
	State.shopModalAnimationGoal:set(1)
end

function Manager.CloseShop()
	State.shopModalVisible:set(false)
	State.shopModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not State.shopModalVisible:get() then
			State.shopModalMounted:set(false)
		end
	end)
end

function Manager.ToggleShop()
	if State.shopModalVisible:get() then
		Manager.CloseShop()
	else
		Manager.OpenShop()
	end
end

function Manager.OpenCode()
	hideAll("code")
	State.codeModalMounted:set(true)
	State.codeModalVisible:set(true)
	State.codeModalAnimationGoal:set(1)
end

function Manager.CloseCode()
	State.codeModalVisible:set(false)
	State.codeModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not State.codeModalVisible:get() then
			State.codeModalMounted:set(false)
		end
	end)
end

function Manager.ToggleCode()
	if State.codeModalVisible:get() then
		Manager.CloseCode()
	else
		Manager.OpenCode()
	end
end

function Manager.OpenDaily()
	hideAll("daily")
	State.dailyModalMounted:set(true)
	State.dailyModalVisible:set(true)
	State.dailyModalAnimationGoal:set(1)
end

function Manager.CloseDaily()
	State.dailyModalVisible:set(false)
	State.dailyModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not State.dailyModalVisible:get() then
			State.dailyModalMounted:set(false)
		end
	end)
end

function Manager.ToggleDaily()
	if State.dailyModalVisible:get() then
		Manager.CloseDaily()
	else
		Manager.OpenDaily()
	end
end

function Manager.OpenRoulette()
	hideAll("roulette")
	GamePackets.requestRouletteState.send({})
	State.rouletteModalMounted:set(true)
	State.rouletteModalVisible:set(true)
	State.rouletteModalAnimationGoal:set(1)
end

function Manager.CloseRoulette()
	State.rouletteModalVisible:set(false)
	State.rouletteModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not State.rouletteModalVisible:get() then
			State.rouletteModalMounted:set(false)
		end
	end)
end

function Manager.ToggleRoulette()
	if State.rouletteModalVisible:get() then
		Manager.CloseRoulette()
	else
		Manager.OpenRoulette()
	end
end

function Manager.OpenGroupChest()
	hideAll("groupChest")
	State.groupChestModalMounted:set(true)
	State.groupChestModalVisible:set(true)
	State.groupChestModalAnimationGoal:set(1)
end

function Manager.CloseGroupChest()
	State.groupChestModalVisible:set(false)
	State.groupChestModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not State.groupChestModalVisible:get() then
			State.groupChestModalMounted:set(false)
		end
	end)
end

function Manager.CloseRevive(reason: string?)
	State.reviveModalVisible:set(false)
	State.reviveModalAnimationGoal:set(0)
	State.reviveCountdownToken += 1
	if reason == "declined" then
		GamePackets.requestRevive.send({
			method = "decline",
		})
	end
	task.delay(0.22, function()
		if not State.reviveModalVisible:get() then
			State.reviveModalMounted:set(false)
		end
	end)
end

function Manager.OpenRevive(
	stage: number,
	durationSeconds: number,
	robuxProductId: number,
	robuxPrice: number,
	adRewardProductId: number,
	freeRevive: boolean?
)
	hideAll("revive")

	State.reviveStage:set(stage)
	State.reviveCountdown:set(durationSeconds)
	State.reviveRobuxProductId:set(robuxProductId)
	State.reviveRobuxPrice:set(robuxPrice)
	State.reviveAdRewardProductId:set(adRewardProductId)
	State.reviveFree:set(freeRevive == true)
	State.reviveModalMounted:set(true)
	State.reviveModalVisible:set(true)
	State.reviveModalAnimationGoal:set(1)

	State.reviveCountdownToken += 1
	local token = State.reviveCountdownToken
	task.spawn(function()
		local remaining = durationSeconds
		while token == State.reviveCountdownToken and remaining > 0 and State.reviveModalVisible:get() do
			task.wait(1)
			remaining -= 1
			State.reviveCountdown:set(math.max(0, remaining))
		end
		if token == State.reviveCountdownToken and State.reviveModalVisible:get() then
			Manager.CloseRevive()
		end
	end)
end

return Manager
