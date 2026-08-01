--!strict
--[[
	BoostCelebration.luau — hiệu ứng chúc mừng toàn server khi có người mua Server Boost:
	  1. Tin nhắn hệ thống màu neon trong Chat Box.
	  2. Banner lớn giữa màn hình (scale-pop + sunburst xoay).
	  3. Pháo hoa giấy (confetti) rơi đầy màn hình + âm thanh Victory.
	Trigger(playerName, boostName) được HUDController gọi khi nhận packet boostCelebration.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

--[[
	Icon của banner chúc mừng, tra theo TÊN CHÍNH XÁC của món vừa mua.

	Bản cũ dò bằng `string.find` trên tiêu đề nên đụng nhau nghiêm trọng: "PURPLE" khớp cả
	Purple Treadmill LẪN Purple Trail và Purple Aura, "BLUE" khớp cả ba món tên Blue — ai mua
	Purple Trail cũng nhận icon máy chạy bộ. Những món không dính từ khoá nào (Mystic Violet
	Trail, Red Heart Aura, …) thì rơi hết về icon tia sét chung.

	Giờ tra bảng dựng thẳng từ config, nên thêm trail/aura mới là icon tự có, không phải sửa
	file này nữa.
]]
local REBIRTH_ICON = "rbxassetid://97340434418797"
local FROZEN_BLOOM_ICON = "rbxassetid://100884545837490"

-- TÊN VIẾT HOA → icon. Dựng từ CHÍNH các nguồn đang bán món đó, không chép tay số nào:
--   • `Theme.SHOP_CATALOG` — treadmill, VIP, Auto-Rebirth, Infinite Revives, gói Wins…
--   • `Constants.TRAILS` / `AURAS` — field `icon` trong Config/Economy.
--   • `Theme.SPEED_PASS_TIERS` — pass x2/x4/x8 không có icon riêng, dùng icon giày tốc độ.
-- Nhờ vậy thêm món mới vào shop/config là banner tự có icon, không phải sửa file này.
local ICON_BY_NAME: { [string]: string } = {}
do
	for _, tab in Theme.SHOP_CATALOG :: { [string]: { any } } do
		for _, item in tab do
			if item.title and item.icon then
				ICON_BY_NAME[string.upper(item.title)] = item.icon
			end
		end
	end
	for _, catalog in { Constants.TRAILS :: { any }, Constants.AURAS :: { any } } do
		for _, item in catalog do
			if item.icon then
				ICON_BY_NAME[string.upper(item.name)] = item.icon
			end
		end
	end
	-- GamepassService gửi tên dạng "x2 SPEED GAMEPASS" (xem SPEED_PASS_NAMES phía server).
	for _, tier in Theme.SPEED_PASS_TIERS do
		ICON_BY_NAME[string.upper(tier.label) .. " GAMEPASS"] = Theme.UI_ASSETS.Shoe
	end
	-- Frozen Bloom chỉ rơi từ Roulette nên không nằm trong shop lẫn `icon` config.
	ICON_BY_NAME["FROZEN BLOOM"] = FROZEN_BLOOM_ICON
end

local function iconForTitle(title: string): string
	local upper = string.upper(title)

	local exact = ICON_BY_NAME[upper]
	if exact then
		return exact
	end

	-- Rebirth mang số đằng sau ("REBIRTH 7!") nên không tra bảng được.
	if string.find(upper, "REBIRTH") then
		return REBIRTH_ICON
	end

	-- Lưới an toàn: tên có kèm hậu tố (vd "PURPLE TREADMILL X3"). Duyệt để tìm khoá NÀO DÀI
	-- NHẤT khớp — "BLUE TREADMILL" phải thắng "BLUE AURA" khi tiêu đề chứa cả cụm dài hơn.
	local bestIcon, bestLength = nil, 0
	for name, image in ICON_BY_NAME do
		if #name > bestLength and string.find(upper, name, 1, true) then
			bestIcon, bestLength = image, #name
		end
	end
	return bestIcon or Theme.UI_ASSETS.Lightning
end

local BANNER_SECONDS = 4.5
local CONFETTI_COUNT = 46
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 89, 94),
	Color3.fromRGB(255, 202, 58),
	Color3.fromRGB(138, 201, 38),
	Color3.fromRGB(25, 130, 196),
	Color3.fromRGB(106, 76, 147),
	Color3.fromRGB(255, 255, 255),
}

