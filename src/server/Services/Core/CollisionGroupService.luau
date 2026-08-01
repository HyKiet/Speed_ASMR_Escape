--!strict
--[[
	CollisionGroupService.luau — Tắt va chạm giữa người chơi với nhau.

	Đăng ký CollisionGroup "Players" (không đụng nhóm khác), set Players×Players = false,
	rồi gán mọi BasePart trong nhân vật vào nhóm này (kể cả accessory/part thêm vào sau
	qua DescendantAdded). 25 player chen chúc ở lobby/treadmill sẽ không xô đẩy nhau —
	vừa mượt vừa chặn trò kẹp người/đẩy người vào bẫy.
]]

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP_NAME = "Players"

local CollisionGroupService = {}

local function setCharacterGroup(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GROUP_NAME
		end
	end

	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GROUP_NAME
		end
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		setCharacterGroup(player.Character)
	end
	player.CharacterAdded:Connect(setCharacterGroup)
end

function CollisionGroupService.Init()
	-- RegisterCollisionGroup lỗi nếu nhóm đã tồn tại (save cũ) → pcall cho an toàn.
	pcall(function()
		PhysicsService:RegisterCollisionGroup(GROUP_NAME)
	end)
	PhysicsService:CollisionGroupSetCollidable(GROUP_NAME, GROUP_NAME, false)
end

function CollisionGroupService.Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
end

return CollisionGroupService
