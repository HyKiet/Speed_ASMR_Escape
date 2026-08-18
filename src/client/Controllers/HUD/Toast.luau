--!strict
-- Toast text, Level-up popup, fixed-screen "+Speed" popup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.State)
local Theme = require(script.Parent.Theme)
local Tokens = require(script.Parent.Tokens)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New

local Toast = {}

local localPlayer = Players.LocalPlayer

local function getSpeedPopupGui(): ScreenGui
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("SpeedEscapeSpeedPopups")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedEscapeSpeedPopups"
	--[[
		⚠️ DisplayOrder ÂM là cố ý (2026-08-10, user): popup "+340 🥿" bám theo nhân vật là thứ
		VUI nhưng KHÔNG QUAN TRỌNG — trước để 80 nên nó nổi trên cả modal Shop, che mất đúng
		mấy tấm thẻ đang bán hàng. Dưới 0 thì nó chui xuống dưới toàn bộ HUD/modal: chỗ nào
		màn hình trống vẫn thấy, mở panel lên là tự nhường chỗ.
	]]
	gui.DisplayOrder = -1
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	return gui
end

-- ── Notification toast v2: pill pop-in + icon + ÂM THANH; success sparkle / error shake ──
type KindStyle = { accent: Color3, icon: string, sound: string }
local KIND_STYLE: { [string]: KindStyle } = {
	success = { accent = Color3.fromRGB(88, 235, 120), icon = "✓", sound = "success" },
	error = { accent = Color3.fromRGB(255, 92, 92), icon = "X", sound = "error" },
	pad = { accent = Color3.fromRGB(96, 224, 110), icon = "▲", sound = "pop" },
	teleport = { accent = Color3.fromRGB(86, 200, 255), icon = "◆", sound = "pop" },
	treadmill = { accent = Color3.fromRGB(255, 176, 64), icon = "⚡", sound = "pop" },
	stage = { accent = Color3.fromRGB(255, 210, 80), icon = "★", sound = "success" },
	revive = { accent = Color3.fromRGB(255, 110, 110), icon = "!", sound = "error" },
	code = { accent = Color3.fromRGB(104, 234, 120), icon = "★", sound = "success" },
	cosmetic = { accent = Color3.fromRGB(214, 130, 255), icon = "★", sound = "success" },
}
local DEFAULT_STYLE: KindStyle = { accent = Color3.fromRGB(255, 210, 80), icon = "★", sound = "pop" }

-- Server gửi message với kind theo HỆ THỐNG (treadmill/pad/...) — tự nhận diện thêm
-- sắc thái tích cực/tiêu cực từ nội dung để chọn nhạc + hiệu ứng phù hợp.
local POSITIVE_PATTERNS = { "unlocked", "redeemed", "collected", "success", "claimed", "granted" }
local NEGATIVE_PATTERNS = {
	"not enough",
	"need ",
	"unlock pad",
	"purchase this",
	"failed",
	"invalid",
	"expired",
	"cooldown",
	"locked",
	"cannot",
	"can't",
	-- Lời từ chối của bệ nhận Wins (`StageCheckpointService.denyPad`). Chúng đi kèm kind
	-- `stage` nên nếu không bắt tường minh ở đây, chúng rơi vào nhánh tích cực và hiện ra
	-- như một tin mừng — trong khi người chơi vừa bị chặn không cho nhận thưởng.
	"too fast",
	"run the stage",
	"run stage",
}

local function resolveStyle(text: string, kind: string?): (KindStyle, string)
	local style = KIND_STYLE[kind or ""] or DEFAULT_STYLE
	local lower = string.lower(text)
	-- Xét TÍCH CỰC trước: "unlocked" chứa chuỗi con "locked" — xét negative trước sẽ nhầm.
	for _, pattern in POSITIVE_PATTERNS do
		if string.find(lower, pattern, 1, true) then
			-- Giữ màu/icon theo hệ thống nhưng dùng nhạc chúc mừng.
			return { accent = style.accent, icon = style.icon, sound = "success" }, "success"
		end
	end
	for _, pattern in NEGATIVE_PATTERNS do
		if string.find(lower, pattern, 1, true) then
			return KIND_STYLE.error, "error"
		end
	end
	return style, style.sound
