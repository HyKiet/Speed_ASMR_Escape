--!strict
--[[
	LoadingScreen.client.luau — MÀN HÌNH CHỜ LÚC VÀO GAME.

	── VẤN ĐỀ ĐANG CHỮA (user báo 2026-08-19) ────────────────────────────────────────────
	"Vào game map chưa load hết, phải chơi 5 phút map mới load xong."

	Nguyên nhân: `Workspace.StreamingEnabled = true` và bản đồ trải 6.806 × 3.756 studs với
	11.907 part trong Zones + 5.492 ở Lobby. Roblox thả người chơi vào NGAY khi khung hình
	đầu tiên dựng được, phần còn lại chảy về dần trong lúc chơi. Không có màn hình chờ thì
	người chơi thấy đúng cái quá trình đó: sàn hiện dần, vật thể bật ra giữa không trung.

	── VÌ SAO FILE NÀY NẰM Ở ReplicatedFirst ─────────────────────────────────────────────
	`ReplicatedFirst` là container DUY NHẤT được sao chép xuống client TRƯỚC mọi thứ khác, và
	`RemoveDefaultLoadingScreen()` chỉ có tác dụng nếu gọi trong vài khung hình đầu. Đặt ở
	StarterPlayerScripts là đã muộn — người chơi kịp thấy thế giới dựng dở.

	── NÓ KHÔNG PHẢI "TẢI HẾT BẢN ĐỒ" ────────────────────────────────────────────────────
	Nạp trọn 73.809 instance xuống client là đi ngược lại lý do tồn tại của streaming, và sẽ
	giết máy yếu (ngân sách bộ nhớ client trên điện thoại chỉ khoảng 1–1,5 GB, trong khi
	riêng phiên Studio đã 3 GB). Việc đúng là bảo đảm KHU VỰC NGƯỜI CHƠI ĐANG ĐỨNG luôn nạp
	xong TRƯỚC khi họ điều khiển được — phần còn lại để `StreamPrefetch` lo theo hướng chạy.

	⚠️ Hai thứ file này KHÔNG làm được, phải chỉnh tay trong Studio (Roblox đánh dấu các
	thuộc tính đó là NotScriptable — script không đọc/ghi được):
	    Workspace.StreamingIntegrityMode = PauseOutsideLoadedArea
	    Workspace.StreamingMinRadius     ≥ 1024
	    Workspace.StreamingTargetRadius  ≥ 3072
	Thiếu chúng thì file này vẫn chạy, nhưng người chơi tốc độ cao vẫn có thể vượt mặt vùng
	đã nạp. Xem README mục "Streaming".
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ⚠️ KHÔNG có hằng "bán kính nạp sẵn" ở đây: `RequestStreamAroundAsync(position, timeout)`
-- chỉ nhận toạ độ và thời gian chờ — bán kính do `Workspace.StreamingTargetRadius` quyết
-- định, mà thuộc tính đó script không đổi được. Muốn nạp rộng hơn phải chỉnh trong Studio.

-- Trần chờ. Mạng kém hay máy yếu thì vẫn phải cho vào chơi, thà thấy map dựng dở còn hơn
-- kẹt ở màn hình chờ mãi mãi — đó là cách người chơi rời game.
local MAX_WAIT_SECONDS = 20
-- Chờ tối thiểu để màn hình không chớp một cái rồi biến mất (máy mạnh + đã cache).
local MIN_SHOW_SECONDS = 1.2

local localPlayer = Players.LocalPlayer

ReplicatedFirst:RemoveDefaultLoadingScreen()

--------------------------------------------------------------------------------
-- Giao diện
--------------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedEscapeLoading"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.DisplayOrder = 10000 -- trên mọi thứ, kể cả SpotlightGui 120 / TutorialGui 130
gui.ResetOnSpawn = false
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
bg.BorderSizePixel = 0
bg.Parent = gui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.44)
title.Size = UDim2.fromScale(0.8, 0.14)
title.Font = Enum.Font.GothamBlack
title.Text = "+1 SPEED ESCAPE"
title.TextColor3 = Color3.fromRGB(255, 205, 46)
title.TextScaled = true
title.Parent = bg

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 4
stroke.Parent = title

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.56)
status.Size = UDim2.fromScale(0.6, 0.05)
status.Font = Enum.Font.GothamMedium
status.Text = "Loading world..."
status.TextColor3 = Color3.fromRGB(210, 214, 230)
status.TextScaled = true
status.Parent = bg

