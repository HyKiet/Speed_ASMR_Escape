--!strict
local Players = game:GetService("Players")
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Sweeper = require(ReplicatedStorage.Packages.Janitor)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnChange = Fusion.OnChange
local OnEvent = Fusion.OnEvent
local Tween = Fusion.Tween
local Value = Fusion.Value

type Snapshot = {
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
	isOnTreadmill: boolean,
	canRebirth: boolean,
	requiredRebirthLevel: number,
	activeTreadmillId: string,
	equippedTrail: string,
	equippedAura: string,
	unlockedTrails: { [string]: boolean },
	unlockedAuras: { [string]: boolean },
}

type TeleportDestinationConfig = {
	id: string,
	name: string,
	description: string,
	targetPath: string,
	accentColor: Color3,
	sortOrder: number,
	priceWins: number,
	priceRobux: number,
	productId: number,
}

type ShopPurchaseKind = "gamepass" | "product"

type ShopItemConfig = {
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

type ShopCatalog = { [string]: { ShopItemConfig } }

local DESIGN_WIDTH = 1920
local DESIGN_HEIGHT = 1080
local MIN_SCALE = 0.12
local MAX_SCALE = 1
local TOAST_Z_INDEX = 220

local UI_ASSETS = {
	Trophy = "rbxassetid://106462244220051",
	Lightning = "rbxassetid://94953097483502",
	Rebirth = "rbxassetid://103236589125008",
	Shop = "rbxassetid://80843877229491",
	Shoe = "rbxassetid://93408043939834",
	Cosmetics = "rbxassetid://100080362113682",
	Trail = "rbxassetid://115065552017670",
	Teleport = "rbxassetid://112885468301298",
	Aura = "rbxassetid://82712548408854",
	Robux = "rbxasset://textures/ui/common/robux.png",
	Sunburst = "rbxassetid://87577740080014",
	Studs = "rbxassetid://6372755229",
	LevelUpSound = "rbxassetid://9086154674",
}

local SHOP_TABS = {
	{
		id = "utility",
		label = "UTILITY GAMEPASS & VIP MEMBERSHIP",
		colorA = Color3.fromRGB(255, 205, 70),
		colorB = Color3.fromRGB(240, 92, 62),
	},
	{
		id = "products",
		label = "INSTANT WINS PACKS (DEVELOPER PRODUCTS)",
		colorA = Color3.fromRGB(75, 221, 255),
		colorB = Color3.fromRGB(34, 113, 230),
	},
	{
		id = "treadmills",
		label = "TREADMILL GAMEPASS",
		colorA = Color3.fromRGB(104, 234, 95),
		colorB = Color3.fromRGB(40, 143, 69),
	},
}

local SHOP_CATALOG: ShopCatalog = {
	utility = {
		{
			id = "vip_membership",
			title = "VIP Membership",
			subtitle = "[VIP] tag + VIP Trail + VIP Aura",
			valueText = "x1.5 Speed + x1.2 Wins",
			priceRobux = 399,
			purchaseKind = "gamepass",
			purchaseId = 0,
			accentColor = Color3.fromRGB(255, 204, 61),
			icon = UI_ASSETS.Trophy,
			sortOrder = 1,
		},
		{
			id = "auto_rebirth",
			title = "Auto-Rebirth",
			subtitle = "Auto rebirth at required level",
			valueText = "AFK rebirth helper",
			priceRobux = 99,
			purchaseKind = "gamepass",
			purchaseId = 0,
			accentColor = Color3.fromRGB(255, 112, 89),
			icon = UI_ASSETS.Rebirth,
			sortOrder = 2,
		},
	},
	products = {
		{
			id = "wins_small",
			title = "Small Wins Pack",
			subtitle = "Open early pads faster",
			valueText = "+1,000 Wins",
			priceRobux = 49,
			purchaseKind = "product",
			purchaseId = 0,
			accentColor = Color3.fromRGB(85, 205, 255),
			icon = UI_ASSETS.Trophy,
			sortOrder = 1,
		},
		{
			id = "wins_medium",
			title = "Medium Wins Pack",
			subtitle = "Fast Pad 5-6 progress",
			valueText = "+10,000 Wins",
			priceRobux = 149,
			purchaseKind = "product",
			purchaseId = 0,
			accentColor = Color3.fromRGB(84, 176, 255),
			icon = UI_ASSETS.Trophy,
			sortOrder = 2,
		},
		{
			id = "wins_large",
			title = "Large Wins Pack",
			subtitle = "Jump into late-game pads",
			valueText = "+100,000 Wins",
			priceRobux = 399,
			purchaseKind = "product",
			purchaseId = 0,
			accentColor = Color3.fromRGB(145, 103, 255),
			icon = UI_ASSETS.Trophy,
			sortOrder = 3,
		},
		{
			id = "wins_ultra",
			title = "Ultra Wins Pack",
			subtitle = "Whale instant economy push",
			valueText = "+1,000,000 Wins",
			priceRobux = 999,
			purchaseKind = "product",
			purchaseId = 0,
			accentColor = Color3.fromRGB(255, 91, 172),
			icon = UI_ASSETS.Trophy,
			sortOrder = 4,
		},
	},
	treadmills = {
		{
			id = "treadmill_2",
			title = "Gold Treadmill",
			subtitle = "Permanent treadmill unlock",
			valueText = "x3 Speed",
			priceRobux = 99,
			purchaseKind = "gamepass",
			purchaseId = 0,
			accentColor = Color3.fromRGB(255, 215, 71),
			icon = UI_ASSETS.Lightning,
			sortOrder = 1,
		},
		{
			id = "treadmill_3",
			title = "Green Treadmill",
			subtitle = "Permanent treadmill unlock",
			valueText = "x9 Speed",
			priceRobux = 249,
			purchaseKind = "gamepass",
			purchaseId = 0,
			accentColor = Color3.fromRGB(91, 220, 117),
			icon = UI_ASSETS.Lightning,
			sortOrder = 2,
		},
		{
			id = "treadmill_4",
			title = "Pink Treadmill",
			subtitle = "Permanent treadmill unlock",
			valueText = "x25 Speed",
			priceRobux = 499,
			purchaseKind = "gamepass",
			purchaseId = 0,
			accentColor = Color3.fromRGB(255, 116, 196),
			icon = UI_ASSETS.Lightning,
			sortOrder = 3,
		},
		{
			id = "treadmill_5",
			title = "Red Admin Treadmill",
			subtitle = "Top whale treadmill",
			valueText = "x100 Speed",
			priceRobux = 999,
			purchaseKind = "gamepass",
			purchaseId = 0,
			accentColor = Color3.fromRGB(255, 79, 73),
			icon = UI_ASSETS.Lightning,
			sortOrder = 4,
		},
	},
}

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
	maxWalkSpeed = Constants.DEFAULT_WALK_SPEED,
	customSpeedLimit = Constants.DEFAULT_WALK_SPEED,
	gainMultiplier = 1,
	treadmillMultiplier = 1,
	isOnTreadmill = false,
	canRebirth = false,
	requiredRebirthLevel = Constants.GetRequiredLevelForRebirth(0),
	activeTreadmillId = "treadmill_1",
	equippedTrail = "none",
	equippedAura = "none",
	unlockedTrails = { none = true },
	unlockedAuras = { none = true },
}

