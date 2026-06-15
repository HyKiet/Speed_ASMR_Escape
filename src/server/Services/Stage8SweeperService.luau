--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Stage8SweeperService = {}

local ZONE_NAME = "Zone8"
local GROUND_NAME = "Ground"
local MECHANICS_NAME = "Mechanics"
local STAGE_START_NAME = "Stage8Start"
local ARENA_FLOOR_NAME = "ArenaFloor"
local SWEEPER_ARM_NAME = "SweeperArm"
local HINGE_NAME = "SpinnerHinge"
local ARROWS_FOLDER_NAME = "RotationArrows"

local STAGE_NUMBER = 8
local MIN_LEVEL_TO_SURVIVE = 74
local MIN_WALK_SPEED_TO_SURVIVE = 152
local SWEEPER_DEGREES_PER_SECOND = 45
local HIT_CHECK_INTERVAL_SECONDS = 0.05
local KILL_COOLDOWN_SECONDS = 0.75
local ARENA_RADIUS = 78
local ARROW_COUNT = 8

local arenaFloor: BasePart?
local stageStart: BasePart?
local sweeperArm: BasePart?
local spinnerHinge: HingeConstraint?
local sweepCenter: Vector3?
local baseArmCFrame: CFrame?
local sweepAngle = 0
local lastHitCheckTime = 0
local lastKillTimes: { [Player]: number } = {}

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

local function getPlayerFromBodyPart(part: BasePart): (Player?, Humanoid?)
	if not BODY_PART_NAMES[part.Name] then
		return nil, nil
	end

	local character = part:FindFirstAncestorOfClass("Model")
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

local function isQualified(player: Player, humanoid: Humanoid): boolean
	return getLevel(player) >= MIN_LEVEL_TO_SURVIVE and humanoid.WalkSpeed >= MIN_WALK_SPEED_TO_SURVIVE
end

local function isPlayerInStage8(player: Player): boolean
	return player:GetAttribute("ActiveStage") == STAGE_NUMBER or player:GetAttribute("CurrentStage") == STAGE_NUMBER
end

local function isInsideArena(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local center = sweepCenter
	if not root or not root:IsA("BasePart") or not center then
		return false
	end

	local flatOffset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	return flatOffset.Magnitude <= ARENA_RADIUS
end

local function killPlayer(player: Player, humanoid: Humanoid)
	local now = os.clock()
	if now - (lastKillTimes[player] or 0) < KILL_COOLDOWN_SECONDS then
		return
	end

	lastKillTimes[player] = now
	humanoid.Health = 0
end

local function markStage8Started(hit: BasePart)
	local player = getPlayerFromBodyPart(hit)
	if player then
		player:SetAttribute("ActiveStage", STAGE_NUMBER)
		player:SetAttribute("CurrentStage", STAGE_NUMBER)
	end
end

local function configureHinge()
	local hinge = spinnerHinge
	if not hinge then
		return
	end

	hinge.Enabled = false
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = math.rad(SWEEPER_DEGREES_PER_SECOND)
	hinge.MotorMaxAcceleration = 500000
	hinge.MotorMaxTorque = 1000000000
end

local function configureParts()
	local floor = arenaFloor
	local arm = sweeperArm
	if floor then
		floor.Size = Vector3.new(150, 2, 150)
		floor.Material = Enum.Material.Plastic
		floor.Color = Color3.fromRGB(75, 151, 75)
		floor.CanCollide = true
		floor.CanTouch = true
		floor.CanQuery = true
	end
	if arm then
		arm.Anchored = true
		arm.Size = Vector3.new(140, 18, 1.5)
		arm.Material = Enum.Material.Neon
		arm.Color = Color3.fromRGB(255, 67, 67)
		arm.CanCollide = true
		arm.CanTouch = true
		arm.CanQuery = true
	end
end

local function createArrowPart(parent: Instance, name: string, size: Vector3, cframe: CFrame): BasePart
	local part = parent:FindFirstChild(name)
	if not part or not part:IsA("BasePart") then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end

	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 255, 255)
	part.Transparency = 0.08
	part.Size = size
	part.CFrame = cframe
	return part
end

