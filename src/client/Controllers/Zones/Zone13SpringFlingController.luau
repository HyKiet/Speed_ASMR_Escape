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
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
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
--[[
	SỐ GIỌNG — 3 → 8 (2026-08-12, user: "mấy cổng đầu va vào một lúc sau mới có tiếng,
	tiếng không đồng đều").

	Công thức số giọng cần (giống Keyboard.voices): **số lần phát/giây × độ dài mẫu**.
	Mẫu vỡ kính dài 2.2s. Chạy đủ tốc để phá cổng thì 10 cổng cách nhau 50 studs bị xuyên
	trong khoảng 2.5s ⇒ ~4 lần phát/giây ⇒ cần ~9 giọng. Với 3 giọng thì cổng thứ 4 CƯỚP lại
	giọng của cổng thứ nhất (`TimePosition = 0` + `Play()` = cắt ngang tiếng đang kêu), nên
	tiếng nghe ra lúc có lúc mất chứ không phải "trễ".
]]
local SHATTER_VOICES = 8
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

	--[[
		HÂM GIỌNG — phải TẢI XONG rồi mới hâm (sửa 2026-08-12).

		Bản cũ gọi thẳng `Play()` ngay lúc dựng rig. Nhưng lúc đó asset thường CHƯA TẢI VỀ:
		Play() trên một Sound chưa load không decode được gì cả, nên màn "hâm" hoá ra chạy
		không — và cú Play() thật đầu tiên vẫn phải chờ tải + decode. Đó đúng là triệu chứng
		"cổng đầu tiên đâm vào, một lúc sau mới nghe tiếng".

		`PreloadAsync` YIELD cho tới khi asset thật sự sẵn sàng, nên nó phải nằm trong
		task.spawn (không được chặn Start), và phần hâm phải nằm SAU nó.
	]]
	task.spawn(function()
		local probe = voices3D[1]
		if probe then
			pcall(function()
				ContentProvider:PreloadAsync({ probe })
			end)
		end
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

--[[
	══ THANH ĐO WALKSPEED TRÊN MẶT KÍNH (2026-08-12, yêu cầu user) ═══════════════════════

	Trước đây cổng không nói gì cả: người chơi tông vào, hoặc vỡ hoặc dội ra, và không có cách
	nào biết mình còn thiếu bao nhiêu. Bản v3 cố ý bỏ "thanh máu" (cổng không có HP để bào),
	nhưng bỏ luôn cả phần THÔNG TIN là quá tay — người chơi cần đọc được ngưỡng.

	Thanh này KHÔNG phải máu của cổng: nó là tốc độ CỦA NGƯỜI CHƠI đo trên ngưỡng của cổng.
	Đầy = đủ sức phá. Nhờ vậy nó vừa là chỉ dẫn ("còn thiếu 40") vừa là phần thưởng thị giác
	(chạy nhanh hơn → cả 10 cổng phía trước sáng dần lên).

	Ba điểm kỹ thuật đáng ghi:
	  • SurfaceGui vẫn hiện rõ trên part Transparency 0.45 — GUI không bị độ trong của part
	    ảnh hưởng (khác Highlight, thứ tắt hẳn khi Transparency > 0 — xem KillBlockVisual).
	  • Đặt lên HAI mặt vuông góc trục mỏng của tường (tường 2×16×72 ⇒ mặt Left/Right), để
	    đọc được cả lúc chạy tới lẫn lúc ngoái lại. Tính theo kích thước chứ không viết cứng
	    Left/Right, phòng khi map xoay tường.
	  • CẬP NHẬT THEO SỰ KIỆN, không phải mỗi frame: WalkSpeed trong game này chỉ đổi khi lên
	    cấp / đặt Custom Speed, nên bám `GetPropertyChangedSignal` là đủ và tốn 0 chi phí mỗi
	    khung hình — 10 cổng × 2 mặt = 20 SurfaceGui, quét mỗi frame là lãng phí thuần tuý.
]]
local METER_GUI_NAME = "Zone13SpeedMeter"
local METER_PPS = 12 -- pixel/stud: mặt kính rộng 72 studs ⇒ canvas ~864px
local METER_MAX_DISTANCE = 520

-- Hai mặt vuông góc với trục MỎNG nhất của tường — đó là hai mặt người chơi nhìn thấy.
local function meterFaces(wall: BasePart): { Enum.NormalId }
	local size = wall.Size
	if size.X <= size.Y and size.X <= size.Z then
		return { Enum.NormalId.Right, Enum.NormalId.Left }
	elseif size.Z <= size.X and size.Z <= size.Y then
		return { Enum.NormalId.Front, Enum.NormalId.Back }
	end
	return { Enum.NormalId.Top, Enum.NormalId.Bottom }
end

local function makeLabel(name: string, size: UDim2, position: UDim2, maxTextSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	-- ⚠️ KHÔNG đụng `TextWrapped`: đặt false là tắt luôn TextScaled (bẫy đã dính ở biển Stage).
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxTextSize
	constraint.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(2, maxTextSize * 0.07)
	stroke.Color = Color3.fromRGB(6, 10, 26)
	stroke.Parent = label
	return label
end

-- Dựng một mặt đồng hồ. Trả về 3 phần cần cập nhật sau này.
local function buildMeterGui(wall: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = METER_GUI_NAME
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = METER_PPS
	gui.MaxDistance = METER_MAX_DISTANCE
	gui.LightInfluence = 0 -- luôn đọc được, không phụ thuộc đèn zone
	gui.AlwaysOnTop = false
	gui.ZOffset = 0.2 -- nhích khỏi mặt kính để không z-fight với chính tấm kính
	gui.ResetOnSpawn = false

	-- Tiêu đề: ngưỡng của CỔNG NÀY. Đứng riêng phía trên thanh vì đây là con số người chơi
	-- cần nhớ khi quyết định "quay lại cày thêm hay chạy tiếp".
	local title = makeLabel("Title", UDim2.fromScale(0.7, 0.16), UDim2.fromScale(0.5, 0.3), 96)
	title.TextColor3 = Color3.fromRGB(150, 240, 255)
	title.Parent = gui

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.BackgroundColor3 = Color3.fromRGB(12, 18, 40)
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.Position = UDim2.fromScale(0.5, 0.52)
	track.Size = UDim2.fromScale(0.62, 0.17)
	track.Parent = gui
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0.5, 0)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Thickness = 5
	trackStroke.Color = Color3.fromRGB(120, 220, 255)
	trackStroke.Transparency = 0.25
	trackStroke.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Rotation = 90
	fillGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.3),
	})
	fillGradient.Parent = fill

	-- Con số nằm TRONG thanh: mắt bám thanh, không phải bám chữ.
	local value = makeLabel("Value", UDim2.fromScale(0.96, 0.8), UDim2.fromScale(0.5, 0.5), 74)
	value.Parent = track

	gui.Parent = wall
	return gui, title, fill, value
