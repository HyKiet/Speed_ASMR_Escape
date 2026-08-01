--!strict
-- Core loop service: tick cộng Speed mỗi 0.35s.
--
-- Gain rules (đơn giản, dễ debug):
--   1. Player phải có nhân vật còn sống.
--   2. Trigger:
--        - Đang đứng trên Treadmill Run model → auto-farm (kể cả đứng im).
--        - HOẶC chạm active MultiplierPad VÀ đang di chuyển (humanoid.MoveDirection > 0).
--   3. amount = activePad.speedPerStep × premiumBucket × cosmeticBucket × rebirthBucket
--   4. XP += amount
--
-- TreadmillService và MultiplierPadService gọi vào để cập nhật session.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GroupChestConfig = require(ReplicatedStorage.Shared.Config.GroupChest)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

type PlayerData = typeof(Constants.DATA_TEMPLATE)

type Session = {
	requestTimes: { [string]: number },
	gamepassMultiplier: number?,
	vipMultiplier: number?,
	autoRebirthOwned: boolean?,
	activePadId: string,
	activePadStep: number,
	treadmillId: string,
	treadmillMultiplier: number,
	isOnTreadmill: boolean,
}

local STUDIO_SPEED_CAP = 1_000_000_000_000_000

local sessions: { [Player]: Session } = {}
local DataService
local PlaytimeService
local FriendService
local GroupChestService
local ServerBoostService
local GamepassService
local RemoteConfigService
local TelemetryService

-- Khai báo trước: `addSpeed` (phía trên) cần gọi, nhưng thân hàm phải nằm dưới
-- `applyRebirth`/`celebrateRebirth`. Gán ở phần AUTO-REBIRTH bên dưới.
local autoRebirthIfEligible: (Player, any) -> ()

local ProgressionService = {}

local function getSession(player: Player): Session
	local existing = sessions[player]
	if existing then
		return existing
	end

	local session: Session = {
		requestTimes = {},
		gamepassMultiplier = nil,
		vipMultiplier = nil,
		activePadId = "pad_1",
		activePadStep = Constants.BASE_SPEED_GAIN,
		treadmillId = "treadmill_1",
		treadmillMultiplier = 1,
		isOnTreadmill = false,
	}
	sessions[player] = session
	return session
end

-- ============================================================================
-- Cosmetic attributes (Trail/Aura render CLIENT-SIDE — xem CosmeticVisualController)
-- ============================================================================

-- Server chỉ đồng bộ id trang bị lên Player attribute; mọi client tự dựng
-- Trail/ParticleEmitter cục bộ. Server không còn tạo instance hiệu ứng vật lý nào.
local function syncCosmeticAttributes(player: Player, data: PlayerData)
	if player:GetAttribute("EquippedTrail") ~= data.EquippedTrail then
		player:SetAttribute("EquippedTrail", data.EquippedTrail)
	end
	if player:GetAttribute("EquippedAura") ~= data.EquippedAura then
		player:SetAttribute("EquippedAura", data.EquippedAura)
	end
end

-- ============================================================================
-- Multipliers
-- ============================================================================

local function isRateLimited(player: Player, key: string): boolean
	local session = getSession(player)
	local now = os.clock()
	local last = session.requestTimes[key] or 0
	if now - last < Constants.NETWORK_RATE_LIMIT_SECONDS then
		return true
	end
	session.requestTimes[key] = now
	return false
end

-- Sở hữu pass: ưu tiên GamepassService (Studio = chưa sở hữu trừ khi mua trong session),
-- fallback gọi thẳng API nếu service chưa nạp.
local function ownsPass(player: Player, passId: number): boolean
	if not passId or passId <= 0 then
		return false
	end
	if GamepassService then
		return GamepassService.OwnsPass(player, passId)
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	return ok and owns == true
end

