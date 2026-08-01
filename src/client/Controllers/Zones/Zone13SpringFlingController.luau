--!strict
--[[
	Zone13SpringFlingController.luau — Cổng Thủy Tinh Cyber (v3)

	Bỏ hoàn toàn thanh máu. Đủ WalkSpeed → đâm vỡ tan cổng và chạy thẳng qua.

	Client làm gì:
	  • Tắt CanCollide CỤC BỘ với những cổng mình đủ sức phá → không bị khựng lại,
	    cảm giác "xuyên qua" mượt. Cổng chưa đủ tốc độ vẫn đặc cứng.
	  • Báo server khi chạm (server tự duyệt WalkSpeed thật — xem Zone13 inline script).
	  • Nhận packet glassShattered → dựng hàng chục mảnh kính 3D văng theo hướng chạy,
	    kèm chùm tia sáng lóe và SFX vỡ kính đanh giòn.

	Zero-GC: mảnh vỡ lấy từ POOL tái sử dụng, không Instance.new mỗi lần vỡ.
	Đổi SFX qua attribute `ShatterSoundId` trên Workspace.Zones.Zone13.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local GamePackets =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("GamePackets"))

-- Pro Sound Effects "Glass Breaks 11" — vỡ kính đanh giòn, 2.2s, free.
-- (ID cũ 9120380327 KHÔNG phải asset Audio nên SFX bản trước im lặng.)
local DEFAULT_SHATTER_SOUND = "rbxassetid://9114592102"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local ROWS, COLS = 5, 7 -- 35 mảnh mỗi cổng
local POOL_SIZE = ROWS * COLS * 2 -- đủ cho 2 cổng vỡ chồng nhau
local DEBRIS_LIFETIME = 1.5
local TOUCH_COOLDOWN = 0.35

-- SFX vỡ kính — v3.1 (2026-07-28), sửa bug "tông vào cổng mà không nghe tiếng vỡ".
-- Ba thứ cộng lại làm tiếng biến mất dù asset hợp lệ và :Play() có chạy:
--   1) Sound 3D neo tại ĐIỂM VA CHẠM, mà người phá đang ở 200+ studs/s ⇒ chỉ vài chục ms
--      sau khi kêu, khoảng cách đã vượt RollOffMinDistance rất xa, tiếng còn lại rất khẽ
--      và nằm phía SAU lưng.
--   2) Lần Play() đầu tiên phải decode ⇒ đúng cửa đầu tiên (cửa người chơi để ý nhất) là
--      cửa im lặng nhất.
--   3) Chỉ có MỘT Sound: 12 cổng đứng sát nhau, phá liên tiếp thì cửa sau :Play() lại từ
--      đầu, cắt cụt tiếng cửa trước → nghe như không có gì.
-- Cách sửa: cổng do CHÍNH mình phá phát bằng giọng 2D (Parent = SoundService, không suy
-- giảm theo khoảng cách, không lệ thuộc vị trí), cổng của người khác vẫn phát 3D tại rig.
-- Cả hai đều có nhiều giọng và được hâm câm lúc Start.
local SHATTER_VOICES = 3
local NEAR_SHATTER_DISTANCE = 150 -- trong tầm này coi như "mình phá" → phát 2D

local Zone13SpringFlingController = {}

local localPlayer = Players.LocalPlayer

local pool: { BasePart } = {}
local poolCursor = 0
local sparkleRig: Part? = nil
local sparkleEmitter: ParticleEmitter? = nil
local voices3D: { Sound } = {}
local voices2D: { Sound } = {}
local voiceCursor = 0
local lastTouch: { [string]: number } = {}

local function shatterSoundId(): string
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone13")
	local custom = zone and zone:GetAttribute("ShatterSoundId")
	return typeof(custom) == "string" and custom or DEFAULT_SHATTER_SOUND
end

