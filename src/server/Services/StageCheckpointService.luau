--!strict
local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local STAGE_TOUCH_DISTANCE = 55
local STAGE_TOUCH_COOLDOWN_SECONDS = 1.5
local REVIVE_ROOT_HEIGHT = 4
local REVIVE_PENDING_GRACE_SECONDS = 120

type PendingRevive = {
	stage: number,
	createdAt: number,
	expiresAt: number,
	targetPath: string,
}

local finishCooldowns: { [Player]: { [number]: number } } = {}
local pendingRevives: { [Player]: PendingRevive } = {}
local zone5Event: RemoteEvent?

local StageCheckpointService = {}

local function resolvePath(path: string): Instance?
	local current: Instance = game
	for segment in string.gmatch(path, "[^%.]+") do
		local nextInstance = current:FindFirstChild(segment)
		if not nextInstance then
			return nil
		end
		current = nextInstance
	end

	return current
end

local function getStagePath(stage: number, partName: string): string
	return `Workspace.Zone{stage}.Mechanics.Stage{stage}{partName}`
end

local function getPlayerFromHit(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end

	return root
end

local function getTargetCFrame(targetPath: string): CFrame?
	local target = resolvePath(targetPath)
	if not target then
		return nil
	end

	if target:IsA("BasePart") then
		return target.CFrame + Vector3.new(0, (target.Size.Y * 0.5) + REVIVE_ROOT_HEIGHT, 0)
	end
	if target:IsA("Model") then
		local _, size = target:GetBoundingBox()
		return target:GetPivot() + Vector3.new(0, (size.Y * 0.5) + REVIVE_ROOT_HEIGHT, 0)
	end

	return nil
end

local function sendToast(player: Player, message: string, amount: number?)
	GamePackets.toast.sendTo({
		kind = "stage",
		message = message,
		amount = amount or 0,
	}, player)
end

local function syncStageAttributes(player: Player)
	local data = DataService.GetData(player)
	local highestCompleted = if data then math.floor((data :: any).HighestCompletedStage or 0) else 0
	player:SetAttribute("HighestCompletedStage", highestCompleted)
	if typeof(player:GetAttribute("CurrentStage")) ~= "number" then
		player:SetAttribute("CurrentStage", math.clamp(highestCompleted + 1, 1, Constants.MAX_CONFIGURED_STAGE))
	end
end

local function setActiveStage(player: Player, stage: number)
	local clampedStage = math.clamp(stage, 0, Constants.MAX_CONFIGURED_STAGE)
	player:SetAttribute("ActiveStage", clampedStage)
	if clampedStage > 0 then
		player:SetAttribute("CurrentStage", clampedStage)
	else
		player:SetAttribute("CurrentStage", 0)
	end
end

local function isTouchNearPart(player: Player, part: BasePart): boolean
	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	return (root.Position - part.Position).Magnitude <= STAGE_TOUCH_DISTANCE
end

local function onStageStartTouched(stage: number, startPart: BasePart, hit: BasePart)
	local player = getPlayerFromHit(hit)
	if not player or not isTouchNearPart(player, startPart) then
		return
	end

	setActiveStage(player, stage)
	syncStageAttributes(player)
end

local function completeStage(player: Player, stage: number): boolean
	local data = DataService.GetData(player)
	if not data then
		sendToast(player, "Data still loading")
		return false
	end

	local dataTable = data :: any
	local previousHighest = math.floor(dataTable.HighestCompletedStage or 0)
	if stage <= previousHighest then
		setActiveStage(player, math.min(stage + 1, Constants.MAX_CONFIGURED_STAGE))
		return false
	end

	dataTable.HighestCompletedStage = stage
	player:SetAttribute("HighestCompletedStage", stage)
	player:SetAttribute("CompletedStage", stage)
	setActiveStage(player, math.min(stage + 1, Constants.MAX_CONFIGURED_STAGE))

	local rewardWins = Constants.STAGE_WINS[stage] or 0
	if rewardWins > 0 then
		ProgressionService.AwardWins(player, rewardWins, "stage")
	else
		ProgressionService.SendSnapshot(player)
	end
	DataService.UpdateLeaderstats(player)

	if stage == 5 and zone5Event then
		local finishPart = resolvePath(getStagePath(stage, "Finish"))
		if finishPart and finishPart:IsA("BasePart") then
			zone5Event:FireClient(player, "Victory", finishPart.Position)
		end
	end

	return true
end

local function onStageFinishTouched(stage: number, finishPart: BasePart, hit: BasePart)
	local player = getPlayerFromHit(hit)
	if not player or not isTouchNearPart(player, finishPart) then
		return
	end

	local now = os.clock()
	local playerCooldowns = finishCooldowns[player]
	if not playerCooldowns then
		playerCooldowns = {}
		finishCooldowns[player] = playerCooldowns
	end
	if now - (playerCooldowns[stage] or 0) < STAGE_TOUCH_COOLDOWN_SECONDS then
		return
	end
	playerCooldowns[stage] = now

	completeStage(player, stage)
end

local function connectTouched(part: BasePart, callback: (BasePart) -> ())
	part.Touched:Connect(function(hit: BasePart)
		if hit:IsA("BasePart") then
			callback(hit)
		end
	end)
end

local function teleportPlayerToPendingRevive(player: Player, pending: PendingRevive): boolean
	local root = getCharacterRoot(player)
	local targetCFrame = getTargetCFrame(pending.targetPath)
	if not root or not targetCFrame then
		return false
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = targetCFrame
	setActiveStage(player, pending.stage)
	pendingRevives[player] = nil
	GamePackets.reviveClosed.sendTo({ reason = "granted" }, player)
	sendToast(player, `Revived at Stage {pending.stage}`)
	return true
end

local function offerRevive(player: Player, stage: number)
	local targetPath = getStagePath(stage, "Start")
	if not resolvePath(targetPath) then
		return
	end

	local now = os.clock()
	pendingRevives[player] = {
		stage = stage,
		createdAt = now,
		expiresAt = now + Constants.REVIVE_PROMPT_SECONDS,
		targetPath = targetPath,
	}

	GamePackets.reviveOffer.sendTo({
		stage = math.clamp(stage, 0, 255),
		durationSeconds = math.clamp(Constants.REVIVE_PROMPT_SECONDS, 0, 255),
		robuxProductId = Constants.REVIVE_PRODUCT_ID,
		robuxPrice = math.clamp(Constants.REVIVE_ROBUX_PRICE, 0, 65535),
		adRewardProductId = Constants.REVIVE_PRODUCT_ID,
	}, player)
end

local function onHumanoidDied(player: Player)
	local activeStage = player:GetAttribute("ActiveStage")
	if typeof(activeStage) ~= "number" or activeStage < 1 or activeStage > Constants.MAX_CONFIGURED_STAGE then
		return
	end

	setActiveStage(player, 0)
	offerRevive(player, activeStage)
end

local function watchCharacter(player: Player, character: Model)
	task.defer(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				onHumanoidDied(player)
			end)
		end
	end)
