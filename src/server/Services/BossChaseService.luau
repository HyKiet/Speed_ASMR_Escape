--!strict

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossChaseService = {}

local ZONE_NAME = "Zone4"
local MECHANICS_NAME = "Mechanics"
local ARENA_FLOOR_NAME = "BossArenaFloor"
local START_GATE_NAME = "Stage4Start"
local FINISH_GATE_NAME = "Stage4Finish"
local KILL_FLOOR_NAME = "KillFloor"
local LEGACY_CONTROLLER_NAME = "Zone4Controller"

local BOSS_NAME = "MonkeyBoss"
local RUN_ANIMATION_ID = "rbxassetid://125733527624272"

local STAGE_NUMBER = 4
local COMPLETE_STAGE = 5

local CHASE_SPEED = 56
local RETURN_SPEED = 72
local TOUCH_KILL_DISTANCE = 3.75
local KILL_COOLDOWN_SECONDS = 1.15
local BOSS_PIVOT_Y = 11.588234901428223
local VISUAL_REPAIR_INTERVAL = 1.25
local VISUAL_DRIFT_DISTANCE = 10
local ARENA_DETECTION_PADDING = 4
local DEBUG_ATTRIBUTE_INTERVAL = 0.5

local HOME_PIVOT = CFrame.new(-4.211, 11.588, 1568.629)

local ARENA_MIN_X = -139
local ARENA_MAX_X = 131
local ARENA_MIN_Z = 1391
local ARENA_MAX_Z = 1746

local zone: Folder?
local mechanics: Folder?
local startGate: BasePart?
local finishGate: BasePart?
local killFloor: BasePart?
local boss: Model?
local bossTemplate: Model?
local runTrack: AnimationTrack?
local runTrackBoss: Model?
local runAnimation = Instance.new("Animation")
local lastVisualRepairTime = 0
local lastDebugAttributeTime = 0
local heartbeatTicks = 0
local lastKillTimes: { [Player]: number } = {}
local activeEncounterPlayers: { [Player]: boolean } = {}
local cachedArenaMinX = ARENA_MIN_X
local cachedArenaMaxX = ARENA_MAX_X
local cachedArenaMinZ = ARENA_MIN_Z
local cachedArenaMaxZ = ARENA_MAX_Z

runAnimation.Name = "MonkeyBossRun"
runAnimation.AnimationId = RUN_ANIMATION_ID

local function getCharacterFromHit(hit: BasePart): Model?
	local candidate = hit:FindFirstAncestorOfClass("Model")
	if candidate and candidate:FindFirstChildOfClass("Humanoid") then
		return candidate
	end

	return nil
end

local function getPlayerFromHit(hit: BasePart): Player?
	local character = getCharacterFromHit(hit)
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function findMechanicsAncestor(instance: Instance): Folder?
	local current = instance.Parent
	while current do
		if current.Name == MECHANICS_NAME and current:IsA("Folder") then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function resolveBossZoneAndMechanics(): (Folder?, Folder?)
	local preferredZone = Workspace:FindFirstChild(ZONE_NAME)
	if preferredZone and preferredZone:IsA("Folder") then
		local preferredMechanics = preferredZone:FindFirstChild(MECHANICS_NAME)
		if preferredMechanics and preferredMechanics:IsA("Folder") then
			local preferredStartGate = preferredMechanics:FindFirstChild(START_GATE_NAME)
			local preferredFinishGate = preferredMechanics:FindFirstChild(FINISH_GATE_NAME)
			if preferredStartGate and preferredFinishGate then
				return preferredZone, preferredMechanics
			end
		end
	end

	local startGateInstance = Workspace:FindFirstChild(START_GATE_NAME, true)
	if startGateInstance then
		local foundMechanics = findMechanicsAncestor(startGateInstance)
		local foundZone = foundMechanics and foundMechanics.Parent
		if foundMechanics and foundZone and foundZone:IsA("Folder") then
			return foundZone, foundMechanics
		end
	end

	if preferredZone and preferredZone:IsA("Folder") then
		local preferredMechanics = preferredZone:FindFirstChild(MECHANICS_NAME)
		if preferredMechanics and preferredMechanics:IsA("Folder") then
			return preferredZone, preferredMechanics
		end
	end

	return nil, nil
end

