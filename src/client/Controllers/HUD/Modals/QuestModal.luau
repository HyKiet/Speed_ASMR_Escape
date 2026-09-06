--!strict
--[[
	QuestModal — bảng nhiệm vụ, dựng theo ĐÚNG khuôn của mọi modal danh sách khác.

	══ VÌ SAO VIẾT LẠI (user 2026-09-05: "bật UI nào cũng phải giống nhau") ═════════════════

	Bản cũ sống trong `Hud/QuestTracker` và là MỘT TRONG HAI modal duy nhất tự đi đường riêng:

	    • `Scale = 0.9` — không modal nào khác có `UIScale`, trừ `ShopModal` (0.86, có lý do
	      riêng ghi trong file đó). Hệ quả: mọi thứ trong Quest nhỏ hơn phần còn lại của HUD
	      đúng 10% — thanh tiêu đề cao 76px thay vì 84, nút X 59px thay vì 66, và VIỀN 4.5px
	      thay vì 4. Nhìn cạnh Shop hay Teleport là thấy ngay nó "lệch tông" mà khó chỉ ra vì
	      sao: không sai một số nào, chỉ là cả bảng bị thu nhỏ.
	    • `MODAL_BORDER = 5` — con số bù cho cái `UIScale` kia (5 × 0.9 ≈ 4.5). Bỏ `UIScale` thì
	      nó cũng biến mất luôn, viền quay về `Tokens.BORDER` như 12 modal còn lại.

	Giờ Quest dùng khuôn danh sách chuẩn, y hệt `TeleportModal`:

	    632×680 · caption ở y=98 · ScrollingFrame (24,140) 584×518 · hàng rộng 556, cách 12
	    hàng: bo 16 / viền 4 · nút hành động 184×60 bo 12 viền 4 · Zoom 1.08 · nhãn nhận `zoom`

	Con số nào cũng chép từ Teleport/Cosmetic chứ không tự nghĩ — đó chính là điểm của việc này.

	══ HAI CHẾ ĐỘ TRONG CÙNG MỘT KHUÔN ══════════════════════════════════════════════════════
	`dailyQuestActive` bật ⇒ 3 hàng nhiệm vụ ngày (mỗi hàng có nút CLAIM riêng).
	Tắt ⇒ một hàng DUY NHẤT của chuỗi quest mở đầu — vẫn là một hàng cùng khuôn, không phải một
	"thẻ lớn" bố cục khác như bản cũ. Người chơi đi từ chuỗi mở đầu sang nhiệm vụ ngày sẽ thấy
	bảng GIỮ NGUYÊN hình dạng thay vì đổi hẳn sang layout khác.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

local QuestModal = {}

local PANEL_WIDTH = 632
-- Mép trên của danh sách, đo từ mép trên vỏ (header 84 + dải caption).
local SCROLL_TOP = 140
local SCROLL_BOTTOM_MARGIN = 24

-- Khuôn danh sách chuẩn (xem `TeleportModal`): hàng rộng 556 nằm trong ScrollingFrame 584.
local ROW_WIDTH = 556
local ROW_HEIGHT = 128
local ROW_GAP = 12
--[[
	⚠️ Một hàng chiếm `ROW_HEIGHT + 2×BORDER` chứ không phải `ROW_HEIGHT`: `MakeSurface` vẽ viền
	RA NGOÀI ô khai báo (xem `growForBorder` trong `Theme`). Đo trong Studio 2026-09-05: hàng khai
	110 nằm cách nhau 130px = 118 + 12. Quên 2×BORDER thì `CanvasSize` hụt và hàng cuối bị cụt
	một dải không cuộn tới được.
]]
local ROW_PITCH = ROW_HEIGHT + Tokens.BORDER * 2 + ROW_GAP

local ACTION_WIDTH = 184
local ACTION_HEIGHT = 60
local ACTION_X = ROW_WIDTH - ACTION_WIDTH - 14

-- Cột trái của hàng: từ sau icon tới sát nút hành động.
local COL_X = 86
local COL_WIDTH = ACTION_X - COL_X - 14

-- Chiều cao ô cuộn / vỏ modal cho một số hàng cho trước. Hàng cuối không có khe sau nó,
-- nên trừ đi một `ROW_GAP`; `+12` là hai lề trong 6px của `UIPadding`.
local function listHeight(rowCount: number): number
	return rowCount * ROW_PITCH - ROW_GAP + 12
end

local function panelHeight(rowCount: number): number
	return SCROLL_TOP + listHeight(rowCount) + SCROLL_BOTTOM_MARGIN
end

local function progressRatio(progress: any, target: any): number
	return math.clamp(progress:get() / math.max(1, target:get()), 0, 1)
end

--[[
	Thanh tiến độ — CÙNG cấu tạo với thanh trong tracker thu gọn và trong `BottomHud`: rãnh tối
	`MakeSurface` + miếng chạy vàng bo cùng bán kính. Chỉ số đo là khác, ngôn ngữ hình ảnh giống.
]]
local function makeProgressBar(progress: any, target: any, y: number)
	return Theme.MakeSurface({
		Position = UDim2.fromOffset(COL_X, y),
		Size = UDim2.fromOffset(COL_WIDTH, 28),
		ZIndex = Tokens.Z.MODAL_CONTENT + 4,
		Radius = Tokens.RADIUS.BUTTON,
		Border = Tokens.BORDER,
		Studs = false,
		Color = Color3.fromRGB(20, 14, 46),
		Content = {
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(255, 203, 54),
				BorderSizePixel = 0,
				Size = Computed(function()
					return UDim2.fromScale(progressRatio(progress, target), 1)
				end),
				ZIndex = Tokens.Z.MODAL_CONTENT + 5,
				[Children] = { Theme.MakeCorner(Tokens.RADIUS.BUTTON) },
			}),
			Theme.MakeOutlineLabel({
				Size = UDim2.fromScale(1, 1),
				Text = Computed(function()
					return `{math.floor(progress:get())} / {math.floor(target:get())}`
				end),
				MaxTextSize = 18,
				ZIndex = Tokens.Z.MODAL_CONTENT + 6,
			}),
		},
	})
