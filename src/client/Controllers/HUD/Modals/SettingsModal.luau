--!strict
--[[
	SettingsModal.luau — Bảng Cài đặt.

	NGÔN NGỮ HÌNH ẢNH (2026-08-07, thiết kế lại): giống hệt cấu trúc mọi modal khác của game
	— header bo góc + studs pattern + nút X đỏ + tab bar + danh sách THẺ (card) — nhưng mang
	MÀU RIÊNG để nhận ra ngay từ xa:
	    Shop = vàng · Cosmetics = tím · Teleport = xanh dương · **Cài đặt = ngọc lam (teal)**
	Trước đây modal này dùng header vàng y hệt Shop và các dòng cài đặt chỉ là chữ trần trên
	nền panel (không thẻ, không icon), nên nhìn như một trang khác game rơi vào.

	Mỗi dòng cài đặt giờ là một thẻ đúng chuẩn ShopModal: nền gradient + viền đen 4 + studs,
	chip icon vuông bên trái, tiêu đề + dòng gợi ý, và bộ điều khiển nằm bên phải.

	TOÀN BỘ CHỮ TRONG BẢNG LÀ TIẾNG ANH (2026-08-09, user chốt) — phần còn lại của HUD
	(Shop/Cosmetics/Teleport/Daily) đều tiếng Anh, riêng bảng này tiếng Việt nên đọc như một
	bản dịch sót. Comment trong code thì vẫn tiếng Việt như mọi file khác.

	HAI TAB:
	  • DISPLAY — Performance Mode / Night Mode
	  • AUDIO   — 3 slider (Master / Music / ASMR Floors) + 2 nút preset.

	── ĐÃ GỠ 2026-08-09 (user chốt) ────────────────────────────────────────────────────────
	  ✗ slider "UI & Effects" (kênh sfx)
	  ✗ công tắc "Background Music"        — trùng chức năng với slider Music kéo về 0
	  ✗ công tắc "Mute when window unfocused"
	Kênh `sfx` trong `AudioMixController` VẪN CÒN và vẫn phải còn: mọi Sound không phải nhạc
	và không phải tiếng sàn đều chảy qua nó, nên bỏ nhóm đi là slider Master mất quyền với
	tiếng UI/bẫy zone. Chỉ có thanh trượt là bị gỡ, kênh thì giữ ở 100%.

	⚠️ VỀ TAB AUDIO: bản mixer bị gỡ ngày 2026-08-05 là bản bắt MỌI controller dựng Sound
	   qua một helper chung (`Audio.luau`) — sửa 20 file, quên một chỗ là tiếng đó lọt lưới.
	   Bản này chạy trên `AudioMixController`: nó tự nhận nuôi mọi Sound vào SoundGroup nên
	   KHÔNG file phát tiếng nào phải sửa, và mọi slider đều điều khiển được thật.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local AudioMixController = require(script.Parent.Parent.Parent.Effects.AudioMixController)
local BgmController = require(script.Parent.Parent.Parent.Effects.BgmController)
local AutoPerformanceController = require(script.Parent.Parent.Parent.Effects.AutoPerformanceController)
local ClientSettingsController = require(script.Parent.Parent.Parent.Effects.ClientSettingsController)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Manager = require(script.Parent.Manager)
local Toast = require(script.Parent.Parent.Toast)

-- Đã nhắc kéo Graphics Quality của Roblox chưa (một lần mỗi phiên) — xem chỗ dùng bên dưới.
local qualityHintShown = false

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local SettingsModal = {}

--[[
	Panel CO GIÃN theo tab. Tab DISPLAY chỉ có 2 dòng; nếu để chung chiều cao với tab AUDIO
	thì hơn nửa bảng là khoảng trống rỗng, nhìn như UI làm dở. Chiều cao đi qua một
	`Fusion.Tween` nên lúc đổi tab nó co/giãn mượt chứ không giật một nhát.
	  content = PANEL_H − 186 (header + tab bar) − 14 (lề dưới)
	AUDIO: 3 thẻ 92 + 2 khe 12 + hàng preset 68 + khe 12 = 392 ⇒ 186 + 392 + 14 = 592.
	Vừa khít, KHÔNG cần cuộn (trước đây 7 dòng nên phải cuộn).
]]
local PANEL_W = 1032
local PANEL_H_DISPLAY, PANEL_H_AUDIO = 430, 592
local CONTENT_TOP = 186
local CONTENT_H_DISPLAY, CONTENT_H_AUDIO = PANEL_H_DISPLAY - CONTENT_TOP - 14, PANEL_H_AUDIO - CONTENT_TOP - 14
local ICON_SETTINGS = "rbxassetid://6031280882"

local panelHeight = Fusion.Tween(
	Computed(function()
		return if State.settingsTab:get() == "audio" then PANEL_H_AUDIO else PANEL_H_DISPLAY
	end),
	TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
)

-- ── Bảng màu RIÊNG của Cài đặt: ngọc lam trên nền xanh mực ───────────────────
local ACCENT_A = Color3.fromRGB(72, 236, 214)
local ACCENT_B = Color3.fromRGB(14, 122, 140)
local PANEL_BG = Color3.fromRGB(12, 30, 42)
local CARD_A = Color3.fromRGB(40, 72, 92)
local CARD_B = Color3.fromRGB(18, 38, 54)
local TAB_OFF_A = Color3.fromRGB(52, 72, 88)
local TAB_OFF_B = Color3.fromRGB(28, 44, 58)
local HINT_COLOR = Color3.fromRGB(168, 208, 220)

-- Kích thước thẻ dùng chung cho mọi dòng cài đặt.
local CARD_W, CARD_H = 872, 92

local TABS = {
	{ id = "display", label = "DISPLAY", colorA = ACCENT_A, colorB = ACCENT_B },
	{
		id = "audio",
		label = "AUDIO",
		colorA = Color3.fromRGB(120, 200, 255),
		colorB = Color3.fromRGB(28, 96, 190),
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- MẢNH GHÉP CHUNG
-- ═══════════════════════════════════════════════════════════════════════════

-- Chip icon vuông bên trái mỗi thẻ. Dùng emoji chứ không phải ImageLabel: bộ icon của game
-- không có biểu tượng loa/nốt nhạc nào, mà upload thêm 6 ảnh chỉ để trang trí bảng cài đặt
-- thì không đáng — emoji render sẵn qua font dự phòng của Roblox (đã dùng ở BoostCelebration).
local function makeChip(glyph: string, colorA: Color3, colorB: Color3)
	return New("Frame")({
		BackgroundColor3 = colorA,
		Position = UDim2.fromOffset(14, 16),
		Size = UDim2.fromOffset(60, 60),
		ZIndex = 46,
		[Children] = {
			Theme.MakeCorner(14),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			New("TextLabel")({
				BackgroundTransparency = 1,
				Font = Theme.FONT,
				Position = UDim2.fromScale(0, 0),
				Size = UDim2.fromScale(1, 1),
				Text = glyph,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				ZIndex = 47,
				[Children] = {
					New("UIPadding")({
						PaddingTop = UDim.new(0, 10),
						PaddingBottom = UDim.new(0, 10),
						PaddingLeft = UDim.new(0, 10),
						PaddingRight = UDim.new(0, 10),
					}),
				},
			}),
		},
	})
end

-- Khung thẻ rỗng + tiêu đề + gợi ý. `extra` là danh sách con thêm vào (công tắc / slider).
local function makeCard(props: {
	glyph: string,
	chipA: Color3,
	chipB: Color3,
	title: string,
	hint: string,
	order: number,
	titleWidth: number?,
	extra: { any },
})
	local children = {
		Theme.MakeCorner(16),
		Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
		Theme.MakeGradient(CARD_A, CARD_B),
		Theme.MakeStandardStuds(16, 45),
		makeChip(props.glyph, props.chipA, props.chipB),
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(88, 12),
			Size = UDim2.fromOffset(props.titleWidth or 520, 36),
			Text = props.title,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 30,
			ZIndex = 46,
		}),
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(90, 50),
			Size = UDim2.fromOffset(props.titleWidth or 520, 28),
			Text = props.hint,
			TextColor3 = HINT_COLOR,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 21,
			ZIndex = 46,
		}),
	}
	for _, child in props.extra do
		table.insert(children, child)
	end

	return New("Frame")({
		BackgroundColor3 = CARD_A,
		ClipsDescendants = true,
		LayoutOrder = props.order,
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		ZIndex = 44,
		[Children] = children,
	})
