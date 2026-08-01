--!strict
--[[
	StageCheckpointService.luau
	Server-side service managing Stage checkpoints (1-15).
	Handles stage progression, Lobby teleports, Revives, Win/x2 Wins pads, and Skip Stage pads.

	Vạch Stage{N}Finish KHÔNG tự trao Wins — nhận thưởng CHỈ qua bộ 3 pad cuối zone
	(WinCollectionPad / DoubleWinCollectionPad / SkipStagePad, xem setupSpecialPads).
	Stage gate (minLv/minWS trong Stages.STAGE_GATES) chỉ còn là GỢI Ý hiển thị trên
	biển báo — không chặn người chơi.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local PathResolver = require(ReplicatedStorage.Shared.Util.PathResolver)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)
local StageFacing = require(ReplicatedStorage.Shared.Util.StageFacing)
local StageLanding = require(ReplicatedStorage.Shared.Util.StageLanding)

local DataService: any = nil
local ProgressionService: any = nil
local AntiCheatService: any = nil
local GamepassService: any = nil

-- Gamepass "Infinite Revives" (249 R$): hồi sinh tại chỗ không giới hạn số lần khi ngã Obby.
-- Chỉ hỏi lúc CHẾT (hiếm) nên gọi thẳng OwnsPass, không cần cache như đường tick/snapshot.
local function ownsInfiniteRevives(player: Player): boolean
	local passId = Constants.GAMEPASS_IDS.InfiniteRevives or 0
	if passId <= 0 or not GamepassService then
		return false
	end
	return GamepassService.OwnsPass(player, passId) == true
end
local zone5Event: RemoteEvent? = nil

local REVIVE_ROOT_HEIGHT = 4
local REVIVE_PENDING_GRACE_SECONDS = 120
local STAGE_TOUCH_DISTANCE = 40.0

-- Xác thực trình tự Start → Finish: tốc độ vượt map tối đa hợp lệ (studs/s) dùng để
-- suy ra thời gian hoàn thành TỐI THIỂU của mỗi stage (slide + gió + fling đều < mức này).
local MAX_LEGIT_TRAVERSAL_SPEED = 450.0
local MIN_STAGE_TIME_FLOOR = 1.5

type PendingRevive = {
	stage: number,
	createdAt: number,
	expiresAt: number,
	robuxPrice: number,
}

local pendingRevives: { [Player]: PendingRevive } = {}

-- Trình tự stage: thời điểm player VÀO stage hiện tại (đổi ActiveStage) + thời gian
-- hoàn thành tối thiểu của từng stage (tính từ khoảng cách Start → Finish).
local stageEnteredAt: { [Player]: number } = {}
local minStageTime: { [number]: number } = {}

-- Purchase tracking tables cho 3 pad cuối zone (Win / x2 Win / Skip)
local pendingDoubleWins: { [Player]: number } = {}
local pendingSkipStage: { [Player]: number } = {}
local lastPadTouchTime: { [Player]: number } = {}

local function sendToast(player: Player, message: string, kind: string?)
	GamePackets.toast.sendTo({
		kind = kind or "stage",
		message = message,
		amount = 0,
	}, player)
end

local function getStagePath(stage: number, childName: string): string
	return `Workspace.Zones.Zone{stage}.Mechanics.Stage{stage}{childName}`
end

local function getTargetCFrame(path: string): CFrame?
	local target = PathResolver.Resolve(path)
	if not target then
		return nil
	end
	if target:IsA("SpawnLocation") then
		return target.CFrame + Vector3.new(0, 4, 0)
	elseif target:IsA("BasePart") then
		return target.CFrame + Vector3.new(0, (target.Size.Y * 0.5) + REVIVE_ROOT_HEIGHT, 0)
	elseif target:IsA("Model") then
		local _, size = target:GetBoundingBox()
		return target:GetPivot() + Vector3.new(0, (size.Y * 0.5) + REVIVE_ROOT_HEIGHT, 0)
	end
	return nil
end

-- Đưa người chơi tới `cframe`, dập tắt vận tốc và báo AntiCheat để không bị giật ngược.
-- Camera là của client: xoay character xong phải gửi snapCamera để client quay camera theo.
local function placePlayer(player: Player, cframe: CFrame): boolean
	local root = CharacterUtil.GetAliveRoot(player)
	if not root then
		return false
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = cframe
	if AntiCheatService then
		AntiCheatService.NoteTeleport(player)
	end
	local look = cframe.LookVector
	pcall(GamePackets.snapCamera.sendTo, { lookX = look.X, lookZ = look.Z }, player)
	return true
end

-- Điểm đáp khi VÀO stage (hồi sinh): giữa bệ Transition{stage-1}To{stage} — xem StageLanding.
-- Stage 1 không có bệ nào (vào từ Lobby) nên vẫn dùng vạch Stage1Start làm fallback.
local function getStageEntryCFrame(stage: number): CFrame?
	local landing = StageLanding.GetEntryCFrame(stage)
	if landing then
		return landing
	end

	local startPart = PathResolver.Resolve(getStagePath(stage, "Start"))
	if not startPart or not startPart:IsA("BasePart") then
		return nil
	end
	local position = startPart.Position + Vector3.new(0, (startPart.Size.Y * 0.5) + REVIVE_ROOT_HEIGHT, 0)
	return StageFacing.Orient(position, stage, startPart.CFrame)
end

-- Nơi đáp sau khi Skip Stage = cửa vào stage kế tiếp = giữa bệ Transition{from}To{from+1}.
local function getTransitionLandingCFrame(fromStage: number): CFrame?
	return StageLanding.GetEntryCFrame(fromStage + 1)
end

local function setActiveStage(player: Player, stage: number)
	local clampedStage = math.clamp(stage, 0, Constants.MAX_CONFIGURED_STAGE)
	if player:GetAttribute("ActiveStage") ~= clampedStage then
		stageEnteredAt[player] = os.clock()
	end
	player:SetAttribute("ActiveStage", clampedStage)
	if clampedStage > 0 then
		player:SetAttribute("CurrentStage", clampedStage)
	else
		player:SetAttribute("CurrentStage", 0)
	end
end

local function syncStageAttributes(player: Player)
	local data = DataService.GetData(player)
	if data then
		local dataTable = data :: any
		player:SetAttribute("HighestCompletedStage", math.floor(dataTable.HighestCompletedStage or 0))
		player:SetAttribute("CompletedStage", math.floor(dataTable.HighestCompletedStage or 0))
	end
end

local function teleportPlayerToLobby(player: Player)
	local targetCFrame = getTargetCFrame("Workspace.Lobby.Spawn.SpawnLocation")
	if not targetCFrame then
		return
	end
	-- Về sảnh luôn quay mặt về cổng Zone 1 — độc lập với orientation của SpawnLocation.
	targetCFrame = StageFacing.Orient(targetCFrame.Position, 1, targetCFrame)
	if not placePlayer(player, targetCFrame) then
		return
	end
	setActiveStage(player, 0)
end

-- Stage gate (minLv/minWS) đã GỠ BỎ hoàn toàn khỏi gameplay: không còn chặn/đá về Lobby.
-- Stages.STAGE_GATES giờ chỉ là dữ liệu GỢI Ý cho biển báo "Recommend: Lv X" và UI.

local function isTouchNearPart(player: Player, part: BasePart): boolean
	local root = CharacterUtil.GetAliveRoot(player)
	if not root then
		return false
	end

	return (root.Position - part.Position).Magnitude <= STAGE_TOUCH_DISTANCE
end

-- Trình tự hợp lệ để ăn Finish/WinPad của stage N:
--   1. ActiveStage == N (đã chạm Start hoặc teleport hợp lệ vào stage N).
--   2. Đã ở trong stage tối thiểu minStageTime[N] giây (không thể tele-hack Start→Finish tức thì).
local function isFinishSequenceValid(player: Player, stage: number): boolean
	local activeStage = player:GetAttribute("ActiveStage")
	if activeStage ~= stage then
		return false
	end

	local enteredAt = stageEnteredAt[player]
	if not enteredAt then
		return false
	end

	return os.clock() - enteredAt >= (minStageTime[stage] or MIN_STAGE_TIME_FLOOR)
end

local function onStageStartTouched(stage: number, startPart: BasePart, hit: BasePart)
	local player = CharacterUtil.GetPlayerFromHit(hit)
	if not player or not isTouchNearPart(player, startPart) then
		return
	end

	setActiveStage(player, stage)
	syncStageAttributes(player)

	-- Đi thẳng vào stage kế mà không đứng lên pad nhận Wins → vẫn ghi nhận đã vượt stage
	-- trước, nhưng KHÔNG báo gì cả: người chơi tự bỏ phần thưởng, không cần thông báo.
	local previousStage = stage - 1
	if previousStage > 0 then
		local data = DataService.GetData(player)
		if data then
			local dataTable = data :: any
			local prevHighest = math.floor(dataTable.HighestCompletedStage or 0)
			if previousStage > prevHighest then
				dataTable.HighestCompletedStage = previousStage
				player:SetAttribute("HighestCompletedStage", previousStage)
				player:SetAttribute("CompletedStage", previousStage)
				DataService.UpdateLeaderstats(player)
			end
		end
	end
end

local function completeStage(player: Player, stage: number): boolean
	local data = DataService.GetData(player)
	if not data then
		sendToast(player, "Data still loading")
		return false
	end

	local dataTable = data :: any
	local previousHighest = math.floor(dataTable.HighestCompletedStage or 0)
	
	-- Save progression
	dataTable.HighestCompletedStage = math.max(previousHighest, stage)
	player:SetAttribute("HighestCompletedStage", dataTable.HighestCompletedStage)
	player:SetAttribute("CompletedStage", dataTable.HighestCompletedStage)
	setActiveStage(player, math.min(stage + 1, Constants.MAX_CONFIGURED_STAGE))

	-- Award wins
	local rewardWins = Constants.STAGE_WINS[stage] or 0
	if stage == 15 then
		rewardWins += Constants.STAGE_15_FIRST_CLEAR_BONUS
	end
	if rewardWins > 0 then
		ProgressionService.AwardWins(player, rewardWins, "stage")
	else
		ProgressionService.SendSnapshot(player)
	end
	DataService.UpdateLeaderstats(player)

	if stage == 5 and zone5Event then
		local finishPart = PathResolver.Resolve(getStagePath(stage, "Finish"))
		if finishPart and finishPart:IsA("BasePart") then
			zone5Event:FireClient(player, "Victory", finishPart.Position)
		end
	end

	return true
end

local function collectNormalWins(player: Player, stage: number)
	completeStage(player, stage)
	sendToast(player, `Collected {Constants.STAGE_WINS[stage]} Wins!`, "stage")
	teleportPlayerToLobby(player)
end

-- Vạch Stage{N}Finish KHÔNG còn gắn Touched trao thưởng: chạm vạch đích không tự nhận
-- Wins/teleport. Người chơi phải CHỦ ĐỘNG bước lên 1 trong 3 pad cuối zone (setupSpecialPads).
-- Part Finish vẫn được giữ lại làm mốc tính minStageTime (chống tele-hack Start→Finish).

-- Mọi part tên `Stage{n}{suffix}` trong zone (có thể nhiều hơn 1).
local function findStageParts(zone: Instance, stage: number, suffix: string): { BasePart }
	local parts: { BasePart } = {}
	local name = `Stage{stage}{suffix}`
	for _, descendant in zone:GetDescendants() do
		if descendant.Name == name and descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function connectTouched(part: BasePart, callback: (BasePart) -> ())
	part.Touched:Connect(function(hit: BasePart)
		callback(hit)
	end)
end

local function onHumanoidDied(player: Player)
	local activeStage = player:GetAttribute("ActiveStage") or 0
	if typeof(activeStage) ~= "number" or activeStage <= 1 then
		return
	end

	setActiveStage(player, 0)
	-- Offer Revive modal
	local now = os.clock()
	pendingRevives[player] = {
		stage = activeStage,
		createdAt = now,
		expiresAt = now + Constants.REVIVE_PROMPT_SECONDS,
		robuxPrice = Constants.REVIVE_ROBUX_PRICE,
	}

	GamePackets.reviveOffer.sendTo({
		stage = math.clamp(activeStage, 0, 255),
		durationSeconds = math.clamp(Constants.REVIVE_PROMPT_SECONDS, 0, 255),
		robuxProductId = Constants.REVIVE_PRODUCT_ID,
		robuxPrice = math.clamp(Constants.REVIVE_ROBUX_PRICE, 0, 65535),
		adRewardProductId = 0,
		freeRevive = ownsInfiniteRevives(player),
	}, player)
end

local function teleportPlayerToPendingRevive(player: Player, pending: PendingRevive): boolean
	local targetCFrame = getStageEntryCFrame(pending.stage)
	if not targetCFrame or not placePlayer(player, targetCFrame) then
		return false
	end
	setActiveStage(player, pending.stage)

	pendingRevives[player] = nil
	GamePackets.reviveClosed.sendTo({ reason = "granted" }, player)
	sendToast(player, `Revived at Stage {pending.stage}`)
	return true
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

local StageCheckpointService = {}

--[[
	Ba pad nằm TRÊN part Transition ở cuối mỗi zone (sau vạch Finish), người chơi
	đã vượt stage đó rồi mới chọn được:

	  WinCollectionPad        → nhận Wins của stage vừa vượt, về Lobby.
	  DoubleWinCollectionPad  → trả Robux, nhận x2 Wins, về Lobby.
	  SkipStagePad            → trả Robux, BỎ QUA luôn stage KẾ TIẾP (N+1),
	                            đáp xuống giữa part Transition{N+1}To{N+2}.

	Đây là đường nhận Wins DUY NHẤT: vạch Finish không tự trao thưởng ở bất kỳ zone nào.
	Zone chưa đặt pad → người chơi vẫn được ghi nhận vượt stage khi chạm Start của stage
	kế (onStageStartTouched) nhưng tự bỏ phần Wins.
]]

local PAD_TOUCH_COOLDOWN_SECONDS = 2.0

local function isPadTouchThrottled(player: Player): boolean
	local now = os.clock()
	if now - (lastPadTouchTime[player] or 0) < PAD_TOUCH_COOLDOWN_SECONDS then
		return true
	end
	lastPadTouchTime[player] = now
	return false
end

-- Pad Handler: gắn Touched vào các part đã dựng sẵn trong Studio (không tạo mới ở đây).
local function setupSpecialPads(stage: number)
	local zonesFolder = Workspace:FindFirstChild("Zones")
	local zone = zonesFolder and zonesFolder:FindFirstChild(`Zone{stage}`)
	if not zone then return end
	local mechanics = zone:FindFirstChild("Mechanics")
	if not mechanics then return end

	-- 1. Nhận Wins thường
	local winPad = mechanics:FindFirstChild("WinCollectionPad")
	if winPad and winPad:IsA("BasePart") then
		winPad.Touched:Connect(function(hit)
			local player = CharacterUtil.GetPlayerFromHit(hit)
			if not player then return end
			if not isTouchNearPart(player, winPad) then return end
			if not isFinishSequenceValid(player, stage) then return end
			if isPadTouchThrottled(player) then return end

			collectNormalWins(player, stage)
		end)
	end

	-- 2. Nhận x2 Wins (trả Robux)
	local x2Pad = mechanics:FindFirstChild("DoubleWinCollectionPad")
	if x2Pad and x2Pad:IsA("BasePart") then
		x2Pad.Touched:Connect(function(hit)
			local player = CharacterUtil.GetPlayerFromHit(hit)
			if not player then return end
			if not isTouchNearPart(player, x2Pad) then return end
			-- Cùng một hàng rào chống gian lận với pad Wins thường: chưa vượt stage
			-- một cách hợp lệ thì không được mở prompt để lấy x2 Wins.
			if not isFinishSequenceValid(player, stage) then return end
			if isPadTouchThrottled(player) then return end

			pendingDoubleWins[player] = stage
			MarketplaceService:PromptProductPurchase(player, Constants.DOUBLE_WINS_PRODUCT_ID)
		end)
	end

	-- 3. Bỏ qua stage kế tiếp (trả Robux)
	local skipPad = mechanics:FindFirstChild("SkipStagePad")
	if skipPad and skipPad:IsA("BasePart") then
		skipPad.Touched:Connect(function(hit)
			local player = CharacterUtil.GetPlayerFromHit(hit)
			if not player then return end
			if not isTouchNearPart(player, skipPad) then return end
			-- Phải đang thực sự ở zone này (chống chạm pad từ xa / sau khi teleport đi nơi khác).
			if player:GetAttribute("ActiveStage") ~= stage then return end
			if stage + 1 > Constants.MAX_CONFIGURED_STAGE then return end
			if isPadTouchThrottled(player) then return end

			pendingSkipStage[player] = stage
			MarketplaceService:PromptProductPurchase(player, Constants.SKIP_STAGE_PRODUCT_ID)
		end)
	end
end

function StageCheckpointService.ProcessReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local productId = receiptInfo.ProductId
	local playerId = receiptInfo.PlayerId
	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if productId == Constants.REVIVE_PRODUCT_ID and Constants.REVIVE_PRODUCT_ID > 0 then
		local pending = pendingRevives[player]
		if not pending or os.clock() - pending.createdAt > REVIVE_PENDING_GRACE_SECONDS then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if teleportPlayerToPendingRevive(player, pending) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	elseif productId == Constants.DOUBLE_WINS_PRODUCT_ID then
		local stage = pendingDoubleWins[player] or player:GetAttribute("ActiveStage") or 1
		local rewardWins = Constants.STAGE_WINS[stage] or 1
		local doubleWins = rewardWins * 2
		
		local data = DataService.GetData(player)
		if data then
			local dataTable = data :: any
			dataTable.HighestCompletedStage = math.max(dataTable.HighestCompletedStage or 0, stage)
			player:SetAttribute("HighestCompletedStage", dataTable.HighestCompletedStage)
			player:SetAttribute("CompletedStage", dataTable.HighestCompletedStage)
		end
		
		ProgressionService.AwardWins(player, doubleWins, "stage_x2")
		DataService.UpdateLeaderstats(player)
		
		sendToast(player, `Collected x2 Wins: +{doubleWins}!`, "stage")
		teleportPlayerToLobby(player)
		
		pendingDoubleWins[player] = nil
		return Enum.ProductPurchaseDecision.PurchaseGranted
	elseif productId == Constants.SKIP_STAGE_PRODUCT_ID then
		-- Pad nằm ở CUỐI zone `padStage` (stage đó đã vượt xong) → cái mua được ở đây
		-- là bỏ qua stage KẾ TIẾP.
		local padStage = pendingSkipStage[player] or player:GetAttribute("ActiveStage") or 1
		local skippedStage = math.min(padStage + 1, Constants.MAX_CONFIGURED_STAGE)

		local data = DataService.GetData(player)
		if data then
			local dataTable = data :: any
			dataTable.HighestCompletedStage = math.max(dataTable.HighestCompletedStage or 0, skippedStage)
			player:SetAttribute("HighestCompletedStage", dataTable.HighestCompletedStage)
			player:SetAttribute("CompletedStage", dataTable.HighestCompletedStage)
		end

		-- Đáp xuống GIỮA Transition{skipped}To{skipped+1} = đúng chỗ vừa vượt stage đó xong.
		local landing = getTransitionLandingCFrame(skippedStage)
		if landing and placePlayer(player, landing) then
			setActiveStage(player, math.min(skippedStage + 1, Constants.MAX_CONFIGURED_STAGE))
		else
			warn(`[StageCheckpointService] Thiếu Transition{skippedStage}To{skippedStage + 1} — trả về Lobby`)
			teleportPlayerToLobby(player)
		end
		syncStageAttributes(player)
		DataService.UpdateLeaderstats(player)

		sendToast(player, `Skipped Stage {skippedStage}!`, "stage")
		pendingSkipStage[player] = nil
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function StageCheckpointService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
	AntiCheatService = ServiceLocator.Find("AntiCheatService")
	GamepassService = ServiceLocator.Find("GamepassService")

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
		setupSpecialPads(stage)
	end

	local zonesFolder = Workspace:FindFirstChild("Zones")
	for stage = 1, Constants.MAX_CONFIGURED_STAGE do
		local zone = zonesFolder and zonesFolder:FindFirstChild(`Zone{stage}`)
		if not zone then
			continue
		end

		-- Một vạch có thể được dựng bằng NHIỀU part cùng tên (Zone 10 có 2 nửa Stage10Finish
		-- ở đỉnh tháp) — phải hook hết, nếu chỉ lấy part đầu thì nửa còn lại thành vạch chết.
		local startParts = findStageParts(zone, stage, "Start")
		local finishParts = findStageParts(zone, stage, "Finish")

		-- Thời gian hoàn thành tối thiểu = khoảng cách Start→Finish / tốc độ vượt map tối đa.
		-- Finish KHÔNG gắn Touched (không tự trao thưởng) nhưng vẫn cần part làm mốc đo.
		if startParts[1] and finishParts[1] then
			local distance = (finishParts[1].Position - startParts[1].Position).Magnitude
			minStageTime[stage] = math.max(MIN_STAGE_TIME_FLOOR, distance / MAX_LEGIT_TRAVERSAL_SPEED)
		end

		if #startParts == 0 then
			warn(`[StageCheckpointService] Missing Stage{stage}Start`)
		end
		for _, startPart in startParts do
			connectTouched(startPart, function(hit: BasePart)
				onStageStartTouched(stage, startPart, hit)
			end)
		end

		if #finishParts == 0 then
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

		if request.method == "decline" then
			pendingRevives[player] = nil
			GamePackets.reviveClosed.sendTo({ reason = "declined" }, player)
			return
		end

		-- Hồi sinh MIỄN PHÍ của gamepass Infinite Revives. Kiểm quyền sở hữu Ở ĐÂY chứ
		-- không tin cờ `freeRevive` đã gửi cho client — client hoàn toàn có thể tự bắn
		-- packet method="free" mà chưa từng mua pass.
		if request.method == "free" then
			if not ownsInfiniteRevives(player) then
				sendToast(player, "Infinite Revives required")
				return
			end
			teleportPlayerToPendingRevive(player, pending)
		end
	end)

	-- TeleportService đặt ActiveStage attribute trực tiếp (không qua setActiveStage) —
	-- lắng nghe attribute để mốc thời gian VÀO stage luôn được stamp đúng.
	local function watchActiveStage(player: Player)
		player:GetAttributeChangedSignal("ActiveStage"):Connect(function()
			stageEnteredAt[player] = os.clock()
		end)
	end

	for _, player in Players:GetPlayers() do
		syncStageAttributes(player)
		watchActiveStage(player)
		if player.Character then
			watchCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		syncStageAttributes(player)
		watchActiveStage(player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingRevives[player] = nil
		pendingDoubleWins[player] = nil
		pendingSkipStage[player] = nil
		lastPadTouchTime[player] = nil
		stageEnteredAt[player] = nil
	end)
end

return StageCheckpointService
