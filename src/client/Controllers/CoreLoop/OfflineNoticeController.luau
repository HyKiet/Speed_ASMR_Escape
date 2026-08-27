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

local overlay: Frame? = nil
local fadeTargets: { any } = {}
local showToken = 0

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

local function buildOverlay(gui: ScreenGui): Frame
	local k1 = math.clamp(gui.AbsoluteSize.Y / 1080, 0.5, 1)
	local function k(value: number): number
		return math.round(value * k1)
	end

	table.clear(fadeTargets)

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

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(10, 8, 20)
	titleStroke.Thickness = math.max(2, k(6))
	titleStroke.Parent = title

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

	local subStroke = Instance.new("UIStroke")
	subStroke.Color = Color3.fromRGB(10, 8, 20)
	subStroke.Thickness = math.max(1.5, k(4))
	subStroke.Parent = sub

	overlay = root
	return root
end

local function show()
	local gui = getGui()
	showToken += 1

	-- Mở/đóng menu liên tục: bỏ lớp cũ đi rồi dựng lại, không chồng hai lớp lên nhau.
	if overlay then
		overlay:Destroy()
		overlay = nil
	end

	local root = buildOverlay(gui)
	local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(root, info, { BackgroundTransparency = 0.45 }):Play()
	for _, target in fadeTargets do
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
	local root = overlay
	if not root then
		return
	end
	overlay = nil

	showToken += 1
	local token = showToken
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, target in fadeTargets do
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
		-- `token` chặn trường hợp người chơi mở lại menu giữa lúc đang mờ dần: lớp mới đã dựng
		-- xong rồi thì lệnh Destroy của lớp cũ không được đụng vào gì nữa.
		if token == showToken and root.Parent then
			root:Destroy()
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