local function refreshArenaBounds()
	local arenaFloor = if zone then zone:FindFirstChild(ARENA_FLOOR_NAME, true) else nil
	if arenaFloor and arenaFloor:IsA("BasePart") then
		local halfSizeX = arenaFloor.Size.X * 0.5
		local halfSizeZ = arenaFloor.Size.Z * 0.5
		cachedArenaMinX = arenaFloor.Position.X - halfSizeX
		cachedArenaMaxX = arenaFloor.Position.X + halfSizeX
		cachedArenaMinZ = arenaFloor.Position.Z - halfSizeZ
		cachedArenaMaxZ = arenaFloor.Position.Z + halfSizeZ
	end
end

local function getStageZBounds(): (number, number)
	return cachedArenaMinZ, cachedArenaMaxZ
end

local function getArenaXBounds(): (number, number)
	return cachedArenaMinX, cachedArenaMaxX
end

local function isPositionInsideArena(position: Vector3, padding: number?): boolean
	local arenaPadding = padding or ARENA_DETECTION_PADDING
	local minX, maxX = getArenaXBounds()
	local minZ, maxZ = getStageZBounds()

	return position.X >= minX - arenaPadding
		and position.X <= maxX + arenaPadding
		and position.Z >= minZ - arenaPadding
		and position.Z <= maxZ + arenaPadding
end

local function shouldChasePlayer(player: Player, position: Vector3): boolean
	local currentStage = player:GetAttribute("CurrentStage")
	if currentStage == STAGE_NUMBER then
		return activeEncounterPlayers[player] == true and isPositionInsideArena(position)
	end

	if type(currentStage) == "number" and currentStage >= COMPLETE_STAGE then
		-- Completed players can re-enter Stage 4 from Stage 5 and retrigger the chase.
		return isPositionInsideArena(position, 0)
	end

	return false
end

local function killCharacter(player: Player, character: Model)
	local now = os.clock()
	local lastKillTime = lastKillTimes[player] or 0
	if now - lastKillTime < KILL_COOLDOWN_SECONDS then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		lastKillTimes[player] = now
		humanoid.Health = 0
	end
end

local function configureBoss(model: Model)
	model.Name = BOSS_NAME
	model:SetAttribute("EncounterState", "Idle")

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
	end

	if humanoid then
		humanoid.AutoRotate = false
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.WalkSpeed = 0

		if not humanoid:FindFirstChildOfClass("Animator") then
			local animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.Anchored = descendant.Name == "HumanoidRootPart" or descendant.Name == "RootPart"

			if not descendant.Anchored then
				pcall(function()
					descendant:SetNetworkOwner(nil)
				end)
			end
		end
	end
end

local function stopRunAnimation()
	if runTrack then
		runTrack:Stop(0.18)
		runTrack = nil
		runTrackBoss = nil
	end
end