local player = Players.LocalPlayer
local snapshot = Value(DEFAULT_SNAPSHOT)
local viewportScale = Value(1)
local viewportSize = Value(Vector2.new(DESIGN_WIDTH, DESIGN_HEIGHT))
local toastText = Value("")
local customSpeedDraft = Value(tostring(Constants.DEFAULT_WALK_SPEED))
local levelUpText = Value("")
local rebirthModalVisible = Value(false)
local rebirthModalMounted = Value(false)
local rebirthModalAnimationGoal = Value(0)
local rebirthModalAnimation = Tween(rebirthModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
local rebirthCloseHovered = Value(false)
local rebirthConfirmHovered = Value(false)
local rebirthSkipHovered = Value(false)
local cosmeticModalVisible = Value(false)
local cosmeticModalMounted = Value(false)
local cosmeticModalAnimationGoal = Value(0)
local cosmeticModalAnimation = Tween(cosmeticModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
local cosmeticCategory = Value("trail")
local cosmeticCloseHovered = Value(false)
local teleportModalVisible = Value(false)
local teleportModalMounted = Value(false)
local teleportModalAnimationGoal = Value(0)
local teleportModalAnimation = Tween(teleportModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
local teleportCloseHovered = Value(false)
local reviveModalVisible = Value(false)
local reviveModalMounted = Value(false)
local reviveModalAnimationGoal = Value(0)
local reviveModalAnimation = Tween(reviveModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
local reviveStage = Value(0)
local reviveCountdown = Value(0)
local reviveRobuxProductId = Value(0)
local reviveRobuxPrice = Value(0)
local reviveAdRewardProductId = Value(0)
local reviveAdAvailable = Value(false)
local reviveCloseHovered = Value(false)
local reviveRobuxHovered = Value(false)
local reviveAdHovered = Value(false)
local shopModalVisible = Value(false)
local shopModalMounted = Value(false)
local shopModalAnimationGoal = Value(0)
local shopModalAnimation = Tween(shopModalAnimationGoal, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
local shopCloseHovered = Value(false)

local sweeper = Sweeper.new()
local lastSpeed = 0
local treadmillRunTrack: AnimationTrack? = nil
local treadmillRunCharacter: Model? = nil
local isEditingCustomSpeed = false

local CoreLoopHUDController = {}

local function getSnapshot(): Snapshot
	return snapshot:get()
end

local function formatInteger(value: number): string
	return Constants.FormatNumber(math.max(0, value))
end

local function makeCorner(radius: number)
	return New("UICorner")({
		CornerRadius = UDim.new(0, radius),
	})
end

local function makeStroke(color: Color3, thickness: number, transparency: number?)
	return New("UIStroke")({
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
	})
end

local function makeGradient(colorA: Color3, colorB: Color3, rotation: number?)
	return New("UIGradient")({
		Color = ColorSequence.new(colorA, colorB),
		Rotation = rotation or 90,
	})
end

local function makeStudsPattern(transparency: number?, zIndex: number?)
	return New("ImageLabel")({
		BackgroundTransparency = 1,
		Image = UI_ASSETS.Studs,
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		ImageTransparency = transparency or 0.76,
		Position = UDim2.fromScale(0, 0),
		ScaleType = Enum.ScaleType.Tile,
		Size = UDim2.fromScale(1, 1),
		TileSize = UDim2.fromOffset(30, 30),
		ZIndex = zIndex or 11,
	})
end

local function makeSunburst()
	local sunburst = New("ImageLabel")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = UI_ASSETS.Sunburst,
		ImageTransparency = 0.08,
		Position = UDim2.fromOffset(49, 51),
		Size = UDim2.fromOffset(148, 148),
		ZIndex = 2,
	})
	local tween = TweenService:Create(
		sunburst,
		TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 }
	)
	tween:Play()
	sweeper:Add(function()
		tween:Cancel()
	end)

	return sunburst
end

local function makeOutlineLabel(props: { [string]: any })
	local maxTextSize = props.MaxTextSize or 48
	local minTextSize = props.MinTextSize or 10

	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
	}

	for key, value in props do
		if key ~= "MaxTextSize" and key ~= "MinTextSize" then
			defaults[key] = value
		end
	end

	if not defaults[Children] then
		defaults[Children] = {
			New("UITextSizeConstraint")({
				MaxTextSize = maxTextSize,
				MinTextSize = minTextSize,
			}),
		}
	end

	return New("TextLabel")(defaults)
end

local function makeButton(
	label,
	colorA: Color3,
	colorB: Color3,
	activated: (() -> ())?
)
	return New("TextButton")({
		AutoButtonColor = true,
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = 12,
		[OnEvent("Activated")] = function()
			if activated then
				activated()
			end
		end,
		[Children] = {
			makeCorner(16),
			makeStroke(Color3.fromRGB(0, 0, 0), 5),
			makeGradient(colorA, colorB),
			makeStudsPattern(0.72, 13),
			makeOutlineLabel({
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				Text = label,
				MaxTextSize = 34,
				MinTextSize = 10,
				ZIndex = 14,
			}),
		},
	})
end

local function makeMenuButton(label: string, icon: string, colorA: Color3, colorB: Color3, action: (() -> ())?)
	return New("Frame")({
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(126, 126),
		[Children] = {
			makeButton("", colorA, colorB, action),
			New("ImageLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromScale(0.5, 0.42),
				Size = UDim2.fromOffset(88, 88),
				ZIndex = 14,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(4, 84),
				Size = UDim2.fromOffset(118, 34),
				Text = label,
				MaxTextSize = 28,
				ZIndex = 15,
			}),
			New("UIPadding")({
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 4),
			}),
		},
	})
end

local function showLevelUpCelebration(level: number, levelsGained: number)
	local suffix = if levelsGained > 1 then ` +{levelsGained} LEVELS` else ""
	levelUpText:set(`LEVEL UP! LEVEL {level}{suffix}`)

	local sound = Instance.new("Sound")
	sound.SoundId = UI_ASSETS.LevelUpSound
	sound.Volume = 0.65
	sound.Parent = player:WaitForChild("PlayerGui")
	sound:Play()

	task.delay(1.8, function()
		sound:Destroy()
	end)
	task.delay(2.4, function()
		if levelUpText:get() == `LEVEL UP! LEVEL {level}{suffix}` then
			levelUpText:set("")
		end
	end)
end

local function showToast(text: string)
	toastText:set(text)
	task.delay(2.5, function()
		if toastText:get() == text then
			toastText:set("")
		end
	end)
end

local function sendCustomSpeed(speed: number)
	GamePackets.requestCustomSpeed.send({
		walkSpeed = speed,
	})
end

local function syncCustomSpeedDraft(speed: number)
	customSpeedDraft:set(tostring(math.floor(speed)))
end

local function submitCustomSpeed()
	local requestedSpeed = tonumber(customSpeedDraft:get())
	if not requestedSpeed then
		syncCustomSpeedDraft(getSnapshot().customSpeedLimit)
		showToast("Enter a valid speed")
		return
	end

	local clampedSpeed = math.clamp(
		math.floor(requestedSpeed),
		Constants.DEFAULT_WALK_SPEED,
		getSnapshot().maxWalkSpeed
	)
	syncCustomSpeedDraft(clampedSpeed)
	sendCustomSpeed(clampedSpeed)
end

local function requestTeleportWithWins(destination: TeleportDestinationConfig): boolean
	if getSnapshot().totalWins < destination.priceWins then
		showToast("Not enough Wins")
		return false
	end

	GamePackets.requestTeleport.send({
		destinationId = destination.id,
		paymentKind = "wins",
	})
	return true
end

local function promptTeleportWithRobux(destination: TeleportDestinationConfig): boolean
	if destination.productId <= 0 then
		showToast("Set teleport product id before purchase")
		return false
	end

	MarketplaceService:PromptProductPurchase(player, destination.productId)
	return true
end

local function isTeleportDestinationVisible(destination: TeleportDestinationConfig): boolean
	return destination.targetPath ~= ""
end

local function getSpeedBuffBreakdown()
	local state = getSnapshot()
	local itemMultiplier = Constants.GetTrailMultiplier(state.equippedTrail) * Constants.GetAuraMultiplier(state.equippedAura)
	local rebirthMultiplier = Constants.GetRebirthMultiplier(state.rebirths)
	local treadmillMultiplier = math.max(1, state.treadmillMultiplier)
	local knownMultiplier = math.max(0.001, itemMultiplier * rebirthMultiplier * treadmillMultiplier)
	local gamepassMultiplier = math.max(1, state.gainMultiplier / knownMultiplier)
	local itemPercent = math.max(0, math.floor((itemMultiplier - 1) * 100 + 0.5))

	return {
		itemMultiplier = itemMultiplier,
		itemPercent = itemPercent,
		rebirthMultiplier = rebirthMultiplier,
		treadmillMultiplier = treadmillMultiplier,
		gamepassMultiplier = gamepassMultiplier,
		totalMultiplier = state.gainMultiplier,
	}
end

local function stopTreadmillRunAnimation()
	local track = treadmillRunTrack
	treadmillRunTrack = nil
	treadmillRunCharacter = nil

	if track then
		track:Stop(0.15)
		track:Destroy()
	end
end

local function playTreadmillRunAnimation(character: Model, humanoid: Humanoid)
	if treadmillRunTrack and treadmillRunCharacter == character then
		if not treadmillRunTrack.IsPlaying then
			treadmillRunTrack:Play(0.15)
		end
		return
	end

	stopTreadmillRunAnimation()

	local animate = character:FindFirstChild("Animate")
	local runAnimation: Animation? = nil
	if animate then
		for _, descendant in animate:GetDescendants() do
			if descendant:IsA("Animation") and descendant.Name == "RunAnim" then
				runAnimation = descendant
				break
			end
		end
	end

	if not runAnimation then
		return
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local track = animator:LoadAnimation(runAnimation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	track:Play(0.15)
	treadmillRunCharacter = character
	treadmillRunTrack = track
end

local function showSpeedPopup(amount: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or amount <= 0 then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 90
	billboard.Size = UDim2.fromOffset(176, 58)
	billboard.StudsOffsetWorldSpace = Vector3.new(
		math.random(-20, 20) / 10,
		4 + math.random(0, 15) / 10,
		0
	)
	billboard.Parent = root

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = UI_ASSETS.Shoe
	icon.Position = UDim2.fromOffset(0, 4)
	icon.Size = UDim2.fromOffset(50, 50)
	icon.Parent = billboard

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Position = UDim2.fromOffset(48, 0)
	label.Size = UDim2.new(1, -48, 1, 0)
	label.Text = `+{formatInteger(amount)}`
	label.TextColor3 = Color3.fromRGB(255, 236, 141)
	label.TextScaled = true
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = billboard

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 44
	constraint.MinTextSize = 18
	constraint.Parent = label

	local tween = TweenService:Create(
		billboard,
		TweenInfo.new(2.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 3.5, 0),
		}
	)
	local fadeTween = TweenService:Create(
		label,
		TweenInfo.new(2.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween:Play()
	fadeTween:Play()
	tween.Completed:Connect(function()
		billboard:Destroy()
	end)
end

local function updateViewportScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local scale = math.min(viewport.X / DESIGN_WIDTH, viewport.Y / DESIGN_HEIGHT)
	viewportSize:set(viewport)
	viewportScale:set(math.clamp(scale, MIN_SCALE, MAX_SCALE))
end

local function getVisibleDesignBounds(): (number, number, number, number, number)
	local scale = viewportScale:get()
	local viewport = viewportSize:get()
	local visibleWidth = viewport.X / scale
	local visibleHeight = viewport.Y / scale
	local left = (DESIGN_WIDTH - visibleWidth) * 0.5
	local top = (DESIGN_HEIGHT - visibleHeight) * 0.5
	return left, top, left + visibleWidth, top + visibleHeight, scale
end

local function openRebirthModal()
	cosmeticModalMounted:set(false)
	cosmeticModalVisible:set(false)
	cosmeticModalAnimationGoal:set(0)
	teleportModalMounted:set(false)
	teleportModalVisible:set(false)
	teleportModalAnimationGoal:set(0)
	shopModalMounted:set(false)
	shopModalVisible:set(false)
	shopModalAnimationGoal:set(0)
	rebirthModalMounted:set(true)
	rebirthModalVisible:set(true)
	rebirthModalAnimationGoal:set(1)
end

local function closeRebirthModal()
	rebirthModalVisible:set(false)
	rebirthModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not rebirthModalVisible:get() then
			rebirthModalMounted:set(false)
		end
	end)
end

local function toggleRebirthModal()
	if rebirthModalVisible:get() then
		closeRebirthModal()
	else
		openRebirthModal()
	end
end

local function openCosmeticModal(category: string)
	rebirthModalMounted:set(false)
	rebirthModalVisible:set(false)
	rebirthModalAnimationGoal:set(0)
	teleportModalMounted:set(false)
	teleportModalVisible:set(false)
	teleportModalAnimationGoal:set(0)
	shopModalMounted:set(false)
	shopModalVisible:set(false)
	shopModalAnimationGoal:set(0)
	reviveModalMounted:set(false)
	reviveModalVisible:set(false)
	reviveModalAnimationGoal:set(0)
	cosmeticCategory:set(category)
	cosmeticModalMounted:set(true)
	cosmeticModalVisible:set(true)
	cosmeticModalAnimationGoal:set(1)
end

local function closeCosmeticModal()
	cosmeticModalVisible:set(false)
	cosmeticModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not cosmeticModalVisible:get() then
			cosmeticModalMounted:set(false)
		end
	end)
end

local function openTeleportModal()
	rebirthModalMounted:set(false)
	rebirthModalVisible:set(false)
	rebirthModalAnimationGoal:set(0)
	cosmeticModalMounted:set(false)
	cosmeticModalVisible:set(false)
	cosmeticModalAnimationGoal:set(0)
	shopModalMounted:set(false)
	shopModalVisible:set(false)
	shopModalAnimationGoal:set(0)
	reviveModalMounted:set(false)
	reviveModalVisible:set(false)
	reviveModalAnimationGoal:set(0)
	teleportModalMounted:set(true)
	teleportModalVisible:set(true)
	teleportModalAnimationGoal:set(1)
end

local function closeTeleportModal()
	teleportModalVisible:set(false)
	teleportModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not teleportModalVisible:get() then
			teleportModalMounted:set(false)
		end
	end)
