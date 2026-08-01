--!strict
-- LevelUp: popup ăn mừng lên cấp "cực đỉnh" — chỉ TEXT + ICON, nền trong suốt.
-- Hỗ trợ LEVEL UP LIÊN HOÀN (combo): lên cấp dồn dập trong khung thời gian sẽ cộng dồn combo,
-- escalate màu sắc / kích thước / pitch âm thanh / số hạt → tạo cú hích Dopamine.
-- Dựng imperative (Instance.new + TweenService) để kiểm soát hiệu ứng, giống Toast.ShowSpeedPopup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)

local LevelUp = {}

local localPlayer = Players.LocalPlayer

local COMBO_WINDOW = 1.7 -- giây: lên cấp tiếp trong khung này = nối combo
local BASE_Y_SCALE = 0.16 -- vị trí theo chiều dọc màn hình (Upper Center — tránh đè lên Purchase Celebrations)

-- Bậc combo -> bộ màu. TẤT CẢ đều TƯƠI/SÁNG (không có màu tối) để chữ luôn rõ & đẹp ở mọi combo.
-- Combo vượt số bậc thì xoay vòng (cycle) qua các màu này.
local TIERS = {
	{ a = Color3.fromRGB(255, 238, 140), b = Color3.fromRGB(255, 176, 40), stroke = Color3.fromRGB(95, 45, 0) },
	{ a = Color3.fromRGB(255, 196, 90), b = Color3.fromRGB(255, 110, 28), stroke = Color3.fromRGB(95, 35, 0) },
	{ a = Color3.fromRGB(255, 150, 215), b = Color3.fromRGB(255, 70, 140), stroke = Color3.fromRGB(95, 0, 45) },
	{ a = Color3.fromRGB(130, 235, 255), b = Color3.fromRGB(45, 150, 255), stroke = Color3.fromRGB(0, 35, 90) },
	{ a = Color3.fromRGB(190, 255, 120), b = Color3.fromRGB(90, 220, 60), stroke = Color3.fromRGB(20, 75, 0) },
}

type Session = {
	gui: ScreenGui,
	root: Frame,
	scale: UIScale,
	titleLabel: TextLabel,
	titleGradient: UIGradient,
	titleStroke: UIStroke,
	levelLabel: TextLabel,
	comboLabel: TextLabel,
	sunburst: ImageLabel,
	burstHolder: Frame,
	combo: number,
	token: number,
	targetScale: number,
	fadeTweens: { Tween },
}

local session: Session? = nil

local function getGui(): ScreenGui
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("SpeedEscapeLevelUp")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedEscapeLevelUp"
	gui.DisplayOrder = 200
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	return gui
end

local function makeTextLabel(name: string, size: UDim2, pos: UDim2, textSize: number, strokeThickness: number): (TextLabel, UIStroke)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.ZIndex = 6
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize
	constraint.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = strokeThickness
	stroke.Color = Color3.fromRGB(80, 30, 0)
	stroke.Parent = label
	return label, stroke
end

