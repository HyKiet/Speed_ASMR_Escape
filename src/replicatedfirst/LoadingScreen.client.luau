--!strict
--[[
	LoadingScreen.client.luau — MÀN HÌNH CHỜ LÚC VÀO GAME.

	── VẤN ĐỀ ĐANG CHỮA (user báo 2026-08-19) ────────────────────────────────────────────
	"Vào game map chưa load hết, phải chơi 5 phút map mới load xong."

	`Workspace.StreamingEnabled = true` và bản đồ trải 6.806 × 3.756 studs với 11.907 part
	trong Zones + 5.492 ở Lobby. Roblox thả người chơi vào NGAY khi khung hình đầu tiên dựng
	được, phần còn lại chảy về dần trong lúc chơi. Không có màn hình chờ thì người chơi thấy
	đúng cái quá trình đó: sàn hiện dần, vật thể bật ra giữa không trung.

	── VÌ SAO FILE NÀY NẰM Ở ReplicatedFirst ─────────────────────────────────────────────
	`ReplicatedFirst` là container DUY NHẤT được sao chép xuống client TRƯỚC mọi thứ khác, và
	`RemoveDefaultLoadingScreen()` chỉ có tác dụng nếu gọi trong vài khung hình đầu. Đặt ở
	StarterPlayerScripts là đã muộn — người chơi kịp thấy thế giới dựng dở.

	⚠️ KHÔNG require được `HUD/Tokens` hay `Theme`: chúng nằm trong StarterPlayerScripts, mà
	container đó chưa chắc đã tới client khi file này chạy — chờ nó là tự đánh mất lý do tồn
	tại của ReplicatedFirst. Vì vậy font/màu bên dưới CHÉP TAY từ Tokens. Đổi bảng màu game
	thì nhớ đổi cả ở đây (chỉ 5 hằng số, cố ý giữ ít).

	── MỌI CHUYỂN ĐỘNG ĐỀU QUA TweenService ──────────────────────────────────────────────
	Không có một vòng `RenderStepped` nào trong file này. Tween chạy trong engine (C++), nên
	hoạt ảnh mượt mà chi phí Lua bằng 0 — đúng lúc client đang bận nhất cả phiên chơi
	(stream địa hình + dựng 79 controller). Một vòng lặp Lua hoạt hoạ ở đây sẽ giành CPU với
	chính việc nạp mà nó đang chờ.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ⚠️ KHÔNG có hằng "bán kính nạp sẵn": `RequestStreamAroundAsync(position, timeout)` chỉ
-- nhận toạ độ và thời gian chờ — bán kính do `Workspace.StreamingTargetRadius` quyết định,
-- mà thuộc tính đó script không đổi được (Roblox đánh dấu NotScriptable).

-- Trần chờ. Mạng kém hay máy yếu thì vẫn phải cho vào chơi: thà thấy map dựng dở còn hơn
-- kẹt ở màn hình chờ mãi mãi — đó là cách chắc chắn nhất để mất người chơi.
local MAX_WAIT_SECONDS = 20
-- Chờ tối thiểu để màn hình không chớp một cái rồi biến mất (máy mạnh + asset đã cache).
local MIN_SHOW_SECONDS = 1.6

-- Chép tay từ HUD/Tokens (xem lý do ở đầu file).
local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(18, 18, 30)
local GOLD = Color3.fromRGB(255, 205, 46)
local GOLD_DEEP = Color3.fromRGB(255, 162, 28)
local DIM = Color3.fromRGB(150, 156, 178)
local SUNBURST = "rbxassetid://87577740080014"

local localPlayer = Players.LocalPlayer

ReplicatedFirst:RemoveDefaultLoadingScreen()

--------------------------------------------------------------------------------
-- Dựng giao diện
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedEscapeLoading"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
-- Trên MỌI thứ, kể cả SpotlightGui (120) và TutorialGui (130).
gui.DisplayOrder = 10000
gui.ResetOnSpawn = false
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = INK
bg.BorderSizePixel = 0
bg.Parent = gui

-- Nền chuyển sắc nhẹ: phẳng tuyệt đối trông như màn hình lỗi, một chút chiều sâu là đủ
-- để đọc ra "đây là màn hình có chủ đích".
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new(Color3.fromRGB(28, 28, 46), INK)
bgGradient.Rotation = 90
bgGradient.Parent = bg

-- Cụm giữa: gom vào một Frame để fade/scale CẢ CỤM bằng đúng một tween.
local center = Instance.new("Frame")
center.BackgroundTransparency = 1
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.fromScale(0.5, 0.5)
center.Size = UDim2.fromScale(1, 1)
center.Parent = bg

local centerScale = Instance.new("UIScale")
centerScale.Scale = 0.94
centerScale.Parent = center

-- Hào quang xoay sau chữ. Cùng asset với nút Shop nên màn chờ trông cùng một game.
local halo = Instance.new("ImageLabel")
halo.BackgroundTransparency = 1
halo.AnchorPoint = Vector2.new(0.5, 0.5)
halo.Position = UDim2.fromScale(0.5, 0.44)
halo.Size = UDim2.fromScale(0.62, 0.62)
halo.SizeConstraint = Enum.SizeConstraint.RelativeYY
halo.Image = SUNBURST
halo.ImageColor3 = GOLD
halo.ImageTransparency = 0.88
halo.Parent = center

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.44)
title.Size = UDim2.fromScale(0.72, 0.13)
title.Font = FONT
title.Text = "+1 SPEED ESCAPE"
title.TextColor3 = GOLD
title.TextScaled = true
title.Parent = center

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new(GOLD, GOLD_DEEP)
titleGradient.Rotation = 90
titleGradient.Parent = title

local titleStroke = Instance.new("UIStroke")
titleStroke.Color = INK
titleStroke.Thickness = 5
titleStroke.Parent = title

-- Nhịp thở của tiêu đề: thứ duy nhất chuyển động liên tục. Mắt bám vào nó nên màn hình
-- không bao giờ trông như đã treo, kể cả khi thanh tiến trình đứng yên chờ mạng.
local titleScale = Instance.new("UIScale")
titleScale.Scale = 1
titleScale.Parent = title

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.565)
status.Size = UDim2.fromScale(0.6, 0.042)
status.Font = FONT
status.Text = "Loading world"
status.TextColor3 = DIM
status.TextScaled = true
status.Parent = center