end

local reviveCountdownToken = 0

local function closeReviveModal(reason: string?)
	reviveModalVisible:set(false)
	reviveModalAnimationGoal:set(0)
	reviveCountdownToken += 1
	if reason == "declined" then
		GamePackets.requestRevive.send({
			method = "decline",
		})
	end
	task.delay(0.22, function()
		if not reviveModalVisible:get() then
			reviveModalMounted:set(false)
		end
	end)
end

local function refreshReviveAdAvailability()
	if reviveAdRewardProductId:get() <= 0 then
		reviveAdAvailable:set(false)
		return
	end

	task.spawn(function()
		local success, result = pcall(function()
			return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
		end)
		reviveAdAvailable:set(success and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable)
	end)
end

local function openReviveModal(stage: number, durationSeconds: number, robuxProductId: number, robuxPrice: number, adRewardProductId: number)
	rebirthModalMounted:set(false)
	rebirthModalVisible:set(false)
	rebirthModalAnimationGoal:set(0)
	cosmeticModalMounted:set(false)
	cosmeticModalVisible:set(false)
	cosmeticModalAnimationGoal:set(0)
	teleportModalMounted:set(false)
	teleportModalVisible:set(false)
	teleportModalAnimationGoal:set(0)
	shopModalMounted:set(false)
	shopModalVisible:set(false)
	shopModalAnimationGoal:set(0)

	reviveStage:set(stage)
	reviveCountdown:set(durationSeconds)
	reviveRobuxProductId:set(robuxProductId)
	reviveRobuxPrice:set(robuxPrice)
	reviveAdRewardProductId:set(adRewardProductId)
	reviveModalMounted:set(true)
	reviveModalVisible:set(true)
	reviveModalAnimationGoal:set(1)
	refreshReviveAdAvailability()

	reviveCountdownToken += 1
	local token = reviveCountdownToken
	task.spawn(function()
		local remaining = durationSeconds
		while token == reviveCountdownToken and remaining > 0 and reviveModalVisible:get() do
			task.wait(1)
			remaining -= 1
			reviveCountdown:set(math.max(0, remaining))
		end
		if token == reviveCountdownToken and reviveModalVisible:get() then
			closeReviveModal()
		end
	end)
end

local function openShopModal()
	rebirthModalMounted:set(false)
	rebirthModalVisible:set(false)
	rebirthModalAnimationGoal:set(0)
	cosmeticModalMounted:set(false)
	cosmeticModalVisible:set(false)
	cosmeticModalAnimationGoal:set(0)
	teleportModalMounted:set(false)
	teleportModalVisible:set(false)
	teleportModalAnimationGoal:set(0)
	reviveModalMounted:set(false)
	reviveModalVisible:set(false)
	reviveModalAnimationGoal:set(0)
	shopModalMounted:set(true)
	shopModalVisible:set(true)
	shopModalAnimationGoal:set(1)
end

local function closeShopModal()
	shopModalVisible:set(false)
	shopModalAnimationGoal:set(0)
	task.delay(0.22, function()
		if not shopModalVisible:get() then
			shopModalMounted:set(false)
		end
	end)
end

local function buildLeftMenu()
	return New("Frame")({
		BackgroundTransparency = 1,
		ZIndex = 10,
		Position = Computed(function()
			local left, top, _, bottom, scale = getVisibleDesignBounds()
			local x = if scale < 0.75 then left + (14 / scale) else 32
			local y = if scale < 0.75 then top + ((bottom - top - 500) * 0.5) else 260
			return UDim2.fromOffset(x, y)
		end),
		Size = UDim2.fromOffset(272, 500),
		[Children] = {
			makeOutlineLabel({
				Position = UDim2.fromOffset(72, 0),
				Size = UDim2.fromOffset(178, 62),
				Text = Computed(function()
					return formatInteger(getSnapshot().totalWins)
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 44,
			}),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = UI_ASSETS.Trophy,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(62, 62),
			}),
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 72),
				Size = UDim2.fromOffset(272, 410),
				ZIndex = 10,
				[Children] = {
					New("UIGridLayout")({
						CellPadding = UDim2.fromOffset(12, 12),
						CellSize = UDim2.fromOffset(126, 126),
						FillDirectionMaxCells = 2,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					makeMenuButton("Rebirth", UI_ASSETS.Rebirth, Color3.fromRGB(86, 194, 255), Color3.fromRGB(44, 110, 217), function()
						toggleRebirthModal()
					end),
					makeMenuButton("Shop", UI_ASSETS.Shop, Color3.fromRGB(255, 101, 120), Color3.fromRGB(255, 205, 93), function()
						openShopModal()
					end),
					makeMenuButton("Cosmetics", UI_ASSETS.Cosmetics, Color3.fromRGB(174, 103, 255), Color3.fromRGB(91, 61, 193), function()
						openCosmeticModal("trail")
					end),
					makeMenuButton("Teleport", UI_ASSETS.Teleport, Color3.fromRGB(179, 117, 232), Color3.fromRGB(113, 63, 175), function()
						openTeleportModal()
					end),
				},
			}),
		},
	})
end

local function buildRightPanel()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = Computed(function()
			local _, top, right, bottom, scale = getVisibleDesignBounds()
			local x = if scale < 0.75 then right - 286 - (14 / scale) else 1608
			local y = if scale < 0.75 then top + ((bottom - top - 310) * 0.5) else 355
			return UDim2.fromOffset(x, y)
		end),
		Size = UDim2.fromOffset(286, 310),
		[Children] = {
			New("TextButton")({
				BackgroundColor3 = Color3.fromRGB(255, 168, 47),
				ClipsDescendants = true,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(286, 110),
				Text = "",
				[OnEvent("Activated")] = function()
					showToast("Set gamepass id before purchase")
				end,
				[Children] = {
					makeCorner(18),
					makeStroke(Color3.fromRGB(0, 0, 0), 5),
					makeGradient(Color3.fromRGB(255, 186, 69), Color3.fromRGB(255, 128, 38), 0),
					makeStudsPattern(0.74, 1),
					makeSunburst(),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = UI_ASSETS.Lightning,
						Position = UDim2.fromOffset(8, 12),
						Size = UDim2.fromOffset(78, 78),
						ZIndex = 3,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(72, 14),
						Size = UDim2.fromOffset(202, 52),
						Text = "2x Speed",
						MaxTextSize = 42,
						ZIndex = 4,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(54, 68),
						Size = UDim2.fromOffset(190, 32),
						Text = "ONLY 3",
						MaxTextSize = 28,
						ZIndex = 4,
					}),
				},
			}),
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(15, 164, 255),
				ClipsDescendants = true,
				Position = UDim2.fromOffset(0, 132),
				Size = UDim2.fromOffset(286, 160),
				[Children] = {
					makeCorner(18),
					makeStroke(Color3.fromRGB(0, 0, 0), 5),
					makeGradient(Color3.fromRGB(22, 191, 255), Color3.fromRGB(0, 104, 242)),
					makeStudsPattern(0.82, 1),
					makeOutlineLabel({
						Position = UDim2.fromOffset(16, 8),
						Size = UDim2.fromOffset(254, 34),
						Text = "Custom Speed",
						MaxTextSize = 30,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(16, 40),
						Size = UDim2.fromOffset(254, 24),
						Text = Computed(function()
							return `Your Max Speed: {math.floor(getSnapshot().maxWalkSpeed)}`
						end),
						TextColor3 = Color3.fromRGB(255, 232, 89),
						MaxTextSize = 20,
					}),
					New("TextBox")({
						BackgroundColor3 = Color3.fromRGB(235, 239, 242),
						ClearTextOnFocus = false,
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(28, 72),
						Size = UDim2.fromOffset(140, 54),
						Text = customSpeedDraft,
						TextColor3 = Color3.fromRGB(135, 135, 135),
						TextScaled = true,
						TextStrokeTransparency = 1,
						[OnChange("Text")] = function(text: string)
							local digitsOnly = string.gsub(text, "[^%d]", "")
							if customSpeedDraft:get() ~= digitsOnly then
								customSpeedDraft:set(digitsOnly)
							end
						end,
						[OnEvent("Focused")] = function()
							isEditingCustomSpeed = true
						end,
						[OnEvent("FocusLost")] = function()
							isEditingCustomSpeed = false
							submitCustomSpeed()
						end,
						[Children] = {
							makeCorner(8),
							makeStroke(Color3.fromRGB(0, 0, 0), 4),
							New("UITextSizeConstraint")({
								MaxTextSize = 34,
								MinTextSize = 12,
							}),
						},
					}),
					New("TextButton")({
						AutoButtonColor = true,
						BackgroundColor3 = Color3.fromRGB(75, 222, 61),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(178, 72),
						Size = UDim2.fromOffset(80, 54),
						Text = "OK",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0,
						[OnEvent("Activated")] = function()
							submitCustomSpeed()
						end,
						[Children] = {
							makeCorner(12),
							makeStroke(Color3.fromRGB(0, 0, 0), 4),
							makeGradient(Color3.fromRGB(75, 222, 61), Color3.fromRGB(34, 155, 33)),
							New("UITextSizeConstraint")({
								MaxTextSize = 32,
								MinTextSize = 12,
							}),
						},
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(28, 128),
						Size = UDim2.fromOffset(230, 24),
						Text = Computed(function()
							return `Current Speed: {math.floor(getSnapshot().customSpeedLimit)}`
						end),
						MaxTextSize = 19,
					}),
				},
			}),
		},
	})