local function ensureRotationArrows(mechanics: Folder)
	local floor = arenaFloor
	local center = sweepCenter
	if not floor or not center then
		return
	end

	local folder = mechanics:FindFirstChild(ARROWS_FOLDER_NAME)
	if not folder or not folder:IsA("Folder") then
		folder = Instance.new("Folder")
		folder.Name = ARROWS_FOLDER_NAME
		folder.Parent = mechanics
	end

	local y = floor.Position.Y + (floor.Size.Y * 0.5) + 0.08
	for index = 1, ARROW_COUNT do
		local theta = ((index - 1) / ARROW_COUNT) * math.pi * 2
		local radial = Vector3.new(math.cos(theta), 0, math.sin(theta))
		local tangent = Vector3.new(radial.Z, 0, -radial.X)
		local position = Vector3.new(center.X, y, center.Z) + (radial * 48)
		local baseCFrame = CFrame.lookAt(position, position + tangent, Vector3.yAxis)

		createArrowPart(folder, `Arrow{index}_Shaft`, Vector3.new(2.2, 0.16, 13), baseCFrame)
		createArrowPart(folder, `Arrow{index}_HeadLeft`, Vector3.new(2.2, 0.16, 7), baseCFrame * CFrame.new(-2.2, 0, -5.2) * CFrame.Angles(0, math.rad(35), 0))
		createArrowPart(folder, `Arrow{index}_HeadRight`, Vector3.new(2.2, 0.16, 7), baseCFrame * CFrame.new(2.2, 0, -5.2) * CFrame.Angles(0, math.rad(-35), 0))
	end
end

local function updateSweeper(dt: number)
	local arm = sweeperArm
	local center = sweepCenter
	local baseCFrame = baseArmCFrame
	if not arm or not center or not baseCFrame then
		return
	end

	sweepAngle = (sweepAngle - math.rad(SWEEPER_DEGREES_PER_SECOND) * dt) % (math.pi * 2)
	arm.CFrame = CFrame.new(center) * CFrame.Angles(0, sweepAngle, 0) * (baseCFrame - baseCFrame.Position)
end

local function getCharactersForOverlap(): { Instance }
	local characters = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and humanoid.Health > 0 and isPlayerInStage8(player) and isInsideArena(player) then
			table.insert(characters, character)
		end
	end

	return characters
end

local function processSweeperHits()
	local arm = sweeperArm
	if not arm then
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

	for _, overlap in Workspace:GetPartsInPart(arm, params) do
		local player, humanoid = getPlayerFromBodyPart(overlap)
		if player and humanoid then
			killPlayer(player, humanoid)
		end
	end
end

function Stage8SweeperService.Init()
	script:SetAttribute("Started", false)
	script:SetAttribute("SweeperDegreesPerSecond", SWEEPER_DEGREES_PER_SECOND)
end

function Stage8SweeperService.Start()
	local zone = Workspace:WaitForChild(ZONE_NAME, 30)
	if not zone then
		warn("[Stage8SweeperService] Workspace.Zone8 not found")
		return
	end

	local foundGround = zone:WaitForChild(GROUND_NAME, 30)
	local foundMechanics = zone:WaitForChild(MECHANICS_NAME, 30)
	if not foundGround or not foundGround:IsA("Folder") or not foundMechanics or not foundMechanics:IsA("Folder") then
		warn("[Stage8SweeperService] Zone8 Ground/Mechanics missing")
		return
	end

	local foundFloor = foundGround:WaitForChild(ARENA_FLOOR_NAME, 30)
	local foundStart = foundMechanics:WaitForChild(STAGE_START_NAME, 30)
	local foundArm = foundMechanics:WaitForChild(SWEEPER_ARM_NAME, 30)
	local foundHinge = foundMechanics:FindFirstChild(HINGE_NAME)
	if not foundFloor or not foundFloor:IsA("BasePart") or not foundStart or not foundStart:IsA("BasePart") or not foundArm or not foundArm:IsA("BasePart") then
		warn("[Stage8SweeperService] Stage8 floor/start/sweeper missing")
		return
	end

	arenaFloor = foundFloor
	stageStart = foundStart
	sweeperArm = foundArm
	spinnerHinge = if foundHinge and foundHinge:IsA("HingeConstraint") then foundHinge else nil
	sweepCenter = Vector3.new(foundFloor.Position.X, foundArm.Position.Y, foundFloor.Position.Z)
	baseArmCFrame = CFrame.new(foundArm.Position) * (foundArm.CFrame - foundArm.Position)
	sweepAngle = 0

	configureHinge()
	configureParts()
	ensureRotationArrows(foundMechanics)

	stageStart.Touched:Connect(function(hit: BasePart)
		if hit:IsA("BasePart") then
			markStage8Started(hit)
		end
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		updateSweeper(dt)
		local now = os.clock()
		if now - lastHitCheckTime >= HIT_CHECK_INTERVAL_SECONDS then
			lastHitCheckTime = now
			processSweeperHits()
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastKillTimes[player] = nil
	end)

	script:SetAttribute("Started", true)
end

return Stage8SweeperService
