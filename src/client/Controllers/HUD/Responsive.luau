--!strict
--[[
	══════════════════════════════════════════════════════════════════════════════════════════
	  Responsive — HỆ CO GIÃN CHUẨN CỦA GAME ROBLOX LỚN (v3, 2026-08-17)
	══════════════════════════════════════════════════════════════════════════════════════════

	── HAI QUY TẮC, KHÔNG CÓ QUY TẮC THỨ BA ───────────────────────────────────────────────────

	  1. MỘT TỈ LỆ DUY NHẤT cho toàn bộ HUD:  scale = min(vw/1920, vh/1080)
	     Mọi thứ — nút, chữ, viền, khoảng cách bên trong một cụm — nhân đúng con số này. Nhờ vậy
	     mọi khối GIỮ NGUYÊN tỉ lệ với nhau trên mọi máy: nút Shop luôn to bằng nút Rebirth, chữ
	     luôn chiếm đúng chừng ấy phần của nút, viền luôn dày đúng chừng ấy phần của khung.

	  2. MỖI CỤM BÁM VÀO GÓC/MÉP CỦA NÓ, với lề đã nhân `scale`.
	     Menu trái cách MÉP TRÁI MÀN HÌNH 28×scale. Cụm đáy cách MÉP DƯỚI 50×scale. Cột phải cách
	     MÉP PHẢI 20×scale. Modal nằm giữa. Y hệt cách CSS `position: fixed` + `margin` hoạt động,
	     và y hệt cách mọi simulator Roblox lớn dựng HUD.

	── VÌ SAO ĐÂY MỚI LÀ "GIỐNG NHAU TRÊN MỌI MÁY" ────────────────────────────────────────────

	Người chơi nhìn thấy "giống nhau" khi: mỗi khối có CÙNG KÍCH THƯỚC tương đối, và nằm CÙNG
	KHOẢNG CÁCH tính từ góc màn hình của nó. Quy tắc 1 lo vế đầu, quy tắc 2 lo vế sau.

	Thử "dán cứng cả bản vẽ 16:9 vào giữa màn hình" (bản 2026-08-17 trưa) thì SAI vế thứ hai:
	trên iPhone XR (2.16:1) bản vẽ chỉ chiếm 668/896 px bề ngang, nên menu trái cách mép màn hình
	13.8% trong khi trên PC chỉ 1.5%. Cùng một bản vẽ, nhưng mắt nhìn ra ngay là hai bố cục khác
	nhau — và 25% bề ngang màn hình bỏ trống. Đó chính là cái user thấy "vẫn không đúng".

	── VÌ SAO KHÔNG BAO GIỜ VỠ BỐ CỤC (khác hẳn bản 2026-08-17 sáng) ──────────────────────────

	Vì `scale` là phép CONTAIN, màn hình quy về design px LUÔN LỚN HƠN HOẶC BẰNG bản vẽ
	1920×1080 ở cả hai chiều. Hệ quả hình học: cụm chỉ có thể DÃN RA XA nhau, không bao giờ bị
	dồn vào nhau. Không có cắt xén, không có chồng lấn, không cần một cái kẹp nào.

	Bản sáng nay phóng LỚN HƠN contain (×1.45, rồi "sàn ngón tay") nên màn hình quy đổi NHỎ HƠN
	bản vẽ — cụm bị dồn vào phần còn nhìn thấy, và đó là lúc chữ hệ số đè lên dải tutorial.

	Và vì contain luôn khít MỘT chiều, mỗi máy chỉ dãn theo ĐÚNG MỘT trục:
	    điện thoại (rộng hơn 16:9) → khít chiều CAO, chỉ dãn ngang ⇒ mọi toạ độ dọc y hệt bản vẽ
	    iPad (cao hơn 16:9)        → khít chiều NGANG, chỉ dãn dọc ⇒ mọi toạ độ ngang y hệt bản vẽ
	    máy 16:9                   → không dãn gì cả ⇒ TRÙNG KHÍT bản vẽ 1920×1080, từng pixel

	── QUY ƯỚC ĐƠN VỊ ─────────────────────────────────────────────────────────────────────────
	    • design px — đơn vị của bản vẽ 1920×1080. MỌI số trong code UI đều là đơn vị này.
	    • px thật   — pixel trên máy người chơi = design px × scale.
	  Chỉ thứ thuộc về PHẦN CỨNG mới là px thật và phải chia `scale` để về design px: chiều cao
	  topbar Roblox, và ngưỡng chạm của ngón tay. Không có ngoại lệ nào khác.

	── KHÔNG ĐƯỢC require `Theme` Ở ĐÂY ───────────────────────────────────────────────────────
	`Theme` require file này, nên chiều ngược lại là vòng require. Chỉ dùng `State` + `Tokens`.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.State)
local Tokens = require(script.Parent.Tokens)

local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local Responsive = {}

export type DeviceClass = "phone" | "tablet" | "desktop" | "console"

--[[
	MÀN HÌNH, quy về design px của bản vẽ 1920×1080.

	LUÔN chứa trọn bản vẽ: `Left` ≤ 0, `Right` ≥ 1920, `Bottom` ≥ 1080 (xem khối lý do đầu file).
	`Top` là ngoại lệ có chủ ý — nó đã CỘNG chiều cao topbar Roblox, nên có thể > 0.
]]
export type Screen = {
	Left: number,
	Top: number,
	Right: number,
	Bottom: number,
	Width: number,
	Height: number,
	Scale: number,
	Class: DeviceClass,
}

--[[
	Lớp thiết bị. CHỈ dùng cho vùng chạm ngón tay — KHÔNG ảnh hưởng tỉ lệ hay bố cục.
	Bố cục chỉ có một, suy ra từ hai quy tắc ở đầu file.
]]
Responsive.deviceClass = Value("desktop" :: DeviceClass)

--[[
	Có phải thiết bị điều khiển bằng NGÓN TAY không.

	`TouchEnabled` một mình chưa đủ: laptop cảm ứng báo `true` nhưng người chơi vẫn dùng chuột.
	Nới vùng chạm trên PC chỉ tạo ra những ô bấm vô hình chồng lên nhau, hại nhiều hơn lợi.
]]
function Responsive.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function classify(viewport: Vector2, isTouch: boolean): DeviceClass
	if GuiService:IsTenFootInterface() then
		return "console"
	end
	if not isTouch then
		return "desktop"
	end
	local shortAxis = math.min(viewport.X, viewport.Y)
	if shortAxis <= Tokens.DEVICE.PHONE_MAX_SHORT_AXIS then
		return "phone"
	elseif shortAxis <= Tokens.DEVICE.TABLET_MAX_SHORT_AXIS then
		return "tablet"
	end
	return "desktop"
end

--[[
	BỘ GIẢI — hàm thuần, một phép `min`.

	Vì sao tách hàm cho một dòng: KHÔNG THỂ đổi cỡ viewport của Studio bằng script, nên đây là
	cách duy nhất đo được bố cục của mọi máy trong một lần chạy. Đã có ba hệ bị bác vì chỉ nhìn
	bằng mắt trên đúng một cỡ màn hình.
]]
function Responsive.Solve(viewport: Vector2, isTouch: boolean): (number, DeviceClass)
	local scale = math.min(viewport.X / Tokens.DESIGN_WIDTH, viewport.Y / Tokens.DESIGN_HEIGHT)
	return math.clamp(scale, Tokens.MIN_SCALE, Tokens.MAX_SCALE), classify(viewport, isTouch)
end

-- Cạnh ngắn tối thiểu của một vùng chạm, quy về DESIGN px ở tỉ lệ hiện tại.
function Responsive.TouchMinDesign(): number
	return Tokens.TOUCH.MIN_PX / math.max(0.01, State.viewportScale:get())
end

--[[
	TÍNH LẠI TOÀN BỘ. Gọi khi viewport / topbar / hướng màn hình đổi.

	Nơi DUY NHẤT được ghi `State.viewportScale`, `State.viewportSize`, `State.guiInsetTop` và
	`Responsive.deviceClass`. Ghi cùng một nhịp: ghi lẻ tẻ thì có một khoảnh khắc `Computed` đọc
	được tỉ lệ mới ghép với inset cũ, và HUD nhảy một cái rồi mới về đúng chỗ.
]]
function Responsive.Recompute()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local scale, class = Responsive.Solve(viewport, Responsive.IsTouch())

	State.guiInsetTop:set(GuiService:GetGuiInset().Y)
	State.viewportSize:set(viewport)
	State.viewportScale:set(scale)
	Responsive.deviceClass:set(class)
end

--[[
	MÀN HÌNH THẬT, quy về design px — thứ mà mọi cụm HUD bám vào.

	Cách đọc: nếu máy đúng 16:9 thì hàm này trả về (0, 0, 1920, 1080) — tức bản vẽ gốc, không sai
	một pixel. Máy rộng hơn thì `Left` âm và `Right` > 1920 (thừa ra hai bên); máy cao hơn thì
	`Top`/`Bottom` nới ra. KHÔNG BAO GIỜ hẹp hơn bản vẽ.

	`Top` đã cộng chiều cao topbar Roblox (HUD đặt `IgnoreGuiInset = true` nên canvas bắt đầu từ
	mép trên tuyệt đối, còn topbar phủ đè lên đó). Topbar là vật lý — nó cao 58 px thật trên điện
	thoại dù UI có co nhỏ tới đâu — nên phải chia `scale` để quy về design px.
]]
function Responsive.Screen(): Screen
	local scale = State.viewportScale:get()
	local viewport = State.viewportSize:get()

	local visibleWidth = viewport.X / scale
	local visibleHeight = viewport.Y / scale
	local left = (Tokens.DESIGN_WIDTH - visibleWidth) * 0.5
	local top = (Tokens.DESIGN_HEIGHT - visibleHeight) * 0.5
	local insetDesign = State.guiInsetTop:get() / scale

	return {
		Left = left,
		Top = top + insetDesign,
		Right = left + visibleWidth,
		Bottom = top + visibleHeight,
		Width = visibleWidth,
		Height = visibleHeight - insetDesign,
		Scale = scale,
		Class = Responsive.deviceClass:get(),
	}
end

export type AnchorProps = {
	-- Mép nào của MÀN HÌNH thì cụm bám vào.
	X: "left" | "center" | "right",
	Y: "top" | "center" | "bottom",
	-- Cỡ cụm (design px) — cần để neo phải/dưới/giữa.
	Width: number,
	Height: number,
	-- Lề tính từ mép màn hình, bằng design px (sẽ được nhân `scale` như mọi thứ khác).
	MarginX: number?,
	MarginY: number?,
	--[[
		Xê dịch thêm khi neo GIỮA. Dùng để khớp đúng bản vẽ gốc: cụm menu trái trong bản vẽ nằm ở
		y = 236 chứ không phải 224 (tâm hình học), tức lệch +12. Không có `Bias` thì hoặc phải bỏ
		neo-giữa (hỏng trên iPad), hoặc chấp nhận lệch 12px so với bản thiết kế.
	]]
	BiasY: number?,
}

--[[
	NEO MỘT CỤM VÀO MÉP MÀN HÌNH.

	Đây là toàn bộ "quy tắc 2". Mọi cụm HUD đi qua đúng hàm này, nên không còn chỗ nào tự chế ra
	một công thức riêng — thứ đã làm 5 cụm trôi mỗi cái một kiểu trước 2026-08-17.

	⚠️ Trả về toạ độ DESIGN, có thể ÂM hoặc lớn hơn 1920 trên máy không phải 16:9. Đó là đúng:
	cụm đang bám vào mép màn hình thật, vốn nằm ngoài khung bản vẽ.
]]
function Responsive.AnchorPos(props: AnchorProps): UDim2
	local s = Responsive.Screen()

	local x: number
	if props.X == "left" then
		x = s.Left + (props.MarginX or 0)
	elseif props.X == "right" then
		x = s.Right - props.Width - (props.MarginX or 0)
	else
		x = s.Left + (s.Width - props.Width) * 0.5
	end

	local y: number
	if props.Y == "top" then
		y = s.Top + (props.MarginY or 0)
	elseif props.Y == "bottom" then
		y = s.Bottom - props.Height - (props.MarginY or 0)
	else
		y = s.Top + (s.Height - props.Height) * 0.5 + (props.BiasY or 0)
	end

	return UDim2.fromOffset(x, y)
end

function Responsive.Anchor(props: AnchorProps)
	return Computed(function()
		return Responsive.AnchorPos(props)
	end)
end

--[[
	══ VÙNG CHẠM VÔ HÌNH ════════════════════════════════════════════════════════════════════

	Gắn một nút TRONG SUỐT lớn hơn lên trên một nút nhỏ: ngón tay bấm trúng mà HÌNH VẼ KHÔNG ĐỔI
	MỘT PIXEL NÀO.

	Đây là cách DUY NHẤT được phép giải quyết chuyện nút nhỏ trên điện thoại. Cách kia — phóng
	`scale` to hơn contain — đã bị bác hai lần, và lý do nằm ở khối đầu file: phóng quá contain là
	bản vẽ tràn ra ngoài màn hình, kéo theo cắt xén và chồng lấn.

	── VÌ SAO ĐO `AbsoluteSize` CHỨ KHÔNG DÙNG CỠ KHAI BÁO ────────────────────────────────────
	Helper cũ (`Theme.MakeTouchTarget`) bắt caller tự truyền `designSize`. Đó là lý do nó chưa bao
	giờ được nối vào đâu: hàng trăm nút, mỗi nút phải gõ tay một con số, mà nút nằm trong
	`UIGridLayout` hoặc khai bằng `fromScale` thì caller CŨNG KHÔNG BIẾT cỡ thật của nó.

	── HAI CÁI BẪY ĐÃ TRÁNH ───────────────────────────────────────────────────────────────────
	  1. `ClipsDescendants` của cha sẽ CẮT CỤT vùng chạm. `MakeSurface` chỉ clip ở lớp RUỘT, nên
	     vùng chạm phải gắn vào lớp NGOÀI.
	  2. Nới quá tay thì vùng chạm hai nút cạnh nhau chồng lên nhau và CƯỚP cú bấm của nhau —
	     người chơi bấm trúng mà ra sai chức năng, khó chịu hơn hẳn nút nhỏ. Vì vậy có trần
	     `TOUCH.MAX_GROWTH`.
]]
export type HitAreaOptions = {
	MaxGrowth: number?,
	ZIndex: number?,
	--[[
		⚠️ BẮT BUỘC TRUYỀN NẾU NÚT CÓ HIỆU ỨNG BẤM — nếu không, nút MẤT phản hồi trên cảm ứng.

		Lớp chạm nằm ĐÈ LÊN nút nên nó nuốt luôn `InputBegan`/`InputEnded` mà hiệu ứng "nhún khi
		bấm" đang dựa vào: ngón tay chạm mà nút đứng im như hỏng. Đây là cái giá của mọi kiểu
		vùng-chạm-phủ-lên, và cách trả là lớp chạm tự lái đúng hai state đó.
	]]
	Pressed: any?,
	Hovered: any?,
}

-- Trả về lớp chạm vừa gắn, hoặc nil trên thiết bị không cảm ứng (không gắn gì cả).
-- ⚠️ Phải khai kiểu trả về: thiếu nó thì Luau suy từ nhánh `return nil` ở đầu hàm ra kiểu
-- `nil`, và `return hit` ở cuối thành lỗi "Expected this to be 'nil', but got 'Instance'".
function Responsive.AttachHitArea(host: GuiObject, activated: () -> (), options: HitAreaOptions?): TextButton?
	if not Responsive.IsTouch() then
		return nil
	end

	--[[
		⚠️ PHẢI chú thích kiểu ở đây, đừng để Luau tự suy.

		`local opts = options or {}` cho ra kiểu `HitAreaOptions | {| |}` — bảng rỗng được suy
		thành một kiểu ĐÓNG không có key nào, nên mọi lần đọc `opts.MaxGrowth` / `opts.Pressed`
		… đều là lỗi "Key is missing from '{| |}'". Chỉ MỘT dòng này sinh ra ~150 lỗi type,
		nhiều nhất toàn repo.

		Chú thích `: HitAreaOptions` làm bảng rỗng được ép về đúng kiểu (mọi field đều optional
		nên `{}` hợp lệ), union biến mất, và các lần đọc field bên dưới thành hợp kiểu thật.
	]]
	local opts: HitAreaOptions = options or {}
	local maxGrowth = opts.MaxGrowth or Tokens.TOUCH.MAX_GROWTH

	local hit = New("TextButton")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Name = "HitArea",
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Text = "",
		ZIndex = opts.ZIndex or 200,
		[OnEvent("Activated")] = activated,
	}) :: TextButton
	-- ⚠️ Ép kiểu BẮT BUỘC: `Fusion.New` khai báo trả về `Instance`, nên nếu không ép thì mọi
	-- lần đọc `hit.Size` / `hit.InputBegan` / `hit.InputEnded` bên dưới đều là lỗi
	-- "Key not found in external type 'Instance'".

	--[[
		Cập nhật bằng tay (không phải `Computed`): `AbsoluteSize` không phải state Fusion, nên
		`Computed` đọc nó sẽ chốt giá trị ở lần chạy đầu và không bao giờ tính lại — đúng cái bẫy
		đã ghi ở `State.guiInsetTop`.
	]]
	local function refresh()
		local abs = host.AbsoluteSize
		if abs.X <= 0 or abs.Y <= 0 then
			return
		end
		local scale = math.max(0.01, State.viewportScale:get())
		-- Thiếu bao nhiêu px THẬT thì bù bấy nhiêu, quy về design px vì `Size` của lớp chạm nằm
		-- trong cùng hệ toạ độ đã bị `UIScale` co.
		local padX = math.max(0, (Tokens.TOUCH.MIN_PX - abs.X)) / scale
		local padY = math.max(0, (Tokens.TOUCH.MIN_PX - abs.Y)) / scale
		local designX, designY = abs.X / scale, abs.Y / scale
		padX = math.min(padX, designX * (maxGrowth - 1))
		padY = math.min(padY, designY * (maxGrowth - 1))
		hit.Size = UDim2.new(1, padX, 1, padY)
	end

	hit.Parent = host
	refresh()
	State.sweeper:Add(host:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh))
	State.sweeper:Add(Fusion.Observer(State.viewportScale):onChange(refresh))

	-- Trả lại phản hồi bấm mà chính lớp chạm này vừa nuốt mất (xem `HitAreaOptions.Pressed`).
	if opts.Pressed or opts.Hovered then
		local function setFeedback(down: boolean)
			if opts.Pressed then
				opts.Pressed:set(down)
			end
			if opts.Hovered then
				opts.Hovered:set(down)
			end
		end
		State.sweeper:Add(hit.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				setFeedback(true)
			end
		end))
		State.sweeper:Add(hit.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				setFeedback(false)
			end
		end))
	end

	return hit