local function computeGamepassMultiplier(player: Player): number
	local session = getSession(player)
	if session.gamepassMultiplier then
		return session.gamepassMultiplier
	end

	local multiplier = 1
	for _, pass in {
		{ id = Constants.GAMEPASS_IDS.DoubleSpeed, multiplier = 2 },
		{ id = Constants.GAMEPASS_IDS.QuadSpeed, multiplier = 4 },
		{ id = Constants.GAMEPASS_IDS.OctaSpeed, multiplier = 8 },
	} do
		if ownsPass(player, pass.id) then
			multiplier = math.max(multiplier, pass.multiplier)
		end
	end

	session.gamepassMultiplier = multiplier
	return multiplier
end

local function computeVipMultiplier(player: Player): number
	local session = getSession(player)
	if session.vipMultiplier then
		return session.vipMultiplier
	end

	local multiplier = if ownsPass(player, Constants.GAMEPASS_IDS.VIPMembership) then 1.5 else 1
	session.vipMultiplier = multiplier
	return multiplier
end

local function getMaxWalkSpeed(data: PlayerData): number
	return math.max(Constants.DEFAULT_WALK_SPEED, Constants.GetMaxWalkSpeed(data.Level))
end

-- Ma sát địa hình: các zone có mặt sàn "níu chân" (Zone 14 slime) đặt attribute
-- `TerrainDrag` ∈ (0, 1] lên player; đây là NƠI DUY NHẤT nhân nó vào WalkSpeed.
-- Đặt ở đây thay vì để zone tự ghi humanoid.WalkSpeed, vì applyWalkSpeed() được gọi lại
-- mỗi tick (và mỗi lần lên level / đổi Custom Speed) — zone ghi đè sẽ bị xoá ngay sau đó.
-- `data.CustomSpeedLimit` KHÔNG bị đụng tới, nên tốc độ gốc luôn khôi phục nguyên vẹn.
local function getTerrainDrag(player: Player): number
	local drag = player:GetAttribute("TerrainDrag")
	if typeof(drag) ~= "number" then
		return 1
	end
	return math.clamp(drag, 0.05, 1)
end

local function applyWalkSpeed(player: Player, data: PlayerData)
	local humanoid = CharacterUtil.GetCharacterParts(player)
	if not humanoid then
		return
	end

	local maxSpeed = getMaxWalkSpeed(data)
	local custom = math.clamp(data.CustomSpeedLimit, Constants.DEFAULT_WALK_SPEED, maxSpeed)
	data.CustomSpeedLimit = custom
	humanoid.WalkSpeed = custom * getTerrainDrag(player)
end

local function getTreadmillMultiplier(player: Player, _data: PlayerData): number
	local session = getSession(player)
	-- Multiplier CHỈ áp dụng khi ĐANG ĐỨNG trên treadmill (server-validated).
	-- Rời treadmill → về x1, không còn buff vĩnh viễn theo Equipped.
	if not session.isOnTreadmill then
		return 1
	end
	return math.max(1, session.treadmillMultiplier)
end

local function additiveBucket(...: number): number
	local total = 1
	for _, multiplier in { ... } do
		total += math.max(0, multiplier - 1)
	end
	return total
end

