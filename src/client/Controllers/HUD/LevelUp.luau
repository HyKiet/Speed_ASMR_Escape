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
--[[
	Popup lên cấp: neo giữa theo chiều ngang, bám MÉP TRÊN theo chiều dọc (Upper Center — tránh
	đè lên banner chúc mừng mua hàng).

	Cùng phép quy đổi với mọi cụm bám mép của HUD:

	    y thật = chiều cao topbar (px thật, KHÔNG co) + lề × scale

	`TOP_MARGIN` = 137 cho ra 36 + 137 = 173 px trên PC — đúng bằng 0.16 × 1080 của bản thiết kế
	cũ, nên PC không đổi một pixel.

	⚠️ ĐÃ BỎ nhánh `BASE_Y_SCALE_SMALL` (hạ popup xuống 0.27 khi `viewportScale < 0.75`). Đó là
	một bố cục riêng cho mobile; nó tồn tại chỉ vì bản cũ nhân cả chiều cao topbar theo tỉ lệ nên
	popup chui vào topbar. Cộng topbar nguyên bản là hết, không cần nhánh nào.
]]
local TOP_MARGIN = 137

-- Toạ độ Y thật (px màn hình) của TÂM popup. Popup cao 260 design px, neo tâm.
local function getBaseY(): number
	return State.guiInsetTop:get() + (TOP_MARGIN + 130) * State.viewportScale:get()
end

-- Bậc combo -> bộ màu. TẤT CẢ đều TƯƠI/SÁNG (không có màu tối) để chữ luôn rõ & đẹp ở mọi combo.
-- Combo vượt số bậc thì xoay vòng (cycle) qua các màu này.
local TIERS = {
	{ a = Color3.fromRGB(255, 238, 140), b = Color3.fromRGB(255, 176, 40), stroke = Color3.fromRGB(95, 45, 0) },
	{ a = Color3.fromRGB(255, 196, 90), b = Color3.fromRGB(255, 110, 28), stroke = Color3.fromRGB(95, 35, 0) },
	{ a = Color3.fromRGB(255, 150, 215), b = Color3.fromRGB(255, 70, 140), stroke = Color3.fromRGB(95, 0, 45) },
	{ a = Color3.fromRGB(130, 235, 255), b = Color3.fromRGB(45, 150, 255), stroke = Color3.fromRGB(0, 35, 90) },
	{ a = Color3.fromRGB(190, 255, 120), b = Color3.fromRGB(90, 220, 60), stroke = Color3.fromRGB(20, 75, 0) },
}

--[[
	── TỐI ƯU FPS CHO CHUỖI COMBO (2026-08-14, user: "level up liên tục thì drop FPS") ─────
	Hiệu ứng KHÔNG đổi một chi tiết nào — cùng số hạt, cùng đường tween, cùng màu, cùng tiếng.
	Thứ đổi là vòng đời của các Instance đứng sau nó. Ba nguồn lag, theo thứ tự nặng dần:

	  1. `setShown` và `fadeOut` duyệt `root:GetDescendants()`. Mà hạt nổ LÀ hậu duệ của root,
	     nên đúng lúc combo dồn dập (hàng trăm hạt đang bay) thì mỗi cú lên cấp lại duyệt qua
	     toàn bộ đám hạt đó — và `fadeOut` còn TẠO MỘT TWEEN cho từng hạt. Nhảy 20 cấp là vài
	     nghìn tween rác trong một giây. Giờ hai hàm này đọc `staticParts`: danh sách 9 phần tử
	     cố định dựng một lần lúc build, không bao giờ chứa hạt.

	  2. Mỗi cấp là 10–34 `Instance.new("Frame")` + `UICorner`, rồi `:Destroy()` sau 0.55s.
	     Ở nhịp 0.055s/cấp thì đó là ~680 lượt tạo-huỷ trong 1.1s. Giờ hạt nằm trong BỂ TÁI
	     DÙNG: tạo một lần, sau đó chỉ bật/tắt và gán lại thuộc tính.

	  3. `s.root:Destroy()` sau mỗi lần fade, rồi lần lên cấp sau dựng lại từ đầu cả popup
	     (ScreenGui con, 4 label, 2 icon, gradient, stroke…). Giờ popup sống suốt phiên và chỉ
	     ẩn/hiện — đằng nào nó cũng sẽ được dùng lại sau vài giây.

	`MAX_LIVE_DOTS` là van an toàn cho trường hợp cực đoan (nhảy 20+ cấp): quá ngưỡng thì hạt
	già nhất bị thu hồi sớm để cấp cho cú nổ mới. 220 là trần rộng — sáu cú nổ đầy chồng nhau
	vẫn chưa chạm tới — nên mắt thường không thấy hạt nào bị cắt.
]]
local MAX_LIVE_DOTS = 220

