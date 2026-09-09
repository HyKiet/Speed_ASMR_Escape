--!strict
-- Modal Daily Login: điểm danh 7 ngày (hardcore streak). Theme hồng/magenta riêng biệt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local UIAnchors = require(script.Parent.Parent.UIAnchors)
local Tokens = require(script.Parent.Parent.Tokens)
local Manager = require(script.Parent.Manager)
-- Icon Streak Aurora lấy THẲNG từ config trail, không chép ID sang đây: CosmeticModal cũng
-- đọc cùng chỗ đó, nên đổi icon một lần là hai màn hình khớp nhau vĩnh viễn.
local Trails = require(ReplicatedStorage.Shared.Config.Economy.Trails)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Tween = Fusion.Tween
local Value = Fusion.Value

local DailyModal = {}

-- Ngã về icon trail chung nếu ai đó lỡ đổi id trong config — thà hiện icon chung còn hơn ô trống.
local STREAK_AURORA_ICON = (function(): string
	for _, trail in Trails do
		if trail.id == "trail_streak_aurora" then
			return trail.icon
		end
	end
	return Theme.UI_ASSETS.Trail
end)()

local PANEL_WIDTH = 700
local PANEL_HEIGHT = 584

--[[
	MŨI TÊN CHỈ VÀO NÚT CLAIM — bước 1 của tutorial (user yêu cầu 2026-08-12).

	Dải nhắc trên đỉnh màn hình đã bảo "bấm CLAIM", nhưng chữ thì người chơi 9 tuổi đọc sau
	cùng, mà modal Daily lại có tới 7 tấm thẻ rực rỡ tranh chỗ nhìn. Một mũi tên nhấp nhô ngay
	trên nút là thứ chỉ đường không cần đọc — cùng ngôn ngữ với thảm mũi tên ngoài thế giới
	(cùng texture chevron 10051771444).

	Mũi tên sống TRONG modal, không phải trong `TutorialGui`: nó phải co giãn cùng modal theo
	UIScale và tắt ngay khi modal đóng. Hiện khi `State.tutorialClaimHint` bật VÀ còn quà để
	nhận — nhận xong là mất ngay, không chỉ vào một cái nút xám.
]]
local HINT_ARROW = "rbxassetid://10051771444"

--[[
	Bảng hiển thị 7 ngày — MỖI PHẦN THƯỞNG MỘT ICON (2026-08-08, yêu cầu user).

	Ngày nào cũng cho từ 2 món trở lên (ngày 7 cho 3 món), nhưng bản cũ chỉ vẽ MỘT icon to ở
	giữa thẻ — cúp cho ngày thưởng Wins, giày cho ngày thưởng Speed — rồi nhét hai dòng chữ
	xuống dưới. Người chơi nhìn thấy cúp mà dòng dưới ghi "+1 Spin Ticket" thì không có cách
	nào đoán ra vé quay trông như thế nào, và món phụ (boost x2 10 phút, MEGA Boost) hoàn toàn
	không có hình.

	Giờ mỗi món là một `part` có icon riêng; thẻ vẽ một HÀNG CHIP icon rồi liệt kê chữ theo
	ĐÚNG thứ tự đó, nên icon nào ứng với dòng nào là đọc ra ngay.

	⚠️ Danh sách phải khớp `DAILY_REWARDS` trong `server/Services/Gameplay/DailyService.luau`
	— sai ở đây là người chơi thấy một đằng nhận một nẻo.
]]
type RewardPart = { icon: string, label: string }

local REWARD_CONFIGS: { { parts: { RewardPart } } } = {
	{
		parts = {
			{ icon = Theme.UI_ASSETS.Shoe, label = "+2.00K Speed" },
			{ icon = Theme.UI_ASSETS.Trophy, label = "+5 Wins" },
		},
	},
	{
		parts = {
			{ icon = Theme.UI_ASSETS.Shoe, label = "+10.00K Speed" },
			{ icon = Theme.UI_ASSETS.BoostSpeed, label = "x2 Speed 15m" },
		},
	},
	{
		parts = {
			{ icon = Theme.UI_ASSETS.Trophy, label = "+150 Wins" },
			{ icon = Theme.UI_ASSETS.Spin, label = "+1 Spin" },
		},
	},
	{
		parts = {
			{ icon = Theme.UI_ASSETS.Shoe, label = "+60.00K Speed" },
			{ icon = Theme.UI_ASSETS.BoostWins, label = "x2 Wins 15m" },
		},
	},
	{
		parts = {
			{ icon = Theme.UI_ASSETS.Trophy, label = "+1.20K Wins" },
			{ icon = Theme.UI_ASSETS.Spin, label = "+2 Spins" },
		},
	},
	{
		parts = {
			{ icon = Theme.UI_ASSETS.Shoe, label = "+400.00K Speed" },
			{ icon = Theme.UI_ASSETS.BoostMega, label = "MEGA Boost 15m" },
		},
	},
	{
		parts = {
			-- Trail đứng ĐẦU hàng: đây là món kéo người chơi đi hết bảy ngày, không phải
			-- số Wins đi kèm. Thứ tự icon = thứ tự dòng chữ nên nó cũng là dòng đầu tiên.
			{ icon = STREAK_AURORA_ICON, label = "STREAK AURORA TRAIL" },
			{ icon = Theme.UI_ASSETS.Trophy, label = "+12.00K Wins" },
			{ icon = Theme.UI_ASSETS.Spin, label = "+3 Spins" },
		},
	},
}

