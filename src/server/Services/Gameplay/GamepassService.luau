--!strict
--[[
	GamepassService.luau — Xử lý sở hữu & mua gamepass NGAY TRONG GAME.

	1. Speed passes (x2/x4/x8) + VIP: khi mua xong (PromptGamePassPurchaseFinished)
	   → xoá cache multiplier trong ProgressionService (áp dụng NGAY không cần rejoin)
	   → gửi purchaseCelebration cho buyer (banner + confetti + sound phía client).
	2. Treadmill passes: đồng bộ ownership → UnlockedTreadmills (persist) khi profile load
	   (fix "mua pass trên web/own sẵn nhưng treadmill vẫn khoá"), và khi mua trong game
	   → unlock + tự trang bị nếu multiplier cao hơn + celebration.
	3. API PromptTreadmillPurchase(player, treadmillId): TreadmillService gọi khi player
	   chạm treadmill chưa sở hữu → hiện prompt thanh toán.
	4. Cosmetic passes (aura/trail Robux-only trong Lobby.AuraBase / Lobby.TrailBase):
	   sync ownership lúc profile load; mua trong game → mở khoá + trang bị ngay + celebration.
	   Đây là ĐƯỜNG DUY NHẤT mở khoá món robuxOnly — ProgressionService từ chối bán bằng Wins.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local StarterPackConfig = require(ReplicatedStorage.Shared.Config.Economy.StarterPack)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local DataService: any = nil
local ProgressionService: any = nil
local StarterPackService: any = nil

local GamepassService = {}

-- passId → tên hiển thị (speed passes + VIP; multiplier tính trong ProgressionService)
local SPEED_PASS_NAMES: { [number]: string } = {}
local VIP_PASS_ID = 0
local AUTO_REBIRTH_PASS_ID = 0

-- passId → treadmillId
local TREADMILL_PASS_TO_ID: { [number]: string } = {}

-- passId → cosmetic (aura/trail bán bằng Robux)
type CosmeticRef = { category: string, id: string, name: string }
local COSMETIC_PASS_TO_ITEM: { [number]: CosmeticRef } = {}
-- "aura:Dark" → passId, để PromptCosmeticPurchase tra ngược.
local COSMETIC_KEY_TO_PASS: { [string]: number } = {}

-- Pass mua TRONG session này (Studio test purchase không persist lên web API).
local sessionOwned: { [Player]: { [number]: boolean } } = {}

-- Cache câu trả lời "CHƯA sở hữu" của web API. Không có nó thì mỗi lần hỏi là một
-- UserOwnsGamePassAsync — mà với ~25 pass × mỗi lần mở Shop/Cosmetics/chạm treadmill,
-- số request đủ để dính rate limit của Roblox và làm mọi lần hỏi sau trả sai (pcall
-- thất bại ⇒ coi như chưa sở hữu ⇒ người đã mua bị khoá món của chính mình).
-- Chỉ cache VẾ PHỦ ĐỊNH: vế khẳng định đã nằm ở sessionOwned và không bao giờ hết hạn.
local NEGATIVE_CACHE_SECONDS = 60
local negativeCache: { [Player]: { [number]: number } } = {}

local function cosmeticKey(category: string, itemId: string): string
	return `{category}:{itemId}`
end

local function buildMaps()
	local ids = Constants.GAMEPASS_IDS
	for passId, name in
		{
			[ids.DoubleSpeed or 0] = "x2 SPEED GAMEPASS",
			[ids.QuadSpeed or 0] = "x4 SPEED GAMEPASS",
			[ids.OctaSpeed or 0] = "x8 SPEED GAMEPASS",
		}
	do
		if passId > 0 then
			SPEED_PASS_NAMES[passId] = name
		end
	end
	VIP_PASS_ID = ids.VIPMembership or 0
	AUTO_REBIRTH_PASS_ID = ids.AutoRebirth or 0

	for _, treadmill in Constants.TREADMILLS :: { Constants.TreadmillConfig } do
		if treadmill.gamepassId and treadmill.gamepassId > 0 then
			TREADMILL_PASS_TO_ID[treadmill.gamepassId] = treadmill.id
		end
	end

	for category, catalog in
		{
			aura = Constants.AURAS :: { any },
			trail = Constants.TRAILS :: { any },
		}
	do
		for _, config in catalog do
			local passId = config.gamepassId or 0
			if passId > 0 then
				COSMETIC_PASS_TO_ITEM[passId] = { category = category, id = config.id, name = config.name }
				COSMETIC_KEY_TO_PASS[cosmeticKey(category, config.id)] = passId
			end
		end
	end
end

local function celebrate(player: Player, itemName: string, subtitle: string?)
	pcall(GamePackets.purchaseCelebration.sendTo, {
		itemName = itemName,
		subtitle = subtitle or "Purchase successful — enjoy your power!",
	}, player)
end

-- Nguồn sự thật DUY NHẤT về sở hữu gamepass phía server.
-- LƯU Ý: hỏi thẳng Roblox CẢ TRONG STUDIO. Bản cũ Studio luôn trả false để "test
-- luồng mua", nhưng tài khoản ĐÃ sở hữu pass thật thì prompt bị Roblox chặn
-- ("You already own this item", purchased=false) → không bao giờ unlock = kẹt vĩnh viễn.
-- Tài khoản chưa sở hữu vẫn test được luồng mua bình thường (Studio test purchase).
function GamepassService.OwnsPass(player: Player, passId: number): boolean
	if passId <= 0 then
		return false
	end

	local owned = sessionOwned[player]
	if owned and owned[passId] then
		return true
	end

	-- Khi testing trong Studio: mặc định KHÔNG sở hữu trước pass nào để test luồng mua.
	-- Chỉ sở hữu nếu vừa mua thành công trong session này (đã lưu ở sessionOwned).
	if RunService:IsStudio() then
		-- [Studio-only test hook] attribute `TestOwnedPasses` = danh sách id cách nhau bởi
		-- dấu phẩy ⇒ coi như đã sở hữu. Cần thiết vì Studio không mua thật được, mà những
		-- tính năng như Auto-Rebirth chỉ chạy khi có pass — không có hook thì không QA nổi.
		local test = player:GetAttribute("TestOwnedPasses")
		if typeof(test) == "string" and string.find(`,{test},`, `,{passId},`, 1, true) then
			return true
		end
		return false
	end

	local misses = negativeCache[player]
	if misses and os.clock() - (misses[passId] or -math.huge) < NEGATIVE_CACHE_SECONDS then
		return false
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok and owns == true then
		return true
	end

	-- Cả "API trả false" lẫn "API lỗi" đều ghi nhận là chưa sở hữu trong 60s. Ghi cả ca
	-- lỗi là CỐ Ý: lúc Roblox đang bóp request, hỏi lại dồn dập chỉ làm bị bóp lâu hơn.
	if not misses then
		misses = {}
		negativeCache[player] = misses
	end
	misses[passId] = os.clock()
	return false
end

local function markSessionOwned(player: Player, passId: number)
	local owned = sessionOwned[player]
	if not owned then
		owned = {}
		sessionOwned[player] = owned
	end
	owned[passId] = true
end

local function syncVipAttribute(player: Player)
	player:SetAttribute("IsVIP", GamepassService.OwnsPass(player, VIP_PASS_ID))
end

-- Unlock treadmill (persist) + trang bị nếu multiplier cao hơn treadmill đang dùng.
local function unlockTreadmill(player: Player, treadmillId: string, announce: boolean)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	local config = Constants.GetTreadmillById(treadmillId)
	if not config then
		return
	end

	local alreadyUnlocked = data.UnlockedTreadmills[treadmillId] == true
	data.UnlockedTreadmills[treadmillId] = true

	local equipped = Constants.GetTreadmillById(data.EquippedTreadmill)
	if not equipped or config.multiplier > equipped.multiplier then
		data.EquippedTreadmill = treadmillId
	end

	if announce and not alreadyUnlocked then
		celebrate(player, string.upper(config.name))
		GamePackets.toast.sendTo({
			kind = "treadmill",
			message = `{config.name} unlocked!`,
			amount = 0,
		}, player)
	end
	ProgressionService.SendSnapshot(player)
end

-- Mở khoá aura/trail mua bằng Robux. `announce` = true khi vừa mua trong game.
-- Vừa mua thì TRANG BỊ luôn (người chơi trả tiền là muốn thấy hiệu ứng ngay);
-- lúc sync ownership khi join thì chỉ mở khoá, giữ nguyên món đang trang bị.
local function unlockCosmetic(player: Player, pass: CosmeticRef, announce: boolean)
	local isNew = ProgressionService.UnlockCosmetic(player, pass.category, pass.id, announce)
	if announce and isNew then
		celebrate(player, string.upper(pass.name))
		GamePackets.toast.sendTo({
			kind = "cosmetic",
			message = `{pass.name} unlocked!`,
			amount = 0,
		}, player)
	end
end

--[[
	Hai cosmetic ĐỘC QUYỀN đi kèm VIP Membership. Chúng không có gamepass riêng và không bán
	bằng Wins (`dailyOnly` trong config), nên ĐÂY là đường trao duy nhất — hỏng chỗ này thì
	người mua 399 R$ vĩnh viễn không nhận được hai phần ba giá trị của gói.

	Trao KHÔNG kèm `announce`: mua VIP đã có banner "VIP MEMBERSHIP" riêng, thêm hai banner
	cosmetic nữa là ba tấm chồng nhau cho cùng một giao dịch. Cũng KHÔNG tự trang bị — người
	chơi có thể đang đeo món họ thích hơn, và VIP là gói mua vì quyền lợi chứ không phải vì
	một bộ đồ cụ thể.
]]
local VIP_COSMETICS: { { category: string, id: string, name: string } } = {
	{ category = "trail", id = "trail_vip", name = "VIP Gold Trail" },
	{ category = "aura", id = "aura_vip", name = "VIP Gold Aura" },
}

local function grantVipCosmetics(player: Player)
	if VIP_PASS_ID <= 0 or not GamepassService.OwnsPass(player, VIP_PASS_ID) then
		return
	end
	local data = DataService.GetData(player)
	if not data then
		return
	end
	for _, item in VIP_COSMETICS do
		local unlocked = if item.category == "trail" then data.UnlockedTrails else data.UnlockedAuras
		if not unlocked[item.id] then
			ProgressionService.UnlockCosmetic(player, item.category, item.id, false)
		end
	end
end

-- Đồng bộ ownership cosmetic passes lúc profile load (mua ngoài game / trên web).
local function syncOwnedCosmetics(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	for passId, pass in COSMETIC_PASS_TO_ITEM do
		local unlocked = if pass.category == "trail" then data.UnlockedTrails else data.UnlockedAuras
		if not unlocked[pass.id] and GamepassService.OwnsPass(player, passId) then
			unlockCosmetic(player, pass, false)
		end
	end
end

-- Đồng bộ ownership treadmill passes lúc profile load (mua ngoài game / trước khi có hệ thống).
-- LƯU Ý: KHÔNG còn reset UnlockedTreadmills trong Studio nữa — reset khiến teammate
-- đã test-buy bị khoá lại mỗi session, mà Studio test-purchase sandbox chặn mua lại
-- ("You already own this item") + web API vẫn trả false → kẹt vĩnh viễn (đã xảy ra
-- với TTDDev8: prompt báo already-own nhưng UserOwnsGamePassAsync=false cho mọi pass).
local function syncOwnedTreadmills(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	for passId, treadmillId in TREADMILL_PASS_TO_ID do
		if not data.UnlockedTreadmills[treadmillId] and GamepassService.OwnsPass(player, passId) then
			unlockTreadmill(player, treadmillId, false)
		end
	end
end

-- ============================================================================
-- Public API
-- ============================================================================

-- TreadmillService gọi khi player chạm treadmill chưa mở khoá.
-- Pre-check ownership: nếu đã sở hữu thật (mua trên web / data chưa sync) thì
-- unlock ngay thay vì hiện prompt bị Roblox chặn "You already own this item".
function GamepassService.PromptTreadmillPurchase(player: Player, treadmillId: string)
	local config = Constants.GetTreadmillById(treadmillId)
	if not config or not config.gamepassId or config.gamepassId <= 0 then
		return
	end
	local passId = config.gamepassId :: number
	task.spawn(function()
		if GamepassService.OwnsPass(player, passId) then
			markSessionOwned(player, passId)
			unlockTreadmill(player, treadmillId, true)
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
end

-- ProgressionService gọi khi player bấm mua aura/trail Robux-only.
function GamepassService.PromptCosmeticPurchase(player: Player, category: string, itemId: string)
	local passId = COSMETIC_KEY_TO_PASS[cosmeticKey(category, itemId)]
	if not passId or passId <= 0 then
		GamePackets.toast.sendTo({
			kind = "cosmetic",
			message = "Not available yet",
			amount = 0,
		}, player)
		return
	end
	task.spawn(function()
		local pass = COSMETIC_PASS_TO_ITEM[passId]
		if pass and GamepassService.OwnsPass(player, passId) then
			markSessionOwned(player, passId)
			unlockCosmetic(player, pass, true)
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
end

-- ============================================================================
-- Lifecycle
-- ============================================================================

function GamepassService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
	-- `Find` chứ không phải `Get`: StarterPackService cũng lấy GamepassService trong Init của
	-- nó, hai bên phụ thuộc chéo nên bên chạy trước không được phép nổ vì bên kia chưa sẵn
	-- sàng. Chỉ cần nó có mặt lúc người chơi bấm mua, mà lúc đó cả hai đã Init xong từ lâu.
	StarterPackService = ServiceLocator.Find("StarterPackService")
	buildMaps()
end

function GamepassService.Start()
	-- Áp quyền lợi của 1 pass (sau khi mua xong hoặc phát hiện đã sở hữu sẵn).
	local function applyPass(player: Player, passId: number)
		markSessionOwned(player, passId)

		local speedName = SPEED_PASS_NAMES[passId]
		if speedName then
			ProgressionService.RefreshGamepassCache(player)
			celebrate(player, speedName)
			return
		end

		if passId == VIP_PASS_ID and VIP_PASS_ID > 0 then
			ProgressionService.RefreshGamepassCache(player)
			syncVipAttribute(player)
			grantVipCosmetics(player)
			celebrate(player, "VIP MEMBERSHIP")
			return
		end

		-- Auto-Rebirth: snapshot mang cờ `ownsAutoRebirth` nên phải làm mới NGAY, nếu không
		-- nút toggle trong RebirthModal vẫn hiện khoá cho tới lần snapshot kế tiếp.
		if AUTO_REBIRTH_PASS_ID > 0 and passId == AUTO_REBIRTH_PASS_ID then
			ProgressionService.RefreshGamepassCache(player)
			celebrate(player, "AUTO-REBIRTH")
			return
		end

		--[[
			Gamepass Rookie Rocket ĐỜI ĐẦU (đã tắt bán, giờ gói bán bằng Developer Product).
			Nhánh này gần như không bao giờ chạy nữa — giữ cho trường hợp Roblox bắn lại sự
			kiện với người đã sở hữu. `trusted = true`: giao dịch vừa được chứng kiến tại đây.
			Không dùng `celebrate` — StarterPackService tự gửi banner riêng có liệt kê quà.
		]]
		if StarterPackService and StarterPackConfig.LEGACY_PASS_ID > 0 and passId == StarterPackConfig.LEGACY_PASS_ID then
			StarterPackService.GrantIfOwnedLegacyPass(player, true)
			return
		end

		local treadmillId = TREADMILL_PASS_TO_ID[passId]
		if treadmillId then
			unlockTreadmill(player, treadmillId, true)
			return
		end

		local cosmetic = COSMETIC_PASS_TO_ITEM[passId]
		if cosmetic then
			unlockCosmetic(player, cosmetic, true)
		end
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if purchased then
				print(`[GamepassService] {player.Name} mua pass {passId} thành công`)
				applyPass(player, passId)
				return
			end

			-- Khi purchased = false (người chơi bấm Cancel / đóng prompt):
			-- CHỈ unlock nếu tài khoản ĐÃ SỞ HỮU THẬT trên Web Roblox (UserOwnsGamePassAsync == true).
			-- Ngược lại nếu bấm Cancel và chưa sở hữu pass → TUYỆT ĐỐI KHÔNG UNLOCK.
			task.spawn(function()
				if player.Parent ~= Players then
					return
				end
				local ok, ownsOnWeb = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				print(
					`[GamepassService] {player.Name} prompt {passId} closed without purchase | ownsOnWeb = {ok and ownsOnWeb}`
				)
				if ok and ownsOnWeb == true then
					applyPass(player, passId)
				end
			end)
		end
	)

	-- [Studio-only] đổi `TestOwnedPasses` giữa chừng phải XOÁ cache ownership của session,
	-- nếu không giá trị false lưu từ lúc join sẽ dính vĩnh viễn và hook vô dụng.
	if RunService:IsStudio() then
		local function bindTestHook(player: Player)
			player:GetAttributeChangedSignal("TestOwnedPasses"):Connect(function()
				ProgressionService.RefreshGamepassCache(player)
				syncVipAttribute(player)
				grantVipCosmetics(player)
			end)
		end
		for _, player in Players:GetPlayers() do
			bindTestHook(player)
		end
		Players.PlayerAdded:Connect(bindTestHook)
	end

	-- Đồng bộ treadmill ownership khi profile sẵn sàng.
	local function pushWhenReady(player: Player)
		task.spawn(function()
			local tries = 0
			while not DataService.IsLoaded(player) and tries < 200 and player.Parent == Players do
				task.wait(0.1)
				tries += 1
			end
			if player.Parent == Players then
				syncOwnedTreadmills(player)
				syncOwnedCosmetics(player)
				syncVipAttribute(player)
				-- Người mua VIP TRƯỚC khi có hai món này (hoặc mua trên web) chỉ nhận được
				-- chúng ở đây — applyPass chỉ chạy khi giao dịch xảy ra trong session.
				grantVipCosmetics(player)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		pushWhenReady(player)
	end
	Players.PlayerAdded:Connect(pushWhenReady)

	Players.PlayerRemoving:Connect(function(player)
		sessionOwned[player] = nil
		negativeCache[player] = nil
	end)
end

return GamepassService