local function getMultiplierBreakdown(player: Player, data: PlayerData)
	local treadmillMult = getTreadmillMultiplier(player, data)
	local speedPassMult = computeGamepassMultiplier(player)
	local vipMult = computeVipMultiplier(player)
	local trailMult = Constants.GetTrailMultiplier(data.EquippedTrail)
	local auraMult = Constants.GetAuraMultiplier(data.EquippedAura)
	local rebirthMult = Constants.GetRebirthMultiplier(data.Rebirths)

	local premiumMult = additiveBucket(treadmillMult, speedPassMult, vipMult)
	local cosmeticMult = additiveBucket(trailMult, auraMult)
	
	local playtimeMult = if PlaytimeService then PlaytimeService.GetPlaytimeMultiplier(player) else 1
	local friendsMult = if FriendService then FriendService.GetFriendsMultiplier(player) else 1
	-- Server Boost (Dev Product, toàn server) × Personal Boost (Roulette) — x2 mỗi loại.
	local serverMult = if ServerBoostService then ServerBoostService.GetSpeedMultiplier(player) else 1
	-- Event thời vụ chỉnh từ Roblox Configs — đổi được mà không cần publish lại game.
	-- Không có event thì luôn là 1, nên rổ liveOps giữ nguyên hành vi cũ.
	local eventMult = if RemoteConfigService then RemoteConfigService.GetEventSpeedMultiplier() else 1
	local liveOpsMult = playtimeMult * friendsMult * serverMult * eventMult

	local totalMult = premiumMult * cosmeticMult * rebirthMult * liveOpsMult

	return {
		treadmillMultiplier = treadmillMult,
		speedPassMultiplier = speedPassMult,
		vipMultiplier = vipMult,
		premiumMultiplier = premiumMult,
		trailMultiplier = trailMult,
		auraMultiplier = auraMult,
		cosmeticMultiplier = cosmeticMult,
		rebirthMultiplier = rebirthMult,
		playtimeMultiplier = playtimeMult,
		friendsMultiplier = friendsMult,
		serverMultiplier = serverMult,
		liveOpsMultiplier = liveOpsMult,
		totalMultiplier = totalMult,
	}
end

local function getGainMultiplier(player: Player, data: PlayerData): number
	return getMultiplierBreakdown(player, data).totalMultiplier
end

-- ============================================================================
-- Snapshot
-- ============================================================================

local function buildSnapshot(player: Player, data: PlayerData)
	local session = getSession(player)
	local maxSpeed = getMaxWalkSpeed(data)
	local requiredRebirthLevel = Constants.GetRequiredLevelForRebirth(data.Rebirths)
	local requiredXP = Constants.GetRequiredXP(data.Level)
	local multipliers = getMultiplierBreakdown(player, data)

	return {
		isLoaded = true,
		speed = data.Speed,
		totalWins = data.TotalWins,
		currentRunWins = data.CurrentRunWins,
		streak = math.clamp(math.floor(data.Streak), 0, 65535),
		personalBestDistance = data.PersonalBestDistance,
		personalBestRunWins = data.PersonalBestRunWins,
		totalRuns = math.clamp(math.floor(data.TotalRuns), 0, 4294967295),
		highestCompletedStage = math.clamp(math.floor((data :: any).HighestCompletedStage or 0), 0, 65535),
		level = math.clamp(math.floor(data.Level), 0, 65535),
		xp = data.XP,
		requiredXP = requiredXP,
		rebirths = math.clamp(math.floor(data.Rebirths), 0, 65535),
		maxWalkSpeed = maxSpeed,
		customSpeedLimit = data.CustomSpeedLimit,
		gainMultiplier = multipliers.totalMultiplier,
		treadmillMultiplier = multipliers.treadmillMultiplier,
		speedPassMultiplier = multipliers.speedPassMultiplier,
		vipMultiplier = multipliers.vipMultiplier,
		premiumMultiplier = multipliers.premiumMultiplier,
		trailMultiplier = multipliers.trailMultiplier,
		auraMultiplier = multipliers.auraMultiplier,
		cosmeticMultiplier = multipliers.cosmeticMultiplier,
		rebirthMultiplier = multipliers.rebirthMultiplier,
		playtimeMultiplier = multipliers.playtimeMultiplier,
		friendsMultiplier = multipliers.friendsMultiplier,
		serverMultiplier = multipliers.serverMultiplier,
		liveOpsMultiplier = multipliers.liveOpsMultiplier,
		friendsInServer = if FriendService then FriendService.GetFriendsInServer(player) else 0,
		isOnTreadmill = session.isOnTreadmill,
		canRebirth = data.Level >= requiredRebirthLevel,
		requiredRebirthLevel = math.clamp(requiredRebirthLevel, 0, 65535),
		ownsAutoRebirth = ProgressionService.OwnsAutoRebirth(player),
		autoRebirthEnabled = data.AutoRebirthEnabled ~= false,
		activeTreadmillId = session.treadmillId,
		equippedTrail = data.EquippedTrail,
		equippedAura = data.EquippedAura,
		unlockedTrails = data.UnlockedTrails,
		unlockedAuras = data.UnlockedAuras,
	}
