--!strict
--[[
	OfflineNoticeController.luau — báo cho người chơi biết treadmill vẫn chạy khi họ thoát.

	── VÌ SAO GẮN VÀO MENU ROBLOX ────────────────────────────────────────────────────────────
	Một tính năng giữ chân chỉ có tác dụng khi người chơi BIẾT nó tồn tại, và thời điểm duy
	nhất chắc chắn họ đang cân nhắc rời đi là lúc mở menu Roblox (Esc / nút hamburger) — nơi
	có nút Leave. Nói đúng câu đó vào đúng giây đó là khác biệt giữa "thoát luôn" và "thoát
	rồi mai vào lấy quà".

	`GuiService.MenuOpened` / `MenuClosed` là hai sự kiện duy nhất báo được chuyện này; không
	có cách nào đọc riêng nút Leave.

	── TOÀN MÀN HÌNH + NỀN MỜ (2026-08-27, user) ────────────────────────────────────────────
	Bản đầu là một dải mỏng ở đỉnh. Đổi sang lớp phủ kín màn hình vì bảng menu của Roblox vẽ
	ĐÈ LÊN mọi ScreenGui của game và nó chiếm nguyên khối giữa — một dải mỏng ở rìa rất dễ bị
	mắt bỏ qua đúng lúc người chơi đang nhìn vào nút Leave.

	Bố cục vì vậy chia làm hai: chữ lớn ở NỬA TRÊN, dòng phụ ở NỬA DƯỚI, chừa trống khoảng
	giữa cho panel menu. Nội dung nằm ở hai vùng mà panel không bao giờ với tới.

	⚠️ Nền mờ để `BackgroundTransparency = 0.45` chứ không đặc: đây là lớp phủ THÔNG BÁO, không
	phải hộp thoại chặn. Làm tối hẳn màn hình sẽ đọc như game bị treo.

	── VÌ SAO KHÔNG DÙNG FUSION ─────────────────────────────────────────────────────────────
	ScreenGui riêng, dựng bằng `Instance.new` — y hệt `HUD/Toast`. Nó không nằm trong canvas
	1920×1080 của HUD nên không có `UIScale` chung; mọi con số phải nhân `k()` (co theo chiều
	cao màn hình thật) như Toast, nếu không trên điện thoại chữ to bằng nửa màn hình.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local OfflineConfig = require(ReplicatedStorage.Shared.Config.OfflineEarnings)
local Theme = require(script.Parent.Parent.HUD.Theme)

local localPlayer = Players.LocalPlayer

local OfflineNoticeController = {}

--[[
	══ VÌ SAO MỖI LỚP PHỦ GIỮ DANH SÁCH FADE CỦA RIÊNG NÓ ═══════════════════════════════════

	Bản trước dùng MỘT bảng `fadeTargets` cấp module dùng chung cho mọi lần dựng, cộng với một
	`showToken` để quyết định có huỷ lớp cũ hay không. Spam mở/đóng menu Roblox làm vỡ cả hai:

	    show()  → dựng lớp A
	    hide()  → `overlay = nil`, A bắt đầu mờ dần, hẹn huỷ NẾU token còn khớp
	    show()  → token TĂNG (⇒ lời hẹn huỷ A vĩnh viễn không chạy), và vì `overlay` đã là nil
	              nên nhánh "bỏ lớp cũ đi" cũng không chạy ⇒ A NẰM LẠI TRÊN MÀN HÌNH MÃI MÃI

	Ghép với lỗi thứ hai — `titleStroke`/`subStroke` KHÔNG hề được nhét vào `fadeTargets`, nên
	`Transparency` của chúng đứng nguyên 0 suốt đời — thì A tuy đã mờ hết phần nền lẫn ruột chữ
	nhưng VIỀN chữ vẫn đặc: đúng cái bóng chữ đen khổng lồ "YOUR TREADMILL KEEPS RUNNING" đè lên
	game mà user chụp lại được. Mỗi lần spam lại chồng thêm một lớp nữa.

	Sửa tận gốc, không vá bằng token:
	  1. mỗi lớp phủ là một `Overlay` mang theo danh sách fade CỦA CHÍNH NÓ (không dùng chung);
	  2. `show()` huỷ lớp trước VÔ ĐIỀU KIỆN — kể cả khi nó đang mờ dần dở;
	  3. `show()` quét sạch mọi con còn sót trong ScreenGui trước khi dựng (lưới an toàn cuối);
	  4. `hide()` huỷ ĐÚNG lớp của mình khi tween xong, không phán xét bằng token nữa.
]]
type Overlay = {
	root: Frame,
	targets: { any },
}

local current: Overlay? = nil

local function getGui(): ScreenGui
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("SpeedEscapeOfflineNotice")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedEscapeOfflineNotice"
	-- Dưới Toast (999) nhưng trên HUD: lớp này không được che mất toast lỗi/thành công.
	gui.DisplayOrder = 998
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	return gui
end

--[[
	Câu chữ lấy THẲNG từ config, không chép tay.

	Viết cứng "3h" vào đây thì lần sau ai đó chỉnh `MAX_SECONDS` sẽ để lại một thông báo nói
	dối người chơi — và không có test nào bắt được chuyện đó.
]]
local function subtitleText(): string
	local hours = OfflineConfig.MAX_SECONDS / 3600
	local hoursText = if hours == math.floor(hours) then `{math.floor(hours)}h` else `{hours}h`
	return `Earning {math.floor(OfflineConfig.RATE * 100)}% speed for up to {hoursText} — come back to collect!`
end

local function buildOverlay(gui: ScreenGui): Overlay
	local k1 = math.clamp(gui.AbsoluteSize.Y / 1080, 0.5, 1)
	local function k(value: number): number
		return math.round(value * k1)
	end

	local fadeTargets: { any } = {}

	local root = Instance.new("Frame")
	root.BackgroundColor3 = Color3.fromRGB(8, 6, 20)
	root.BackgroundTransparency = 1 -- fade-in tween sẽ kéo về 0.45
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 9000
	root.Parent = gui

	--[[
		MỖI KHỐI CHỮ CÓ NỀN TỐI RIÊNG.

		Lớp phủ mờ 45% một mình KHÔNG đủ: đo lúc nghiệm thu 2026-08-27, chữ lớn đè đúng lên dải
		nhắc tutorial còn dòng phụ đè lên thanh Level — hai chỗ đó có nền sáng và viền dày, nên
		chữ trắng trên nền mờ vẫn đọc ra "Le…7K" lẫn với câu của mình.

		Tấm nền đặc phía sau từng khối là thứ duy nhất đảm bảo đọc được, bất kể HUD phía dưới
		đang vẽ gì. Đừng thay nó bằng cách làm lớp phủ tối hơn — tối hẳn màn hình đọc như game
		bị treo, và đây chỉ là một THÔNG BÁO chứ không phải hộp thoại chặn.
	]]
	local function makePanel(): Frame
		local panel = Instance.new("Frame")
		panel.BackgroundColor3 = Color3.fromRGB(14, 11, 30)
		panel.BackgroundTransparency = 1
		panel.BorderSizePixel = 0
		panel.ZIndex = 9001
		panel.Parent = root
		table.insert(fadeTargets, panel)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, k(26))
		corner.Parent = panel

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 205, 46)
		stroke.Thickness = math.max(2, k(5))
		stroke.Transparency = 1
		stroke.Parent = panel
		table.insert(fadeTargets, stroke :: any)

		return panel
	end

	-- KHỐI TRÊN — icon + chữ lớn. Panel menu Roblox căn giữa nên dải này không bao giờ bị che.
	local top = makePanel()
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, k(72))
	top.Size = UDim2.new(0.82, 0, 0, k(228))

	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image = Theme.UI_ASSETS.Shoe
	icon.ImageTransparency = 1
	icon.Position = UDim2.new(0.5, 0, 0, k(16))
	icon.Size = UDim2.fromOffset(k(96), k(96))
	icon.ZIndex = 9002
	icon.Parent = top
	table.insert(fadeTargets, icon)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Theme.FONT
	title.Position = UDim2.new(0.04, 0, 0, k(120))
	title.Size = UDim2.new(0.92, 0, 0, k(92))
	title.Text = "YOUR TREADMILL KEEPS RUNNING"
	title.TextColor3 = Color3.fromRGB(255, 213, 74)
	title.TextScaled = true
	title.TextTransparency = 1
	title.ZIndex = 9002
	title.Parent = top
	table.insert(fadeTargets, title)

	local titleCap = Instance.new("UITextSizeConstraint")
	titleCap.MaxTextSize = k(80)
	titleCap.Parent = title

	--[[
		⚠️ VIỀN CHỮ PHẢI NẰM TRONG DANH SÁCH FADE.

		`UIStroke` trên một `TextLabel` có `Transparency` RIÊNG: kéo `TextTransparency` về 1 chỉ
		xoá phần RUỘT chữ, viền vẫn vẽ đủ nét. Bỏ sót nó ở đây (đúng lỗi cũ) thì lúc ẩn đi người
		chơi thấy chữ rỗng viền đen nằm giữa màn hình chứ không phải thấy nó biến mất.
	]]
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(10, 8, 20)
	titleStroke.Thickness = math.max(2, k(6))
	titleStroke.Transparency = 1
	titleStroke.Parent = title
	table.insert(fadeTargets, titleStroke :: any)

	--[[
		KHỐI DƯỚI — dòng phụ. Neo theo mép DƯỚI (AnchorPoint Y = 1): panel menu cao bao nhiêu
		cũng không đẩy được nó đi đâu.
	]]
	local bottom = makePanel()
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.fromScale(0.5, 0.93)
	bottom.Size = UDim2.new(0.74, 0, 0, k(96))

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Font = Theme.FONT
	sub.Position = UDim2.new(0.04, 0, 0.18, 0)
	sub.Size = UDim2.new(0.92, 0, 0.64, 0)
	sub.Text = subtitleText()
	sub.TextColor3 = Color3.fromRGB(226, 232, 255)
	sub.TextScaled = true
	sub.TextTransparency = 1
	sub.ZIndex = 9002
	sub.Parent = bottom
	table.insert(fadeTargets, sub)

	local subCap = Instance.new("UITextSizeConstraint")
	subCap.MaxTextSize = k(42)
	subCap.Parent = sub

	-- Cùng lý do với `titleStroke` ở trên.
	local subStroke = Instance.new("UIStroke")
	subStroke.Color = Color3.fromRGB(10, 8, 20)
	subStroke.Thickness = math.max(1.5, k(4))
	subStroke.Transparency = 1
	subStroke.Parent = sub
	table.insert(fadeTargets, subStroke :: any)

	return { root = root, targets = fadeTargets }