end

local function buildBottomHud()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = Computed(function()
			local left, _, right, bottom, scale = getVisibleDesignBounds()
			local x = left + ((right - left - 1160) * 0.5)
			local y = if scale < 0.75 then bottom - 158 - (12 / scale) else 872
			return UDim2.fromOffset(x, y)
		end),
		Size = UDim2.fromOffset(1160, 158),
		[Children] = {
			makeOutlineLabel({
				Position = UDim2.fromOffset(400, 0),
				Size = UDim2.fromOffset(360, 58),
				Text = Computed(function()
					return `{formatInteger(getSnapshot().speed)} Speed`
				end),
				MaxTextSize = 46,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(0, -6),
				Size = UDim2.fromOffset(390, 30),
				Text = Computed(function()
					return `+{getSpeedBuffBreakdown().itemPercent}% Speed (Items)`
				end),
				TextColor3 = Color3.fromRGB(58, 255, 92),
				MaxTextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.fromOffset(390, 30),
				Text = Computed(function()
					return `Multiplier x{string.format("%.1f", getSpeedBuffBreakdown().gamepassMultiplier)} (Gamepass)`
				end),
				TextColor3 = Color3.fromRGB(255, 91, 245),
				MaxTextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(770, -6),
				Size = UDim2.fromOffset(390, 30),
				Text = Computed(function()
					return `Multiplier x{string.format("%.1f", getSpeedBuffBreakdown().treadmillMultiplier)} (Treadmill)`
				end),
				TextColor3 = Color3.fromRGB(255, 147, 221),
				MaxTextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(770, 24),
				Size = UDim2.fromOffset(390, 30),
				Text = Computed(function()
					return `Multiplier x{string.format("%.1f", getSpeedBuffBreakdown().rebirthMultiplier)} (Rebirth)`
				end),
				TextColor3 = Color3.fromRGB(88, 245, 255),
				MaxTextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(196, 147, 85),
				ClipsDescendants = true,
				Position = UDim2.fromOffset(0, 76),
				Size = UDim2.fromOffset(1158, 74),
				[Children] = {
					makeCorner(12),
					makeStroke(Color3.fromRGB(0, 0, 0), 4),
					makeGradient(Color3.fromRGB(222, 176, 111), Color3.fromRGB(165, 112, 59)),
					makeStudsPattern(0.84, 1),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(242, 199, 132),
						BorderSizePixel = 0,
						Size = Computed(function()
							local state = getSnapshot()
							local progress = 0
							if state.requiredXP > 0 then
								progress = math.clamp(state.xp / state.requiredXP, 0, 1)
							end
							if state.xp > 0 then
								progress = math.max(progress, 0.035)
							end
							return UDim2.fromScale(progress, 1)
						end),
						[Children] = {
							makeCorner(12),
						},
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(26, 8),
						Size = UDim2.fromOffset(340, 58),
						Text = Computed(function()
							return `Level {getSnapshot().level}`
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 42,
						ZIndex = 3,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(760, 10),
						Size = UDim2.fromOffset(370, 54),
						Text = Computed(function()
							local state = getSnapshot()
							return `{formatInteger(state.xp)} / {formatInteger(state.requiredXP)}`
						end),
						TextXAlignment = Enum.TextXAlignment.Right,
						MaxTextSize = 34,
						ZIndex = 3,
					}),
				},
			}),
		},
	})
end

local function makeRebirthMultiplierCard(position: UDim2, multiplier: any)
	return New("Frame")({
		BackgroundColor3 = Color3.fromRGB(255, 245, 204),
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(330, 126),
		ZIndex = 42,
		[Children] = {
			makeCorner(18),
			makeStroke(Color3.fromRGB(184, 111, 0), 5),
			makeGradient(Color3.fromRGB(255, 255, 244), Color3.fromRGB(255, 211, 75)),
			makeStudsPattern(0.76, 43),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = UI_ASSETS.Lightning,
				Position = UDim2.fromOffset(108, 2),
				Size = UDim2.fromOffset(112, 112),
				ZIndex = 44,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(16, 34),
				Size = UDim2.fromOffset(298, 58),
				Text = multiplier,
				MaxTextSize = 44,
				ZIndex = 45,
			}),
		},
	})
end

local function buildRebirthPanel()
	return New("CanvasGroup")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(190, 30, 45),
		ClipsDescendants = true,
		GroupTransparency = Computed(function()
			return 1 - rebirthModalAnimation:get()
		end),
		Position = Computed(function()
			return UDim2.fromOffset(960, 492 - (18 * rebirthModalAnimation:get()))
		end),
		Size = UDim2.fromOffset(920, 650),
		ZIndex = 40,
		[Children] = {
			makeCorner(28),
			makeStroke(Color3.fromRGB(99, 9, 24), 8),
			makeGradient(Color3.fromRGB(238, 57, 67), Color3.fromRGB(145, 13, 36)),
			makeStudsPattern(0.82, 41),
			makeOutlineLabel({
				Position = UDim2.fromOffset(220, 18),
				Size = UDim2.fromOffset(480, 76),
				Text = "~Rebirth~",
				MaxTextSize = 66,
				ZIndex = 45,
			}),
			New("TextButton")({
				BackgroundColor3 = Computed(function()
					return if rebirthCloseHovered:get() then Color3.fromRGB(255, 76, 65) else Color3.fromRGB(211, 39, 29)
				end),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(818, 20),
				Size = UDim2.fromOffset(76, 76),
				Text = "X",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 45,
				[OnEvent("Activated")] = function()
					closeRebirthModal()
				end,
				[OnEvent("MouseEnter")] = function()
					rebirthCloseHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					rebirthCloseHovered:set(false)
				end,
				[Children] = {
					makeCorner(16),
					makeStroke(Color3.fromRGB(112, 16, 20), 5),
					New("UIScale")({
						Scale = Tween(Computed(function()
							return if rebirthCloseHovered:get() then 1.08 else 1
						end), TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)),
					}),
				},
			}),
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(255, 205, 61),
				Position = UDim2.fromOffset(270, 112),
				Size = UDim2.fromOffset(380, 92),
				ZIndex = 42,
				[Children] = {
					makeCorner(18),
					makeStroke(Color3.fromRGB(145, 101, 10), 5),
					makeGradient(Color3.fromRGB(255, 224, 92), Color3.fromRGB(255, 182, 39)),
					makeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							return `Level {getSnapshot().requiredRebirthLevel}`
						end),
						MaxTextSize = 50,
						ZIndex = 45,
					}),
				},
			}),
			makeRebirthMultiplierCard(UDim2.fromOffset(44, 242), Computed(function()
				return `x{string.format("%.1f", Constants.GetRebirthMultiplier(getSnapshot().rebirths))} Speed`
			end)),
			makeOutlineLabel({
				Position = UDim2.fromOffset(400, 275),
				Size = UDim2.fromOffset(120, 62),
				Text = ">",
				MaxTextSize = 58,
				ZIndex = 45,
			}),
			makeRebirthMultiplierCard(UDim2.fromOffset(546, 242), Computed(function()
				return `x{string.format("%.1f", Constants.GetRebirthMultiplier(getSnapshot().rebirths + 1))} Speed`
			end)),
			makeOutlineLabel({
				Position = UDim2.fromOffset(180, 376),
				Size = UDim2.fromOffset(560, 36),
				Text = "Rebirth resets your speed level!",
				TextColor3 = Color3.fromRGB(255, 225, 74),
				MaxTextSize = 26,
				ZIndex = 45,
			}),
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(118, 12, 31),
				ClipsDescendants = true,
				Position = UDim2.fromOffset(44, 424),
				Size = UDim2.fromOffset(832, 70),
				ZIndex = 42,
				[Children] = {
					makeCorner(14),
					makeStroke(Color3.fromRGB(76, 4, 18), 4),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(255, 204, 54),
						Size = Tween(Computed(function()
							local state = getSnapshot()
							return UDim2.fromScale(math.clamp(state.level / state.requiredRebirthLevel, 0, 1), 1)
						end), TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)),
						ZIndex = 43,
						[Children] = {
							makeCorner(14),
							makeGradient(Color3.fromRGB(255, 242, 133), Color3.fromRGB(255, 166, 24), 0),
						},
					}),
					makeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							local state = getSnapshot()
							return `Level {state.level} / {state.requiredRebirthLevel}`
						end),
						MaxTextSize = 42,
						ZIndex = 45,
					}),
				},
			}),
			New("TextButton")({
				BackgroundColor3 = Computed(function()
					if not getSnapshot().canRebirth then
						return Color3.fromRGB(255, 188, 37)
					end
					return if rebirthConfirmHovered:get() then Color3.fromRGB(255, 226, 91) else Color3.fromRGB(255, 188, 37)
				end),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(44, 516),
				Size = UDim2.fromOffset(446, 94),
				Text = Computed(function()
					local state = getSnapshot()
					return if state.canRebirth then "REBIRTH NOW!" else `Need Level {state.requiredRebirthLevel}`
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(88, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 45,
				[OnEvent("Activated")] = function()
					local state = getSnapshot()
					if state.canRebirth then
						GamePackets.requestRebirth.send({})
						closeRebirthModal()
					else
						showToast(`Need Level {state.requiredRebirthLevel}`)
					end
				end,
				[OnEvent("MouseEnter")] = function()
					rebirthConfirmHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					rebirthConfirmHovered:set(false)
				end,
				[Children] = {
					makeCorner(16),
					makeStroke(Color3.fromRGB(163, 79, 0), 5),
					makeStudsPattern(0.76, 44),
					New("UITextSizeConstraint")({
						MaxTextSize = 42,
						MinTextSize = 16,
					}),
				},
			}),
			New("TextButton")({
				BackgroundColor3 = Computed(function()
					return if rebirthSkipHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(216, 39, 47)
				end),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(508, 516),
				Size = UDim2.fromOffset(368, 94),
				Text = "Skip Rebirth!",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(92, 0, 17),
				TextStrokeTransparency = 0,
				ZIndex = 45,
				[OnEvent("Activated")] = function()
					showToast("Skip Rebirth product not wired yet")
				end,
				[OnEvent("MouseEnter")] = function()
					rebirthSkipHovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					rebirthSkipHovered:set(false)
				end,
				[Children] = {
					makeCorner(16),
					makeStroke(Color3.fromRGB(111, 5, 22), 5),
					makeStudsPattern(0.76, 44),
					New("UITextSizeConstraint")({
						MaxTextSize = 38,
						MinTextSize = 16,
					}),
				},
			}),
		},
	})
