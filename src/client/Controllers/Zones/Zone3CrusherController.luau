--!strict
--[[
	Zone3CrusherController.luau — render local 6 máy ép Stage 3.

	Server không dời piston (xem Zone3CrusherService): vị trí suy ra từ
	`workspace:GetServerTimeNow()` nên mọi client thấy y hệt nhau mà không tốn băng thông.
	Piston vẫn `CanCollide = true` — nhân vật do chính client mô phỏng nên vẫn bị đẩy/ép
	đúng như hình đang thấy.

	Cull một lần cho cả cụm: 6 máy ép nằm gọn trong 140 studs nên dùng chung một tâm là đủ
	(khác Zone 15 trải 3.800 studs phải cull theo từng cụm).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Zone3Crushers = require(ReplicatedStorage.Shared.Config.Zones.Zone3Crushers)

local RENDER_RADIUS = 320
local RENDER_RADIUS_SQ = RENDER_RADIUS * RENDER_RADIUS
local RESOLVE_INTERVAL = 0.5

local Zone3CrusherController = {}

local player = Players.LocalPlayer

type Crusher = { piston: BasePart, rot: CFrame, group: number, startX: number, endX: number, y: number, z: number }

local crushers: { Crusher } = {}
local centerX, centerZ = 0, 0
local awake = false
local connection: RBXScriptConnection? = nil

local function resolve()
	table.clear(crushers)

	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone3")
	local mechanics = zone and zone:FindFirstChild("Mechanics")
	local folder = mechanics and mechanics:FindFirstChild(Zone3Crushers.FolderName)
	if not folder then
		return
	end

	local sumX, sumZ = 0, 0
	for _, model in folder:GetChildren() do
		local group = model:GetAttribute("GroupIndex")
		local piston = model:FindFirstChild("Piston")
		local startX = model:GetAttribute("StartX")
		local endX = model:GetAttribute("EndX")
		local pistonY = model:GetAttribute("PistonY")

		if
			typeof(group) == "number"
			and piston
			and piston:IsA("BasePart")
			and typeof(startX) == "number"
			and typeof(endX) == "number"
		then
			-- Piston chỉ trượt dọc X: Y/Z lấy từ attribute + vị trí gốc nên KHÔNG bị trôi
			-- dù controller đã dời part (khác trục X, không đọc lại bao giờ).
			table.insert(crushers, {
				piston = piston,
				rot = piston.CFrame.Rotation,
				group = group,
				startX = startX,
				endX = endX,
				y = if typeof(pistonY) == "number" then pistonY else piston.Position.Y,
				z = piston.Position.Z,
			})
			sumX += (startX + endX) * 0.5
			sumZ += piston.Position.Z
		end
	end

	-- Thiếu máy ép nào đó (streaming nạp lẻ) → bỏ hết, lượt poll sau thử lại.
	local expected = 0
	for _ in Zone3Crushers.GroupOf do
		expected += 1
	end
	if #crushers ~= expected then
		table.clear(crushers)
		return
	end

	centerX, centerZ = sumX / #crushers, sumZ / #crushers
end

local function alive(): boolean
	return #crushers > 0 and crushers[1].piston:IsDescendantOf(Workspace)
end

local function step()
	if not alive() then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local pos = root.Position
	local dx, dz = pos.X - centerX, pos.Z - centerZ
	if dx * dx + dz * dz > RENDER_RADIUS_SQ then
		-- SLEEP: đưa piston về đúng tư thế nghỉ MỘT LẦN rồi thôi động vào part nữa,
		-- tránh cảnh máy ép đứng chết cứng giữa nhịp khi nhìn từ xa.
		if awake then
			awake = false
			for i = 1, #crushers do
				local c = crushers[i]
				c.piston.CFrame = CFrame.new(c.startX, c.y, c.z) * c.rot
			end
		end
		return
	end
	awake = true

	local now = Workspace:GetServerTimeNow()
	for i = 1, #crushers do
		local c = crushers[i]
		local x = Zone3Crushers.PistonX(now, c.group, c.startX, c.endX)
		c.piston.CFrame = CFrame.new(x, c.y, c.z) * c.rot
	end
end

function Zone3CrusherController.Init() end

function Zone3CrusherController.Start()
	connection = RunService.RenderStepped:Connect(step)

	task.spawn(function()
		while true do
			if not alive() then
				resolve()
			end
			task.wait(RESOLVE_INTERVAL)
		end
	end)
end

function Zone3CrusherController.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Zone3CrusherController