end

local function show()
	local gui = getGui()

	--[[
		Mở/đóng menu liên tục: bỏ lớp cũ đi rồi dựng lại, không chồng hai lớp lên nhau.

		VÔ ĐIỀU KIỆN — kể cả lớp đang mờ dần dở dang (`hide()` cố tình GIỮ `current` trỏ vào nó
		đúng để chỗ này với tới được). Đây là chỗ bản cũ bỏ lọt: nó xoá `current` ngay trong
		`hide()` nên lớp đang mờ trở thành mồ côi, không ai huỷ nữa.
	]]
	if current then
		current.root:Destroy()
		current = nil
	end
	-- Lưới an toàn cuối: quét sạch mọi lớp còn sót vì bất kỳ lý do gì. ScreenGui này chỉ chứa
	-- duy nhất lớp phủ, nên không có gì khác để mất.
	for _, child in gui:GetChildren() do
		child:Destroy()
	end

	local overlay = buildOverlay(gui)
	current = overlay
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(overlay.root, info, { BackgroundTransparency = 0.45 }):Play()
	for _, target in overlay.targets do
		if target:IsA("ImageLabel") then
			TweenService:Create(target, info, { ImageTransparency = 0 }):Play()
		elseif target:IsA("UIStroke") then
			TweenService:Create(target, info, { Transparency = 0 }):Play()
		elseif target:IsA("Frame") then
			TweenService:Create(target, info, { BackgroundTransparency = 0.08 }):Play()
		else
			TweenService:Create(target, info, { TextTransparency = 0 }):Play()
		end
	end