local BoostCelebration = {}

local bannerVisible = Value(false)
local bannerScaleGoal = Value(0)
local bannerScale = Fusion.Tween(bannerScaleGoal, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
local bannerTitle = Value("")
local bannerSubtitle = Value("")
local bannerToken = 0
local currentIsRebirth = Value(false)

local confettiLayer: Frame? = nil
local rng = Random.new()

local function sendChatMessage(playerName: string, boostName: string)
	task.spawn(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			general:DisplaySystemMessage(
				`<font color="#39FF88"><b>[BOOST]</b> Cảm ơn <font color="#FFDD33">{playerName}</font> đã kích hoạt <font color="#66DDFF">{boostName}</font> cho toàn máy chủ!</font>`
			)
		end
	end)
end

local function playVictorySound(isRebirth: boolean)
	local sound = Instance.new("Sound")
	sound.SoundId = if isRebirth then "rbxassetid://4612383790" else Theme.UI_ASSETS.LevelUpSound
	sound.Volume = 0.85
	sound.PlayOnRemove = false
	sound.Parent = confettiLayer
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function spawnConfettiPiece(parent: Frame)
	local size = rng:NextInteger(10, 22)
	local startX = rng:NextInteger(0, Theme.DESIGN_WIDTH)
	local drift = rng:NextInteger(-220, 220)
	local fallTime = rng:NextNumber(2.2, 4.2)

	local piece = Instance.new("Frame")
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.BackgroundColor3 = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
	piece.BorderSizePixel = 0
	piece.Position = UDim2.fromOffset(startX, -40 - rng:NextInteger(0, 240))
	piece.Rotation = rng:NextInteger(0, 360)
	piece.Size = UDim2.fromOffset(size, math.max(6, size // 2))
	piece.ZIndex = 210
	piece.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = piece

	local tween = TweenService:Create(piece, TweenInfo.new(fallTime, Enum.EasingStyle.Linear), {
		Position = UDim2.fromOffset(startX + drift, Theme.DESIGN_HEIGHT + 60),
		Rotation = piece.Rotation + rng:NextInteger(240, 720) * (if rng:NextNumber() < 0.5 then -1 else 1),
	})
	tween.Completed:Once(function()
		piece:Destroy()
	end)
	tween:Play()
end

-- Chớp sáng vàng toàn màn hình (0.5s) — báo hiệu "sự kiện lớn" tức thì cho mọi người.
local function goldenFlash()
	local layer = confettiLayer
	if not layer then
		return
	end
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Color3.fromRGB(255, 225, 120)
	flash.BackgroundTransparency = 0.55
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 206
	flash.Parent = layer

	local tween = TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	tween.Completed:Once(function()
		flash:Destroy()
	end)
	tween:Play()
end

-- ══════════════════════════════════════════════════════════════════════════
-- PHÁO HOA server boost: 10 quả (5 trái + 5 phải), rocket vút lên rồi nổ bung
-- ══════════════════════════════════════════════════════════════════════════

-- Sound pop đã vet trong game (PopIt ProSoundEffects) — pitch thấp = tiếng nổ pháo hoa.
local FIREWORK_POPS = { "rbxassetid://9117848644", "rbxassetid://9119669295", "rbxassetid://9117183955" }
local FIREWORK_PALETTES = {
	{ Color3.fromRGB(255, 224, 92), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 255, 255) },
	{ Color3.fromRGB(92, 220, 255), Color3.fromRGB(70, 120, 255), Color3.fromRGB(255, 255, 255) },
	{ Color3.fromRGB(255, 96, 220), Color3.fromRGB(190, 70, 255), Color3.fromRGB(255, 255, 255) },
	{ Color3.fromRGB(120, 255, 130), Color3.fromRGB(60, 220, 190), Color3.fromRGB(255, 255, 255) },
	{ Color3.fromRGB(255, 110, 90), Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 255, 255) },
}

local lastPopAt = 0
-- Pop 3D positional: gắn vào part tại vị trí nổ — ai gần nghe to, xa nghe nhỏ.
-- 2 tầng: pop sáng + boom bass trầm chồng lên nhau → tiếng nổ "đã" như pháo hoa thật.
local function playFireworkPop(parent: Instance)
	local now = os.clock()
	if now - lastPopAt < 0.08 then
		return
	end
	lastPopAt = now
	local sound = Instance.new("Sound")
	sound.SoundId = FIREWORK_POPS[rng:NextInteger(1, #FIREWORK_POPS)]
	sound.Volume = 1.35
	sound.PlaybackSpeed = rng:NextNumber(0.62, 0.9)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 45
	sound.RollOffMaxDistance = 700
	sound.Parent = parent
	sound:Play()

	local boom = Instance.new("Sound")
	boom.SoundId = FIREWORK_POPS[rng:NextInteger(1, #FIREWORK_POPS)]
	boom.Volume = 1.1
	boom.PlaybackSpeed = rng:NextNumber(0.4, 0.52)
	boom.RollOffMode = Enum.RollOffMode.InverseTapered
	boom.RollOffMinDistance = 45
	boom.RollOffMaxDistance = 700
	boom.Parent = parent
	boom:Play()
end

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- Folder hiệu ứng CLIENT-LOCAL trong Workspace (client tự tạo → không replicate,
-- server không hề biết — nhưng MỌI client đều spawn tại CÙNG toạ độ thế giới).
local fxFolder: Folder? = nil
local function getFxFolder(): Folder
	local existing = fxFolder
	if existing and existing.Parent then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ClientFireworksFX"
	folder.Parent = Workspace
	fxFolder = folder
	return folder
end

-- Tâm bầu trời Lobby: đỉnh Baseplate (mọi client tính ra cùng một điểm).
local function getLobbySkyCenter(): Vector3?
	local lobby = Workspace:FindFirstChild("Lobby")
	local baseplate = lobby and lobby:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		return baseplate.Position + Vector3.new(0, baseplate.Size.Y / 2, 0)
	end
	return nil
end

-- Nổ pháo hoa 3D tại toạ độ thế giới: 80 tia bung cầu + 40 kim tuyến rơi + chớp sáng thật.
local function fireworkBurst3D(position: Vector3, palette: { Color3 })
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.CastShadow = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = CFrame.new(position)
	holder.Parent = getFxFolder()

	-- Quả cầu sáng NỞ BUNG khổng lồ ở tâm — nhìn thấy rực rỡ toàn máy chủ.
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Material = Enum.Material.Neon
	core.Color = palette[1]
	core.Size = Vector3.new(3.5, 3.5, 3.5)
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CastShadow = false
	core.Transparency = 0.02
	core.CFrame = CFrame.new(position)
	core.Parent = holder
	TweenService:Create(core, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(48, 48, 48),
		Transparency = 1,
	}):Play()

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = SPARKLE_TEXTURE
	burst.Color = ColorSequence.new(palette[1], palette[2])
	burst.LightEmission = 1
	burst.LightInfluence = 0
	burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 8.2), NumberSequenceKeypoint.new(1, 0.6) })
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Lifetime = NumberRange.new(2.5, 3.6)
	burst.Speed = NumberRange.new(38, 64)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Acceleration = Vector3.new(0, -28, 0)
	burst.Drag = 1.4
	burst.Rate = 0
	burst.Parent = holder
	burst:Emit(210)

	local glitter = Instance.new("ParticleEmitter")
	glitter.Texture = SPARKLE_TEXTURE
	glitter.Color = ColorSequence.new(palette[3], palette[1])
	glitter.LightEmission = 1
	glitter.LightInfluence = 0
	glitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.8), NumberSequenceKeypoint.new(1, 0) })
	glitter.Lifetime = NumberRange.new(3.0, 4.2)
	glitter.Speed = NumberRange.new(14, 25)
	glitter.SpreadAngle = Vector2.new(180, 180)
	glitter.Acceleration = Vector3.new(0, -16, 0)
	glitter.Drag = 1.1
	glitter.Rate = 0
	glitter.Parent = holder
	-- Tầng 2 (0.5s sau): kim tuyến toả rơi chậm
	task.delay(0.5, function()
		if glitter.Parent then
			glitter:Emit(130)
		end
	end)
	-- Tầng 3 (1.0s sau): crackle trắng nhấp nháy — dư âm pháo hoa thật
	task.delay(1.0, function()
		if not holder.Parent then
			return
		end
		local crackle = Instance.new("ParticleEmitter")
		crackle.Texture = SPARKLE_TEXTURE
		crackle.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), palette[3])
		crackle.LightEmission = 1
		crackle.LightInfluence = 0
		crackle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.0), NumberSequenceKeypoint.new(1, 0) })
		crackle.Lifetime = NumberRange.new(0.6, 1.4)
		crackle.Speed = NumberRange.new(5, 12)
		crackle.SpreadAngle = Vector2.new(180, 180)
		crackle.Acceleration = Vector3.new(0, -12, 0)
		crackle.Rate = 0
		crackle.Parent = holder
		crackle:Emit(60)
	end)

	local light = Instance.new("PointLight")
	light.Brightness = 26
	light.Range = 150
	light.Color = palette[1]
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	}):Play()


	playFireworkPop(holder)
	Debris:AddItem(holder, 7)
