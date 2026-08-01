--!strict
--[[
	Ownership.luau — theo dõi player đã sở hữu gamepass nào, phía CLIENT.

	VÌ SAO CẦN: Shop vẽ nút giá cho mọi card bất kể đã mua hay chưa, nên người chơi mua rồi
	vẫn thấy nút "◉ 399" và bấm lại chỉ để Roblox báo "You already own this item".

	Không phải module Controller (không có Init/Start) — chỉ là kho state dùng chung cho
	ShopModal + RightPanel, hai nơi trước đây mỗi nơi tự hỏi `UserOwnsGamePassAsync` một kiểu.

	Trả về Fusion `Value(boolean)` chứ không phải boolean: câu trả lời tới BẤT ĐỒNG BỘ (một
	web request), UI phải tự cập nhật khi có kết quả thay vì đọc một lần lúc dựng rồi kẹt
	mãi ở `false`.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local Value = Fusion.Value

local Ownership = {}

local localPlayer = Players.LocalPlayer

-- Studio: coi như CHƯA sở hữu pass nào để test được luồng mua; pass mua trong phiên vẫn tính.
local IS_STUDIO = RunService:IsStudio()

local states: { [number]: any } = {}
local boughtThisSession: { [number]: boolean } = {}

local function fetch(passId: number)
	task.spawn(function()
		if IS_STUDIO then
			return
		end
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, passId)
		end)
		if ok and owns == true then
			states[passId]:set(true)
		end
	end)
end

-- Value(boolean) cho một gamepass. Gọi nhiều lần cùng id trả về CÙNG một Value.
function Ownership.Owns(passId: number)
	if passId <= 0 then
		return Value(false)
	end
	local existing = states[passId]
	if existing then
		return existing
	end
	local state = Value(boughtThisSession[passId] == true)
	states[passId] = state
	fetch(passId)
	return state
end

-- Pass rẻ nhất trong danh sách mà người chơi CHƯA sở hữu (0 = đã sở hữu hết).
-- Dùng cho promo speed pass ở RightPanel.
function Ownership.FirstUnowned(passIds: { number }): number
	for index, passId in passIds do
		if not Ownership.Owns(passId):get() then
			return index
		end
	end
	return 0
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if player ~= localPlayer or not purchased then
		return
	end
	boughtThisSession[passId] = true
	local state = states[passId]
	if state then
		state:set(true)
	end
end)

return Ownership
