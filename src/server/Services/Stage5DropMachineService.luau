--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Stage5DropMachineService = {}

local ZONE_NAME = "Zone5"
local MECHANICS_NAME = "Mechanics"
local DROP_MACHINE_NAME = "DropMachine"
local SPAWNER_NAME = "SpawnerCenter"
local STAGE_START_NAME = "Stage5Start"
local LEGACY_SPAWN_SCRIPT_NAME = "SpawnLogic"
local LEGACY_ZONE_CONTROLLER_NAME = "Zone5Controller"
local OBSTACLE_NAME = "DropMachineObstacle"
local STAGE_NUMBER = 5

local SPAWN_INTERVAL_SECONDS = 1.35
local OBSTACLE_SIZE = Vector3.new(10, 10, 10)
local OBSTACLE_SPEED = 42
local OBSTACLE_LIFETIME_SECONDS = 30
local CLEANUP_CHECK_INTERVAL_SECONDS = 0.25
local KILL_COOLDOWN_SECONDS = 0.65
local FALL_CLEANUP_OFFSET_Y = 16
local STAGE_START_CLEANUP_PADDING = 1
local FALL_RESET_Y = 5
local VOID_CHECK_INTERVAL_SECONDS = 0.1
local STAGE5_FALLBACK_MIN_Z = 1746
local STAGE5_FALLBACK_MAX_Z = 2395
local START_TRANSITION_ZONE_NAME = "Zone4"
local START_TRANSITION_NAME = "Transition4To5"
local FINISH_TRANSITION_ZONE_NAME = "Zone5"
local FINISH_TRANSITION_NAME = "Transition5To6"

local random = Random.new()
local mechanics: Folder?
local spawner: BasePart?
local stageStart: BasePart?
local activeObstacles: { BasePart } = {}
local lastKillTimes: { [Player]: number } = {}
local obstacleTouchConnections: { [BasePart]: RBXScriptConnection } = {}