-- Thanh tiến trình: đây là tiến trình THẬT (tỉ lệ thời gian đã chờ so với các cột mốc đã
-- hoàn thành), không phải thanh giả chạy theo đồng hồ.
local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 0.5)
barBg.Position = UDim2.fromScale(0.5, 0.64)
barBg.Size = UDim2.fromScale(0.42, 0.022)
barBg.BackgroundColor3 = Color3.fromRGB(38, 38, 56)
barBg.BorderSizePixel = 0
barBg.Parent = bg
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = barBg

local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = Color3.fromRGB(255, 205, 46)
bar.BorderSizePixel = 0
bar.Parent = barBg
local barCorner2 = Instance.new("UICorner")
barCorner2.CornerRadius = UDim.new(1, 0)
barCorner2.Parent = bar

local function setProgress(alpha: number, text: string?)
	bar.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	if text then
		status.Text = text
	end
end

--------------------------------------------------------------------------------
-- Các bước nạp
--------------------------------------------------------------------------------

local startedAt = os.clock()

local function timedOut(): boolean
	return os.clock() - startedAt > MAX_WAIT_SECONDS
end

-- 1) Đợi nhân vật có mặt — không có nó thì không biết nạp quanh ĐÂU.
setProgress(0.08, "Waiting for character...")
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local root = character:FindFirstChild("HumanoidRootPart")
while not root and not timedOut() do
	task.wait(0.1)
	root = character:FindFirstChild("HumanoidRootPart")
end

-- 2) Nạp SẴN vùng quanh spawn. Đây là bước quan trọng nhất: `RequestStreamAroundAsync`
--    bảo Roblox ưu tiên đẩy content quanh một điểm rồi CHỜ tới khi xong.
setProgress(0.25, "Streaming world around you...")
if root then
	pcall(function()
		localPlayer:RequestStreamAroundAsync((root :: BasePart).Position, MAX_WAIT_SECONDS)
	end)
end

-- 3) Preload asset của UI đang hiển thị + những gì đã nằm trong Workspace.
--    KHÔNG preload toàn bộ Workspace: với 73.809 instance nó sẽ chờ hàng phút.
setProgress(0.6, "Preparing interface...")
do
	local toPreload: { Instance } = {}
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		for _, d in playerGui:GetDescendants() do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") or d:IsA("Sound") then
				table.insert(toPreload, d)
			end
		end
	end
	if #toPreload > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(toPreload)
		end)
	end
end

-- 4) Đợi vài khung hình để những gì vừa stream về kịp dựng, tránh "vào là thấy giật".
setProgress(0.85, "Almost there...")
for _ = 1, 6 do
	RunService.RenderStepped:Wait()
end

while os.clock() - startedAt < MIN_SHOW_SECONDS do
	task.wait(0.05)
end

setProgress(1, "Ready!")
task.wait(0.15)

--------------------------------------------------------------------------------
-- Mờ dần rồi bỏ
--------------------------------------------------------------------------------

local fade = TweenService:Create(bg, TweenInfo.new(0.45, Enum.EasingStyle.Quad), {
	BackgroundTransparency = 1,
})
for _, obj in { title, status } do
	TweenService:Create(obj, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
end
TweenService:Create(stroke, TweenInfo.new(0.35), { Transparency = 1 }):Play()
TweenService:Create(barBg, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
TweenService:Create(bar, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
fade:Play()
fade.Completed:Wait()
gui:Destroy()

print(("[LoadingScreen] xong sau %.1fs"):format(os.clock() - startedAt))
