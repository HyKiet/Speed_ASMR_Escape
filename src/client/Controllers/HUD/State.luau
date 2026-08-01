--!strict
-- Trạng thái dùng chung cho toàn HUD và các Modal (Fusion Values + Tweens).
-- Mọi module HUD đều require State để truy cập/ghi cùng một bộ state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Tween = Fusion.Tween
local Value = Fusion.Value

export type Snapshot = {
	isLoaded: boolean,
	speed: number,
	totalWins: number,
	currentRunWins: number,
	streak: number,
	personalBestDistance: number,
	personalBestRunWins: number,
	totalRuns: number,
	highestCompletedStage: number,
	level: number,
	xp: number,
	requiredXP: number,
	rebirths: number,
	maxWalkSpeed: number,
	customSpeedLimit: number,
	gainMultiplier: number,
	treadmillMultiplier: number,
	speedPassMultiplier: number,
	vipMultiplier: number,
	premiumMultiplier: number,
	trailMultiplier: number,
	auraMultiplier: number,
	cosmeticMultiplier: number,
	rebirthMultiplier: number,
	playtimeMultiplier: number,
	friendsMultiplier: number,
	serverMultiplier: number,
	liveOpsMultiplier: number,
	friendsInServer: number,
	isOnTreadmill: boolean,
	canRebirth: boolean,
	requiredRebirthLevel: number,
	ownsAutoRebirth: boolean,
	autoRebirthEnabled: boolean,
	activeTreadmillId: string,
	equippedTrail: string,
	equippedAura: string,
	unlockedTrails: { [string]: boolean },
	unlockedAuras: { [string]: boolean },
}

export type TeleportDestinationConfig = Constants.TeleportDestinationConfig

export type ShopPurchaseKind = "gamepass" | "product"

export type ShopItemConfig = {
	id: string,
	title: string,
	subtitle: string,
	valueText: string,
	priceRobux: number,
	purchaseKind: ShopPurchaseKind,
	purchaseId: number,
	accentColor: Color3,
	icon: string,
	sortOrder: number,
}

export type ShopCatalog = { [string]: { ShopItemConfig } }

local DEFAULT_SNAPSHOT: Snapshot = {
	isLoaded = false,
	speed = 0,
	totalWins = 0,
	currentRunWins = 0,
	streak = 0,
	personalBestDistance = 0,
	personalBestRunWins = 0,
	totalRuns = 0,
	highestCompletedStage = 0,
	level = 1,
	xp = 0,
	requiredXP = Constants.GetRequiredXP(1),
	rebirths = 0,
	maxWalkSpeed = Constants.GetMaxWalkSpeed(1),
	customSpeedLimit = Constants.GetMaxWalkSpeed(1),
	gainMultiplier = 1,
	treadmillMultiplier = 1,
	speedPassMultiplier = 1,
	vipMultiplier = 1,
	premiumMultiplier = 1,
	trailMultiplier = 1,
	auraMultiplier = 1,
	cosmeticMultiplier = 1,
	rebirthMultiplier = 1,
	playtimeMultiplier = 1,
	friendsMultiplier = 1,
	serverMultiplier = 1,
	liveOpsMultiplier = 1,
	friendsInServer = 0,
	isOnTreadmill = false,
	canRebirth = false,
	requiredRebirthLevel = Constants.GetRequiredLevelForRebirth(0),
	ownsAutoRebirth = false,
	autoRebirthEnabled = true,
	activeTreadmillId = "treadmill_1",
	equippedTrail = "none",
	equippedAura = "none",
	unlockedTrails = { none = true },
	unlockedAuras = { none = true },
}

local State = {}

State.DEFAULT_SNAPSHOT = DEFAULT_SNAPSHOT

-- Snapshot + viewport
State.snapshot = Value(DEFAULT_SNAPSHOT)
State.viewportScale = Value(1)
State.viewportSize = Value(Vector2.new(1920, 1080))

-- Toast + LevelUp
State.toastText = Value("")
State.levelUpText = Value("")

-- Custom speed input
State.customSpeedDraft = Value(tostring(Constants.GetMaxWalkSpeed(1)))
State.isEditingCustomSpeed = false

-- Playtime Boost
State.sessionPlaytime = Value(0)

