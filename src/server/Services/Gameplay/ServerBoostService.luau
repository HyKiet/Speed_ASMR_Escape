--!strict
--[[
	ServerBoostService.luau
	Quản lý Boost x2 Speed/Wins:
	  - SERVER BOOST (Dev Product): áp dụng toàn máy chủ 10 phút, mua chồng → cộng dồn thời gian.
	  - PERSONAL BOOST (trúng Roulette / code): áp dụng riêng 1 player.
	Multiplier tổng = server × personal (2 × 2 = 4 nếu cả hai đang chạy).

	ProgressionService hook GetSpeedMultiplier() vào bucket live-ops;
	AwardWins (reason stage) hook GetWinsMultiplier().
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Products = require(ReplicatedStorage.Shared.Config.Economy.Products)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local DataService: any = nil

local BOOST_NAMES: { [string]: string } = {
	speed = "SERVER x2 SPEED",
	wins = "SERVER x2 WINS",
	mega = "MEGA BOOST x2 ALL",
}

-- expiresAt theo os.clock(); 0 = không hoạt động
local serverBoosts: { [string]: number } = { speed = 0, wins = 0 }
local personalBoosts: { [Player]: { [string]: number } } = {}

local ServerBoostService = {}

local function remaining(expiresAt: number): number
	return math.max(0, expiresAt - os.clock())
end

local function getPersonal(player: Player): { [string]: number }
	local existing = personalBoosts[player]
	if existing then
		return existing
	end
	local boosts = { speed = 0, wins = 0 }
	personalBoosts[player] = boosts
	return boosts
end

local function sendState(player: Player)
	if player.Parent ~= Players then
		return
	end
	local personal = getPersonal(player)
	-- pcall: ByteNet chưa kịp tạo channel cho player vừa join lúc server khởi động → bỏ qua,
	-- state sẽ được gửi lại ở lần broadcast/kích hoạt kế tiếp.
	pcall(GamePackets.boostState.sendTo, {
		serverSpeedSecondsLeft = remaining(serverBoosts.speed),
		serverWinsSecondsLeft = remaining(serverBoosts.wins),
		personalSpeedSecondsLeft = remaining(personal.speed),
		personalWinsSecondsLeft = remaining(personal.wins),
	}, player)
end

local function broadcastState()
	for _, player in Players:GetPlayers() do
		sendState(player)
	end
end

-- ============================================================================
-- Public API
-- ============================================================================

function ServerBoostService.GetSpeedMultiplier(player: Player?): number
	local multiplier = if remaining(serverBoosts.speed) > 0 then 2 else 1
	if player then
		local personal = personalBoosts[player]
		if personal and remaining(personal.speed) > 0 then
			multiplier *= 2
		end
	end
	return multiplier
end

function ServerBoostService.GetWinsMultiplier(player: Player?): number
	local multiplier = if remaining(serverBoosts.wins) > 0 then 2 else 1
	if player then
		local personal = personalBoosts[player]
		if personal and remaining(personal.wins) > 0 then
			multiplier *= 2
		end
	end
	return multiplier
end

-- kind: "speed" | "wins" | "mega". Boost cùng loại đang chạy → cộng dồn thêm duration.
function ServerBoostService.ActivateServerBoost(kind: string, byPlayer: Player?, durationSeconds: number?)
	local duration = durationSeconds or Products.SERVER_BOOST_DURATION_SECONDS
	local kinds: { string } = if kind == "mega" then { "speed", "wins" } else { kind }
	for _, boostKind in kinds do
		if serverBoosts[boostKind] ~= nil then
			serverBoosts[boostKind] = math.max(os.clock(), serverBoosts[boostKind]) + duration
		end
	end

	if byPlayer then
		GamePackets.boostCelebration.sendToAll({
			playerName = byPlayer.DisplayName,
			boostName = BOOST_NAMES[kind] or kind,
			kind = kind,
			userId = byPlayer.UserId,
		})
	end
	broadcastState()
end

function ServerBoostService.ActivatePersonalBoost(player: Player, kind: string, durationSeconds: number)
	local personal = getPersonal(player)
	if personal[kind] == nil then
		return
	end
	personal[kind] = math.max(os.clock(), personal[kind]) + durationSeconds
	sendState(player)
end

function ServerBoostService.SendState(player: Player)
	sendState(player)
end

-- ============================================================================
-- Receipt processor (đăng ký trong ReceiptService)
-- ============================================================================

function ServerBoostService.ProcessReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId
	local kind: string? = nil
	if productId == Products.SERVER_BOOST_SPEED_PRODUCT_ID then
		kind = "speed"
	elseif productId == Products.SERVER_BOOST_WINS_PRODUCT_ID then
		kind = "wins"
	elseif productId == Products.SERVER_BOOST_MEGA_PRODUCT_ID then
		kind = "mega"
	end

	if not kind then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	ServerBoostService.ActivateServerBoost(kind, player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function ServerBoostService.Init()
	DataService = ServiceLocator.Get("DataService")
end

function ServerBoostService.Start()
	-- Đợi profile load xong mới gửi state lần đầu (tránh race ByteNet lúc player vừa join).
	local function pushWhenReady(player: Player)
		task.spawn(function()
			local tries = 0
			while not DataService.IsLoaded(player) and tries < 200 and player.Parent == Players do
				task.wait(0.1)
				tries += 1
			end
			if player.Parent == Players then
				sendState(player)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		pushWhenReady(player)
	end
	Players.PlayerAdded:Connect(pushWhenReady)

	-- Studio-only: set attribute TestBoost = "speed"|"wins"|"mega" trên Player để kích hoạt
	-- server boost 60s (test celebration + multiplier). Không chạy ở production.
	if RunService:IsStudio() then
		local function hookTestAttribute(player: Player)
			player:GetAttributeChangedSignal("TestBoost"):Connect(function()
				local kind = player:GetAttribute("TestBoost")
				if kind == "speed" or kind == "wins" or kind == "mega" then
					ServerBoostService.ActivateServerBoost(kind :: string, player, 60)
					player:SetAttribute("TestBoost", nil)
				end
			end)
		end
		for _, player in Players:GetPlayers() do
			hookTestAttribute(player)
		end
		Players.PlayerAdded:Connect(hookTestAttribute)
	end
	Players.PlayerRemoving:Connect(function(player)
		personalBoosts[player] = nil
	end)

	-- Đồng bộ lại khi có boost vừa hết hạn (client tự đếm ngược, đây chỉ là chốt trạng thái).
	task.spawn(function()
		local wasActive = false
		while true do
			task.wait(1)
			local anyActive = remaining(serverBoosts.speed) > 0 or remaining(serverBoosts.wins) > 0
			for _, boosts in personalBoosts do
				if remaining(boosts.speed) > 0 or remaining(boosts.wins) > 0 then
					anyActive = true
					break
				end
			end
			if wasActive and not anyActive then
				broadcastState()
			end
			wasActive = anyActive
		end
	end)
end

return ServerBoostService
