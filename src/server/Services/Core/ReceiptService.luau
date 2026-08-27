--!strict
-- Bộ định tuyến ProcessReceipt: thử lần lượt các Service đăng ký xử lý hóa đơn.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local ReceiptService = {}

local processors: { (any) -> Enum.ProductPurchaseDecision } = {}
local LeaderboardService

--[[
	GHI DONATE Ở ĐÂY, KHÔNG Ở TỪNG SERVICE (2026-08-26, user báo bảng Top Donate trống trên
	Live dù đã mua thật bằng tài khoản khác).

	Nguyên nhân của cái bảng trống: `LeaderboardService.RecordDonation` tồn tại, đúng logic,
	có publish — nhưng KHÔNG AI GỌI NÓ. Không một dòng nào trong `src/`. Nên
	`data.TotalDonatedRobux` đứng yên ở 0 mãi mãi, và `publishPlayer` cố tình bỏ qua mốc 0
	(để bảng Donate không thành một rừng key giá trị 0) ⇒ kho OrderedDataStore rỗng ⇒ bảng rỗng.
	Cả chuỗi im lặng tuyệt đối: không lỗi, không warn, không gì cả.

	Móc vào ĐÂY vì đây là cửa duy nhất mọi developer product phải đi qua. Móc vào từng
	service (Teleport/Stage/Boost/Roulette/StarterPack/Product) là lặp lại đúng kiểu hỏng vừa
	rồi: thêm một sản phẩm mới mà quên một dòng thì Robux của nó biến mất khỏi bảng, và không
	có gì báo cho ai biết.

	`CurrencySpent` là số Robux THỰC TRẢ do Roblox gửi kèm hoá đơn — không tự đọc giá từ config
	game, vì giá trong config có thể lệch với giá thật trên Creator Dashboard.
]]
local function recordDonation(receiptInfo: { [string]: any })
	if not LeaderboardService then
		return
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return
	end
	local spent = tonumber(receiptInfo.CurrencySpent) or 0
	if spent <= 0 then
		return
	end
	-- pcall: bảng xếp hạng KHÔNG được phép làm hỏng việc giao hàng. Hoá đơn đã grant rồi.
	local ok, err = pcall(LeaderboardService.RecordDonation, player, spent)
	if not ok then
		warn(`[ReceiptService] RecordDonation lỗi cho {player.Name}: {err}`)
	end
end

--[[
	⚠️ MỖI processor phải chạy trong pcall RIÊNG.

	Bản cũ gọi thẳng `processor(receiptInfo)`. Chỉ cần MỘT service ném lỗi (ví dụ đọc
	`data.X` khi profile chưa load xong) là:
	  1. Các processor phía sau KHÔNG BAO GIỜ được thử → sản phẩm của chúng cũng chết theo,
	     dù bản thân chúng hoàn toàn lành lặn.
	  2. Callback ProcessReceipt ném lỗi ⇒ Roblox coi như chưa xử lý và thử lại liên tục,
	     trong khi người chơi ĐÃ BỊ TRỪ ROBUX.
	Ở quy mô hàng ngàn CCU thì một lỗi hiếm gặp cũng thành hàng loạt đơn không giao được.

	Trả `NotProcessedYet` khi không ai nhận là ĐÚNG: Roblox sẽ gọi lại sau, tiền không mất.
]]
local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	for _, processor in processors do
		local ok, decision = pcall(processor, receiptInfo)
		if not ok then
			warn(`[ReceiptService] processor lỗi khi xử lý ProductId {receiptInfo.ProductId}: {decision}`)
			continue
		end
		if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
			-- CHỈ ghi khi đã grant thật. `NotProcessedYet` nghĩa là Roblox sẽ gọi lại hoá đơn
			-- này — ghi ở đó là cộng dồn nhiều lần cho một lần mua.
			recordDonation(receiptInfo)
			return decision
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ReceiptService.Init()
	local teleport = ServiceLocator.Get("TeleportService")
	local stage = ServiceLocator.Get("StageCheckpointService")
	local serverBoost = ServiceLocator.Get("ServerBoostService")
	local roulette = ServiceLocator.Get("RouletteService")
	local product = ServiceLocator.Get("ProductService")
	local starterPack = ServiceLocator.Get("StarterPackService")
	local offline = ServiceLocator.Get("OfflineEarningsService")
	-- `Find`: bảng xếp hạng là thứ phụ, thiếu nó thì hoá đơn vẫn phải giao được.
	LeaderboardService = ServiceLocator.Find("LeaderboardService")
	processors = {
		teleport.ProcessReceipt,
		stage.ProcessReceipt,
		serverBoost.ProcessReceipt,
		roulette.ProcessReceipt,
		starterPack.ProcessReceipt,
		offline.ProcessReceipt,
		product.ProcessReceipt,
	}

	MarketplaceService.ProcessReceipt = processReceipt
end

function ReceiptService.Start() end

return ReceiptService
