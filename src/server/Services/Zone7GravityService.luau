--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Zone7GravityService = {}

local ZONE_NAME = "Zone7"
local GROUND_NAME = "Ground"
local MECHANICS_NAME = "Mechanics"
local STAGE_START_NAME = "Stage7Start"
local STAGE_FINISH_NAME = "Stage7Finish"
local GRAVITY_ZONES_NAME = "GravityZones"
local KILL_FLOOR_NAME = "KillFloor"
local LEGACY_ZONE_CONTROLLER_NAME = "Zone7Controller"
local LEGACY_KILL_LOGIC_NAME = "KillLogic"

local STAGE_NUMBER = 7
local GRAVITY_ATTRIBUTE = "Zone7GravityEnabled"
local MIN_LEVEL_TO_RUN = 61
local MIN_WALK_SPEED_TO_RUN = 126
local TOUCH_COOLDOWN_SECONDS = 0.6
local COLLAPSE_SPEED_STUDS_PER_SECOND = 126
local PLATFORM_LENGTH_STUDS = 10
local COLLAPSE_START_DELAY_SECONDS = 0.8
local COLLAPSE_RESET_DELAY_SECONDS = 4
local COLLAPSE_TWEEN_SECONDS = 0.3
local COLLAPSE_DROP_STUDS = 40

type PartState = {
	CFrame: CFrame,
	Size: Vector3,
	CanCollide: boolean,
	CanTouch: boolean,
	Transparency: number,
	Color: Color3,
}

type PlatformEntry = {
	index: number,
	instance: Instance,
	parts: { BasePart },
	states: { [BasePart]: PartState },
}

local ground: Folder?
local mechanics: Folder?
local stageStart: BasePart?
local stageFinish: BasePart?
local gravityZones: Folder?
local killFloor: BasePart?
local platforms: { PlatformEntry } = {}
local activeGravityPlayers: { [Player]: boolean } = {}
local touchCooldowns: { [Player]: number } = {}
local isCollapsing = false
local collapseGeneration = 0

