--!strict
local MarketplaceService = game:GetService("MarketplaceService")

local StageCheckpointService = require(script.Parent.StageCheckpointService)
local TeleportService = require(script.Parent.TeleportService)

local ReceiptService = {}

local receiptProcessors = {
	TeleportService.ProcessReceipt,
	StageCheckpointService.ProcessReceipt,
}

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	for _, processor in receiptProcessors do
		local decision = processor(receiptInfo)
		if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
			return decision
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ReceiptService.Init()
	MarketplaceService.ProcessReceipt = processReceipt
end

function ReceiptService.Start() end

return ReceiptService