local function loadRunTrack(model: Model): AnimationTrack?
	if runTrack and runTrackBoss == model then
		return runTrack
	end

	stopRunAnimation()

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local track = animator:LoadAnimation(runAnimation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	runTrack = track
	runTrackBoss = model

	return track
end

local function warmRunAnimation(model: Model)
	local track = loadRunTrack(model)
	if not track then
		return
	end

	track:Play(0)
	track:AdjustSpeed(0)
	track:Stop(0)
	track:AdjustSpeed(1)
end

local function playRunAnimation(model: Model)
	local track = loadRunTrack(model)
	if not track then
		return
	end

	if not track.IsPlaying then
		track:Play(0.08)
	end
end

local function findBossModel(): Model?
	local currentZone = zone
	if not currentZone then
		return nil
	end

	local currentMechanics = mechanics
	if currentMechanics then
		local existingInMechanics = currentMechanics:FindFirstChild(BOSS_NAME, true)
		if existingInMechanics and existingInMechanics:IsA("Model") then
			return existingInMechanics
		end
	end

	local existingInZone = currentZone:FindFirstChild(BOSS_NAME)
	if existingInZone and existingInZone:IsA("Model") then
		return existingInZone
	end

	local existingInWorkspace = Workspace:FindFirstChild(BOSS_NAME, true)
	if existingInWorkspace and existingInWorkspace:IsA("Model") then
		existingInWorkspace.Parent = currentMechanics or currentZone
		return existingInWorkspace
	end

	if bossTemplate then
		local clone = bossTemplate:Clone()
		clone.Parent = currentMechanics or currentZone
		return clone
	end

	return nil
end

local function ensureBoss(): Model?
	local model = boss
	if model and model.Parent and model:FindFirstChild("HumanoidRootPart") then
		return model
	end

	stopRunAnimation()

	model = findBossModel()
	if not model then
		return nil
	end

	configureBoss(model)
	boss = model

	if not bossTemplate then
		bossTemplate = model:Clone()
		bossTemplate.Parent = nil
	end

	model:PivotTo(HOME_PIVOT)
	warmRunAnimation(model)
	return model
end

local function findNearestRunner(model: Model): BasePart?
	local bossPosition = model:GetPivot().Position
	local closestRoot: BasePart? = nil
	local closestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil

		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local position = root.Position
			if shouldChasePlayer(player, position) then
				local distance = (position - bossPosition).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestRoot = root
				end
			end
		end
	end

	return closestRoot
end

local function getPlayerFromCharacter(character: Model?): Player?
	if not character then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getFlatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function repairBossVisualIfNeeded(model: Model)
	local now = os.clock()
	if now - lastVisualRepairTime < VISUAL_REPAIR_INTERVAL then
		return
	end
	lastVisualRepairTime = now

	local pivot = model:GetPivot()
	local boundingBox = model:GetBoundingBox()
	if (boundingBox.Position - pivot.Position).Magnitude <= VISUAL_DRIFT_DISTANCE then
		return
	end

	local wasRunning = runTrack and runTrack.IsPlaying
	configureBoss(model)
	model:PivotTo(pivot)

	if wasRunning then
		playRunAnimation(model)
	end
end

local function advanceToward(current: CFrame, targetPosition: Vector3, speed: number, deltaTime: number): CFrame
	local currentPosition = current.Position
	local flatTarget = Vector3.new(targetPosition.X, HOME_PIVOT.Position.Y, targetPosition.Z)
	local offset = flatTarget - currentPosition
	local minStageX, maxStageX = getArenaXBounds()
	local minStageZ, maxStageZ = getStageZBounds()
	if offset.Magnitude < 0.05 then
		return current
	end

	local stepDistance = speed * deltaTime
	local nextPosition = if offset.Magnitude <= stepDistance
		then flatTarget
		else currentPosition + offset.Unit * stepDistance

	nextPosition = Vector3.new(
		math.clamp(nextPosition.X, minStageX, maxStageX),
		HOME_PIVOT.Position.Y,
		math.clamp(nextPosition.Z, minStageZ, maxStageZ)
	)

	local lookTarget = Vector3.new(flatTarget.X, nextPosition.Y, flatTarget.Z)
	local lookOffset = lookTarget - nextPosition
	if lookOffset.Magnitude > 0.05 then
		return CFrame.lookAt(nextPosition, lookTarget)
	end

	return CFrame.new(nextPosition) * (current - currentPosition)
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		activeEncounterPlayers[player] = nil
	end)
end

local function connectStageGates()
	local currentStartGate = startGate
	local currentFinishGate = finishGate
	local currentKillFloor = killFloor
	if not currentStartGate or not currentFinishGate then
		return
	end

	currentStartGate.Touched:Connect(function(hit: BasePart)
		local player = getPlayerFromHit(hit)
		if not player then
			return
		end

		local currentStage = player:GetAttribute("CurrentStage")
		if type(currentStage) ~= "number" or currentStage < STAGE_NUMBER then
			player:SetAttribute("CurrentStage", STAGE_NUMBER)
		end
		activeEncounterPlayers[player] = true
	end)

	currentFinishGate.Touched:Connect(function(hit: BasePart)
		local player = getPlayerFromHit(hit)
		if player then
			activeEncounterPlayers[player] = nil
			if player:GetAttribute("CurrentStage") == STAGE_NUMBER then
				player:SetAttribute("CurrentStage", COMPLETE_STAGE)
			end
		end
	end)

	if currentKillFloor then
		currentKillFloor.Touched:Connect(function(hit: BasePart)
			local character = getCharacterFromHit(hit)
			local player = getPlayerFromCharacter(character)
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if player and character and root and root:IsA("BasePart") and shouldChasePlayer(player, root.Position) then
				killCharacter(player, character)
			end
		end)
	end
end