end

local function sendSnapshot(player: Player)
	local data = DataService.GetData(player)
	if not data then
		GamePackets.profileSnapshot.sendTo({
			isLoaded = false, speed = 0, totalWins = 0, currentRunWins = 0, streak = 0,
			personalBestDistance = 0, personalBestRunWins = 0, totalRuns = 0,
			highestCompletedStage = 0, level = 1, xp = 0,
			requiredXP = Constants.GetRequiredXP(1), rebirths = 0,
			maxWalkSpeed = Constants.GetMaxWalkSpeed(1),
			customSpeedLimit = Constants.GetMaxWalkSpeed(1),
			gainMultiplier = 1, treadmillMultiplier = 1, isOnTreadmill = false,
			speedPassMultiplier = 1, vipMultiplier = 1, premiumMultiplier = 1,
			trailMultiplier = 1, auraMultiplier = 1, cosmeticMultiplier = 1, rebirthMultiplier = 1,
			playtimeMultiplier = 1, friendsMultiplier = 1, serverMultiplier = 1, liveOpsMultiplier = 1,
			friendsInServer = 0,
			canRebirth = false, requiredRebirthLevel = Constants.GetRequiredLevelForRebirth(0),
			ownsAutoRebirth = false, autoRebirthEnabled = true,
			activeTreadmillId = "treadmill_1", equippedTrail = "none", equippedAura = "none",
			unlockedTrails = { none = true }, unlockedAuras = { none = true },
		}, player)
		return
	end
	GamePackets.profileSnapshot.sendTo(buildSnapshot(player, data), player)
end

-- ============================================================================
-- Speed gain
-- ============================================================================

local function addSpeed(player: Player, data: PlayerData, amount: number)
	if amount <= 0 then
		return
	end

	local applied = amount
	if RunService:IsStudio() then
		applied = math.max(0, math.min(amount, STUDIO_SPEED_CAP - data.Speed))
	end
	if applied <= 0 then
		applyWalkSpeed(player, data)
		DataService.UpdateLeaderstats(player)
		sendSnapshot(player)
		return
	end

	local previousMaxSpeed = getMaxWalkSpeed(data)
	local wasAtMax = data.CustomSpeedLimit >= previousMaxSpeed

	data.Speed += applied
	data.XP += applied * Constants.XP_CONVERSION_RATE

	-- Bước 2 của funnel: người chơi đã hiểu treadmill dùng để làm gì.
	-- Onboarding() tự chặn lần gọi thứ 2 nên đây chỉ là một phép tra bảng mỗi tick.
	if TelemetryService then
		TelemetryService.Onboarding(player, "FirstSpeed")
	end

	while data.XP >= Constants.GetRequiredXP(data.Level) do
		data.XP -= Constants.GetRequiredXP(data.Level)
		data.Level += 1
	end

	if wasAtMax then
		data.CustomSpeedLimit = getMaxWalkSpeed(data)
	end

	applyWalkSpeed(player, data)
	DataService.UpdateLeaderstats(player)
	sendSnapshot(player)
end