local BODY_PART_NAMES = {
	HumanoidRootPart = true,
	Head = true,
	Torso = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftArm = true,
	RightArm = true,
	LeftLeg = true,
	RightLeg = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local SHAPES = {
	{ shape = Enum.PartType.Ball, color = Color3.fromRGB(255, 34, 34) },
	{ shape = Enum.PartType.Block, color = Color3.fromRGB(34, 102, 255) },
	{ shape = Enum.PartType.Cylinder, color = Color3.fromRGB(31, 255, 95) },
}

local function isCharacterBodyPart(part: BasePart): (Player?, Humanoid?)
	if not BODY_PART_NAMES[part.Name] then
		return nil, nil
	end

	local character = part.Parent
	if not character or not character:IsA("Model") then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil, nil
	end

	return player, humanoid
end

local function killPlayer(player: Player, humanoid: Humanoid)
	local now = os.clock()
	if now - (lastKillTimes[player] or 0) < KILL_COOLDOWN_SECONDS then
		return
	end

	lastKillTimes[player] = now
	humanoid.Health = 0
end

local function getTransitionPart(zoneName: string, transitionName: string): BasePart?
	local transitionZone = Workspace:FindFirstChild(zoneName)
	local ground = transitionZone and transitionZone:FindFirstChild("Ground")
	local transition = ground and ground:FindFirstChild(transitionName)
	if transition and transition:IsA("BasePart") then
		return transition
	end

	return nil
end

local function getStage5ZBounds(): (number, number)
	local startTransition = getTransitionPart(START_TRANSITION_ZONE_NAME, START_TRANSITION_NAME)
	local finishTransition = getTransitionPart(FINISH_TRANSITION_ZONE_NAME, FINISH_TRANSITION_NAME)
	if startTransition and finishTransition then
		return math.min(startTransition.Position.Z, finishTransition.Position.Z),
			math.max(startTransition.Position.Z, finishTransition.Position.Z)
	end

	return STAGE5_FALLBACK_MIN_Z, STAGE5_FALLBACK_MAX_Z
end

local function shouldWatchStage5Void(player: Player): boolean
	local activeStage = player:GetAttribute("ActiveStage")
	if activeStage == STAGE_NUMBER then
		return true
	end

	return player:GetAttribute("CurrentStage") == STAGE_NUMBER
end

local function processStage5VoidFalls()
	local minStageZ, maxStageZ = getStage5ZBounds()
	for _, player in Players:GetPlayers() do
		if shouldWatchStage5Void(player) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
				local position = root.Position
				if position.Y < FALL_RESET_Y and position.Z >= minStageZ and position.Z <= maxStageZ then
					killPlayer(player, humanoid)
				end
			end
		end
	end
end

local function getCharactersForOverlap(): { Instance }
	local characters = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 then
			table.insert(characters, character)
		end
	end

	return characters
end

local function disableLegacyDropMachineScript(dropMachine: Model)
	local foundSpawner = dropMachine:FindFirstChild(SPAWNER_NAME)
	local legacyScript = foundSpawner and foundSpawner:FindFirstChild(LEGACY_SPAWN_SCRIPT_NAME)
	if legacyScript and legacyScript:IsA("BaseScript") then
		legacyScript.Disabled = true
	end
end

local function disableLegacyZoneController(zone: Instance)
	local legacyScript = zone:FindFirstChild(LEGACY_ZONE_CONTROLLER_NAME)
	if legacyScript and legacyScript:IsA("BaseScript") then
		legacyScript.Disabled = true
		legacyScript.Name = "Zone5Controller_DISABLED_OLD"
	end
end

local function unregisterObstacle(obstacle: BasePart)
	local connection = obstacleTouchConnections[obstacle]
	if connection then
		connection:Disconnect()
		obstacleTouchConnections[obstacle] = nil
	end
end

local function destroyObstacle(obstacle: BasePart)
	unregisterObstacle(obstacle)
	if obstacle.Parent then
		obstacle:Destroy()
	end
end

local function connectObstacleTouch(obstacle: BasePart)
	obstacleTouchConnections[obstacle] = obstacle.Touched:Connect(function(hit: BasePart)
		if not hit:IsA("BasePart") then
			return
		end

		local player, humanoid = isCharacterBodyPart(hit)
		if player and humanoid then
			killPlayer(player, humanoid)
		end
	end)
end

local function hasObstacleReachedStageStart(obstacle: BasePart): boolean
	local currentStageStart = stageStart
	local currentSpawner = spawner
	if not currentStageStart or not currentSpawner then
		return false
	end

	local travelVector = currentStageStart.Position - currentSpawner.Position
	if travelVector.Magnitude < 0.01 then
		local halfExtent = math.max(obstacle.Size.X, obstacle.Size.Y, obstacle.Size.Z) * 0.5
		return obstacle.Position.Z - halfExtent <= currentStageStart.Position.Z + STAGE_START_CLEANUP_PADDING
	end

	local travelDirection = travelVector.Unit
	local halfExtent = math.max(obstacle.Size.X, obstacle.Size.Y, obstacle.Size.Z) * 0.5
	local distanceFromStart = (obstacle.Position - currentStageStart.Position):Dot(travelDirection)
	return distanceFromStart >= -halfExtent - STAGE_START_CLEANUP_PADDING
end

local function removeExistingObstacles(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("BasePart") and (child.Name == OBSTACLE_NAME or child.Name == "NeonObstacle") then
			child:Destroy()
		end
	end
end

local function spawnObstacle()
	local currentSpawner = spawner
	local currentMechanics = mechanics
	if not currentSpawner or not currentMechanics then
		return
	end

	local shapeInfo = SHAPES[random:NextInteger(1, #SHAPES)]
	local part = Instance.new("Part")
	part.Name = OBSTACLE_NAME
	part.Shape = shapeInfo.shape
	part.Size = OBSTACLE_SIZE
	part.Color = shapeInfo.color
	part.Material = Enum.Material.Neon
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.Anchored = false
	part.CustomPhysicalProperties = PhysicalProperties.new(10, 0, 0, 1, 1)
	part:SetAttribute("ManagedByStage5DropMachineService", true)

	local randomX = random:NextNumber(-30, 30)
	local spawnCFrame = currentSpawner.CFrame * CFrame.new(randomX, 0, 0)
	if shapeInfo.shape == Enum.PartType.Cylinder then
		spawnCFrame *= CFrame.Angles(0, 0, math.pi / 2)
	end
	part.CFrame = spawnCFrame
	part.AssemblyLinearVelocity = currentSpawner.CFrame.LookVector * OBSTACLE_SPEED
	part.Parent = currentMechanics
	connectObstacleTouch(part)

	table.insert(activeObstacles, part)

	task.delay(OBSTACLE_LIFETIME_SECONDS, function()
		destroyObstacle(part)
	end)
end

local function cleanupObstacles()
	local currentStageStart = stageStart
	for index = #activeObstacles, 1, -1 do
		local obstacle = activeObstacles[index]
		if not obstacle.Parent then
			unregisterObstacle(obstacle)
			table.remove(activeObstacles, index)
		elseif currentStageStart then
			local passedStart = hasObstacleReachedStageStart(obstacle)
			local fellBelowStage = obstacle.Position.Y < currentStageStart.Position.Y - FALL_CLEANUP_OFFSET_Y
			if passedStart or fellBelowStage then
				destroyObstacle(obstacle)
				table.remove(activeObstacles, index)
			end
		end
	end
end

local function processObstacleHits()
	if #activeObstacles == 0 then
		return
	end

	local characters = getCharactersForOverlap()
	if #characters == 0 then
		return
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = characters
	params.RespectCanCollide = false

	for _, obstacle in activeObstacles do
		if obstacle.Parent then
			for _, overlap in Workspace:GetPartsInPart(obstacle, params) do
				local player, humanoid = isCharacterBodyPart(overlap)
				if player and humanoid then
					killPlayer(player, humanoid)
				end
			end
		end
	end
end

function Stage5DropMachineService.Init()
	script:SetAttribute("Started", false)
	script:SetAttribute("ActiveObstacleCount", 0)
end

function Stage5DropMachineService.Start()
	local zone = Workspace:WaitForChild(ZONE_NAME, 30)
	if not zone then
		warn("[Stage5DropMachineService] Workspace.Zone5 not found")
		return
	end
	disableLegacyZoneController(zone)

	local foundMechanics = zone:WaitForChild(MECHANICS_NAME, 30)
	if not foundMechanics or not foundMechanics:IsA("Folder") then
		warn("[Stage5DropMachineService] Workspace.Zone5.Mechanics not found")
		return
	end
	mechanics = foundMechanics

	local dropMachine = foundMechanics:WaitForChild(DROP_MACHINE_NAME, 30)
	if not dropMachine or not dropMachine:IsA("Model") then
		warn("[Stage5DropMachineService] DropMachine model not found")
		return
	end
	disableLegacyDropMachineScript(dropMachine)
	removeExistingObstacles(foundMechanics)

	local foundSpawner = dropMachine:FindFirstChild(SPAWNER_NAME)
	if not foundSpawner or not foundSpawner:IsA("BasePart") then
		warn("[Stage5DropMachineService] DropMachine.SpawnerCenter not found")
		return
	end
	spawner = foundSpawner

	local foundStageStart = foundMechanics:FindFirstChild(STAGE_START_NAME)
	if foundStageStart and foundStageStart:IsA("BasePart") then
		stageStart = foundStageStart
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		lastKillTimes[player] = nil
	end)

	task.spawn(function()
		while script.Parent do
			spawnObstacle()
			task.wait(SPAWN_INTERVAL_SECONDS)
		end
	end)

	task.spawn(function()
		while script.Parent do
			cleanupObstacles()
			script:SetAttribute("ActiveObstacleCount", #activeObstacles)
			task.wait(CLEANUP_CHECK_INTERVAL_SECONDS)
		end
	end)

	task.spawn(function()
		while script.Parent do
			processStage5VoidFalls()
			task.wait(VOID_CHECK_INTERVAL_SECONDS)
		end
	end)

	RunService.Heartbeat:Connect(processObstacleHits)

	script:SetAttribute("Started", true)
end

return Stage5DropMachineService
