--!strict
--[[
	══════════════════════════════════════════════════════════════════════════════════════════
	  ModalShell — MỘT KHUÔN VỎ DUY NHẤT CHO MỌI MODAL
	══════════════════════════════════════════════════════════════════════════════════════════

	Dựng trọn ba lớp mà TRƯỚC ĐÂY 11 modal đều tự chép lại:

	    Frame phủ canvas (bật/tắt theo `Mounted`)          ← Tokens.Z.MODAL_ROOT
	     └─ CanvasGroup vỏ modal (mờ dần + trượt lên)      ← Tokens.Z.MODAL_PANEL
	         ├─ UIScale (tuỳ chọn, thu nhỏ cả modal)
	         ├─ UICorner + UIStroke
	         ├─ Header: nền gradient + icon + tiêu đề + nút X
	         └─ Content  ← phần RIÊNG của từng modal, do caller truyền vào

	── VÌ SAO ─────────────────────────────────────────────────────────────────────────────────
	Ba lớp trên là ~55 dòng giống hệt nhau nhân với 11 file. Không ai chép 11 lần mà đúng cả 11,
	và đo lại 2026-08-16 thì đúng là không:

	    • icon header nằm ở 4 toạ độ khác nhau  (20,7) (18,8) (18,5) (24,8)
	    • tiêu đề nằm ở 4 toạ độ khác nhau      (100,4) (98,5) (98,2) (106,4)
	    • ZIndex header chỗ 45 chỗ 42, icon/tiêu đề chỗ 44 chỗ 47 chỗ 48
	    • nút X có 11 toạ độ gõ tay, trong đó 5 cái tràn ra ngoài ruột header đang
	      `ClipsDescendants = true` ⇒ BỊ CẮT CỤT (Rebirth, Code, GroupChest, Daily, Cosmetic)

	Giờ mọi số đo đọc từ `Tokens.MODAL` và nút X suy ra từ bề rộng vỏ, nên 11 modal không còn
	cách nào lệch nhau nữa — và thêm modal thứ 12 là tự động đúng.

	── VỎ VẪN LÀ `UICorner + UIStroke`, KHÔNG PHẢI `MakeSurface` ──────────────────────────────
	Cố ý. Vỏ modal để `BackgroundTransparency ≈ 0.3` cho nhìn xuyên thấy cảnh game; `MakeSurface`
	vẽ viền bằng một khối ĐẶC nằm dưới nên thân mờ sẽ hoà vào màu đen thay vì hoà vào cảnh —
	mất hẳn hiệu ứng kính mờ. Xem khối lý do dài ở `Theme.MakeSurface`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New

local ModalShell = {}

export type ModalShellProps = {
	--[[
		Tiền tố state của modal, ví dụ "shop". Từ đây suy ra `State.shopModalMounted`,
		`State.shopModalAnimation`, `State.shopCloseHovered` — cùng bộ tên mà `Manager` và
		`Modals/Registry` đang dùng, nên không có cách nào lệch tên giữa ba nơi.
	]]
	Id: string,

	Width: number,
	-- Modal có UIScale riêng có thể truyền viền bù để độ dày sau scale khớp Tokens.BORDER.
	Border: number?,
	-- Chiều cao vỏ. Nhận số THƯỜNG hoặc state Fusion (Settings đổi chiều cao theo tab đang mở).
	Height: any,
	--[[
		Chiều cao dùng để tính chỗ nhích lên của `Theme.ModalPosition`. Chỉ cần truyền khi
		`Height` là state động — lúc đó phải chốt một con số, nếu không vị trí modal sẽ nhảy
		theo hoạt ảnh đổi chiều cao.
	]]
	RaiseHeight: number?,
	-- Thu nhỏ CẢ modal quanh tâm. Xem khối lý do ở `ShopModal`.
	Scale: number?,

	PanelColor: Color3,
	PanelTransparency: number?,

	HeaderColor: any,
	HeaderColorB: any,
	HeaderBorderColor: Color3?,

	Icon: string,
	IconColor: Color3?,
	Title: string,
	TitleMaxTextSize: number?,
	-- Chỉ truyền khi header có thứ khác chen vào bên phải tiêu đề (xem `HeaderExtra`).
	TitleWidth: number?,
	-- Nội dung phụ nhét thêm vào header, ví dụ nhãn "−90%" của Starter Pack.
	HeaderExtra: { any }?,

	OnClose: () -> (),
	-- Mặc định lấy `State[Id .. "CloseHovered"]`; truyền tay khi modal tự giữ state riêng.
	CloseHovered: any?,

	Content: { any },
}

--[[
	Header RỘNG BẰNG ĐÚNG thân modal (không trừ lề): viền của nó vẽ ra ngoài thêm `BORDER` mỗi
	bên, nên mép ngoài rơi đúng mép ngoài viền của thân — hai đường viền trùng khít thành một.

	Toạ độ nút X suy từ bề rộng, KHÔNG gõ tay: `CLOSE_MARGIN` = 20 cho ra lề thật 20px tính từ
	mép ngoài modal — bằng đúng lề của icon bên trái (`EDGE_MARGIN`), nên thanh tiêu đề cân.
]]
local function closeButtonX(width: number): number
	return width - Tokens.MODAL.CLOSE_MARGIN - Tokens.MODAL.CLOSE_SIZE
end

local function buildHeader(props: ModalShellProps, closeHovered: any)
	local width = props.Width
	local headerWidth = width
	local closeX = closeButtonX(width)

	local content: { any } = {
		New("ImageLabel")({
			BackgroundTransparency = 1,
			Image = props.Icon,
			ImageColor3 = props.IconColor,
			Position = UDim2.fromOffset(Tokens.MODAL.ICON_X, Tokens.MODAL.ICON_Y),
			Size = UDim2.fromOffset(Tokens.MODAL.ICON_SIZE, Tokens.MODAL.ICON_SIZE),
			ZIndex = Tokens.Z.MODAL_HEADER_CONTENT,
		}),
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(Tokens.MODAL.TITLE_X, Tokens.MODAL.TITLE_Y),
			-- Chạy từ mép tiêu đề tới sát nút X. Tiêu đề căn TRÁI nên ô rộng hơn không làm chữ
			-- to lên (`TextScaled` bị `MaxTextSize` chặn trước) — nó chỉ cho tiêu đề dài chỗ thở.
			Size = UDim2.fromOffset(
				props.TitleWidth or (closeX - Tokens.MODAL.TITLE_GAP - Tokens.MODAL.TITLE_X),
				Tokens.MODAL.TITLE_HEIGHT
			),
			Text = props.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = props.TitleMaxTextSize or Tokens.MODAL.TITLE_MAX_TEXT_SIZE,
			ZIndex = Tokens.Z.MODAL_HEADER_CONTENT,
		}),
	}

	for _, child in props.HeaderExtra or {} do
		table.insert(content, child)
	end

	table.insert(
		content,
		Theme.MakeCloseButton({
			Position = UDim2.fromOffset(closeX, Tokens.MODAL.CLOSE_Y),
			Hovered = closeHovered,
			Activated = props.OnClose,
			ZIndex = Tokens.Z.MODAL_CLOSE,
		})
	)

	return Theme.MakeSurface({
		Position = UDim2.fromOffset(Tokens.MODAL.HEADER_INSET, Tokens.MODAL.HEADER_INSET),
		Size = UDim2.fromOffset(headerWidth, Tokens.MODAL.HEADER_HEIGHT),
		ZIndex = Tokens.Z.MODAL_HEADER,
		Radius = Tokens.RADIUS.HEADER,
		Border = props.Border or Tokens.MODAL.BORDER,
		-- Mặc định đen như 7/10 modal cũ. Ba modal từng dùng (18,18,30) / (6,20,26) — chênh lệch
		-- đó không nhìn ra được trên viền 4px, nên gom hết về một màu; modal nào thật sự cần khác
		-- thì truyền `HeaderBorderColor`.
		BorderColor = props.HeaderBorderColor or Tokens.COLOR.OUTLINE,
		Color = props.HeaderColor,
		ColorB = props.HeaderColorB,
		GradientRotation = 0,
		Content = content,
	})