end

-- Rocket 3D: part Neon vút lên từ CHÂN màn hình 3D (Transition1To2) rồi nổ bung
-- QUANH màn hình — pháo hoa và màn hình boost là MỘT sân khấu. fromLeft = bên trái màn hình.
local function launchFirework3D(screenCFrame: CFrame, fromLeft: boolean)
	local palette = FIREWORK_PALETTES[rng:NextInteger(1, #FIREWORK_PALETTES)]
	local side = if fromLeft then -1 else 1
	local right = screenCFrame.RightVector
	local forward = screenCFrame.LookVector -- mặt màn hình quay về Lobby
	-- Màn hình treo 74 studs trên mặt Transition → chân sân khấu ≈ mặt sàn.
	local groundBase = screenCFrame.Position - Vector3.new(0, 66, 0)
	local startPos = groundBase
		+ right * (side * rng:NextInteger(26, 78))
		+ forward * rng:NextInteger(6, 34)
	local apex = startPos + Vector3.new(rng:NextInteger(-12, 12), rng:NextInteger(58, 108), rng:NextInteger(-12, 12))

	local rocket = Instance.new("Part")
	rocket.Material = Enum.Material.Neon
	rocket.Color = palette[1]
	rocket.Size = Vector3.new(1.6, 5.5, 1.6)
	rocket.Anchored = true
	rocket.CanCollide = false
	rocket.CanQuery = false
	rocket.CanTouch = false
	rocket.CastShadow = false
	-- Trục Y của part hướng theo đường bay (lookAt trỏ -Z → xoay X 90° đưa Y về hướng đó).
	rocket.CFrame = CFrame.lookAt(startPos, apex) * CFrame.Angles(math.rad(90), 0, 0)
	rocket.Parent = getFxFolder()

	local tail = Instance.new("ParticleEmitter")
	tail.Texture = SPARKLE_TEXTURE
	tail.Color = ColorSequence.new(palette[1], palette[3])
	tail.LightEmission = 1
	tail.LightInfluence = 0
	tail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(1, 0) })
	tail.Lifetime = NumberRange.new(0.3, 0.55)
	tail.Speed = NumberRange.new(4, 8)
	tail.Rate = 110
	tail.EmissionDirection = Enum.NormalId.Bottom
	tail.Parent = rocket

	-- Bay CHẬM rãi lên trời (theo yêu cầu) — Sine cho chuyển động đều, thư thái.
	local ascend = TweenService:Create(rocket, TweenInfo.new(rng:NextNumber(1.7, 2.3), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(apex, apex + (apex - startPos)) * CFrame.Angles(math.rad(90), 0, 0),
	})
	ascend.Completed:Once(function()
		rocket:Destroy()
		fireworkBurst3D(apex, palette)
	end)
	ascend:Play()
