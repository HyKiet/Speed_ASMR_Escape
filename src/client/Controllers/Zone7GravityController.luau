--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Zone7GravityController = {}

local localPlayer = Players.LocalPlayer
local GRAVITY_ATTRIBUTE = "Zone7GravityEnabled"
local GRAVITY_FOLDER_NAME = "GravityController"
local ZONE_NAME = "Zone7"
local GROUND_NAME = "Ground"
local MECHANICS_NAME = "Mechanics"
local STAGE_START_NAME = "Stage7Start"
local STAGE_FINISH_NAME = "Stage7Finish"
local GRAVITY_ZONES_NAME = "GravityZones"

local PLAYER_DEPENDENCIES = {
	"PlayerModule",
	"PlayerScriptsLoader",
	"RbxCharacterSounds",
}

local LOCAL_SCAN_INTERVAL_SECONDS = 1 / 30
local TOUCH_PREDICTION_SECONDS = 3
local SPATIAL_PREDICTION_SECONDS = 1.5
local LOCAL_PART_MARGIN = Vector3.new(7, 8, 7)
local GRAVITY_CATCHUP_BIND_NAME = "Zone7GravityCatchUp"
local GRAVITY_CATCHUP_ALPHA = 0.45

local Controller: any = nil
local GravityControllerClass: any = nil
local creatingController = false
local dependenciesPrepared = false
local preparingDependencies = false
local predictedActive = false
local predictionExpiresAt = 0
local lastLocalScanAt = 0
local lastTargetGravityUp = Vector3.yAxis
local activationParts: { BasePart } = {}
local activationTouchConnections: { [BasePart]: RBXScriptConnection } = {}
local finishTouchConnection: RBXScriptConnection?

local PI2 = math.pi * 2
local ZERO = Vector3.new(0, 0, 0)

local LOWER_RADIUS_OFFSET = 3
local NUM_DOWN_RAYS = 24
local ODD_DOWN_RAY_START_RADIUS = 3
local EVEN_DOWN_RAY_START_RADIUS = 2
local ODD_DOWN_RAY_END_RADIUS = 1.66666
local EVEN_DOWN_RAY_END_RADIUS = 1

local NUM_FEELER_RAYS = 9
local FEELER_LENGTH = 2
local FEELER_START_OFFSET = 2
local FEELER_RADIUS = 3.5
local FEELER_APEX_OFFSET = 1
local FEELER_WEIGHTING = 8

local function getGravitySourceFolder(): Folder?
	local source = Workspace:FindFirstChild(GRAVITY_FOLDER_NAME)
	if source and source:IsA("Folder") then
		return source
	end

	return nil
end

local function getGravityModule(): ModuleScript?
	local replicatedModule = ReplicatedStorage:FindFirstChild(GRAVITY_FOLDER_NAME)
	if replicatedModule and replicatedModule:IsA("ModuleScript") then
		return replicatedModule
	end

	local source = getGravitySourceFolder()
	local sourceReplicated = source and source:FindFirstChild("ReplicatedStorage")
	local sourceModule = sourceReplicated and sourceReplicated:FindFirstChild(GRAVITY_FOLDER_NAME)
	if sourceModule and sourceModule:IsA("ModuleScript") then
		return sourceModule
	end

	return nil
end

local function cloneDependency(parent: Instance, sourceParent: Instance, childName: string): Instance?
	local existing = parent:FindFirstChild(childName)
	if existing then
		return existing
	end

	local source = sourceParent:FindFirstChild(childName)
	if not source then
		return nil
	end

	local clone = source:Clone()
	clone.Parent = parent
	return clone
end

local function ensurePlayerScriptDependencies(): boolean
	local source = getGravitySourceFolder()
	local sourceStarterPlayer = source and source:FindFirstChild("StarterPlayer")
	local sourceStarterPlayerScripts = sourceStarterPlayer and sourceStarterPlayer:FindFirstChild("StarterPlayerScripts")
	if not sourceStarterPlayerScripts then
		return false
	end

	local playerScripts = localPlayer:FindFirstChildOfClass("PlayerScripts") or localPlayer:WaitForChild("PlayerScripts", 10)
	if not playerScripts then
		return false
	end

	for _, dependencyName in PLAYER_DEPENDENCIES do
		if not cloneDependency(playerScripts, sourceStarterPlayerScripts, dependencyName) then
			return false
		end
	end

	return true
