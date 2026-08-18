--!strict
--[[
	RouletteService.luau — Vòng quay May mắn (Speed Roulette).

	Vé quay (SpinTickets, persist trong profile):
	  - Free: mỗi 15 phút online liên tục +1 vé (chỉ tích khi đang < 3 vé; đầy thì tạm dừng đếm).
	  - Daily Ngày 7: +1 vé (DailyService gọi GrantTickets, bỏ qua cap free).
	  - Mua Robux: 1/5/10 lượt (ProcessReceipt, bỏ qua cap free, kẹp MAX_TICKETS).

	Spin: server trừ vé, roll theo weight trong Config/Roulette.
	Kết quả gửi spinResult để client chạy hiệu ứng bánh xe.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)
local Products = require(ReplicatedStorage.Shared.Config.Economy.Products)
local RouletteConfig = require(ReplicatedStorage.Shared.Config.Roulette)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local DataService: any = nil
local ProgressionService: any = nil
local ServerBoostService: any = nil

local rng = Random.new()

-- Giây online đã tích cho vé free tiếp theo (reset khi nhận vé hoặc rời server).
local freeAccrualSeconds: { [Player]: number } = {}
local lastSpinAt: { [Player]: number } = {}

local totalWeight = 0
for _, slot in RouletteConfig.SLOTS do
	totalWeight += slot.weight
end

local RouletteService = {}

local function getTickets(data: any): number
	return math.max(0, math.floor(tonumber(data.SpinTickets) or 0))
end

--[[
	Nhịp hồi vé + trần tích trữ giờ THEO NGƯỜI CHƠI, không còn là hằng số: VIP Membership hồi
	8 phút/vé và giữ được 5 vé (xem khối lý do trong `Config/Roulette.luau`).

	Đọc attribute `IsVIP` do GamepassService set — KHÔNG gọi `UserOwnsGamePassAsync` ở đây:
	vòng lặp tích vé chạy mỗi giây cho mọi người trong server, gọi web API trong đó là tự
	bắn hàng trăm request mỗi phút. Attribute được set lúc profile load và ngay khi mua giữa
	session, nên nó luôn kịp thời.
]]
local function ticketInterval(player: Player): number
	return if player:GetAttribute("IsVIP") == true
		then RouletteConfig.VIP_TICKET_INTERVAL_SECONDS
		else RouletteConfig.FREE_TICKET_INTERVAL_SECONDS
end

local function ticketCap(player: Player): number
	return if player:GetAttribute("IsVIP") == true
		then RouletteConfig.VIP_TICKET_STOCK_CAP
		else RouletteConfig.FREE_TICKET_STOCK_CAP
end

local function sendState(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	local tickets = getTickets(data)
	local nextFree = -1
	if tickets < ticketCap(player) then
		nextFree = math.max(0, ticketInterval(player) - (freeAccrualSeconds[player] or 0))
	end

	GamePackets.rouletteState.sendTo({
		tickets = math.clamp(tickets, 0, 255),
		nextFreeTicketSeconds = nextFree,
	}, player)
end

-- ignoreFreeCap: vé mua Robux / daily được vượt cap free (vẫn kẹp MAX_TICKETS).
function RouletteService.GrantTickets(player: Player, amount: number, ignoreFreeCap: boolean?): boolean
	local data = DataService.GetData(player)
	if not data or amount <= 0 then
		return false
	end

	local tickets = getTickets(data)
	local cap = if ignoreFreeCap then RouletteConfig.MAX_TICKETS else ticketCap(player)
	local newTickets = math.min(cap, tickets + math.floor(amount))
	if newTickets <= tickets then
		return false
	end

	data.SpinTickets = newTickets
	GamePackets.toast.sendTo({
		kind = "roulette",
		message = "Spin Ticket",
		amount = newTickets - tickets,
	}, player)
	sendState(player)
	return true
end

-- ============================================================================
-- Spin
-- ============================================================================

local function rollSlotIndex(): number
	local roll = rng:NextNumber(0, totalWeight)
	local cursor = 0
	for index, slot in RouletteConfig.SLOTS do
		cursor += slot.weight
		if roll <= cursor then
			return index
		end
	end
	return #RouletteConfig.SLOTS
end

local function grantReward(player: Player, slotIndex: number): string
	local slot = RouletteConfig.SLOTS[slotIndex]
	if slot.kind == "speed" then
		ProgressionService.GrantSpeed(player, slot.amount)
		return `+{Constants.FormatNumber(slot.amount)} Speed`
	elseif slot.kind == "wins" then
		ProgressionService.AwardWins(player, slot.amount, "roulette")
		return `+{Constants.FormatNumber(slot.amount)} Wins`
	elseif slot.kind == "boostSpeed" then
		if ServerBoostService then
			ServerBoostService.ActivatePersonalBoost(player, "speed", slot.amount)
		end
		return `x2 Speed ({math.floor(slot.amount / 60)} min)`
	elseif slot.kind == "boostWins" then
		if ServerBoostService then
			ServerBoostService.ActivatePersonalBoost(player, "wins", slot.amount)
		end
		return `x2 Wins ({math.floor(slot.amount / 60)} min)`
	elseif slot.kind == "aura" then
		local data = DataService.GetData(player)
		local auraId = slot.auraId or "aura_frozen_bloom"
		if data and not data.UnlockedAuras[auraId] then
			data.UnlockedAuras[auraId] = true
			ProgressionService.SendSnapshot(player)
			return "FROZEN BLOOM UNLOCKED!"
		end

		-- Đã sở hữu → đền bù Wins
		ProgressionService.AwardWins(player, slot.amount, "roulette")
		return `Owned! +{Constants.FormatNumber(slot.amount)} Wins`
	end
	return ""
end

local function onSpinRequest(player: Player)
	local now = os.clock()
	if now - (lastSpinAt[player] or 0) < 1.0 then
		return
	end
	lastSpinAt[player] = now

	local data = DataService.GetData(player)
	if not data then
		return
	end

	local tickets = getTickets(data)
	if tickets <= 0 then
		GamePackets.toast.sendTo({ kind = "roulette", message = "No Spin Tickets!", amount = 0 }, player)
		sendState(player)
		return
	end
	data.SpinTickets = tickets - 1

	local slotIndex = rollSlotIndex()

	local remainingTickets = math.clamp(getTickets(data), 0, 255)
	GamePackets.spinResult.sendTo({
		slotIndex = slotIndex,
		rewardText = "",
		tickets = remainingTickets,
	}, player)
	sendState(player)

	-- Trì hoãn 4.2s (đúng thời gian bánh xe quay) rồi mới cộng thưởng và phát Toast thông báo
	task.delay(4.2, function()
		if player and player.Parent == Players then
			local rewardText = grantReward(player, slotIndex)
			if rewardText ~= "" then
				GamePackets.toast.sendTo({ kind = "roulette", message = rewardText, amount = 0 }, player)
			end
		end
	end)
end

-- ============================================================================
-- Receipt processor (gói lượt quay Robux)
-- ============================================================================

function RouletteService.ProcessReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	for _, pack in Products.SPIN_PACKS do
		if pack.productId > 0 and receiptInfo.ProductId == pack.productId then
			RouletteService.GrantTickets(player, pack.spins, true)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function RouletteService.SendState(player: Player)
	sendState(player)
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function RouletteService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
	ServerBoostService = ServiceLocator.Find("ServerBoostService")
end

function RouletteService.Start()
	GamePackets.requestSpin.listen(function(_data, player: Player)
		onSpinRequest(player)
	end)

	GamePackets.requestRouletteState.listen(function(_data, player: Player)
		if NetRateLimit.ShouldDrop(player, "rouletteState") then
			return
		end
		sendState(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		freeAccrualSeconds[player] = 0
	end)

	--[[
		Studio-only: tặng vé test khi profile load xong. KHÔNG chạy ở production —
		người chơi thật vào game có 0 vé và phải online 15 phút mới được vé đầu tiên.

		2026-08-13: hạ 3 → 1. Con số 3 làm chính người phát triển tưởng game đang tặng 3 vé
		cho người mới (badge "Spin FULL" ngay lần đầu vào Studio). Một vé là đủ để thử
		luồng quay, mà lại khớp với thứ nhìn thấy ở production.
	]]
	--[[
		[Studio-only test hook] BẮN THẲNG MỘT KẾT QUẢ QUAY (2026-08-14).

		Đặt attribute `StudioTestSpin` = số ô (1..8) lên Player ⇒ server gửi đúng gói `spinResult`
		mà một lượt quay thật gửi, KHÔNG trừ vé và KHÔNG phát thưởng. Dùng để nghiệm thu phần
		HIỂN THỊ phía client (bánh xe dừng đúng ô + banner chúc mừng) mà không phải cày vé cho
		từng ô — ô hiếm nhất là 1%, không có hook thì không ai QA nổi nó.

		Attribute chứ không phải hàm gọi thẳng: `execute_luau` chạy VM riêng nên không với tới
		service thật (cùng lý do với hook cosmetic trong ProgressionService).
	]]
	if RunService:IsStudio() then
		local function watchTestSpin(player: Player)
			player:GetAttributeChangedSignal("StudioTestSpin"):Connect(function()
				local slotIndex = tonumber(player:GetAttribute("StudioTestSpin"))
				if not slotIndex then
					return
				end
				player:SetAttribute("StudioTestSpin", nil)
				slotIndex = math.clamp(math.floor(slotIndex), 1, #RouletteConfig.SLOTS)

				local data = DataService.GetData(player)
				GamePackets.spinResult.sendTo({
					slotIndex = slotIndex,
					rewardText = "",
					tickets = if data then math.clamp(getTickets(data), 0, 255) else 0,
				}, player)
				print(
					`[RouletteService] [Studio hook] Gửi spinResult ô {slotIndex} `
						.. `("{RouletteConfig.SLOTS[slotIndex].label}") cho {player.Name} — không trừ vé, không phát thưởng.`
				)
			end)
		end
		for _, player in Players:GetPlayers() do
			watchTestSpin(player)
		end
		Players.PlayerAdded:Connect(watchTestSpin)
	end

	if RunService:IsStudio() then
		task.spawn(function()
			while true do
				task.wait(2)
				for _, player in Players:GetPlayers() do
					local data = DataService.GetData(player)
					if data and not player:GetAttribute("StudioSpinGranted") then
						player:SetAttribute("StudioSpinGranted", true)
						RouletteService.GrantTickets(player, 1, true)
					end
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		freeAccrualSeconds[player] = nil
		lastSpinAt[player] = nil
	end)

	-- Tích vé free: đếm mỗi giây, đủ một nhịp → +1 vé (chỉ khi chưa đầy cap).
	-- Nhịp và cap lấy theo người chơi: thường 15 phút/3 vé, VIP 8 phút/5 vé.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = DataService.GetData(player)
				if not data then
					continue
				end

				if getTickets(data) >= ticketCap(player) then
					freeAccrualSeconds[player] = 0
					continue
				end

				local accrued = (freeAccrualSeconds[player] or 0) + 1
				if accrued >= ticketInterval(player) then
					freeAccrualSeconds[player] = 0
					RouletteService.GrantTickets(player, 1)
				else
					freeAccrualSeconds[player] = accrued
					-- Đồng bộ đồng hồ đếm ngược mỗi 30s để client không lệch.
					if accrued % 30 == 0 then
						sendState(player)
					end
				end
			end
		end
	end)
end

return RouletteService