type Session = {
	gui: ScreenGui,
	root: Frame,
	scale: UIScale,
	titleLabel: TextLabel,
	titleGradient: UIGradient,
	titleStroke: UIStroke,
	levelLabel: TextLabel,
	comboLabel: TextLabel,
	comboStroke: UIStroke,
	comboScale: UIScale,
	sunburst: ImageLabel,
	burstHolder: Frame,
	-- Chín phần tử hiển thị CỐ ĐỊNH (label/stroke/icon). Không bao giờ chứa hạt nổ — đó là
	-- toàn bộ lý do nó tồn tại.
	staticParts: { Instance },
	dotPool: { Frame }, -- hạt rảnh, đang tắt, chờ tái dùng
	liveDots: { Frame }, -- hạt đang bay (hàng đợi: phần tử [1] là già nhất)
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

local function makeTextLabel(
	name: string,
	size: UDim2,
	pos: UDim2,
	textSize: number,
	strokeThickness: number
): (TextLabel, UIStroke)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = Theme.FONT
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
	root.Position = UDim2.new(0.5, 0, 0, getBaseY())
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
	local bolts: { ImageLabel } = {}
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
		table.insert(bolts, bolt)
	end

	local titleLabel, titleStroke = makeTextLabel("Title", UDim2.fromOffset(700, 96), UDim2.fromScale(0.5, 0.34), 76, 4)
	titleLabel.Text = "LEVEL UP!"
	titleLabel.Parent = root
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Rotation = 90
	titleGradient.Parent = titleLabel

	local levelLabel, levelStroke = makeTextLabel("Level", UDim2.fromOffset(520, 70), UDim2.fromScale(0.5, 0.66), 54, 4)
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.Parent = root

	local comboLabel, comboStroke = makeTextLabel("Combo", UDim2.fromOffset(420, 56), UDim2.fromScale(0.5, 0.04), 46, 4)
	comboLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	comboLabel.TextTransparency = 1
	comboLabel.Parent = root

	-- Dựng SẴN ở đây thay vì `Instance.new` giữa lúc combo đang chạy (bản cũ tạo UIScale này
	-- lần đầu combo >= 2, tức đúng vào frame nặng nhất).
	local comboScale = Instance.new("UIScale")
	comboScale.Parent = comboLabel

	local burstHolder = Instance.new("Frame")
	burstHolder.Name = "Burst"
	burstHolder.BackgroundTransparency = 1
	burstHolder.Position = UDim2.fromScale(0.5, 0.46)
	burstHolder.Size = UDim2.fromOffset(0, 0)
	burstHolder.ZIndex = 4
	burstHolder.Parent = root

	return {
		gui = gui,
		root = root,
		scale = scale,
		titleLabel = titleLabel,
		titleGradient = titleGradient,
		titleStroke = titleStroke,
		levelLabel = levelLabel,
		comboLabel = comboLabel,
		comboStroke = comboStroke,
		comboScale = comboScale,
		sunburst = sunburst,
		burstHolder = burstHolder,
		staticParts = {
			sunburst,
			bolts[1],
			bolts[2],
			titleLabel,
			titleStroke,
			levelLabel,
			levelStroke,
			comboLabel,
			comboStroke,
		},
		dotPool = {},
		liveDots = {},
		combo = 0,
		token = 0,
		targetScale = 1,
		fadeTweens = {},
	}
end

--[[
	Số đời của mỗi hạt, tăng mỗi lần hạt được LẤY RA khỏi bể.

	Cần nó vì hẹn giờ thu hồi (`task.delay` 0.55s) sống lâu hơn lượt dùng khi hạt bị thu hồi
	SỚM do chạm trần rồi lập tức được cấp lại cho cú nổ mới. Không có số đời thì cái hẹn giờ
	cũ sẽ tắt một hạt đang bay dở giữa chừng — người chơi thấy hạt biến mất đột ngột.
]]
local dotGeneration: { [Frame]: number } = {}

-- Trả hạt về bể: TẮT chứ không huỷ. Gọi hai lần trên cùng một hạt là vô hại (kiểm `Visible`).
local function releaseDot(s: Session, dot: Frame)
	if not dot.Visible then
		return
	end
	dot.Visible = false
	table.insert(s.dotPool, dot)
end

local function acquireDot(s: Session): Frame
	local pooled = table.remove(s.dotPool)
	if pooled then
		return pooled
	end

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BorderSizePixel = 0
	dot.ZIndex = 4
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = dot
	dot.Parent = s.burstHolder
	return dot
end

local function spawnParticles(s: Session, count: number, hot: boolean)
	for i = 1, count do
		-- Chạm trần hạt sống: thu hồi hạt GIÀ NHẤT (đầu hàng đợi) — nó đang ở cuối đường bay,
		-- gần như trong suốt hoàn toàn, nên cắt nó là thứ ít bị nhìn thấy nhất.
		if #s.liveDots >= MAX_LIVE_DOTS then
			local oldest = table.remove(s.liveDots, 1)
			if oldest then
				releaseDot(s, oldest)
			end
		end

		local dot = acquireDot(s)
		local generation = (dotGeneration[dot] or 0) + 1
		dotGeneration[dot] = generation
		local rotation = math.random(0, 360)
		dot.BackgroundColor3 = if hot
			then Color3.fromHSV(math.random(), 0.9, 1)
			else Color3.fromRGB(255, math.random(200, 255), math.random(90, 170))
		dot.BackgroundTransparency = 0
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Rotation = rotation
		dot.Visible = true

		local angle = math.rad((360 / count) * i + math.random(-12, 12))
		local dist = math.random(120, 230)
		local target = UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist)
		local startSize = math.random(14, 26)

		dot.Size = UDim2.fromOffset(startSize, startSize)
		TweenService:Create(dot, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = target,
			Size = UDim2.fromOffset(2, 2),
			Rotation = rotation + math.random(-160, 160),
			BackgroundTransparency = 1,
		}):Play()

		table.insert(s.liveDots, dot)
		task.delay(0.55, function()
			-- Hạt đã được cấp lại cho cú nổ khác → hẹn giờ này quá hạn, bỏ qua.
			if dotGeneration[dot] ~= generation then
				return
			end
			local index = table.find(s.liveDots, dot)
			if index then
				table.remove(s.liveDots, index)
			end
			releaseDot(s, dot)
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

--[[
	Hiện/ẩn TOÀN BỘ độ trong suốt (gồm cả UIStroke) — tránh "chữ rỗng chỉ còn viền".

	Duyệt `staticParts` (9 phần tử) chứ KHÔNG phải `root:GetDescendants()`. Hạt nổ cũng là hậu
	duệ của root, nên bản cũ vừa duyệt qua hàng trăm hạt vừa ghi đè `BackgroundTransparency`
	giữa lúc chúng đang bay — vừa tốn vừa sai.
]]
local function setShown(s: Session, shown: boolean)
	for _, obj in s.staticParts do
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
	local scaleT =
		TweenService:Create(s.scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	table.insert(s.fadeTweens, scaleT)
	scaleT:Play()
	-- 9 tween cố định. Bản cũ tạo một tween cho MỌI hậu duệ, tức là cả từng hạt nổ đang bay —
	-- một cú nhảy 20 cấp sinh ra hàng nghìn tween chỉ để làm mờ thứ vốn đã tự mờ.
	for _, obj in s.staticParts do
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
	--[[
		ẨN, KHÔNG HUỶ (2026-08-14). Bản cũ `root:Destroy()` rồi đặt `session = nil`, nên lần
		lên cấp kế tiếp phải dựng lại toàn bộ popup từ con số không — và người chơi lên cấp
		vài giây một lần, nên đó là dựng-rồi-huỷ liên miên suốt phiên chơi. Giữ nguyên popup
		đã tắt tốn vài chục instance nằm im, đổi lại mọi cú lên cấp sau đều chỉ là bật lại.
	]]
	task.delay(0.36, function()
		if session == s and s.token == token then
			s.root.Visible = false
			s.combo = 0
			State.levelUpActive:set(false)
		end
	end)
end

--[[
	MỘT SOUND MỚI CHO MỖI CẤP — cố ý, đừng gộp thành bể dùng chung.

	Đã thử bể 8 giọng xoay vòng (2026-08-14) để bớt tạo/huỷ instance, và ĐÃ PHẢI GỠ: người chơi
	báo mất hẳn tiếng lên cấp. Bể giữ tham chiếu tới 8 Sound nằm trong PlayerGui, mà PlayerGui
	bị dọn khi hồi sinh — sau lần chết đầu tiên bể vẫn còn 8 phần tử (nên không dựng lại) nhưng
	cả 8 đều đã mồ côi, và im lặng vĩnh viễn từ đó.

	Còn một lý do nữa để không gộp, quan trọng hơn cả bug trên: chuỗi combo phải nghe DỒN DẬP,
	tức các tiếng CHỒNG LÊN NHAU. Bể xoay vòng thì giọng bị chiếm lại sẽ tua về đầu, cắt ngang
	chính nó — càng nhiều cấp một lúc càng ít tiếng nghe được, ngược hẳn hiệu ứng mong muốn.

	Chi phí thật của nó là nhỏ: 20 Sound trong một chuỗi 20 cấp không đáng gì so với ~680 Frame
	mà bể hạt đã cắt được. Tối ưu FPS nằm ở `staticParts` + bể hạt, KHÔNG nằm ở đây.
]]
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

-- Một NHỊP của màn ăn mừng: vẽ đúng một con số cấp. Nhảy nhiều cấp = gọi hàm này nhiều lần
-- liên tiếp (xem `LevelUp.Trigger`), nên mỗi cấp đều có cú punch + hạt + tiếng riêng.
local function showLevel(level: number)
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
	-- Popup sống suốt phiên (xem `fadeOut`), nên vị trí phải cập nhật lại mỗi lần hiện —
	-- người chơi có thể xoay máy hoặc đổi cửa sổ giữa chừng.
	s.root.Position = UDim2.new(0.5, 0, 0, getBaseY())

	-- QUAN TRỌNG: huỷ fade cũ + hiện rõ TẤT CẢ (gồm UIStroke) trước khi vẽ lại →
	-- chống lỗi "chữ rỗng chỉ còn viền tối" khi combo nối tiếp lúc đang fade.
	clearFades(s)
	setShown(s, true)
	s.root.Visible = true -- popup giờ được ẩn chứ không huỷ (xem `fadeOut`)
	State.levelUpActive:set(true) -- banner chúc mừng tụt xuống làn dưới để không đè lên nhau

	-- Cập nhật text. KHÔNG có hậu tố "(+N)": nhảy nhiều cấp thì con số ĐẾM LÊN từng cấp một
	-- (xem `LevelUp.Trigger`) — mắt đọc được cả hành trình thay vì một phép trừ.
	s.titleLabel.Text = "LEVEL UP!"
	s.levelLabel.Text = `LEVEL {level}`
	applyTier(s, combo)

	-- Combo label (>=2 mới hiện) — ẩn/hiện CẢ viền UIStroke.
	if combo >= 2 then
		s.comboLabel.Text = `🔥 COMBO x{combo}`
		s.comboLabel.TextTransparency = 0
		s.comboStroke.Transparency = 0
		s.comboScale.Scale = 1.6
		TweenService
			:Create(s.comboScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	else
		s.comboLabel.TextTransparency = 1
		s.comboStroke.Transparency = 1
	end

	-- POP: phóng to giật theo kiểu Back (re-punch mỗi hit), kèm wobble xoay
	local punchFrom = combo == 1 and 0 or s.targetScale * 0.72
	s.scale.Scale = punchFrom
	TweenService
		:Create(
			s.scale,
			TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = s.targetScale }
		)
		:Play()
	s.root.Rotation = (combo % 2 == 0) and 4 or -4
	TweenService
		:Create(s.root, TweenInfo.new(0.4, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 })
		:Play()

	-- Sunburst: pulse + xoay
	s.sunburst.Size = UDim2.fromOffset(360, 360)
	TweenService:Create(s.sunburst, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(540 + combo * 14, 540 + combo * 14),
	}):Play()
	TweenService
		:Create(s.sunburst, TweenInfo.new(2.2, Enum.EasingStyle.Linear), { Rotation = s.sunburst.Rotation + 90 })
		:Play()

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

--[[
	Gọi mỗi lần lên cấp. `level` = cấp mới, `levelsGained` = số cấp tăng trong lần này.

	── NHẢY LIÊN TỤC, KHÔNG PHẢI "(+8)" (2026-08-10, user) ────────────────────────────────
	Một cú farm mạnh có thể nhảy 8-11 cấp trong CÙNG một gói snapshot. Bản cũ vẽ đúng một
	dòng `LEVEL 9 (+8)` — con số cuối thì đọc được, nhưng 8 cấp kia biến mất không dấu vết,
	và phần thưởng lớn nhất trong game lại hiện ra bằng đúng một khung hình tĩnh.

	Giờ số cấp CHẠY LÊN từng bậc: mỗi bậc là một `showLevel` đầy đủ (punch scale + wobble
	xoay + nổ hạt + tiếng lên cao dần theo combo), nên nhảy 8 cấp = 8 cú đấm nối nhau — đúng
	cảm giác "máy quay số" mà mắt bám theo được.

	Nhịp co theo số cấp để tổng thời gian luôn nằm trong ~1.1s: nhảy 2 cấp thì thong thả
	(0.16s/cấp), nhảy 20 cấp thì dồn dập (0.055s/cấp). Chậm hơn nữa là lê thê; nhanh hơn nữa
	thì các con số nhoè thành một vệt không đọc được.

	⚠️ `COMBO_WINDOW` (1.7s) phải LỚN HƠN tổng thời gian đếm, nếu không popup sẽ fade giữa
	chừng rồi bật lại — đó là lý do có trần `RUN_SECONDS`.
]]
local RUN_SECONDS = 1.1 -- tổng thời gian đếm tối đa
local STEP_MIN = 0.055
local STEP_MAX = 0.16

function LevelUp.Trigger(level: number, levelsGained: number)
	local gained = math.max(1, math.floor(levelsGained))
	if gained == 1 then
		showLevel(level)
		return
	end

	local step = math.clamp(RUN_SECONDS / gained, STEP_MIN, STEP_MAX)
	local first = level - gained + 1

	task.spawn(function()
		for value = first, level do
			showLevel(value)
			if value < level then
				task.wait(step)
			end
		end
	end)
end

return LevelUp
