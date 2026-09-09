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

--[[
	Có đang chạy ở place Live không.

	CHÉP TAY id thay vì `require(Shared.Util.Env)` — cùng lý do với bảng màu bên dưới: file
	này chạy ở `ReplicatedFirst`, TRƯỚC khi `ReplicatedStorage.Shared` chắc chắn đã tới
	client. Chờ nó là tự đánh mất lý do tồn tại của ReplicatedFirst.

	⚠️ Đổi `LIVE_PLACE_ID` trong `Shared/Util/Env.luau` thì nhớ đổi cả ở đây.
	Dùng để CÂM dòng log trên bản Live: tab Client của Developer Console ai cũng mở được.
]]
local LIVE_PLACE_ID = 94107323826144
local IS_LIVE = not RunService:IsStudio() and game.PlaceId == LIVE_PLACE_ID

-- Chép tay từ HUD/Tokens (xem lý do ở đầu file).
local INK = Color3.fromRGB(18, 18, 30)
local GOLD = Color3.fromRGB(255, 205, 46)
local GOLD_DEEP = Color3.fromRGB(255, 162, 28)

--[[
	Ảnh nền tràn màn hình (2026-08-24). Cùng tấm art với thumbnail của game, cố ý: thứ người
	chơi vừa bấm vào ở Home phải là thứ họ thấy ngay khi vào — không có một giây nào họ phải
	tự hỏi "mình vào đúng game chưa".

	⚠️ Asset ảnh trong game bị Roblox chặn cứng ở **1024×1024**. Ảnh to hơn vẫn upload được
	nhưng engine tự bóp xuống, và nó bóp xấu hơn mình tự bóp. Xuất lại thì xuất đúng 1024
	chiều rộng (1024×576 cho 16:9).

	KHÔNG đưa ảnh này vào `PreloadAsync` ở bước 3: `PreloadAsync` CHẶN, mỗi asset thêm vào đó
	là màn hình chờ dài thêm — mà cả file này tồn tại để RÚT NGẮN cảm giác chờ. Ảnh cứ để tự
	stream về; chưa về thì người chơi thấy nền gradient, về rồi thì thấy ảnh. Chờ nó là tự
	mâu thuẫn với chính mục đích của file.
]]
local BACKGROUND = "rbxassetid://97656375918556"

-- Lớp tối phủ lên ảnh. Ảnh thumbnail vốn rực rỡ và nhiều chi tiết; không có lớp này thì
-- thanh vàng chìm vào nền và màn hình đọc ra như một ảnh chụp bị treo, không ra "đang tải".
local SCRIM_TRANSPARENCY = 0.45

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

-- Nền chuyển sắc nhẹ NẰM DƯỚI ảnh: nó là thứ người chơi thấy trong khoảnh khắc ảnh chưa
-- stream về, và là bản dự phòng vĩnh viễn nếu asset lỗi. Phẳng tuyệt đối trông như màn hình
-- lỗi, một chút chiều sâu là đủ để đọc ra "đây là màn hình có chủ đích".
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new(Color3.fromRGB(28, 28, 46), INK)
bgGradient.Rotation = 90
bgGradient.Parent = bg

local photo = Instance.new("ImageLabel")
photo.BackgroundTransparency = 1
photo.Size = UDim2.fromScale(1, 1)
photo.Image = BACKGROUND
-- `Crop` chứ không phải `Stretch`: điện thoại và PC có tỉ lệ khác nhau, kéo giãn là méo mặt
-- nhân vật. Crop cắt bớt mép và giữ nguyên tỉ lệ.
photo.ScaleType = Enum.ScaleType.Crop
--[[
	⚠️ HIỆN NGAY, ĐỪNG CHỜ `IsLoaded` (sửa 2026-08-24 — bản đầu tiên KHÔNG hiện ảnh).

	Bản đầu đặt `ImageTransparency = 1` rồi định mờ dần hiện ra khi ảnh về tới nơi, bắt qua
	`GetPropertyChangedSignal("IsLoaded")`. Kết quả: ảnh **không bao giờ hiện**. Đo lại bằng
	đối chứng ba mức trong suốt (1 · 0,99 · 0), cùng asset, cùng cây GUI, chờ 3 giây mỗi lần:

	    ImageTransparency = 1      IsLoaded=false  signal bắn 0 lần
	    ImageTransparency = 0.99   IsLoaded=false  signal bắn 0 lần
	    ImageTransparency = 0      IsLoaded=false  signal bắn 0 lần

	`IsLoaded` đứng nguyên `false` ở CẢ BA, và signal chưa bao giờ bắn — kể cả với asset đã
	nằm trong cache. Nên nó không dùng làm điều kiện hiện hình được. (Cùng một bài học đã gặp
	trước đó trong phiên này: `ContentProvider:PreloadAsync` báo Success cho 22 ảnh trong khi
	`IsLoaded` của cả 22 vẫn là false.)

	Cách đúng lại đơn giản hơn: để `ImageTransparency = 0` ngay từ đầu. Texture chưa về thì
	ImageLabel không vẽ gì cả — đúng bằng cái nền gradient bên dưới — rồi ảnh về là hiện.
	Không có bước "bụp" nào đáng lo, vì thứ nó thay thế cũng là màu tối.
]]
photo.ImageTransparency = 0
photo.Parent = bg

