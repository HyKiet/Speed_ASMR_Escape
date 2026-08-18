--!strict
--[[
	Thanh đếm ngược Boost đang hoạt động (GÓC DƯỚI PHẢI, xếp dọc).
	Server gửi số giây còn lại qua boostState; client tự đếm ngược theo State.boostClockNow.

	── MỖI NGUỒN MỘT CHIP, KHÔNG GỘP (2026-08-10, user) ───────────────────────────────────
	Bản cũ nhân hai nguồn lại thành MỘT chip "x4 SPEED" và lấy `math.max` của hai đồng hồ.
	Sai ở ba chỗ cùng lúc:
	  • Người chơi đang có x2 cá nhân, mua thêm Server x2 → chip nhảy thành "x4 SERVER",
	    trông như tiền của họ mua ra một thứ khác hẳn thứ ghi trên thẻ hàng.
	  • Hai boost hết hạn ở HAI thời điểm khác nhau, mà chỉ hiện một đồng hồ ⇒ đến lúc cái
	    dài hơn còn chạy thì hệ số đã âm thầm tụt từ x4 về x2, không có gì báo.
	  • Chỉ có một icon cho hai nguồn khác nhau.
	Giờ mỗi nguồn là một chip riêng với icon, nhãn và ĐỒNG HỒ RIÊNG; nhân đôi hệ số vẫn xảy
	ra ở server, nhưng trên màn hình người chơi đọc được chính xác mình đang có những gì và
	cái nào sắp hết.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New

local BoostHud = {}

local function formatClock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

--[[
	MỘT chip = MỘT nguồn boost. `icon` khớp đúng thứ người chơi thấy lúc mua (thẻ Server Boost
	trong Shop cho boost server; giày/cúp cho boost cá nhân từ Daily, code, Roulette).
	`label` phải nói rõ NGUỒN ("SERVER x2 SPEED" / "MY x2 SPEED") — hai chip cùng ghi
	"x2 SPEED" xếp chồng nhau thì lại thành một câu đố khác.
]]
local function makeChip(icon: string, label: string, colorA: Color3, colorB: Color3, untilValue: any, order: number)
	local secondsLeft = Computed(function()
		return math.max(0, untilValue:get() - State.boostClockNow:get())
	end)

	return New("Frame")({
		BackgroundColor3 = colorA,
		LayoutOrder = order,
		-- 300 chứ không phải 250 của bản gộp: nhãn giờ có thêm chữ nguồn ("SERVER x2 SPEED"),
		-- hẹp hơn là TextScaled xuống dòng thành hai hàng chữ bé trong một chip cao 54.
		Size = UDim2.fromOffset(300, 54),
		Visible = Computed(function()
			return secondsLeft:get() > 0
		end),
		ZIndex = 30,
		[Children] = {
			Theme.MakeCorner(14),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB, 0),
			Theme.MakeStandardStuds(14, 31),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(8, 7),
				Size = UDim2.fromOffset(40, 40),
				ZIndex = 33,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(52, 6),
				Size = UDim2.fromOffset(172, 42),
				Text = label,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 23,
				ZIndex = 33,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(224, 6),
				Size = UDim2.fromOffset(68, 42),
				Text = Computed(function()
					return formatClock(secondsLeft:get())
				end),
				TextColor3 = Color3.fromRGB(255, 244, 130),
				TextXAlignment = Enum.TextXAlignment.Right,
				MaxTextSize = 26,
				ZIndex = 33,
			}),
		},
	})
end

function BoostHud.Build()
	return New("Frame")({
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = Computed(function()
			local _, _, right, bottom = Theme.GetVisibleDesignBounds()
			return UDim2.fromOffset(right - 14, bottom - 14)
		end),
		-- 4 chip × 54 + 3 khe × 12 = 252. Khung phải đủ cao cho trường hợp cả bốn cùng chạy,
		-- nếu không UIListLayout đẩy chip trên cùng ra ngoài khung và nó biến mất.
		Size = UDim2.fromOffset(300, 252),
		ZIndex = 30,
		[Children] = {
			New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			-- Thứ tự: server trước, cá nhân sau, Speed trước Wins. Boost server là món vừa
			-- được mua bằng Robux nên nằm trên cùng — chỗ mắt nhìn đầu tiên.
			-- Icon trùng đúng thẻ "Server x2 Speed" / "Server x2 Wins" trong Shop.
			makeChip(
				Theme.UI_ASSETS.BoostSpeed,
				"SERVER x2 SPEED",
				Color3.fromRGB(72, 220, 200),
				Color3.fromRGB(20, 130, 150),
				State.boostServerSpeedUntil,
				1
			),
			makeChip(
				Theme.UI_ASSETS.Shoe,
				"MY x2 SPEED",
				Color3.fromRGB(120, 210, 255),
				Color3.fromRGB(40, 110, 220),
				State.boostPersonalSpeedUntil,
				2
			),
			makeChip(
				Theme.UI_ASSETS.BoostWins,
				"SERVER x2 WINS",
				Color3.fromRGB(255, 190, 72),
				Color3.fromRGB(220, 110, 20),
				State.boostServerWinsUntil,
				3
			),
			makeChip(
				Theme.UI_ASSETS.Trophy,
				"MY x2 WINS",
				Color3.fromRGB(255, 226, 130),
				Color3.fromRGB(228, 158, 40),
				State.boostPersonalWinsUntil,
				4
			),
		},
	})
end

return BoostHud
