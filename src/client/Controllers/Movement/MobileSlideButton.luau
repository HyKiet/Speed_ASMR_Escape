--!strict
--[[
	MobileSlideButton.luau — nút SLIDE cho thiết bị cảm ứng.

	Trên PC slide là phím [C], trên tay cầm là L3 (`MovementConfig.Keys` / `GamepadKeys`).
	Mobile thì KHÔNG có gì cả: cả cơ chế slide — kể cả đoạn chui cổng thấp Zone 5 vốn thiết
	kế quanh nó — trước nay người chơi điện thoại không chạm tới được.

	══ VÌ SAO BÁM THEO NÚT NHẢY THAY VÌ ĐẶT TOẠ ĐỘ CỐ ĐỊNH ═══════════════════════════════

	Yêu cầu là "nút slide nằm gần nút nhảy". Nút nhảy KHÔNG phải của mình: Roblox `PlayerModule`
	dựng nó trong `PlayerGui.TouchGui.TouchControlFrame.JumpButton`, và nó tự đổi cỡ lẫn chỗ
	đứng theo kích thước màn hình, theo tai thỏ, theo kiểu điều khiển đang bật, theo cả việc
	người chơi có bật/tắt cụm cảm ứng. Hardcode một toạ độ là chắc chắn lệch trên một dòng máy
	nào đó — hoặc tệ hơn, đè lên chính nút nhảy.

	Nên nút này SOI GƯƠNG nút nhảy: đọc `AbsolutePosition`/`AbsoluteSize` của nó rồi đặt mình
	sang bên trái, cỡ bằng 0,82 lần. Cỡ nào, chỗ nào, ẩn hiện lúc nào cũng đi theo — 0 hằng số
	toạ độ tuyệt đối trong file này.

	⚠️ BẪY AbsolutePosition ↔ GuiInset: `AbsolutePosition` của hai ScreenGui khác nhau về
	`IgnoreGuiInset` nằm trên hai gốc toạ độ lệch nhau đúng chiều cao topbar. Ở đây KHÔNG cộng
	trừ inset bằng tay (kiểu gì cũng sai một lần): lấy hiệu `jump.AbsolutePosition −
	root.AbsolutePosition`, hai gốc toạ độ tự triệt tiêu dù Roblox có đổi quy ước.

	Cập nhật theo SỰ KIỆN (`AbsolutePosition`/`AbsoluteSize` đổi) chứ không quét mỗi frame:
	máy yếu (Redmi A2+) đã chật vật sẵn, không thêm một vòng RenderStepped cho một cái nút.

	⚠️ ScreenGui tên `SpeedEscapeTouchControls` — `HUD/TopBarController` nhận diện tiền tố này
	để KHÔNG tắt nó khi bấm "Ẩn giao diện". Nút slide là ĐIỀU KHIỂN, cùng hạng với nút nhảy,
	không phải HUD. Đổi tên ở đây thì phải đổi luôn bên đó.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(script.Parent.MovementConfig)
local MovementController = require(script.Parent.MovementController)

local localPlayer = Players.LocalPlayer

local MobileSlideButton = {}

local GUI_NAME = "SpeedEscapeTouchControls"
-- `TouchGui` của PlayerModule để DisplayOrder = 10. Đứng CÙNG mức là đủ để nút hiện lên
-- bình thường mà không nhảy lên trên modal (modal HUD dùng order cao hơn hẳn).
local DISPLAY_ORDER = 10

local SIZE_FACTOR = 0.82 -- so với nút nhảy: nhỏ hơn để mắt vẫn thấy nhảy là nút chính
local GAP_FACTOR = 0.22 -- khe hở giữa hai nút, tính theo bề ngang nút nhảy
local RAISE_FACTOR = 0.34 -- nhấc lên so với tâm nút nhảy — ngón cái quét theo cung, không theo đường ngang

local IDLE_TRANSPARENCY = 0.25
local HELD_TRANSPARENCY = 0.05
--[[
	Chữ SẪM trên nền tròn trắng, không phải trắng-trên-trắng.

	Bản đầu để cả nền lẫn chữ đều trắng (bắt chước nút nhảy của Roblox) và chụp lại thì gần
	như không đọc được — nút nhảy dùng được cách đó vì nó vẽ MŨI TÊN, hình khối đủ to để chỉ
	cần đường viền là nhận ra. Chữ "SLIDE" cao ~20px thì không: phải tương phản thật.
]]
local TEXT_COLOR = Color3.fromRGB(26, 26, 40)

local gui: ScreenGui? = nil
local root: Frame? = nil
local button: TextButton? = nil
local stroke: UIStroke? = nil

-- Nút nhảy đang theo dõi + các kết nối bám theo nó (đứt hết khi nó bị dựng lại).
local jumpButton: GuiObject? = nil
local jumpConns: { RBXScriptConnection } = {}
-- Kết nối thuộc về ScreenGui của mình, sống theo build()/teardown() — KHÔNG được nằm chung
-- `jumpConns`, vì bảng đó bị cắt sạch mỗi lần nút nhảy bị dựng lại.
local ownConns: { RBXScriptConnection } = {}

--[[
	NHẬN DIỆN MOBILE — chép đúng luật của `HUD/TopBarController.isMobileDevice`.

	Không dùng riêng `TouchEnabled`: laptop cảm ứng và màn hình cảm ứng gắn PC đều bật cờ đó
	nhưng chơi bằng bàn phím, và ở đó phím [C] đã có sẵn — thêm nút cảm ứng chỉ tổ che HUD.
]]
--[[
	HOOK QA (chỉ Studio) — `Workspace:SetAttribute("StudioForceMobileSlide", true)`.

	Device Emulation của Studio KHÔNG mô phỏng nổi luật trên: nó bật `TouchEnabled` nhưng vẫn
	để `MouseEnabled = true` (máy thật vẫn có chuột), nên `isMobileDevice()` trả false và nút
	không bao giờ dựng — tức là bằng Studio thuần thì KHÔNG có cách nào nhìn thấy nút này.
	Cờ này mở đường đó ra. Nó chỉ bỏ qua bước NHẬN DIỆN; phần còn lại (bám nút nhảy, đo đạc,
	bấm) vẫn chạy đúng như trên máy thật, vì Device Emulation có dựng `TouchGui` thật.

	`RunService:IsStudio()` chặn cứng: trên server live cờ này vô hiệu, không lo ai đó set
	nhầm attribute rồi người chơi PC mọc thêm nút.
]]
local function studioForced(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("StudioForceMobileSlide") == true
end

local function isMobileDevice(): boolean
	if studioForced() then
		return true
	end
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
		and not GuiService:IsTenFootInterface()
end

local function findJumpButton(): GuiObject?
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local touchGui = playerGui:FindFirstChild("TouchGui")
	local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	return if jump and jump:IsA("GuiObject") then jump else nil
end

local function layout()
	local b, r, jump = button, root, jumpButton
	if not (b and r) then
		return
	end
	if not (jump and jump.Parent) then
		b.Visible = false
		return
	end

	local jumpSize = jump.AbsoluteSize
	if jumpSize.X < 1 or jumpSize.Y < 1 then
		b.Visible = false -- cụm cảm ứng đang tắt / chưa dựng xong
		return
	end

	local size = math.floor(jumpSize.X * SIZE_FACTOR)
	local gap = jumpSize.X * GAP_FACTOR

	-- Hiệu hai AbsolutePosition ⇒ không phụ thuộc GuiInset của bên nào (xem đầu file).
	local rel = jump.AbsolutePosition - r.AbsolutePosition
	local x = rel.X - size - gap
	-- Căn tâm theo nút nhảy rồi nhấc lên một chút.
	local y = rel.Y + (jumpSize.Y - size) * 0.5 - jumpSize.Y * RAISE_FACTOR

	b.Size = UDim2.fromOffset(size, size)
	b.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	b.Visible = jump.Visible
end

local function watchJumpButton(jump: GuiObject?)
	for _, conn in jumpConns do
		conn:Disconnect()
	end
	table.clear(jumpConns)

	jumpButton = jump
	if not jump then
		layout()
		return
	end

	for _, prop in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
		table.insert(jumpConns, jump:GetPropertyChangedSignal(prop):Connect(layout))
	end
	-- Cụm cảm ứng bị Roblox huỷ rồi dựng lại khi đổi kiểu điều khiển; bám vào cái đã chết
	-- thì nút slide đứng nguyên một chỗ trong khi nút nhảy đã dời đi.
	table.insert(
		jumpConns,
		jump.AncestryChanged:Connect(function()
			if not jump:IsDescendantOf(game) then
				watchJumpButton(nil)
			end
		end)
	)
	layout()
end

local function setHeld(held: boolean)
	local b, s = button, stroke
	if not (b and s) then
		return
	end
	b.BackgroundTransparency = if held then HELD_TRANSPARENCY else IDLE_TRANSPARENCY
	s.Transparency = if held then 0 else 0.25
end

local function onPressed()
	local started = MovementController.TrySlide()
	setHeld(true)
	if started or not button then
		return
	end
	--[[
		Bấm mà KHÔNG slide được (đang cooldown, đang trên không, đang đứng yên) thì phải nói
		ra. Nút im lặng nuốt cú bấm là kiểu hỏng khó chịu nhất trên mobile: người chơi không
		phân biệt được "nút hỏng" với "chưa tới lúc". Nháy đỏ một nhịp — không tween, không
		Instance mới, chỉ hai lần ghi màu.
	]]
	local b = button
	b.BackgroundColor3 = Color3.fromRGB(196, 62, 62)
	task.delay(0.16, function()
		if b.Parent then
			b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		end
	end)
end

local function build()
	if gui then
		return
	end
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = GUI_NAME
	screen.ResetOnSpawn = false -- respawn không được làm mất nút điều khiển
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = DISPLAY_ORDER
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local frame = Instance.new("Frame")
	frame.Name = "Root"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = screen

	local b = Instance.new("TextButton")
	b.Name = "SlideButton"
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	b.BackgroundTransparency = IDLE_TRANSPARENCY
	b.Text = "SLIDE"
	b.TextColor3 = TEXT_COLOR
	b.TextScaled = true
	b.Font = Enum.Font.GothamBlack
	b.Visible = false
	b.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0) -- tròn như nút nhảy
	corner.Parent = b

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(255, 255, 255)
	s.Thickness = 2
	s.Transparency = 0.25
	s.Parent = b

	-- Chữ chỉ chiếm phần lõi để không dính viền tròn. Lề ngang hẹp hơn lề dọc vì "SLIDE" là
	-- chữ NẰM NGANG: nới ngang ra mới lấy được cỡ chữ, còn nới dọc thì chữ tự cao lên và
	-- đâm vào cung tròn hai đầu.
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.1, 0)
	pad.PaddingRight = UDim.new(0.1, 0)
	pad.PaddingTop = UDim.new(0.3, 0)
	pad.PaddingBottom = UDim.new(0.3, 0)
	pad.Parent = b

	b.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			onPressed()
		end
	end)
	b.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			setHeld(false)
		end
	end)

	screen.Parent = playerGui

	gui, root, button, stroke = screen, frame, b, s

	table.insert(ownConns, frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))

	-- Cụm cảm ứng tới SAU nút này (nó chỉ dựng khi nhân vật spawn lần đầu), và bị dựng lại
	-- mỗi lần đổi kiểu điều khiển ⇒ phải rình cả hai chiều.
	table.insert(
		ownConns,
		playerGui.DescendantAdded:Connect(function(descendant)
			if descendant.Name == "JumpButton" and descendant:IsA("GuiObject") and jumpButton ~= descendant then
				watchJumpButton(findJumpButton())
			end
		end)
	)

	watchJumpButton(findJumpButton())
end

local function teardown()
	if not gui then
		return
	end
	watchJumpButton(nil)
	for _, conn in ownConns do
		conn:Disconnect()
	end
	table.clear(ownConns)
	gui:Destroy()
	gui, root, button, stroke = nil, nil, nil, nil
end

function MobileSlideButton.Start()
	if not MovementConfig.Slide then
		return
	end

	local function sync()
		if isMobileDevice() then
			build()
		else
			teardown()
		end
	end

	--[[
		Kiểu thiết bị KHÔNG cố định trong một phiên: máy tính bảng cắm bàn phím rời giữa chừng
		là `KeyboardEnabled` bật lên, và ngược lại. Cùng lý do (và cùng cách) mà
		`HUD/TopBarController` dựng/gỡ nút khoá camera của nó.
	]]
	for _, prop in { "TouchEnabled", "KeyboardEnabled", "MouseEnabled" } do
		UserInputService:GetPropertyChangedSignal(prop):Connect(sync)
	end
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("StudioForceMobileSlide"):Connect(sync)
	end
	sync()
end

return MobileSlideButton