end

local function buildRebirthModal()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
		Visible = rebirthModalMounted,
		ZIndex = 38,
		[Children] = {
			buildRebirthPanel(),
		},
	})
end

local function getCosmeticCardColors(category: string, index: number): (Color3, Color3)
	local trailColors = {
		{ Color3.fromRGB(84, 224, 113), Color3.fromRGB(27, 133, 75) },
		{ Color3.fromRGB(84, 176, 255), Color3.fromRGB(45, 86, 203) },
		{ Color3.fromRGB(183, 98, 255), Color3.fromRGB(101, 49, 196) },
		{ Color3.fromRGB(255, 91, 91), Color3.fromRGB(185, 31, 48) },
		{ Color3.fromRGB(255, 201, 75), Color3.fromRGB(210, 61, 157) },
		{ Color3.fromRGB(108, 76, 255), Color3.fromRGB(32, 22, 102) },
	}
	local auraColors = {
		{ Color3.fromRGB(255, 223, 92), Color3.fromRGB(221, 118, 34) },
		{ Color3.fromRGB(255, 104, 64), Color3.fromRGB(179, 30, 31) },
		{ Color3.fromRGB(92, 205, 255), Color3.fromRGB(52, 84, 211) },
		{ Color3.fromRGB(153, 93, 255), Color3.fromRGB(55, 23, 126) },
		{ Color3.fromRGB(255, 100, 212), Color3.fromRGB(68, 49, 178) },
	}
	local colors = if category == "trail" then trailColors else auraColors
	local selected = colors[index] or colors[1]
	return selected[1], selected[2]
end

local function makeCosmeticCard(category: string, config: any, index: number)
	local colorA, colorB = getCosmeticCardColors(category, index)
	local icon = if category == "trail" then UI_ASSETS.Trail else UI_ASSETS.Aura

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(252, 194),
		ZIndex = 44,
		[Children] = {
			makeCorner(18),
			makeStroke(Color3.fromRGB(45, 13, 71), 5),
			makeGradient(colorA, colorB),
			makeStudsPattern(0.8, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(12, 14),
				Size = UDim2.fromOffset(68, 68),
				ZIndex = 46,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(84, 12),
				Size = UDim2.fromOffset(154, 52),
				Text = config.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 23,
				ZIndex = 46,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(84, 60),
				Size = UDim2.fromOffset(154, 30),
				Text = `x{string.format("%.1f", config.multiplier)} Speed`,
				TextColor3 = Color3.fromRGB(255, 239, 112),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 21,
				ZIndex = 46,
			}),
			New("TextButton")({
				AutoButtonColor = true,
				BackgroundColor3 = Computed(function()
					local state = getSnapshot()
					local equippedId = if category == "trail" then state.equippedTrail else state.equippedAura
					local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
					if equippedId == config.id then
						return Color3.fromRGB(78, 212, 80)
					end
					return if unlocked[config.id] then Color3.fromRGB(71, 172, 255) else Color3.fromRGB(255, 185, 48)
				end),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(14, 112),
				Size = UDim2.fromOffset(224, 64),
				Text = Computed(function()
					local state = getSnapshot()
					local equippedId = if category == "trail" then state.equippedTrail else state.equippedAura
					local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
					if equippedId == config.id then
						return "EQUIPPED"
					end
					if unlocked[config.id] then
						return "EQUIP"
					end
					return `{formatInteger(config.priceWins)} WINS`
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 46,
				[OnEvent("Activated")] = function()
					local state = getSnapshot()
					local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
					if not unlocked[config.id] and state.totalWins < config.priceWins then
						showToast("Not enough Wins")
						return
					end

					GamePackets.requestCosmeticAction.send({
						category = category,
						itemId = config.id,
					})
				end,
				[Children] = {
					makeCorner(13),
					makeStroke(Color3.fromRGB(57, 30, 77), 4),
					New("UITextSizeConstraint")({
						MaxTextSize = 26,
						MinTextSize = 12,
					}),
				},
			}),
		},
	})
end

local function makeCosmeticCatalog(category: string, catalog: { any })
	local cards = {}
	for index, config in catalog do
		table.insert(cards, makeCosmeticCard(category, config, index))
	end
	table.insert(cards, New("UIGridLayout")({
		CellPadding = UDim2.fromOffset(18, 18),
		CellSize = UDim2.fromOffset(252, 194),
		FillDirectionMaxCells = 3,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}))

	return New("ScrollingFrame")({
		Active = true,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, math.ceil(#catalog / 3) * 212),
		Position = UDim2.fromOffset(52, 188),
		ScrollBarImageColor3 = Color3.fromRGB(255, 216, 90),
		ScrollBarThickness = 10,
		Size = UDim2.fromOffset(816, 420),
		Visible = Computed(function()
			return cosmeticCategory:get() == category
		end),
		ZIndex = 44,
		[Children] = cards,
	})
end

local function makeCosmeticTab(category: string, label: string, position: UDim2, colorA: Color3, colorB: Color3)
	return New("TextButton")({
		BackgroundColor3 = Computed(function()
			return if cosmeticCategory:get() == category then colorA else Color3.fromRGB(103, 67, 126)
		end),
		Font = Enum.Font.GothamBlack,
		Position = position,
		Size = UDim2.fromOffset(260, 70),
		Text = label,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0,
		ZIndex = 45,
		[OnEvent("Activated")] = function()
			cosmeticCategory:set(category)
		end,
		[Children] = {
			makeCorner(16),
			makeStroke(Color3.fromRGB(62, 22, 91), 5),
			makeGradient(colorA, colorB),
			New("UITextSizeConstraint")({
				MaxTextSize = 34,
				MinTextSize = 14,
			}),
		},
	})
end

local function buildCosmeticModal()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
		Visible = cosmeticModalMounted,
		ZIndex = 38,
		[Children] = {
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(108, 44, 151),
				ClipsDescendants = true,
				GroupTransparency = Computed(function()
					return 1 - cosmeticModalAnimation:get()
				end),
				Position = Computed(function()
					return UDim2.fromOffset(960, 492 - (18 * cosmeticModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(920, 700),
				ZIndex = 40,
				[Children] = {
					makeCorner(28),
					makeStroke(Color3.fromRGB(57, 16, 89), 8),
					makeGradient(Color3.fromRGB(165, 81, 214), Color3.fromRGB(79, 31, 126)),
					makeStudsPattern(0.82, 41),
					makeOutlineLabel({
						Position = UDim2.fromOffset(220, 16),
						Size = UDim2.fromOffset(480, 70),
						Text = "~Boost Shop~",
						MaxTextSize = 60,
						ZIndex = 45,
					}),
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return if cosmeticCloseHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
						end),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(818, 20),
						Size = UDim2.fromOffset(76, 76),
						Text = "X",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0,
						ZIndex = 46,
						[OnEvent("Activated")] = closeCosmeticModal,
						[OnEvent("MouseEnter")] = function()
							cosmeticCloseHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							cosmeticCloseHovered:set(false)
						end,
						[Children] = {
							makeCorner(16),
							makeStroke(Color3.fromRGB(112, 16, 20), 5),
						},
					}),
					makeCosmeticTab("trail", "TRAILS", UDim2.fromOffset(186, 102), Color3.fromRGB(177, 106, 255), Color3.fromRGB(94, 55, 196)),
					makeCosmeticTab("aura", "AURAS", UDim2.fromOffset(474, 102), Color3.fromRGB(255, 104, 79), Color3.fromRGB(184, 36, 47)),
					makeCosmeticCatalog("trail", Constants.TRAILS),
					makeCosmeticCatalog("aura", Constants.AURAS),
				},
			}),
		},
	})
end

local function promptShopPurchase(item: ShopItemConfig)
	if item.purchaseId <= 0 then
		showToast(`Set {item.title} product id`)
		return
	end

	if item.purchaseKind == "gamepass" then
		MarketplaceService:PromptGamePassPurchase(player, item.purchaseId)
	else
		MarketplaceService:PromptProductPurchase(player, item.purchaseId)
	end