end

local function ensureCharacterAnimate(character: Model): boolean
	local source = getGravitySourceFolder()
	local sourceStarterPlayer = source and source:FindFirstChild("StarterPlayer")
	local sourceStarterCharacterScripts = sourceStarterPlayer and sourceStarterPlayer:FindFirstChild("StarterCharacterScripts")
	local sourceAnimate = sourceStarterCharacterScripts and sourceStarterCharacterScripts:FindFirstChild("Animate")
	if not sourceAnimate then
		return false
	end

	local animate = character:FindFirstChild("Animate")
	if animate and animate:FindFirstChild("Controller") then
		return true
	end
	if animate then
		animate:Destroy()
	end

	local clone = sourceAnimate:Clone()
	clone.Parent = character
	return clone:FindFirstChild("Controller") ~= nil
end

local function areRuntimeScriptsReady(): boolean
	local playerScripts = localPlayer:FindFirstChildOfClass("PlayerScripts")
	if not playerScripts then
		return false
	end

	local loader = playerScripts:FindFirstChild("PlayerScriptsLoader")
	local loaded = loader and loader:FindFirstChild("Loaded")
	if not loaded or not loaded:IsA("BoolValue") then
		return false
	end

	return loaded.Value
end

local function preloadGravityModule(): boolean
	if GravityControllerClass then
		return true
	end

	local gravityModule = getGravityModule()
	if not gravityModule then
		return false
	end

	GravityControllerClass = require(gravityModule)
	return GravityControllerClass ~= nil
end

local function prepareDependencies()
	if dependenciesPrepared or preparingDependencies then
		return
	end

	preparingDependencies = true
	task.spawn(function()
		local success, err = pcall(function()
			local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
			if not character then
				return
			end

			dependenciesPrepared = ensurePlayerScriptDependencies()
				and ensureCharacterAnimate(character)
				and preloadGravityModule()
		end)

		if not success then
			warn("[Zone7GravityController] Failed to preload GravityController: " .. tostring(err))
			dependenciesPrepared = false
		end

		preparingDependencies = false
	end)
end

local function removeGravityRuntimeObjects(character: Model?)
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		for _, objectName in { "BodyGyro", "VectorForce" } do
			local child = root:FindFirstChild(objectName)
			if child then
				child:Destroy()
			end
		end
	end

	for _, objectName in { "Sphere", "Floor" } do
		local child = character:FindFirstChild(objectName)
		if child then
			child:Destroy()
		end
	end
end

local function buildIgnoreList(): { Instance }
	local ignoreList = {}
	for index, player in Players:GetPlayers() do
		ignoreList[index] = player.Character
	end

	return ignoreList
end

