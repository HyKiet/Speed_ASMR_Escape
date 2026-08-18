--!strict
local Players = game:GetService("Players")

local FriendService = {}

local friendsInServer: { [Player]: number } = {}

local function updateFriendsCount()
	local players = Players:GetPlayers()
	local counts = {}
	for _, p in players do
		counts[p] = 0
	end

	local pairsToCheck = {}
	for i = 1, #players do
		for j = i + 1, #players do
			table.insert(pairsToCheck, { p1 = players[i], p2 = players[j] })
		end
	end

	for _, pair in pairsToCheck do
		if not pair.p1.Parent or not pair.p2.Parent then
			continue
		end
		local ok, isFriends = pcall(function()
			return pair.p1:IsFriendsWith(pair.p2.UserId)
		end)
		if ok and isFriends then
			if counts[pair.p1] then
				counts[pair.p1] += 1
			end
			if counts[pair.p2] then
				counts[pair.p2] += 1
			end
		end
	end

	for p, count in counts do
		if not p.Parent then
			continue
		end
		if friendsInServer[p] ~= count then
			friendsInServer[p] = count
			local ServiceLocator = require(game:GetService("ReplicatedStorage").Shared.Util.ServiceLocator)
			local ProgressionService = ServiceLocator.Get("ProgressionService")
			if ProgressionService then
				ProgressionService.SendSnapshot(p)
			end
		end
	end
end

function FriendService.GetFriendsInServer(player: Player): number
	return friendsInServer[player] or 0
end

function FriendService.GetFriendsMultiplier(player: Player): number
	local count = math.min(5, FriendService.GetFriendsInServer(player))
	return 1 + (count * 0.1)
end

function FriendService.Init() end

function FriendService.Start()
	Players.PlayerAdded:Connect(function(player)
		friendsInServer[player] = 0
		task.spawn(updateFriendsCount)
	end)

	Players.PlayerRemoving:Connect(function(player)
		friendsInServer[player] = nil
		task.spawn(updateFriendsCount)
	end)
end

return FriendService
