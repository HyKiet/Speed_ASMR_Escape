--!strict
-- Dịch chuyển nhanh đến Lobby/Stage/Training, thanh toán bằng Wins hoặc Robux.
-- Player được TỰ DO teleport: không còn chặn theo Level/WalkSpeed (Stage Gate đã gỡ bỏ).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local PathResolver = require(ReplicatedStorage.Shared.Util.PathResolver)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)
local StageFacing = require(ReplicatedStorage.Shared.Util.StageFacing)
local StageLanding = require(ReplicatedStorage.Shared.Util.StageLanding)

local TELEPORT_COOLDOWN_SECONDS = 1.25
local TELEPORT_ROOT_HEIGHT = 3
local TELEPORT_FACING_CORRECTION = CFrame.Angles(0, math.pi, 0)

type DestinationConfig = Constants.TeleportDestinationConfig

local lastTeleportTimeByPlayer: { [Player]: number } = {}
local destinationById: { [string]: DestinationConfig } = {}
local destinationByProductId: { [number]: DestinationConfig } = {}

local DataService
local AntiCheatService: any

local TeleportService = {}

local function isTeleportDestinationEnabled(destination: DestinationConfig): boolean
	return destination.targetPath ~= ""
end

local function getStageNumber(destination: DestinationConfig): number?
	local stageText = destination.id:match("^stage_(%d+)$")
	return if stageText then tonumber(stageText) else nil
end

local function getDestinationCFrame(destination: DestinationConfig): CFrame?
	-- Điểm đến là một stage → LUÔN đáp giữa bệ Transition dẫn vào stage đó, giống hệt
	-- hồi sinh và Skip Stage (xem StageLanding). `targetPath` chỉ còn là fallback cho
	-- Stage 1 (không có bệ) và cho trường hợp bệ chưa stream về.
	local stageNumber = getStageNumber(destination)
	if stageNumber then
		local landing = StageLanding.GetEntryCFrame(stageNumber)
		if landing then
			return landing
		end
	end

	local target = PathResolver.Resolve(destination.targetPath)
	if not target then
		return nil
	end

	local baseCFrame: CFrame
	local liftedPosition: Vector3
	if target:IsA("BasePart") then
		baseCFrame = target.CFrame
		liftedPosition = target.Position + Vector3.new(0, (target.Size.Y * 0.5) + TELEPORT_ROOT_HEIGHT, 0)
	elseif target:IsA("Model") then
		local _, size = target:GetBoundingBox()
		baseCFrame = target:GetPivot()
		liftedPosition = baseCFrame.Position + Vector3.new(0, (size.Y * 0.5) + TELEPORT_ROOT_HEIGHT, 0)
	else
		return nil
	end

	-- Điểm đến là một stage → quay mặt về phía zone phía trước (hình học, không xoay cứng).
	local stage = getStageNumber(destination)
	if stage then
		return StageFacing.Orient(liftedPosition, stage, baseCFrame)
	end

	-- Lobby: quay mặt về cổng Zone 1 (các zone luôn "phía trước" người chơi khi về sảnh).
	if destination.id == "lobby" then
		return StageFacing.Orient(liftedPosition, 1, baseCFrame)
	end

	-- Training: giữ nguyên hướng cũ (xoay 180° so với part đích).
	return (CFrame.new(liftedPosition) * (baseCFrame - baseCFrame.Position)) * TELEPORT_FACING_CORRECTION
end

local function teleportPlayer(player: Player, destination: DestinationConfig)
	local now = os.clock()
	if now - (lastTeleportTimeByPlayer[player] or 0) < TELEPORT_COOLDOWN_SECONDS then
		return
	end
	lastTeleportTimeByPlayer[player] = now

	local root = CharacterUtil.GetAliveRoot(player)
	local destinationCFrame = getDestinationCFrame(destination)
	if not root or not destinationCFrame then
		return
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = destinationCFrame
	if AntiCheatService then
		AntiCheatService.NoteTeleport(player)
	end
	-- Camera là của client — xoay character xong phải bảo client snap camera theo.
	local look = destinationCFrame.LookVector
	pcall(GamePackets.snapCamera.sendTo, { lookX = look.X, lookZ = look.Z }, player)
	player:SetAttribute("CurrentTeleportDestination", destination.id)
	local stageNumber = getStageNumber(destination)
	if stageNumber then
		player:SetAttribute("ActiveStage", stageNumber)
		player:SetAttribute("CurrentStage", stageNumber)
	else
		player:SetAttribute("ActiveStage", 0)
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

	local root = CharacterUtil.GetAliveRoot(player)
	local destinationCFrame = getDestinationCFrame(destination)
	if not root or not destinationCFrame then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	teleportPlayer(player, destination)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function TeleportService.Init()
	DataService = ServiceLocator.Get("DataService")
	AntiCheatService = ServiceLocator.Find("AntiCheatService")

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
