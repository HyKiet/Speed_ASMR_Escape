--!strict
--[[
	Zone11StamperController.luau — render local Máy Ép Ngang Cyber Metal (Stage 11).

	Server không set Position mỗi frame nữa (xem Zone11.Mechanics.Zone11HorizontalStamperScript):
	alpha đóng/mở suy ra từ workspace:GetServerTimeNow() → client dựng lại y hệt.

	3 pha (v4 — 2026-07-26):
	  Telegraph — LED chớp + 2 đường laser chỉ giới nơi 2 khối sẽ gặp nhau
	  Stamp     — ÉP TỪ TỪ vào giữa (smoothstep 1.70s), BANG kim loại + tia lửa
	  Retract   — MỞ TỪ TỪ nhưng nhanh hơn ép (smoothstep 1.15s)
	⚠️ `closeAlphaAt` PHẢI khớp tuyệt đối với bản trong Zone11HorizontalStamperScript —
	server phán xử sát thương bằng chính công thức này, lệch là "chết oan/hụt".

	Rig hạt/âm thanh tạo MỘT LẦN lúc Start; RenderStepped chỉ set thuộc tính.

	SFX: đổi asset qua attribute `StampImpactSoundId` trên Workspace.Zones.Zone11
	(mặc định dùng engine sound để luôn phát được).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Pro Sound Effects "Metal Impacts 5" — va chạm kim loại nhiều lớp, 2.0s, free.
local DEFAULT_IMPACT_SOUND = "rbxassetid://9116684884"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local ZoneLod = require(script.Parent.ZoneLod)

-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed — xem ZoneLod.
local RENDER_RADIUS = 420

-- v4 (2026-07-26): khói Cyber đã bỏ; HazardFace GIỮ MÀU người dựng map đặt (controller không
-- ghi .Color nữa). LED_ALERT giờ chỉ còn dùng cho laser chỉ giới + tia lửa lúc va chạm.
local LED_ALERT = Color3.fromRGB(255, 64, 0)

local HAZARD_OFFSET_Z = 15.0

local Zone11StamperController = {}

local player = Players.LocalPlayer

local leftCrusher: BasePart? = nil
local rightCrusher: BasePart? = nil
local leftHazard: BasePart? = nil
local rightHazard: BasePart? = nil

local nextFarStep = 0
local cycle, telegraphAt, stampAt, holdAt, retractAt = 1, 0, 0, 0, 0
local retractDuration = 0.55
local openLeftZ, pressLeftZ, openRightZ, pressRightZ = 0, 0, 0, 0
local centerX, centerZ, crusherY, trackLength = 0, 0, 0, 0

local laserLeft: Part? = nil
local laserRight: Part? = nil
local impactRig: Part? = nil
local sparkEmitter: ParticleEmitter? = nil
local impactSound: Sound? = nil

local lastCyclePhase = -1
local ready = false
local connection: RBXScriptConnection? = nil

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone11")
	local mech = zone and zone:FindFirstChild("Mechanics")
	local folder = mech and mech:FindFirstChild("HorizontalStampers")
	local model = folder and folder:FindFirstChild("ContinuousStamper")
	if not (zone and model) then
		return false
	end

	local cycleAttr = zone:GetAttribute("StampCycle")
	if typeof(cycleAttr) ~= "number" then
		return false
	end

	local l = model:FindFirstChild("LeftCrusher")
	local r = model:FindFirstChild("RightCrusher")
	if not (l and l:IsA("BasePart") and r and r:IsA("BasePart")) then
		return false
	end

	leftCrusher, rightCrusher = l, r
	leftHazard = l:FindFirstChild("HazardFace") :: BasePart?
	rightHazard = r:FindFirstChild("HazardFace") :: BasePart?

	cycle = cycleAttr
	telegraphAt = zone:GetAttribute("StampTelegraphAt") :: number
	stampAt = zone:GetAttribute("StampStampAt") :: number
	holdAt = zone:GetAttribute("StampHoldAt") :: number
	retractAt = zone:GetAttribute("StampRetractAt") :: number
	retractDuration = cycle - retractAt
	openLeftZ = zone:GetAttribute("StampOpenLeftZ") :: number
	pressLeftZ = zone:GetAttribute("StampPressLeftZ") :: number
	openRightZ = zone:GetAttribute("StampOpenRightZ") :: number
	pressRightZ = zone:GetAttribute("StampPressRightZ") :: number
	centerX = zone:GetAttribute("StampCenterX") :: number
	centerZ = zone:GetAttribute("StampCenterZ") :: number
	crusherY = zone:GetAttribute("StampY") :: number
	trackLength = zone:GetAttribute("StampTrackLength") :: number

	return true
end

local function makeLaser(z: number): Part
	local beam = Instance.new("Part")
	beam.Name = "StampLaserGuide"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = LED_ALERT
	beam.Transparency = 1
	beam.Size = Vector3.new(trackLength, 0.35, 0.35)
	beam.Position = Vector3.new(centerX, crusherY - 10, z)
	beam.Parent = Workspace
	return beam
end

local function buildRigs()
	laserLeft = makeLaser(centerZ - 4)
	laserRight = makeLaser(centerZ + 4)

	local rig = Instance.new("Part")
	rig.Name = "Zone11ImpactRig"
	rig.Anchored = true
	rig.CanCollide = false
	rig.CanQuery = false
	rig.CanTouch = false
	rig.Transparency = 1
	rig.Size = Vector3.new(trackLength, 2, 2)
	rig.Position = Vector3.new(centerX, crusherY - 8, centerZ)

	local spark = Instance.new("ParticleEmitter")
	spark.Name = "CyberSpark"
	spark.Texture = SPARK_TEXTURE
	spark.Color = ColorSequence.new(LED_ALERT, Color3.fromRGB(255, 200, 90))
	spark.LightEmission = 1
	spark.LightInfluence = 0
	spark.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	spark.Size = NumberSequence.new(2.2, 0)
	spark.Rate = 0
	spark.Lifetime = NumberRange.new(0.25, 0.55)
	spark.Speed = NumberRange.new(55, 110)
	spark.SpreadAngle = Vector2.new(180, 45)
	spark.Acceleration = Vector3.new(0, -120, 0)
	spark.Parent = rig

	local sound = Instance.new("Sound")
	sound.Name = "StampImpact"
	local zone = Workspace.Zones:FindFirstChild("Zone11")
	local custom = zone and zone:GetAttribute("StampImpactSoundId")
	sound.SoundId = typeof(custom) == "string" and custom or DEFAULT_IMPACT_SOUND
	sound.Volume = 1
	sound.PlaybackSpeed = 0.55 -- hạ cao độ → tiếng kim loại nén khí đanh, trầm
	sound.RollOffMaxDistance = 340
	sound.RollOffMinDistance = 25
	sound.Parent = rig

	rig.Parent = Workspace
	impactRig, sparkEmitter, impactSound = rig, spark, sound
end

local function closeAlphaAt(t: number): number
	if t < stampAt then
		return 0
	elseif t < holdAt then
		local p = (t - stampAt) / (holdAt - stampAt)
		return p * p * (3 - 2 * p) -- smoothstep — "ép từ từ"
	elseif t < retractAt then
		return 1
	else
		local p = (t - retractAt) / retractDuration
		return 1 - p * p * (3 - 2 * p) -- cùng dạng, pha ngắn hơn nên mở nhanh hơn
	end
end

local function step()
	local l, r = leftCrusher, rightCrusher
	-- StreamingEnabled=true: crusher có thể bị dỡ khi đi xa → resolve lại.
	if not l or not r or not l:IsDescendantOf(Workspace) then
		leftCrusher, rightCrusher, leftHazard, rightHazard = nil, nil, nil, nil
		ready = false
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local dx = root.Position.X - centerX
	local dz = root.Position.Z - centerZ
	local distSq = dx * dx + dz * dz
	if distSq > ZoneLod.RadiusSq(RENDER_RADIUS) then
		return -- SLEEP
	end

	local now = Workspace:GetServerTimeNow()
	local shouldStep: boolean
	shouldStep, nextFarStep = ZoneLod.ShouldStepFar(distSq, now, nextFarStep)
	if not shouldStep then
		return
	end

	local t = now % cycle
	local alpha = closeAlphaAt(t)

	local leftZ = openLeftZ + (pressLeftZ - openLeftZ) * alpha
	local rightZ = openRightZ + (pressRightZ - openRightZ) * alpha

	l.Position = Vector3.new(centerX, crusherY, leftZ)
	r.Position = Vector3.new(centerX, crusherY, rightZ)
	if leftHazard then
		leftHazard.Position = Vector3.new(centerX, crusherY, leftZ + HAZARD_OFFSET_Z)
	end
	if rightHazard then
		rightHazard.Position = Vector3.new(centerX, crusherY, rightZ - HAZARD_OFFSET_Z)
	end

	-- Pha 1: LED đỏ chớp + laser chỉ giới
	local inTelegraph = t >= telegraphAt and t < stampAt
	if laserLeft and laserRight then
		local visible = inTelegraph and 0.25 or 1
		laserLeft.Transparency = visible
		laserRight.Transparency = visible
	end

	-- HazardFace GIỮ NGUYÊN MÀU do người dựng map đặt trong Studio (yêu cầu 2026-07-26):
	-- controller KHÔNG ghi .Color nữa. Cảnh báo pha telegraph đã có laser chỉ giới ở trên.

	-- Pha 2: khoảnh khắc chạm đáy → burst 1 lần / chu kỳ
	local cycleIndex = math.floor(Workspace:GetServerTimeNow() / cycle)
	if t >= holdAt and t < retractAt and lastCyclePhase ~= cycleIndex then
		lastCyclePhase = cycleIndex
		if sparkEmitter then
			sparkEmitter:Emit(45)
		end
		if impactSound then
			impactSound:Play()
		end
	end
end

function Zone11StamperController.Start()
	connection = RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			if not ready then
				ready = resolve()
				if ready and not impactRig then
					buildRigs()
				end
			end
			task.wait(0.5)
		end
	end)
end

function Zone11StamperController.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, inst in { laserLeft, laserRight, impactRig } do
		if inst then
			inst:Destroy()
		end
	end
	laserLeft, laserRight, impactRig = nil, nil, nil
end

return Zone11StamperController