--[[
	Bảng phần thưởng cho NGƯỜI KHÁC đọc: `WinsFlight` dựng thẻ chúc mừng lúc CLAIM từ chính
	bảng này, nên thẻ luôn liệt kê đúng những gì modal đã hứa — kể cả sau này sửa quà.
	Trả về nil nếu `day` ngoài 1..7.
]]
function DailyModal.GetRewardParts(day: number): { RewardPart }?
	local config = REWARD_CONFIGS[day]
	return if config then config.parts else nil
end

--[[
	Chip icon: nền tối bo tròn + viền đen, icon nằm trong.

	Cần cái nền này vì hai icon đặt sát nhau trên thẻ gradient rực rỡ sẽ dính thành một mảng
	màu, mắt không tách ra được là "hai phần thưởng". Nền tối cũng kéo tương phản cho mấy icon
	sáng màu (giày trắng-đỏ trên thẻ vàng ngày claimable gần như tàng hình).
]]
local function makeRewardChip(icon: string, x: number, y: number, size: number)
	local pad = math.floor(size * 0.12)
	return New("Frame")({
		BackgroundColor3 = Color3.fromRGB(18, 4, 26),
		BackgroundTransparency = 0.28,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 46,
		[Children] = {
			Theme.MakeCorner(math.floor(size * 0.28)),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), Tokens.BORDER),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(pad, pad),
				Size = UDim2.fromOffset(size - pad * 2, size - pad * 2),
				ZIndex = 47,
			}),
		},
	})
end

-- Trạng thái 1 ngày: "claimed" | "claimable" | "locked"
local function dayStatus(day: number): string
	local streak = State.dailyStreakDay:get()
	local nextDay = State.dailyNextDay:get()
	local canClaim = State.dailyCanClaim:get()
	if day <= streak then
		return "claimed"
	end
	if canClaim and day == nextDay then
		return "claimable"
	end
	return "locked"
end

