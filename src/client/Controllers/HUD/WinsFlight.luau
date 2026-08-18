--!strict
--[[
	WinsFlight.luau — màn ăn mừng khi NHẬN THƯỞNG: Wins ở bệ cuối zone, Daily, Group Chest.

	Một màn duy nhất cho cả ba (2026-08-10, user muốn Daily/Group Chest "mượt giống khi nhận
	Wins"): cùng nhịp, cùng đường bay, chỉ khác nội dung thẻ và ĐÍCH bay. Dựng thêm hai hệ
	hoạt ảnh song song là chắc chắn lệch nhau sau vài lần chỉnh — và người chơi sẽ đọc ra
	ngay "cái này làm sau, cẩu thả hơn".

	    WinsFlight.Trigger(amount)        — Wins từ bệ cuối zone (bay về huy hiệu Wins)
	    WinsFlight.TriggerReward(config)  — Daily / Group Chest (bay về huy hiệu Wins nếu quà
	                                        có Wins, còn lại bay về dòng Speed dưới đáy)

	Nhịp 3 pha (tổng ~1.9s), toàn bộ dựng bằng Fusion:
	  1. POP    0.42s — thẻ nở bung giữa màn hình (Back Out), sunburst xoay sau lưng,
	                    tia sáng loé, cúp nảy nhẹ
	  2. HOLD   0.80s — đứng yên cho người chơi ĐỌC được con số
	  3. FLY    0.62s — bay theo đường cong Bézier về huy hiệu Wins góc trái, vừa bay vừa
	                    co nhỏ và mờ dần (Quart In: chậm rồi vút — cảm giác "bị hút vào")
	  → chạm đích: huy hiệu Wins nảy lên (LeftMenu.PulseWins) + toé tia sáng

	VÌ SAO BÉZIER CHỨ KHÔNG PHẢI ĐƯỜNG THẲNG: đích nằm chếch trên-trái so với tâm màn hình.
	Bay thẳng trông như thẻ bị kéo lê. Đường cong vồng lên trước rồi đổ xuống đích đọc ra là
	"vật thể được ném", mắt bám theo dễ hơn nhiều.

	CHỈ MỘT màn bay sống tại một thời điểm: `token` cắt mọi task.delay của lượt trước, nên
	nhận Wins dồn dập (x2 pad rồi win pad) không chồng hai thẻ lên nhau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local BottomHud = require(script.Parent.Hud.BottomHud)
local LeftMenu = require(script.Parent.Hud.LeftMenu)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

local WinsFlight = {}

local POP_SECONDS = 0.42
local HOLD_SECONDS = 0.80
local FLY_SECONDS = 0.62
-- Cỡ thẻ lúc chạm huy hiệu. 0.18 ≈ đúng cỡ icon cúp trên HUD ⇒ thẻ "nhập" vào huy hiệu
-- thay vì biến mất khi vẫn còn to.
local FLY_END_SCALE = 0.18
local CARD_CENTER = Vector2.new(960, 470)

-- Số icon tối đa vẽ trên thẻ. Daily ngày 7 cho 3 món — nhiều hơn thế thì hàng icon co lại
-- nhỏ hơn chữ và mất tác dụng "nhìn là biết được gì".
local MAX_ICONS = 3

export type RewardConfig = {
	icons: { string }, -- icon từng món, theo đúng thứ tự đọc của `detail`
	headline: string, -- dòng to giữa thẻ (món chính)
	detail: string, -- dòng nhỏ liệt kê các món còn lại ("" = không có)
	caption: string, -- nhãn dưới cùng: "DAILY REWARD" / "GROUP CHEST"
	accent: Color3?, -- màu chữ headline (mặc định vàng như Wins)
	toWinsBadge: boolean?, -- true = bay về huy hiệu Wins, false = bay về dòng Speed
}

-- ===== state =====
local visible = Value(false)
local amountText = Value("")
local detailText = Value("")
local captionText = Value("WINS COLLECTED!")
local accentColor = Value(Color3.fromRGB(255, 236, 96))
local iconImages = { Value(Theme.UI_ASSETS.Trophy), Value(""), Value("") }
local iconCount = Value(1)
local token = 0
-- Chỉ khi `flying` bật thì vị trí/cỡ thẻ mới đọc theo `fly`. Lúc tắt, thẻ đứng yên giữa
-- màn hình bất kể `fly` đang ở đâu — nhờ vậy pha reset (tween 1 → 0) diễn ra vô hình
-- thay vì cho người chơi xem thẻ bay NGƯỢC từ huy hiệu về giữa màn hình.
local flying = Value(false)

-- 0 → 1 khi thẻ nở ra
local popGoal = Value(0)
local pop = Fusion.Tween(popGoal, TweenInfo.new(POP_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
-- 0 → 1 khi thẻ bay về huy hiệu
local flyGoal = Value(0)
local fly = Fusion.Tween(flyGoal, TweenInfo.new(FLY_SECONDS, Enum.EasingStyle.Quart, Enum.EasingDirection.In))

-- Đích + điểm điều khiển, chốt MỘT LẦN lúc bắt đầu bay. Không tính lại trong Computed:
-- `GetVisibleDesignBounds` phụ thuộc viewport, người chơi đổi cỡ cửa sổ giữa chừng thì
-- đường bay sẽ giật sang chỗ khác.
local target = Value(Vector2.new(56, 267))
local control = Value(Vector2.new(500, 300))

local layer: Frame? = nil
local rng = Random.new()

local function bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: number): Vector2
	local inv = 1 - t
	return p0 * (inv * inv) + p1 * (2 * inv * t) + p2 * (t * t)
end

local cardPosition = Computed(function(): UDim2
	if not flying:get() then
		return UDim2.fromOffset(CARD_CENTER.X, CARD_CENTER.Y)
	end
	local p = bezier(CARD_CENTER, control:get(), target:get(), fly:get())
	return UDim2.fromOffset(p.X, p.Y)
end)

local cardScale = Computed(function(): number
	-- Lúc pop: 0.6 → 1 (Back Out tự tạo cú vọt quá đà). Lúc bay: 1 → FLY_END_SCALE.
	local base = 0.6 + 0.4 * pop:get()
	local t = if flying:get() then fly:get() else 0
	return base * (1 - (1 - FLY_END_SCALE) * t)
end)

local cardTransparency = Computed(function(): number
	-- Hiện theo pop, và chỉ mờ ở NỬA SAU đường bay — mờ ngay từ đầu thì mắt mất dấu giữa
	-- chặng và không thấy được thẻ "đi vào" huy hiệu.
	local appear = 1 - math.clamp(pop:get(), 0, 1)
	local t = if flying:get() then fly:get() else 0
	local fade = math.clamp((t - 0.5) / 0.5, 0, 1)
	return math.clamp(appear + fade, 0, 1)
end)

local function playChime()
	local sound = Instance.new("Sound")
	sound.SoundId = Theme.UI_ASSETS.CelebrationSound
	sound.Volume = 0.7
	sound.PlaybackSpeed = 1.12
	sound.Parent = SoundService
	sound.PlayOnRemove = true
	sound:Destroy()
end

-- Tia sáng toé ra tại đích khi thẻ chạm huy hiệu Wins.
local function sparkAt(position: Vector2)
	local host = layer
	if not host then
		return
	end
	for _ = 1, 10 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextInteger(34, 78)
		local size = rng:NextInteger(7, 14)

		local spark = Instance.new("Frame")
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.BackgroundColor3 = Color3.fromRGB(255, 232, 92)
		spark.BorderSizePixel = 0
		spark.Position = UDim2.fromOffset(position.X, position.Y)
		spark.Rotation = rng:NextInteger(0, 360)
		spark.Size = UDim2.fromOffset(size, size)
		spark.ZIndex = 232
		spark.Parent = host

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = spark

		local tween = TweenService:Create(spark, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(position.X + math.cos(angle) * dist, position.Y + math.sin(angle) * dist),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 0),
		})
		tween.Completed:Once(function()
			spark:Destroy()
		end)
		tween:Play()
	end
end

--[[
	Chạy nhịp 3 pha. `getDestination` được gọi ĐÚNG LÚC bắt đầu bay (không phải lúc gọi hàm)
	để lấy toạ độ đích mới nhất — huy hiệu Wins và dòng Speed đều dời chỗ theo cỡ cửa sổ.
]]
local function play(getDestination: () -> Vector2)
	token += 1
	local myToken = token

	-- Ẩn + hạ cả hai goal về 0. `Fusion.Tween` KHÔNG nhảy tức thời được: nó luôn tween từ giá
	-- trị hiện tại. Sau lượt trước, `pop` đang đứng ở 1 — set 1 lần nữa là KHÔNG có cú nở nào
	-- cả (goal không đổi). Nên phải hạ về 0 thật, rồi đợi tween lắng mới nở lại.
	visible:set(false)
	flying:set(false)
	flyGoal:set(0)
	popGoal:set(0)

	task.spawn(function()
		-- Đợi tween reset chạm đáy. Bình thường lượt trước đã kết thúc từ lâu nên vòng này
		-- thoát ngay ở lần kiểm tra đầu; chỉ khi nhận Wins hai lần trong chưa đầy 0.4s
		-- (x2 pad rồi win pad) mới thực sự chờ — mà lúc đó thẻ đang ẩn, không ai thấy.
		local deadline = os.clock() + POP_SECONDS + FLY_SECONDS
		while (pop:get() > 0.02 or fly:get() > 0.02) and os.clock() < deadline do
			task.wait()
		end
		if myToken ~= token then
			return
		end

		visible:set(true)
		playChime()
		popGoal:set(1)

		task.wait(POP_SECONDS + HOLD_SECONDS)
		if myToken ~= token then
			return
		end

		local dest = getDestination()
		target:set(dest)
		-- Điểm điều khiển: giữa đường nhưng NHẤC LÊN 190px ⇒ vồng lên rồi đổ xuống huy hiệu.
		control:set(Vector2.new((CARD_CENTER.X + dest.X) * 0.5, math.min(CARD_CENTER.Y, dest.Y) - 190))
		flying:set(true)
		flyGoal:set(1)

		task.wait(FLY_SECONDS)
		if myToken ~= token then
			return
		end
		visible:set(false)
		flying:set(false)
		-- Huy hiệu chỉ nảy khi thẻ THỰC SỰ bay tới nó — quà chỉ có Speed thì bay xuống dòng
		-- Speed, mà cho huy hiệu Wins nảy lúc đó là nói dối "bạn vừa được thêm Wins".
		if math.abs(dest.X - LeftMenu.GetWinsBadgeCenter().X) < 2 then
			LeftMenu.PulseWins()
		end
		sparkAt(dest)
		-- Hạ goal ngay để lượt sau không phải chờ (thẻ đã ẩn nên tween này vô hình).
		popGoal:set(0)
		flyGoal:set(0)
	end)
end

-- Đặt lại nội dung thẻ. `icons` cắt còn tối đa MAX_ICONS.
local function setCard(icons: { string }, headline: string, detail: string, caption: string, accent: Color3)
	amountText:set(headline)
	detailText:set(detail)
	captionText:set(caption)
	accentColor:set(accent)

	local count = math.clamp(#icons, 1, MAX_ICONS)
	iconCount:set(count)
	for index = 1, MAX_ICONS do
		iconImages[index]:set(icons[index] or "")
	end
end

--[[
	Wins từ bệ cuối zone. `amount` = số Wins vừa nhận.
	Gọi từ HUDController khi nhận toast kind == "wins_collected".
]]
function WinsFlight.Trigger(amount: number)
	if amount <= 0 then
		return
	end
	setCard(
		{ Theme.UI_ASSETS.Trophy },
		`+{Theme.FormatInteger(amount)}`,
		"",
		"WINS COLLECTED!",
		Color3.fromRGB(255, 236, 96)
	)
	play(LeftMenu.GetWinsBadgeCenter)
end

-- Daily / Group Chest. Xem type `RewardConfig` ở đầu file.
function WinsFlight.TriggerReward(config: RewardConfig)
	setCard(config.icons, config.headline, config.detail, config.caption, config.accent or Color3.fromRGB(255, 236, 96))
	play(if config.toWinsBadge then LeftMenu.GetWinsBadgeCenter else BottomHud.GetSpeedTextCenter)
end

function WinsFlight.Build()
	local host = New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		-- Trên banner boost (208) nhưng dưới modal — thẻ này không bao giờ chặn thao tác.
		ZIndex = 230,
		[Children] = {
			New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				GroupTransparency = cardTransparency,
				Position = cardPosition,
				-- 286 chứ không phải 250 như bản chỉ-có-Wins: thẻ giờ có thêm dòng liệt kê món
				-- phụ (Daily ngày 7 có 3 món), để 250 là CanvasGroup xén mất nửa dưới dòng chữ.
				Size = UDim2.fromOffset(560, 286),
				Visible = visible,
				ZIndex = 231,
				[Children] = {
					New("UIScale")({ Scale = cardScale }),

					-- Sunburst xoay sau lưng — cùng ngôn ngữ hình ảnh với banner Rebirth/Boost.
					(function()
						local burst = New("ImageLabel")({
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							Image = Theme.UI_ASSETS.Sunburst,
							ImageColor3 = Color3.fromRGB(255, 226, 96),
							ImageTransparency = 0.24,
							Position = UDim2.fromOffset(280, 96),
							Size = UDim2.fromOffset(430, 430),
							ZIndex = 231,
						}) :: ImageLabel
						TweenService:Create(
							burst,
							TweenInfo.new(7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
							{ Rotation = 360 }
						):Play()
						return burst
					end)(),

					--[[
						HÀNG ICON. Một món (Wins) thì icon to 150px đúng như bản cũ; nhiều món
						(Daily) thì co lại và xếp ngang — icon nhỏ mà ĐỦ MẶT còn hơn một icon to
						đại diện cho ba thứ khác nhau (đúng bài học của DailyModal 2026-08-08).
					]]
					New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(280, 92),
						Size = UDim2.fromOffset(480, 150),
						ZIndex = 232,
						[Children] = {
							New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, 18),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = iconImages[1],
								LayoutOrder = 1,
								Size = Computed(function()
									local side = if iconCount:get() > 1 then 116 else 150
									return UDim2.fromOffset(side, side)
								end),
								ZIndex = 232,
							}),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = iconImages[2],
								LayoutOrder = 2,
								Size = UDim2.fromOffset(116, 116),
								Visible = Computed(function()
									return iconCount:get() >= 2
								end),
								ZIndex = 232,
							}),
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = iconImages[3],
								LayoutOrder = 3,
								Size = UDim2.fromOffset(116, 116),
								Visible = Computed(function()
									return iconCount:get() >= 3
								end),
								ZIndex = 232,
							}),
						},
					}),

					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(0, 152),
						Size = UDim2.fromOffset(560, 58),
						Text = amountText,
						TextColor3 = accentColor,
						TextXAlignment = Enum.TextXAlignment.Center,
						MaxTextSize = 68,
						ZIndex = 233,
					}),
					-- Dòng liệt kê các món phụ. Rỗng ⇒ ẩn hẳn để thẻ Wins trông y như cũ.
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(0, 206),
						Size = UDim2.fromOffset(560, 32),
						Text = detailText,
						Visible = Computed(function()
							return detailText:get() ~= ""
						end),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextXAlignment = Enum.TextXAlignment.Center,
						MaxTextSize = 30,
						ZIndex = 233,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(0, 236),
						Size = UDim2.fromOffset(560, 34),
						Text = captionText,
						TextColor3 = Color3.fromRGB(190, 255, 220),
						TextXAlignment = Enum.TextXAlignment.Center,
						MaxTextSize = 32,
						ZIndex = 233,
					}),
				},
			}),
		},
	}) :: Frame

	layer = host
	return host
end

return WinsFlight
