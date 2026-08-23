--!strict
--[[
	TopRightRow.luau — HÀNG NGANG góc phải-trên: Spin · Playtime Boost.

	(Ô thứ ba của hàng, Starter Pack, sống trong `StarterPackCard.luau` vì nó có nhịp thở,
	hào quang và đồng hồ 48h riêng — nó chỉ đọc chung bảng vị trí `Theme.TOP_ROW`.)

	══ VÌ SAO TÁCH RA KHỎI `RightPanel` (user chốt 2026-08-21) ════════════════════════════

	Trước đây cả 5 ô góc phải nằm trong MỘT chồng dọc cao 654 design px, và cái đuôi của nó
	đè lên nút nhảy của mobile — vấn đề đã ghi sẵn ở lề trên của cụm phải, kèm
	kết luận "muốn tách hẳn thì phải bớt một ô khỏi cột, đó là quyết định thiết kế". Nay
	quyết định đó đã có, và nút SLIDE mới (`Movement/MobileSlideButton`) cũng vừa vào đúng
	vùng ấy nên không hoãn thêm được.

	Ranh giới chia ĐÚNG theo cách người chơi dùng, không phải theo chỗ nào còn trống:
	  • HÀNG NGANG (file này + StarterPackCard) = ba món "ngó rồi bấm", đều là ĐỒNG HỒ đếm
	    (Starter Pack 48h · Spin vé free · Playtime đếm lên). Liếc một cái là xong.
	  • CỘT DỌC (`RightPanel`) = ba ô ĐIỀU KHIỂN/MUA, nằm trong tầm ngón cái phải.

	Vị trí đọc từ `Theme.TOP_ROW` — đừng đặt toạ độ tay ở đây, và đừng đổi thứ tự bằng cách
	đảo thứ tự khai báo trong file này (nó không có tác dụng gì).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Responsive = require(script.Parent.Parent.Responsive)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Manager = require(script.Parent.Parent.Modals.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local TopRightRow = {}

--[[
	Nút icon thô (`ImageButton`) KHÔNG đi qua `Theme.MakeSurface` nên không được luật ngón tay
	tự động phủ. Helper này dựng nút rồi gắn tay vùng chạm — cả hai nút trong hàng đều là nút
	bấm thật nên cả hai đều cần.
]]
local function makeIconButton(props: { [any]: any }, activated: () -> ())
	local button = New("ImageButton")(props)
	Responsive.AttachHitArea(button, activated)
	return button
end

local function formatPlaytime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d", m, s)
end

local function getPlaytimeMultiplier(seconds: number): number
	local m = math.floor(seconds / 60)
	if m >= 60 then
		return 4
	elseif m >= 40 then
		return 3
	elseif m >= 20 then
		return 2
	else
		return 1
	end
end

TopRightRow.GetPlaytimeMultiplier = getPlaytimeMultiplier

function TopRightRow.Build()
	local hoveredSpin = Value(false)
	local hoveredPlaytime = Value(false)

	return New("Frame")({
		BackgroundTransparency = 1,
		Position = Computed(function()
			return Theme.TopRowSlotPosition("starterPack")
		end),
		Size = UDim2.fromOffset(Theme.TOP_ROW_WIDTH, Theme.TOP_ROW_HEIGHT),
		[Children] = {
			-- ── SPIN: icon + đếm ngược vé free + badge số vé ────────────────────────────
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(Theme.TOP_ROW.spin, 0),
				Size = UDim2.fromOffset(120, 130),
				[Children] = {
					makeIconButton({
						BackgroundTransparency = 1,
						Image = Theme.UI_ASSETS.Spin,
						Position = UDim2.fromOffset(10, 0),
						Size = UDim2.fromOffset(100, 100),
						[OnEvent("Activated")] = Manager.ToggleRoulette,
						[OnEvent("MouseEnter")] = function()
							hoveredSpin:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							hoveredSpin:set(false)
						end,
					}, Manager.ToggleRoulette),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(0, 60),
						Size = UDim2.fromOffset(120, 25),
						Text = "Spin",
						MaxTextSize = 24,
						ZIndex = 5,
					}),
					-- Đếm ngược vé free tiếp theo (FULL khi kho vé free đầy).
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(0, 85),
						Size = UDim2.fromOffset(120, 25),
						Text = Computed(function()
							local base = State.rouletteNextFreeSeconds:get()
							if base < 0 then
								return "FULL"
							end
							local elapsed = State.boostClockNow:get() - State.rouletteNextFreeReceivedAt:get()
							local left = math.max(0, math.floor(base - elapsed))
							return string.format("%d:%02d", left // 60, left % 60)
						end),
						TextColor3 = Color3.fromRGB(255, 222, 62),
						MaxTextSize = 22,
						ZIndex = 5,
					}),
					-- Badge số vé. Dựng bằng `MakeSurface` (2026-08-16) thay vì tự chồng "khung đen +
					-- ruột": chỉ khối đi qua `MakeSurface` mới được kẹp SÀN độ dày viền theo px thật,
					-- nên trên cửa sổ nhỏ viền không mỏng tới mức biến mất.
					Theme.MakeSurface({
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(102, 14),
						Size = UDim2.fromOffset(38, 38),
						ZIndex = 6,
						Radius = 19,
						Border = Tokens.BORDER,
						Studs = false,
						Color = Color3.fromRGB(226, 35, 55),
						Visible = Computed(function()
							return State.rouletteTickets:get() > 0
						end),
						Content = {
							Theme.MakeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = Computed(function()
									return tostring(State.rouletteTickets:get())
								end),
								MaxTextSize = 24,
								ZIndex = 7,
							}),
						},
					}),
				},
			}),

			-- ── PLAYTIME BOOST: icon + hệ số + bảng giải thích ──────────────────────────
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(Theme.TOP_ROW.playtime, 0),
				Size = UDim2.fromOffset(120, 110),
				[Children] = {
					--[[
						⚠️ Bảng giải thích Playtime Boost trước đây CHỈ hiện khi RÊ CHUỘT — tức là
						người chơi mobile không có cách nào đọc được nó, mà mobile là phần lớn
						người chơi. Trên cảm ứng không tồn tại trạng thái "rê", nên chạm = bật/tắt.
					]]
					makeIconButton({
						BackgroundTransparency = 1,
						Image = "rbxassetid://105847442035004",
						Position = UDim2.fromOffset(10, 0),
						Size = UDim2.fromOffset(100, 100),
						[OnEvent("MouseEnter")] = function()
							hoveredPlaytime:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							hoveredPlaytime:set(false)
						end,
					}, function()
						hoveredPlaytime:set(not hoveredPlaytime:get(false))
					end),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(0, 60),
						Size = UDim2.fromOffset(120, 25),
						Text = "Playtime",
						MaxTextSize = 24,
						ZIndex = 5,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(0, 85),
						Size = UDim2.fromOffset(120, 25),
						Text = Computed(function()
							return "Boost: x" .. getPlaytimeMultiplier(State.sessionPlaytime:get())
						end),
						MaxTextSize = 22,
						ZIndex = 5,
					}),
					--[[
						Bảng bung sang TRÁI và XUỐNG DƯỚI icon.

						Playtime là ô ngoài cùng bên PHẢI của hàng, nên bảng rộng 420 phải mở về bên
						trái (x âm) — mở sang phải là chạy thẳng ra ngoài mép màn hình. Và vì hàng
						này giờ nằm sát mép TRÊN (không còn ở giữa cột như trước), bảng phải thả
						XUỐNG dưới icon chứ không nhô lên: y = −30 của bản cũ giờ là chui lên trên
						mép màn hình.
					]]
					Theme.MakeSurface({
						Position = UDim2.fromOffset(-320, 112),
						Size = UDim2.fromOffset(420, 160),
						Visible = hoveredPlaytime,
						ZIndex = 50,
						Radius = 12,
						Border = Tokens.BORDER,
						Studs = false,
						Color = Color3.fromRGB(0, 0, 0),
						-- Trong suốt NHẸ (user 2026-08-20). Phải hạ cả hai lớp: chỉ hạ
						-- `FillTransparency` thì khung ngoài vẫn đen đặc phủ trọn ô và bảng
						-- trông kín mít y như cũ — xem `BorderTransparency` trong Theme.
						-- Chữ giữ nguyên độ đục + đã có viền nên vẫn đọc rõ trên nền sáng.
						FillTransparency = 0.6,
						BorderTransparency = 0.4,
						Content = {
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(16, 16),
								Size = UDim2.fromOffset(388, 64),
								Text = "Gain x2 speed boost for every 20 minutes of playtime upto a maximum of 60 minutes 👟",
								MaxTextSize = 22,
								TextWrapped = true,
								TextYAlignment = Enum.TextYAlignment.Top,
								ZIndex = 51,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(16, 86),
								Size = UDim2.fromOffset(388, 28),
								Text = Computed(function()
									return "Playtime: " .. formatPlaytime(State.sessionPlaytime:get())
								end),
								TextColor3 = Color3.fromRGB(255, 222, 62),
								MaxTextSize = 26,
								ZIndex = 51,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(16, 118),
								Size = UDim2.fromOffset(388, 28),
								Text = Computed(function()
									return "Speed Boost: x" .. getPlaytimeMultiplier(State.sessionPlaytime:get())
								end),
								TextColor3 = Color3.fromRGB(255, 222, 62),
								MaxTextSize = 26,
								ZIndex = 51,
							}),
						},
					}),
				},
			}),
		},
	})
end

return TopRightRow