-- Phát tiếng vỡ tại `hit`. Gần người chơi → giọng 2D (nghe rõ, không tắt dần khi lao đi).
local function playShatter(hit: Vector3)
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local near = root and root:IsA("BasePart") and (root.Position - hit).Magnitude <= NEAR_SHATTER_DISTANCE

	voiceCursor = voiceCursor % SHATTER_VOICES + 1
	local sound = near and voices2D[voiceCursor] or voices3D[voiceCursor]
	if not sound then
		return
	end
	sound.Volume = near and 0.9 or 1.5
	sound.TimePosition = 0
	sound:Play()
end

local function ensureRigs()
	if sparkleRig then
		return
	end

	local rig = Instance.new("Part")
	rig.Name = "Zone13ShatterRig"
	rig.Anchored = true
	rig.CanCollide = false
	rig.CanQuery = false
	rig.CanTouch = false
	rig.Transparency = 1
	rig.Size = Vector3.one

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "GlassSparkle"
	sparkle.Texture = SPARKLE_TEXTURE
	sparkle.Color = ColorSequence.new(Color3.fromRGB(190, 240, 255), Color3.fromRGB(255, 255, 255))
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkle.Size = NumberSequence.new(3.2, 0)
	sparkle.Rate = 0
	sparkle.Lifetime = NumberRange.new(0.3, 0.75)
	sparkle.Speed = NumberRange.new(45, 105)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Acceleration = Vector3.new(0, -90, 0)
	sparkle.Parent = rig

	local soundId = shatterSoundId()
	for i = 1, SHATTER_VOICES do
		local s3 = Instance.new("Sound")
		s3.Name = "GlassShatter3D_" .. i
		s3.SoundId = soundId
		s3.Volume = 1.5
		s3.RollOffMaxDistance = 400
		s3.RollOffMinDistance = 60
		s3.Parent = rig
		table.insert(voices3D, s3)

		local s2 = Instance.new("Sound")
		s2.Name = "GlassShatter2D_" .. i
		s2.SoundId = soundId
		s2.Volume = 0.9
		s2.Parent = SoundService -- Parent = SoundService ⇒ 2D, không suy giảm theo khoảng cách
		table.insert(voices2D, s2)
	end

	rig.Parent = Workspace
	sparkleRig, sparkleEmitter = rig, sparkle

	-- HÂM: lần Play() đầu của mỗi Sound phải decode. Chạy câm ngay lúc load để cổng
	-- ĐẦU TIÊN người chơi phá đã kêu đúng nhịp.
	task.spawn(function()
		for _, s in voices3D do
			s.Volume = 0
			s:Play()
		end
		for _, s in voices2D do
			s.Volume = 0
			s:Play()
		end
		task.wait(0.15)
		for _, s in voices3D do
			s:Stop()
			s.Volume = 1.5
		end
		for _, s in voices2D do
			s:Stop()
			s.Volume = 0.9
		end
	end)

	for _ = 1, POOL_SIZE do
		local chunk = Instance.new("Part")
		chunk.Name = "GlassFragment"
		chunk.Material = Enum.Material.Glass
		chunk.Transparency = 1
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CastShadow = false
		chunk.Anchored = true
		chunk.Parent = Workspace
		table.insert(pool, chunk)
	end
end

local function spawnDebris(wall: BasePart, dir: Vector3, speed: number)
	local size = wall.Size
	local wallCF = wall.CFrame
	local chunkH = size.Y / ROWS
	local chunkW = size.Z / COLS
	-- Càng nhanh mảnh văng càng xa, nhưng chặn trần để không bay khỏi map.
	local push = math.clamp(speed * 0.55, 45, 160)

	for r = 1, ROWS do
		for c = 1, COLS do
			poolCursor = poolCursor % #pool + 1
			local chunk = pool[poolCursor]

			local localY = -size.Y / 2 + (r - 0.5) * chunkH
			local localZ = -size.Z / 2 + (c - 0.5) * chunkW

			chunk.Anchored = true
			chunk.Size =
				Vector3.new(size.X, chunkH * (0.78 + math.random() * 0.36), chunkW * (0.78 + math.random() * 0.36))
			chunk.CFrame = wallCF * CFrame.new(0, localY, localZ)
			chunk.Color = wall.Color
			chunk.Transparency = 0.35
			chunk.Anchored = false

			chunk.AssemblyLinearVelocity = dir * (push * (0.65 + math.random() * 0.7))
				+ Vector3.new(0, math.random(12, 52), 0)
				+ Vector3.new(-dir.Z, 0, dir.X) * (math.random(-30, 30))
			chunk.AssemblyAngularVelocity =
				Vector3.new(math.random(-24, 24), math.random(-24, 24), math.random(-24, 24))
		end
	end

	task.delay(DEBRIS_LIFETIME, function()
		-- Trả mảnh về pool: neo lại + ẩn, KHÔNG Destroy (tránh rác GC).
		for _, chunk in pool do
			if chunk.Transparency < 1 then
				chunk.Anchored = true
				chunk.Transparency = 1
				chunk.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end)