end

local function hide()
	local overlay = current
	if not overlay then
		return
	end

	--[[
		⚠️ CỐ Ý KHÔNG xoá `current` ở đây.

		Lớp này còn sống thêm 0.18s nữa để mờ dần; trong khoảng đó người chơi hoàn toàn có thể mở
		lại menu. `current` vẫn trỏ vào nó chính là sợi dây để `show()` với tới mà huỷ — bản cũ
		cắt sợi dây này ngay lập tức và đó là lý do lớp phủ nằm lại vĩnh viễn khi spam menu.
	]]
	local root = overlay.root
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, target in overlay.targets do
		if target:IsA("ImageLabel") then
			TweenService:Create(target, info, { ImageTransparency = 1 }):Play()
		elseif target:IsA("UIStroke") then
			TweenService:Create(target, info, { Transparency = 1 }):Play()
		elseif target:IsA("Frame") then
			TweenService:Create(target, info, { BackgroundTransparency = 1 }):Play()
		else
			TweenService:Create(target, info, { TextTransparency = 1 }):Play()
		end
	end
	local tween = TweenService:Create(root, info, { BackgroundTransparency = 1 })
	tween.Completed:Once(function()
		--[[
			Huỷ ĐÚNG lớp của mình, không điều kiện. Nếu người chơi đã mở lại menu giữa chừng thì
			`show()` huỷ nó trước rồi — gọi `Destroy` lần nữa lên một Instance đã huỷ là vô hại,
			nên ở đây không cần (và không được) phán xét bằng token: chính phép phán xét đó là
			thứ đã bỏ sót lớp cũ lại trên màn hình.
		]]
		root:Destroy()
		-- Chỉ dọn con trỏ khi nó vẫn là lớp của mình; `show()` xen giữa thì `current` đã là lớp
		-- MỚI và không được đụng tới.
		if current == overlay then
			current = nil
		end
	end)
	tween:Play()