end

-- Dựng đủ hai mặt, và chỉ dựng mặt còn THIẾU: hàm này chạy lại mỗi lần tag được gắn
-- (streaming trả tường về), nếu dựng vô điều kiện thì mỗi lần vào ra zone là chồng thêm một
-- lớp SurfaceGui nữa lên cùng một mặt.
local function ensureMeter(wall: BasePart)
	for _, face in meterFaces(wall) do
		local found = false
		for _, child in wall:GetChildren() do
			if child:IsA("SurfaceGui") and child.Name == METER_GUI_NAME and child.Face == face then
				found = true
				break
			end
		end
		if not found then
			buildMeterGui(wall, face)
		end
	end
end

-- Vẽ lại đồng hồ của MỘT cổng theo tốc độ hiện tại.
local function refreshMeter(wall: BasePart, speed: number)
	local req = wall:GetAttribute("ReqSpeed")
	local shattered = wall:GetAttribute("Shattered") == true
	for _, child in wall:GetChildren() do
		if child:IsA("SurfaceGui") and child.Name == METER_GUI_NAME then
			-- Cổng đã vỡ thì tắt hẳn: nó sắp biến mất, để lại đồng hồ lơ lửng là rác thị giác.
			-- `ReqSpeed` chưa về (server chưa init xong) cũng tắt — thà không hiện còn hơn hiện 0.
			if shattered or typeof(req) ~= "number" then
				child.Enabled = false
				continue
			end
			child.Enabled = true

			local required = math.max(1, req :: number)
			local ratio = math.clamp(speed / required, 0, 1)
			local enough = speed >= required

			local title = child:FindFirstChild("Title") :: TextLabel?
			local track = child:FindFirstChild("Track") :: Frame?
			local fill = track and track:FindFirstChild("Fill") :: Frame?
			local value = track and track:FindFirstChild("Value") :: TextLabel?

			if title then
				title.Text = if enough then "SMASH!" else `NEED {math.floor(required)}`
				title.TextColor3 = if enough then Color3.fromRGB(150, 255, 190) else Color3.fromRGB(150, 240, 255)
			end
			if fill then
				fill.Size = UDim2.fromScale(ratio, 1)
				-- Ba nấc màu, đọc được bằng đuôi mắt lúc đang chạy: đỏ = còn xa, hổ phách =
				-- gần tới, xanh = qua được. Ngưỡng 0.65 chọn theo thang cổng (mỗi cổng cách
				-- nhau 20 WalkSpeed): dưới mức đó thì người chơi còn thiếu hơn một bậc cổng.
				fill.BackgroundColor3 = if enough
					then Color3.fromRGB(96, 235, 130)
					elseif ratio >= 0.65 then Color3.fromRGB(255, 196, 60)
					else Color3.fromRGB(255, 96, 96)
			end
			if value then
				value.Text = `{math.floor(speed)} / {math.floor(required)}`
			end
		end
	end
