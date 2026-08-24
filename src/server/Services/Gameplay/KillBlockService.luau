--!strict
--[[
	KillBlockService.luau — Quản lý va chạm và tiêu diệt người chơi cho KillBlockGlobal:
	  1. Quét toàn bộ BasePart trong Workspace.KillBlockGlobal.
	  2. Lắng nghe sự kiện Touched: khi người chơi va chạm sẽ lập tức làm rỗng Health (chết).
	  3. Có Cooldown chống spam log và hỗ trợ các Part được spawn sau (DescendantAdded).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local KillBlockService = {}

local FOLDER_NAME = "KillBlockGlobal"
local KILL_COOLDOWN = 0.8 -- GIây: Cooldown diệt người chơi chống spam

local lastKillTime: { [Player]: number } = {}
local connectedParts: { [BasePart]: RBXScriptConnection } = {}

local function handleTouch(hit: BasePart)
	local player, humanoid = CharacterUtil.GetPlayerFromHit(hit)
	if not player or not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local last = lastKillTime[player] or 0
	if now - last < KILL_COOLDOWN then
		return
	end

	lastKillTime[player] = now
	humanoid.Health = 0
end

local function bindPart(part: Instance)
	if part:IsA("BasePart") and not connectedParts[part] then
		part.CanTouch = true
		connectedParts[part] = part.Touched:Connect(handleTouch)
	end
end

local function unbindPart(part: Instance)
	if part:IsA("BasePart") and connectedParts[part] then
		connectedParts[part]:Disconnect()
		connectedParts[part] = nil
	end
end

local function scanFolder(folder: Folder)
	for _, desc in folder:GetDescendants() do
		bindPart(desc)
	end

	folder.DescendantAdded:Connect(bindPart)
	folder.DescendantRemoving:Connect(unbindPart)
end

function KillBlockService.Init() end

function KillBlockService.Start()
	-- 1. Scan folder hiện tại nếu đã có trong Workspace
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		scanFolder(folder)
	end

	-- 2. Lắng nghe khi folder KillBlockGlobal được tạo muộn
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == FOLDER_NAME and child:IsA("Folder") then
			scanFolder(child)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKillTime[player] = nil
	end)

	Log.Boot("[KillBlockService] KillBlockGlobal Touch-Kill System Initialized.")
end

return KillBlockService