end

function OfflineNoticeController.Start()
	GuiService.MenuOpened:Connect(show)
	GuiService.MenuClosed:Connect(hide)

	--[[
		[Studio-only test hook] HIỆN/ẨN LỚP PHỦ MÀ KHÔNG CẦN MỞ MENU ROBLOX.

		    LocalPlayer:SetAttribute("StudioOfflineNotice", 1)   -- hiện
		    LocalPlayer:SetAttribute("StudioOfflineNotice", 0)   -- ẩn

		Bắt buộc phải có, vì menu Roblox không mở được bằng script: `GuiService:SetMenuIsOpen`
		đòi capability `RobloxScript`, và phím Escape bị khoá cứng vào CoreGUI nên công cụ nhập
		liệu ảo cũng không gửi được (đã thử cả hai, 2026-08-27).

		⚠️ Ảnh chụp qua MCP KHÔNG bắt được lớp CoreGui của menu Roblox, nên lớp phủ chụp ra sẽ
		nằm trên nền game trống — đúng bố cục, nhưng không thấy panel menu che khoảng giữa.
		Muốn kiểm chỗ chồng lấn thì phải mở menu bằng tay.
	]]
	if RunService:IsStudio() then
		localPlayer:GetAttributeChangedSignal("StudioOfflineNotice"):Connect(function()
			local mode = tonumber(localPlayer:GetAttribute("StudioOfflineNotice"))
			if not mode then
				return
			end
			localPlayer:SetAttribute("StudioOfflineNotice", nil)
			if mode == 0 then
				hide()
			else
				show()
			end
		end)
	end
end

return OfflineNoticeController