--------------------------------------------------------------------------------
-- Thanh tiến trình
--------------------------------------------------------------------------------

local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 0.5)
barBg.Position = UDim2.fromScale(0.5, 0.645)
barBg.Size = UDim2.fromScale(0.4, 0.024)
barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 62)
barBg.BorderSizePixel = 0
barBg.Parent = center
local c1 = Instance.new("UICorner")
c1.CornerRadius = UDim.new(1, 0)
c1.Parent = barBg
local barStroke = Instance.new("UIStroke")
barStroke.Color = INK
barStroke.Thickness = 3
barStroke.Parent = barBg

local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = GOLD
bar.BorderSizePixel = 0
bar.Parent = barBg
local c2 = Instance.new("UICorner")
c2.CornerRadius = UDim.new(1, 0)
c2.Parent = bar
local barGradient = Instance.new("UIGradient")
barGradient.Color = ColorSequence.new(GOLD, GOLD_DEEP)
barGradient.Rotation = 90
barGradient.Parent = bar

--[[
	Thanh TRƯỢT tới mốc mới chứ không nhảy phắt.

	Các bước nạp hoàn thành rời rạc (0.08 → 0.25 → 0.6 → 0.85 → 1). Gán thẳng thì thanh giật
	từng nấc, đọc ra là "đơ rồi nhảy". Tween 0.35s làm chuyển động liên tục mà KHÔNG nói dối
	về tiến trình: nó vẫn chỉ chạy khi có việc thật hoàn thành, chỉ là đi tới đó mượt hơn.
]]
local BAR_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function setProgress(alpha: number, text: string?)
	TweenService:Create(bar, BAR_TWEEN, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) }):Play()
	if text then
		status.Text = text
	end
