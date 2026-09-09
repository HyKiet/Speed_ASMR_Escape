--!strict
--[[
	TopBarController.luau — Nút ẨN GIAO DIỆN + CÀI ĐẶT trên topbar, dựng bằng **TopbarPlus
	v3.4.0** (`Packages/TopbarPlus`, wally `1foreverhd/topbarplus@3.4.0`).

	Dùng TopbarPlus thay vì tự dựng ScreenGui: nó tự lo canh vị trí cạnh cụm nút gốc của
	Roblox trên MỌI thiết bị (desktop / mobile / tay cầm), tự làm caption khi hover, tự thu
	vào overflow khi hết chỗ — những thứ bản tự dựng phải hardcode `GuiService.TopbarInset`.

	⚠️ TopbarPlus dựng ScreenGui riêng trong PlayerGui (`Topbar*`). Chức năng "ẩn giao diện"
	PHẢI chừa chúng ra, nếu không bấm ẩn xong là mất luôn nút để bấm lại.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Icon = require(ReplicatedStorage.Packages.TopbarPlus)
local Manager = require(script.Parent.Modals.Manager)

local localPlayer = Players.LocalPlayer

local TopBarController = {}

-- Icon trong bộ material chính chủ Roblox (đã verify IsLoaded=true trong Studio).
local ICON_HIDE = "rbxassetid://6031075929" -- mắt gạch chéo
local ICON_SETTINGS = "rbxassetid://6031280882" -- bánh răng
-- Ổ khoá (bộ icon Roblox chính chủ, cùng bộ với hai icon trên nên nhìn đồng bộ).
local ICON_CAMERA_LOCK = "rbxassetid://6031082533"

--[[
	══ SHIFT LOCK TỰ DỰNG ═══════════════════════════════════════════════════════════════════

	⚠️ KHÔNG dùng `Player.DevTouchCameraMode` / `DevComputerCameraMode` — ĐÃ THỬ VÀ HỎNG
	(2026-08-14). Hai thuộc tính đó chỉ SERVER ghi được; gọi từ LocalScript thì Roblox ném
	thẳng lỗi và nút thành nút câm:
	    "The current thread cannot set 'DevTouchCameraMode' (lacking capability RobloxScript)"
	Chúng cũng không phải thứ user muốn: `Follow` chỉ xoay camera theo hướng chạy, còn shift
	lock là NHÂN VẬT XOAY THEO CAMERA (chạy ngang mà vẫn nhìn thẳng) — hai hành vi khác hẳn.

	Nên dựng tay, và đây là toàn bộ shift lock:
	  1. Nhân vật luôn quay theo hướng camera  ⇒ tắt `AutoRotate` rồi tự ghi CFrame mỗi frame.
	  2. Trên PC khoá con trỏ vào giữa màn hình (`MouseBehavior = LockCenter`) để rê chuột là
	     xoay camera. Trên mobile không có con trỏ nên bỏ qua — vuốt màn hình vẫn xoay camera,
	     và nhân vật xoay theo, đúng thứ người chơi obby cần.

	Chạy ở `RenderPriority.Character.Value + 1`: PHẢI sau bước cập nhật nhân vật mặc định của
	Roblox, chạy trước là bị nó ghi đè ngay trong cùng frame và nhân vật giật qua lại.
]]
--[[
	══ CHỈ MOBILE MỚI CÓ NÚT NÀY (user 2026-08-20) ═════════════════════════════════════════

	User: "trên PC nếu bật thì nó khoá luôn con trỏ — muốn chức năng này chỉ có trên thiết bị
	di động". Đúng vậy: `MouseBehavior = LockCenter` ghim con trỏ vào giữa màn hình, nên trên
	PC người chơi hết bấm được các nút HUD (Shop, Daily, Custom Speed…) cho tới khi tắt lại.
	Mà trên PC nút này vốn cũng thừa — Roblox đã có Shift Lock sẵn.

	NHẬN DIỆN — phải hỏi ĐỦ BA thứ, không chỉ `TouchEnabled`:
	  • `TouchEnabled` một mình là SAI: laptop cảm ứng và màn hình cảm ứng trên PC đều bật cờ
	    này, và đó chính là nhóm máy bị dính lỗi con trỏ.
	  • `KeyboardEnabled` / `MouseEnabled` = có bàn phím/chuột thật ⇒ là máy tính.
	  • `IsTenFootInterface()` = console (Xbox), cũng không phải mobile.
	Kết luận: mobile = có cảm ứng, KHÔNG bàn phím, KHÔNG chuột, KHÔNG phải console.
]]
local function isMobileDevice(): boolean
	return UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled
		and not GuiService:IsTenFootInterface()
end

local CAMERA_LOCK_BIND = "SpeedEscapeCameraLock"
local cameraLocked = false

local function applyCameraLockStep()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		return
	end
	humanoid.AutoRotate = false

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- Chỉ lấy thành phần NGANG của hướng nhìn: giữ nguyên Y thì nhân vật ngả người theo góc
	-- camera nhìn lên/xuống.
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then
		return
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
end

local function setCameraLocked(locked: boolean)
	if cameraLocked == locked then
		return
	end
	cameraLocked = locked

	if locked then
		RunService:BindToRenderStep(CAMERA_LOCK_BIND, Enum.RenderPriority.Character.Value + 1, applyCameraLockStep)
		--[[
			DÂY AN TOÀN THỨ HAI. Nút chỉ được dựng trên mobile (xem `isMobileDevice`), nên
			nhánh này lẽ ra không bao giờ chạy trên máy có chuột. Vẫn kiểm lại ở đây vì hậu
			quả đoán sai là nặng và IM LẶNG: con trỏ bị ghim giữa màn hình, người chơi không
			bấm được nút HUD nào và cũng không hiểu vì sao. Điều kiện cũ (`not TouchEnabled`)
			để lọt đúng nhóm máy tính CÓ cảm ứng — chính là nhóm user báo lỗi.
		]]
		if not UserInputService.MouseEnabled and not UserInputService.KeyboardEnabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		return
	end

	RunService:UnbindFromRenderStep(CAMERA_LOCK_BIND)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
	end
end

--[[
	Hồi sinh là có Humanoid MỚI, mà `AutoRotate = false` nằm trên Humanoid cũ. Không gắn lại
	thì sau lần chết đầu tiên nút vẫn sáng nhưng nhân vật quay tự do như chưa khoá.
	`applyCameraLockStep` tự set `AutoRotate` mỗi frame nên chỉ cần đảm bảo nó còn chạy.
]]
localPlayer.CharacterAdded:Connect(function()
	if cameraLocked then
		task.defer(function()
			if cameraLocked then
				RunService:UnbindFromRenderStep(CAMERA_LOCK_BIND)
				RunService:BindToRenderStep(
					CAMERA_LOCK_BIND,
					Enum.RenderPriority.Character.Value + 1,
					applyCameraLockStep
				)
			end
		end)
	end
end)

-- ScreenGui của TopbarPlus — không bao giờ được tắt. Đo trong Studio: nó dựng tới BỐN cái
-- (`TopbarStandard`, `TopbarCentered` + hai bản `…Clipped` để vẽ dropdown tràn ra ngoài
-- widget), nên khớp theo TIỀN TỐ chứ đừng liệt kê tay — thiếu bản Clipped là bấm ẩn xong
-- dropdown Cài đặt mất tiêu.
local function isTopbarPlusGui(gui: Instance): boolean
	return gui.Name:sub(1, 6) == "Topbar"
end

--[[
	CẦN ĐIỀU KHIỂN ĐƯỢC MỚI CHƠI ĐƯỢC (bug user báo 2026-08-21).

	Trên mobile, nút NHẢY và cần điều khiển di chuyển KHÔNG nằm trong CoreGui — `PlayerModule`
	tự dựng một ScreenGui tên `TouchGui` (bên trong là `TouchControlFrame` chứa `JumpButton`
	và `DynamicThumbstickFrame`) rồi cắm thẳng vào **PlayerGui**. Vòng quét bên dưới tắt mọi
	LayerCollector trong PlayerGui, nên nó vơ luôn cả cụm điều khiển: bấm "Ẩn giao diện" là
	người chơi mobile đứng chôn chân, không nhảy không đi được, và cũng không có cách nào
	đoán ra vì nút topbar vẫn còn đó.

	"Ẩn giao diện" là để quay phim/chụp ảnh — HUD của game phải biến mất, còn ĐIỀU KHIỂN thì
	không: đó là thứ duy nhất giữ cho người chơi vẫn chơi được trong lúc quay. Roblox cũng
	theo đúng nguyên tắc này (`CoreGuiType.Backpack/Health/PlayerList` tắt được, cụm điều
	khiển cảm ứng thì không).

	Khớp theo TIỀN TỐ `Touch`: tuỳ phiên bản PlayerModule mà có thêm `TouchGui`, `TouchJump`,
	`TouchControlFrame`… — liệt kê tay là kiểu gì cũng sót ở lần Roblox cập nhật kế tiếp.
	`SpeedEscapeTouchControls` là ScreenGui nút SLIDE mobile của chính mình
	(`Movement/MobileSlideButton`): cũng là ĐIỀU KHIỂN, nên ở lại cùng nút nhảy.
]]
local function isTouchControlGui(gui: Instance): boolean
	return gui.Name:sub(1, 5) == "Touch" or gui.Name == "SpeedEscapeTouchControls"
end

-- CoreGui bị tắt khi ẩn giao diện. **Chat KHÔNG có trong danh sách** (yêu cầu 2026-07-29:
-- người chơi vẫn phải chat được khi đang quay video / chụp ảnh).
local CORE_GUI_TO_HIDE = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.EmotesMenu,
}

local isHidden = false
-- Nhớ ScreenGui nào ĐANG bật lúc ẩn, để lúc hiện lại không bật nhầm modal vốn đã đóng.
local suppressed: { [LayerCollector]: boolean } = {}

local function applyHidden(hide: boolean)
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	for _, gui in playerGui:GetChildren() do
		if gui:IsA("LayerCollector") and not isTopbarPlusGui(gui) and not isTouchControlGui(gui) then
			if hide then
				if gui.Enabled then
					suppressed[gui] = true
					gui.Enabled = false
				end
			elseif suppressed[gui] then
				gui.Enabled = true
			end
		end
	end
	if not hide then
		table.clear(suppressed)
	end

	for _, coreGuiType in CORE_GUI_TO_HIDE do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(coreGuiType, not hide)
		end)
	end