end

--[[
	Vỏ CanvasGroup + header + nội dung. Trả về CanvasGroup, chưa có khung phủ canvas.
	Tách riêng để modal nào cần nhét thêm lớp ngoài vỏ vẫn dùng lại được.
]]
function ModalShell.BuildPanel(props: ModalShellProps)
	local animation = (State :: any)[props.Id .. "ModalAnimation"]
	local closeHovered = props.CloseHovered or (State :: any)[props.Id .. "CloseHovered"]

	local raiseHeight = props.RaiseHeight
	if raiseHeight == nil and typeof(props.Height) == "number" then
		raiseHeight = props.Height
	end

	local bodyChildren: { any } = {}
	--[[
		⚠️ `UIScale` phải nằm ở CanvasGroup, KHÔNG phải trong `body`.

		Header là ANH EM của `body` (nó cần đè lên viền `body`), nên đặt `UIScale` trong `body`
		thì chỉ mình thân co lại còn header giữ nguyên cỡ — Rebirth (scale 0.85) hiện ra với
		thanh tiêu đề thò rộng hơn thân cả trăm pixel. Đặt ở CanvasGroup thì cả hai cùng co,
		và vì CanvasGroup neo tâm nên modal vẫn đứng giữa màn hình.
	]]
	local canvasChildren: { any } = {}
	if props.Scale then
		--[[
			⚠️ `UIScale` co CHÍNH đối tượng nó nằm trong (đã đo trong Studio: 1032 → 846), và vì
			`AnchorPoint` của CanvasGroup là (0.5, 0.5) nên nó co quanh TÂM — modal vẫn nằm đúng
			giữa màn hình, không phải chỉnh `Position`.

			Dùng `UIScale` chứ không sửa từng toạ độ: trong một modal có tới hơn 40 offset khớp
			nhau theo pixel (header, lưới thẻ, ScrollingFrame, CanvasSize…). Sửa tay là chắc chắn
			lệch một chỗ nào đó; `UIScale` co ĐỀU nên tỉ lệ giữ nguyên tuyệt đối.
		]]
		table.insert(canvasChildren, New("UIScale")({ Scale = props.Scale }))
	end
	table.insert(bodyChildren, Theme.MakeCorner(Tokens.RADIUS.MODAL))
	local shellBorder = props.Border or Tokens.MODAL.BORDER
	table.insert(bodyChildren, Theme.MakeStroke(Tokens.COLOR.OUTLINE, shellBorder))
	for _, child in props.Content do
		table.insert(bodyChildren, child)
	end

	--[[
		══ HEADER ĐÈ LÊN VỎ, KHÔNG NẰM LỌT TRONG VỎ (user chốt 2026-08-16) ═══════════════════

		Bản trước cho header lấp đầy phần trong của vỏ. Kết quả: ở mép trên có HAI đường viền
		đen chồng nhau — viền của vỏ (`UIStroke` vẽ ra ngoài) rồi tới viền của chính header —
		nên dải trên trông dày gấp đôi ba cạnh còn lại. User muốn header ĐÈ lên đúng chỗ khung
		vỏ, khớp kích thước với nó, để chỉ còn MỘT đường viền.

		Muốn thế thì viền header phải trùng viền vỏ, tức là header rộng hơn thân vỏ 2×BORDER và
		bắt đầu ở toạ độ âm — mà `CanvasGroup` dựng ảnh đúng bằng kích thước của nó nên phần âm
		bị cắt. Vì vậy cấu trúc đổi thành:

		    CanvasGroup  (rộng W+2B, cao H+2B — CHỪA CHỖ cho viền, trong suốt, chỉ để mờ dần)
		     ├─ body    (Frame tại (B,B), cỡ W×H — nền + bo góc + viền + toàn bộ nội dung)
		     └─ header  (MakeSurface khai tại (B,B), viền của nó vẽ ra tới (0,0))

		Nhờ vỏ to thêm 2B, mép ngoài viền của cả `body` lẫn `header` cùng rơi vào (0,0) —
		trùng khít nhau, một đường viền duy nhất.

		⚠️ Nội dung nằm trong `body` (không phải trong CanvasGroup) để vẫn được `ClipsDescendants`
		cắt gọn theo thân modal; toạ độ con GIỮ NGUYÊN vì `body` cũng bắt đầu từ gốc của nó.
	]]
	local border = shellBorder
	local height = props.Height
	local bodySize = if typeof(height) == "number"
		then UDim2.fromOffset(props.Width, height)
		else Computed(function()
			return UDim2.fromOffset(props.Width, height:get())
		end)
	local canvasSize = if typeof(height) == "number"
		then UDim2.fromOffset(props.Width + border * 2, height + border * 2)
		else Computed(function()
			return UDim2.fromOffset(props.Width + border * 2, height:get() + border * 2)
		end)

	local body = New("Frame")({
		BackgroundColor3 = props.PanelColor,
		BackgroundTransparency = props.PanelTransparency or Tokens.MODAL.PANEL_TRANSPARENCY,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(border, border),
		Size = bodySize,
		ZIndex = Tokens.Z.MODAL_PANEL,
		[Children] = bodyChildren,
	})

	return New("CanvasGroup")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = Computed(function()
			return 1 - animation:get()
		end),
		Position = Computed(function()
			return Theme.ModalPosition(animation:get(), raiseHeight)
		end),
		Size = canvasSize,
		ZIndex = Tokens.Z.MODAL_PANEL,
		[Children] = (function()
			table.insert(canvasChildren, body)
			table.insert(canvasChildren, buildHeader(props, closeHovered))
			return canvasChildren
		end)(),
	})
end

-- Khung phủ canvas + vỏ. Đây là thứ `HUDController` gắn vào ScreenGui.
function ModalShell.Build(props: ModalShellProps)
	local mounted = (State :: any)[props.Id .. "ModalMounted"]

	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(Tokens.DESIGN_WIDTH, Tokens.DESIGN_HEIGHT),
		Visible = mounted,
		ZIndex = Tokens.Z.MODAL_ROOT,
		[Children] = {
			ModalShell.BuildPanel(props),
		},
	})
end

return ModalShell