local function getGravityUp(self: any, oldGravityUp: Vector3): Vector3
	local ignoreList = buildIgnoreList()
	local hrpCF = self.HRP.CFrame
	local isR15 = self.Humanoid.RigType == Enum.HumanoidRigType.R15
	local origin = if isR15 then hrpCF.Position else hrpCF.Position + (0.35 * oldGravityUp)
	local radialVector = if math.abs(hrpCF.LookVector:Dot(oldGravityUp)) < 0.999
		then hrpCF.LookVector:Cross(oldGravityUp)
		else hrpCF.RightVector:Cross(oldGravityUp)

	local centerRayLength = 25
	local centerRay = Ray.new(origin, -centerRayLength * oldGravityUp)
	local centerHit, _, centerHitNormal = Workspace:FindPartOnRayWithIgnoreList(centerRay, ignoreList)

	local downHitCount = 0
	local feelerHitCount = 0
	local mainDownNormal = ZERO
	if centerHit then
		mainDownNormal = centerHitNormal
	end

	local downRaySum = ZERO
	for index = 1, NUM_DOWN_RAYS do
		local dtheta = PI2 * ((index - 1) / NUM_DOWN_RAYS)
		local angleWeight = 0.25 + (0.75 * math.abs(math.cos(dtheta)))
		local isEvenRay = index % 2 == 0
		local startRadius = if isEvenRay then EVEN_DOWN_RAY_START_RADIUS else ODD_DOWN_RAY_START_RADIUS
		local endRadius = if isEvenRay then EVEN_DOWN_RAY_END_RADIUS else ODD_DOWN_RAY_END_RADIUS
		local offset = CFrame.fromAxisAngle(oldGravityUp, dtheta) * radialVector
		local direction = (LOWER_RADIUS_OFFSET * -oldGravityUp) + ((endRadius - startRadius) * offset)
		local ray = Ray.new(origin + (startRadius * offset), centerRayLength * direction.Unit)
		local hit, _, hitNormal = Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
		if hit then
			downRaySum += angleWeight * hitNormal
			downHitCount += 1
		end
	end

	local feelerNormalSum = ZERO
	for index = 1, NUM_FEELER_RAYS do
		local dtheta = 2 * math.pi * ((index - 1) / NUM_FEELER_RAYS)
		local angleWeight = 0.25 + (0.75 * math.abs(math.cos(dtheta)))
		local offset = CFrame.fromAxisAngle(oldGravityUp, dtheta) * radialVector
		local direction = ((FEELER_RADIUS * offset) + (LOWER_RADIUS_OFFSET * -oldGravityUp)).Unit
		local feelerOrigin = origin - (FEELER_APEX_OFFSET * -oldGravityUp) + (FEELER_START_OFFSET * direction)
		local ray = Ray.new(feelerOrigin, FEELER_LENGTH * direction)
		local hit, _, hitNormal = Workspace:FindPartOnRayWithIgnoreList(ray, ignoreList)
		if hit then
			feelerNormalSum += FEELER_WEIGHTING * angleWeight * hitNormal
			feelerHitCount += 1
		end
	end

	if downHitCount + feelerHitCount > 0 or centerHit then
		local normalSum = mainDownNormal + downRaySum + feelerNormalSum
		if normalSum ~= ZERO then
			lastTargetGravityUp = normalSum.Unit
			return lastTargetGravityUp
		end
	end

	lastTargetGravityUp = oldGravityUp
	return oldGravityUp
end

local function isLocalCharacterHit(hit: BasePart): boolean
	local character = localPlayer.Character
	return character ~= nil and hit:IsDescendantOf(character)
end

local function shouldBeActive(): boolean
	return localPlayer:GetAttribute(GRAVITY_ATTRIBUTE) == true or predictedActive
end

local function destroyController()
	RunService:UnbindFromRenderStep(GRAVITY_CATCHUP_BIND_NAME)

	local controller = Controller
	Controller = nil
	if controller then
		pcall(function()
			controller:Destroy()
		end)
	end

	local character = localPlayer.Character
	removeGravityRuntimeObjects(character)
end

local function createController()
	if Controller or creatingController then
		return
	end
	if not shouldBeActive() then
		return
	end

	creatingController = true
	local success, err = pcall(function()
		local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
		if not character then
			return
		end

		if not dependenciesPrepared then
			dependenciesPrepared = ensurePlayerScriptDependencies()
				and ensureCharacterAnimate(character)
				and preloadGravityModule()
		end

		if not dependenciesPrepared then
			warn("[Zone7GravityController] GravityController dependencies are missing")
			return
		end

		if not areRuntimeScriptsReady() then
			prepareDependencies()
			return
		end

		local gravityClass = GravityControllerClass
		if not gravityClass then
			warn("[Zone7GravityController] GravityController module is missing")
			return
		end

		local controller = gravityClass.new(localPlayer)
		controller.GetGravityUp = getGravityUp

		local initialGravityUp = getGravityUp(controller, controller.GravityUp)
		if initialGravityUp ~= ZERO then
			controller.GravityUp = initialGravityUp
		end

		Controller = controller
		RunService:BindToRenderStep(GRAVITY_CATCHUP_BIND_NAME, Enum.RenderPriority.Input.Value + 2, function()
			local activeController = Controller
			if not activeController then
				return
			end

			local blendedGravityUp = activeController.GravityUp:Lerp(lastTargetGravityUp, GRAVITY_CATCHUP_ALPHA)
			if blendedGravityUp ~= ZERO then
				activeController.GravityUp = blendedGravityUp.Unit
			end
		end)
	end)
	creatingController = false

	if not success then
		warn("[Zone7GravityController] Failed to start GravityController: " .. tostring(err))
		destroyController()
	end
