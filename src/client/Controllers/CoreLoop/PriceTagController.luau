--!strict
--[[
	PriceTagController.luau — gắn giá Robux THEO VÙNG lên billboard trong thế giới.

	Billboard trong Workspace (Treadmills / AuraBase / TrailBase) trước đây hardcode số
	Robux, nên (a) lệch giá Dashboard khi đổi giá, (b) sai với người chơi ở vùng có
	regional pricing khác. Controller này ghi đè text lúc runtime bằng giá LIVE lấy từ
	MarketplaceService phía client → luôn khớp đúng con số trong prompt thanh toán.

	⚠️ Workspace.StreamingEnabled = true: lúc client Start, Lobby CHƯA replicate xong,
	và model có thể stream out/in nhiều lần trong phiên chơi. Mỗi lần stream vào là một
	instance MỚI mang lại text hardcode cũ. Nên KHÔNG thể quét một lần rồi thôi —
	phải bám `DescendantAdded` để sơn lại giá cho mọi billboard vừa xuất hiện.

	Cấu trúc billboard (dựng sẵn trong Studio, KHÔNG tạo mới ở đây):
		Treadmill_x3 [Model]        |  Dark [Folder]              ← tên khớp `id` trong config
		└── Billboard [Part]        |  └── Base [Model]
		    └── Title [BillboardGui]|      └── Billboard [Part]
		        ├── Main [Frame]    ←  tên + icon (giữ nguyên)
		        └── Requirement [Frame]
		            └── Title [TextLabel]     ← ghi giá vào đây
		                └── Color [TextLabel] ← bản gradient chồng lên, phải ghi cùng text
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)

local PriceTagController = {}

local BILLBOARD_NAME = "Billboard"
local CHILD_TIMEOUT_SECONDS = 10

type PriceTarget = {
	gamepassId: number,
	-- Text thay cho giá khi gamepassId == 0 (treadmill free).
	freeText: string?,
	-- Giá trong config — hiển thị tạm khi chưa điền gamepassId hoặc fetch giá live lỗi.
	fallbackPrice: number?,
}

-- Tên Model/Folder sở hữu billboard → giá phải hiện.
local targetsByOwnerName: { [string]: PriceTarget } = {}

local function buildTargets()
	for _, treadmill in Constants.TREADMILLS :: { Constants.TreadmillConfig } do
		local modelName = string.format("Treadmill_x%d", math.floor(treadmill.multiplier))
		targetsByOwnerName[modelName] = { gamepassId = treadmill.gamepassId, freeText = "FREE" }
	end

	-- Folder trong AuraBase / TrailBase trùng tên với `id` trong config.
	-- Chỉ món BÁN BẰNG ROBUX mới có billboard giá; món mua bằng Wins không dựng trong Lobby.
	-- Món chưa điền gamepassId vẫn đăng ký với giá config làm fallback — người chơi thấy
	-- đúng giá dự kiến; khi điền ID thật thì tự chuyển sang giá live theo vùng.
	local function registerCosmetic(id: string, gamepassId: number, priceRobux: number, robuxOnly: boolean)
		if gamepassId > 0 or priceRobux > 0 or robuxOnly then
			targetsByOwnerName[id] = {
				gamepassId = gamepassId,
				fallbackPrice = if priceRobux > 0 then priceRobux else nil,
			}
		end
	end

	for _, aura in Constants.AURAS :: { Constants.AuraConfig } do
		registerCosmetic(aura.id, aura.gamepassId, aura.priceRobux, aura.robuxOnly)
	end
	for _, trail in Constants.TRAILS :: { Constants.TrailConfig } do
		registerCosmetic(trail.id, trail.gamepassId, trail.priceRobux, trail.robuxOnly)
	end
end

-- Billboard là con trực tiếp của Treadmill_xN, hoặc cháu qua Base của folder aura/trail.
local function findTarget(billboard: BasePart): PriceTarget?
	local parent = billboard.Parent
	if not parent then
		return nil
	end
	local direct = targetsByOwnerName[parent.Name]
	if direct then
		return direct
	end
	local grandparent = parent.Parent
	return if grandparent then targetsByOwnerName[grandparent.Name] else nil
end

-- Streaming có thể giao Billboard trước khi giao con của nó → chờ từng cấp.
local function waitForChild(parent: Instance, name: string): Instance?
	return parent:WaitForChild(name, CHILD_TIMEOUT_SECONDS)
end

local function applyPrice(billboard: BasePart)
	local target = findTarget(billboard)
	if not target then
		return
	end

	task.spawn(function()
		local text: string
		if target.gamepassId > 0 then
			-- Giá live theo vùng; fetch lỗi thì lùi về giá config thay vì "SOON".
			local price = RobuxPrice.GetAsync(target.gamepassId) or target.fallbackPrice
			text = RobuxPrice.Format(price)
		elseif target.freeText then
			text = target.freeText
		else
			text = RobuxPrice.Format(target.fallbackPrice)
		end

		local gui = waitForChild(billboard, "Title")
		local requirement = gui and waitForChild(gui, "Requirement")
		local title = requirement and waitForChild(requirement, "Title")
		if not title or not title:IsA("TextLabel") then
			warn(`[PriceTagController] {billboard:GetFullName()} thiếu Requirement.Title`)
			return
		end

		-- Billboard có thể đã stream out trong lúc đang chờ giá.
		if not billboard:IsDescendantOf(Workspace) then
			return
		end

		title.Text = text
		local color = title:FindFirstChild("Color")
		if color and color:IsA("TextLabel") then
			color.Text = text
		end
	end)
end

function PriceTagController.Start()
	buildTargets()

	-- Nạp sẵn giá để billboard stream vào sau được sơn ngay (không phải chờ web request).
	for _, target in targetsByOwnerName do
		if target.gamepassId > 0 then
			task.spawn(RobuxPrice.GetAsync, target.gamepassId)
		end
	end

	for _, descendant in Workspace:GetDescendants() do
		if descendant.Name == BILLBOARD_NAME and descendant:IsA("BasePart") then
			applyPrice(descendant)
		end
	end

	-- Mỗi lần model stream vào lại là instance mới mang text hardcode cũ → sơn lại.
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == BILLBOARD_NAME and descendant:IsA("BasePart") then
			applyPrice(descendant)
		end
	end)
end

return PriceTagController