local function buildSession(): Session
	local gui = getGui()

	local root = Instance.new("Frame")
	root.Name = "Popup"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundTransparency = 1
	root.Position = UDim2.fromScale(0.5, BASE_Y_SCALE)
	root.Size = UDim2.fromOffset(820, 260)
	root.ZIndex = 5
	root.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = root

	-- Sunburst phát sáng phía sau (icon, trong suốt — không phải nền đặc)
	local sunburst = Instance.new("ImageLabel")
	sunburst.Name = "Glow"
	sunburst.AnchorPoint = Vector2.new(0.5, 0.5)
	sunburst.BackgroundTransparency = 1
	sunburst.Image = Theme.UI_ASSETS.Sunburst
	sunburst.ImageColor3 = Color3.fromRGB(255, 220, 120)
	sunburst.ImageTransparency = 0.45
	sunburst.Position = UDim2.fromScale(0.5, 0.46)
	sunburst.Size = UDim2.fromOffset(520, 520)
	sunburst.ZIndex = 1
	sunburst.Parent = root

	-- Icon tia sét hai bên
	for _, x in { 0.12, 0.88 } do
		local bolt = Instance.new("ImageLabel")
		bolt.Name = "Bolt"
		bolt.AnchorPoint = Vector2.new(0.5, 0.5)
		bolt.BackgroundTransparency = 1
		bolt.Image = "rbxassetid://122652751413172"
		bolt.Position = UDim2.fromScale(x, 0.4)
		bolt.Size = UDim2.fromOffset(96, 96)
		bolt.Rotation = if x < 0.5 then -12 else 12
		bolt.ZIndex = 6
		bolt.Parent = root
	end

	local titleLabel, titleStroke = makeTextLabel("Title", UDim2.fromOffset(700, 96), UDim2.fromScale(0.5, 0.34), 76, 4)
	titleLabel.Text = "LEVEL UP!"
	titleLabel.Parent = root
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Rotation = 90
	titleGradient.Parent = titleLabel

	local levelLabel = makeTextLabel("Level", UDim2.fromOffset(520, 70), UDim2.fromScale(0.5, 0.66), 54, 4)
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.Parent = root

	local comboLabel = makeTextLabel("Combo", UDim2.fromOffset(420, 56), UDim2.fromScale(0.5, 0.04), 46, 4)
	comboLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	comboLabel.TextTransparency = 1
	comboLabel.Parent = root

	local burstHolder = Instance.new("Frame")
	burstHolder.Name = "Burst"
	burstHolder.BackgroundTransparency = 1
	burstHolder.Position = UDim2.fromScale(0.5, 0.46)
	burstHolder.Size = UDim2.fromOffset(0, 0)
	burstHolder.ZIndex = 4
	burstHolder.Parent = root

	return {
		gui = gui, root = root, scale = scale,
		titleLabel = titleLabel, titleGradient = titleGradient, titleStroke = titleStroke,
		levelLabel = levelLabel, comboLabel = comboLabel, sunburst = sunburst, burstHolder = burstHolder,
		combo = 0, token = 0, targetScale = 1, fadeTweens = {},
	}
end

local function spawnParticles(s: Session, count: number, hot: boolean)
	for i = 1, count do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(0, 0)
		dot.Rotation = math.random(0, 360)
		dot.BackgroundColor3 = if hot
			then Color3.fromHSV(math.random(), 0.9, 1)
			else Color3.fromRGB(255, math.random(200, 255), math.random(90, 170))
		dot.BorderSizePixel = 0
		dot.ZIndex = 4
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = dot
		dot.Parent = s.burstHolder

		local angle = math.rad((360 / count) * i + math.random(-12, 12))
		local dist = math.random(120, 230)
		local target = UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist)
		local startSize = math.random(14, 26)

		dot.Size = UDim2.fromOffset(startSize, startSize)
		TweenService:Create(dot, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = target,
			Size = UDim2.fromOffset(2, 2),
			Rotation = dot.Rotation + math.random(-160, 160),
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.55, function()
			dot:Destroy()
		end)
	end
end