function BossChaseService.Init()
	runAnimation.Parent = script
	script:SetAttribute("Initialized", false)
	script:SetAttribute("Started", false)
	script:SetAttribute("StartBlocked", "")

	local foundZone, foundMechanics = resolveBossZoneAndMechanics()
	if not foundZone then
		script:SetAttribute("StartBlocked", "Boss zone with Stage4Start not found")
		warn("[BossChaseService] Boss zone with Stage4Start not found")
		return
	end

	zone = foundZone
	script:SetAttribute("ZonePath", foundZone:GetFullName())
	refreshArenaBounds()

	local legacyController = foundZone:FindFirstChild(LEGACY_CONTROLLER_NAME)
	if legacyController and legacyController:IsA("BaseScript") then
		legacyController.Disabled = true
	end

	if not foundMechanics then
		script:SetAttribute("StartBlocked", "Mechanics folder with Stage4Start not found")
		warn("[BossChaseService] Mechanics folder with Stage4Start not found")
		return
	end

	mechanics = foundMechanics
	script:SetAttribute("MechanicsPath", foundMechanics:GetFullName())

	local foundStartGate = foundMechanics:FindFirstChild(START_GATE_NAME)
	local foundFinishGate = foundMechanics:FindFirstChild(FINISH_GATE_NAME)
	local foundKillFloor = foundMechanics:FindFirstChild(KILL_FLOOR_NAME)

	if foundStartGate and foundStartGate:IsA("BasePart") then
		startGate = foundStartGate
	end
	if foundFinishGate and foundFinishGate:IsA("BasePart") then
		finishGate = foundFinishGate
	end
	if foundKillFloor and foundKillFloor:IsA("BasePart") then
		killFloor = foundKillFloor
	end

	connectStageGates()
	script:SetAttribute("Initialized", true)
end

function BossChaseService.Start()
	if not zone or not mechanics or not startGate or not finishGate then
		script:SetAttribute("StartBlocked", "Missing zone, mechanics, startGate, or finishGate")
		return
	end

	local model = ensureBoss()
	if not model then
		script:SetAttribute("StartBlocked", "MonkeyBoss model not found")
		warn("[BossChaseService] MonkeyBoss model not found")
		return
	end

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ runAnimation })
		end)
		warmRunAnimation(model)
	end)

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		activeEncounterPlayers[player] = nil
		lastKillTimes[player] = nil
	end)

	script:SetAttribute("Started", true)
	script:SetAttribute("HeartbeatTicks", 0)
	RunService.Heartbeat:Connect(function(deltaTime: number)
		heartbeatTicks += 1
		local activeBoss = ensureBoss()
		if not activeBoss then
			script:SetAttribute("LastRunner", "NoBoss")
			return
		end
		repairBossVisualIfNeeded(activeBoss)

		local runnerRoot = findNearestRunner(activeBoss)
		if runnerRoot then
			local now = os.clock()
			if now - lastDebugAttributeTime >= DEBUG_ATTRIBUTE_INTERVAL then
				lastDebugAttributeTime = now
				script:SetAttribute("HeartbeatTicks", heartbeatTicks)
				script:SetAttribute("LastRunner", runnerRoot:GetFullName())
			end
			activeBoss:SetAttribute("EncounterState", "Chasing")
			playRunAnimation(activeBoss)
			activeBoss:PivotTo(advanceToward(activeBoss:GetPivot(), runnerRoot.Position, CHASE_SPEED, deltaTime))

			if getFlatDistance(runnerRoot.Position, activeBoss:GetPivot().Position) <= TOUCH_KILL_DISTANCE then
				local character = runnerRoot.Parent
				local player = getPlayerFromCharacter(if character and character:IsA("Model") then character else nil)
				if player and character and character:IsA("Model") then
					killCharacter(player, character)
				end
			end
		else
			local now = os.clock()
			if now - lastDebugAttributeTime >= DEBUG_ATTRIBUTE_INTERVAL then
				lastDebugAttributeTime = now
				script:SetAttribute("HeartbeatTicks", heartbeatTicks)
				script:SetAttribute("LastRunner", "")
			end
			local current = activeBoss:GetPivot()
			local distanceHome = (HOME_PIVOT.Position - current.Position).Magnitude
			if distanceHome > 0.05 then
				activeBoss:SetAttribute("EncounterState", "Returning")
				playRunAnimation(activeBoss)
				activeBoss:PivotTo(advanceToward(current, HOME_PIVOT.Position, RETURN_SPEED, deltaTime))
			else
				activeBoss:SetAttribute("EncounterState", "Idle")
				activeBoss:PivotTo(HOME_PIVOT)
				stopRunAnimation()
			end
		end
	end)
end

return BossChaseService