end

-- Một ô phần thưởng: icon + "+N". Ẩn hẳn khi phần thưởng đó bằng 0 để hàng không có chỗ trống lửng.
local function makeRewardChip(icon: string, amount: any, x: number, y: number)
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(120, 30),
		Visible = Computed(function()
			return amount:get() > 0
		end),
		ZIndex = Tokens.Z.MODAL_CONTENT + 4,
		[Children] = {
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Size = UDim2.fromOffset(28, 28),
				ZIndex = Tokens.Z.MODAL_CONTENT + 4,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(32, 0),
				Size = UDim2.fromOffset(86, 28),
				Text = Computed(function()
					return `+{Theme.FormatInteger(amount:get())}`
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(255, 226, 95),
				MaxTextSize = 20,
				ZIndex = Tokens.Z.MODAL_CONTENT + 4,
			}),
		},
	})
end

--[[
	Vỏ hàng dùng chung cho CẢ HAI chế độ.

	`action` là bảng mô tả nút bên phải, hoặc `nil` khi hàng không có nút (chuỗi quest mở đầu
	hoàn thành tự động, không có gì để bấm) — lúc đó cột trái nới rộng ra chiếm chỗ nút.
]]
type RowAction = {
	Label: any,
	Color: any,
	ColorB: any,
	Hovered: any,
	Activated: () -> (),
}

local function makeRow(props: {
	LayoutOrder: number,
	Visible: any?,
	Icon: string,
	Title: any,
	Progress: any,
	Target: any,
	RewardA: { Icon: string, Amount: any },
	RewardB: { Icon: string, Amount: any }?,
	Action: RowAction?,
})
	local content: { any } = {
		New("ImageLabel")({
			BackgroundTransparency = 1,
			Image = props.Icon,
			Position = UDim2.fromOffset(14, 32),
			Size = UDim2.fromOffset(64, 64),
			ZIndex = Tokens.Z.MODAL_CONTENT + 4,
		}),
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(COL_X, 14),
			Size = UDim2.fromOffset(COL_WIDTH, 38),
			Text = props.Title,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 28,
			ZIndex = Tokens.Z.MODAL_CONTENT + 4,
		}),
		makeProgressBar(props.Progress, props.Target, 58),
		makeRewardChip(props.RewardA.Icon, props.RewardA.Amount, COL_X, 94),
	}
	if props.RewardB then
		table.insert(content, makeRewardChip(props.RewardB.Icon, props.RewardB.Amount, COL_X + 132, 94))
	end

	local action = props.Action
	if action then
		table.insert(
			content,
			Theme.MakeSurface({
				ClassName = "TextButton",
				Position = UDim2.fromOffset(ACTION_X, (ROW_HEIGHT - ACTION_HEIGHT) // 2),
				Size = UDim2.fromOffset(ACTION_WIDTH, ACTION_HEIGHT),
				ZIndex = Tokens.Z.MODAL_CONTENT + 5,
				Radius = 12,
				Border = Tokens.BORDER,
				Color = action.Color,
				ColorB = action.ColorB,
				GradientRotation = 0,
				Zoom = { Hovered = action.Hovered, Scale = Tokens.HOVER_SCALE },
				Activated = action.Activated,
				MouseEnter = function()
					action.Hovered:set(true)
				end,
				MouseLeave = function()
					action.Hovered:set(false)
				end,
				-- `Content` dạng HÀM để chữ phóng cùng nhịp với khung nút — quy ước chung của
				-- mọi nút trong HUD (xem khối lý do ở `DailyModal`).
				Content = function(zoom)
					return {
						Theme.MakeOutlineLabel({
							Size = UDim2.fromScale(1, 1),
							Text = action.Label,
							Zoom = zoom,
							TextColor3 = Color3.new(1, 1, 1),
							MaxTextSize = 24,
							MinTextSize = 12,
							ZIndex = Tokens.Z.MODAL_CONTENT + 7,
						}),
					}
				end,
			})
		)
	end

	return Theme.MakeSurface({
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT),
		Visible = props.Visible,
		ZIndex = Tokens.Z.MODAL_CONTENT + 2,
		Radius = 16,
		Border = Tokens.BORDER,
		Color = Color3.fromRGB(66, 47, 126),
		ColorB = Color3.fromRGB(42, 28, 88),
		Content = content,
	})