end

local function syncController()
	if shouldBeActive() then
		createController()
	else
		destroyController()
	end
end

local function requestPredictedActivation(durationSeconds: number)
	local now = os.clock()
	predictedActive = true
	predictionExpiresAt = math.max(predictionExpiresAt, now + durationSeconds)
	prepareDependencies()
	syncController()
end

local function stopPrediction()
	predictedActive = false
	predictionExpiresAt = 0
	syncController()
end

local function isPositionInsidePart(part: BasePart, position: Vector3, margin: Vector3): boolean
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local halfSize = part.Size * 0.5

	return math.abs(localPosition.X) <= halfSize.X + margin.X
		and math.abs(localPosition.Y) <= halfSize.Y + margin.Y
		and math.abs(localPosition.Z) <= halfSize.Z + margin.Z
end

local function addActivationPart(part: Instance?)
	if not part or not part:IsA("BasePart") then
		return
	end

	table.insert(activationParts, part)
	if not activationTouchConnections[part] then
		activationTouchConnections[part] = part.Touched:Connect(function(hit: BasePart)
			if isLocalCharacterHit(hit) then
				requestPredictedActivation(TOUCH_PREDICTION_SECONDS)
			end
		end)
	end
end

local function refreshActivationParts()
	table.clear(activationParts)

	local zone = Workspace:FindFirstChild(ZONE_NAME)
	if not zone then
		return
	end

	local mechanicsFolder = zone:FindFirstChild(MECHANICS_NAME)
	local groundFolder = zone:FindFirstChild(GROUND_NAME)
	if mechanicsFolder then
		addActivationPart(mechanicsFolder:FindFirstChild(STAGE_START_NAME))

		local gravityZonesFolder = mechanicsFolder:FindFirstChild(GRAVITY_ZONES_NAME)
		if gravityZonesFolder then
			for _, descendant in gravityZonesFolder:GetDescendants() do
				addActivationPart(descendant)
			end
		end

		local finishPart = mechanicsFolder:FindFirstChild(STAGE_FINISH_NAME)
		if finishPart and finishPart:IsA("BasePart") and not finishTouchConnection then
			finishTouchConnection = finishPart.Touched:Connect(function(hit: BasePart)
				if isLocalCharacterHit(hit) then
					stopPrediction()
				end
			end)
		end
	end

	if groundFolder then
		for _, child in groundFolder:GetChildren() do
			if child:IsA("BasePart") and child.Name:match("^Platform_%d+$") then
				addActivationPart(child)
			end
		end
	end
end

local function scanLocalActivation()
	local now = os.clock()
	if now - lastLocalScanAt < LOCAL_SCAN_INTERVAL_SECONDS then
		return
	end
	lastLocalScanAt = now

	if predictedActive and now > predictionExpiresAt and localPlayer:GetAttribute(GRAVITY_ATTRIBUTE) ~= true then
		predictedActive = false
		syncController()
	end

	if localPlayer:GetAttribute(GRAVITY_ATTRIBUTE) == true or predictedActive then
		if not Controller then
			createController()
		end
		return
	end

	if #activationParts == 0 then
		refreshActivationParts()
	end

	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end

	local position = root.Position
	for _, part in activationParts do
		if part.Parent and isPositionInsidePart(part, position, LOCAL_PART_MARGIN) then
			requestPredictedActivation(SPATIAL_PREDICTION_SECONDS)
			return
		end
	end
end

function Zone7GravityController.Init()
end

function Zone7GravityController.Start()
	refreshActivationParts()
	prepareDependencies()

	localPlayer:GetAttributeChangedSignal(GRAVITY_ATTRIBUTE):Connect(function()
		if localPlayer:GetAttribute(GRAVITY_ATTRIBUTE) == true then
			predictedActive = false
			predictionExpiresAt = 0
		end
		syncController()
	end)

	localPlayer.CharacterAdded:Connect(function()
		dependenciesPrepared = false
		destroyController()
		prepareDependencies()
		task.defer(syncController)
	end)

	localPlayer.CharacterRemoving:Connect(function()
		stopPrediction()
		destroyController()
	end)

	RunService.PreSimulation:Connect(scanLocalActivation)
	syncController()
end

return Zone7GravityController