local function makeDayCard(day: number)
	local isDay7 = day == 7
	local cfg = REWARD_CONFIGS[day]

	local colorA = Computed(function()
		local status = dayStatus(day)
		if status == "claimed" then
			return Color3.fromRGB(86, 200, 110)
		elseif status == "claimable" then
			return if isDay7 then Color3.fromRGB(255, 222, 60) else Color3.fromRGB(255, 206, 64)
		end
		return if isDay7 then Color3.fromRGB(200, 60, 220) else Color3.fromRGB(150, 70, 165)
	end)
	local colorB = Computed(function()
		return colorA:get():Lerp(Color3.fromRGB(0, 0, 0), 0.34)
	end)

	local w = if isDay7 then 200 else 145
	local h = if isDay7 then 315 else 152

	local cardChildren: { any } = {
		Theme.MakeCorner(16),
		-- Day 7 nổi bật bằng MÀU viền (vàng), KHÔNG bằng độ dày: độ dày viền là một con số
		-- duy nhất cho cả HUD (xem `Tokens.BORDER`).
		Theme.MakeStroke(if isDay7 then Color3.fromRGB(255, 235, 100) else Color3.fromRGB(0, 0, 0), Tokens.BORDER),
		Theme.MakeGradientDynamic(colorA, colorB),
		Theme.MakeStandardStuds(16, 44),
	}

	-- Nếu là Day 7: Thêm tia hào quang Sunburst xoay rực rỡ
	if isDay7 then
		local sunburst = Theme.MakeSunburst({
			ImageColor3 = Color3.fromRGB(255, 235, 110),
			ImageTransparency = 0.25,
			Position = UDim2.fromOffset(w / 2, h / 2 - 25),
			Size = UDim2.fromOffset(270, 270),
			ZIndex = 45,
			SpinSeconds = 10,
		})
		table.insert(cardChildren, sunburst)
	end

	-- DAY n / GRAND JACKPOT
	table.insert(
		cardChildren,
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.fromOffset(w, 24),
			Text = if isDay7 then "GRAND JACKPOT ★" else `DAY {day}`,
			TextColor3 = if isDay7 then Color3.fromRGB(255, 245, 120) else Color3.fromRGB(255, 255, 255),
			MaxTextSize = if isDay7 then 24 else 20,
			ZIndex = 46,
		})
	)

	--[[
		CHIP ICON.

		Ngày thường: một hàng ngang, mỗi phần thưởng một chip.

		Ngày 7: xếp TAM GIÁC — chip Trail to nằm ĐỈNH, hai chip nhỏ (Wins, Spin) làm đáy.
		Ba chip bằng nhau xếp hàng ngang thì mắt đọc là "ba món ngang hàng"; thực tế món kéo
		người chơi đi trọn bảy ngày là cái trail độc quyền, hai món kia chỉ là phần thêm.
		Chip to đặt trên đỉnh nói ra điều đó mà không cần một chữ nào, và hình tam giác cũng
		hợp với tia Sunburst xoay phía sau hơn là một hàng ngang cắt ngang giữa thẻ.
	]]
	local parts = cfg.parts
	local textTop: number
	local lineHeight = if isDay7 then 28 else 22

	if isDay7 then
		local topSize = 74
		local baseSize = 52
		local baseGap = 12
		local topY = 66

		-- Đỉnh: món đầu tiên trong `parts` (đã cố ý xếp Trail lên đầu ở REWARD_CONFIGS).
		table.insert(cardChildren, makeRewardChip(parts[1].icon, math.floor((w - topSize) / 2), topY, topSize))

		-- Đáy: các món còn lại, căn giữa dưới đỉnh.
		local baseCount = #parts - 1
		local baseWidth = baseCount * baseSize + (baseCount - 1) * baseGap
		local baseX = math.floor((w - baseWidth) / 2)
		local baseY = topY + topSize + 8
		for index = 2, #parts do
			table.insert(
				cardChildren,
				makeRewardChip(parts[index].icon, baseX + (index - 2) * (baseSize + baseGap), baseY, baseSize)
			)
		end

		textTop = baseY + baseSize + 12
	else
		local chipSize = 46
		local chipGap = 9
		local rowWidth = #parts * chipSize + (#parts - 1) * chipGap
		local chipX = math.floor((w - rowWidth) / 2)
		local chipY = 38
		for index, part in parts do
			table.insert(
				cardChildren,
				makeRewardChip(part.icon, chipX + (index - 1) * (chipSize + chipGap), chipY, chipSize)
			)
		end
		textTop = chipY + chipSize + 8
	end

	-- DANH SÁCH CHỮ — cùng thứ tự với chip ở trên, một dòng một món.
	for index, part in parts do
		table.insert(
			cardChildren,
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, textTop + (index - 1) * lineHeight),
				Size = UDim2.fromOffset(w, lineHeight),
				Text = part.label,
				-- Dòng đầu = phần thưởng chính (vàng), các dòng sau = món kèm theo (bạc hà).
				TextColor3 = if index == 1 then Color3.fromRGB(255, 244, 130) else Color3.fromRGB(180, 255, 220),
				MaxTextSize = if isDay7 then (if index == 1 then 26 else 21) else (if index == 1 then 19 else 16),
				ZIndex = 46,
			})
		)
	end

	-- Lớp phủ "CLAIMED" khi đã nhận
	table.insert(
		cardChildren,
		New("Frame")({
			BackgroundColor3 = Color3.fromRGB(8, 40, 16),
			BackgroundTransparency = 0.45,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(1, 1),
			Visible = Computed(function()
				return dayStatus(day) == "claimed"
			end),
			ZIndex = 47,
			[Children] = {
				Theme.MakeCorner(16),
				Theme.MakeOutlineLabel({
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Rotation = -15,
					Size = UDim2.fromScale(0.9, 0.4),
					Text = "CLAIMED",
					TextColor3 = Color3.fromRGB(88, 255, 120),
					MaxTextSize = 28,
					ZIndex = 48,
				}),
			},
		})
	)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		LayoutOrder = day,
		Size = UDim2.fromOffset(w, h),
		ZIndex = 43,
		[Children] = cardChildren,
	})
end

local function buildGrid()
	local cards1to6 = {}
	for day = 1, 6 do
		table.insert(cards1to6, makeDayCard(day))
	end
	table.insert(
		cards1to6,
		New("UIGridLayout")({
			CellPadding = UDim2.fromOffset(10, 10),
			CellSize = UDim2.fromOffset(145, 152),
			FillDirectionMaxCells = 3,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	)

	local leftFrame = New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(455, 315),
		[Children] = cards1to6,
	})

	local day7Card = makeDayCard(7)
	day7Card.Position = UDim2.fromOffset(465, 0)

	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(17, 146),
		Size = UDim2.fromOffset(665, 315),
		ZIndex = 43,
		[Children] = {
			leftFrame,
			day7Card,
		},
	})