end

-- ══════════════════════════════════════════════════════════════════════════
-- MÀN HÌNH 3D server boost: panel SurfaceGui treo trên bầu trời TẠI Transition1To2
-- (cổng vào Zone1) — mọi người trong Lobby nhìn thấy CÙNG một màn hình thế giới.
-- ══════════════════════════════════════════════════════════════════════════

local infoToken = 0
local activeInfo: BasePart? = nil

local function boostAccent(boostName: string): (Color3, Color3)
	local upper = string.upper(boostName)
	if string.find(upper, "WINS") then
		return Color3.fromRGB(130, 255, 140), Color3.fromRGB(40, 200, 120)
	elseif string.find(upper, "MEGA") then
		return Color3.fromRGB(255, 110, 235), Color3.fromRGB(170, 70, 255)
	end
	return Color3.fromRGB(255, 226, 92), Color3.fromRGB(255, 150, 40)
end

-- Vị trí màn hình: trên bầu trời NGAY TRÊN Transition1To2, mặt quay về Lobby.
local function getInfoScreenCFrame(): CFrame?
	local transition = Workspace:FindFirstChild("Transition1To2", true)
	local anchor: Vector3? = nil
	if transition and transition:IsA("BasePart") then
		anchor = transition.Position + Vector3.new(0, 74, 0)
	else
		local center = getLobbySkyCenter()
		anchor = center and (center + Vector3.new(0, 90, 0)) or nil
	end
	if not anchor then
		return nil
	end
	local lookTarget = getLobbySkyCenter() or (anchor - Vector3.new(0, 0, 300))
	-- Mặt Front (-Z) quay về phía Lobby, giữ panel thẳng đứng.
	return CFrame.lookAt(anchor :: Vector3, Vector3.new(lookTarget.X, (anchor :: Vector3).Y, lookTarget.Z))