end

local function makeShopCard(item: ShopItemConfig)
	local colorA = item.accentColor
	local colorB = colorA:Lerp(Color3.fromRGB(33, 41, 113), 0.58)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		LayoutOrder = item.sortOrder,
		Size = UDim2.fromOffset(416, 166),
		ZIndex = 44,
		[Children] = {
			makeCorner(18),
			makeStroke(Color3.fromRGB(48, 18, 72), 3),
			makeGradient(colorA, colorB),
			makeStudsPattern(0.81, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = item.icon,
				Position = UDim2.fromOffset(16, 16),
				Size = UDim2.fromOffset(92, 92),
				ZIndex = 46,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(116, 14),
				Size = UDim2.fromOffset(278, 34),
				Text = item.title,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 28,
				ZIndex = 46,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(118, 50),
				Size = UDim2.fromOffset(272, 28),
				Text = item.valueText,
				TextColor3 = Color3.fromRGB(255, 238, 111),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 23,
				ZIndex = 46,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(118, 80),
				Size = UDim2.fromOffset(278, 34),
				Text = item.subtitle,
				TextColor3 = Color3.fromRGB(232, 251, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 18,
				ZIndex = 46,
			}),
			New("TextButton")({
				AutoButtonColor = true,
				BackgroundColor3 = Color3.fromRGB(101, 255, 41),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(118, 114),
				Size = UDim2.fromOffset(278, 42),
				Text = "",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 47,
				[OnEvent("Activated")] = function()
					promptShopPurchase(item)
				end,
				[Children] = {
					makeCorner(12),
					makeStroke(Color3.fromRGB(11, 111, 19), 3),
					makeGradient(Color3.fromRGB(143, 255, 58), Color3.fromRGB(38, 198, 25), 0),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = UI_ASSETS.Robux,
						Position = UDim2.fromOffset(82, 4),
						Size = UDim2.fromOffset(34, 34),
						ZIndex = 48,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(122, 1),
						Size = UDim2.fromOffset(92, 40),
						Text = tostring(item.priceRobux),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 31,
						ZIndex = 48,
					}),
					New("UITextSizeConstraint")({
						MaxTextSize = 26,
						MinTextSize = 12,
					}),
				},
			}),
		},
	})
end

local function makeShopSection(sectionConfig: { [string]: any }, index: number)
	local items = SHOP_CATALOG[sectionConfig.id] or {}
	local rowCount = math.max(1, math.ceil(#items / 2))
	local cardChildren = {
		New("UIGridLayout")({
			CellPadding = UDim2.fromOffset(18, 18),
			CellSize = UDim2.fromOffset(416, 166),
			FillDirectionMaxCells = 2,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, item in items do
		table.insert(cardChildren, makeShopCard(item))
	end
	local children = {
		New("Frame")({
			BackgroundColor3 = sectionConfig.colorA,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(850, 58),
			ZIndex = 44,
			[Children] = {
				makeCorner(14),
				makeStroke(Color3.fromRGB(46, 19, 74), 3),
				makeGradient(sectionConfig.colorA, sectionConfig.colorB, 0),
				makeStudsPattern(0.83, 47),
				makeOutlineLabel({
					Position = UDim2.fromOffset(22, 0),
					Size = UDim2.fromOffset(806, 58),
					Text = sectionConfig.label,
					MaxTextSize = 31,
					ZIndex = 46,
				}),
			},
		}),
		New("Frame")({
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromOffset(884, rowCount * 184),
			ZIndex = 44,
			[Children] = cardChildren,
		}),
	}

	return New("Frame")({
		BackgroundTransparency = 1,
		LayoutOrder = index,
		Size = UDim2.fromOffset(884, 82 + (rowCount * 184)),
		ZIndex = 43,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 16),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			table.unpack(children),
		},
	})
end

local function makeShopScroll()
	local sections = {}
	local totalHeight = 0
	for index, sectionConfig in SHOP_TABS do
		local itemCount = #(SHOP_CATALOG[sectionConfig.id] or {})
		local rowCount = math.max(1, math.ceil(itemCount / 2))
		totalHeight += 82 + (rowCount * 184) + 22
		table.insert(sections, makeShopSection(sectionConfig, index))
	end
	table.insert(sections, New("UIListLayout")({
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 22),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}))

	return New("ScrollingFrame")({
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.fromOffset(0, totalHeight),
		Position = UDim2.fromOffset(58, 134),
		ScrollBarImageColor3 = Color3.fromRGB(103, 255, 53),
		ScrollBarThickness = 8,
		Size = UDim2.fromOffset(916, 566),
		ZIndex = 44,
		[Children] = sections,
	})
end

local function buildShopModal()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
		Visible = shopModalMounted,
		ZIndex = 38,
		[Children] = {
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(214, 54, 74),
				ClipsDescendants = true,
				GroupTransparency = Computed(function()
					return 1 - shopModalAnimation:get()
				end),
				Position = Computed(function()
					return UDim2.fromOffset(960, 492 - (18 * shopModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(1032, 760),
				ZIndex = 40,
				[Children] = {
					makeCorner(18),
					makeStroke(Color3.fromRGB(18, 18, 30), 5),
					makeGradient(Color3.fromRGB(255, 57, 68), Color3.fromRGB(124, 25, 112)),
					makeStudsPattern(0.78, 41),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(255, 205, 46),
						Position = UDim2.fromOffset(0, 0),
						Size = UDim2.fromOffset(1032, 96),
						ZIndex = 45,
						[Children] = {
							makeCorner(18),
							makeStroke(Color3.fromRGB(18, 18, 30), 4),
							makeGradient(Color3.fromRGB(255, 238, 77), Color3.fromRGB(255, 162, 28), 0),
							makeStudsPattern(0.86, 47),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = UI_ASSETS.Shop,
								Position = UDim2.fromOffset(26, 16),
								Size = UDim2.fromOffset(68, 68),
								ZIndex = 47,
							}),
							makeOutlineLabel({
								Position = UDim2.fromOffset(108, 12),
								Size = UDim2.fromOffset(340, 72),
								Text = "Store",
								TextXAlignment = Enum.TextXAlignment.Left,
								MaxTextSize = 58,
								ZIndex = 47,
							}),
							New("TextButton")({
								BackgroundColor3 = Computed(function()
									return if shopCloseHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
								end),
								Font = Enum.Font.GothamBlack,
								Position = UDim2.fromOffset(940, 15),
								Size = UDim2.fromOffset(66, 66),
								Text = "X",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
								TextStrokeTransparency = 0,
								ZIndex = 48,
								[OnEvent("Activated")] = closeShopModal,
								[OnEvent("MouseEnter")] = function()
									shopCloseHovered:set(true)
								end,
								[OnEvent("MouseLeave")] = function()
									shopCloseHovered:set(false)
								end,
								[Children] = {
									makeCorner(10),
									makeStroke(Color3.fromRGB(48, 8, 13), 4),
								},
							}),
						},
					}),
					makeShopScroll(),
				},
			}),
		},
	})
end

local function makeTeleportCard(destination: TeleportDestinationConfig)
	local colorA = destination.accentColor
	local colorB = colorA:Lerp(Color3.fromRGB(33, 20, 87), 0.58)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		LayoutOrder = destination.sortOrder,
		Size = UDim2.fromOffset(372, 178),
		ZIndex = 44,
		[Children] = {
			makeCorner(18),
			makeStroke(Color3.fromRGB(45, 13, 71), 5),
			makeGradient(colorA, colorB),
			makeStudsPattern(0.8, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = UI_ASSETS.Teleport,
				Position = UDim2.fromOffset(16, 18),
				Size = UDim2.fromOffset(76, 76),
				ZIndex = 46,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(104, 16),
				Size = UDim2.fromOffset(240, 42),
				Text = destination.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 34,
				ZIndex = 46,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(106, 58),
				Size = UDim2.fromOffset(236, 32),
				Text = destination.description,
				TextColor3 = Color3.fromRGB(255, 238, 118),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 22,
				ZIndex = 46,
			}),
			New("TextButton")({
				AutoButtonColor = true,
				BackgroundColor3 = Color3.fromRGB(248, 225, 36),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(16, 108),
				Size = UDim2.fromOffset(220, 56),
				Text = "",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 47,
				[OnEvent("Activated")] = function()
					if requestTeleportWithWins(destination) then
						closeTeleportModal()
					end
				end,
				[Children] = {
					makeCorner(12),
					makeStroke(Color3.fromRGB(18, 77, 0), 4),
					makeGradient(Color3.fromRGB(241, 255, 73), Color3.fromRGB(84, 207, 20), 0),
					makeStudsPattern(0.86, 48),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = UI_ASSETS.Trophy,
						Position = UDim2.fromOffset(24, 8),
						Size = UDim2.fromOffset(40, 40),
						ZIndex = 49,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(72, 4),
						Size = UDim2.fromOffset(130, 48),
						Text = if destination.priceWins <= 0 then "FREE" else formatInteger(destination.priceWins),
						MaxTextSize = 36,
						ZIndex = 49,
					}),
				},
			}),
			New("TextButton")({
				AutoButtonColor = true,
				BackgroundColor3 = Color3.fromRGB(54, 200, 56),
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromOffset(248, 108),
				Size = UDim2.fromOffset(104, 56),
				Text = "",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 47,
				[OnEvent("Activated")] = function()
					if promptTeleportWithRobux(destination) then
						closeTeleportModal()
					end
				end,
				[Children] = {
					makeCorner(12),
					makeStroke(Color3.fromRGB(12, 72, 22), 4),
					makeGradient(Color3.fromRGB(120, 255, 80), Color3.fromRGB(31, 152, 43), 0),
					makeStudsPattern(0.86, 48),
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = UI_ASSETS.Robux,
						Position = UDim2.fromOffset(12, 14),
						Size = UDim2.fromOffset(28, 28),
						ZIndex = 49,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(40, 6),
						Size = UDim2.fromOffset(56, 44),
						Text = if destination.productId <= 0 then "--" else formatInteger(destination.priceRobux),
						MaxTextSize = 30,
						ZIndex = 49,
					}),
				},
			}),
		},
	})