local function getPlayerFromHit(hit: BasePart): (Player?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
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

local function shouldAcceptTouch(player: Player): boolean
	local now = os.clock()
	if now - (touchCooldowns[player] or 0) < TOUCH_COOLDOWN_SECONDS then
		return false
	end

	touchCooldowns[player] = now
	return true
end

local function getActivePlayerCount(): number
	local count = 0
	for _ in activeGravityPlayers do
		count += 1
	end

	return count
end

local function setGravityActive(player: Player, isActive: boolean)
	if isActive then
		activeGravityPlayers[player] = true
		player:SetAttribute("ActiveStage", STAGE_NUMBER)
		player:SetAttribute("CurrentStage", STAGE_NUMBER)
	else
		activeGravityPlayers[player] = nil
	end

	player:SetAttribute(GRAVITY_ATTRIBUTE, isActive)
	script:SetAttribute("ActivePlayerCount", getActivePlayerCount())
end

local function deactivatePlayer(player: Player)
	if activeGravityPlayers[player] then
		setGravityActive(player, false)
	else
		player:SetAttribute(GRAVITY_ATTRIBUTE, false)
	end
end

local function syncGravityWithStage(player: Player)
	local activeStage = player:GetAttribute("ActiveStage")
	local currentStage = player:GetAttribute("CurrentStage")
	if activeGravityPlayers[player] and activeStage ~= STAGE_NUMBER and currentStage ~= STAGE_NUMBER then
		deactivatePlayer(player)
	end
end

local function disableLegacyScript(parent: Instance?, scriptName: string, disabledName: string)
	local legacyScript = parent and parent:FindFirstChild(scriptName)
	if legacyScript and legacyScript:IsA("BaseScript") then
		legacyScript.Disabled = true
		legacyScript.Name = disabledName
	end
end

local function getLevel(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue and levelValue:IsA("IntValue") then
		return levelValue.Value
	end
	if levelValue and levelValue:IsA("NumberValue") then
		return levelValue.Value
	end

	return 1
end

local function isPlayerQualified(player: Player, humanoid: Humanoid): boolean
	return getLevel(player) >= MIN_LEVEL_TO_RUN and humanoid.WalkSpeed >= MIN_WALK_SPEED_TO_RUN
end

local function capturePartState(part: BasePart): PartState
	return {
		CFrame = part.CFrame,
		Size = part.Size,
		CanCollide = part.CanCollide,
		CanTouch = part.CanTouch,
		Transparency = part.Transparency,
		Color = part.Color,
	}
end

local function collectPlatformParts(instance: Instance): { BasePart }
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
		return parts
	end

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function collectPlatforms(foundGround: Folder): { PlatformEntry }
	local collected = {}

	for _, child in foundGround:GetChildren() do
		local platformIndex = tonumber(child.Name:match("^Platform_(%d+)$"))
		if platformIndex then
			local parts = collectPlatformParts(child)
			local states = {}
			for _, part in parts do
				states[part] = capturePartState(part)
			end

			table.insert(collected, {
				index = platformIndex,
				instance = child,
				parts = parts,
				states = states,
			})
		end
	end

	table.sort(collected, function(left: PlatformEntry, right: PlatformEntry)
		return left.index < right.index
	end)

	return collected
end

local function restorePlatform(entry: PlatformEntry)
	for _, part in entry.parts do
		local state = entry.states[part]
		if state and part.Parent then
			part.CFrame = state.CFrame
			part.Size = state.Size
			part.CanCollide = state.CanCollide
			part.CanTouch = state.CanTouch
			part.Transparency = state.Transparency
			part.Color = state.Color
		end
	end
end

local function resetTrack()
	collapseGeneration += 1
	for _, entry in platforms do
		restorePlatform(entry)
	end

	isCollapsing = false
	script:SetAttribute("Collapsing", false)
end

local function collapsePlatform(entry: PlatformEntry)
	for _, part in entry.parts do
		if part.Parent and part.CanCollide then
			part.CanCollide = false
			part.CanTouch = false
			local tween = TweenService:Create(part, TweenInfo.new(COLLAPSE_TWEEN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = part.CFrame - Vector3.new(0, COLLAPSE_DROP_STUDS, 0),
				Transparency = 1,
			})
			tween:Play()
		end
	end
end

local function startCollapse()
	if isCollapsing then
		return
	end

	isCollapsing = true
	collapseGeneration += 1
	local generation = collapseGeneration
	script:SetAttribute("Collapsing", true)

	task.spawn(function()
		task.wait(COLLAPSE_START_DELAY_SECONDS)
		local interval = PLATFORM_LENGTH_STUDS / COLLAPSE_SPEED_STUDS_PER_SECOND

		for _, entry in platforms do
			if not isCollapsing or generation ~= collapseGeneration then
				return
			end

			collapsePlatform(entry)
			task.wait(interval)
		end

		task.wait(COLLAPSE_RESET_DELAY_SECONDS)
		if generation == collapseGeneration then
			resetTrack()
		end
	end)
end

local function onStageStartTouched(hit: BasePart)
	local player, humanoid = getPlayerFromHit(hit)
	if not player or not humanoid or not shouldAcceptTouch(player) then
		return
	end

	setGravityActive(player, true)
end

local function onStageFinishTouched(hit: BasePart)
	local player = getPlayerFromHit(hit)
	if player then
		deactivatePlayer(player)
	end
end

local function onKillFloorTouched(hit: BasePart)
	local player, humanoid = getPlayerFromHit(hit)
	if player and humanoid then
		humanoid.Health = 0
	end
end

local function onPlatformTouched(entry: PlatformEntry, hit: BasePart)
	local player, humanoid = getPlayerFromHit(hit)
	if not player or not humanoid or not shouldAcceptTouch(player) then
		return
	end

	setGravityActive(player, true)
	if not isPlayerQualified(player, humanoid) then
		collapsePlatform(entry)
		return
	end

	startCollapse()
end

local function connectGravityZone(zonePart: BasePart)
	zonePart.Touched:Connect(function(hit: BasePart)
		local player = getPlayerFromHit(hit)
		if player then
			setGravityActive(player, true)
		end
	end)
end

local function watchCharacter(player: Player, character: Model)
	deactivatePlayer(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 8)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			deactivatePlayer(player)
		end)
	end
end

local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player, player.Character)
	end

	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)

	player:GetAttributeChangedSignal("ActiveStage"):Connect(function()
		syncGravityWithStage(player)
	end)

	player:GetAttributeChangedSignal("CurrentStage"):Connect(function()
		syncGravityWithStage(player)
	end)
