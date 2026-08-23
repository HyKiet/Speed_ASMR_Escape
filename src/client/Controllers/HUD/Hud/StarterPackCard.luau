--!strict
--[[
	StarterPackCard.luau — ICON gói "Rookie Rocket" trên HUD, neo ở GÓC PHẢI TRÊN.

	── VÌ SAO LÀ ICON TRÊN HUD, KHÔNG PHẢI MODAL TỰ BẬT ──────────────────────────────────
	Modal tự bật lúc vào game sẽ đâm thẳng vào chuỗi mở đầu vốn đã đông: Daily mở trước
	(tutorial), rồi tia chỉ đường, rồi Group Chest ở cuối. Nhét thêm một hộp thoại bán hàng
	vào giữa là người chơi bấm X theo phản xạ — mất luôn cơ hội duy nhất.

	Icon nằm sẵn trên HUD thì KHÔNG chặn ai, nhưng cái đồng hồ đếm lùi làm việc của nó suốt
	48 giờ: mỗi lần người chơi liếc lên góc phải là thấy thời gian đang cạn.

	── VÌ SAO CO TỪ TẤM THẺ XUỐNG CÒN ICON (user chốt 2026-08-12) ────────────────────────
	Bản trước là tấm thẻ 300×268 bày sẵn cả 4 dòng phần thưởng lẫn nút mua. Nó chiếm gần
	một phần tư chiều cao màn hình ở đúng khu vực người chơi cần nhìn đường, và bày hết bài
	ngay từ đầu — không còn gì để người chơi tò mò bấm vào.

	Giờ trên HUD chỉ còn bốn thứ, đều là thứ tạo sức ép chứ không phải thứ mô tả hàng: hình
	gói, "-90%", GIÁ (999 gạch ngang → 99) và đồng hồ. Bấm vào mới mở
	`Modals/StarterPackModal` — nơi bày đủ 4 món. Danh sách phần thưởng nằm ở ĐÓ, đừng chép
	lại vào đây.

	── KHÔNG CÓ NỀN (user chốt 2026-08-12) ───────────────────────────────────────────────
	Bản icon đầu tiên vẫn giữ khung bo góc màu cam của tấm thẻ cũ. Cụm góc phải trên khi đó
	có ba khối chữ nhật màu đứng cạnh nhau (Starter Pack, Spin, Playtime Boost) — hình gói
	bị chính cái khung của nó nuốt mất. Giờ chỉ còn ẢNH GÓI đứng trên nền trời, các con số
	dựa vào viền chữ dày (`TextStrokeThickness` 4-5) để đọc được, không dựa vào nền.

	── HAI THỨ ĐỂ HÚT MẮT, MỖI THỨ MỘT VIỆC ──────────────────────────────────────────────
	  • SUNBURST xoay + thở phía sau: tạo chuyển động ở vùng nhìn ngoại vi, kéo mắt tới.
	  • PULSE phóng to/thu nhỏ cả icon: giữ mắt lại thêm một nhịp sau khi đã nhìn.
	Hai cái phải khác chu kỳ nhau (sunburst 1.05s, pulse icon 1.25s, xoay 7s) — trùng chu kỳ
	thì cả khối đập như một, nhìn thành cái đèn nhấp nháy rẻ tiền.

	Icon TỰ ẨN khi: chưa cấu hình Product ID, đã mua, hoặc hết hạn — xem `StarterPackShared`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local StarterPackConfig = require(ReplicatedStorage.Shared.Config.Economy.StarterPack)
local Shared = require(script.Parent.StarterPackShared)
local Theme = require(script.Parent.Parent.Theme)
local Manager = require(script.Parent.Parent.Modals.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnEvent = Fusion.OnEvent
local Tween = Fusion.Tween
local Value = Fusion.Value

local StarterPackCard = {}

-- Ba tầng xếp dọc: ảnh gói (0–120), hàng giá (120–154), đồng hồ (156–184).
local ICON_WIDTH = 132
local ICON_HEIGHT = 186
local IMAGE_SIZE = 120

--[[
	Nhịp thở của cả icon. Một Value dùng chung cho hover lẫn pulse: hai `UIScale` chồng trên
	cùng một Frame thì chỉ một cái có tác dụng (thứ tự không xác định), nên phải NHÂN hai hệ
	số lại rồi đưa vào đúng một UIScale.

	1.25s mỗi nhịp — cố ý lệch với sunburst (1.05s) để hai chuyển động không khớp pha.
]]
local PULSE_PERIOD = 1.25
local PULSE_AMOUNT = 0.05 -- ±5%: đủ thấy ở đuôi mắt, chưa tới mức làm chữ khó đọc

local pulseGoal = Value(0)
local pulse = Tween(pulseGoal, TweenInfo.new(PULSE_PERIOD, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
task.spawn(function()
	while true do
		pulseGoal:set(1)
		task.wait(PULSE_PERIOD)
		pulseGoal:set(0)
		task.wait(PULSE_PERIOD)
	end
end)

function StarterPackCard.Build()
	local hovered = Value(false)

	return New("Frame")({
		BackgroundTransparency = 1,
		--[[
			Ô ĐẦU TIÊN (trái nhất) của HÀNG NGANG góc phải-trên — xem `Theme.TOP_ROW`.

			2026-08-21: hàng ngang thay cho chồng dọc cũ; trước đó ô này là ô đầu của
			`Theme.RIGHT_STACK` và phải tự cộng offset căn phải. Giờ bảng `TOP_ROW` đã giữ sẵn
			offset X nên ở đây không còn phép cộng tay nào.

			Vẫn giữ nguyên nguyên tắc cũ: KHÔNG tự chép lại công thức neo của panel bên cạnh
			(bản trước-2026-08-15 làm thế và lệch mỗi lần ô kia đổi cỡ), và KHÔNG đọc
			`AbsolutePosition` của panel khác — đó là pixel màn hình thật, còn icon này sống
			trong lớp đã bị `UIScale` co lại.
		]]
		Position = Computed(function()
			return Theme.TopRowSlotPosition("starterPack")
		end),
		Size = UDim2.fromOffset(ICON_WIDTH, ICON_HEIGHT),
		Visible = Shared.Available,
		ZIndex = 19,
		[Children] = {
			-- Hào quang nằm SAU thân icon (ZIndex 18 < 20). Chỉ hoạt động vì ScreenGui đặt
			-- `ZIndexBehavior = Global` — ở chế độ Sibling thì con không bao giờ chui được
			-- xuống dưới cha. Màu vàng nghệ chứ không phải trắng: nền là trời xanh + cát
			-- sáng của Lobby, hào quang trắng ở đó là tàng hình.
			Theme.MakeSunburst({
				-- Tâm hào quang đặt ở giữa ẢNH GÓI, không phải giữa cả khối: bỏ nền đi rồi thì
				-- ảnh mới là thứ cần được toả sáng, phần chữ bên dưới không cần.
				Position = UDim2.fromOffset(ICON_WIDTH * 0.5, IMAGE_SIZE * 0.5),
				Size = UDim2.fromOffset(IMAGE_SIZE + 120, IMAGE_SIZE + 120),
				ZIndex = 18,
				ImageColor3 = Color3.fromRGB(255, 208, 74),
				ImageTransparency = 0.42,
				Pulse = true,
			}),

			-- Nhịp thở của cả icon, nhân với hệ số hover. Một UIScale duy nhất (xem ghi chú
			-- ở đầu file).
			New("UIScale")({
				Scale = Computed(function()
					local hover = if hovered:get() then 1.06 else 1
					return hover * (1 + PULSE_AMOUNT * pulse:get())
				end),
			}),

			-- Cả khối là MỘT nút TRONG SUỐT phủ lên hình + chữ: bấm vào bất cứ đâu cũng mở
			-- modal. Nút trong suốt vẫn nhận input bình thường, nên không cần một cái nền
			-- nào để "có chỗ mà bấm".
			New("TextButton")({
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(ICON_WIDTH, ICON_HEIGHT),
				Text = "",
				ZIndex = 20,
				[OnEvent("Activated")] = Manager.OpenStarterPack,
				[OnEvent("MouseEnter")] = function()
					hovered:set(true)
				end,
				[OnEvent("MouseLeave")] = function()
					hovered:set(false)
				end,
				[Children] = {
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = Theme.UI_ASSETS.StarterPack,
						Position = UDim2.fromOffset((ICON_WIDTH - IMAGE_SIZE) * 0.5, 0),
						Size = UDim2.fromOffset(IMAGE_SIZE, IMAGE_SIZE),
						ZIndex = 24,
					}),

					-- Băng "−90%" chéo góc phải: con số này mới là thứ bán hàng, phải to nhất icon.
					Theme.MakeOutlineLabel({
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromOffset(ICON_WIDTH, 0),
						Size = UDim2.fromOffset(84, 36),
						Rotation = 8,
						Text = `-{StarterPackConfig.DISCOUNT_PERCENT}%`,
						TextColor3 = Color3.fromRGB(255, 240, 92),
						MaxTextSize = 34,
						ZIndex = 26,
					}),

					--[[
						GIÁ ngay trên HUD (user chốt 2026-08-12). Trước đây phải mở modal mới
						biết gói bao nhiêu, mà "-90%" thì không nói được là rẻ tới đâu — 90%
						của một con số chưa biết vẫn là chưa biết. Hai con số đứng CẠNH nhau
						mới tạo được phép so sánh, nên 999 gạch ngang nằm sát bên trái 99.
					]]
					Theme.MakeOutlineLabel({
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromOffset(ICON_WIDTH * 0.5 - 2, 126),
						Size = UDim2.fromOffset(60, 26),
						RichText = true,
						Text = `<s>{RobuxPrice.GLYPH}{StarterPackConfig.ORIGINAL_PRICE_ROBUX}</s>`,
						TextColor3 = Color3.fromRGB(228, 228, 228),
						TextXAlignment = Enum.TextXAlignment.Right,
						MaxTextSize = 22,
						ZIndex = 25,
					}),
					Theme.MakePriceLabel({
						Position = UDim2.fromOffset(ICON_WIDTH * 0.5 + 2, 122),
						Size = UDim2.fromOffset(64, 34),
						Text = `{RobuxPrice.GLYPH}{StarterPackConfig.PRICE_ROBUX}`,
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 30,
						ZIndex = 25,
					}),

					-- Đồng hồ đếm lùi — lý do duy nhất khiến người chơi bấm HÔM NAY thay vì "để mai".
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(0, 156),
						Size = UDim2.fromOffset(ICON_WIDTH, 28),
						Text = Computed(function()
							return Shared.FormatCountdown(Shared.SecondsLeft())
						end),
						TextColor3 = Color3.fromRGB(255, 236, 140),
						MaxTextSize = 24,
						ZIndex = 25,
					}),
				},
			}),
		},
	})
end

return StarterPackCard