end

local function buildTeleportList()
	local cards = {}
	local visibleCount = 0
	for _, destination in Constants.TELEPORT_DESTINATIONS do
		if isTeleportDestinationVisible(destination) then
			visibleCount += 1
			table.insert(cards, makeTeleportCard(destination))
		end
	end
	table.insert(cards, New("UIGridLayout")({
		CellPadding = UDim2.fromOffset(18, 18),
		CellSize = UDim2.fromOffset(372, 178),
		FillDirectionMaxCells = 2,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}))

	return New("ScrollingFrame")({
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, math.ceil(visibleCount / 2) * 196),
		Position = UDim2.fromOffset(52, 186),
		ScrollBarImageColor3 = Color3.fromRGB(255, 216, 90),
		ScrollBarThickness = 10,
		Size = UDim2.fromOffset(816, 414),
		ZIndex = 44,
		[Children] = cards,
	})
end

local function buildTeleportModal()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
		Visible = teleportModalMounted,
		ZIndex = 38,
		[Children] = {
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(81, 36, 139),
				ClipsDescendants = true,
				GroupTransparency = Computed(function()
					return 1 - teleportModalAnimation:get()
				end),
				Position = Computed(function()
					return UDim2.fromOffset(960, 492 - (18 * teleportModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(920, 650),
				ZIndex = 40,
				[Children] = {
					makeCorner(28),
					makeStroke(Color3.fromRGB(62, 22, 91), 8),
					makeGradient(Color3.fromRGB(137, 67, 205), Color3.fromRGB(50, 25, 95)),
					makeStudsPattern(0.82, 41),
					makeOutlineLabel({
						Position = UDim2.fromOffset(210, 18),
						Size = UDim2.fromOffset(560, 82),
						Text = "~Teleport~",
						MaxTextSize = 66,
						ZIndex = 45,
					}),
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return if teleportCloseHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
						end),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(818, 20),
						Size = UDim2.fromOffset(76, 76),
						Text = "X",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0,
						ZIndex = 46,
						[OnEvent("Activated")] = closeTeleportModal,
						[OnEvent("MouseEnter")] = function()
							teleportCloseHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							teleportCloseHovered:set(false)
						end,
						[Children] = {
							makeCorner(16),
							makeStroke(Color3.fromRGB(112, 16, 20), 4),
						},
					}),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(255, 205, 61),
						Position = UDim2.fromOffset(270, 112),
						Size = UDim2.fromOffset(380, 60),
						ZIndex = 44,
						[Children] = {
							makeCorner(16),
							makeStroke(Color3.fromRGB(145, 101, 10), 5),
							makeGradient(Color3.fromRGB(255, 227, 99), Color3.fromRGB(255, 165, 35)),
							makeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = "PAY TO TELEPORT",
								MaxTextSize = 34,
								ZIndex = 46,
							}),
						},
					}),
					buildTeleportList(),
				},
			}),
		},
	})
end

local function promptReviveWithRobux()
	local productId = reviveRobuxProductId:get()
	if productId <= 0 then
		showToast("Set revive product id before purchase")
		return
	end

	MarketplaceService:PromptProductPurchase(player, productId)
end

local function requestReviveWithAd()
	if reviveAdRewardProductId:get() <= 0 then
		showToast("Set revive product id before ads")
		return
	end
	if not reviveAdAvailable:get() then
		showToast("Ad not available")
		refreshReviveAdAvailability()
		return
	end

	GamePackets.requestRevive.send({
		method = "ad",
	})
end

local function buildReviveModal()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
		Visible = reviveModalMounted,
		ZIndex = 150,
		[Children] = {
			New("TextButton")({
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = Computed(function()
					return 0.36 + (0.42 * (1 - reviveModalAnimation:get()))
				end),
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 150,
			}),
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(44, 31, 86),
				ClipsDescendants = true,
				GroupTransparency = Computed(function()
					return 1 - reviveModalAnimation:get()
				end),
				Position = Computed(function()
					return UDim2.fromOffset(960, 506 - (22 * reviveModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(740, 430),
				ZIndex = 151,
				[Children] = {
					makeCorner(24),
					makeStroke(Color3.fromRGB(20, 14, 43), 8),
					makeGradient(Color3.fromRGB(112, 62, 219), Color3.fromRGB(28, 21, 68)),
					makeStudsPattern(0.84, 152),
					makeOutlineLabel({
						Position = UDim2.fromOffset(86, 30),
						Size = UDim2.fromOffset(568, 72),
						Text = "REVIVE?",
						TextColor3 = Color3.fromRGB(255, 235, 104),
						MaxTextSize = 58,
						ZIndex = 154,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(92, 112),
						Size = UDim2.fromOffset(556, 44),
						Text = Computed(function()
							return `Return to Stage {reviveStage:get()}`
						end),
						MaxTextSize = 32,
						ZIndex = 154,
					}),
					New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundColor3 = Color3.fromRGB(255, 202, 62),
						Position = UDim2.fromOffset(370, 170),
						Size = UDim2.fromOffset(220, 58),
						ZIndex = 154,
						[Children] = {
							makeCorner(16),
							makeStroke(Color3.fromRGB(109, 62, 0), 5),
							makeGradient(Color3.fromRGB(255, 235, 87), Color3.fromRGB(255, 135, 35)),
							makeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = Computed(function()
									return `{reviveCountdown:get()}s`
								end),
								MaxTextSize = 38,
								ZIndex = 156,
							}),
						},
					}),
					New("TextButton")({
						AutoButtonColor = true,
						BackgroundColor3 = Computed(function()
							return if reviveRobuxHovered:get() then Color3.fromRGB(86, 239, 86) else Color3.fromRGB(54, 200, 56)
						end),
						Position = UDim2.fromOffset(70, 272),
						Size = UDim2.fromOffset(280, 86),
						Text = "",
						ZIndex = 154,
						[OnEvent("Activated")] = promptReviveWithRobux,
						[OnEvent("MouseEnter")] = function()
							reviveRobuxHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							reviveRobuxHovered:set(false)
						end,
						[Children] = {
							makeCorner(18),
							makeStroke(Color3.fromRGB(12, 72, 22), 5),
							makeGradient(Color3.fromRGB(120, 255, 80), Color3.fromRGB(31, 152, 43), 0),
							makeStudsPattern(0.86, 155),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = UI_ASSETS.Robux,
								Position = UDim2.fromOffset(34, 22),
								Size = UDim2.fromOffset(42, 42),
								ZIndex = 157,
							}),
							makeOutlineLabel({
								Position = UDim2.fromOffset(86, 13),
								Size = UDim2.fromOffset(160, 58),
								Text = Computed(function()
									local price = reviveRobuxPrice:get()
									return if reviveRobuxProductId:get() <= 0 then "--" else formatInteger(price)
								end),
								MaxTextSize = 42,
								ZIndex = 157,
							}),
						},
					}),
					New("TextButton")({
						AutoButtonColor = true,
						BackgroundColor3 = Computed(function()
							if not reviveAdAvailable:get() then
								return Color3.fromRGB(110, 110, 122)
							end
							return if reviveAdHovered:get() then Color3.fromRGB(80, 213, 255) else Color3.fromRGB(45, 166, 238)
						end),
						Position = UDim2.fromOffset(390, 272),
						Size = UDim2.fromOffset(280, 86),
						Text = "",
						ZIndex = 154,
						[OnEvent("Activated")] = requestReviveWithAd,
						[OnEvent("MouseEnter")] = function()
							reviveAdHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							reviveAdHovered:set(false)
						end,
						[Children] = {
							makeCorner(18),
							makeStroke(Color3.fromRGB(15, 54, 93), 5),
							makeGradient(Color3.fromRGB(84, 221, 255), Color3.fromRGB(30, 85, 204), 0),
							makeStudsPattern(0.86, 155),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = UI_ASSETS.Teleport,
								Position = UDim2.fromOffset(24, 18),
								Size = UDim2.fromOffset(50, 50),
								ZIndex = 157,
							}),
							makeOutlineLabel({
								Position = UDim2.fromOffset(82, 12),
								Size = UDim2.fromOffset(174, 60),
								Text = Computed(function()
									return if reviveAdAvailable:get() then "WATCH AD" else "NO AD"
								end),
								MaxTextSize = 32,
								ZIndex = 157,
							}),
						},
					}),
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return if reviveCloseHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
						end),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(648, 18),
						Size = UDim2.fromOffset(64, 64),
						Text = "X",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0,
						ZIndex = 158,
						[OnEvent("Activated")] = function()
							closeReviveModal("declined")
						end,
						[OnEvent("MouseEnter")] = function()
							reviveCloseHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							reviveCloseHovered:set(false)
						end,
						[Children] = {
							makeCorner(14),
							makeStroke(Color3.fromRGB(112, 16, 20), 4),
						},
					}),
				},
			}),
		},
	})
end