end

local lastToastSoundAt = 0
local function playToastSound(gui: ScreenGui, preset: string)
	local now = os.clock()
	if now - lastToastSoundAt < 0.15 then
		return
	end
	lastToastSoundAt = now

	local function spawnSound(id: string, volume: number, speed: number, delaySeconds: number?)
		task.delay(delaySeconds or 0, function()
			local sound = Instance.new("Sound")
			sound.SoundId = id
			sound.Volume = volume
			sound.PlaybackSpeed = speed
			sound.Parent = gui
			sound:Play()
			task.delay(2.5, function()
				sound:Destroy()
			end)
		end)
	end

	--[[
		⚠️ TOAST KHÔNG DÙNG ÂM CHÚC MỪNG (2026-08-12, user).

		Toast là kênh THÔNG BÁO HỆ THỐNG: nó báo "đã nhận", "không đủ Wins", "chạy lại stage
		cho tử tế". Bản trước gán `CelebrationSound` cho preset success, nên một lời TỪ CHỐI
		như "Too fast — run the stage properly" (kind `stage` ⇒ preset success) lại kêu đúng
		tiếng ăn mừng rebirth. Người chơi nghe tiếng thắng trong lúc bị chặn thưởng.

		Âm chúc mừng chỉ thuộc về các hệ thống ĂN MỪNG THẬT (banner rebirth/boost, thẻ Wins
		bay, mở pad, trúng roulette, pháo hoa cuối zone). Toast dùng một tiếng chuông ngắn,
		trung tính — 9120150515 (Tone Clusters 23, 0.40s, đã đo IsLoaded=true).
	]]
	if preset == "success" then
		spawnSound(Theme.UI_ASSETS.NotifySound, 0.45, 1.0)
	elseif preset == "error" then
		-- Double-thud trầm = "denied" cổ điển (tái dùng ClickSound pitch thấp, không cần asset mới).
		spawnSound(Theme.UI_ASSETS.ClickSound, 0.75, 0.42)
		spawnSound(Theme.UI_ASSETS.ClickSound, 0.75, 0.34, 0.09)
	else
		spawnSound(Theme.UI_ASSETS.ClickSound, 0.4, 1.2)
	end
end

local activeToast: Instance? = nil
local toastToken = 0

local function getToastGui(): ScreenGui
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("SpeedEscapeToasts")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedEscapeToasts"
	gui.DisplayOrder = 999 -- Neo trên cùng tuyệt đối của mọi UI khác
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	return gui
end

-- Tia sáng bung ra từ pill khi thành công (8 ngôi sao nhỏ).
local function burstSparkles(gui: ScreenGui, centerX: number, centerY: number, accent: Color3)
	for index = 1, 8 do
		local angle = (index / 8) * math.pi * 2 + math.random() * 0.6
		local distance = 55 + math.random(0, 35)
		local star = Instance.new("TextLabel")
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.BackgroundTransparency = 1
		star.Font = Theme.FONT
		star.Text = "★"
		star.TextColor3 = accent

		star.TextSize = 20
		star.Position = UDim2.fromOffset(centerX, centerY)
		star.ZIndex = 10000
		star.Parent = gui
		local tween = TweenService:Create(star, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(centerX + math.cos(angle) * distance, centerY + math.sin(angle) * distance),
			TextTransparency = 1,
			TextSize = 8,
		})
		tween.Completed:Once(function()
			star:Destroy()
		end)
		tween:Play()
	end
end

-- Rung lắc pill khi báo lỗi.
local function shakeToast(pill: GuiObject)
	task.spawn(function()
		for _, rotation in { -5, 5, -3, 3, 0 } do
			if not pill.Parent then
				return
			end
			TweenService:Create(pill, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Rotation = rotation,
			}):Play()
			task.wait(0.05)
		end
	end)
end

