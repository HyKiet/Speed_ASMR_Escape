--!nocheck
-- Build script for Zone 9 — Tsunami Swim Sprint (horizontal water channel running along +X).
-- Run in the Edit datamodel via Studio MCP (execute_luau). Safe to re-run: it deletes the
-- existing Workspace.Zone9 + ServerStorage.TsunamiTemplate first, then rebuilds.
--
-- Geometry is NOT managed by Rojo (only scripts are), so the parts created here persist into the
-- committed SpeedEscape.rbxlx, exactly like Zone1-8. Remember to SAVE the place afterwards.

local ServerStorage = game:GetService("ServerStorage")
local ws = workspace

-- ── Layout params ────────────────────────────────────────────────────────────
local ZONE_Z = 3140 -- channel runs along +X at this fixed Z (just past Zone8 finish @ Z=3077)
local WIDTH = 90 -- channel width along Z
local FLOOR_TOP = 0 -- top surface Y of the water floor (players stand here)
local START_X = -4 -- Stage9Start gate X (player enters from Zone8 here)
local FINISH_X = 460 -- Stage9Finish gate X (far end)
local FLOOR_X_MIN = -45
local FLOOR_X_MAX = 495
local floorCenterX = (FLOOR_X_MIN + FLOOR_X_MAX) / 2
local floorSizeX = FLOOR_X_MAX - FLOOR_X_MIN
local frontZ = ZONE_Z - WIDTH / 2 -- 3095
local backZ = ZONE_Z + WIDTH / 2 -- 3185

-- ── Cleanup previous build ───────────────────────────────────────────────────
local oldZone = ws:FindFirstChild("Zone9")
if oldZone then oldZone:Destroy() end
local oldTemplate = ServerStorage:FindFirstChild("TsunamiTemplate")
if oldTemplate then oldTemplate:Destroy() end

-- ── Folders ──────────────────────────────────────────────────────────────────
local zone = Instance.new("Folder"); zone.Name = "Zone9"; zone.Parent = ws
local ground = Instance.new("Folder"); ground.Name = "Ground"; ground.Parent = zone
local mech = Instance.new("Folder"); mech.Name = "Mechanics"; mech.Parent = zone
local bounds = Instance.new("Folder"); bounds.Name = "Boundaries"; bounds.Parent = zone

local function part(name, parent, size, pos, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = pos
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = parent
	return p
end

-- ── Channel floor (themed solid floor: players run at WalkSpeed = their speed stat) ──
part("WaterFloor", ground, Vector3.new(floorSizeX, 4, WIDTH), Vector3.new(floorCenterX, FLOOR_TOP - 2, ZONE_Z), {
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(28, 86, 130),
	CanCollide = true,
})

-- Cosmetic translucent water surface
part("WaterSurface", ground, Vector3.new(floorSizeX, 1, WIDTH), Vector3.new(floorCenterX, FLOOR_TOP + 0.6, ZONE_Z), {
	Material = Enum.Material.Glass,
	Color = Color3.fromRGB(72, 170, 226),
	Transparency = 0.45,
	Reflectance = 0.12,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
})

-- ── Connector from Zone8 finish (-4,0,3077) into the channel ──────────────────
part("Transition8To9", ground, Vector3.new(72, 4, 18), Vector3.new(-4, FLOOR_TOP - 2, 3087), {
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(70, 78, 92),
	CanCollide = true,
})

-- ── Stage gates (CanCollide=false trigger volumes; StageCheckpointService reads Touched) ──
part("Stage9Start", mech, Vector3.new(4, 20, WIDTH), Vector3.new(START_X, FLOOR_TOP + 10, ZONE_Z), {
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(235, 235, 235),
	Transparency = 0.5,
	CanCollide = false,
	CanQuery = true,
	CanTouch = true,
})
part("Stage9Finish", mech, Vector3.new(4, 20, WIDTH), Vector3.new(FINISH_X, FLOOR_TOP + 10, ZONE_Z), {
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 170, 0),
	Transparency = 0.4,
	CanCollide = false,
	CanQuery = true,
	CanTouch = true,
})

-- Simple sign
local sign = part("Stage9SignPart", mech, Vector3.new(2, 12, 22), Vector3.new(START_X - 3, FLOOR_TOP + 9, backZ - 6), {
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(20, 30, 45),
	CanCollide = false,
	CanQuery = false,
})
do
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "STAGE 9\nTSUNAMI SPRINT"
	label.TextColor3 = Color3.fromRGB(120, 220, 255)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
end

-- ── Boundary walls (front wall leaves a gap at the entrance) ──────────────────
part("WallBack", bounds, Vector3.new(floorSizeX, 30, 4), Vector3.new(floorCenterX, 15, backZ), {
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(18, 52, 80),
	CanCollide = true,
	Transparency = 0.2,
})
do
	local frontMinX = START_X + 34 -- gap from FLOOR_X_MIN..START_X+34 for the Zone8 connector
	local frontCenter = (frontMinX + FLOOR_X_MAX) / 2
	local frontSize = FLOOR_X_MAX - frontMinX
	part("WallFront", bounds, Vector3.new(frontSize, 30, 4), Vector3.new(frontCenter, 15, frontZ), {
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(18, 52, 80),
		CanCollide = true,
		Transparency = 0.2,
	})
end
part("WallEndFinish", bounds, Vector3.new(4, 30, WIDTH), Vector3.new(FLOOR_X_MAX, 15, ZONE_Z), {
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(18, 52, 80),
	CanCollide = true,
	Transparency = 0.2,
})

-- ── Attributes consumed by Zone9TsunamiService ───────────────────────────────
zone:SetAttribute("ChannelZ", ZONE_Z)
zone:SetAttribute("ChannelWidth", WIDTH)
zone:SetAttribute("FloorTopY", FLOOR_TOP)

-- ── Tsunami template (reuse the existing Workspace.Tsunami model) ─────────────
local tsunami = ws:FindFirstChild("Tsunami")
local templateInfo = "NO Workspace.Tsunami found — service will fall back to a generated block wave"
if tsunami and tsunami:IsA("Model") then
	local _, size = tsunami:GetBoundingBox()
	local scale = WIDTH / size.Z -- fit channel width
	tsunami:ScaleTo(scale)

	local cf, nsize = tsunami:GetBoundingBox()
	local kv = Instance.new("Part")
	kv.Name = "KillVolume"
	kv.Anchored = true
	kv.CanCollide = false
	kv.CanQuery = true
	kv.CanTouch = true
	kv.Transparency = 1
	kv.Size = Vector3.new(nsize.X + 2, 50, WIDTH + 2)
	kv.CFrame = cf
	kv.Parent = tsunami
	tsunami.PrimaryPart = kv

	tsunami.Name = "TsunamiTemplate"
	tsunami.Parent = ServerStorage
	templateInfo = string.format("TsunamiTemplate scaled x%.3f -> size %.1f,%.1f,%.1f", scale, nsize.X, nsize.Y, nsize.Z)
end

return string.format(
	"Zone9 built. Floor X[%d..%d] Z=%d width=%d. Start X=%d Finish X=%d. %s",
	FLOOR_X_MIN, FLOOR_X_MAX, ZONE_Z, WIDTH, START_X, FINISH_X, templateInfo
)
