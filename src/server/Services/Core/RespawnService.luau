--!strict
-- Khi player bị giết bởi BẤT KỲ thứ gì → hồi sinh về Lobby NHANH NHẤT có thể.
-- Roblox mặc định RespawnTime = 5s (quá lâu). Hạ xuống mức rất thấp + auto-load nhân vật.
-- Spawn về Lobby do Workspace.SpawnLocation (lobby) là SpawnLocation duy nhất.
--
-- HƯỚNG NHÌN LÚC SPAWN
-- ====================
-- `Workspace.Spawn.SpawnLocation` (NGOÀI Lobby — xem PathResolver.FindLobbySpawn) có
-- LookVector = (0,0,-1) trong khi toàn bộ zone
-- nằm về phía +Z ⇒ Roblox đặt nhân vật QUAY LƯNG vào các zone mỗi lần vào game và mỗi
-- lần chết đi sống lại. Xoay part trong Studio cũng sửa được, nhưng đó là place data
-- (Rojo không quản) nên dễ mất — chốt hướng bằng code ở đây.
--
-- Chỉ đổi YAW, giữ nguyên vị trí, và phải gửi `snapCamera`: camera là của client, server
-- xoay character thôi thì người chơi vẫn nhìn theo khung hình cũ.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local StageFacing = require(ReplicatedStorage.Shared.Util.StageFacing)

local RespawnService = {}

local RESPAWN_TIME = 0.4 -- giây chờ trước khi hồi sinh (đủ để thấy hiệu ứng chết, vẫn rất nhanh)
local ROOT_WAIT_SECONDS = 5

local function faceZones(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", ROOT_WAIT_SECONDS)
	if not root or not root:IsA("BasePart") then
		return
	end

	-- Nhân vật vừa spawn: chờ engine đặt xong CFrame ban đầu rồi mới xoay, nếu không
	-- phép xoay của mình bị chính bước đặt vị trí của engine ghi đè.
	task.wait()
	if character.Parent == nil or root.Parent ~= character then
		return
	end

	-- Hướng "phía trước" = từ chỗ đứng nhìn về cổng Zone 1 (suy từ hình học, xem StageFacing).
	local oriented = StageFacing.Orient(root.Position, 1, root.CFrame)
	root.CFrame = oriented

	local look = oriented.LookVector
	pcall(GamePackets.snapCamera.sendTo, { lookX = look.X, lookZ = look.Z }, player)
end

local function bindPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(faceZones, player, character)
	end)
	if player.Character then
		task.spawn(faceZones, player, player.Character)
	end
end

function RespawnService.Init()
	Players.CharacterAutoLoads = true
	Players.RespawnTime = RESPAWN_TIME
end

function RespawnService.Start()
	-- Bảo hiểm: giữ RespawnTime thấp kể cả khi có script khác đổi.
	Players.RespawnTime = RESPAWN_TIME

	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerAdded:Connect(bindPlayer)
end

return RespawnService