end

-- ── Công tắc BẬT/TẮT ─────────────────────────────────────────────────────────
local function makeToggle(props: {
	glyph: string,
	chipA: Color3,
	chipB: Color3,
	title: string,
	hint: string,
	order: number,
	state: any,
	onChanged: (boolean) -> (),
})
	local hovered = Value(false)

	-- Khai lệch +4 để mép ngoài viền vẫn rơi đúng (682, 18) như bản cũ.
	local button = Theme.MakeSurface({
		ClassName = "TextButton",
		Position = UDim2.fromOffset(686, 22),
		Size = UDim2.fromOffset(166, 48),
		ZIndex = 47,
		Radius = 14,
		Border = 4,
		Color = Computed(function()
			return if props.state:get() then Color3.fromRGB(96, 236, 148) else Color3.fromRGB(122, 134, 148)
		end),
		ColorB = Computed(function()
			return if props.state:get() then Color3.fromRGB(30, 152, 78) else Color3.fromRGB(60, 70, 84)
		end),
		GradientRotation = 0,
		Zoom = { Hovered = hovered, Scale = 1.06 },
		Activated = function()
			props.onChanged(not props.state:get())
		end,
		MouseEnter = function()
			hovered:set(true)
		end,
		MouseLeave = function()
			hovered:set(false)
		end,
		Content = function(zoom)
			return {
				Theme.MakeOutlineLabel({
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					Text = Computed(function()
						return if props.state:get() then "ON" else "OFF"
					end),
					Zoom = zoom,
					MaxTextSize = 28,
					ZIndex = 48,
				}),
			}
		end,
	})

	return makeCard({
		glyph = props.glyph,
		chipA = props.chipA,
		chipB = props.chipB,
		title = props.title,
		hint = props.hint,
		order = props.order,
		titleWidth = 580,
		extra = { button },
	})