local function tickPlayer(player: Player)
	local data = DataService.GetData(player)
	local humanoid, root = CharacterUtil.GetCharacterParts(player)
	if not data or not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	syncCosmeticAttributes(player, data)

	-- AUTO-REBIRTH kiểm tra ở ĐÂY chứ không phải trong vòng lên level của `addSpeed`.
	-- Bản đầu móc vào lúc lên level và KHÔNG BAO GIỜ chạy trong trường hợp thường gặp
	-- nhất: người chơi ĐÃ vượt mốc từ trước (vừa mua pass, hoặc đang đứng ở Level 120 —
	-- trần World 1 nên không còn lần lên level nào nữa). Đặt ở tick thì mọi đường vào đều
	-- được phủ bằng MỘT nhánh: vừa join, vừa mua pass, vừa bật lại công tắc, vừa lên level.
	-- Chi phí = 1 phép so sánh + 1 lần đọc cache ownership.
	autoRebirthIfEligible(player, data)

	local session = getSession(player)
	local isMoving = humanoid.MoveDirection.Magnitude > 0.05
	local shouldGain = session.isOnTreadmill or isMoving

	if not shouldGain then
		applyWalkSpeed(player, data)
		return
	end

	local amount = session.activePadStep * getGainMultiplier(player, data)
	addSpeed(player, data, amount)
end

local function runTickLoop(player: Player)
	while player.Parent == Players do
		tickPlayer(player)
		task.wait(Constants.SPEED_GAIN_INTERVAL)
	end
end

-- ============================================================================
-- Public API (gọi từ TreadmillService / MultiplierPadService / Stage / Race)
-- ============================================================================

function ProgressionService.SetTreadmillState(player: Player, treadmillId: string, multiplier: number, isOn: boolean)
	local session = getSession(player)
	local stateChanged = session.treadmillId ~= treadmillId or session.treadmillMultiplier ~= multiplier or session.isOnTreadmill ~= isOn

	session.treadmillId = treadmillId
	session.treadmillMultiplier = multiplier
	session.isOnTreadmill = isOn

	if stateChanged then
		-- Attribute replicate tới MỌI client → TreadmillAnimController phát/tắt
		-- hoạt ảnh chạy cho nhân vật này trên tất cả máy (kể cả chính chủ).
		player:SetAttribute("TreadmillFarming", isOn)
		sendSnapshot(player)
	end
end

function ProgressionService.SetActivePad(player: Player, padId: string, speedPerStep: number)
	local session = getSession(player)
	session.activePadId = padId
	session.activePadStep = speedPerStep
end

function ProgressionService.AwardWins(player: Player, amount: number, reason: string?): boolean
	local data = DataService.GetData(player)
	if not data or amount <= 0 then
		return false
	end

	local finalWins = math.max(0, math.floor(amount))
	if GroupChestService and GroupChestService.IsGroupMember(player) then
		finalWins = math.max(1, math.floor(finalWins * GroupChestConfig.WINS_MULTIPLIER))
	end

	-- Wins Boost (server/personal) chỉ áp cho thưởng vượt ải — không nhân đôi gói mua/daily/roulette.
	if ServerBoostService and (reason == "stage" or reason == "stage_x2") then
		finalWins = math.floor(finalWins * ServerBoostService.GetWinsMultiplier(player))
	end

	-- Event thời vụ (Roblox Configs). Cùng phạm vi với Wins Boost: CHỈ thưởng vượt ải, để
	-- không vô tình nhân đôi cả gói Robux đã mua lẫn quà daily/roulette.
	if RemoteConfigService and (reason == "stage" or reason == "stage_x2") then
		finalWins = math.floor(finalWins * RemoteConfigService.GetEventWinsMultiplier())
	end

	data.TotalWins += finalWins
	data.CurrentRunWins += finalWins
	data.PersonalBestRunWins = math.max(data.PersonalBestRunWins, data.CurrentRunWins)
	DataService.UpdateLeaderstats(player)

	if TelemetryService then
		TelemetryService.Economy(player, "Source", finalWins, data.TotalWins, reason or "wins")
		if reason == "stage" or reason == "stage_x2" then
			TelemetryService.Onboarding(player, "FirstStage")
		end
	end

	GamePackets.toast.sendTo({
		kind = reason or "wins",
		message = "Wins earned",
		amount = finalWins,
	}, player)
	sendSnapshot(player)
	return true