end

local function buildContent(hintBob: any): { any }
	local claimHovered = State.dailyClaimHovered

	return {
		-- Subtitle
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(24, 106),
			Size = UDim2.fromOffset(652, 36),
			Text = "Log in every day! Miss a day and your streak resets.",
			TextColor3 = Color3.fromRGB(255, 226, 244),
			MaxTextSize = 22,
			ZIndex = 42,
		}),

		buildGrid(),

		-- Mũi tên chỉ xuống nút CLAIM (xem khối ghi chú ở đầu file). Chevron gốc chỉ LÊN
		-- nên xoay 180°. Nhấp nhô 0→14px, chu kỳ 0.45s — nhanh hơn nhịp thở của thẻ để nó
		-- không hoà vào cái nền đang chuyển động sẵn.
		New("ImageLabel")({
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Image = HINT_ARROW,
			ImageColor3 = Color3.fromRGB(255, 226, 82),
			Position = Computed(function()
				return UDim2.fromOffset(350, 496 - 14 * hintBob:get())
			end),
			Rotation = 180,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(64, 64),
			Visible = Computed(function()
				return State.tutorialClaimHint:get() and State.dailyCanClaim:get()
			end),
			ZIndex = 48,
		}),

		-- Claim button
		--[[
			Nút CLAIM — dựng bằng `MakeSurface` + `Zoom`, không tự chồng khung đen nữa.

			Bản cũ là "khung đen bọc ngoài + TextButton bên trong", và `HoverZoom` nằm TRONG cái
			TextButton — nên rê chuột chỉ ruột xanh phình ra còn viền đen đứng im (user báo
			2026-08-16: "stroke không có hiệu ứng theo button"). `MakeSurface` đặt `UIScale` lên
			chính lớp viền nên cả khối phóng như một, và `Zoom` bọc thêm một lớp neo tâm nên nó
			nở ĐỀU ra bốn góc thay vì chỉ về phải + xuống dưới.
		]]
		-- Điểm neo cho spotlight của tutorial: bước cuối chiếu thẳng vào chính nút này
		-- (xem `HUD/UIAnchors` và `CoreLoop/TutorialController`).
		UIAnchors.Keep(
			"dailyClaimButton",
			Theme.MakeSurface({
				ClassName = "TextButton",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(350, 500),
				Size = UDim2.fromOffset(440, 66),
				ZIndex = 45,
				Radius = 16,
				Border = 4,
				Color = Computed(function()
					return if State.dailyCanClaim:get()
						then Color3.fromRGB(108, 240, 130)
						else Color3.fromRGB(110, 64, 100)
				end),
				ColorB = Computed(function()
					return if State.dailyCanClaim:get() then Color3.fromRGB(34, 162, 64) else Color3.fromRGB(70, 36, 64)
				end),
				Zoom = { Hovered = claimHovered, Scale = 1.08 },
				Activated = function()
					if State.dailyCanClaim:get() then
						GamePackets.requestDailyClaim.send({})
					end
				end,
				MouseEnter = function()
					claimHovered:set(true)
				end,
				MouseLeave = function()
					claimHovered:set(false)
				end,
				-- `Content` dạng HÀM: nhận hệ số phóng để CHỮ to lên cùng nhịp với khung nút.
				Content = function(zoom)
					return {
						Theme.MakeOutlineLabel({
							Position = UDim2.fromScale(0, 0),
							Size = UDim2.fromScale(1, 1),
							Text = Computed(function()
								if State.dailyCanClaim:get() then
									return `CLAIM DAY {State.dailyNextDay:get()}`
								end
								return "COME BACK TOMORROW"
							end),
							Zoom = zoom,
							MaxTextSize = 36,
							ZIndex = 47,
						}),
					}
				end,
			})
		),
	}
end

function DailyModal.Build()
	local hintBobGoal = Value(0)
	local hintBob = Tween(hintBobGoal, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
	local hintThread = task.spawn(function()
		while true do
			hintBobGoal:set(1)
			task.wait(0.45)
			hintBobGoal:set(0)
			task.wait(0.45)
		end
	end)
	local modal = ModalShell.Build({
		Id = "daily",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(30, 0, 20),
		HeaderColor = Color3.fromRGB(255, 150, 214),
		HeaderColorB = Color3.fromRGB(236, 64, 156),
		Icon = Theme.UI_ASSETS.Daily,
		Title = "Daily Rewards",
		TitleMaxTextSize = 50,
		OnClose = Manager.CloseDaily,
		Content = buildContent(hintBob),
	})
	modal.Destroying:Connect(function()
		task.cancel(hintThread)
	end)
	return modal
end

return DailyModal
