--!strict
--[[
	══════════════════════════════════════════════════════════════════════════════════════════
	  Spotlight — LÀM TỐI CẢ MÀN HÌNH, CHỪA ĐÚNG MỘT Ô SÁNG
	══════════════════════════════════════════════════════════════════════════════════════════

	Dùng cho tutorial: thay vì viết "bấm nút Daily ở bên trái" rồi hy vọng người chơi tìm ra, ta
	tối cả màn hình và chỉ chừa đúng cái nút đó sáng. Không đọc chữ vẫn biết phải bấm đâu.

	── HÌNH HỌC: BỐN TẤM CHE, KHÔNG PHẢI MỘT TẤM CÓ LỖ ────────────────────────────────────────
	Roblox không có "khoét lỗ" trên GuiObject (không stencil, không mask ngược). Cách chuẩn của
	mọi game Roblox là ghép BỐN tấm quanh ô sáng:

	    ┌───────────────────────────────┐
	    │             TRÊN              │
	    ├───────┬───────────────┬───────┤
	    │ TRÁI  │   Ô SÁNG      │ PHẢI  │   ← ô sáng không có tấm nào phủ
	    ├───────┴───────────────┴───────┤
	    │             DƯỚI              │
	    └───────────────────────────────┘

	Bốn tấm là `TextButton` chứ không phải `Frame`: chúng phải NUỐT mọi cú chạm ngoài ô sáng
	(user chốt 2026-08-17 "chặn — chỉ bấm được chỗ đang sáng"). Nhờ đó không ai bấm nhầm sang
	việc khác giữa chừng tutorial, và tỉ lệ hoàn thành cao hơn hẳn.

	── VÌ SAO Ở MỘT `ScreenGui` RIÊNG, VÀ THỨ TỰ DISPLAYORDER ─────────────────────────────────
	    CoreLoopHUD    0    ← HUD + modal: BỊ làm tối
	    SpotlightGui   120  ← bốn tấm che
	    TutorialGui    130  ← dải nhắc + nút SKIP: KHÔNG bị tối, và luôn bấm được

	Dải nhắc phải nằm TRÊN lớp tối, nếu không câu hướng dẫn bị mờ đi đúng lúc cần đọc nhất, và
	nút SKIP thì bị lớp che nuốt mất — người chơi kẹt cứng trong tutorial, không có đường ra.

	── TOẠ ĐỘ Ở ĐÂY LÀ PX THẬT, KHÔNG PHẢI DESIGN PX ──────────────────────────────────────────
	Ô sáng lấy từ `AbsolutePosition`/`AbsoluteSize` của chính cái nút — đó là pixel màn hình.
	Nên `ScreenGui` này KHÔNG có `UIScale`. Chỉ những số do ta tự đặt (lề quanh ô, độ dày vành)
	mới là design px và phải nhân `viewportScale` — xem `px()`.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.State)
local Tokens = require(script.Parent.Tokens)

local LocalPlayer = Players.LocalPlayer

local Spotlight = {}

-- Độ tối của phần bị che. 0.45 = còn thấy lờ mờ khung cảnh phía sau (người chơi không mất
-- phương hướng), nhưng đủ tương phản để ô sáng bật hẳn lên.
local DIM = 0.45
local FADE = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--[[
	Lề quanh ô sáng + độ dày vành, tính bằng DESIGN px (bản vẽ 1920×1080) — KÈM SÀN PX THẬT.

	⚠️ Vì sao phải có sàn, khác với mọi số đo khác của HUD: hai giá trị này không phải "kích
	thước nội dung" mà là ĐỘ NHẤN THỊ GIÁC. Co chúng theo bản vẽ thì trên điện thoại (tỉ lệ
	0.36) vành chỉ còn 1.8 px và lề còn 5 px — đo thật ở 801×392: lỗ sáng 59×55 px với một
	đường viền mảnh như sợi chỉ. Người chơi không đọc ra "chỗ này đang được chỉ", tức là
	spotlight mất tác dụng đúng trên thiết bị mà nó cần nhất (user 2026-08-17).

	Sàn chỉ ăn trên máy nhỏ: ở tỉ lệ 1.0 thì 14 > 8 và 5 > 3, nên PC không đổi một pixel nào.
]]
local PADDING = 14
local PADDING_MIN_PX = 8
local RING_THICKNESS = 5
local RING_MIN_PX = 3
local RING_RADIUS = 16

