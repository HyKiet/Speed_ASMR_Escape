-- Zone 8 — Sweeper (INLINE trap script).
-- Đặt trực tiếp làm con của Workspace.Zone8.Mechanics (Script chạy trên Server).
-- Cánh tay quét quay 90°/s quanh arena; player ActiveStage/CurrentStage==8 chạm cánh tay là chết ngay.
-- (Bản gốc để tham khảo/version-control; bản chạy nằm trong .rbxlx do không được Rojo sync.)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local mech = script.Parent
local zone = mech.Parent
local ground = zone:FindFirstChild("Ground")
local arenaFloor = ground and ground:FindFirstChild("ArenaFloor")
local arm = mech:FindFirstChild("SweeperArm")
local stageStart = mech:FindFirstChild("Stage8Start")

local STAGE = 8
local DEG_PER_SEC = 90
local KILL_CD = 0.5
local ARENA_RADIUS = 78

if not arenaFloor or not arm then
	warn("[Zone8 inline] ArenaFloor/SweeperArm missing")
	return
end

local BODY = {
	HumanoidRootPart = true, Head = true, Torso = true, UpperTorso = true, LowerTorso = true,
	LeftArm = true, RightArm = true, LeftLeg = true, RightLeg = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

arm.Anchored = true
arm.Size = Vector3.new(140, 18, 1.5)
arm.Material = Enum.Material.Neon
arm.Color = Color3.fromRGB(255, 67, 67)
arm.CanCollide = true
arm.CanTouch = true
arm.CanQuery = true

local center = Vector3.new(arenaFloor.Position.X, arm.Position.Y, arenaFloor.Position.Z)
local baseRot = arm.CFrame - arm.Position
local sweepAngle = 0
local lastKill = {}

local function inStage(plr)
	return plr:GetAttribute("ActiveStage") == STAGE or plr:GetAttribute("CurrentStage") == STAGE
end
local function insideArena(plr)
	local c = plr.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r or not r:IsA("BasePart") then
		return false
	end
	local off = Vector3.new(r.Position.X - center.X, 0, r.Position.Z - center.Z)
	return off.Magnitude <= ARENA_RADIUS
end
local function playerFromPart(part)
	if not BODY[part.Name] then
		return nil, nil
	end
	local c = part:FindFirstAncestorOfClass("Model")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then
		return nil, nil
	end
	local plr = Players:GetPlayerFromCharacter(c)
	return plr, h
end
local function kill(plr, h)
	local now = os.clock()
	if now - (lastKill[plr] or 0) < KILL_CD then
		return
	end
	lastKill[plr] = now
	h.Health = 0
end

if stageStart then
	stageStart.Touched:Connect(function(hit)
		local plr = select(1, playerFromPart(hit))
		if plr then
			plr:SetAttribute("ActiveStage", STAGE)
			plr:SetAttribute("CurrentStage", STAGE)
		end
	end)
end

arm.Touched:Connect(function(hit)
	local plr, h = playerFromPart(hit)
	if plr and h and inStage(plr) then
		kill(plr, h)
	end
end)

local function activeCharacters()
	local list = {}
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if c and h and h.Health > 0 and inStage(plr) and insideArena(plr) then
			table.insert(list, c)
		end
	end
	return list
end

RunService.Heartbeat:Connect(function(dt)
	sweepAngle = (sweepAngle - math.rad(DEG_PER_SEC) * dt) % (math.pi * 2)
	arm.CFrame = CFrame.new(center) * CFrame.Angles(0, sweepAngle, 0) * baseRot

	local chars = activeCharacters()
	if #chars == 0 then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = chars
	params.RespectCanCollide = false
	for _, overlap in Workspace:GetPartsInPart(arm, params) do
		local plr, h = playerFromPart(overlap)
		if plr and h then
			kill(plr, h)
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastKill[plr] = nil
end)