end

-- ── Slider âm lượng ──────────────────────────────────────────────────────────
--[[
	Kéo bằng chuột LẪN cảm ứng. Vị trí tính theo TRỤC X của `AbsolutePosition/AbsoluteSize`
	của chính thanh track — KHÔNG dùng `GetMouseLocation()`: toàn bộ HUD nằm trong một
	`UIScale`, toạ độ thiết kế 1920×1080 và toạ độ màn hình thật lệch nhau đúng bằng hệ số
	scale, còn AbsolutePosition thì đã là pixel thật nên hai vế cùng hệ. (Chỉ lấy X nên cũng
	không dính offset 36px của topbar — cái đó chỉ ảnh hưởng trục Y.)
]]
local TRACK_X, TRACK_W = 420, 330
-- Chiều cao thanh VẼ, và chiều cao vùng CHẠM (xem khối lý do ở `hit` trong `makeSlider`).
local TRACK_H = 26
local TOUCH_MIN = Tokens.MIN_TOUCH_PX

local function makeSlider(props: {
	glyph: string,
	chipA: Color3,
	chipB: Color3,
	title: string,
	hint: string,
	order: number,
	state: any,
	onChanged: (number) -> (),
})
	local hovered = Value(false)
	local janitor = Janitor.new()

	local track = New("Frame")({
		BackgroundColor3 = Color3.fromRGB(16, 30, 42),
		Position = UDim2.fromOffset(TRACK_X, 34),
		Size = UDim2.fromOffset(TRACK_W, TRACK_H),
		ZIndex = 47,
		[Children] = {
			Theme.MakeCorner(13),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			-- Phần đã lấp
			New("Frame")({
				BackgroundColor3 = props.chipA,
				Size = Computed(function()
					return UDim2.new(props.state:get(), 0, 1, 0)
				end),
				ZIndex = 48,
				[Children] = {
					Theme.MakeCorner(13),
					Theme.MakeGradient(props.chipA, props.chipB),
				},
			}),
			-- Núm kéo
			New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Position = Computed(function()
					return UDim2.new(props.state:get(), 0, 0.5, 0)
				end),
				Size = Computed(function()
					local grow = if hovered:get() then 6 else 0
					return UDim2.fromOffset(30 + grow, 30 + grow)
				end),
				ZIndex = 49,
				[Children] = {
					Theme.MakeCorner(15),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
				},
			}),
		},
	}) :: Frame

	--[[
		VÙNG CHẠM CỦA SLIDER — tách khỏi thanh vẽ (2026-08-16).

		Thanh chỉ cao `TRACK_H` = 26 design px. Trên điện thoại `UIScale` ≈ 0.48 nên nó còn ~12 px
		THẬT — audit đo được 3 slider đều dưới ngưỡng chạm 44 px của Roblox, tức là người chơi
		mobile phải chọc đúng một vạch mỏng bằng nửa đầu ngón tay mới kéo được âm lượng.

		Cách chữa giống `Theme.MakeTouchTarget`: KHÔNG phóng to hình vẽ (làm thế là phá bố cục
		thẻ), mà phủ một nút TRONG SUỐT cao hơn hẳn lên trên. Thanh giờ là `Frame` thuần, mọi
		input đi qua nút này.

		⚠️ Toạ độ ngang vẫn quy chiếu theo `track`: vùng chạm chỉ cao hơn chứ không rộng hơn, nên
		hai mốc trùng nhau — nhưng nếu sau này nới ngang thì phải giữ nguyên mốc `track`, không
		thì kéo hết cỡ sang phải vẫn chưa đạt 100%.

		⚠️ Chiều cao phải TÍNH THEO `viewportScale`, không để hằng 44. `MIN_TOUCH_PX` là px THẬT,
		mà mọi số đo ở đây là design px rồi bị `UIScale` nhân vào — để 44 cứng thì trên điện thoại
		(scale ≈ 0.48) vùng chạm chỉ còn 21px thật, tức là không sửa được gì. Cùng công thức với
		`Theme.MakeTouchTarget`.
	]]
	local hitHeight = Computed(function()
		return math.max(TRACK_H, TOUCH_MIN / math.max(0.01, State.viewportScale:get()))
	end)
	local hit = New("TextButton")({
		[Fusion.Cleanup] = function()
			janitor:Sweep()
		end,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		-- Căn giữa theo thanh vẽ: thanh nằm ở y = 34 cao TRACK_H.
		Position = Computed(function()
			return UDim2.fromOffset(TRACK_X, 34 + TRACK_H // 2 - hitHeight:get() // 2)
		end),
		Size = Computed(function()
			return UDim2.fromOffset(TRACK_W, hitHeight:get())
		end),
		ZIndex = 50,
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
		end,
	}) :: TextButton

	local dragging = false
	local function setFromX(x: number)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		props.onChanged(math.clamp((x - track.AbsolutePosition.X) / width, 0, 1))
	end

	janitor:Add(hit.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			setFromX(input.Position.X)
		end
	end))
	-- Nghe trên UserInputService chứ không phải trên track: kéo nhanh là con trỏ ra khỏi
	-- thanh ngay, `track.InputChanged` sẽ ngừng bắn và slider kẹt giữa chừng.
	janitor:Add(UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		then
			setFromX(input.Position.X)
		end
	end))
	janitor:Add(UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end))

	local percent = Theme.MakeOutlineLabel({
		Position = UDim2.fromOffset(TRACK_X + TRACK_W + 14, 28),
		Size = UDim2.fromOffset(96, 38),
		Text = Computed(function()
			return `{math.floor(props.state:get() * 100 + 0.5)}%`
		end),
		TextColor3 = Color3.fromRGB(255, 244, 168),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 30,
		ZIndex = 47,
	})

	return makeCard({
		glyph = props.glyph,
		chipA = props.chipA,
		chipB = props.chipB,
		title = props.title,
		hint = props.hint,
		order = props.order,
		titleWidth = 318,
		extra = { track, hit, percent },
	})