local scrim = Instance.new("Frame")
scrim.Size = UDim2.fromScale(1, 1)
scrim.BackgroundColor3 = INK
scrim.BackgroundTransparency = SCRIM_TRANSPARENCY
scrim.BorderSizePixel = 0
scrim.Parent = bg

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

--------------------------------------------------------------------------------
-- Thanh tiến trình
--------------------------------------------------------------------------------

local barBg = Instance.new("Frame")
barBg.AnchorPoint = Vector2.new(0.5, 0.5)
--[[
	Thanh nằm THẤP, không nằm giữa (sửa 2026-08-24 sau khi nhìn ảnh chụp thật).

	Bỏ chữ xong tôi đưa thanh về giữa màn hình (0.5) vì "không còn gì để nằm dưới". Chụp lại
	màn hình chờ đang chạy thì thấy hậu quả: thanh **cắt ngang giữa ngực nhân vật** trong ảnh
	nền — đúng điểm nhìn của cả tấm art.

	0.85 đưa thanh xuống dưới chân nhân vật, chừa trọn phần art cho mắt. Đây cũng là chỗ mắt
	người quen tìm thanh tiến trình.

	⚠️ Ảnh nền thay đổi thì kiểm lại con số này bằng ảnh chụp, đừng chỉnh mù.
]]
barBg.Position = UDim2.fromScale(0.5, 0.85)
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

--[[
	`label` KHÔNG còn hiện lên màn hình (nhãn trạng thái đã gỡ 2026-08-24), nhưng vẫn giữ
	tham số: nó là thứ duy nhất cho biết màn hình chờ TREO Ở BƯỚC NÀO. Không có nó thì một
	phiên chờ 20 giây chỉ để lại đúng một dòng "xong sau 20.0s" — không truy được gì.
]]
local lastStep = "start"
local function setProgress(alpha: number, label: string?)
	TweenService:Create(bar, BAR_TWEEN, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) }):Play()
	if label then
		lastStep = label
	end
end

--------------------------------------------------------------------------------
-- Hoạt ảnh nền (tween lặp — không tốn Lua mỗi frame)
--------------------------------------------------------------------------------

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

local function loadContent()
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
		local toPreload: { Instance } = {}
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			for _, d in playerGui:GetDescendants() do
				-- ⚠️ LOẠI TRỪ `photo` — nó nằm TRONG PlayerGui nên vòng quét này gom trúng nó.
				-- Chờ ảnh nền của chính màn hình chờ là tự mâu thuẫn: `PreloadAsync` chặn, nên
				-- màn hình chờ sẽ đứng thêm đúng bằng thời gian tải tấm ảnh mà nó đang hiển thị.
				-- Ảnh tự tải và hiển thị khi sẵn sàng, không chờ tín hiệu IsLoaded.
				if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d ~= photo then
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
end

-- Trần chờ phải bao cả CharacterAdded và PreloadAsync, vì hai lời gọi này có thể yield lâu.
local loadingDone = false
local loadingThread = task.spawn(function()
	local ok, err = pcall(function()
		loadContent()
		return true
	end)
	if not ok then
		warn(`[LoadingScreen] {lastStep}: {err}`)
	end
	loadingDone = true
end)
while not loadingDone and not timedOut() do
	task.wait(0.05)
end
local timedOutAt = if not loadingDone then lastStep else nil
if timedOutAt and coroutine.status(loadingThread) == "suspended" then
	task.cancel(loadingThread)
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
TweenService:Create(photo, FADE, { ImageTransparency = 1 }):Play()
TweenService:Create(scrim, FADE, { BackgroundTransparency = 1 }):Play()
TweenService:Create(barBg, FADE, { BackgroundTransparency = 1 }):Play()
TweenService:Create(barStroke, FADE, { Transparency = 1 }):Play()
TweenService:Create(bar, FADE, { BackgroundTransparency = 1 }):Play()

local fade = TweenService:Create(bg, FADE, { BackgroundTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()

do
	local elapsed = os.clock() - startedAt
	-- ReplicatedFirst chạy TRƯỚC khi `Shared` chắc chắn tới nơi nên KHÔNG require `Log` được
	-- ở đây (xem cảnh báo đầu file). Tự kiểm môi trường bằng PlaceId thay vì qua Env.
	if not IS_LIVE then
		print(("[LoadingScreen] done in %.1fs (last step: %s)"):format(elapsed, lastStep))
	end
	-- Chạm trần chờ nghĩa là có bước không bao giờ xong — `lastStep` chỉ đúng chỗ đó.
	if timedOutAt then
		warn(("[LoadingScreen] HIT %ds CAP — stuck at step %q"):format(MAX_WAIT_SECONDS, timedOutAt))
	end
end
