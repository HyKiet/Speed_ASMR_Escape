--!strict
-- Bộ định tuyến ProcessReceipt: thử lần lượt các Service đăng ký xử lý hóa đơn.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local ReceiptService = {}

local processors: { (any) -> Enum.ProductPurchaseDecision } = {}

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
	processors = {
		teleport.ProcessReceipt,
		stage.ProcessReceipt,
		serverBoost.ProcessReceipt,
		roulette.ProcessReceipt,
		starterPack.ProcessReceipt,
		product.ProcessReceipt,
	}

	MarketplaceService.ProcessReceipt = processReceipt
end

function ReceiptService.Start() end

return ReceiptService