local screenGui: ScreenGui? = nil
local shades: { [string]: TextButton } = {}
local ring: Frame? = nil
local ringStroke: UIStroke? = nil

local currentTarget: GuiObject? = nil
local followConn: RBXScriptConnection? = nil
local pulseClock = 0
local shown = false

-- Design px → px thật. Cùng luật với cả HUD: số của bản vẽ thì nhân `viewportScale`.
local function px(designValue: number): number
	return designValue * State.viewportScale:get()
end

-- Như `px` nhưng KHÔNG bao giờ nhỏ hơn `minPx` pixel thật (xem khối lý do ở `PADDING`).
local function emphasisPx(designValue: number, minPx: number): number
	return math.max(designValue * State.viewportScale:get(), minPx)
end

local function build()
	if screenGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpotlightGui"
	gui.DisplayOrder = 120
	gui.IgnoreGuiInset = true
	--[[
		⚠️ `IgnoreGuiInset` KHÔNG ĐỦ — đây là nguyên nhân "hai mép và cạnh dưới không bị tối"
		(user 2026-08-18, ảnh chụp trên máy giả lập điện thoại).

		`IgnoreGuiInset = true` chỉ bỏ topbar; Roblox quy nó về `ScreenInsets.DeviceSafeInsets`,
		tức là vẫn NÉ vùng tai thỏ + vạch home của máy. Đo thật trong Studio (iPhone ngang):

		    ScreenGui DeviceSafeInsets → absPos (0, −58)   absSize 801×392
		    ScreenGui None             → absPos (−47, −58) absSize 895×413

		Bốn tấm che được cắt theo `AbsoluteSize`, nên chúng hụt đúng 47 px mỗi bên và 21 px ở
		đáy — ba mép user chỉ ra. `None` cho ta toàn bộ màn hình vật lý.

		Phép quy đổi gốc toạ độ ở `layout` vẫn đúng nguyên: nó trừ `gui.AbsolutePosition`, mà
		giá trị đó tự đổi theo (−47, −58) cùng lúc.
	]]
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	for _, side in { "Top", "Bottom", "Left", "Right" } do
		local shade = Instance.new("TextButton")
		shade.Name = side
		shade.AutoButtonColor = false
		shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		shade.BackgroundTransparency = 1
		shade.BorderSizePixel = 0
		shade.Text = ""
		shade.ZIndex = 1
		-- Nuốt cú chạm nhưng KHÔNG làm gì: đây là mục đích tồn tại của nó.
		shade.Activated:Connect(function() end)
		shade.Parent = gui
		shades[side] = shade
	end

	--[[
		Vành sáng quanh ô. `Active = false` + nền trong suốt ⇒ nó KHÔNG chặn chạm, nên vành có
		thể phủ lấn vào trong ô sáng mà người chơi vẫn bấm xuyên qua được tới cái nút thật.
	]]
	local r = Instance.new("Frame")
	r.Name = "Ring"
	r.Active = false
	r.BackgroundTransparency = 1
	r.BorderSizePixel = 0
	r.ZIndex = 2
	r.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, RING_RADIUS)
	corner.Parent = r
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 226, 92)
	stroke.Thickness = 4
	stroke.Transparency = 1
	stroke.Parent = r

	screenGui, ring, ringStroke = gui, r, stroke
end

