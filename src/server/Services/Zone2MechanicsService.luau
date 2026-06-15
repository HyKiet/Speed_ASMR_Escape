--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Zone2MechanicsService = {}

local ZONE_NAME = "Zone2"
local MECHANICS_NAME = "Mechanics"
local PIVOT_NAME = "Pivot"
local KILL_COOLDOWN_SECONDS = 0.85

type LaserDefaults = {
	rpm: number,
	dir: number,
	pivotZ: number,
}

type LaserConfig = {
	model: Model,
	pivot: BasePart,
	rpm: number,
	dir: number,
	pivotX: number,
	pivotY: number,
	pivotZ: number,
	angle: number,
}

local LASER_DEFAULTS: { [string]: LaserDefaults } = {
	LaserSweeper1 = { rpm = 18, dir = 1, pivotZ = 495 },
	LaserSweeper2 = { rpm = 22, dir = -1, pivotZ = 763 },
	Laser2_1 = { rpm = 28, dir = 1, pivotZ = 629 },
	Laser2_2 = { rpm = 32, dir = -1, pivotZ = 897 },
	Laser2_3 = { rpm = 38, dir = 1, pivotZ = 1031 },
}

local lasers: { LaserConfig } = {}
local configuredModels: { [Model]: boolean } = {}
local lastKillTimes: { [Player]: number } = {}

local function getNumberAttribute(instance: Instance?, attributeName: string, fallback: number): number
	if not instance then
		return fallback
	end

	local value = instance:GetAttribute(attributeName)
	if type(value) == "number" then
		return value
	end

	return fallback
end

local function getPlayerFromHit(hit: BasePart): (Player?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil
	end

	return Players:GetPlayerFromCharacter(character), humanoid
end

local function killPlayerFromHit(hit: BasePart)
	local player, humanoid = getPlayerFromHit(hit)
	if not player or not humanoid or humanoid.Health <= 0 then
		return
	end

	local now = os.clock()
	local lastKillTime = lastKillTimes[player] or 0
	if now - lastKillTime < KILL_COOLDOWN_SECONDS then
		return
	end

	lastKillTimes[player] = now
	humanoid.Health = 0
end

local function connectLaserBeam(beam: BasePart)
	beam.CanTouch = true
	beam.CanQuery = true
	beam.CanCollide = false
	beam.Touched:Connect(killPlayerFromHit)
end

local function isLaserBeam(part: BasePart, pivot: BasePart): boolean
	if part == pivot then
		return false
	end

	local lowerName = string.lower(part.Name)
	return string.find(lowerName, "beam", 1, true) ~= nil or string.find(lowerName, "laser", 1, true) ~= nil
end

local function configureLaserModel(model: Model)
	if configuredModels[model] then
		return
	end

	local pivot = model:FindFirstChild(PIVOT_NAME)
	if not pivot or not pivot:IsA("BasePart") then
		return
	end

	local defaults = LASER_DEFAULTS[model.Name]
	if not defaults then
		return
	end

	local legacyScript = model:FindFirstChildWhichIsA("Script")
	local rpm = getNumberAttribute(model, "RPM", defaults.rpm)
	local dir = getNumberAttribute(model, "Dir", defaults.dir)
	local pivotZ = getNumberAttribute(model, "PivotZ", defaults.pivotZ)

	rpm = getNumberAttribute(legacyScript, "RPM", rpm)
	dir = getNumberAttribute(legacyScript, "Dir", dir)
	pivotZ = getNumberAttribute(legacyScript, "PivotZ", pivotZ)

	if legacyScript then
		legacyScript.Disabled = true
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and isLaserBeam(descendant, pivot) then
			connectLaserBeam(descendant)
		end
	end

	configuredModels[model] = true
	model:SetAttribute("ManagedByZone2MechanicsService", true)
	table.insert(lasers, {
		model = model,
		pivot = pivot,
		rpm = rpm,
		dir = dir,
		pivotX = pivot.Position.X,
		pivotY = pivot.Position.Y,
		pivotZ = pivotZ,
		angle = 0,
	})
	script:SetAttribute("LaserCount", #lasers)
end

function Zone2MechanicsService.Init()
	script:SetAttribute("Started", false)
	script:SetAttribute("LaserCount", 0)
end

function Zone2MechanicsService.Start()
	local zone = Workspace:WaitForChild(ZONE_NAME, 30)
	if not zone then
		warn("[Zone2MechanicsService] Workspace.Zone2 not found")
		return
	end

	local mechanics = zone:WaitForChild(MECHANICS_NAME, 30)
	if not mechanics then
		warn("[Zone2MechanicsService] Workspace.Zone2.Mechanics not found")
		return
	end

	for _, child in mechanics:GetChildren() do
		if child:IsA("Model") then
			configureLaserModel(child)
		end
	end

	mechanics.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			task.defer(configureLaserModel, child)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastKillTimes[player] = nil
	end)

	script:SetAttribute("LaserCount", #lasers)
	script:SetAttribute("Started", true)

	RunService.Heartbeat:Connect(function(deltaTime: number)
		for _, laser in lasers do
			if laser.pivot.Parent then
				laser.angle += laser.dir * (laser.rpm / 60) * 360 * deltaTime
				laser.pivot.CFrame = CFrame.new(laser.pivotX, laser.pivotY, laser.pivotZ)
					* CFrame.Angles(0, math.rad(laser.angle), 0)
			end
		end
	end)
end

return Zone2MechanicsService