end

local function makeScreenLabel(parent: Instance, text: string, yScale: number, heightScale: number, color: Color3, maxSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Position = UDim2.fromScale(0.5, yScale)
	label.Size = UDim2.fromScale(0.94, heightScale)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(14, 8, 30)
	stroke.Parent = label
	return label
end

local function showServerBoostInfo(playerName: string, boostName: string)
	local screenCFrame = getInfoScreenCFrame()
	if not screenCFrame then
		return
	end
	infoToken += 1
	local token = infoToken
	if activeInfo then
		activeInfo:Destroy()
		activeInfo = nil
	end

	local accentA, accentB = boostAccent(boostName)
	local FULL_SIZE = Vector3.new(84, 38, 1.4)

	local panel = Instance.new("Part")
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanQuery = false
	panel.CanTouch = false
	panel.CastShadow = false
	panel.Transparency = 1
	panel.Size = Vector3.new(4, 2, 1.4)
	panel.CFrame = screenCFrame
	panel.Parent = getFxFolder()
	activeInfo = panel

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 14
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.MaxDistance = 1200
	gui.Parent = panel

	-- Nền kính tối bo góc + viền neon theo màu boost = "màn hình hologram".
	local container = Instance.new("Frame")
	container.BackgroundColor3 = Color3.fromRGB(16, 10, 36)
	container.BackgroundTransparency = 0.22
	container.BorderSizePixel = 0
	container.Size = UDim2.fromScale(1, 1)
	container.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.06, 0)
	corner.Parent = container
	local stroke = Instance.new("UIStroke")
	stroke.Color = accentA
	stroke.Thickness = 6
	stroke.Transparency = 0.1
	stroke.Parent = container

	local title = makeScreenLabel(container, `⚡ {string.upper(boostName)} ⚡`, 0.07, 0.36, Color3.fromRGB(255, 255, 255), 130)
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accentA),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, accentB),
	})
	titleGradient.Offset = Vector2.new(-1, 0)
	titleGradient.Parent = title
	TweenService:Create(titleGradient, TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
		Offset = Vector2.new(1, 0),
	}):Play()

	makeScreenLabel(container, `🎉 Activated by {playerName} — thank you! 🎉`, 0.5, 0.2, Color3.fromRGB(255, 255, 255), 64)
	makeScreenLabel(container, "ACTIVE FOR THE WHOLE SERVER • 10 MINUTES", 0.75, 0.15, accentA, 46)

	-- Vào: panel nở ra Back easing. Ở lại 10s (lơ lửng nhấp nhô nhẹ). Ra: thu nhỏ + biến mất.
	TweenService:Create(panel, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = FULL_SIZE,
	}):Play()
	local bob = TweenService:Create(panel, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = screenCFrame * CFrame.new(0, 2.4, 0),
	})
	task.delay(0.6, function()
		if token == infoToken and panel.Parent then
			bob:Play()
		end
	end)

	task.delay(10, function()
		if token ~= infoToken or not panel.Parent then
			return
		end
		bob:Cancel()
		local out = TweenService:Create(panel, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.new(3, 1.5, 1.4),
		})
		out.Completed:Once(function()
			if panel == activeInfo then
				activeInfo = nil
			end
			panel:Destroy()
		end)
		out:Play()
	end)