end

local function handleAdRevive(player: Player, pending: PendingRevive)
	if Constants.REVIVE_PRODUCT_ID <= 0 then
		sendToast(player, "Set revive product id before ads")
		return
	end
	if os.clock() > pending.expiresAt then
		sendToast(player, "Revive expired")
		return
	end

	local success, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(Constants.REVIVE_PRODUCT_ID)
		if Constants.REVIVE_AD_PLACEMENT_ID > 0 then
			return AdService:ShowRewardedVideoAdAsync(player, reward, Constants.REVIVE_AD_PLACEMENT_ID)
		end
		return AdService:ShowRewardedVideoAdAsync(player, reward)
	end)

	if not success then
		sendToast(player, "Ad not available")
		return
	end
	if result ~= Enum.ShowAdResult.ShowCompleted then
		sendToast(player, "Ad not completed")
	end
end

function StageCheckpointService.ProcessReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	if Constants.REVIVE_PRODUCT_ID <= 0 or receiptInfo.ProductId ~= Constants.REVIVE_PRODUCT_ID then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local pending = pendingRevives[player]
	if not pending or os.clock() - pending.createdAt > REVIVE_PENDING_GRACE_SECONDS then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if teleportPlayerToPendingRevive(player, pending) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function StageCheckpointService.Init()
	local existingEvent = ReplicatedStorage:FindFirstChild("Zone5Event")
	if existingEvent and existingEvent:IsA("RemoteEvent") then
		zone5Event = existingEvent
	else
		local event = Instance.new("RemoteEvent")
		event.Name = "Zone5Event"
		event.Parent = ReplicatedStorage
		zone5Event = event
	end
end

function StageCheckpointService.Start()
	for stage = 1, Constants.MAX_CONFIGURED_STAGE do
		local startPart = resolvePath(getStagePath(stage, "Start"))
		local finishPart = resolvePath(getStagePath(stage, "Finish"))

		if startPart and startPart:IsA("BasePart") then
			connectTouched(startPart, function(hit: BasePart)
				onStageStartTouched(stage, startPart, hit)
			end)
		else
			warn(`[StageCheckpointService] Missing Stage{stage}Start`)
		end

		if finishPart and finishPart:IsA("BasePart") then
			connectTouched(finishPart, function(hit: BasePart)
				onStageFinishTouched(stage, finishPart, hit)
			end)
		else
			warn(`[StageCheckpointService] Missing Stage{stage}Finish`)
		end
	end

	GamePackets.requestRevive.listen(function(request, player: Player)
		if typeof(request.method) ~= "string" then
			return
		end

		local pending = pendingRevives[player]
		if not pending then
			sendToast(player, "No revive available")
			return
		end

		if request.method == "ad" then
			handleAdRevive(player, pending)
		elseif request.method == "decline" then
			pendingRevives[player] = nil
			GamePackets.reviveClosed.sendTo({ reason = "declined" }, player)
		end
	end)

	for _, player in Players:GetPlayers() do
		syncStageAttributes(player)
		if player.Character then
			watchCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		syncStageAttributes(player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		finishCooldowns[player] = nil
		pendingRevives[player] = nil
	end)
end

return StageCheckpointService