end

function ProgressionService.GrantSpeed(player: Player, amount: number): boolean
	local data = DataService.GetData(player)
	if not data or amount <= 0 then
		return false
	end

	addSpeed(player, data, amount)
	return true
end

function ProgressionService.GiveWins(player: Player, baseWins: number): number
	local finalWins = math.max(0, math.floor(baseWins))
	if GroupChestService and GroupChestService.IsGroupMember(player) then
		finalWins = math.max(1, math.floor(finalWins * GroupChestConfig.WINS_MULTIPLIER))
	end

	ProgressionService.AwardWins(player, baseWins, "wins")
	return finalWins
end

local function celebrateRebirth(player: Player, data: PlayerData)
	local multiplier = Constants.GetRebirthMultiplier(data.Rebirths)
	pcall(GamePackets.purchaseCelebration.sendTo, {
		itemName = `REBIRTH {data.Rebirths}!`,
		subtitle = `Permanent x{string.format("%.2g", multiplier)} multiplier — keep grinding!`,
	}, player)
end

-- Xoá cache multiplier gamepass/VIP của session — gọi sau khi mua pass để áp dụng NGAY.
function ProgressionService.RefreshGamepassCache(player: Player)
	local session = getSession(player)
	session.gamepassMultiplier = nil
	session.vipMultiplier = nil
	session.autoRebirthOwned = nil
	sendSnapshot(player)
end

-- Thân của MỌI lần trùng sinh (thủ công / Skip Rebirth / Auto-Rebirth). Trước đây đoạn
-- reset này bị chép ra 2 chỗ; gộp lại để không bao giờ lệch nhau khi đổi luật reset.
local function applyRebirth(player: Player, data: PlayerData)
	data.Speed = 0
	data.Level = 1
	data.XP = 0
	data.Rebirths += 1
	data.CustomSpeedLimit = Constants.GetMaxWalkSpeed(1)
	applyWalkSpeed(player, data)
	DataService.UpdateLeaderstats(player)
	celebrateRebirth(player, data)
	sendSnapshot(player)

	if TelemetryService then
		TelemetryService.Onboarding(player, "FirstRebirth")
		TelemetryService.Custom(player, "Rebirth", data.Rebirths)
	end
end

-- Trùng sinh KHÔNG kiểm tra level (Skip Rebirth product). Trả về false nếu data chưa load.
function ProgressionService.ForceRebirth(player: Player): boolean
	local data = DataService.GetData(player)
	if not data then
		return false
	end
	applyRebirth(player, data)
	return true
end

-- ============================================================================
-- AUTO-REBIRTH (gamepass 99 R$)
-- ============================================================================
-- Chạy NGAY SAU vòng lên level trong addSpeed thay vì một vòng lặp riêng: người chơi đủ
-- điều kiện đúng tick nào là trùng sinh tick đó, không có độ trễ và không tốn thêm loop.
--
-- ⚠️ Phải là VÒNG LẶP, không phải một lần: sau khi reset về Level 1, mốc yêu cầu của lần
-- sau CAO HƠN (50 + rebirths*10) nên bình thường chỉ chạy đúng 1 vòng — nhưng người chơi
-- nhận một cục XP lớn (code/roulette) có thể đủ cho nhiều lần liên tiếp. Chốt trần
-- AUTO_REBIRTH_MAX_CHAIN để một lỗi số học không bao giờ treo server trong vòng vô hạn.
local AUTO_REBIRTH_MAX_CHAIN = 20

