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
local TelemetryService: any = nil

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
-- Throttle chạm pad — khoá theo TỪNG PAD, không phải theo player.
-- BUG cũ (user: "bệ nhận win lâu lâu không hoạt động"): bảng này từng là {[Player]: number}
-- dùng chung cho cả 3 pad. Ba pad nằm sát nhau trên cùng bệ Transition, nên chỉ cần lướt
-- qua x2Pad hay SkipStagePad là WinCollectionPad bị khoá 2 giây — bấm vào không ra gì, không
-- báo lỗi. Đúng kiểu "lúc được lúc không".
local lastPadTouchTime: { [Player]: { [string]: number } } = {}
-- Throttle riêng cho thông báo TỪ CHỐI, để không spam khi người chơi đứng lì trên pad.
local lastPadDenyAt: { [Player]: number } = {}

local function sendToast(player: Player, message: string, kind: string?, amount: number?)
	GamePackets.toast.sendTo({
		kind = kind or "stage",
		message = message,
		amount = amount or 0,
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

-- BUG 2026-08-07 (user báo: "ăn Wins ở WinCollectionPad/DoubleWinCollectionPad xong không
-- teleport về lobby"). Hàm này tra cứng `Workspace.Lobby.Spawn.SpawnLocation`, nhưng trong map
-- SpawnLocation nằm ở `Workspace.Spawn.SpawnLocation` — NGOÀI Lobby. PathResolver trả nil và
-- `return` ngay ⇒ Wins vẫn được trao, toast vẫn hiện, chỉ mỗi teleport là không xảy ra, và
-- KHÔNG có một dòng log nào. Giờ dò qua PathResolver.FindLobbySpawn (nhiều phương án + quét
-- SpawnLocation làm chốt chặn) và warn to nếu trượt hết.
local function teleportPlayerToLobby(player: Player)
	local spawnPart = PathResolver.FindLobbySpawn()
	if not spawnPart then
		warn("[StageCheckpointService] KHÔNG tìm thấy SpawnLocation nào — không thể đưa về Lobby")
		return
	end
	local targetCFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
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

--[[
	Trình tự hợp lệ để ăn WinPad/x2/Skip của stage N:
	  1. ActiveStage == N (đã chạm Start hoặc teleport vào stage N), HOẶC N+1 — xem dưới.
	  2. Đã ở trong stage tối thiểu minStageTime[N] giây (không tele-hack Start→Finish tức thì).

	Vì sao chấp nhận cả N+1: bộ 3 pad của zone N nằm TRÊN bệ Transition N→N+1, mà đó cũng
	chính là chỗ teleport tới stage N+1 thả người chơi xuống (StageLanding.GetEntryCFrame).
	Teleport đặt ActiveStage = N+1 nên nếu chỉ nhận đúng N thì vừa đáp xuống là cả 3 pad
	dưới chân đều câm — người chơi tưởng game hỏng.

	ĐÁNH ĐỔI ĐÃ BIẾT (user chốt 2026-08-03): mở như vậy nghĩa là mua teleport tới stage N+1
	là nhận được Wins của stage N mà không phải chạy. Cân bằng nằm ở GIÁ teleport, không
	nằm ở đây — giá Wins của destination stage N+1 phải > Constants.STAGE_WINS[N], nếu không
	người chơi lặp teleport để farm Wins vô hạn.
]]
local function isFinishSequenceValid(player: Player, stage: number): boolean
	local activeStage = player:GetAttribute("ActiveStage")
	if activeStage ~= stage and activeStage ~= stage + 1 then
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

-- Trả về (thành công, SỐ WINS thực nhận) — số SAU hệ số, dùng cho màn ăn mừng ở client.
local function completeStage(player: Player, stage: number): (boolean, number)
	local data = DataService.GetData(player)
	if not data then
		sendToast(player, "Data still loading")
		return false, 0
	end

	local dataTable = data :: any
	local previousHighest = math.floor(dataTable.HighestCompletedStage or 0)

	-- Save progression
	dataTable.HighestCompletedStage = math.max(previousHighest, stage)
	player:SetAttribute("HighestCompletedStage", dataTable.HighestCompletedStage)
	player:SetAttribute("CompletedStage", dataTable.HighestCompletedStage)
	setActiveStage(player, math.min(stage + 1, Constants.MAX_CONFIGURED_STAGE))
	local questService = ServiceLocator.Find("QuestService")
	if questService then
		questService.Record(player, "stage_clear", 1)
	end

	-- Award wins. Không còn bonus lần đầu Stage 15 (gỡ 2026-09-06, GDD 3.0 §4.2): bảng
	-- STAGE_WINS mới trả 400.000 cho Stage 15, nhiều hơn hẳn 150.000 + 50.000 bonus của bản cũ.
	local rewardWins = Constants.STAGE_WINS[stage] or 0
	-- Con số trả về là số SAU hệ số (x2 Wins Boost, buff group, event) — đó mới là số được
	-- phép hiện lên thẻ ăn mừng. Xem ghi chú ở `ProgressionService.AwardWins`.
	if rewardWins > 0 then
		local _, finalWins = ProgressionService.AwardWins(player, rewardWins, "stage")
		rewardWins = finalWins
	else
		ProgressionService.SendSnapshot(player)
	end
	DataService.UpdateLeaderstats(player)
	if stage == 1 and TelemetryService then
		TelemetryService.CoreLoopV2(player, "Stage1Clear")
	end
	if stage == 1 then
		local nextGate = Constants.GetStageGate(2)
		if nextGate then
			local currentWalkSpeed = Constants.GetMaxWalkSpeed(dataTable.Level or 1)
			GamePackets.nextStageBanner.sendTo({
				stage = 2,
				rewardWins = Constants.STAGE_WINS[2] or 0,
				requiredWalkSpeed = nextGate.minWS,
				missingWalkSpeed = math.max(0, nextGate.minWS - currentWalkSpeed),
			}, player)
		end
	end

	if stage == 5 and zone5Event then
		local finishPart = PathResolver.Resolve(getStagePath(stage, "Finish"))
		if finishPart and finishPart:IsA("BasePart") then
			zone5Event:FireClient(player, "Victory", finishPart.Position)
		end
	end

	return true, rewardWins
end

local function collectNormalWins(player: Player, stage: number)
	local ok, awarded = completeStage(player, stage)
	if not ok then
		return
	end
	-- kind "wins_collected" → client chạy WinsFlight (thẻ giữa màn hình bay về huy hiệu Wins)
	-- thay cho toast thường. Xem HUDController.
	sendToast(player, "Wins", "wins_collected", awarded)
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

	-- Ghi TRƯỚC các early-return dưới đây: chết ngoài stage (rơi ở lobby, ngã ở đoạn
	-- dẫn) cũng là trải nghiệm xấu của người mới — bỏ qua chúng là giấu đi đúng cái
	-- đang giết phiên chơi đầu tiên.
	if TelemetryService then
		TelemetryService.Death(player, if typeof(activeStage) == "number" then activeStage else 0)
	end

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
local PAD_DENY_TOAST_COOLDOWN = 3.0

-- `padId` = định danh RIÊNG của từng pad ("win:3", "x2:3", …). Xem ghi chú ở `lastPadTouchTime`.
local function isPadTouchThrottled(player: Player, padId: string): boolean
	local now = os.clock()
	local perPad = lastPadTouchTime[player]
	if not perPad then
		perPad = {}
		lastPadTouchTime[player] = perPad
	end
	if now - (perPad[padId] or 0) < PAD_TOUCH_COOLDOWN_SECONDS then
		return true
	end
	perPad[padId] = now
	return false
end

-- Từ chối pad thì PHẢI nói vì sao. Bản cũ `return` lặng lẽ ở cả 3 cửa kiểm tra, nên người
-- chơi đứng trên bệ bấm mãi không ra gì và kết luận là game hỏng — đúng như user mô tả.
local function denyPad(player: Player, reason: string)
	local now = os.clock()
	if now - (lastPadDenyAt[player] or 0) < PAD_DENY_TOAST_COOLDOWN then
		return
	end
	lastPadDenyAt[player] = now
	sendToast(player, reason)
end

--[[
	ĐĂNG KÝ PAD + DÒ THEO VỊ TRÍ (2026-08-07).

	Bản cũ chỉ dựa vào `Touched`. Ở walkspeed cao bước physics nhảy qua hẳn tấm pad nên
	Touched không nổ — cùng họ lỗi với bẫy zone (xem shared/Util/TrapSweep). Giờ mọi pad
	được ghi vào registry và một vòng dò 30Hz kiểm tra người chơi có ĐANG ĐỨNG TRÊN pad
	không; `Touched` vẫn giữ để bắt các pad bị xoay/hình lạ mà phép so hộp bỏ sót.

	30Hz chọn theo số đo: ở 250 WS người chơi đi 8.3 studs mỗi tick, còn cửa sổ của một pad
	(nửa bề rộng ~4 + nới mép 3, tính cả hai bên) là ~14 studs ⇒ không thể lọt qua.
]]
type PadKind = "win" | "x2" | "skip"
type PadEntry = { part: BasePart, kind: PadKind, stage: number, id: string }

local padRegistry: { PadEntry } = {}
local startRegistry: { { part: BasePart, stage: number } } = {}

local PAD_EDGE_SLACK = 3.0
local PAD_ABOVE = 9.0
local PAD_BELOW = 4.0

local function isStandingOnPad(root: BasePart, pad: BasePart): boolean
	local p = root.Position
	local half = pad.Size * 0.5
	local dy = p.Y - (pad.Position.Y + half.Y)
	return math.abs(p.X - pad.Position.X) <= half.X + PAD_EDGE_SLACK
		and math.abs(p.Z - pad.Position.Z) <= half.Z + PAD_EDGE_SLACK
		and dy <= PAD_ABOVE
		and dy >= -PAD_BELOW
end

--[[
	Một người chơi kích hoạt pad. Dùng CHUNG cho cả `Touched` lẫn vòng dò vị trí, nên hai
	đường vào không thể lệch luật nhau.
]]
local function activatePad(player: Player, entry: PadEntry)
	local stage = entry.stage

	if entry.kind == "skip" then
		-- Phải đang thực sự ở zone này (chống chạm pad từ xa / sau khi teleport đi nơi khác).
		-- Nhận cả stage+1 vì pad nằm trên bệ Transition — chỗ teleport tới stage kế thả
		-- người chơi xuống (cùng lý do với isFinishSequenceValid).
		local activeStage = player:GetAttribute("ActiveStage")
		if activeStage ~= stage and activeStage ~= stage + 1 then
			denyPad(player, "Finish this stage first")
			return
		end
		if stage + 1 > Constants.MAX_CONFIGURED_STAGE then
			denyPad(player, "No stage left to skip")
			return
		end
		if isPadTouchThrottled(player, entry.id) then
			return
		end
		pendingSkipStage[player] = stage
		MarketplaceService:PromptProductPurchase(player, Constants.SKIP_STAGE_PRODUCT_ID)
		return
	end

	-- win + x2 dùng chung hàng rào chống gian lận: chưa vượt stage hợp lệ thì không được
	-- nhận Wins, cũng không được mở prompt mua x2.
	if not isFinishSequenceValid(player, stage) then
		local activeStage = player:GetAttribute("ActiveStage")
		if activeStage ~= stage and activeStage ~= stage + 1 then
			denyPad(player, `Run Stage {stage} first`)
		else
			denyPad(player, "Too fast — run the stage properly")
		end
		return
	end
	if isPadTouchThrottled(player, entry.id) then
		return
	end

	if entry.kind == "win" then
		collectNormalWins(player, stage)
	else
		pendingDoubleWins[player] = stage
		MarketplaceService:PromptProductPurchase(player, Constants.DOUBLE_WINS_PRODUCT_ID)
	end
end

-- Pad Handler: gắn Touched + ghi registry cho vòng dò vị trí (part đã dựng sẵn trong Studio).
local function setupSpecialPads(stage: number)
	local zonesFolder = Workspace:FindFirstChild("Zones")
	local zone = zonesFolder and zonesFolder:FindFirstChild(`Zone{stage}`)
	if not zone then
		return
	end
	local mechanics = zone:FindFirstChild("Mechanics")
	if not mechanics then
		return
	end

	local pads: { { name: string, kind: PadKind } } = {
		{ name = "WinCollectionPad", kind = "win" :: PadKind },
		{ name = "DoubleWinCollectionPad", kind = "x2" :: PadKind },
		{ name = "SkipStagePad", kind = "skip" :: PadKind },
	}

	for _, spec in pads do
		local part = mechanics:FindFirstChild(spec.name)
		if part and part:IsA("BasePart") then
			local entry: PadEntry = {
				part = part,
				kind = spec.kind,
				stage = stage,
				id = `{spec.kind}:{stage}`,
			}
			table.insert(padRegistry, entry)
			part.Touched:Connect(function(hit)
				local player = CharacterUtil.GetPlayerFromHit(hit)
				if player and isTouchNearPart(player, part) then
					activatePad(player, entry)
				end
			end)
		end
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
		local questService = ServiceLocator.Find("QuestService")
		if questService then
			questService.Record(player, "stage_clear", 1)
		end

		-- Cùng lý do như `completeStage`: thẻ ăn mừng phải đọc số SAU hệ số, không phải số gốc.
		local _, finalWins = ProgressionService.AwardWins(player, doubleWins, "stage_x2")
		DataService.UpdateLeaderstats(player)

		sendToast(player, "Wins", "wins_collected", finalWins)
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
	TelemetryService = ServiceLocator.Find("TelemetryService")

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
			table.insert(startRegistry, { part = startPart, stage = stage })
			connectTouched(startPart, function(hit: BasePart)
				onStageStartTouched(stage, startPart, hit)
			end)
		end

		if #finishParts == 0 then
			warn(`[StageCheckpointService] Missing Stage{stage}Finish`)
		end
	end

	--[[
		VÒNG DÒ VỊ TRÍ 30Hz — chữa tận gốc "bệ nhận win lâu lâu không hoạt động".

		Ba nguyên nhân độc lập của bug đó, cái nào cũng IM LẶNG:
		  1. Throttle pad dùng chung cho cả 3 pad ⇒ lướt qua pad này là khoá pad kia 2 giây.
		     (đã sửa: khoá theo từng pad — xem `lastPadTouchTime`)
		  2. `Touched` của chính pad bị bước physics nhảy qua khi chạy nhanh.
		  3. NẶNG NHẤT: `Stage{N}Start.Touched` bị nhảy qua ⇒ `ActiveStage` không bao giờ
		     thành N ⇒ `isFinishSequenceValid` từ chối, và người chơi vừa chạy hết cả zone
		     xong đứng trên bệ bấm mãi không ra gì. Chạy càng nhanh càng chắc dính.

		Vòng này chữa (2) và (3) bằng cách hỏi VỊ TRÍ thay vì chờ sự kiện va chạm — cùng
		học thuyết đã dùng cho bẫy zone (xem shared/Util/TrapSweep). `Touched` vẫn giữ
		nguyên để bắt các pad bị xoay mà phép so hộp AABB bỏ sót.

		Chi phí: 30Hz × người chơi × (~15 vạch Start + ~45 pad). Toàn phép so số vô hướng,
		không raycast, không cấp phát — không đáng kể.
	]]
	task.spawn(function()
		while true do
			task.wait(1 / 30)
			for _, player in Players:GetPlayers() do
				local root = CharacterUtil.GetAliveRoot(player)
				if not root then
					continue
				end
				local pos = root.Position

				-- Vạch Start: bán kính rộng như `isTouchNearPart` (40 studs). Ở 250 WS người
				-- chơi đi 8.3 studs/tick nên không thể xuyên qua vùng này mà không bị thấy.
				for _, entry in startRegistry do
					if (entry.part.Position - pos).Magnitude <= STAGE_TOUCH_DISTANCE then
						if player:GetAttribute("ActiveStage") ~= entry.stage then
							onStageStartTouched(entry.stage, entry.part, root)
						end
					end
				end

				for _, entry in padRegistry do
					if isStandingOnPad(root, entry.part) then
						activatePad(player, entry)
					end
				end
			end
		end
	end)

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
		lastPadDenyAt[player] = nil
		stageEnteredAt[player] = nil
	end)
end

return StageCheckpointService
