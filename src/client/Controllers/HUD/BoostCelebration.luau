--!strict
--[[
	BoostCelebration.luau — hiệu ứng chúc mừng toàn server khi có người mua Server Boost:
	  1. Tin nhắn hệ thống màu neon trong Chat Box.
	  2. Banner lớn giữa màn hình (scale-pop + sunburst xoay) — dùng chung với Rebirth/mua hàng.
	  3. Pháo hoa giấy (confetti) rơi đầy màn hình + âm thanh Victory.
	Trigger(playerName, boostName) được HUDController gọi khi nhận packet boostCelebration.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.State)
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
local FROZEN_BLOOM_ICON = "rbxassetid://108748255826046"

-- TÊN VIẾT HOA → icon. Dựng từ CHÍNH các nguồn đang bán món đó, không chép tay số nào:
--   • `Theme.SHOP_CATALOG` — treadmill, VIP, Auto-Rebirth, Infinite Revives, gói Wins…
--   • `Constants.TRAILS` / `AURAS` — field `icon` trong Config/Economy.
--   • `Theme.SPEED_PASS_TIERS` — field `icon` riêng từng bậc x2/x4/x8 (giày có số bậc trên
--     thân); tier nào chưa có icon thì rơi về icon giày chung.
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
		ICON_BY_NAME[string.upper(tier.label) .. " GAMEPASS"] = tier.icon or Theme.UI_ASSETS.Shoe
	end
	-- Frozen Bloom chỉ rơi từ Roulette nên không nằm trong shop lẫn `icon` config.
	ICON_BY_NAME["FROZEN BLOOM"] = FROZEN_BLOOM_ICON
	-- Starter Pack bán bằng Developer Product nên KHÔNG có thẻ trong `SHOP_CATALOG` — không
	-- khai ở đây thì nó rơi về icon tia sét chung (xem tên gửi đi ở StarterPackService).
	ICON_BY_NAME["STARTER PACK"] = Theme.UI_ASSETS.StarterPack
	-- ServerBoostService gửi tên theo BOOST_NAMES phía server, KHÔNG trùng tiêu đề shop
	-- ("MEGA BOOST x2 ALL" vs "MEGA Boost (x2 Both)") nên phải khai báo thẳng, nếu không
	-- MEGA rơi về icon tia sét chung.
	ICON_BY_NAME["SERVER X2 SPEED"] = Theme.UI_ASSETS.BoostSpeed
	ICON_BY_NAME["SERVER X2 WINS"] = Theme.UI_ASSETS.BoostWins
	ICON_BY_NAME["MEGA BOOST X2 ALL"] = Theme.UI_ASSETS.BoostMega
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

--[[
	══ CONFETTI — VIẾT LẠI CHO 60 FPS (2026-08-19) ═════════════════════════════════════════

	User đo được: FPS 47.1, Render 5.6 ms / 27% ở đúng khoảnh khắc "confetti + LEVEL UP +
	COMBO x2 chồng nhau". Bản cũ, mỗi lần ăn mừng cỡ lớn:

	  • 92 × `Instance.new("Frame")` + 92 × `Instance.new("UICorner")` = 184 instance được
	    TẠO rồi HUỶ trong ~4 giây. Tạo/huỷ instance là việc nặng nhất trong cả hiệu ứng, và
	    nó rơi đúng vào frame mà popup lên cấp cũng đang dựng.
	  • 92 × `task.delay` (hàng đợi rải hạt) + 92 × `TweenService:Create` = 184 mục nữa nằm
	    trong bộ lịch của engine, mỗi mục ghi 2 thuộc tính mỗi frame.
	  • Không có TRẦN nào cả. LevelUp có `MAX_LIVE_DOTS`, confetti thì không — nên combo x2
	    lên cấp liên tiếp + mua hàng là số hạt cộng dồn không giới hạn.

	Bản mới giữ NGUYÊN hiệu ứng nhìn thấy (vẫn rơi, vẫn xoay, vẫn dạt ngang, vẫn rải so le)
	nhưng đổi ba thứ bên dưới:

	  1. BỂ TÁI DÙNG — hạt tạo một lần rồi chỉ bật/tắt. Sau cú ăn mừng đầu tiên thì mọi cú
	     sau KHÔNG tạo instance nào nữa. Cùng bài học đã áp cho LevelUp (xem `MAX_LIVE_DOTS`).
	  2. BỎ `UICorner` — hạt to 10–22 px, bo góc 3 px ở cỡ đó mắt không thấy, mà nó nhân đôi
	     số instance và đẩy mỗi hạt sang đường vẽ bo góc riêng.
	  3. MỘT vòng lặp duy nhất thay cho 92 tween + 92 `task.delay`. Vòng lặp này tự ngắt khi
	     hết hạt, nên lúc không ăn mừng thì chi phí bằng 0 tuyệt đối.

	Và thêm `CONFETTI_CAP` — trần hạt sống cùng lúc, đúng vai trò `MAX_LIVE_DOTS` bên LevelUp:
	đây mới là thứ chặn được cảnh chồng nhau mà user đo được.
]]
local CONFETTI_COUNT = 34
local CONFETTI_COUNT_BIG = 56
local CONFETTI_CAP = 60
-- Performance mode (Cài đặt) hạ thêm một nấc: người bật nó là người máy yếu.
local CONFETTI_PERF_SCALE = 0.45
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

--[[
	Tween xoay của sunburst trên thẻ chúc mừng. Giữ ở tầm module để `showBanner` bật và cái
	hẹn giờ ẩn thẻ TẮT nó đi được.

	Bản cũ gọi `:Play()` một lần lúc `Build` rồi cho chạy VĨNH VIỄN với `RepeatCount = -1` —
	tức là suốt cả phiên chơi, engine vẫn ghi `Rotation` 60 lần/giây cho một ImageLabel nằm
	trong CanvasGroup `Visible = false`. Không thấy được gì, nhưng mỗi lần ghi vẫn đánh dấu
	bẩn cả CanvasGroup. Thẻ chỉ hiện ~4.8 giây mỗi lần mua, nên 99% thời gian là ghi thừa.
]]
local bannerSpin: Tween? = nil

local function sendChatMessage(playerName: string, boostName: string)
	task.spawn(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general and general:IsA("TextChannel") then
			general:DisplaySystemMessage(
				`<font color="#39FF88"><b>[BOOST]</b> Thanks <font color="#FFDD33">{playerName}</font> for activating <font color="#66DDFF">{boostName}</font> for the whole server!</font>`
			)
		end
	end)
end

-- 2026-08-12: banner boost thường dùng CHUNG âm rebirth (Theme.UI_ASSETS.CelebrationSound).
-- Tham số `isRebirth` giữ lại để phân biệt sắc thái (pitch), không còn đổi asset nữa.
local function playVictorySound(isRebirth: boolean)
	local sound = Instance.new("Sound")
	sound.SoundId = Theme.UI_ASSETS.CelebrationSound
	sound.PlaybackSpeed = if isRebirth then 1 else 1.08
	sound.Volume = 0.85
	sound.PlayOnRemove = false
	sound.Parent = confettiLayer
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

--[[
	── BỂ HẠT + VÒNG LẶP DUY NHẤT ─────────────────────────────────────────────────────────

	`pool`  : hạt rảnh, `Visible = false`, chờ tái dùng.
	`live`  : hạt đang bay, mỗi phần tử mang sẵn cả quỹ đạo của nó (không hỏi lại RNG).
	`queue` : hạt CHƯA tới lượt xuất hiện — thay cho 92 cái `task.delay` của bản cũ.

	Quỹ đạo tính bằng tay chứ không nhờ `TweenService`: hạt rơi TUYẾN TÍNH (easing Linear,
	đúng như bản cũ) nên vị trí chỉ là một phép nội suy theo `t / fallTime`. Một vòng lặp
	ghi 60 vị trí rẻ hơn hẳn 60 tween, và quan trọng hơn là ta GIỮ ĐƯỢC QUYỀN cắt bớt: chạm
	`CONFETTI_CAP` thì hạt già nhất bị thu hồi ngay, không đợi tween của nó chạy hết.
]]
type Piece = {
	frame: Frame,
	startX: number,
	startY: number,
	drift: number,
	fallTime: number,
	rot0: number,
	spin: number,
	t: number,
}

local pool: { Frame } = {}
local live: { Piece } = {}
-- Mỗi phần tử là mốc thời gian (giây, tính từ lúc bắt đầu vòng lặp) mà hạt kế tiếp xuất hiện.
local queue: { number } = {}
local queueClock = 0
local driver: RBXScriptConnection? = nil

local FALL_END = 0
local function fallEnd(): number
	if FALL_END == 0 then
		FALL_END = Theme.DESIGN_HEIGHT + 60
	end
	return FALL_END
end

local function releasePiece(piece: Piece)
	piece.frame.Visible = false
	table.insert(pool, piece.frame)
end

local function acquireFrame(parent: Frame): Frame
	local reused = table.remove(pool)
	if reused then
		return reused
	end
	-- KHÔNG có `UICorner`: xem khối lý do ở `CONFETTI_COUNT`.
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 210
	frame.Parent = parent
	return frame
end

local function launchPiece(parent: Frame)
	-- Chạm trần: thu hồi hạt GIÀ NHẤT (đang ở cuối đường rơi, sát mép dưới màn hình) — đó là
	-- hạt ít bị nhìn thấy nhất. Cùng luật với `MAX_LIVE_DOTS` của LevelUp.
	if #live >= CONFETTI_CAP then
		local oldest = table.remove(live, 1)
		if oldest then
			releasePiece(oldest)
		end
	end

	local frame = acquireFrame(parent)
	local size = rng:NextInteger(10, 22)
	local startX = rng:NextInteger(0, Theme.DESIGN_WIDTH)
	local startY = -40 - rng:NextInteger(0, 240)
	local rot0 = rng:NextInteger(0, 360)

	frame.BackgroundColor3 = CONFETTI_COLORS[rng:NextInteger(1, #CONFETTI_COLORS)]
	frame.Size = UDim2.fromOffset(size, math.max(6, size // 2))
	frame.Position = UDim2.fromOffset(startX, startY)
	frame.Rotation = rot0
	frame.Visible = true

	table.insert(live, {
		frame = frame,
		startX = startX,
		startY = startY,
		drift = rng:NextInteger(-220, 220),
		fallTime = rng:NextNumber(2.2, 4.2),
		rot0 = rot0,
		spin = rng:NextInteger(240, 720) * (if rng:NextNumber() < 0.5 then -1 else 1),
		t = 0,
	})
end

local function stopDriver()
	if driver then
		driver:Disconnect()
		driver = nil
	end
end

local function stepConfetti(dt: number)
	local layer = confettiLayer
	if not layer or not layer.Parent then
		for index = #live, 1, -1 do
			releasePiece(live[index])
			live[index] = nil
		end
		table.clear(queue)
		stopDriver()
		return
	end

	-- 1. Thả những hạt đã tới lượt. `queue` xếp tăng dần nên chỉ cần xét từ đầu.
	queueClock += dt
	while queue[1] and queue[1] <= queueClock do
		table.remove(queue, 1)
		launchPiece(layer)
	end

	-- 2. Đẩy hạt đang bay. Duyệt NGƯỢC để xoá tại chỗ không lệch chỉ số.
	local endY = fallEnd()
	for index = #live, 1, -1 do
		local piece = live[index]
		piece.t += dt
		local alpha = piece.t / piece.fallTime
		if alpha >= 1 then
			releasePiece(piece)
			table.remove(live, index)
		else
			local frame = piece.frame
			frame.Position =
				UDim2.fromOffset(piece.startX + piece.drift * alpha, piece.startY + (endY - piece.startY) * alpha)
			frame.Rotation = piece.rot0 + piece.spin * alpha
		end
	end

	-- 3. Hết việc thì NGẮT HẲN — lúc không ăn mừng, hiệu ứng này tốn đúng 0.
	if #live == 0 and #queue == 0 then
		stopDriver()
	end
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
-- ĐÃ GỠ (2026-08-07, yêu cầu user): toàn bộ hệ chúc mừng Server Boost kiểu 3D —
--   • 10 quả pháo hoa 3D bắn lên từ chân màn hình (launchFirework3D/fireworkBurst3D)
--   • Màn hình SurfaceGui treo trên bầu trời tại Transition1To2 (showServerBoostInfo)
--   • Folder ClientFireworksFX trong Workspace, PointLight, sound pop 3D
-- Thay bằng ĐÚNG banner UI mà Rebirth/mua hàng đang dùng (showBanner) — chỉ khác là
-- server phát cho MỌI client chứ không riêng người mua. Lý do đổi: hiệu ứng 3D chỉ nhìn
-- thấy được khi người chơi đang ở Lobby và quay mặt đúng hướng cổng Zone 1; ai đang chạy
-- obby ở zone xa thì không thấy gì cả (code còn tự cull ở 700 studs). Banner UI thì ai
-- cũng thấy, ở bất kỳ đâu trong map.
-- ══════════════════════════════════════════════════════════════════════════

local function burstConfetti(isRebirth: boolean)
	local layer = confettiLayer
	if not layer then
		return
	end

	local count = if isRebirth then CONFETTI_COUNT_BIG else CONFETTI_COUNT
	if State.performanceMode:get() then
		count = math.max(8, math.floor(count * CONFETTI_PERF_SCALE))
	end

	--[[
		Ăn mừng CHỒNG LÊN nhau (mua hàng ngay giữa lúc combo lên cấp — đúng cảnh user đo được
		47 FPS): không cộng dồn vô hạn nữa. Chỗ còn trống tính theo trần, phần thừa bỏ đi.
		Bỏ đi là ĐÚNG chứ không phải cắt bớt cho rẻ: 60 hạt đã phủ kín màn hình rồi, hạt thứ
		61 không thêm được gì cho mắt mà vẫn ăn đủ chi phí.
	]]
	local room = CONFETTI_CAP - (#live + #queue)
	if room <= 0 then
		return
	end
	count = math.min(count, room)

	-- Rải so le y như bản cũ (0.02s/hạt khi lớn, 0.035s khi thường) — nhưng bằng một hàng
	-- đợi mốc thời gian chứ không phải `count` cái `task.delay`.
	local gap = if isRebirth then 0.02 else 0.035
	local base = queueClock
	for index = 1, count do
		table.insert(queue, base + (index - 1) * gap)
	end
	table.sort(queue)

	if not driver then
		driver = RunService.RenderStepped:Connect(stepConfetti)
	end
end

-- `big` = màn ăn mừng cỡ lớn (rebirth / server boost): gấp đôi confetti, rơi dày gấp đôi,
-- nhạc riêng. Mua hàng thường thì để nhỏ cho khỏi loãng.
local function showBanner(title: string, subtitle: string, big: boolean?)
	local isBig = big == true or string.find(string.upper(title), "REBIRTH") ~= nil
	currentIsRebirth:set(isBig)

	playVictorySound(isBig)
	burstConfetti(isBig)

	bannerTitle:set(title)
	bannerSubtitle:set(subtitle)
	bannerVisible:set(true)
	bannerScaleGoal:set(1)
	if bannerSpin then
		bannerSpin:Play()
	end

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
				-- `Pause` chứ không `Cancel`: giữ nguyên góc đang xoay, lần sau chạy tiếp từ đó
				-- nên không có cú giật về 0 độ ngay khi thẻ vừa trượt vào.
				if bannerSpin then
					bannerSpin:Pause()
				end
			end
		end)
	end)
end

--[[
	SERVER BOOST (2026-08-07) — hiện trên MỌI client, dùng ĐÚNG banner UI của Rebirth:
	  1. Chớp vàng toàn màn hình — báo "sự kiện lớn" tức thì, kể cả khi đang nhìn chỗ khác
	  2. Banner giữa màn hình: icon món boost + sunburst xoay + tên người mua
	  3. Confetti dày (cỡ `big`) + nhạc chúc mừng
	  4. Tin nhắn chat neon cảm ơn người mua

	Bản 3D cũ (pháo hoa + màn hình treo trên bầu trời tại Transition1To2) đã GỠ HẲN: nó chỉ
	nhìn thấy được nếu người chơi đang ở Lobby VÀ quay đúng hướng cổng Zone 1, và còn tự cull
	ở 700 studs — nghĩa là gần như cả server đang chạy obby thì không ai thấy gì.
]]
function BoostCelebration.Trigger(playerName: string, boostName: string)
	sendChatMessage(playerName, boostName)
	goldenFlash()
	-- `showBanner` tự phát nhạc; gọi playVictorySound ở đây nữa là chồng 2 tiếng vào cùng frame.
	showBanner(boostName, `🎉 Activated by {playerName} — thanks! • WHOLE SERVER • 10 MINUTES`, true)
end

-- Mua gamepass/treadmill/rebirth thành công: chỉ hiện cho BUYER (kích thích lặp lại hành vi).
function BoostCelebration.TriggerPurchase(itemName: string, subtitle: string?)
	showBanner(itemName, subtitle or "Purchase successful — enjoy your power!")
end

--[[
	PHẦN THƯỞNG RƠI RA cỡ lớn — chớp vàng toàn màn hình + banner `big` (confetti dày, nhạc trầm).

	Hiện chưa có nơi gọi: đã dựng cho vòng quay rồi user chốt là chỉ Frozen Bloom mới được ăn
	mừng, mà Frozen Bloom dùng `TriggerPurchase`. Giữ lại vì Daily/Group Chest là hai chỗ tiếp
	theo có thể cần — nhưng ĐỪNG nối nó lại vào vòng quay (xem khối lý do trong RouletteModal).
]]
function BoostCelebration.TriggerReward(rewardName: string, subtitle: string, big: boolean?)
	if big then
		goldenFlash()
	end
	showBanner(rewardName, subtitle, big)
end

--[[
	HOOK NGHIỆM THU TRONG STUDIO — cùng kiểu với `StudioTestSpin` / `StudioTutorialFinale`.

	Đặt thuộc tính `StudioTestCelebration` lên LocalPlayer là chạy đúng hiệu ứng thật:
	    "buy"  → banner mua hàng thường (confetti thưa)
	    "big"  → cỡ Server Boost: chớp vàng + confetti dày + nhạc
	    "spam" → bắn 6 cú liên tiếp cách nhau 0.15s, tức ĐÚNG cảnh chồng nhau đã làm tụt FPS

	Phải đi qua attribute chứ không gọi thẳng hàm: `execute_luau` chạy trong một VM riêng, nên
	`require` từ đó sẽ nạp một BẢN SAO của module này — bản sao ấy chưa từng gọi `Build` nên
	`confettiLayer` là nil và không có gì hiện ra. Attribute nằm trên Instance nên mọi VM đều
	ghi/đọc được (bài học đã ghi lại ở TutorialController).
]]
local function bindStudioHook()
	if not RunService:IsStudio() then
		return
	end
	local Players = game:GetService("Players")
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end
	localPlayer:GetAttributeChangedSignal("StudioTestCelebration"):Connect(function()
		local mode = localPlayer:GetAttribute("StudioTestCelebration")
		if type(mode) ~= "string" then
			return
		end
		localPlayer:SetAttribute("StudioTestCelebration", nil)
		if mode == "big" then
			BoostCelebration.Trigger("QA_Tester", "MEGA BOOST X2 ALL")
		elseif mode == "spam" then
			task.spawn(function()
				for index = 1, 6 do
					BoostCelebration.TriggerPurchase(`QA STRESS {index}`, "stress test")
					task.wait(0.15)
				end
			end)
		else
			BoostCelebration.TriggerPurchase("PURPLE TREADMILL", "Purchase successful — enjoy your power!")
		end
	end)
end

function BoostCelebration.Build()
	bindStudioHook()

	-- Lớp confetti phủ toàn canvas (không bắt chuột).
	local layer = New("Frame")({
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Theme.DESIGN_WIDTH, Theme.DESIGN_HEIGHT),
		ZIndex = 205,
	}) :: Frame
	confettiLayer = layer

	--[[
		══ THẺ CHÚC MỪNG — THIẾT KẾ LẠI 2026-08-14 ══════════════════════════════════════════

		Bản cũ: khối 1150×450 giữa màn hình, icon 210px + sunburst 380px, chữ căn giữa xếp dọc.
		Ba vấn đề, và cả ba đều tệ hơn trên điện thoại:
		  • Nó CHE TẦM NHÌN. 1150×450 là 60%% bề ngang và 42%% chiều cao canvas — người chơi đang
		    chạy obby ở 200 WS bị bịt mắt 4.5 giây. Ở tốc độ đó, 4.5 giây là rơi.
		  • Nó ĐÁNH NHAU với popup lên cấp. Đã phải thêm cơ chế tách làn (banner tụt xuống 640)
		    chỉ để hai thứ không đè nhau — chữa triệu chứng, không chữa nguyên nhân là "cả hai
		    đều quá to".
		  • Sunburst 380px xoay liên tục + 92 mảnh confetti là chi phí vẽ thường trực.

		Bản mới — THẺ NGANG GỌN, neo ĐÁY-GIỮA, ngay trên thanh XP:
		  620×132 (chưa bằng 1/6 diện tích cũ), icon 96px bên TRÁI, tiêu đề + dòng phụ xếp bên
		  PHẢI theo chiều ngang — đúng dạng thẻ phần thưởng mà các simulator lớn dùng, và đọc
		  được trong một cú liếc vì mắt quét ngang nhanh hơn quét dọc.

		Vì sao ĐÁY chứ không phải giữa: giữa màn hình là nơi người chơi NHÌN ĐƯỜNG. Đáy đã là
		vùng HUD (thanh XP, chỉ số Speed) nên mắt vốn đã liếc xuống đó, và nó không giao với
		popup lên cấp ở trên — bỏ được luôn cơ chế tách làn.

		Sunburst thu còn 190px và chỉ nằm sau icon (vẫn giữ được nhịp "toả sáng" mà không phủ
		nền). Confetti + chớp vàng + nhạc giữ nguyên: đó mới là phần "đã tay", và chúng không
		chiếm chỗ cố định trên màn hình.
	]]
	local CARD_WIDTH = 540
	local bannerSize = UDim2.fromOffset(CARD_WIDTH, 124)

	--[[
		TRƯỢT VÀO TỪ GÓC PHẢI-TRÊN (user chốt 2026-08-14).

		Đây là dạng "achievement toast" mà phần lớn game lớn dùng, và nó hợp ở đây vì hai lẽ:
		  • Góc phải-trên KHÔNG phải nơi người chơi nhìn khi chạy — mắt bám đường ở giữa màn
		    hình. Thẻ hiện ra trong tầm nhìn ngoại vi: thấy được mà không che lối.
		  • CHUYỂN ĐỘNG NGANG tự nó là tín hiệu. Thẻ đứng yên ở góc dễ bị bỏ qua; thẻ trượt vào
		    thì mắt bắt được ngay cả khi đang tập trung chỗ khác.

		Trượt theo `bannerScale` (Tween sẵn có, Back/Out): scale 0 ⇒ thẻ nằm hẳn ngoài mép phải,
		scale 1 ⇒ dừng cách mép 24px. Easing `Back` cho cú "va nhẹ rồi ổn định" ở cuối đường
		trượt — cùng nhịp với mọi hoạt ảnh khác trong HUD.

		Neo theo `GetVisibleDesignBounds` chứ không phải mép canvas 1920×1080: `top` đã trừ sẵn
		topbar Roblox và `right` là mép THẬT của màn hình, nên trên máy tỉ lệ nào thẻ cũng nằm
		đúng góc phải-trên nhìn thấy được.
	]]
	local bannerPosition = Computed(function()
		local _, top, right = Theme.GetVisibleDesignBounds()
		local slide = (1 - bannerScale:get()) * (CARD_WIDTH + 80)
		return UDim2.fromOffset(right - 24 + slide, top + 20)
	end)
	local bgTransparency = 0.1

	local lightningPosition = UDim2.fromOffset(66, 62)
	local lightningSize = UDim2.fromOffset(88, 88)

	local sunburstPosition = UDim2.fromOffset(66, 62)
	local sunburstSize = UDim2.fromOffset(176, 176)

	-- Chữ xếp bên PHẢI icon, căn trái — mắt đọc từ icon sang chữ thành một dòng liền.
	local titlePosition = UDim2.new(0, 132, 0, 20)
	local titleSize = UDim2.new(1, -156, 0, 50)
	local titleXAlign = Enum.TextXAlignment.Left

	local subtitlePosition = UDim2.new(0, 132, 0, 70)
	local subtitleSize = UDim2.new(1, -156, 0, 36)
	local subtitleXAlign = Enum.TextXAlignment.Left

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

	-- CHƯA chạy ở đây: `showBanner` bật, hẹn giờ ẩn thẻ tắt (xem `bannerSpin`).
	bannerSpin = TweenService:Create(
		sunburstLabel,
		TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 }
	)

	local banner = New("CanvasGroup")({
		-- Neo mép PHẢI-TRÊN của chính thẻ: `Position` trả về toạ độ góc phải-trên nên thẻ trượt
		-- ra/vào theo trục X mà không phải bù nửa chiều rộng ở mọi phép tính.
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(22, 14, 38),
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
					-- Chuyển động chính là TRƯỢT NGANG (xem `bannerPosition`), nên phần phóng to chỉ
					-- còn là gia vị: 0.96 → 1.0. Pop mạnh cộng với trượt là hai chuyển động đánh nhau.
					return 0.96 + 0.04 * bannerScale:get()
				end),
			}),
			Theme.MakeCorner(20),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),

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
				MaxTextSize = 40,
				ZIndex = 211,
			}),

			Theme.MakeOutlineLabel({
				Position = subtitlePosition,
				Size = subtitleSize,
				Text = bannerSubtitle,
				TextColor3 = Color3.fromRGB(190, 255, 220),
				TextXAlignment = subtitleXAlign,
				MaxTextSize = 26,
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
