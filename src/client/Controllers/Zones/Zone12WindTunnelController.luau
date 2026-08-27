--!strict
--[[
	Zone12WindTunnelController.luau
	Client-side controller for Stage 12: Cyber Wind Tunnel.
	
	Features:
	1. Applies a physical VectorForce to HumanoidRootPart to push players back when jumping.
	2. Applies a continuous CFrame displacement of -180 studs/s along World X-axis to simulate wind velocity.
	3. Calculates tunnel X bounds dynamically based on Platform_12 workspace position/size.
	4. Triggers high-frequency camera shake when exposed to the wind.
	5. Modulates a localized howling wind sound dynamically.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local State = require(script.Parent.Parent.HUD.State)
local ZoneLod = require(script.Parent.ZoneLod)

local Zone12WindTunnelController = {}

--[[
	══ CÁNH QUẠT CYBER FAN — chuyển từ SERVER quay sang CLIENT quay (2026-08-27) ════════════

	User: "bẫy ở mọi zone giật giật khi stage đông người, cảm giác như lag mạng". Quạt Zone 12
	là ví dụ thuần khiết nhất của đúng bệnh đó, và nó là cái tệ nhất trong game:

	`Zone12WindTunnelScript` cũ chạy `blades:PivotTo(...)` trên SERVER mỗi Heartbeat, 360°/s,
	VĨNH VIỄN — không cổng ngủ, không LOD, chạy cả khi zone trống và cả khi mọi người đang ở
	lobby. Hệ quả:

	  1. Vị trí cánh quạt phải REPLICATE về từng client. Part neo do script dời KHÔNG được
	     engine nội suy phía client — client nhảy thẳng tới giá trị mới mỗi khi gói tới. Nhịp
	     gói replicate thấp hơn nhịp frame, nên cái người chơi thấy là quạt quay GIẬT theo
	     nhịp mạng, không phải theo nhịp hình.
	  2. Stage đông người ⇒ nhiều gói tranh nhau băng thông ⇒ nhịp đó còn thưa và ĐỀU hơn
	     nữa. Đây chính là "5 người trong stage thì bẫy giật".
	  3. Ping 390ms của user làm mọi thứ tệ hơn một bậc.

	Cách chữa giống hệt Zone 2/3/8/9/11/15: server công bố THAM SỐ (pivot gốc + số vòng/giây)
	đúng một lần, client tự dựng góc từ đồng hồ tất định. 0 byte replicate, quạt mượt tuyệt
	đối, và mọi client thấy cùng một góc.

	⚠️ KHÔNG dùng `PivotTo` ở client dưới StreamingEnabled — part stream về lẻ tẻ tại vị trí
	HOME của server trong lúc model client đã trôi, PivotTo sẽ ghim vĩnh viễn cái offset sai
	đó (đã dính ở sóng Zone 9). Nhớ `rel` NGAY khi part xuất hiện, mỗi frame ghi
	`part.CFrame = pivotNow * rel`.
]]
local FAN_RENDER_RADIUS = 420

type Blade = { part: BasePart, rel: CFrame }

local fanPivot: CFrame? = nil
local fanRPS = 1
local bladesModel: Model? = nil
local blades: { Blade } = {}
local fanAwake = false
local fanNextFar = 0

local function resolveFan()
	table.clear(blades)
	bladesModel = nil

	local zones = Workspace:FindFirstChild("Zones")
	local zone12 = zones and zones:FindFirstChild("Zone12")
	if not zone12 or zone12:GetAttribute("FanReady") ~= true then
		return
	end
	local pivotCF = zone12:GetAttribute("FanPivotCF")
	local rps = zone12:GetAttribute("FanSpinRPS")
	if typeof(pivotCF) ~= "CFrame" or typeof(rps) ~= "number" then
		return
	end
	local ground = zone12:FindFirstChild("Ground")
	local fan = ground and ground:FindFirstChild("CyberFan")
	local model = fan and fan:FindFirstChild("Blades")
	if not model or not model:IsA("Model") then
		return
	end

	fanPivot = pivotCF
	fanRPS = rps
	bladesModel = model
	for _, part in model:GetDescendants() do
		-- `HomeCF` là CFrame BẤT BIẾN do server ghi. KHÔNG đọc `part.CFrame` ở đây: client
		-- đã tự dời part rồi, lấy nhầm là quạt trôi dần mỗi lần re-resolve.
		local home = part:IsA("BasePart") and part:GetAttribute("HomeCF")
		if part:IsA("BasePart") and typeof(home) == "CFrame" then
			table.insert(blades, { part = part, rel = pivotCF:ToObjectSpace(home) })
		end
	end
end

-- Số part cánh ĐÃ stream về. So với `#blades` mỗi vòng poll: `resolveFan()` chạy sớm chỉ bắt
-- được vài cánh, phần stream sau sẽ không bao giờ được quay (đã dính ở Zone 14 + 15).
local function streamedBladeCount(): number
	local model = bladesModel
	if not model or not model:IsDescendantOf(Workspace) then
		return -1
	end
	local n = 0
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("HomeCF") ~= nil then
			n += 1
		end
	end
	return n
end

local function stepFan()
	local pivotCF = fanPivot
	if not pivotCF or #blades == 0 then
		return
	end
	if not blades[1].part:IsDescendantOf(Workspace) then
		return
	end
	if not ZoneLod.Root() then
		return
	end

	local pos = ZoneLod.RootPosition()
	local o = pivotCF.Position
	local dx, dz = pos.X - o.X, pos.Z - o.Z
	local distSq = dx * dx + dz * dz
	if distSq > ZoneLod.RadiusSq(FAN_RENDER_RADIUS) then
		if fanAwake then
			-- Ngủ: trả cánh về đúng tư thế gốc MỘT LẦN. Bỏ qua bước này thì nhìn từ zone
			-- khác sẽ thấy quạt đứng chết cứng ở một góc dở dang, tưởng bẫy hỏng.
			fanAwake = false
			for i = 1, #blades do
				blades[i].part.CFrame = pivotCF * blades[i].rel
			end
		end
		return
	end
	fanAwake = true

	local now = ZoneLod.Now()
	local shouldStep: boolean
	shouldStep, fanNextFar = ZoneLod.ShouldStepFar(distSq, now, fanNextFar)
	if not shouldStep then
		return
	end

	-- Modulo theo CHU KỲ trước khi nhân ra góc: `now` cỡ 1.78e9 nên nhân thẳng rồi đưa vào
	-- CFrame.Angles là góc đóng băng (xem BUG PRECISION trong Zone2Lasers).
	local period = 1 / fanRPS
	local angle = (now % period) / period * math.pi * 2
	local spin = pivotCF * CFrame.Angles(angle, 0, 0)
	for i = 1, #blades do
		blades[i].part.CFrame = spin * blades[i].rel
	end
end

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Constants
local WIND_VELOCITY = 170 -- Wind velocity pushing player back (only WS > 170 can pass!)
local BASE_FORCE = 4500 -- Physical force to push back in air

local activeForce: VectorForce? = nil
local activeAttachment: Attachment? = nil
local windSound: Sound? = nil
local currentExposure = 0 -- Lerps between 0 (outside) and 1 (inside tunnel)

-- Dynamic bounds cached at startup/heartbeat
local cachedMinX = 1660
local cachedMaxX = 1860

local function updateTunnelBounds()
	local zone12 = Workspace:FindFirstChild("Zone12", true)
	local ground = zone12 and zone12:FindFirstChild("Ground")
	local tunnel = ground and ground:FindFirstChild("WindTunnel") :: Model?
	if tunnel then
		local cf, size = tunnel:GetBoundingBox()
		cachedMinX = cf.Position.X - size.X / 2
		cachedMaxX = cf.Position.X + size.X / 2
	end
end

local function cleanupWind()
	if activeForce then
		activeForce:Destroy()
		activeForce = nil
	end
	if activeAttachment then
		activeAttachment:Destroy()
		activeAttachment = nil
	end
	if windSound then
		windSound:Stop()
		windSound:Destroy()
		windSound = nil
	end
	currentExposure = 0
end

local function setupWind(root: BasePart)
	cleanupWind()

	-- Create attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "WindAttachment"
	attachment.Parent = root
	activeAttachment = attachment

	-- Create VectorForce
	local force = Instance.new("VectorForce")
	force.Name = "WindForce"
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.new(0, 0, 0)
	force.Parent = root
	activeForce = force

	-- Create looping Wind Sound
	local sound = Instance.new("Sound")
	sound.Name = "WindTunnelHowl"
	sound.SoundId = "rbxassetid://687874741" -- 180155825 không phải asset Sound (không bao giờ load)
	sound.Volume = 0
	sound.Looped = true
	sound.PlayOnRemove = false
	sound.Parent = SoundService
	sound:Play()
	windSound = sound
end

local function getCharacterMass(char: Model): number
	local mass = 0
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			mass = mass + part:GetMass()
		end
	end
	return mass > 0 and mass or 120
end

function Zone12WindTunnelController.Init()
	updateTunnelBounds()
end

function Zone12WindTunnelController.Start()
	-- Periodic check in case map loads late or shifts
	task.spawn(function()
		while true do
			updateTunnelBounds()
			task.wait(2.0)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local char = localPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if not root or not hum or hum.Health <= 0 then
			cleanupWind()
			return
		end

		local pPos = root.Position
		-- Check if player is inside Stage 12 Wind Tunnel bounds
		local inTunnel = pPos.X >= cachedMinX
			and pPos.X <= cachedMaxX
			and pPos.Y >= 180
			and pPos.Y <= 300
			and pPos.Z >= 2990
			and pPos.Z <= 3070

		if not inTunnel then
			cleanupWind()
			return
		end

		-- Inside tunnel: Ensure VectorForce is set up
		if not activeForce or not activeAttachment or activeAttachment.Parent ~= root then
			setupWind(root)
		end

		-- Wind is continuous inside the tunnel
		local targetExposure = 1
		currentExposure = currentExposure + (targetExposure - currentExposure) * 0.15 -- Smooth transition

		-- 1. Apply CFrame pushback based on wind exposure (World X translation)
		if currentExposure > 0.01 then
			local pushback = -WIND_VELOCITY * currentExposure * dt
			root.CFrame = root.CFrame + Vector3.new(pushback, 0, 0)
		end

		-- 2. Apply physical force (mainly pushes player back in the air when jumping)
		local mass = getCharacterMass(char)
		local forceValue = -BASE_FORCE * (mass / 120) * currentExposure
		if activeForce then
			activeForce.Force = Vector3.new(forceValue, 0, 0)
		end

		-- 3. Camera Shake when exposed
		if currentExposure > 0.05 then
			camera = Workspace.CurrentCamera
			if camera then
				local shakeMultiplier = currentExposure * 0.08
				local shake = Vector3.new(
					math.random(-100, 100) / 1000 * shakeMultiplier,
					math.random(-100, 100) / 1000 * shakeMultiplier,
					math.random(-100, 100) / 1000 * shakeMultiplier
				)
				camera.CFrame = camera.CFrame * CFrame.new(shake)
			end
		end

		-- 4. Modulate looping Wind Sound
		if windSound then
			windSound.Volume = currentExposure * 1.5
			windSound.PlaybackSpeed = 0.85 + currentExposure * 0.45
		end
	end)

	-- Cánh quạt: render cục bộ theo đồng hồ tất định (xem khối lý do ở đầu file).
	RunService.RenderStepped:Connect(stepFan)
	task.spawn(function()
		while true do
			if #blades == 0 or #blades ~= streamedBladeCount() then
				resolveFan()
			end
			task.wait(0.5)
		end
	end)

	Log.Boot("[Zone12WindTunnelController] Client-side Wind Tunnel controller successfully loaded!")
end

return Zone12WindTunnelController
