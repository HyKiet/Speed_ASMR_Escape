--!strict
-- Server dùng CharacterUtil để xử lý người chạm KillBlockGlobal.
-- Janitor dọn listener theo folder và từng part khi map thêm hoặc gỡ kill block.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local KillBlockService = {}

local FOLDER_NAME = "KillBlockGlobal"
local KILL_COOLDOWN = 0.8 -- GIây: Cooldown diệt người chơi chống spam

local lastKillTime: { [Player]: number } = {}
local folderJanitors: { [Folder]: any } = {}

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

local function scanFolder(folder: Folder)
	if folderJanitors[folder] then
		return
	end
	local janitor: any = Janitor.new()
	folderJanitors[folder] = janitor
	local function bindPart(part: Instance)
		if part:IsA("BasePart") and not janitor[part] then
			part.CanTouch = true
			janitor[part] = part.Touched:Connect(handleTouch)
		end
	end

	janitor:Add(folder.DescendantAdded:Connect(bindPart))
	janitor:Add(folder.DescendantRemoving:Connect(function(part)
		-- Xoá key của Janitor đồng thời ngắt listener của part đó.
		janitor[part] = nil
	end))
	for _, desc in folder:GetDescendants() do
		bindPart(desc)
	end
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
	Workspace.ChildRemoved:Connect(function(child)
		if child:IsA("Folder") then
			local janitor = folderJanitors[child]
			if janitor then
				folderJanitors[child] = nil
				janitor:Sweep()
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKillTime[player] = nil
	end)

	Log.Boot("[KillBlockService] KillBlockGlobal Touch-Kill System Initialized.")
end

return KillBlockService