end

local function makeDailyRow(index: number, title: any, progress: any, target: any, claimed: any)
	local hovered = Value(false)
	local canClaim = Computed(function()
		return not claimed:get() and progress:get() >= target:get()
	end)

	return makeRow({
		LayoutOrder = index,
		Icon = Theme.UI_ASSETS.Quest,
		Title = title,
		Progress = progress,
		Target = target,
		RewardA = { Icon = Theme.UI_ASSETS.Shoe, Amount = State.dailyQuestRewardSpeed },
		RewardB = { Icon = Theme.UI_ASSETS.Trophy, Amount = State.dailyQuestRewardWins },
		Action = {
			Label = Computed(function()
				if claimed:get() then
					return "CLAIMED"
				end
				return if canClaim:get() then "CLAIM" else "IN PROGRESS"
			end),
			--[[
				Ba trạng thái, ba màu — CÙNG bộ màu mà `DailyModal` và `CosmeticModal` dùng:
				xanh lá (108,240,130)/(34,162,64) = bấm được, xám = đã xong, tím trầm = chưa đủ.
				Đừng pha màu mới ở đây; người chơi học màu một lần rồi áp cho cả game.
			]]
			Color = Computed(function()
				if claimed:get() then
					return Color3.fromRGB(96, 106, 128)
				end
				return if canClaim:get() then Color3.fromRGB(108, 240, 130) else Color3.fromRGB(86, 66, 148)
			end),
			ColorB = Computed(function()
				if claimed:get() then
					return Color3.fromRGB(58, 66, 88)
				end
				return if canClaim:get() then Color3.fromRGB(34, 162, 64) else Color3.fromRGB(52, 38, 104)
			end),
			Hovered = hovered,
			Activated = function()
				if canClaim:get() then
					GamePackets.requestDailyQuestClaim.send({ index = index })
				end
			end,
		},
	})
end

--[[
	Hàng của CHUỖI QUEST MỞ ĐẦU. Không có nút: chuỗi này tự phát thưởng khi đạt mốc, người chơi
	không phải bấm gì — nên đặt một nút chết ở đó chỉ để "cho cân" là nói dối về khả năng tương tác.
]]
local function makeChainRow()
	return makeRow({
		LayoutOrder = 1,
		Icon = Theme.UI_ASSETS.Quest,
		Title = Computed(function()
			return if State.questActive:get() then State.questTitle:get() else "Complete the tutorial above"
		end),
		Progress = State.questProgress,
		Target = State.questTarget,
		RewardA = { Icon = Theme.UI_ASSETS.Shoe, Amount = State.questRewardSpeed },
		RewardB = { Icon = Theme.UI_ASSETS.Spin, Amount = State.questRewardSpins },
	})
end

