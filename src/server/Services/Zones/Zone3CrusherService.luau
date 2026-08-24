--!strict
--[[
	Zone3CrusherService.luau — Server cho cụm máy ép Stage 3.

	THAY THẾ 12 script inline cũ (6 CrusherScript chạy TweenService vòng lặp + 6 KillScript
	bắt Touched). Cách cũ tốn: 6 luồng replicate CFrame liên tục + 6 connection Touched luôn
	bật kể cả khi zone không có ai.

	Bây giờ:
	  • Server KHÔNG dời piston. Vị trí = f(GetServerTimeNow) → client render local, 0 byte/frame.
	  • Sát thương phân xử tập trung ở 15Hz, mỗi player thoát sớm bằng 1 phép so hộp.
	    Không ai ở Stage 3 → vòng lặp gần như không làm gì.
	  • Piston `CanTouch=false`: không còn chi phí Touched cho engine.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local Zone3Crushers = require(ReplicatedStorage.Shared.Config.Zones.Zone3Crushers)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone3CrusherService = {}

local TICK_RATE = 1 / 15
local KILL_COOLDOWN = 1.0
local BOX = Zone3Crushers.WakeBox

type Crusher = { piston: BasePart, group: number, startX: number, endX: number, y: number, z: number }

local crushers: { Crusher } = {}
local lastKill: { [Player]: number } = {}

--=====================================================================================

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone3")
	local mechanics = zone and zone:FindFirstChild("Mechanics")
	local folder = mechanics and mechanics:FindFirstChild(Zone3Crushers.FolderName)
	if not folder then
		return false
	end

	table.clear(crushers)
	for _, model in folder:GetChildren() do
		local group = Zone3Crushers.GroupOf[model.Name]
		local piston = model:FindFirstChild("Piston")
		local startX = model:GetAttribute("StartX")
		local endX = model:GetAttribute("EndX")
		local pistonY = model:GetAttribute("PistonY")

		if group and piston and piston:IsA("BasePart") and typeof(startX) == "number" and typeof(endX) == "number" then
			-- Đồng bộ trạng thái part với mô hình "client render local".
			piston.Anchored = true
			piston.CanTouch = false
			piston.CanQuery = false
			model:SetAttribute("GroupIndex", group)

			table.insert(crushers, {
				piston = piston,
				group = group,
				startX = startX,
				endX = endX,
				y = if typeof(pistonY) == "number" then pistonY else piston.Position.Y,
				z = piston.Position.Z,
			})
		end
	end

	return #crushers > 0
end

--=====================================================================================

local function inWakeBox(pos: Vector3): boolean
	return pos.X >= BOX.MinX
		and pos.X <= BOX.MaxX
		and pos.Z >= BOX.MinZ
		and pos.Z <= BOX.MaxZ
		and pos.Y >= BOX.MinY
		and pos.Y <= BOX.MaxY
end

local function crushed(pos: Vector3, now: number): boolean
	local bodyY = pos.Y + Zone3Crushers.BodyCenterYOffset
	for i = 1, #crushers do
		local c = crushers[i]
		if math.abs(pos.Z - c.z) <= Zone3Crushers.HalfZ and math.abs(bodyY - c.y) <= Zone3Crushers.HalfY then
			local x = Zone3Crushers.PistonX(now, c.group, c.startX, c.endX)
			if math.abs(pos.X - x) <= Zone3Crushers.HalfX then
				return true
			end
		end
	end
	return false
end

local function tick()
	if #crushers == 0 then
		return
	end
	-- StreamingEnabled: cụm bị dỡ thì tham chiếu còn nhưng đã rời Workspace.
	if not crushers[1].piston:IsDescendantOf(Workspace) then
		return
	end

	local now = Workspace:GetServerTimeNow()

	for _, player in Players:GetPlayers() do
		local root = CharacterUtil.GetAliveRoot(player)
		if root and inWakeBox(root.Position) and crushed(root.Position, now) then
			local last = lastKill[player] or 0
			if now - last >= KILL_COOLDOWN then
				lastKill[player] = now
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
	end
end

--=====================================================================================

function Zone3CrusherService.Init() end

function Zone3CrusherService.Start()
	task.spawn(function()
		while not resolve() do
			task.wait(1)
		end
		Log.Boot(`[Zone3CrusherService] {#crushers} máy ép — nhóm 1&2 ép chung, nhóm 3 ép sau`)

		while true do
			task.wait(TICK_RATE)
			tick()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKill[player] = nil
	end)
end

return Zone3CrusherService