end

local function currentWalkSpeed(): number
	local char = localPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	return if humanoid then humanoid.WalkSpeed else 0
end

local function refreshAllMeters()
	local speed = currentWalkSpeed()
	for _, inst in CollectionService:GetTagged("Zone13GlassWall") do
		if inst:IsA("BasePart") then
			refreshMeter(inst, speed)
		end
	end
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
			-- Đồng hồ đi CÙNG một nhịp với va chạm: hai thứ này đọc chung một ngưỡng, tách
			-- nhịp là có lúc thanh báo "SMASH!" mà tường vẫn đặc (hoặc ngược lại).
			refreshMeter(inst, speed)
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

	-- Đồng hồ đo tốc độ trên mặt kính. `ReqSpeed` do script server trong map gán SAU khi
	-- client đã chạy, nên phải bám cả sự kiện đổi attribute — dựng xong mà không nghe thì
	-- đồng hồ đứng im ở trạng thái "chưa có ngưỡng" (tắt) suốt phiên chơi.
	ensureMeter(wall)
	wall:GetAttributeChangedSignal("ReqSpeed"):Connect(function()
		refreshMeter(wall, currentWalkSpeed())
	end)
	wall:GetAttributeChangedSignal("Shattered"):Connect(function()
		refreshMeter(wall, currentWalkSpeed())
	end)
	refreshMeter(wall, currentWalkSpeed())
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
	-- Quét một lần lúc khởi động: tag có thể đã được gắn TRƯỚC khi controller này nạp xong
	-- (thứ tự nạp controller không đảm bảo), khi đó `GetInstanceAddedSignal` không bắn lại.
	refreshAllMeters()
	local walls = #CollectionService:GetTagged("Zone13GlassWall")
	Log.Boot(
		`[Zone13] Cổng Thủy Tinh Cyber v3 (client): shatter + mảnh vỡ 3D + đồng hồ WalkSpeed trên {walls} cổng`
	)
end

return Zone13SpringFlingController
