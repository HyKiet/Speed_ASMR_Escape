--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlaytimeService = {}
local sessionTimes: { [Player]: number } = {}

function PlaytimeService.Start()
	-- Khởi tạo attribute cho người chơi khi vào game
	Players.PlayerAdded:Connect(function(player)
		sessionTimes[player] = 0
		player:SetAttribute("SessionPlaytime", 0)
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessionTimes[player] = nil
	end)

	-- Update playtime mỗi giây
	RunService.Heartbeat:Connect(function(dt)
		for player, timeAccumulated in pairs(sessionTimes) do
			local newTime = timeAccumulated + dt
			sessionTimes[player] = newTime

			-- Cập nhật attribute mỗi giây (chỉ làm tròn để giảm thiểu traffic mạng)
			local roundedOld = math.floor(timeAccumulated)
			local roundedNew = math.floor(newTime)
			if roundedNew > roundedOld then
				player:SetAttribute("SessionPlaytime", roundedNew)
			end
		end
	end)
end

function PlaytimeService.GetPlaytimeMultiplier(player: Player): number
	local seconds = player:GetAttribute("SessionPlaytime") or 0
	local minutes = math.floor(seconds / 60)

	if minutes >= 60 then
		return 4
	elseif minutes >= 40 then
		return 3
	elseif minutes >= 20 then
		return 2
	else
		return 1
	end
end

return PlaytimeService