-- Rebirth modal
State.rebirthModalVisible = Value(false)
State.rebirthModalMounted = Value(false)
State.rebirthModalAnimationGoal = Value(0)
State.rebirthModalAnimation = Tween(State.rebirthModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.rebirthCloseHovered = Value(false)
State.rebirthConfirmHovered = Value(false)
State.rebirthSkipHovered = Value(false)
State.rebirthAutoHovered = Value(false)

-- Cosmetic modal
State.cosmeticModalVisible = Value(false)
State.cosmeticModalMounted = Value(false)
State.cosmeticModalAnimationGoal = Value(0)
State.cosmeticModalAnimation = Tween(State.cosmeticModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.cosmeticCategory = Value("trail")
State.cosmeticCloseHovered = Value(false)

-- Teleport modal
State.teleportModalVisible = Value(false)
State.teleportModalMounted = Value(false)
State.teleportModalAnimationGoal = Value(0)
State.teleportModalAnimation = Tween(State.teleportModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.teleportCloseHovered = Value(false)

-- Revive modal
State.reviveModalVisible = Value(false)
State.reviveModalMounted = Value(false)
State.reviveModalAnimationGoal = Value(0)
State.reviveModalAnimation = Tween(State.reviveModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.reviveStage = Value(0)
State.reviveCountdown = Value(0)
State.reviveRobuxProductId = Value(0)
State.reviveRobuxPrice = Value(0)
State.reviveAdRewardProductId = Value(0)
-- Gamepass Infinite Revives: hồi sinh miễn phí, không giới hạn số lần.
State.reviveFree = Value(false)
State.reviveAdAvailable = Value(false)
State.reviveCloseHovered = Value(false)
State.reviveRobuxHovered = Value(false)
State.reviveAdHovered = Value(false)
State.reviveCountdownToken = 0

-- Shop modal
State.shopModalVisible = Value(false)
State.shopModalMounted = Value(false)
State.shopModalAnimationGoal = Value(0)
State.shopModalAnimation = Tween(State.shopModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.shopCloseHovered = Value(false)

-- Daily login modal
State.dailyModalVisible = Value(false)
State.dailyModalMounted = Value(false)
State.dailyModalAnimationGoal = Value(0)
State.dailyModalAnimation = Tween(State.dailyModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.dailyCloseHovered = Value(false)
State.dailyClaimHovered = Value(false)
State.dailyStreakDay = Value(0)
State.dailyCanClaim = Value(false)
State.dailyNextDay = Value(1)

-- Group Chest modal
State.groupChestModalVisible = Value(false)
State.groupChestModalMounted = Value(false)
State.groupChestModalAnimationGoal = Value(0)
State.groupChestModalAnimation = Tween(State.groupChestModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.groupChestCloseHovered = Value(false)
State.groupChestJoinHovered = Value(false)
State.groupChestLikeHovered = Value(false)
State.groupChestClaimHovered = Value(false)
State.groupChestIsGroupMember = Value(false)
State.groupChestHasConfirmedLike = Value(false)
State.groupChestHasClaimed = Value(false)

-- Code modal
State.codeModalVisible = Value(false)

State.codeModalMounted = Value(false)
State.codeModalAnimationGoal = Value(0)
State.codeModalAnimation = Tween(State.codeModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.codeCloseHovered = Value(false)
State.codeRedeemHovered = Value(false)
State.codeInput = Value("")
State.isEnteringCode = false

-- Roulette modal
State.rouletteModalVisible = Value(false)
State.rouletteModalMounted = Value(false)
State.rouletteModalAnimationGoal = Value(0)
State.rouletteModalAnimation = Tween(State.rouletteModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
State.rouletteCloseHovered = Value(false)
State.rouletteSpinHovered = Value(false)
State.rouletteTickets = Value(0)
State.rouletteNextFreeSeconds = Value(-1) -- -1 = đầy cap (không đếm)
State.rouletteNextFreeReceivedAt = Value(0) -- os.clock() lúc nhận state (đếm ngược cục bộ)
State.rouletteSpinning = Value(false)
State.rouletteResultText = Value("")

-- Server/Personal Boosts (deadline theo os.clock; client tự đếm ngược)
State.boostServerSpeedUntil = Value(0)
State.boostServerWinsUntil = Value(0)
State.boostPersonalSpeedUntil = Value(0)
State.boostPersonalWinsUntil = Value(0)
State.boostClockNow = Value(0) -- cập nhật ~4 lần/giây trong HUDController

-- Event thời vụ (RemoteConfigService đẩy xuống qua packet eventState).
-- eventName = "" ⇒ không có event ⇒ HUD ẩn dòng Event.
State.eventName = Value("")
State.eventSpeedMultiplier = Value(1)
State.eventWinsMultiplier = Value(1)

-- Janitor cho HUD
State.sweeper = Janitor.new()

State.lastSpeed = 0

function State.GetSnapshot(): Snapshot
	return State.snapshot:get()
end

function State.SyncCustomSpeedDraft(speed: number)
	State.customSpeedDraft:set(tostring(math.floor(speed)))
end

return State