local function buildCompactReviveModal()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
		Visible = reviveModalMounted,
		ZIndex = 150,
		[Children] = {
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(45, 31, 94),
				ClipsDescendants = true,
				GroupTransparency = Computed(function()
					return 1 - reviveModalAnimation:get()
				end),
				Position = Computed(function()
					return UDim2.fromOffset(960, 124 - (10 * reviveModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(520, 148),
				ZIndex = 151,
				[Children] = {
					makeCorner(18),
					makeStroke(Color3.fromRGB(18, 11, 45), 5),
					makeGradient(Color3.fromRGB(105, 61, 210), Color3.fromRGB(28, 21, 68)),
					makeStudsPattern(0.87, 152),
					makeOutlineLabel({
						Position = UDim2.fromOffset(20, 10),
						Size = UDim2.fromOffset(180, 42),
						Text = "REVIVE?",
						TextColor3 = Color3.fromRGB(255, 235, 104),
						MaxTextSize = 36,
						ZIndex = 154,
					}),
					makeOutlineLabel({
						Position = UDim2.fromOffset(204, 12),
						Size = UDim2.fromOffset(196, 36),
						Text = Computed(function()
							return `Stage {reviveStage:get()}`
						end),
						MaxTextSize = 26,
						ZIndex = 154,
					}),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(255, 202, 62),
						Position = UDim2.fromOffset(408, 14),
						Size = UDim2.fromOffset(82, 34),
						ZIndex = 154,
						[Children] = {
							makeCorner(10),
							makeStroke(Color3.fromRGB(109, 62, 0), 3),
							makeGradient(Color3.fromRGB(255, 235, 87), Color3.fromRGB(255, 135, 35)),
							makeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = Computed(function()
									return `{reviveCountdown:get()}s`
								end),
								MaxTextSize = 24,
								ZIndex = 156,
							}),
						},
					}),
					New("TextButton")({
						AutoButtonColor = true,
						BackgroundColor3 = Computed(function()
							return if reviveRobuxHovered:get() then Color3.fromRGB(86, 239, 86) else Color3.fromRGB(54, 200, 56)
						end),
						Position = UDim2.fromOffset(22, 72),
						Size = UDim2.fromOffset(216, 54),
						Text = "",
						ZIndex = 154,
						[OnEvent("Activated")] = promptReviveWithRobux,
						[OnEvent("MouseEnter")] = function()
							reviveRobuxHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							reviveRobuxHovered:set(false)
						end,
						[Children] = {
							makeCorner(14),
							makeStroke(Color3.fromRGB(12, 72, 22), 4),
							makeGradient(Color3.fromRGB(120, 255, 80), Color3.fromRGB(31, 152, 43), 0),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = UI_ASSETS.Robux,
								Position = UDim2.fromOffset(28, 13),
								Size = UDim2.fromOffset(28, 28),
								ZIndex = 157,
							}),
							makeOutlineLabel({
								Position = UDim2.fromOffset(62, 7),
								Size = UDim2.fromOffset(126, 40),
								Text = Computed(function()
									local price = reviveRobuxPrice:get()
									return if reviveRobuxProductId:get() <= 0 then "--" else formatInteger(price)
								end),
								MaxTextSize = 28,
								ZIndex = 157,
							}),
						},
					}),
					New("TextButton")({
						AutoButtonColor = true,
						BackgroundColor3 = Computed(function()
							if not reviveAdAvailable:get() then
								return Color3.fromRGB(110, 110, 122)
							end
							return if reviveAdHovered:get() then Color3.fromRGB(80, 213, 255) else Color3.fromRGB(45, 166, 238)
						end),
						Position = UDim2.fromOffset(262, 72),
						Size = UDim2.fromOffset(216, 54),
						Text = "",
						ZIndex = 154,
						[OnEvent("Activated")] = requestReviveWithAd,
						[OnEvent("MouseEnter")] = function()
							reviveAdHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							reviveAdHovered:set(false)
						end,
						[Children] = {
							makeCorner(14),
							makeStroke(Color3.fromRGB(15, 54, 93), 4),
							makeGradient(Color3.fromRGB(84, 221, 255), Color3.fromRGB(30, 85, 204), 0),
							makeOutlineLabel({
								Position = UDim2.fromOffset(18, 7),
								Size = UDim2.fromOffset(180, 40),
								Text = Computed(function()
									return if reviveAdAvailable:get() then "WATCH AD" else "NO AD"
								end),
								MaxTextSize = 25,
								ZIndex = 157,
							}),
						},
					}),
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return if reviveCloseHovered:get() then Color3.fromRGB(255, 92, 84) else Color3.fromRGB(211, 39, 49)
						end),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(482, 8),
						Size = UDim2.fromOffset(30, 30),
						Text = "X",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0,
						ZIndex = 158,
						[OnEvent("Activated")] = function()
							closeReviveModal("declined")
						end,
						[OnEvent("MouseEnter")] = function()
							reviveCloseHovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							reviveCloseHovered:set(false)
						end,
						[Children] = {
							makeCorner(8),
							makeStroke(Color3.fromRGB(112, 16, 20), 3),
						},
					}),
				},
			}),
		},
	})
end

local function buildLevelUpToast()
	return New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 188, 48),
		ClipsDescendants = true,
		Position = UDim2.fromOffset(960, 300),
		Size = UDim2.fromOffset(650, 112),
		Visible = Computed(function()
			return levelUpText:get() ~= ""
		end),
		ZIndex = 30,
		[Children] = {
			makeCorner(18),
			makeStroke(Color3.fromRGB(0, 0, 0), 5),
			makeGradient(Color3.fromRGB(255, 226, 95), Color3.fromRGB(255, 135, 32), 0),
			makeStudsPattern(0.72, 31),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = UI_ASSETS.Trophy,
				Position = UDim2.fromOffset(18, 14),
				Size = UDim2.fromOffset(84, 84),
				ZIndex = 32,
			}),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = UI_ASSETS.Lightning,
				Position = UDim2.fromOffset(548, 14),
				Size = UDim2.fromOffset(84, 84),
				ZIndex = 32,
			}),
			makeOutlineLabel({
				Position = UDim2.fromOffset(112, 22),
				Size = UDim2.fromOffset(426, 68),
				Text = levelUpText,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				MaxTextSize = 42,
				ZIndex = 33,
			}),
		},
	})
end

local function buildCenterToast()
	return New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(31, 20, 61),
		Position = UDim2.fromOffset(960, 154),
		Size = UDim2.fromOffset(760, 76),
		Visible = Computed(function()
			local toast = toastText:get()
			return toast ~= "" or not getSnapshot().isLoaded
		end),
		ZIndex = TOAST_Z_INDEX,
		[Children] = {
			makeCorner(18),
			makeStroke(Color3.fromRGB(0, 0, 0), 5),
			makeGradient(Color3.fromRGB(92, 63, 196), Color3.fromRGB(31, 20, 61), 0),
			makeStudsPattern(0.84, TOAST_Z_INDEX + 1),
			makeOutlineLabel({
				Position = UDim2.fromOffset(24, 6),
				Size = UDim2.fromOffset(712, 64),
				Text = Computed(function()
					local toast = toastText:get()
					if toast ~= "" then
						return toast
					end
					if not getSnapshot().isLoaded then
						return "Loading profile..."
					end
					return ""
				end),
				TextColor3 = Color3.fromRGB(255, 238, 112),
				MaxTextSize = 38,
				ZIndex = TOAST_Z_INDEX + 2,
			}),
		},
	})
end

local function buildGui()
	local playerGui = player:WaitForChild("PlayerGui")

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
				Size = UDim2.fromOffset(DESIGN_WIDTH, DESIGN_HEIGHT),
				[Children] = {
					New("UIScale")({
						Scale = viewportScale,
					}),
					buildLeftMenu(),
					buildRightPanel(),
					buildBottomHud(),
					buildRebirthModal(),
					buildShopModal(),
					buildCosmeticModal(),
					buildTeleportModal(),
					buildCompactReviveModal(),
					buildLevelUpToast(),
					buildCenterToast(),
				},
			}),
		},
	})

	sweeper:Add(gui)
end

function CoreLoopHUDController.Init()
	buildGui()
	updateViewportScale()

	local camera = Workspace.CurrentCamera
	if camera then
		sweeper:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateViewportScale))
	end
	sweeper:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateViewportScale))
end

function CoreLoopHUDController.Start()
	local snapshotListener = GamePackets.profileSnapshot.listen(function(data: Snapshot)
		local previousSpeed = lastSpeed
		local previousSnapshot = snapshot:get(false)
		local wasLoaded = previousSnapshot.isLoaded
		snapshot:set(data)
		lastSpeed = data.speed
		if not isEditingCustomSpeed then
			syncCustomSpeedDraft(data.customSpeedLimit)
		end

		if wasLoaded and data.speed > previousSpeed then
			showSpeedPopup(data.speed - previousSpeed)
		end
		if wasLoaded and data.level > previousSnapshot.level then
			showLevelUpCelebration(data.level, data.level - previousSnapshot.level)
		end
	end)

	local toastListener = GamePackets.toast.listen(function(data)
		showToast(if data.amount > 0 then `+{formatInteger(data.amount)} {data.message}` else data.message)
	end)

	local reviveOfferListener = GamePackets.reviveOffer.listen(function(data)
		openReviveModal(
			data.stage,
			data.durationSeconds,
			data.robuxProductId,
			data.robuxPrice,
			data.adRewardProductId
		)
	end)

	local reviveClosedListener = GamePackets.reviveClosed.listen(function(_data)
		closeReviveModal()
	end)

	local treadmillConnection = RunService.RenderStepped:Connect(function()
		if not getSnapshot().isOnTreadmill then
			stopTreadmillRunAnimation()
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid then
			stopTreadmillRunAnimation()
			return
		end

		if humanoid.MoveDirection.Magnitude <= 0.05 then
			playTreadmillRunAnimation(character, humanoid)
		else
			stopTreadmillRunAnimation()
		end
	end)

	sweeper:Add(function()
		GamePackets.profileSnapshot.disconnect(snapshotListener)
		GamePackets.toast.disconnect(toastListener)
		GamePackets.reviveOffer.disconnect(reviveOfferListener)
		GamePackets.reviveClosed.disconnect(reviveClosedListener)
	end)
	sweeper:Add(treadmillConnection)
	sweeper:Add(stopTreadmillRunAnimation)

	task.spawn(function()
		while player.Parent == Players do
			GamePackets.requestSnapshot.send({})
			task.wait(1.5)
		end
	end)
end

return CoreLoopHUDController