--[[
	Vẽ lại bốn tấm che theo ô sáng hiện tại.

	⚠️ Kẹp về 0: khi nút nằm sát mép màn hình, bề rộng tấm bên đó ra SỐ ÂM. `UDim2` nhận số âm
	mà không báo lỗi, và tấm đó lật ngược ra ngoài màn hình — kết quả là một mảng tối lệch hẳn
	sang phía đối diện, nhìn như spotlight chiếu nhầm chỗ.
]]
local function layout(target: GuiObject)
	local gui = screenGui
	if not gui then
		return
	end

	local viewport = gui.AbsoluteSize
	local pad = emphasisPx(PADDING, PADDING_MIN_PX)

	--[[
		⚠️ PHẢI QUY ĐỔI GỐC TOẠ ĐỘ, KHÔNG DÙNG THẲNG `AbsolutePosition`.

		`AbsolutePosition` của mọi GuiObject đo từ gốc ĐÃ TRỪ topbar. Nhưng `ScreenGui` này đặt
		`IgnoreGuiInset = true`, nên toạ độ CON của nó bắt đầu từ mép trên tuyệt đối — hai hệ
		lệch nhau đúng chiều cao topbar.

		Đã đo lỗi này: ô sáng nằm CAO HƠN nút Daily 72 px (= topbar 58 + lề 14). Trên máy khác
		topbar khác chiều cao nên độ lệch cũng khác — kiểu lỗi "chỉ sai trên một số máy".

		Lấy `gui.AbsolutePosition` làm gốc thay vì hỏi `GuiService`: chính `ScreenGui` này báo
		(0, −58) khi đang bỏ qua inset, nên phép trừ tự đúng cho mọi cấu hình, kể cả khi sau này
		đổi `IgnoreGuiInset` thành false.
	]]
	local origin = gui.AbsolutePosition
	local localX = target.AbsolutePosition.X - origin.X
	local localY = target.AbsolutePosition.Y - origin.Y

	--[[
		Làm tròn TRƯỚC khi dựng `UDim2`: `UDim.Offset` bị CẮT xuống số nguyên (đặt 13.99 ra 13),
		nên không làm tròn thì lề quanh ô sáng lệch nhau 1–3 px giữa các cạnh — cùng họ với lỗi
		viền đã sửa ở `Theme.borderFor`.
	]]
	local x = math.round(math.max(0, localX - pad))
	local y = math.round(math.max(0, localY - pad))
	local w = math.round(math.min(viewport.X - x, target.AbsoluteSize.X + pad * 2))
	local h = math.round(math.min(viewport.Y - y, target.AbsoluteSize.Y + pad * 2))

	--[[
		Bốn tấm che ĐỀU TRÀN RA NGOÀI MÀN HÌNH `OVERSCAN` px về mọi phía.

		Không phải để đẹp mà để KHÔNG BAO GIỜ HỞ MÉP nữa: `AbsoluteSize` của một `ScreenGui` phụ
		thuộc vào `ScreenInsets`, vào thanh trạng thái của hệ điều hành, vào tai thỏ của từng
		máy — mỗi thứ có thể trả về nhỏ hơn màn hình thật vài chục pixel (đúng cái đã xảy ra
		2026-08-18). Cắt sát mép thì mọi sai số ấy hiện thành một dải sáng ở rìa; tràn ra ngoài
		thì sai số bị nuốt hết, mà phần thừa nằm ngoài màn hình nên không tốn gì.

		Phần tràn KHÔNG bao giờ chạm vào ô sáng: nó chỉ nới bốn cạnh HƯỚNG RA NGOÀI.
	]]
	local OVERSCAN = 120

	shades.Top.Position = UDim2.fromOffset(-OVERSCAN, -OVERSCAN)
	shades.Top.Size = UDim2.fromOffset(viewport.X + OVERSCAN * 2, math.max(0, y) + OVERSCAN)

	shades.Bottom.Position = UDim2.fromOffset(-OVERSCAN, y + h)
	shades.Bottom.Size =
		UDim2.fromOffset(viewport.X + OVERSCAN * 2, math.max(0, viewport.Y - (y + h)) + OVERSCAN)

	shades.Left.Position = UDim2.fromOffset(-OVERSCAN, y)
	shades.Left.Size = UDim2.fromOffset(math.max(0, x) + OVERSCAN, h)

	shades.Right.Position = UDim2.fromOffset(x + w, y)
	shades.Right.Size = UDim2.fromOffset(math.max(0, viewport.X - (x + w)) + OVERSCAN, h)

	if ring then
		ring.Position = UDim2.fromOffset(x, y)
		ring.Size = UDim2.fromOffset(w, h)
		local corner = ring:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0, px(RING_RADIUS))
		end
	end
