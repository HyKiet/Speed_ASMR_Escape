--!strict
-- Xử lý hóa đơn Dev Product chung: Wins Packs (4 gói) + Skip Rebirth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Products = require(ReplicatedStorage.Shared.Config.Economy.Products)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local DataService: any = nil
local ProgressionService: any = nil

local ProductService = {}

function ProductService.ProcessReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	local packWins = Products.WINS_PACKS[productId]
	if packWins then
		if ProgressionService.AwardWins(player, packWins, "product") then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if productId == Products.SKIP_REBIRTH_PRODUCT_ID then
		local data = DataService.GetData(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if ProgressionService.ForceRebirth(player) then
			GamePackets.toast.sendTo({ kind = "rebirth", message = "Skip Rebirth!", amount = data.Rebirths }, player)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function ProductService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
end

function ProductService.Start() end

return ProductService