end

-- ── Nút preset (hàng cuối tab Âm thanh) ──────────────────────────────────────
local function makePresetButton(label: string, colorA: Color3, colorB: Color3, onClick: () -> ())
	local hovered = Value(false)
	return Theme.MakeSurface({
		ClassName = "TextButton",
		Size = UDim2.fromOffset(418, 60),
		ZIndex = 46,
		Radius = 16,
		Border = 4,
		Color = colorA,
		ColorB = colorB,
		Zoom = { Hovered = hovered, Scale = 1.05 },
		Activated = onClick,
		MouseEnter = function()
			hovered:set(true)
		end,
		MouseLeave = function()
			hovered:set(false)
		end,
		Content = function(zoom)
			return {
				Theme.MakeOutlineLabel({
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					Text = label,
					Zoom = zoom,
					MaxTextSize = 27,
					ZIndex = 48,
				}),
			}
		end,
	})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB: DISPLAY
-- ═══════════════════════════════════════════════════════════════════════════
local function buildDisplayTab()
	return New("ScrollingFrame")({
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 2 * (CARD_H + 12)),
		Position = UDim2.fromOffset(72, CONTENT_TOP),
		ScrollBarImageColor3 = ACCENT_A,
		ScrollBarThickness = 8,
		Size = UDim2.fromOffset(892, CONTENT_H_DISPLAY),
		Visible = Computed(function()
			return State.settingsTab:get() == "display"
		end),
		ZIndex = 44,
		[Children] = {
			New("UIListLayout")({
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			makeToggle({
				glyph = "⚡",
				chipA = Color3.fromRGB(255, 208, 84),
				chipB = Color3.fromRGB(226, 130, 22),
				title = "Performance Mode",
				hint = "Hides shadows and other players' VFX. Colours stay the same.",
				order = 1,
				state = State.performanceMode,
				onChanged = function(on)
					State.performanceMode:set(on)
					-- Người chơi đã tự quyết ⇒ `AutoPerformanceController` im lặng vĩnh viễn
					-- trong phiên này. Phải gọi TRƯỚC `SetPerformanceMode` để không có khe hở
					-- nào mà bên tự-động còn tưởng công tắc là của mình.
					AutoPerformanceController.NotePlayerOverride()
					ClientSettingsController.SetPerformanceMode(on)
					--[[
						Nhắc kéo thanh Graphics Quality của Roblox — MỘT LẦN mỗi phiên.

						Vì sao phải nhờ người chơi tự kéo thay vì game tự làm: engine CHẶN, và
						chặn thẳng chứ không phải "ghi không ăn". Đo 2026-08-22:
						`UserGameSettings.SavedQualityLevel` → "lacking capability RobloxScript";
						`GraphicsQualityLevel` và `GraphicsOptimizationMode` thì đến ĐỌC cũng
						không được. Chi tiết ở khối 4 của `ClientSettingsController`.

						Nên đây là nửa còn lại của Performance Mode, và chỉ người chơi bấm được.

						Khuyên **Automatic** chứ không phải "kéo Quality xuống thấp nhất": user test
						nhiều lần 2026-08-22 và thấy Automatic mượt hẳn, còn Manual + max thì giật.
						Automatic để engine tự hạ khi không theo kịp — đúng thứ mình muốn mà không
						bắt người chơi chịu hình ảnh xấu lúc máy đang thừa sức.
					]]
					if on and not qualityHintShown then
						qualityHintShown = true
						-- Câu này TỪNG bảo "kéo Quality xuống thấp nhất", ngược hẳn với kết luận
						-- đo được ghi ngay phía trên (Automatic mượt hơn Manual+max). Sửa cho
						-- khớp, và chuyển sang tiếng Anh như mọi chữ hiện ra cho người chơi.
						Toast.Show("Even smoother: Roblox ⚙ → Graphics Mode → Automatic", "success")
					end
				end,
			}),
			makeToggle({
				glyph = "🌙",
				chipA = Color3.fromRGB(150, 160, 255),
				chipB = Color3.fromRGB(58, 46, 168),
				title = "Night Mode",
				hint = "Night sky, zones stay bright. Trails and auras glow best.",
				order = 2,
				state = State.nightMode,
				onChanged = function(on)
					State.nightMode:set(on)
					ClientSettingsController.SetNightMode(on)
				end,
			}),
		},
	})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TAB: AUDIO
-- ═══════════════════════════════════════════════════════════════════════════
--[[
	Kéo slider Music về 0 thì DỪNG HẲN Sound nhạc nền chứ không chỉ hạ SoundGroup xuống 0.
	Đây là phần việc mà công tắc "Bật nhạc nền" (đã gỡ) từng làm: Sound câm nhưng vẫn phát
	nghĩa là vẫn giải mã audio mỗi frame — vô ích trên máy yếu. `State.musicEnabled` vẫn được
	cập nhật theo (giờ là giá trị SUY RA từ slider) để không chỗ nào đọc phải state cũ.
]]
local function setMusicLevel(level: number)
	State.volMusic:set(level)
	AudioMixController.SetVolume("music", level)

	local enabled = level > 0
	if State.musicEnabled:get() ~= enabled then
		State.musicEnabled:set(enabled)
		BgmController.SetEnabled(enabled)
	end
end

local function setChannel(channel: string, stateValue: any, level: number)
	stateValue:set(level)
	AudioMixController.SetVolume(channel :: any, level)
end

local function buildAudioTab()
	local presetRow = New("Frame")({
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Size = UDim2.fromOffset(CARD_W, 68),
		ZIndex = 44,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 20),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			makePresetButton("🎧 ASMR MODE", Color3.fromRGB(96, 236, 208), Color3.fromRGB(18, 128, 132), function()
				-- Đẩy tiếng sàn lên tối đa, dìm nhạc xuống nền: đúng cách nghe mà game này
				-- bán. Một cú bấm thay cho hai lần kéo slider.
				-- ⚠️ KHÔNG đụng kênh `sfx`: slider của nó đã gỡ, hạ xuống là người chơi
				-- không có cách nào thấy hay kéo lại — state ẩn thì đừng bao giờ đổi.
				setChannel("master", State.volMaster, 1)
				setChannel("asmr", State.volAsmr, 1)
				setMusicLevel(0.2)
			end),
			makePresetButton(
				-- Emoji chứ không phải ký tự ↺ (U+21BA): GothamBlack không có glyph đó nên nó
				-- render ra ô vuông tofu — đã thấy trên ảnh chụp playtest 2026-08-08.
				"🔄 RESET TO DEFAULT",
				Color3.fromRGB(150, 164, 186),
				Color3.fromRGB(64, 76, 96),
				function()
					setChannel("master", State.volMaster, 1)
					setChannel("asmr", State.volAsmr, 1)
					-- "Mặc định" phải là ĐÚNG cái mức lúc vào game, không phải 100%: nhạc ở
					-- 100% (0.45 hiệu dụng) sẽ đè lên tiếng sàn ASMR — xem DEFAULT_MUSIC.
					setMusicLevel(AudioMixController.DEFAULT_MUSIC)
				end
			),
		},
	})

	return New("ScrollingFrame")({
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 3 * (CARD_H + 12) + 68),
		Position = UDim2.fromOffset(72, CONTENT_TOP),
		ScrollBarImageColor3 = ACCENT_A,
		ScrollBarThickness = 8,
		Size = UDim2.fromOffset(892, CONTENT_H_AUDIO),
		Visible = Computed(function()
			return State.settingsTab:get() == "audio"
		end),
		ZIndex = 44,
		[Children] = {
			New("UIListLayout")({
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			makeSlider({
				glyph = "🔊",
				chipA = Color3.fromRGB(255, 214, 92),
				chipB = Color3.fromRGB(226, 138, 20),
				title = "Master Volume",
				hint = "Scales everything in the game",
				order = 1,
				state = State.volMaster,
				onChanged = function(level)
					setChannel("master", State.volMaster, level)
				end,
			}),
			makeSlider({
				glyph = "🎵",
				chipA = Color3.fromRGB(168, 150, 255),
				chipB = Color3.fromRGB(78, 46, 190),
				title = "Music",
				-- Ngắn để vừa MỘT dòng trong ô hint rộng 318px: câu dài hơn bị xuống hai dòng
				-- và tràn khỏi thẻ (đã thấy trên ảnh chụp playtest 2026-08-09).
				hint = "Lounge music — 0 stops it",
				order = 2,
				state = State.volMusic,
				onChanged = setMusicLevel,
			}),
			makeSlider({
				glyph = "🎧",
				chipA = Color3.fromRGB(96, 236, 208),
				chipB = Color3.fromRGB(18, 128, 132),
				title = "ASMR Floors",
				hint = "Slime, keycaps, bubble wrap…",
				order = 3,
				state = State.volAsmr,
				onChanged = function(level)
					setChannel("asmr", State.volAsmr, level)
				end,
			}),
			presetRow,
		},
	})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- KHUNG MODAL
-- ═══════════════════════════════════════════════════════════════════════════
local function makeTabBar()
	local buttons = {}
	for index, tab in TABS do
		local hovered = Value(false)
		local active = Computed(function()
			return State.settingsTab:get() == tab.id
		end)
		table.insert(
			buttons,
			Theme.MakeSurface({
				ClassName = "TextButton",
				Size = UDim2.fromOffset(426, 56),
				LayoutOrder = index,
				ZIndex = 45,
				Radius = 14,
				Border = 4,
				Color = Computed(function()
					return if active:get() then tab.colorA else TAB_OFF_A
				end),
				ColorB = Computed(function()
					return if active:get() then tab.colorB else TAB_OFF_B
				end),
				Zoom = { Hovered = hovered, Scale = 1.04 },
				Activated = function()
					State.settingsTab:set(tab.id)
				end,
				MouseEnter = function()
					hovered:set(true)
				end,
				MouseLeave = function()
					hovered:set(false)
				end,
				Content = function(zoom)
					return {
						Theme.MakeOutlineLabel({
							Position = UDim2.fromScale(0, 0),
							Size = UDim2.fromScale(1, 1),
							Text = tab.label,
							Zoom = zoom,
							MaxTextSize = 26,
							ZIndex = 47,
						}),
					}
				end,
			})
		)
	end

	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(72, 118),
		Size = UDim2.fromOffset(892, 56),
		ZIndex = 45,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 20),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			table.unpack(buttons),
		},
	})