function Toast.Show(text: string, kind: string?)
	if text == "" then
		return
	end
	toastToken += 1
	local token = toastToken
	if activeToast then
		activeToast:Destroy()
		activeToast = nil
	end

	local gui = getToastGui()
	local style, soundPreset = resolveStyle(text, kind)

	--[[
		⚠️ TOAST PHẢI CO THEO MÀN HÌNH (2026-08-14, user: "UI thông báo hệ thống đang bị rất to").

		Pill này dựng bằng PIXEL MÀN HÌNH THẬT (ScreenGui riêng, không nằm trong canvas
		1920×1080 nên không có UIScale) và dùng `AutomaticSize`, tức chiều cao do cỡ chữ +
		padding quyết định. Cỡ chữ cứng 26 + padding 12 cho ra pill cao ~62px: trên PC 1080 là
		6% màn hình, nhưng trên điện thoại cao 413 thì vẫn 62px = 15% — dải thông báo to bằng
		một phần bảy màn hình và che mất chỗ đang chơi.

		`k` co mọi con số theo chiều cao màn hình. Ở 1080 nó = 1 ⇒ PC không đổi một pixel nào.
		Sàn 0.5 để chữ không bao giờ nhỏ hơn 13px thật.
	]]
	local toastK = math.clamp(gui.AbsoluteSize.Y / 1080, 0.5, 1)
	local function k(value: number): number
		return math.round(value * toastK)
	end

	-- Pill bo tròn giữa mép trên: pop-in Back easing, viền màu hệ thống, icon + text outline.
	-- LƯU Ý: KHÔNG dùng CanvasGroup + AutomaticSize (bug engine: canvas không resize → con
	-- không render). Dùng Frame thường, fade-out tween từng phần tử.
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.BackgroundColor3 = Color3.fromRGB(20, 15, 38)
	pill.BackgroundTransparency = 0.06
	pill.BorderSizePixel = 0
	pill.Position = UDim2.new(0.5, 0, 0, k(26))
	pill.ZIndex = 9999
	pill.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, k(16))
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color = style.accent
	stroke.Thickness = 2.5
	stroke.Transparency = 0.1
	stroke.Parent = pill

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(48, 36, 92), Color3.fromRGB(16, 12, 32))
	gradient.Rotation = 90
	gradient.Parent = pill

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, k(12))
	padding.PaddingBottom = UDim.new(0, k(12))
	padding.PaddingLeft = UDim.new(0, k(20))
	padding.PaddingRight = UDim.new(0, k(22))
	padding.Parent = pill

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, k(12))
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pill

	local iconLabel = Instance.new("TextLabel")
	iconLabel.AutomaticSize = Enum.AutomaticSize.XY
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Theme.FONT
	iconLabel.Text = style.icon
	iconLabel.TextColor3 = style.accent
	iconLabel.TextSize = k(22)
	iconLabel.LayoutOrder = 1
	iconLabel.ZIndex = 10000
	iconLabel.Parent = pill

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Thickness = 2
	iconStroke.Color = Color3.fromRGB(10, 8, 20)
	iconStroke.Parent = iconLabel

	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundTransparency = 1
	label.Font = Theme.FONT
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = k(26)
	label.LayoutOrder = 2
	label.ZIndex = 10000
	label.Parent = pill
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Thickness = 2.2
	labelStroke.Color = Color3.fromRGB(10, 8, 20)
	labelStroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = pill

	activeToast = pill

	playToastSound(gui, soundPreset)
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()

	if soundPreset == "error" then
		shakeToast(pill)
	elseif soundPreset == "success" then
		task.delay(0.16, function()
			if pill.Parent then
				local absolutePosition = pill.AbsolutePosition
				local absoluteSize = pill.AbsoluteSize
				burstSparkles(
					gui,
					absolutePosition.X + absoluteSize.X / 2,
					absolutePosition.Y + absoluteSize.Y / 2,
					style.accent
				)
			end
		end)
	end

	task.delay(2.6, function()
		if toastToken ~= token or not pill.Parent then
			return
		end
		local outInfo = TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(pill, outInfo, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stroke, outInfo, { Transparency = 1 }):Play()
		TweenService:Create(iconLabel, outInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(iconStroke, outInfo, { Transparency = 1 }):Play()
		TweenService:Create(label, outInfo, { TextTransparency = 1 }):Play()
		TweenService:Create(labelStroke, outInfo, { Transparency = 1 }):Play()
		TweenService:Create(scale, outInfo, { Scale = 0.82 }):Play()
		task.delay(0.3, function()
			if pill == activeToast then
				activeToast = nil
			end
			pill:Destroy()
		end)
	end)
end

-- API tường minh cho code mới (server có thể gửi kind="success"/"error").
function Toast.Success(text: string)
	Toast.Show(text, "success")
end

function Toast.Error(text: string)
	Toast.Show(text, "error")
end

function Toast.ShowLevelUp(level: number, levelsGained: number)
	local suffix = if levelsGained > 1 then ` +{levelsGained} LEVELS` else ""
	local label = `LEVEL UP! LEVEL {level}{suffix}`
	State.levelUpText:set(label)

	local sound = Instance.new("Sound")
	sound.SoundId = Theme.UI_ASSETS.LevelUpSound
	sound.Volume = 0.65
	sound.Parent = localPlayer:WaitForChild("PlayerGui")
	sound:Play()

	task.delay(1.8, function()
		sound:Destroy()
	end)
	task.delay(2.4, function()
		if State.levelUpText:get() == label then
			State.levelUpText:set("")
		end
	end)
end

function Toast.ShowSpeedPopup(amount: number)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or amount <= 0 then
		return
	end

	local popup = Instance.new("Frame")
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundTransparency = 1
	popup.AutomaticSize = Enum.AutomaticSize.XY
	popup.ZIndex = 80
	popup.Parent = getSpeedPopupGui()

	local popupScale = Instance.new("UIScale")
	popupScale.Scale = 0
	popupScale.Parent = popup

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10) -- Khoảng cách xa nhau ra một chút
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = popup

	local iconHolder = Instance.new("Frame")
	iconHolder.BackgroundTransparency = 1
	iconHolder.Size = UDim2.fromOffset(40, 40)
	iconHolder.LayoutOrder = 1
	iconHolder.Parent = popup

	local elementsToFade = {}

	for _, offset in
		{
			Vector2.new(-2, 0),
			Vector2.new(2, 0),
			Vector2.new(0, -2),
			Vector2.new(0, 2),
			Vector2.new(2, 2),
			Vector2.new(-2, -2),
			Vector2.new(2, -2),
			Vector2.new(-2, 2),
		}
	do
		local outline = Instance.new("ImageLabel")
		outline.BackgroundTransparency = 1
		outline.Image = "rbxassetid://93408043939834"
		outline.ImageColor3 = Color3.fromRGB(0, 0, 0)
		outline.Position = UDim2.fromOffset(offset.X, offset.Y)
		outline.Size = UDim2.fromScale(1, 1)
		outline.ZIndex = 81
		outline.Parent = iconHolder
		table.insert(elementsToFade, outline)
	end

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://93408043939834"
	icon.Size = UDim2.fromScale(1, 1)
	icon.ZIndex = 82
	icon.Parent = iconHolder
	table.insert(elementsToFade, icon)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Theme.FONT
	label.Text = `+{Theme.FormatInteger(amount)}`
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 38
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.LayoutOrder = 2
	label.ZIndex = 83
	label.Parent = popup
	table.insert(elementsToFade, label)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 230, 255))
	gradient.Rotation = 90
	gradient.Parent = label

	local camera = Workspace.CurrentCamera
	local randomX = math.random(-40, 40)
	local randomY = math.random(-15, 15)
	local driftX = math.random(-25, 25)

	local lift = Instance.new("NumberValue")
	lift.Value = 0
	local drift = Instance.new("NumberValue")
	drift.Value = 0
	local popProgress = Instance.new("NumberValue")
	popProgress.Value = 0

	local connection: RBXScriptConnection?
	connection = RunService.RenderStepped:Connect(function()
		camera = Workspace.CurrentCamera
		if not camera or not root.Parent then
			if connection then
				connection:Disconnect()
			end
			popup:Destroy()
			return
		end

		local distance = (camera.CFrame.Position - root.Position).Magnitude
		-- Khi camera cách 16 studs -> scale 1. Xa hơn -> nhỏ lại. Gần hơn -> to ra
		local distanceScale = math.clamp(20 / math.max(distance, 1), 0.45, 1.65)
		popupScale.Scale = popProgress.Value * distanceScale

		local worldPos = root.Position + Vector3.new(0, 2.8, 0)
		local screenPosition, onScreen = camera:WorldToViewportPoint(worldPos)
		popup.Visible = onScreen
		-- Di chuyển lift và drift có tỉ lệ thuận với distanceScale để mượt hơn
		popup.Position = UDim2.fromOffset(
			screenPosition.X + (randomX + drift.Value) * distanceScale,
			screenPosition.Y + (randomY - lift.Value) * distanceScale
		)
	end)

	local popTween = TweenService:Create(
		popProgress,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 1 }
	)
	local liftTween =
		TweenService:Create(lift, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 90 })
	local driftTween = TweenService:Create(
		drift,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Value = driftX }
	)

	popTween:Play()
	liftTween:Play()
	driftTween:Play()

	task.delay(0.7, function()
		local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, el in elementsToFade do
			if el:IsA("ImageLabel") then
				TweenService:Create(el, fadeInfo, { ImageTransparency = 1 }):Play()
			elseif el:IsA("TextLabel") then
				TweenService:Create(el, fadeInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end
	end)

	liftTween.Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end
		lift:Destroy()
		drift:Destroy()
		popProgress:Destroy()
		popup:Destroy()
	end)