end

function Zone7GravityService.Init()
	script:SetAttribute("Started", false)
	script:SetAttribute("Collapsing", false)
	script:SetAttribute("PlatformCount", 0)
	script:SetAttribute("ActivePlayerCount", 0)
end

function Zone7GravityService.Start()
	local zone = Workspace:WaitForChild(ZONE_NAME, 30)
	if not zone then
		warn("[Zone7GravityService] Workspace.Zone7 not found")
		return
	end

	disableLegacyScript(zone, LEGACY_ZONE_CONTROLLER_NAME, "Zone7Controller_DISABLED_OLD")

	local foundGround = zone:WaitForChild(GROUND_NAME, 30)
	if not foundGround or not foundGround:IsA("Folder") then
		warn("[Zone7GravityService] Workspace.Zone7.Ground not found")
		return
	end
	ground = foundGround

	local foundMechanics = zone:WaitForChild(MECHANICS_NAME, 30)
	if not foundMechanics or not foundMechanics:IsA("Folder") then
		warn("[Zone7GravityService] Workspace.Zone7.Mechanics not found")
		return
	end
	mechanics = foundMechanics

	local foundStageStart = foundMechanics:WaitForChild(STAGE_START_NAME, 30)
	local foundStageFinish = foundMechanics:WaitForChild(STAGE_FINISH_NAME, 30)
	if not foundStageStart or not foundStageStart:IsA("BasePart") then
		warn("[Zone7GravityService] Stage7Start not found")
		return
	end
	if not foundStageFinish or not foundStageFinish:IsA("BasePart") then
		warn("[Zone7GravityService] Stage7Finish not found")
		return
	end

	stageStart = foundStageStart
	stageFinish = foundStageFinish
	stageStart.Touched:Connect(onStageStartTouched)
	stageFinish.Touched:Connect(onStageFinishTouched)

	local foundGravityZones = foundMechanics:FindFirstChild(GRAVITY_ZONES_NAME)
	if foundGravityZones and foundGravityZones:IsA("Folder") then
		gravityZones = foundGravityZones
		for _, child in foundGravityZones:GetChildren() do
			if child:IsA("BasePart") then
				connectGravityZone(child)
			end
		end
	end

	local foundKillFloor = foundMechanics:FindFirstChild(KILL_FLOOR_NAME)
	if foundKillFloor and foundKillFloor:IsA("BasePart") then
		killFloor = foundKillFloor
		disableLegacyScript(foundKillFloor, LEGACY_KILL_LOGIC_NAME, "KillLogic_DISABLED_OLD")
		killFloor.Touched:Connect(onKillFloorTouched)
	end

	platforms = collectPlatforms(foundGround)
	for _, entry in platforms do
		for _, part in entry.parts do
			part.Touched:Connect(function(hit: BasePart)
				onPlatformTouched(entry, hit)
			end)
		end
	end

	for _, player in Players:GetPlayers() do
		player:SetAttribute(GRAVITY_ATTRIBUTE, false)
		watchPlayer(player)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		player:SetAttribute(GRAVITY_ATTRIBUTE, false)
		watchPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		activeGravityPlayers[player] = nil
		touchCooldowns[player] = nil
	end)

	script:SetAttribute("PlatformCount", #platforms)
	script:SetAttribute("Started", true)
end

return Zone7GravityService