local function buildList()
	--[[
		Hai chế độ nằm trong HAI Frame chồng nhau, bật/tắt bằng `Visible`, chứ không phải một
		danh sách đổi nội dung: mỗi chế độ có số hàng khác nhau nên `CanvasSize` cũng khác, và
		`UIListLayout` của chế độ đang ẩn vẫn phải giữ nguyên bố cục của nó.
	]]
	local function pane(visible: any, rows: { any }, rowCount: number)
		local children: { any } = {
			New("UIListLayout")({
				Padding = UDim.new(0, ROW_GAP),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			New("UIPadding")({
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
		}
		for _, row in rows do
			table.insert(children, row)
		end

		--[[
			Ô cuộn cao ĐÚNG bằng nội dung của chế độ đó, và vỏ modal cao theo nó (xem `panelHeight`).

			Vì sao không để một chiều cao cố định cho cả hai: chế độ chuỗi mở đầu chỉ có MỘT hàng,
			nên trong tấm 680px của khuôn danh sách chuẩn nó bỏ trống hai phần ba bảng — đo trong
			Studio 2026-09-05, hàng duy nhất chiếm 148/518px. Một tấm kính mờ rỗng như vậy đọc như
			là UI hỏng chứ không phải như một bảng gọn.
		]]
		return New("ScrollingFrame")({
			Active = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			-- Canvas ĐÚNG BẰNG ô nhìn thấy: lệch một chút thôi là hiện thanh cuộn thừa
			-- trên một danh sách vốn không cần cuộn (đo 2026-09-05: lệch 12px).
			CanvasSize = UDim2.fromOffset(0, listHeight(rowCount)),
			Position = UDim2.fromOffset(24, SCROLL_TOP),
			ScrollBarImageColor3 = Color3.fromRGB(200, 222, 255),
			ScrollBarThickness = 10,
			Size = UDim2.fromOffset(584, listHeight(rowCount)),
			Visible = visible,
			ZIndex = Tokens.Z.MODAL_CONTENT,
			[Children] = children,
		})
	end

	local dailyPane = pane(State.dailyQuestActive, {
		makeDailyRow(
			1,
			State.dailyQuest1Title,
			State.dailyQuest1Progress,
			State.dailyQuest1Target,
			State.dailyQuest1Claimed
		),
		makeDailyRow(
			2,
			State.dailyQuest2Title,
			State.dailyQuest2Progress,
			State.dailyQuest2Target,
			State.dailyQuest2Claimed
		),
		makeDailyRow(
			3,
			State.dailyQuest3Title,
			State.dailyQuest3Progress,
			State.dailyQuest3Target,
			State.dailyQuest3Claimed
		),
	}, 3)

	local chainPane = pane(
		Computed(function()
			return not State.dailyQuestActive:get()
		end),
		{ makeChainRow() },
		1
	)

	return dailyPane, chainPane
end

-- Hai dòng caption ở y=98: trái = tên nhóm, phải = ghi chú. Cùng vị trí và cùng cỡ chữ với
-- caption của `ShopModal` / `RouletteModal`, nên ba modal xếp cạnh nhau đọc như một bộ.
local function buildCaptions(): { any }
	return {
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(26, 98),
			Size = UDim2.fromOffset(320, 34),
			Text = Computed(function()
				if not State.questActive:get() then
					return "GETTING STARTED"
				end
				return if State.dailyQuestActive:get()
					then "TODAY'S MISSIONS"
					else `QUEST CHAIN  •  {State.questIndex:get()}/6`
			end),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(255, 226, 95),
			MaxTextSize = 26,
			ZIndex = Tokens.Z.MODAL_CONTENT,
		}),
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(354, 98),
			Size = UDim2.fromOffset(252, 34),
			Text = Computed(function()
				if not State.questActive:get() then
					return "FINISH THE TUTORIAL ABOVE"
				end
				return if State.dailyQuestActive:get() then "RESETS DAILY" else "FOLLOW THE NEXT GOAL"
			end),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Color3.fromRGB(200, 187, 255),
			MaxTextSize = 19,
			ZIndex = Tokens.Z.MODAL_CONTENT,
		}),
	}
end

function QuestModal.Build()
	local dailyPane, chainPane = buildList()
	local content = buildCaptions()
	table.insert(content, dailyPane)
	table.insert(content, chainPane)

	return ModalShell.Build({
		Id = "quest",
		Width = PANEL_WIDTH,
		--[[
			Vỏ co theo chế độ đang bật: 3 hàng nhiệm vụ ngày, hay 1 hàng chuỗi mở đầu.

			`RaiseHeight` PHẢI là một con số chốt (xem `ModalShell.ModalShellProps`) — lấy chiều
			cao LỚN NHẤT để chỗ nhích lên tính theo tấm to nhất và modal không nhảy vị trí lúc
			đổi chế độ.
		]]
		Height = Computed(function()
			return panelHeight(if State.dailyQuestActive:get() then 3 else 1)
		end),
		RaiseHeight = panelHeight(3),
		PanelColor = Color3.fromRGB(30, 18, 68),
		-- Đúng cặp màu của nút "Quest" trong `Hud/LeftMenu`: bấm nút vàng-cam ra bảng vàng-cam,
		-- mắt nối được nút với bảng mà không phải đọc chữ.
		HeaderColor = Color3.fromRGB(255, 203, 54),
		HeaderColorB = Color3.fromRGB(225, 116, 28),
		Icon = Theme.UI_ASSETS.Quest,
		Title = "Quests",
		TitleMaxTextSize = 50,
		OnClose = Manager.CloseQuest,
		Content = content,
	})
end

return QuestModal