end

-- Cổng nào mình đủ sức phá thì cho đi xuyên cục bộ, khỏi khựng.
local function updateLocalCollisions()
	local char = localPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local speed = humanoid.WalkSpeed
	for _, inst in CollectionService:GetTagged("Zone13GlassWall") do
		if inst:IsA("BasePart") then
			local req = inst:GetAttribute("ReqSpeed")
			local shattered = inst:GetAttribute("Shattered") == true
			inst.CanCollide = not (shattered or (typeof(req) == "number" and speed >= req))
		end
	end
end

local function setupWall(wall: BasePart)
	wall.Touched:Connect(function(hit)
		local char = localPlayer.Character
		if not char or not hit:IsDescendantOf(char) then
			return
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local req = wall:GetAttribute("ReqSpeed")
		if not humanoid or humanoid.Health <= 0 or typeof(req) ~= "number" then
			return
		end
		if wall:GetAttribute("Shattered") == true or humanoid.WalkSpeed < req then
			return
		end

		local now = os.clock()
		if now - (lastTouch[wall.Name] or 0) < TOUCH_COOLDOWN then
			return
		end
		lastTouch[wall.Name] = now

		GamePackets.requestGlassSmash.send({ wallName = wall.Name })
	end)

	wall:GetAttributeChangedSignal("Shattered"):Connect(updateLocalCollisions)
end

function Zone13SpringFlingController.Init()
	GamePackets.glassShattered.listen(function(data)
		ensureRigs()

		local zones = Workspace:FindFirstChild("Zones")
		local zone13 = zones and zones:FindFirstChild("Zone13")
		local ground = zone13 and zone13:FindFirstChild("Ground")
		local wall = ground and ground:FindFirstChild(data.wallName)

		local hit = Vector3.new(data.hitX, data.hitY, data.hitZ)
		local dir = Vector3.new(data.dirX, 0, data.dirZ)
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.xAxis

		if sparkleRig then
			sparkleRig.Position = hit
		end
		if sparkleEmitter then
			sparkleEmitter:Emit(70)
		end
		playShatter(hit)
		if wall and wall:IsA("BasePart") then
			spawnDebris(wall, dir, data.speed)
		end

		updateLocalCollisions()
	end)

	for _, inst in CollectionService:GetTagged("Zone13GlassWall") do
		if inst:IsA("BasePart") then
			setupWall(inst)
		end
	end
	CollectionService:GetInstanceAddedSignal("Zone13GlassWall"):Connect(function(inst)
		if inst:IsA("BasePart") then
			setupWall(inst)
			updateLocalCollisions()
		end
	end)

	local function bindCharacter(char: Model)
		local humanoid = char:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(updateLocalCollisions)
			updateLocalCollisions()
		end
	end
	localPlayer.CharacterAdded:Connect(bindCharacter)
	if localPlayer.Character then
		bindCharacter(localPlayer.Character)
	end
end

function Zone13SpringFlingController.Start()
	ensureRigs()
	print("[Zone13] Cổng Thủy Tinh Cyber v3 (client): shatter + mảnh vỡ 3D, không thanh máu")
end

return Zone13SpringFlingController