end

function Toast.BuildLevelUpFrame()
	return New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 188, 48),
		ClipsDescendants = true,
		Position = UDim2.fromOffset(960, 300),
		Size = UDim2.fromOffset(650, 112),
		Visible = Computed(function()
			return State.levelUpText:get() ~= ""
		end),
		ZIndex = 30,
		[Children] = {
			Theme.MakeCorner(18),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), Tokens.BORDER),
			Theme.MakeGradient(Color3.fromRGB(255, 226, 95), Color3.fromRGB(255, 135, 32), 0),
			-- 0.86 = độ mờ CHUẨN của cả HUD (`MakeStandardStuds`). Bản cũ 0.72 làm hoa văn ở
			-- riêng khung này đậm gấp đôi mọi khối khác — đúng chỗ "vân nền không đồng bộ".
			Theme.MakeStandardStuds(18, 31),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Trophy,
				Position = UDim2.fromOffset(18, 14),
				Size = UDim2.fromOffset(84, 84),
				ZIndex = 32,
			}),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Lightning,
				Position = UDim2.fromOffset(548, 14),
				Size = UDim2.fromOffset(84, 84),
				ZIndex = 32,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(112, 22),
				Size = UDim2.fromOffset(426, 68),
				Text = State.levelUpText,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				MaxTextSize = 42,
				ZIndex = 33,
			}),
		},
	})
end

function Toast.BuildCenterToast()
	return New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(31, 20, 61),
		Position = UDim2.fromOffset(960, 154),
		Size = UDim2.fromOffset(760, 76),
		Visible = Computed(function()
			return not State.GetSnapshot().isLoaded
		end),
		ZIndex = Theme.TOAST_Z_INDEX,
		[Children] = {
			Theme.MakeCorner(18),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), Tokens.BORDER),
			Theme.MakeGradient(Color3.fromRGB(92, 63, 196), Color3.fromRGB(31, 20, 61), 0),
			Theme.MakeStandardStuds(18, Theme.TOAST_Z_INDEX + 1),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(24, 6),
				Size = UDim2.fromOffset(712, 64),
				Text = Computed(function()
					return if State.GetSnapshot().isLoaded then "" else "Loading profile..."
				end),
				TextColor3 = Color3.fromRGB(255, 238, 112),
				MaxTextSize = 38,
				ZIndex = Theme.TOAST_Z_INDEX + 2,
			}),
		},
	})
end

return Toast