end

local function burstConfetti(isRebirth: boolean)
	local layer = confettiLayer
	if not layer then
		return
	end
	local count = if isRebirth then CONFETTI_COUNT * 2 else CONFETTI_COUNT
	for index = 1, count do
		task.delay((index - 1) * (if isRebirth then 0.02 else 0.035), function()
			if layer.Parent then
				spawnConfettiPiece(layer)
			end
		end)
	end
end

local function showBanner(title: string, subtitle: string)
	local isRebirth = string.find(string.upper(title), "REBIRTH") ~= nil
	currentIsRebirth:set(isRebirth)

	playVictorySound(isRebirth)
	burstConfetti(isRebirth)

	bannerTitle:set(title)
	bannerSubtitle:set(subtitle)
	bannerVisible:set(true)
	bannerScaleGoal:set(1)

	bannerToken += 1
	local token = bannerToken
	task.delay(BANNER_SECONDS, function()
		if token ~= bannerToken then
			return
		end
		bannerScaleGoal:set(0)
		task.delay(0.3, function()
			if token == bannerToken then
				bannerVisible:set(false)
			end
		end)
	end)
end

-- Server boost (3D world edition): hiện trên MỌI client —
--   1. Chớp vàng toàn màn hình (báo hiệu sự kiện lớn tức thì)
--   2. 10 QUẢ PHÁO HOA 3D bắn lên từ chân MÀN HÌNH 3D tại Transition1To2 (5 trái + 5 phải,
--      so le) và nổ bung QUANH màn hình: mỗi client tự spawn tại CÙNG toạ độ thế giới →
--      ai nhìn về cổng Zone 1 đều thấy cùng một sân khấu. Server không replicate gì.
--   3. Màn hình 3D thông tin boost tại cùng vị trí (xuất hiện 1.1s sau loạt pháo đầu)
--   4. Tin nhắn chat neon + nhạc chúc mừng
function BoostCelebration.Trigger(playerName: string, boostName: string)
	sendChatMessage(playerName, boostName)
	playVictorySound(false)
	goldenFlash()

	-- [OPT-25P] Chỉ spawn pháo hoa 3D khi camera trong ~700 studs quanh màn hình
	-- (người đang ở zone xa không thấy được thì không tốn particle).
	local screenCFrame = getInfoScreenCFrame()
	local camera = Workspace.CurrentCamera
	if screenCFrame and camera and (camera.CFrame.Position - screenCFrame.Position).Magnitude < 700 then
		for index = 1, 5 do
			task.delay((index - 1) * 0.55, function()
				launchFirework3D(screenCFrame, true)
			end)
			task.delay((index - 1) * 0.55 + 0.27, function()
				launchFirework3D(screenCFrame, false)
			end)
		end
	end

	task.delay(1.1, function()
		showServerBoostInfo(playerName, boostName)
	end)
end

-- Mua gamepass/treadmill/rebirth thành công: chỉ hiện cho BUYER (kích thích lặp lại hành vi).
function BoostCelebration.TriggerPurchase(itemName: string, subtitle: string?)
	showBanner(itemName, subtitle or "Purchase successful — enjoy your power!")
end