end

--[[
	══ NHÃN PHIÊN BẢN (2026-08-27, user) ═══════════════════════════════════════════════════

	Bối cảnh: bản LIVE đã publish nhưng người chơi vẫn thấy nội dung cũ. Nguyên nhân là
	Roblox KHÔNG cập nhật server đang chạy — bản mới chỉ áp cho server sinh ra sau đó. Không
	có cách nào nhìn vào game mà biết server này đang chạy build nào, nên mọi lần nghi ngờ
	đều phải đoán.

	`game.PlaceVersion` đọc thẳng được ở client, không cần packet hay attribute: nó chính là
	số phiên bản của place mà SERVER NÀY đang chạy. Sau mỗi lần publish, số này tăng — thấy
	số cũ nghĩa là đang ở server cũ, không phải publish hỏng.

	`game.JobId` đi kèm để phân biệt hai server cùng phiên bản (khi cần đối chiếu với danh
	sách server trên trang web). Cắt 8 ký tự đầu là đủ để nhận ra, mà không chiếm cả dòng.

	Đặt trong Cài đặt chứ không phải trên HUD: đây là thông tin CHẨN ĐOÁN, người chơi bình
	thường không cần thấy, nhưng phải lấy được từ điện thoại mà không cần Developer Console.
]]
local function makeVersionLabel()
	--[[
		⚠️ `game.JobId` KHÔNG rỗng ở client trong Studio — nó là GUID toàn số 0
		("00000000-0000-…"), khác hẳn phía server nơi nó rỗng thật. Đo được 2026-08-27: nhãn
		hiện "server 00000000" thay vì "studio". Hỏi thẳng RunService mới đúng ở cả hai phía.
	]]
	local shortJob = if RunService:IsStudio() then "studio" else string.sub(game.JobId, 1, 8)
	return New("TextLabel")({
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(72, 96),
		Size = UDim2.fromOffset(892, 18),
		Text = `v{game.PlaceVersion}  ·  server {shortJob}`,
		TextColor3 = Color3.fromRGB(120, 160, 172),
		TextSize = 16,
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 45,
	})
