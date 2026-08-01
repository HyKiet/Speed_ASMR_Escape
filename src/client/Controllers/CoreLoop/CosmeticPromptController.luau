--!strict
--[[
	CosmeticPromptController.luau — Quản lý ProximityPrompt (nút E) trên bệ Aura & Trail.

	Khi player tiến lại gần bệ trưng bày Aura/Trail trong Lobby, hiển thị ProximityPrompt
	phím E (ActionText: "Buy Pass", ObjectText: Tên Cosmetic) ĐẶT TẠI RIG MANNEQUIN.
	Khi nhấn E, tự động gọi MarketplaceService:PromptGamePassPurchase() để mở khung thanh toán Robux.

	⚠️ Workspace.StreamingEnabled = true: Xử lý cả khi bệ stream in/out lúc runtime.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)

local CosmeticPromptController = {}

local PROMPT_NAME = "CosmeticPrompt"
local LocalPlayer = Players.LocalPlayer

type CosmeticInfo = {
	name: string,
	gamepassId: number,
}

local cosmeticMap: { [string]: CosmeticInfo } = {}

local function buildCosmeticMap()
	for _, aura in Constants.AURAS do
		if aura.gamepassId and aura.gamepassId > 0 then
			cosmeticMap[aura.id] = {
				name = aura.name,
				gamepassId = aura.gamepassId,
			}
		end
	end
	for _, trail in Constants.TRAILS do
		if trail.gamepassId and trail.gamepassId > 0 then
			cosmeticMap[trail.id] = {
				name = trail.name,
				gamepassId = trail.gamepassId,
			}
		end
	end
end

local function attachPromptToFolder(folder: Instance)
	local info = cosmeticMap[folder.Name]
	if not info then
		return
	end

	-- Ưu tiên 1: Rig mannequin (HumanoidRootPart hoặc BasePart trong Rig)
	local targetPart: BasePart? = nil
	local rig = folder:FindFirstChild("Rig")
	if rig then
		targetPart = rig:FindFirstChild("HumanoidRootPart") or rig:FindFirstChild("Torso") or rig:FindFirstChildWhichIsA("BasePart", true)
	end

	-- Ưu tiên 2: BasePart vật lý cố định trên mặt đất của bệ (Bỏ qua Billboard và Part có Script di chuyển)
	if not targetPart or not targetPart:IsA("BasePart") then
		for _, descendant in ipairs(folder:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name ~= "Billboard" and not descendant:FindFirstChildWhichIsA("Script") then
				targetPart = descendant
				break
			end
		end
	end

	-- Ưu tiên 3: Fallback Billboard part nếu bệ không có part nào khác
	if not targetPart or not targetPart:IsA("BasePart") then
		targetPart = folder:FindFirstChild("Billboard", true)
	end

	if not targetPart or not targetPart:IsA("BasePart") then
		return
	end

	-- Dọn dẹp prompt cũ ở các part khác (nhất là part di chuyển)
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= targetPart then
			local oldPrompt = descendant:FindFirstChild(PROMPT_NAME)
			if oldPrompt then
				oldPrompt:Destroy()
			end
		end
	end


	local prompt = targetPart:FindFirstChild(PROMPT_NAME)
	if not prompt then
		local newPrompt = Instance.new("ProximityPrompt")
		newPrompt.Name = PROMPT_NAME
		newPrompt.ObjectText = info.name
		newPrompt.ActionText = "Buy Pass"
		newPrompt.KeyboardKeyCode = Enum.KeyCode.E
		newPrompt.HoldDuration = 0
		newPrompt.MaxActivationDistance = 9
		newPrompt.RequiresLineOfSight = false
		newPrompt.Parent = targetPart
		prompt = newPrompt
	else
		prompt = prompt :: ProximityPrompt
	end

	-- Tránh bind trùng listener
	if not prompt:GetAttribute("BoundToPurchase") then
		prompt:SetAttribute("BoundToPurchase", true)
		prompt.Triggered:Connect(function(player: Player)
			if player == LocalPlayer and info.gamepassId > 0 then
				MarketplaceService:PromptGamePassPurchase(LocalPlayer, info.gamepassId)
			end
		end)
	end
end

local function scanAndAttachAll()
	local auraBase = Workspace:FindFirstChild("AuraBase", true)
	if auraBase then
		for _, folder in auraBase:GetChildren() do
			attachPromptToFolder(folder)
		end
	end

	local trailBase = Workspace:FindFirstChild("TrailBase", true)
	if trailBase then
		for _, folder in trailBase:GetChildren() do
			attachPromptToFolder(folder)
		end
	end
end

function CosmeticPromptController.Start()
	buildCosmeticMap()
	scanAndAttachAll()

	-- Lắng hệ khi model bệ stream-in vào Workspace
	Workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Folder") and (descendant.Parent and (descendant.Parent.Name == "AuraBase" or descendant.Parent.Name == "TrailBase")) then
			attachPromptToFolder(descendant)
		elseif descendant:IsA("BasePart") and descendant.Name == "Billboard" then
			local folder = descendant.Parent
			if folder and folder.Parent and (folder.Parent.Name == "AuraBase" or folder.Parent.Name == "TrailBase") then
				attachPromptToFolder(folder)
			elseif folder and folder.Parent and folder.Parent.Parent and (folder.Parent.Parent.Name == "AuraBase" or folder.Parent.Parent.Name == "TrailBase") then
				attachPromptToFolder(folder.Parent)
			end
		end
	end)
end

return CosmeticPromptController