function BoostCelebration.Build()
	-- Lớp confetti phủ toàn canvas (không bắt chuột).
	local layer = New("Frame")({
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		ZIndex = 205,
	}) :: Frame
	confettiLayer = layer

	-- Cấu hình chuẩn Rebirth style (sạch sẽ, căn giữa, kích thước lớn rầm rộ) cho mọi màn ăn mừng
	local bannerSize = UDim2.fromOffset(1150, 450)
	local bannerPosition = UDim2.fromOffset(960, 360)
	local bgTransparency = 1

	local lightningPosition = UDim2.fromOffset(575, 115)
	local lightningSize = UDim2.fromOffset(210, 210)

	local sunburstPosition = UDim2.fromOffset(575, 115)
	local sunburstSize = UDim2.fromOffset(380, 380)

	local titlePosition = UDim2.new(0, 0, 0, 250)
	local titleSize = UDim2.new(1, 0, 0, 95)
	local titleXAlign = Enum.TextXAlignment.Center

	local subtitlePosition = UDim2.new(0, 0, 0, 350)
	local subtitleSize = UDim2.new(1, 0, 0, 65)
	local subtitleXAlign = Enum.TextXAlignment.Center

	local sunburstColor = Computed(function()
		local t = string.upper(bannerTitle:get())
		if string.find(t, "RED ADMIN") then
			return Color3.fromRGB(255, 45, 60)
		elseif string.find(t, "PURPLE") then
			return Color3.fromRGB(210, 80, 255)
		elseif string.find(t, "GOLD") then
			return Color3.fromRGB(255, 215, 0)
		elseif string.find(t, "BLUE") then
			return Color3.fromRGB(50, 210, 255)
		elseif string.find(t, "FROZEN") or string.find(t, "BLOOM") then
			return Color3.fromRGB(80, 240, 255)
		elseif string.find(t, "DARK AURA") then
			return Color3.fromRGB(180, 70, 255)
		elseif string.find(t, "FLAME AURA") then
			return Color3.fromRGB(255, 120, 30)
		elseif string.find(t, "RED HEART") then
			return Color3.fromRGB(255, 50, 90)
		end
		return Color3.fromRGB(255, 222, 89)
	end)

	local sunburstLabel = New("ImageLabel")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = Theme.UI_ASSETS.Sunburst,
		ImageColor3 = sunburstColor,
		ImageTransparency = 0.12, -- Tia sáng đậm nét, nổi bật rực rỡ
		Position = sunburstPosition,
		Size = sunburstSize,
		ZIndex = 210,
	})


	local rotateTween = TweenService:Create(
		sunburstLabel,
		TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 }
	)
	rotateTween:Play()

	local banner = New("CanvasGroup")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(26, 6, 40),
		BackgroundTransparency = bgTransparency,
		GroupTransparency = Computed(function()
			return 1 - bannerScale:get()
		end),
		Position = bannerPosition,
		Size = bannerSize,
		Visible = bannerVisible,
		ZIndex = 208,
		[Children] = {
			New("UIScale")({
				Scale = Computed(function()
					return 0.75 + 0.45 * bannerScale:get()
				end),
			}),

			sunburstLabel,

			New("ImageLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Computed(function()
					return iconForTitle(bannerTitle:get())
				end),


				Position = lightningPosition,
				Size = lightningSize,
				ZIndex = 211,
			}),


			Theme.MakeOutlineLabel({
				Position = titlePosition,
				Size = titleSize,
				Text = Computed(function()
					local t = bannerTitle:get()
					local clean = string.gsub(t, "⭐ ", "")
					clean = string.gsub(clean, "#", "")
					clean = string.gsub(clean, "^🎉%s*", "")
					return `🎉 {clean} 🎉`
				end),
				TextColor3 = Color3.fromRGB(255, 234, 100),
				TextXAlignment = titleXAlign,
				MaxTextSize = 72,
				ZIndex = 211,
			}),

			Theme.MakeOutlineLabel({
				Position = subtitlePosition,
				Size = subtitleSize,
				Text = bannerSubtitle,
				TextColor3 = Color3.fromRGB(190, 255, 220),
				TextXAlignment = subtitleXAlign,
				MaxTextSize = 40,
				ZIndex = 211,
			}),
		},
	})



	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		ZIndex = 205,
		[Children] = {
			layer,
			banner,
		},
	})
end

return BoostCelebration