end

function SettingsModal.Build()
	return ModalShell.Build({
		Id = "settings",
		Width = PANEL_W,
		-- Chiều cao ĐỔI THEO TAB (Display cao hơn Audio), nên truyền state chứ không phải số.
		Height = panelHeight,
		--[[
			…nhưng chỗ nhích lên phải chốt ở MỘT con số. Bám vào `panelHeight` là mỗi lần đổi tab
			modal vừa cao lên vừa trôi dọc màn hình — hai chuyển động cùng lúc trông như lỗi.
		]]
		RaiseHeight = 430,
		PanelColor = PANEL_BG,
		PanelTransparency = 0.15,
		-- Header NGỌC LAM — cùng khuôn với header vàng của Shop, khác màu để nhận diện.
		HeaderColor = Color3.fromRGB(126, 250, 228),
		HeaderColorB = ACCENT_B,
		HeaderBorderColor = Color3.fromRGB(6, 20, 26),
		Icon = ICON_SETTINGS,
		-- Icon gốc màu sáng; trên nền ngọc lam sáng nó biến mất, nên nhuộm tối lại.
		IconColor = Color3.fromRGB(6, 42, 46),
		Title = "Settings",
		OnClose = Manager.CloseSettings,
		Content = {
			makeVersionLabel(),
			makeTabBar(),
			buildDisplayTab(),
			buildAudioTab(),
		},
	})
end

return SettingsModal