end

--------------------------------------------------------------------------------
-- Hoạt ảnh nền (tween lặp — không tốn Lua mỗi frame)
--------------------------------------------------------------------------------

-- Hào quang xoay đều. `math.huge` vòng lặp, engine tự chạy tới khi Instance bị huỷ.
TweenService
	:Create(halo, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
	:Play()

-- Nhịp thở tiêu đề: phóng nhẹ 1 ↔ 1.04, đảo chiều (reverses = true).
TweenService
	:Create(
		titleScale,
		TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.04 }
	)
	:Play()

-- Hào quang cũng thở, lệch pha với chữ để hai chuyển động không trùng nhịp.
TweenService:Create(
	halo,
	TweenInfo.new(2.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ ImageTransparency = 0.8 }
):Play()

-- Cụm giữa trôi vào: 0.94 → 1. Chỉ chạy một lần, tạo cảm giác màn hình "mở ra".
TweenService:Create(centerScale, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
	Scale = 1,
}):Play()

--------------------------------------------------------------------------------
-- Các bước nạp
--------------------------------------------------------------------------------

local startedAt = os.clock()

local function timedOut(): boolean
	return os.clock() - startedAt > MAX_WAIT_SECONDS
end

-- 1) Đợi nhân vật — không có nó thì không biết nạp quanh ĐÂU.
setProgress(0.08, "Waiting for character")
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local root = character:FindFirstChild("HumanoidRootPart")
while not root and not timedOut() do
	task.wait(0.1)
	root = character:FindFirstChild("HumanoidRootPart")
end

-- 2) Bước quan trọng nhất: bảo Roblox ưu tiên đẩy content quanh chỗ người chơi sắp đứng,
--    rồi CHỜ tới khi xong.
setProgress(0.25, "Streaming the world")
if root then
	pcall(function()
		localPlayer:RequestStreamAroundAsync((root :: BasePart).Position, MAX_WAIT_SECONDS)
	end)
end

-- 3) Preload asset của UI đang có. KHÔNG preload cả Workspace: với 73.809 instance thì chờ
--    hàng phút, mà phần lớn nằm ngoài tầm nhìn.
setProgress(0.6, "Preparing interface")
do
	local toPreload: { Instance } = { halo }
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, d in playerGui:GetDescendants() do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then
				table.insert(toPreload, d)
			end
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(toPreload)
	end)
end

-- 4) Vài khung hình để thứ vừa stream về kịp dựng — tránh "vào là thấy giật".
setProgress(0.88, "Almost ready")
for _ = 1, 6 do
	RunService.RenderStepped:Wait()
end

while os.clock() - startedAt < MIN_SHOW_SECONDS do
	task.wait(0.05)
end

setProgress(1, "Go!")
task.wait(0.35) -- để thanh chạy hết rồi mới mờ đi

--------------------------------------------------------------------------------
-- Mờ dần rồi bỏ
--------------------------------------------------------------------------------

local FADE = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Cụm giữa phóng nhẹ ra trong lúc mờ: cảm giác "màn hình lùi ra sau" thay vì tắt phụt.
TweenService:Create(centerScale, FADE, { Scale = 1.08 }):Play()
TweenService:Create(title, FADE, { TextTransparency = 1 }):Play()
TweenService:Create(status, FADE, { TextTransparency = 1 }):Play()
TweenService:Create(titleStroke, FADE, { Transparency = 1 }):Play()
TweenService:Create(halo, FADE, { ImageTransparency = 1 }):Play()
TweenService:Create(barBg, FADE, { BackgroundTransparency = 1 }):Play()
TweenService:Create(barStroke, FADE, { Transparency = 1 }):Play()
TweenService:Create(bar, FADE, { BackgroundTransparency = 1 }):Play()

local fade = TweenService:Create(bg, FADE, { BackgroundTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()

print(("[LoadingScreen] xong sau %.1fs"):format(os.clock() - startedAt))
