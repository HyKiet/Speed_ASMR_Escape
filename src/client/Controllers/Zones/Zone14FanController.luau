--!strict
--[[
	Zone14FanController.luau — QUẠT GIÓ CÔNG NGHIỆP (Stage 14).

	Cơ chế: mỗi cụm quạt (Zone14.Mechanics.Fan1 / Fan2) thổi một luồng gió NGANG cắt qua
	đường chạy. Gió LUÔN thổi; WalkSpeed so với Bảng Chỉ Số Stage (minWS = 218) quyết định
	có trụ nổi hay không:
	  • WS ≥ 218 → chỉ chịu gió nền 30 studs/s: dạt ~16 studs khi băng qua một platform,
	    phải lái người chơi nhưng qua được thoải mái.
	  • WS < 218 → cộng thêm tới 130 studs/s theo mức thiếu chuẩn. WS 150 dạt ~63 studs,
	    vượt nửa bề rộng platform (36) ⇒ bị hất xuống nước → GlobalKillZone lo phần còn lại.

	Client-side có chủ đích (giống Zone12WindTunnelController): HumanoidRootPart do client sở
	hữu physics, đẩy ở server sẽ giật/đàn hồi. Rơi/chết vẫn do server phán quyết.

	Hiệu năng:
	  • Cụm quạt resolve MỘT LẦN (retry khi streaming nạp trễ), cache AABB + trục quay.
	  • Cánh quạt quay bằng CFrame dựng lại từ workspace:GetServerTimeNow() → 0 replication,
	    mọi client thấy cùng pha. Ngoài 260 studs (camera) → ngủ hoàn toàn, không ghi part.
	  • Không AABB nào chứa chân → return sớm, chi phí = 3 phép so sánh hộp.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone14FanController = {}

local GATE_WS = (Stages.STAGE_GATES[14] and Stages.STAGE_GATES[14].minWS) or 218
-- ⚠️ v1 CHỈ đẩy khi thiếu chuẩn ⇒ người chơi đạt trần tốc độ (250 ở Lv120) đi qua Zone 14 mà
-- KHÔNG cảm thấy gì, tưởng cơ chế hỏng. Gió thật thì luôn thổi; tốc độ chỉ quyết định có
-- trụ được hay không. Nên tách làm 2 phần:
--   • NỀN — thổi mọi người, đủ để phải lái người chơi chứ không hất bay.
--   • PHẠT — cộng thêm theo mức thiếu Bảng Chỉ Số, đủ để hất khỏi platform rộng 72 studs.
-- Dạt thực tế ≈ 90% con số lý thuyết (phần còn lại bị ma sát Humanoid ăn). Platform dài 152:
--   WS 250 → qua trong 0.61s, dạt ~16 studs (lái được)
--   WS 150 → qua trong 1.01s, dạt ~63 studs ⇒ vượt nửa bề rộng 36 ⇒ rơi
local WIND_BASE = 30 -- studs/s gió nền, áp cho MỌI tốc độ
local WIND_EXTRA = 130 -- studs/s cộng thêm khi thiếu chuẩn hoàn toàn
local BASE_FORCE = 3200 -- lực đẩy khi đang ở trên không (mass chuẩn 120)
local BLADE_RPS = 0.85 -- vòng/giây của cánh quạt
local REACH = 130 -- tầm gió tính từ mặt quạt (studs)
local SIDE_PAD = 6 -- nới ngang mỗi bên so với dàn quạt
local Y_BELOW, Y_ABOVE = 24, 18 -- vùng gió theo chiều cao so với tâm quạt
local CULL_DIST = 260 -- ngoài tầm này cánh quạt ngừng quay
local CULL_DIST_SQ = CULL_DIST * CULL_DIST
-- ⚠️ 180155825 (bản cũ, copy từ Zone12) KHÔNG phải asset Sound: Studio log
-- "Asset type does not match requested type" mỗi lần vào vùng gió ⇒ Zone 14 chưa bao giờ
-- có tiếng gió. 687874741 là asset gió SpeedWindAudioController vẫn dùng tốt.
local WIND_SOUND_ID = "rbxassetid://687874741"

local localPlayer = Players.LocalPlayer

type Blade = { part: BasePart, rest: CFrame }
type Cluster = {
	minX: number,
	maxX: number,
	minY: number,
	maxY: number,
	minZ: number,
	maxZ: number,
	dir: Vector3, -- hướng thổi (đơn vị, mặt phẳng XZ)
	axis: Vector3, -- trục quay cánh
	hubs: { Vector3 },
	blades: { Blade },
	center: Vector3,
}

local clusters: { Cluster } = {}
local ready = false
local lastFingerprint = -1

local force: VectorForce? = nil
local attachment: Attachment? = nil
local windSound: Sound? = nil
local exposure = 0

local function clearRig()
	if force then
		force:Destroy()
		force = nil
	end
	if attachment then
		attachment:Destroy()
		attachment = nil
	end
	if windSound then
		windSound:Stop()
		windSound:Destroy()
		windSound = nil
	end
	exposure = 0
end

local function buildRig(root: BasePart)
	clearRig()

	local att = Instance.new("Attachment")
	att.Name = "FanWindAttachment"
	att.Parent = root
	attachment = att

	local f = Instance.new("VectorForce")
	f.Name = "FanWindForce"
	f.Attachment0 = att
	f.RelativeTo = Enum.ActuatorRelativeTo.World
	f.Force = Vector3.zero
	f.Parent = root
	force = f

	local s = Instance.new("Sound")
	s.Name = "Zone14FanHowl"
	s.SoundId = WIND_SOUND_ID
	s.Volume = 0
	s.Looped = true
	s.Parent = SoundService
	s:Play()
	windSound = s
end

-- Một cụm = folder chứa N Model "Fan" + 1 Part "WindEffect".
-- Hướng gió lấy từ WindEffect.CFrame.UpVector (đúng EmissionDirection=Top của particle).
local function buildCluster(folder: Instance): Cluster?
	local windEffect = folder:FindFirstChild("WindEffect")
	if not (windEffect and windEffect:IsA("BasePart")) then
		return nil
	end

	local up = windEffect.CFrame.UpVector
	local flat = Vector3.new(up.X, 0, up.Z)
	if flat.Magnitude < 1e-3 then
		return nil
	end
	local dir = flat.Unit

	local blades: { Blade } = {}
	local hubs: { Vector3 } = {}
	local minX, maxX = math.huge, -math.huge
	local fanY = windEffect.Position.Y

	for _, fan in folder:GetChildren() do
		if fan:IsA("Model") then
			local turbine = fan:FindFirstChild("WindTurbine")
			if turbine then
				-- hub = part ngắn nhất; cánh = các part dài (Size.X ~ đường kính)
				local hub: BasePart? = nil
				local longest = 0
				for _, p in turbine:GetChildren() do
					if p:IsA("BasePart") then
						local span = math.max(p.Size.X, p.Size.Y)
						if span > longest then
							longest = span
						end
					end
				end
				local bladeParts: { BasePart } = {}
				for _, p in turbine:GetChildren() do
					if p:IsA("BasePart") then
						if math.max(p.Size.X, p.Size.Y) >= longest * 0.7 then
							table.insert(bladeParts, p)
						elseif hub == nil then
							hub = p
						end
					end
				end
				local pivot = if hub then hub.Position else fan:GetPivot().Position
				table.insert(hubs, pivot)
				for _, p in bladeParts do
					table.insert(blades, { part = p, rest = p.CFrame })
				end
			end
			local cf, size = fan:GetBoundingBox()
			minX = math.min(minX, cf.X - size.X / 2)
			maxX = math.max(maxX, cf.X + size.X / 2)
		end
	end

	if #hubs == 0 then
		return nil
	end

	-- vùng gió: dải ngang trọn dàn quạt, kéo dài REACH studs theo hướng thổi
	local z0 = windEffect.Position.Z
	local zFar = z0 + dir.Z * REACH
	local zLo, zHi = math.min(z0, zFar), math.max(z0, zFar)
	-- gió cũng lệch theo X nếu quạt xoay: nới cả 2 chiều cho an toàn
	local xFar = windEffect.Position.X + dir.X * REACH
	if dir.X < -0.1 then
		minX = math.min(minX, xFar)
	elseif dir.X > 0.1 then
		maxX = math.max(maxX, xFar)
	end

	return {
		minX = minX - SIDE_PAD,
		maxX = maxX + SIDE_PAD,
		minY = fanY - Y_BELOW,
		maxY = fanY + Y_ABOVE,
		minZ = zLo - SIDE_PAD,
		maxZ = zHi + SIDE_PAD,
		dir = dir,
		axis = dir,
		hubs = hubs,
		blades = blades,
		center = Vector3.new((minX + maxX) / 2, fanY, (zLo + zHi) / 2),
	}
end

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone14")
	local mech = zone and zone:FindFirstChild("Mechanics")
	if not mech then
		return false
	end

	local built: { Cluster } = {}
	for _, folder in mech:GetChildren() do
		if folder:IsA("Folder") and folder.Name:match("^Fan%d*$") then
			local c = buildCluster(folder)
			if c then
				table.insert(built, c)
			end
		end
	end
	if #built == 0 then
		return false
	end
	clusters = built
	return true
end

-- DẤU VÂN TAY của dàn quạt đang thực sự nằm trong Workspace: đếm cả part cánh, không chỉ
-- folder. Dưới StreamingEnabled, đi xa rồi quay lại là Roblox DỰNG PART MỚI — cache cũ trỏ
-- vào part mồ côi, ghi CFrame vào đó thì cánh trên màn hình đứng im vĩnh viễn mà không hề
-- báo lỗi. Đếm theo folder không phát hiện được vì số folder không đổi.
local function fanFingerprint(): number
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone14")
	local mech = zone and zone:FindFirstChild("Mechanics")
	if not mech then
		return -1
	end
	local n = 0
	for _, folder in mech:GetChildren() do
		if folder:IsA("Folder") and folder.Name:match("^Fan%d*$") then
			if folder:FindFirstChild("WindEffect") then
				n += 1000
			end
			for _, fan in folder:GetChildren() do
				local turbine = fan:IsA("Model") and fan:FindFirstChild("WindTurbine")
				if turbine then
					n += #turbine:GetChildren()
				end
			end
		end
	end
	return n
end

-- Cache còn sống không? Một part bị stream-out là cả cache hỏng.
local function cacheAlive(): boolean
	for _, c in clusters do
		for _, b in c.blades do
			if not b.part:IsDescendantOf(Workspace) then
				return false
			end
		end
	end
	return true
end

-- QA hook: soi sức gió đang tác dụng lên LocalPlayer từ ngoài (attribute local, không
-- replicate). Throttle 0.4s — chỉ để quan sát, không nằm trong đường nóng.
local lastProbeT = 0
local function setProbe(deficit: number, exp: number)
	local now = os.clock()
	if now - lastProbeT < 0.4 then
		return
	end
	lastProbeT = now
	Workspace:SetAttribute("Z14FanDeficit", math.floor(deficit * 100) / 100)
	Workspace:SetAttribute("Z14FanExposure", math.floor(exp * 100) / 100)
end

local function characterMass(char: Model): number
	local mass = 0
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			mass += p:GetMass()
		end
	end
	return if mass > 0 then mass else 120
end

local function clusterAt(pos: Vector3): Cluster?
	for _, c in clusters do
		if
			pos.X >= c.minX
			and pos.X <= c.maxX
			and pos.Z >= c.minZ
			and pos.Z <= c.maxZ
			and pos.Y >= c.minY
			and pos.Y <= c.maxY
		then
			return c
		end
	end
	return nil
end

local function spinBlades()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local camPos = camera.CFrame.Position
	local angle = (Workspace:GetServerTimeNow() * BLADE_RPS * math.pi * 2) % (math.pi * 2)

	for _, c in clusters do
		local d = camPos - c.center
		if d.X * d.X + d.Y * d.Y + d.Z * d.Z <= CULL_DIST_SQ then
			local spin = CFrame.fromAxisAngle(c.axis, angle)
			for _, b in c.blades do
				-- quay quanh trục quạt đi qua tâm cánh (tâm cánh trùng tâm hub)
				local restPos = b.rest.Position
				b.part.CFrame = CFrame.new(restPos) * spin * CFrame.new(-restPos) * b.rest
			end
		end
	end
end

function Zone14FanController.Start()
	task.spawn(function()
		local lastPrint = -1
		while true do
			local fp = fanFingerprint()
			if not ready or fp ~= lastFingerprint or not cacheAlive() then
				ready = resolve()
				lastFingerprint = if ready then fp else -1
				if ready then
					local blades = 0
					for _, c in clusters do
						blades += #c.blades
					end
					-- chỉ báo khi CẤU HÌNH đổi, không spam mỗi lần stream lại y hệt
					if blades ~= lastPrint then
						lastPrint = blades
						Log.Boot(
							("[Zone14Fan] sẵn sàng — %d cụm quạt, %d cánh, ngưỡng %d WS"):format(
								#clusters,
								blades,
								GATE_WS
							)
						)
					end
				end
			end
			task.wait(1)
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not ready then
			return
		end

		spinBlades()

		local char = localPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum) or hum.Health <= 0 then
			clearRig()
			return
		end

		local cluster = clusterAt(root.Position)
		if not cluster then
			if force or windSound then
				clearRig()
				setProbe(0, 0)
			end
			return
		end

		-- Bảng Chỉ Số Stage: thiếu bao nhiêu thổi thêm bấy nhiêu (gió nền thì ai cũng chịu)
		local deficit = math.clamp(1 - hum.WalkSpeed / GATE_WS, 0, 1)
		local windSpeed = WIND_BASE + WIND_EXTRA * deficit

		if not (force and attachment) or (attachment :: Attachment).Parent ~= root then
			buildRig(root)
		end

		exposure += (1 - exposure) * math.min(dt * 9, 1)

		root.CFrame = root.CFrame + cluster.dir * (windSpeed * exposure * dt)
		if force then
			-- lực vật lý chỉ để hất người đang ở TRÊN KHÔNG (nhảy qua khe giữa 2 platform)
			force.Force = cluster.dir * (BASE_FORCE * (characterMass(char) / 120) * (0.25 + 0.75 * deficit) * exposure)
		end

		if windSound then
			windSound.Volume = exposure * (0.55 + 0.8 * deficit)
			windSound.PlaybackSpeed = 0.9 + 0.35 * deficit
		end

		setProbe(deficit, exposure)

		-- rung máy quay theo sức gió thực nhận
		local shakeAmp = exposure * (0.02 + deficit * 0.08)
		if shakeAmp > 0.004 then
			local camera = Workspace.CurrentCamera
			if camera then
				camera.CFrame = camera.CFrame
					* CFrame.new(
						(math.random() - 0.5) * shakeAmp,
						(math.random() - 0.5) * shakeAmp,
						(math.random() - 0.5) * shakeAmp
					)
			end
		end
	end)
end

function Zone14FanController.Stop()
	clearRig()
end

return Zone14FanController