-- ⚠️ PHẢI cache theo session: `buildSnapshot` chạy mỗi tick (0.35s) và OwnsPass ngoài
-- Studio là một lệnh gọi web `UserOwnsGamePassAsync`. Không cache = mỗi người chơi bắn
-- ~3 request/giây lên Roblox API, 25 người là ~75 rps — bị rate-limit tức thì.
-- Cache được xoá trong `RefreshGamepassCache` (GamepassService gọi ngay sau khi mua).
function ProgressionService.OwnsAutoRebirth(player: Player): boolean
	local session = getSession(player)
	if session.autoRebirthOwned == nil then
		session.autoRebirthOwned = ownsPass(player, Constants.GAMEPASS_IDS.AutoRebirth or 0)
	end
	return session.autoRebirthOwned == true
end

autoRebirthIfEligible = function(player: Player, data)
	if data.AutoRebirthEnabled == false then
		return
	end
	if not ProgressionService.OwnsAutoRebirth(player) then
		return
	end

	local chain = 0
	while data.Level >= Constants.GetRequiredLevelForRebirth(data.Rebirths) and chain < AUTO_REBIRTH_MAX_CHAIN do
		chain += 1
		applyRebirth(player, data)
	end
end

function ProgressionService.SendSnapshot(player: Player)
	sendSnapshot(player)
end

-- Mở khoá cosmetic KHÔNG tốn Wins (GamepassService gọi sau khi xác nhận sở hữu pass).
-- Trả về true nếu đây là lần mở khoá đầu tiên (để bên gọi quyết định có ăn mừng không).
function ProgressionService.UnlockCosmetic(player: Player, category: string, itemId: string, equip: boolean): boolean
	local data = DataService.GetData(player)
	if not data then
		return false
	end

	local unlocked = if category == "trail" then data.UnlockedTrails else data.UnlockedAuras
	local isNew = unlocked[itemId] ~= true
	unlocked[itemId] = true

	if equip then
		if category == "trail" then
			data.EquippedTrail = itemId
		else
			data.EquippedAura = itemId
		end
	end

	syncCosmeticAttributes(player, data)
	sendSnapshot(player)
	return isNew
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function ProgressionService.Init()
	DataService = ServiceLocator.Get("DataService")
	PlaytimeService = ServiceLocator.Get("PlaytimeService")
	FriendService = ServiceLocator.Get("FriendService")
	GroupChestService = ServiceLocator.Find("GroupChestService")
	ServerBoostService = ServiceLocator.Find("ServerBoostService")
	GamepassService = ServiceLocator.Find("GamepassService")
	RemoteConfigService = ServiceLocator.Find("RemoteConfigService")
	TelemetryService = ServiceLocator.Find("TelemetryService")
end