end

local function setHidden(hide: boolean)
	if isHidden == hide then
		return
	end
	isHidden = hide
	applyHidden(hide)
end

function TopBarController.Init()
	localPlayer:WaitForChild("PlayerGui")

	--[[
		1. Nút ẩn giao diện. `oneClick(false)` (mặc định) ⇒ bấm lần nữa là bỏ chọn, đúng kiểu
		   công tắc; trạng thái "đang chọn" cũng chính là dấu hiệu giao diện đang bị ẩn.

		⚠️ `autoDeselect(false)` — ĐỪNG GỠ (bug user 2026-08-21: "bật ẩn UI rồi bấm khoá màn
		hình thì UI hiện lại, và ngược lại").

		TopbarPlus mặc định `deselectWhenOtherIconSelected = true` cho MỌI icon
		(`Packages/_Index/…/topbarplus/src/init.lua`, dòng 236), và ở dòng 384 nó nghe
		`anyIconSelected`: hễ một icon được chọn thì mọi icon khác có cờ đó tự bỏ chọn. Mặc
		định này hợp lý cho MENU — kiểu radio, mỗi lúc mở một bảng. Nhưng Ẩn-giao-diện và
		Khoá-camera là hai CÔNG TẮC ĐỘC LẬP: bật cái này không có lý do gì tắt cái kia.

		Đây là lý do triệu chứng đối xứng một cách kỳ lạ (bật A rồi bấm B thì A tắt, và ngược
		lại) — không phải hai lỗi, mà là một cơ chế radio dùng nhầm chỗ. Vì việc bỏ chọn đi qua
		đúng `bindEvent("deselected")` nên `setHidden(false)`/`setCameraLocked(false)` chạy
		thật, không có lỗi nào in ra.

		Phải tắt cờ ở CẢ HAI icon: dòng 384 chỉ bỏ chọn khi cả hai bên đều còn bật cờ.
	]]
	Icon.new()
		:setName("HideUiIcon")
		:setImage(ICON_HIDE)
		:setCaption("Ẩn giao diện")
		:autoDeselect(false)
		:bindEvent("selected", function()
			setHidden(true)
		end)
		:bindEvent("deselected", function()
			setHidden(false)
		end)

	--[[
		2. Nút cài đặt — giờ MỞ MODAL `Modals/SettingsModal` thay vì bung dropdown.

		Bản cũ nhét ba công tắc vào dropdown TopbarPlus. Dropdown đó không chứa nổi slider
		âm lượng (yêu cầu 2026-08-04), chữ quá nhỏ để đọc trạng thái BẬT/TẮT khi liếc qua,
		và nhìn hoàn toàn lạc khỏi hệ UI vàng-cam của game. Modal mới giữ cả ba công tắc cũ
		(chuyển sang tab HIỂN THỊ / ÂM THANH) nên không mất chức năng nào.

		`oneClick(true)` để icon không kẹt ở trạng thái "đang chọn" sau khi modal đã đóng
		bằng nút X — trạng thái chọn của icon và trạng thái mở của modal là hai thứ khác
		nhau, để chúng tự đồng bộ chỉ tổ lệch pha.
	]]
	Icon.new()
		:setName("SettingsIcon")
		:setImage(ICON_SETTINGS)
		:setCaption("Cài đặt")
		:oneClick(true)
		:bindEvent("selected", function()
			Manager.ToggleSettings()
		end)

	--[[
		3. KHOÁ CAMERA — thêm 2026-08-14 theo yêu cầu user, chủ yếu phục vụ người chơi mobile.

		Vấn đề nó giải quyết: trên điện thoại, ngón trái đẩy joystick còn ngón phải vuốt để xoay
		camera. Đang chạy obby mà lỡ chạm nửa màn hình phải là camera xoay ngang, người chơi mất
		phương hướng giữa lúc đang nhảy — và ở game này tốc độ 100–250 WS thì mất phương hướng
		nửa giây là rơi.

		Cách khoá: shift lock TỰ DỰNG — nhân vật xoay theo camera mỗi frame. Toàn bộ cơ chế và
		lý do KHÔNG dùng `DevTouchCameraMode` nằm ở khối "SHIFT LOCK TỰ DỰNG" đầu file; đừng
		đọc mỗi khối này rồi đi tìm `DevTouchCameraMode` trong code, nó đã bị gỡ từ 2026-08-14.

		`oneClick(false)` (mặc định): đây là CÔNG TẮC, trạng thái "đang chọn" của icon chính là
		dấu hiệu camera đang khoá — khác với nút Cài đặt vốn chỉ mở modal rồi thôi.
	]]
	--[[
		BẬT/TẮT THEO THIẾT BỊ, ĐÁNH GIÁ LẠI ĐƯỢC — không phải quyết định một lần lúc khởi động.

		Bản đầu (2026-08-20) chỉ `return` sớm nếu không phải mobile, tức chốt cứng ngay lúc
		`Init`. Nó đúng với 99% phiên, nhưng hỏng im lặng ở hai ca có thật:
		  • Máy tính bảng đang chơi rồi CẮM bàn phím rời (hoặc gập vào dock) — `KeyboardEnabled`
		    bật lên giữa phiên. Nút vẫn nằm đó, bấm vào là ghim con trỏ, đúng lỗi cũ.
		  • Điện thoại nối tay cầm/bàn phím Bluetooth — y hệt.
		Chốt cứng lúc khởi động thì không sửa được cho tới khi người chơi thoát game.

		Nên: LUÔN dựng nút, rồi `setEnabled` theo thiết bị và nghe cả ba cờ đầu vào để đánh giá
		lại. Rời khỏi diện mobile mà nút đang bật thì TỰ NHẢ KHOÁ — không bao giờ để ai kẹt con
		trỏ vì một cái nút vừa biến mất khỏi màn hình.
	]]
	local cameraLockIcon = Icon
		.new()
		:setName("CameraLockIcon")
		:setImage(ICON_CAMERA_LOCK)
		:setCaption("Khoá camera")
		-- Xem khối lý do dài ở `HideUiIcon`: hai công tắc độc lập, KHÔNG phải radio.
		:autoDeselect(
			false
		)
		:bindEvent("selected", function()
			setCameraLocked(true)
		end)
		:bindEvent("deselected", function()
			setCameraLocked(false)
		end)

	local function syncCameraLockAvailability()
		local mobile = isMobileDevice()
		cameraLockIcon:setEnabled(mobile)
		if not mobile and cameraLocked then
			-- Gọi cả hai: `deselect` để icon không kẹt trạng thái "đang chọn" nếu sau này
			-- thiết bị quay lại diện mobile, và `setCameraLocked` để chắc chắn con trỏ được
			-- nhả kể cả khi `deselect` không phát sự kiện. Hàm này tự bỏ qua nếu trùng trạng thái.
			cameraLockIcon:deselect()
			setCameraLocked(false)
		end
	end

	syncCameraLockAvailability()
	for _, prop in { "TouchEnabled", "KeyboardEnabled", "MouseEnabled" } do
		UserInputService:GetPropertyChangedSignal(prop):Connect(syncCameraLockAvailability)
	end
end

function TopBarController.Start()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	-- ScreenGui dựng SAU khi đã ẩn (modal mở lần đầu, ReviveModal…) cũng phải tắt theo,
	-- nếu không bấm ẩn xong mở modal là giao diện lòi ra lại.
	-- ⚠️ Phải lọc y hệt `applyHidden`, kể cả cụm điều khiển cảm ứng: Roblox HUỶ RỒI DỰNG LẠI
	-- `TouchGui` mỗi lần đổi kiểu điều khiển, nên bản dựng lại đi qua đúng nhánh này. Thiếu
	-- `isTouchControlGui` ở đây thì lỗi "ẩn UI xong hết nhảy được" quay lại, chỉ khác là nó
	-- chỉ xuất hiện khi người chơi đổi kiểu điều khiển giữa lúc đang ẩn — càng khó lần ra.
	playerGui.ChildAdded:Connect(function(child)
		if not isHidden or not child:IsA("LayerCollector") or isTopbarPlusGui(child) or isTouchControlGui(child) then
			return
		end
		local collector = child :: LayerCollector
		task.defer(function()
			if isHidden and collector.Parent and collector.Enabled then
				suppressed[collector] = true
				collector.Enabled = false
			end
		end)
	end)
end

return TopBarController
