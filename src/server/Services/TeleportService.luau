--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local DataService = require(script.Parent.DataService)

local TELEPORT_COOLDOWN_SECONDS = 1.25
local TELEPORT_ROOT_HEIGHT = 3
local TELEPORT_FACING_CORRECTION = CFrame.Angles(0, math.pi, 0)

type DestinationConfig = {
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

local lastTeleportTimeByPlayer: { [Player]: number } = {}
local destinationById: { [string]: DestinationConfig } = {}
local destinationByProductId: { [number]: DestinationConfig } = {}

local TeleportService = {}

local function isTeleportDestinationEnabled(destination: DestinationConfig): boolean
	return destination.targetPath ~= ""
end

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

local function getDestinationCFrame(destination: DestinationConfig): CFrame?
	local target = resolvePath(destination.targetPath)
	if not target then
		return nil
	end

	if target:IsA("BasePart") then
		return (target.CFrame + Vector3.new(0, (target.Size.Y * 0.5) + TELEPORT_ROOT_HEIGHT, 0))
			* TELEPORT_FACING_CORRECTION
	end
	if target:IsA("Model") then
		local _, size = target:GetBoundingBox()
		return (target:GetPivot() + Vector3.new(0, (size.Y * 0.5) + TELEPORT_ROOT_HEIGHT, 0))
			* TELEPORT_FACING_CORRECTION
	end

	return nil
end

local function teleportPlayer(player: Player, destination: DestinationConfig)
	local now = os.clock()
	if now - (lastTeleportTimeByPlayer[player] or 0) < TELEPORT_COOLDOWN_SECONDS then
		return
	end
	lastTeleportTimeByPlayer[player] = now

	local root = getCharacterRoot(player)
	local destinationCFrame = getDestinationCFrame(destination)
	if not root or not destinationCFrame then
		return
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = destinationCFrame
	player:SetAttribute("CurrentTeleportDestination", destination.id)
	if destination.id == "lobby" or destination.id == "training" then
		player:SetAttribute("ActiveStage", 0)
	else
		local stageText = destination.id:match("^stage_(%d+)$")
		local stageNumber = stageText and tonumber(stageText)
		if stageNumber then
			player:SetAttribute("ActiveStage", stageNumber)
			player:SetAttribute("CurrentStage", stageNumber)
		end
	end

	GamePackets.toast.sendTo({
		kind = "teleport",
		message = `Teleported to {destination.name}`,
		amount = 0,
	}, player)
end

local function tryPayWins(player: Player, destination: DestinationConfig): boolean
	local data = DataService.GetData(player)
	if not data then
		GamePackets.toast.sendTo({
			kind = "teleport",
			message = "Data still loading",
			amount = 0,
		}, player)
		return false
	end

	local priceWins = math.max(0, destination.priceWins)
	if data.TotalWins < priceWins then
		GamePackets.toast.sendTo({
			kind = "teleport",
			message = "Not enough Wins",
			amount = 0,
		}, player)
		return false
	end

	data.TotalWins -= priceWins
	DataService.UpdateLeaderstats(player)
	return true
end

function TeleportService.ProcessReceipt(receiptInfo: { PlayerId: number, ProductId: number }): Enum.ProductPurchaseDecision
	local destination = destinationByProductId[receiptInfo.ProductId]
	if not destination then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local root = getCharacterRoot(player)
	local destinationCFrame = getDestinationCFrame(destination)
	if not root or not destinationCFrame then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	teleportPlayer(player, destination)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function TeleportService.Init()
	table.clear(destinationById)
	table.clear(destinationByProductId)
	for _, destination in Constants.TELEPORT_DESTINATIONS do
		if isTeleportDestinationEnabled(destination) then
			destinationById[destination.id] = destination
		end
		if isTeleportDestinationEnabled(destination) and destination.productId > 0 then
			destinationByProductId[destination.productId] = destination
		end
	end
end

function TeleportService.Start()
	GamePackets.requestTeleport.listen(function(request, player: Player)
		if typeof(request.destinationId) ~= "string" then
			return
		end
		if typeof(request.paymentKind) ~= "string" then
			return
		end

		local destination = destinationById[request.destinationId]
		if not destination then
			return
		end

		if request.paymentKind ~= "wins" then
			GamePackets.toast.sendTo({
				kind = "teleport",
				message = "Choose Wins or Robux",
				amount = 0,
			}, player)
			return
		end

		if not tryPayWins(player, destination) then
			return
		end

		teleportPlayer(player, destination)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTeleportTimeByPlayer[player] = nil
	end)
end

return TeleportService