function ProgressionService.Start()
	GamePackets.requestSnapshot.listen(function(_data, player: Player)
		if isRateLimited(player, "snapshot") then
			return
		end
		sendSnapshot(player)
	end)

	GamePackets.requestCustomSpeed.listen(function(packet, player: Player)
		if isRateLimited(player, "customSpeed") then
			return
		end
		local data = DataService.GetData(player)
		if not data or typeof(packet.walkSpeed) ~= "number" or packet.walkSpeed ~= packet.walkSpeed or math.abs(packet.walkSpeed) == math.huge then
			return
		end
		local maxSpeed = getMaxWalkSpeed(data)
		data.CustomSpeedLimit = math.clamp(math.floor(packet.walkSpeed), Constants.DEFAULT_WALK_SPEED, maxSpeed)
		applyWalkSpeed(player, data)
		sendSnapshot(player)
	end)

	GamePackets.requestRebirth.listen(function(_data, player: Player)
		if isRateLimited(player, "rebirth") then
			return
		end
		local data = DataService.GetData(player)
		if not data then
			return
		end
		local required = Constants.GetRequiredLevelForRebirth(data.Rebirths)
		if data.Level < required then
			return
		end
		applyRebirth(player, data)
	end)

	GamePackets.requestAutoRebirthToggle.listen(function(packet, player: Player)
		if isRateLimited(player, "autoRebirth") then
			return
		end
		local data = DataService.GetData(player)
		if not data then
			return
		end
		-- Chưa có pass thì không cho bật (client cũng ẩn, đây là chốt chặn server).
		if packet.enabled and not ProgressionService.OwnsAutoRebirth(player) then
			return
		end
		data.AutoRebirthEnabled = packet.enabled == true
		-- Bật lại lúc đang thừa level ⇒ trùng sinh ngay, khỏi bắt người chơi chờ tick sau.
		if data.AutoRebirthEnabled then
			autoRebirthIfEligible(player, data)
		end
		sendSnapshot(player)
	end)

	GamePackets.requestCosmeticAction.listen(function(request, player: Player)
		if isRateLimited(player, "cosmeticAction") then
			return
		end
		local data = DataService.GetData(player)
		if not data or typeof(request.category) ~= "string" or typeof(request.itemId) ~= "string" then
			return
		end

		local catalog = if request.category == "trail" then Constants.TRAILS elseif request.category == "aura" then Constants.AURAS else nil
		if not catalog then
			return
		end

		local config
		for _, entry in catalog do
			if entry.id == request.itemId then
				config = entry
				break
			end
		end
		if not config then
			return
		end

		local unlocked = if request.category == "trail" then data.UnlockedTrails else data.UnlockedAuras
		local wasUnlocked = unlocked[request.itemId] == true
		if not unlocked[request.itemId] then
			-- Item chỉ rơi từ Speed Roulette (Frozen Bloom): không có đường mua nào cả.
			-- `priceWins` = 999.999.999 vốn là chốt chặn, nhưng whale hoàn toàn có thể
			-- chạm mốc đó ⇒ phải chặn tường minh, đừng dựa vào con số.
			if config.spinOnly then
				return
			end

			-- Item Robux-only: KHÔNG bao giờ bán bằng Wins, kể cả khi client gửi packet giả.
			-- Việc mở khoá chỉ đi qua GamepassService sau khi Roblox xác nhận thanh toán.
			if config.robuxOnly then
				if GamepassService then
					GamepassService.PromptCosmeticPurchase(player, request.category, request.itemId)
				end
				return
			end

			if data.TotalWins < config.priceWins then
				GamePackets.toast.sendTo({ kind = "cosmetic", message = "Not enough Wins", amount = 0 }, player)
				return
			end
			data.TotalWins -= config.priceWins
			unlocked[request.itemId] = true
		end

		if request.category == "trail" then
			data.EquippedTrail = if data.EquippedTrail == request.itemId then "none" else request.itemId
		else
			data.EquippedAura = if data.EquippedAura == request.itemId then "none" else request.itemId
		end
		syncCosmeticAttributes(player, data)

		DataService.UpdateLeaderstats(player)
		GamePackets.toast.sendTo({
			kind = "cosmetic",
			message = if wasUnlocked then "Equipped" else "Purchased",
			amount = 0,
		}, player)
		sendSnapshot(player)
	end)

	-- Trail/Aura render hoàn toàn client-side; server chỉ cần attribute (đồng bộ trong tick).
	--
	-- ⚠️ KHÔNG spawn runTickLoop ở đây. Trước đây có một vòng `for player in GetPlayers()`
	-- ngay chỗ này, rồi `bindPlayer` bên dưới lại spawn thêm một vòng nữa cho ĐÚNG những
	-- player đó ⇒ ai đã có mặt lúc Start chạy sẽ có HAI vòng tick, tức farm Speed GẤP ĐÔI
	-- suốt phiên. Trong Studio dính 100% (player luôn tồn tại trước khi service Start).
	local function bindPlayer(player: Player)
		task.spawn(runTickLoop, player)
		-- Vào/ra vùng slime phải đổi tốc độ NGAY, không đợi tick kế tiếp.
		player:GetAttributeChangedSignal("TerrainDrag"):Connect(function()
			local data = DataService.GetData(player)
			if data then
				applyWalkSpeed(player, data)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return ProgressionService