end

local function stopFollowing()
	if followConn then
		followConn:Disconnect()
		followConn = nil
	end
end

--[[
	Chiếu đèn vào `target`.

	Gọi lại với target khác trong lúc đang sáng thì đèn TRƯỢT sang chỗ mới (không tắt rồi bật):
	mắt bám theo được chuyển động, còn tắt-bật là một cú chớp làm mất dấu.
]]
function Spotlight.Show(target: GuiObject)
	build()
	local gui = screenGui
	if not gui or not ring or not ringStroke then
		return
	end

	currentTarget = target
	gui.Enabled = true
	layout(target)

	if not shown then
		shown = true
		for _, shade in shades do
			shade.BackgroundTransparency = 1
			TweenService:Create(shade, FADE, { BackgroundTransparency = DIM }):Play()
		end
	end

	stopFollowing()
	--[[
		Bám theo mỗi frame thay vì nghe `GetPropertyChangedSignal("AbsolutePosition")`.

		Lý do: nút trong HUD nhúc nhích vì rất nhiều nguồn — hiệu ứng phóng khi chạm, modal trượt
		lên lúc mở, người chơi xoay máy, `UIGridLayout` xếp lại. Bắt cho đủ từng tín hiệu là chắc
		chắn sót một cái, và sót thì lỗ sáng đứng lệch khỏi nút. Bốn `UDim2` mỗi frame là phép
		tính không đáng kể, mà chỉ chạy trong lúc tutorial đang chiếu.
	]]
	followConn = RunService.Heartbeat:Connect(function(dt)
		local t = currentTarget
		-- Nút biến mất giữa chừng (modal đóng, HUD dựng lại) thì tắt đèn — để nguyên là cả màn
		-- hình tối đen với một cái lỗ chỉ vào hư không, và người chơi không bấm được gì nữa.
		if not t or t.Parent == nil or not t.Visible or t.AbsoluteSize.X <= 0 then
			Spotlight.Hide()
			return
		end
		layout(t)

		-- Vành thở nhè nhẹ: chuyển động là thứ mắt bắt được ở rìa tầm nhìn, màu sắc thì không.
		pulseClock += dt
		local wave = (math.sin(pulseClock * 3.4) + 1) * 0.5
		if ringStroke then
			ringStroke.Thickness = emphasisPx(RING_THICKNESS, RING_MIN_PX) * (0.75 + wave * 0.5)
			ringStroke.Transparency = 0.15 * wave
		end
	end)
end

function Spotlight.Hide()
	stopFollowing()
	currentTarget = nil
	if not shown then
		return
	end
	shown = false

	local gui = screenGui
	if not gui then
		return
	end
	for _, shade in shades do
		TweenService:Create(shade, FADE, { BackgroundTransparency = 1 }):Play()
	end
	if ringStroke then
		TweenService:Create(ringStroke, FADE, { Transparency = 1 }):Play()
	end
	-- Tắt hẳn ScreenGui SAU khi mờ xong; tắt ngay là hình biến mất phụt một cái.
	task.delay(FADE.Time + 0.02, function()
		if not shown and gui then
			gui.Enabled = false
		end
	end)
end

function Spotlight.IsShown(): boolean
	return shown
end

-- Đèn có đang chiếu đúng vào `target` không (dùng để khỏi gọi `Show` lại mỗi frame).
function Spotlight.IsTargeting(target: GuiObject?): boolean
	return shown and currentTarget == target
end

return Spotlight