end

--[[
	Nối các tín hiệu làm tỉ lệ đổi. Gọi MỘT LẦN lúc HUD khởi động.

	`TopbarInset` là tín hiệu bắt buộc chứ không phải "cho chắc": lúc HUD dựng xong thì topbar
	Roblox chưa nạp và `GetGuiInset()` còn trả 0. Không bắt nó thì mọi cụm neo mép TRÊN chốt vị
	trí theo inset = 0 và nằm chui dưới topbar suốt phiên chơi.

	`GetPropertyChangedSignal("CurrentCamera")` cũng vậy: camera bị thay khi respawn/cutscene, và
	tín hiệu ViewportSize cũ chết theo camera cũ.
]]
function Responsive.Connect()
	Responsive.Recompute()

	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			State.sweeper:Add(camera:GetPropertyChangedSignal("ViewportSize"):Connect(Responsive.Recompute))
		end
		Responsive.Recompute()
	end

	bindCamera()
	State.sweeper:Add(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	State.sweeper:Add(GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(Responsive.Recompute))

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		--[[
			══ KHOÁ NGANG MÀN HÌNH ══════════════════════════════════════════════════════════

			Bản vẽ là 16:9 nằm ngang. Ở màn dọc, contain sẽ khít CHIỀU NGANG và tỉ lệ rơi xuống
			rất thấp (400×700 ⇒ 0.208, chữ Level còn 8 px — không đọc nổi), đồng thời cụm HUD đáy
			rộng 1160 design px chiếm gần trọn bề ngang.

			⚠️ Muốn hỗ trợ dọc thật sự thì phải VẼ LẠI bố cục dọc, không phải chỉnh hằng số.
		]]
		playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
		State.sweeper:Add(playerGui:GetPropertyChangedSignal("CurrentScreenOrientation"):Connect(Responsive.Recompute))
	end
end

return Responsive
