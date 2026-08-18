--!strict
--[[
	StarterPackService.luau — gói "Rookie Rocket" (xem Config/Economy/StarterPack.luau).

	Ba việc:
	  1. Đồng bộ trạng thái (còn bao nhiêu giây / đã mua chưa) cho client vẽ thẻ + đồng hồ.
	  2. Phát gói: toàn bộ quà + bật cờ `StarterPackBought`, đúng MỘT lần cho mỗi tài khoản.
	  3. Từ chối mở prompt khi gói chưa được cấu hình Pass ID, hoặc cửa sổ 48h đã đóng.

	── HẠN 48H TÍNH THEO GIỜ THẬT ────────────────────────────────────────────────────────
	Dùng `os.time()` (giờ tuyệt đối, lưu trong profile) chứ KHÔNG phải `os.clock()` hay số
	giây đã chơi: người chơi đăng xuất rồi vào lại sau ba ngày phải thấy gói đã hết hạn, chứ
	không phải "vẫn còn vì mới chơi có 20 phút". Client được gửi SỐ GIÂY CÒN LẠI rồi tự đếm
	lùi — không gửi mốc `os.time()` để client không phải tin vào đồng hồ máy nó.

	── HAI ĐƯỜNG TIỀN VÀO, MỘT CỬA PHÁT QUÀ (2026-08-11) ─────────────────────────────────
	Gói bán bằng Developer Product 3703422987. Nhưng nó từng bán bằng gamepass 1940593812
	trong một ngày (xem lời giải thích trong Config/Economy/StarterPack), nên có HAI đường:
	  • `ProcessReceipt` — đường chính, mọi giao dịch từ nay.
	  • `GrantIfOwnedLegacyPass` — quét gamepass cũ lúc profile load, phát bù cho người đã
	    mua hồi đó.
	Cả hai đều đi qua `grantPack` và đều bị cờ `StarterPackBought` chặn, nên dù người chơi
	vừa mua product vừa sở hữu pass cũ thì quà cũng chỉ ra đúng một lần.

	⚠️ HẠN 48H KHÔNG CHẶN VIỆC PHÁT QUÀ, chỉ chặn thẻ hiện và prompt mở. Đã trừ tiền là phải
	nhận hàng, bất kể đồng hồ (xem chú thích trong ProcessReceipt).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local StarterPackConfig = require(ReplicatedStorage.Shared.Config.Economy.StarterPack)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local StarterPackService = {}

local DataService: any
local GamepassService: any
local ProgressionService: any
local RouletteService: any
local ServerBoostService: any

-- Số giây còn lại của cửa sổ 48h. <= 0 nghĩa là hết hạn.
local function secondsLeft(data: any): number
	local firstJoin = tonumber(data.FirstJoinTime) or 0
	if firstJoin <= 0 then
		return StarterPackConfig.WINDOW_SECONDS
	end
	return math.max(0, (firstJoin + StarterPackConfig.WINDOW_SECONDS) - os.time())
end

local function isAvailable(data: any): boolean
	return StarterPackConfig.IsConfigured() and not data.StarterPackBought and secondsLeft(data) > 0
end

-- Đang xem trước (Studio, chưa có Product ID) mà tài khoản test đã chơi quá 48h thì đồng hồ
-- về 0 và thẻ vẫn ẩn — vô nghĩa với mục đích duyệt giao diện. Chế độ xem trước luôn thấy
-- một cửa sổ đầy. KHÔNG ảnh hưởng bản thật: nhánh này đòi `not IsConfigured()`.
local function isPreview(): boolean
	return StarterPackConfig.ShowsCard() and not StarterPackConfig.IsConfigured()
end

local function sendState(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local left = secondsLeft(data)
	if isPreview() and left <= 0 then
		left = StarterPackConfig.WINDOW_SECONDS
	end
	GamePackets.starterPackState.sendTo({
		secondsLeft = left,
		bought = data.StarterPackBought == true,
		-- `ShowsCard` chứ không phải `IsConfigured`: trong Studio thẻ vẫn hiện để duyệt giao
		-- diện khi chưa có Product ID. Đường thanh toán bên dưới vẫn khoá ở `IsConfigured`.
		configured = StarterPackConfig.ShowsCard(),
	}, player)
end

function StarterPackService.SendState(player: Player)
	sendState(player)
end

function StarterPackService.IsAvailable(player: Player): boolean
	local data = DataService.GetData(player)
	return data ~= nil and isAvailable(data)
end

-- ============================================================================
-- Phát quà
-- ============================================================================

local function grantPack(player: Player, data: any)
	data.StarterPackBought = true

	ProgressionService.AwardWins(player, StarterPackConfig.WINS, "starterPack")

	-- Trail độc quyền: `equip = true` — món đẹp nhất trong gói phải hiện ra sau lưng người
	-- chơi NGAY, không bắt họ đi tìm trong menu Cosmetics (cùng lý do với trail Daily ngày 7).
	ProgressionService.UnlockCosmetic(player, "trail", StarterPackConfig.TRAIL_ID, true)

	if RouletteService then
		RouletteService.GrantTickets(player, StarterPackConfig.SPINS, true)
	end
	if ServerBoostService then
		ServerBoostService.ActivatePersonalBoost(player, "wins", StarterPackConfig.BOOST_WINS_SECONDS)
	end

	--[[
		x2 Speed vĩnh viễn nằm ở cờ `StarterPackBought` (ProgressionService đọc trong
		`computeGamepassMultiplier`). Phải XOÁ CACHE multiplier của session, nếu không buff chỉ
		có hiệu lực ở lần đăng nhập SAU — người vừa trả tiền mà tốc độ không đổi gì.
	]]
	ProgressionService.RefreshGamepassCache(player) -- hàm này tự gửi snapshot

	--[[
		⚠️ `itemName` = "STARTER PACK", KHÔNG phải "ROOKIE ROCKET" (sửa 2026-08-12).

		Hai lý do, cùng một cái tên gây ra:
		  1. Người chơi vừa bấm mua một thứ tên "Starter Pack" (icon HUD + modal + shop đều gọi
		     thế) mà banner lại chúc mừng một cái tên chưa từng xuất hiện ở đâu.
		  2. Banner tra icon THEO TÊN (`ICON_BY_NAME` trong BoostCelebration, dựng từ config).
		     "ROOKIE ROCKET" khớp đúng tên TRAIL trong Trails.luau ⇒ banner hiện ảnh cái trail
		     nhỏ trong gói thay vì ảnh cả gói.
		"Rookie Rocket" giờ chỉ còn là tên của TRAIL, và nó nằm ở dòng phụ đúng như vậy.
	]]
	GamePackets.purchaseCelebration.sendTo({
		itemName = "STARTER PACK",
		subtitle = `+{Constants.FormatNumber(StarterPackConfig.WINS)} Wins · x2 Speed forever · {StarterPackConfig.SPINS} Spins · Rookie Rocket Trail`,
	}, player)
	sendState(player)
end

--[[
	ĐƯỜNG DI SẢN: phát bù cho người đã mua GAMEPASS 1940593812 trong ngày gói còn bán bằng
	pass. Pass đã tắt bán nên đường này không nhận thêm ai mới, nhưng phải sống mãi — sở hữu
	gamepass là vĩnh viễn, và người đã trả 99 R$ có quyền nhận hàng ở mọi lần đăng nhập sau.

	Gọi bao nhiêu lần cũng được: đã phát rồi thì lặng lẽ thoát.

	`trusted = true` nghĩa là người gọi vừa CHỨNG KIẾN giao dịch thành công
	(`PromptGamePassPurchaseFinished` với purchased = true) — khỏi hỏi lại web API. Mọi
	đường khác phải hỏi `GamepassService.OwnsPass`.
]]
function StarterPackService.GrantIfOwnedLegacyPass(player: Player, trusted: boolean?): boolean
	local passId = StarterPackConfig.LEGACY_PASS_ID
	if passId <= 0 then
		return false
	end

	local data = DataService.GetData(player)
	if not data or data.StarterPackBought then
		return false
	end

	if not trusted then
		if not GamepassService or not GamepassService.OwnsPass(player, passId) then
			return false
		end
	end

	print(`[StarterPackService] {player.Name} sở hữu gamepass Rookie Rocket đời đầu — phát bù gói.`)
	grantPack(player, data)
	return true
end

function StarterPackService.ProcessReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	if not StarterPackConfig.IsConfigured() or receiptInfo.ProductId ~= StarterPackConfig.PRODUCT_ID then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataService.GetData(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	--[[
		ĐÃ MUA RỒI thì KHÔNG phát lại nhưng vẫn trả `PurchaseGranted`: Roblox đã trừ tiền, trả
		`NotProcessedYet` chỉ khiến nó gọi lại mãi mãi. Trường hợp này xảy ra khi hoá đơn được
		thử lại sau khi đã xử lý xong, hoặc khi người chơi vốn đã sở hữu gamepass đời đầu —
		phát lần hai là nhân đôi quà.

		HẾT HẠN thì VẪN PHÁT: prompt chỉ mở được từ thẻ của client, mà tiền đã bị trừ thật. Bắt
		người chơi mất 99 R$ vì lệch vài giây đồng hồ là cách nhanh nhất để ăn một report.
	]]
	if data.StarterPackBought then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	grantPack(player, data)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================================================
-- Vòng đời
-- ============================================================================

function StarterPackService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
	GamepassService = ServiceLocator.Get("GamepassService")
	RouletteService = ServiceLocator.Find("RouletteService")
	ServerBoostService = ServiceLocator.Find("ServerBoostService")
end

function StarterPackService.Start()
	if not StarterPackConfig.IsConfigured() then
		warn(
			"[StarterPackService] PRODUCT_ID = 0 → gói Rookie Rocket đang TẮT. "
				.. "Tạo Developer Product 99 Robux trên Creator Dashboard rồi điền vào "
				.. "Shared/Config/Economy/StarterPack.luau."
		)
	end

	--[[
		Lúc profile load: quét gamepass đời đầu TRƯỚC, phát bù nếu cần, RỒI mới gửi trạng
		thái. Ngược thứ tự thì người đã sở hữu pass sẽ thấy thẻ bán hàng nhấp nháy vài giây
		trước khi nó tự biến mất — trông y như game vừa bán lại món họ đã có.
	]]
	local function pushWhenReady(player: Player)
		task.spawn(function()
			local tries = 0
			while not DataService.IsLoaded(player) and tries < 200 and player.Parent == Players do
				task.wait(0.1)
				tries += 1
			end
			if not DataService.IsLoaded(player) then
				return
			end
			StarterPackService.GrantIfOwnedLegacyPass(player)
			sendState(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		pushWhenReady(player)
	end
	Players.PlayerAdded:Connect(pushWhenReady)

	GamePackets.requestStarterPackPurchase.listen(function(_payload, player: Player)
		local data = DataService.GetData(player)
		if not data or not isAvailable(data) then
			-- Thẻ xem trước trong Studio: nút mua là thứ DUY NHẤT không chạy được, nói thẳng
			-- ra console để khỏi tưởng nút hỏng.
			if data and StarterPackConfig.ShowsCard() and not StarterPackConfig.IsConfigured() then
				warn("[StarterPackService] Thẻ đang ở chế độ XEM TRƯỚC (PRODUCT_ID = 0) — không mở prompt mua.")
			end
			sendState(player) -- client đang giữ trạng thái cũ → sửa lại cho nó
			return
		end

		task.spawn(function()
			-- Sở hữu gamepass đời đầu mà quà chưa vào tay: phát luôn, đừng bắt họ trả lần hai.
			if StarterPackService.GrantIfOwnedLegacyPass(player) then
				return
			end
			MarketplaceService:PromptProductPurchase(player, StarterPackConfig.PRODUCT_ID)
		end)
	end)

	--[[
		Đồng hồ hết hạn: quét mỗi 30s. Không cần nhanh hơn — client tự đếm lùi từng giây, đây
		chỉ là lúc CHỐT trạng thái (ẩn thẻ) khi cửa sổ đóng lại giữa phiên chơi.
	]]
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local data = DataService.GetData(player)
				if data and not data.StarterPackBought and secondsLeft(data) <= 0 then
					sendState(player)
				end
			end
		end
	end)
end

return StarterPackService
