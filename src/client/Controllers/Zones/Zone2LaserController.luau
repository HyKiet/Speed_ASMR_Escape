--!strict
--[[
	Zone2LaserController.luau — render local dàn laser quét Stage 2.

	Server không xoay Pivot (xem Zone2LaserService): góc quay suy ra từ
	`workspace:GetServerTimeNow()` nên client dựng lại y hệt → 0 byte replicate CFrame.
	Beam hàn vào Pivot nên chỉ cần xoay Pivot, beam theo.

	Cull theo TỪNG laser: dải Stage 2 trải dọc ~270 studs. Ngoài tầm thì để Pivot ở base
	MỘT LẦN rồi thôi (tránh part đứng chết cứng ở góc dở dang khi nhìn từ xa).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Zone2Lasers = require(ReplicatedStorage.Shared.Config.Zones.Zone2Lasers)
local ZoneLod = require(script.Parent.ZoneLod)

-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed — xem ZoneLod.
-- 240 là con số tệ nhất trong cả game: dải Stage 2 dài ~270 studs nên ở 250 WS người chơi
-- nhìn thấy cả ba laser đứng chết cứng suốt hành lang rồi mới bật lên lúc sát mặt.
local RENDER_RADIUS = 240
local RESOLVE_INTERVAL = 0.5

local Zone2LaserController = {}

type Laser = {
	pivot: BasePart,
	base: CFrame,
	rpm: number,
	dir: number,
	cx: number,
	cz: number,
	awake: boolean,
	-- Mốc thời gian cho nhịp hạ tần khi laser này ở xa (xem ZoneLod.ShouldStepFar).
	nextFar: number,
}

local lasers: { Laser } = {}
local connection: RBXScriptConnection? = nil
local resolverThread: thread? = nil

local function resolve()
	table.clear(lasers)

	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(Zone2Lasers.ZoneName)
	if not zone or zone:GetAttribute(Zone2Lasers.ReadyAttribute) ~= true then
		return
	end
	local mechanics = zone:FindFirstChild("Mechanics")
	if not mechanics then
		return
	end

	for _, model in mechanics:GetChildren() do
		if model:IsA("Model") and Zone2Lasers.Defaults[model.Name] then
			local pivot = model:FindFirstChild("Pivot")
			local rpm = model:GetAttribute("RPM")
			local dir = model:GetAttribute("Dir")
			local baseCF = pivot and pivot:GetAttribute("BaseCF")
			-- Đọc BaseCF từ attribute (server ghi) — KHÔNG lấy pivot.CFrame vì client đã dời nó.
			if
				pivot
				and pivot:IsA("BasePart")
				and typeof(rpm) == "number"
				and typeof(dir) == "number"
				and typeof(baseCF) == "CFrame"
			then
				table.insert(lasers, {
					pivot = pivot,
					base = baseCF,
					rpm = rpm,
					dir = dir,
					cx = baseCF.Position.X,
					cz = baseCF.Position.Z,
					awake = false,
					nextFar = 0,
				})
			end
		end
	end
end

-- Đếm số laser ĐÃ stream (model có Pivot + BaseCF). StreamingEnabled nạp lẻ từng laser:
-- nếu chỉ so `#lasers > 0` thì laser gần nhất resolve xong là dừng, các laser xa stream sau
-- KHÔNG BAO GIỜ được thêm → không xoay (đã dính: chỉ LaserSweeper1 xoay).
local function streamedCount(): number
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(Zone2Lasers.ZoneName)
	local mechanics = zone and zone:FindFirstChild("Mechanics")
	if not mechanics then
		return 0
	end
	local n = 0
	for _, model in mechanics:GetChildren() do
		if model:IsA("Model") and Zone2Lasers.Defaults[model.Name] then
			local pivot = model:FindFirstChild("Pivot")
			if pivot and pivot:GetAttribute("BaseCF") ~= nil then
				n += 1
			end
		end
	end
	return n
end

local function alive(): boolean
	return #lasers > 0 and lasers[1].pivot:IsDescendantOf(Workspace)
end

local function step()
	if not alive() then
		return
	end

	-- Gốc nhân vật tra MỘT lần mỗi frame cho cả bảy controller bẫy, không phải mỗi
	-- controller một lần `FindFirstChild` — xem `ZoneLod.Root`.
	if not ZoneLod.Root() then
		return
	end
	local pos = ZoneLod.RootPosition()
	local now = ZoneLod.Now()
	-- Tra bảng một lần cho cả vòng lặp — bán kính chung cho mọi laser trong zone.
	local radiusSq = ZoneLod.RadiusSq(RENDER_RADIUS)

	for i = 1, #lasers do
		local laser = lasers[i]
		local dx, dz = pos.X - laser.cx, pos.Z - laser.cz
		local distSq = dx * dx + dz * dz
		if distSq <= radiusSq then
			-- Laser ở xa hạ nhịp riêng từng cái (mốc `nextFar` nằm trong bản ghi laser):
			-- người chơi thường đứng gần MỘT laser và xa hai cái kia.
			local shouldStep: boolean
			shouldStep, laser.nextFar = ZoneLod.ShouldStepFar(distSq, now, laser.nextFar)
			if shouldStep then
				local angle = math.rad(Zone2Lasers.AngleDeg(now, laser.rpm, laser.dir))
				laser.pivot.CFrame = laser.base * CFrame.Angles(0, angle, 0)
			end
			laser.awake = true
		elseif laser.awake then
			-- ngủ: đưa về góc gốc đúng một lần
			laser.pivot.CFrame = laser.base
			laser.awake = false
		end
	end
end

function Zone2LaserController.Init() end

function Zone2LaserController.Start()
	if connection then
		return
	end
	connection = RunService.RenderStepped:Connect(step)

	resolverThread = task.spawn(function()
		while true do
			-- Re-resolve khi mất tham chiếu HOẶC khi streaming vừa nạp thêm laser.
			if not alive() or #lasers ~= streamedCount() then
				resolve()
			end
			task.wait(RESOLVE_INTERVAL)
		end
	end)
end

function Zone2LaserController.Stop()
	-- Dừng cả vòng dò streaming; ngắt render thôi vẫn giữ controller sống ngầm.
	if resolverThread then
		if coroutine.status(resolverThread) == "suspended" then
			task.cancel(resolverThread)
		end
		resolverThread = nil
	end
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Zone2LaserController
