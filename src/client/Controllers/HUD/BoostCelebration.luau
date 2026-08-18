--!strict
--[[
	BoostCelebration.luau — hiệu ứng chúc mừng toàn server khi có người mua Server Boost:
	  1. Tin nhắn hệ thống màu neon trong Chat Box.
	  2. Banner lớn giữa màn hình (scale-pop + sunburst xoay) — dùng chung với Rebirth/mua hàng.
	  3. Pháo hoa giấy (confetti) rơi đầy màn hình + âm thanh Victory.
	Trigger(playerName, boostName) được HUDController gọi khi nhận packet boostCelebration.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
	local count = if isRebirth then CONFETTI_COUNT * 2 else CONFETTI_COUNT
	for index = 1, count do
		task.delay((index - 1) * (if isRebirth then 0.02 else 0.035), function()
			if layer.Parent then
				spawnConfettiPiece(layer)
			end
		end)
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

	local rotateTween = TweenService:Create(
		sunburstLabel,
		TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 }
	)
	rotateTween:Play()

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
