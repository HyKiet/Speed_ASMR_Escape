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

--[[
	TÊN gói Wins cho banner chúc mừng. Viết HOA và khớp `title` của thẻ hàng trong
	`Theme.SHOP_CATALOG.products` — client tra icon banner bằng chính tên này (ICON_BY_NAME
	trong BoostCelebration dựng từ SHOP_CATALOG), lệch một chữ là rơi về icon tia sét chung.
]]
local WINS_PACK_NAMES: { [number]: string } = {
	[3608400621] = "SMALL WINS PACK",
	[3608400807] = "MEDIUM WINS PACK",
	[3608401003] = "LARGE WINS PACK",
	[3608401110] = "ULTRA WINS PACK",
}

function ProductService.ProcessReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productId = receiptInfo.ProductId

	local packWins = Products.WINS_PACKS[productId]
	if packWins then
		if ProgressionService.AwardWins(player, packWins, "product") then
			--[[
				Gói Wins là món DUY NHẤT trong shop mua xong không có gì xảy ra trên màn hình
				(user 2026-08-10): gamepass, cosmetic, Rebirth, Server Boost đều bắn
				`purchaseCelebration`, riêng gói Wins chỉ có con số ở góc trái nhích lên. Người
				vừa trả 1299 R$ xứng đáng có màn ăn mừng như mọi món khác — và đây còn là món
				dễ mua lại nhất, cảm giác lúc mua quyết định họ có mua gói thứ hai không.

				`pcall` cho đồng bộ với hai chỗ gửi kia: gói tin chúc mừng hỏng KHÔNG được phép
				làm hoá đơn trả về NotProcessedYet — Roblox sẽ tính tiền lại lần sau.
			]]
			pcall(GamePackets.purchaseCelebration.sendTo, {
				itemName = WINS_PACK_NAMES[productId] or "WINS PACK",
				subtitle = `+{Constants.FormatNumber(packWins)} Wins added instantly!`,
			}, player)
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