local function applyTier(s: Session, combo: number)
	-- Xoay vòng qua các màu TƯƠI → chữ luôn sáng rõ, viền tối tương phản. Glow + combo đồng bộ màu.
	local tier = TIERS[((combo - 1) % #TIERS) + 1]
	s.titleGradient.Color = ColorSequence.new(tier.a, tier.b)
	s.titleStroke.Color = tier.stroke
	s.sunburst.ImageColor3 = tier.a
	s.comboLabel.TextColor3 = tier.a
end

-- Huỷ mọi tween fade đang chạy (chống lỗi tween fade ghi đè khi combo nối tiếp).
local function clearFades(s: Session)
	for _, t in s.fadeTweens do
		t:Cancel()
	end
	table.clear(s.fadeTweens)
end

-- Hiện/ẩn TOÀN BỘ độ trong suốt (gồm cả UIStroke) — tránh "chữ rỗng chỉ còn viền".
local function setShown(s: Session, shown: boolean)
	for _, obj in s.root:GetDescendants() do
		if obj:IsA("ImageLabel") then
			obj.ImageTransparency = shown and (if obj == s.sunburst then 0.45 else 0) or 1
		elseif obj:IsA("TextLabel") then
			obj.TextTransparency = shown and 0 or 1
		elseif obj:IsA("UIStroke") then
			obj.Transparency = shown and 0 or 1
		end
	end
end

local function fadeOut(s: Session)
	local token = s.token
	clearFades(s)
	local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local scaleT = TweenService:Create(s.scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	table.insert(s.fadeTweens, scaleT)
	scaleT:Play()
	for _, obj in s.root:GetDescendants() do
		local t: Tween? = nil
		if obj:IsA("ImageLabel") then
			t = TweenService:Create(obj, info, { ImageTransparency = 1 })
		elseif obj:IsA("TextLabel") then
			t = TweenService:Create(obj, info, { TextTransparency = 1 })
		elseif obj:IsA("UIStroke") then
			t = TweenService:Create(obj, info, { Transparency = 1 })
		end
		if t then
			table.insert(s.fadeTweens, t)
			t:Play()
		end
	end
	task.delay(0.36, function()
		if session == s and s.token == token then
			s.root:Destroy()
			session = nil
		end
	end)
end

local function playSound(combo: number)
	local sound = Instance.new("Sound")
	sound.SoundId = Theme.UI_ASSETS.LevelUpSound
	sound.Volume = 0.7
	-- pitch tăng dần theo combo -> cảm giác "leo thang" dopamine
	sound.PlaybackSpeed = math.clamp(1 + (combo - 1) * 0.07, 1, 1.7)
	sound.Parent = localPlayer:WaitForChild("PlayerGui")
	sound:Play()
	task.delay(2.2, function()
		sound:Destroy()
	end)
end

-- Gọi mỗi lần lên cấp. level = cấp mới, levelsGained = số cấp tăng trong lần này.
function LevelUp.Trigger(level: number, levelsGained: number)
	local s = session
	if not s then
		s = buildSession()
		session = s
	end
	s = s :: Session
	s.combo += 1
	s.token += 1
	local combo = s.combo
	local token = s.token
	s.targetScale = State.viewportScale:get()

	-- QUAN TRỌNG: huỷ fade cũ + hiện rõ TẤT CẢ (gồm UIStroke) trước khi vẽ lại →
	-- chống lỗi "chữ rỗng chỉ còn viền tối" khi combo nối tiếp lúc đang fade.
	clearFades(s)
	setShown(s, true)

	-- Cập nhật text
	s.titleLabel.Text = "LEVEL UP!"
	local gainSuffix = if levelsGained > 1 then `  (+{levelsGained})` else ""
	s.levelLabel.Text = `LEVEL {level}{gainSuffix}`
	applyTier(s, combo)

	-- Combo label (>=2 mới hiện) — ẩn/hiện CẢ viền UIStroke.
	local comboStroke = s.comboLabel:FindFirstChildOfClass("UIStroke")
	if combo >= 2 then
		s.comboLabel.Text = `🔥 COMBO x{combo}`
		s.comboLabel.TextTransparency = 0
		if comboStroke then comboStroke.Transparency = 0 end
		local cs = s.comboLabel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", s.comboLabel)
		cs.Scale = 1.6
		TweenService:Create(cs, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		s.comboLabel.TextTransparency = 1
		if comboStroke then comboStroke.Transparency = 1 end
	end

	-- POP: phóng to giật theo kiểu Back (re-punch mỗi hit), kèm wobble xoay
	local punchFrom = combo == 1 and 0 or s.targetScale * 0.72
	s.scale.Scale = punchFrom
	TweenService:Create(s.scale, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = s.targetScale }):Play()
	s.root.Rotation = (combo % 2 == 0) and 4 or -4
	TweenService:Create(s.root, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()

	-- Sunburst: pulse + xoay
	s.sunburst.Size = UDim2.fromOffset(360, 360)
	TweenService:Create(s.sunburst, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(540 + combo * 14, 540 + combo * 14),
	}):Play()
	TweenService:Create(s.sunburst, TweenInfo.new(2.2, Enum.EasingStyle.Linear), { Rotation = s.sunburst.Rotation + 90 }):Play()

	spawnParticles(s, math.clamp(10 + combo * 3, 10, 34), combo >= 6)
	playSound(combo)

	-- Hết khung combo -> fade out + reset
	task.delay(COMBO_WINDOW, function()
		if session == s and s.token == token then
			fadeOut(s)
			if session == s then
				s.combo = 0
			end
		end
	end)
end

return LevelUp
