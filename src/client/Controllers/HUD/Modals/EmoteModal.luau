--!strict
--[[
	EmoteModal — bảng emote, dựng theo ĐÚNG khuôn danh sách của `TeleportModal`.

	══ VÌ SAO VIẾT LẠI (user 2026-09-05: "bật UI nào cũng phải giống nhau") ═════════════════

	Bản cũ nằm trong `Emotes/EmoteController` và lệch khỏi phần còn lại của HUD ở BỐN chỗ, mỗi
	chỗ một chút nên khó chỉ tên nhưng nhìn là thấy:

	    1. `Scale = 0.88` — cả bảng nhỏ hơn mọi modal khác 12%: thanh tiêu đề 74px thay vì 84,
	       nút X 58px thay vì 66. Không modal nào khác thu nhỏ như vậy (trừ Shop, có lý do riêng).
	    2. `MODAL_BORDER = 5` — con số bù cho cái `UIScale` kia. Bỏ scale thì viền quay về
	       `Tokens.BORDER` = 4 như 12 modal còn lại.
	    3. Lưới 3 cột thẻ vuông 268×164 — KHÔNG có modal nào khác dùng lưới; Teleport, Cosmetic,
	       Shop đều là danh sách HÀNG NGANG rộng 556 trong `ScrollingFrame`. Lưới cứng cũng có
	       trần: emote thứ 7 trở đi tràn khỏi bảng vì không cuộn được.
	    4. `Zoom` 1.07 thay vì `Tokens.HOVER_SCALE` (1.08) — nút emote nảy khác nhịp nút Teleport.

	Giờ dùng chung khuôn: 632×680 · caption y=98 · ScrollingFrame (24,136) 584×448 · hàng 556×110
	cách 12 · nút hành động 244×60 bo 12 viền 4 · Zoom 1.08 · nhãn nhận `zoom`. Danh sách cuộn
	nên thêm bao nhiêu emote cũng không phải sửa bố cục.

	══ MODAL SỐNG TRONG ScreenGui CHUNG CỦA HUD ═════════════════════════════════════════════
	Bản cũ tự dựng `ScreenGui` riêng (`DisplayOrder = 180`) — tức là nó nằm ở một tầng khác mọi
	modal, và có `UIScale` riêng đọc cùng `State.viewportScale`. Hai bản sao của cùng một thứ là
	hai chỗ để lệch. `HUDController` giờ gắn nó cạnh 11 modal kia.

	`EmoteController` giữ lại đúng phần việc của nó: nạp/dừng `AnimationTrack` và nghe packet.
	Dữ liệu "đã mở khoá món nào" chuyển sang `State.emoteUnlocked` (xem khối lý do ở `State`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Emotes = require(ReplicatedStorage.Shared.Config.Economy.Emotes)
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

local EmoteModal = {}

local PANEL_WIDTH = 632
local PANEL_HEIGHT = 680

-- Khuôn danh sách chuẩn — mọi con số chép từ `TeleportModal`, không tự nghĩ số mới.
local ROW_WIDTH = 556
local ROW_HEIGHT = 110
local ROW_GAP = 12
--[[
	⚠️ Một hàng chiếm `ROW_HEIGHT + 2×BORDER` chứ không phải `ROW_HEIGHT`: `MakeSurface` vẽ viền
	RA NGOÀI ô khai báo (xem `growForBorder` trong `Theme`). Đo trong Studio 2026-09-05: hàng khai
	110 nằm cách nhau 130px = 118 + 12. Quên 2×BORDER thì `CanvasSize` hụt và hàng cuối bị cụt
	một dải không cuộn tới được.
]]
local ROW_PITCH = ROW_HEIGHT + Tokens.BORDER * 2 + ROW_GAP

local ACTION_WIDTH = 244
local ACTION_HEIGHT = 60

local function isUnlocked(config: Emotes.EmoteConfig): boolean
	return State.emoteUnlocked:get()[config.id] == true
end

local function choose(config: Emotes.EmoteConfig)
	Manager.CloseEmote()
	GamePackets.requestEmoteAction.send({
		action = if isUnlocked(config) then "play" else "buy",
		emoteId = config.id,
	})
end

local function makeRow(config: Emotes.EmoteConfig, index: number)
	local hovered = Value(false)
	local owned = Computed(function()
		return isUnlocked(config)
	end)

	return Theme.MakeSurface({
		LayoutOrder = index,
		Size = UDim2.fromOffset(ROW_WIDTH, ROW_HEIGHT),
		ZIndex = Tokens.Z.MODAL_CONTENT + 2,
		Radius = 16,
		Border = Tokens.BORDER,
		-- Đã sở hữu = xanh lam, chưa = tím. Cùng cách phân biệt mà `CosmeticModal` dùng cho
		-- thẻ trail/aura, nên hai bảng "đồ trang trí" đọc giống nhau.
		Color = Computed(function()
			return if owned:get() then Color3.fromRGB(58, 74, 132) else Color3.fromRGB(66, 43, 116)
		end),
		ColorB = Computed(function()
			return if owned:get() then Color3.fromRGB(32, 44, 90) else Color3.fromRGB(42, 26, 82)
		end),
		Content = {
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Emotes,
				Position = UDim2.fromOffset(12, 25),
				Size = UDim2.fromOffset(60, 60),
				ZIndex = Tokens.Z.MODAL_CONTENT + 4,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(82, 16),
				Size = UDim2.fromOffset(210, 42),
				Text = config.displayName,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 30,
				ZIndex = Tokens.Z.MODAL_CONTENT + 4,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(84, 58),
				Size = UDim2.fromOffset(208, 30),
				Text = Computed(function()
					return if owned:get() then "Owned • tap to play" else "Locked"
				end),
				TextColor3 = Color3.fromRGB(255, 240, 130),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 20,
				ZIndex = Tokens.Z.MODAL_CONTENT + 4,
			}),
			--[[
				Nút hành động: xanh lá "PLAY" khi đã sở hữu, vàng-cam kèm icon cúp + giá khi chưa.
				Cùng bộ màu và cùng số đo (244×60, bo 12, viền 4) với nút mua của Teleport.
			]]
			Theme.MakeSurface({
				ClassName = "TextButton",
				Position = UDim2.fromOffset(300, (ROW_HEIGHT - ACTION_HEIGHT) // 2),
				Size = UDim2.fromOffset(ACTION_WIDTH, ACTION_HEIGHT),
				ZIndex = Tokens.Z.MODAL_CONTENT + 5,
				Radius = 12,
				Border = Tokens.BORDER,
				Color = Computed(function()
					return if owned:get() then Color3.fromRGB(120, 240, 80) else Color3.fromRGB(255, 196, 56)
				end),
				ColorB = Computed(function()
					return if owned:get() then Color3.fromRGB(40, 160, 36) else Color3.fromRGB(230, 122, 20)
				end),
				GradientRotation = 0,
				Zoom = { Hovered = hovered, Scale = Tokens.HOVER_SCALE },
				Activated = function()
					choose(config)
				end,
				MouseEnter = function()
					hovered:set(true)
				end,
				MouseLeave = function()
					hovered:set(false)
				end,
				Content = function(zoom)
					return {
						New("ImageLabel")({
							BackgroundTransparency = 1,
							Image = Theme.UI_ASSETS.Trophy,
							Position = UDim2.fromOffset(36, 14),
							Size = UDim2.fromOffset(32, 32),
							Visible = Computed(function()
								return not owned:get()
							end),
							ZIndex = Tokens.Z.MODAL_CONTENT + 7,
						}),
						Theme.MakeOutlineLabel({
							--[[
								Có icon cúp thì nhãn lùi sang phải và căn TRÁI; không có thì nó
								chiếm trọn nút và căn GIỮA. Đúng cách `EmoteController` cũ làm —
								chỗ đó vốn không sai, chỉ là số đo quanh nó mới sai.
							]]
							Position = Computed(function()
								return if owned:get() then UDim2.fromOffset(0, 6) else UDim2.fromOffset(76, 6)
							end),
							Size = Computed(function()
								return if owned:get()
									then UDim2.fromOffset(ACTION_WIDTH, 48)
									else UDim2.fromOffset(148, 48)
							end),
							Text = Computed(function()
								return if owned:get() then "PLAY" else Theme.FormatInteger(config.priceWins)
							end),
							TextXAlignment = Computed(function()
								return if owned:get() then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
							end),
							Zoom = zoom,
							TextColor3 = Color3.new(1, 1, 1),
							MaxTextSize = 30,
							MinTextSize = 12,
							ZIndex = Tokens.Z.MODAL_CONTENT + 7,
						}),
					}
				end,
			}),
		},
	})
end

local function buildList()
	local rows: { any } = {
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
	for index, config in Emotes.CATALOG do
		table.insert(rows, makeRow(config, index))
	end

	return New("ScrollingFrame")({
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		-- Hàng cuối không có khe sau nó, nên trừ một `ROW_GAP`; `+12` là hai lề `UIPadding`.
		-- Đo 2026-09-05: nội dung thật 649,7px — canvas phải là 650, không phải 662.
		CanvasSize = UDim2.fromOffset(0, #Emotes.CATALOG * ROW_PITCH - ROW_GAP + 12),
		Position = UDim2.fromOffset(24, 136),
		ScrollBarImageColor3 = Color3.fromRGB(200, 222, 255),
		ScrollBarThickness = 10,
		--[[
			428 chứ không phải 448: nút STOP bắt đầu ở y=596, và ở 448 thì đáy danh sách (584) chỉ
			cách nút 12px — hàng bị cắt dở nằm DÍNH vào nút, đọc như nút đang đè lên danh sách
			(đo bằng ảnh chụp Studio 2026-09-05). 428 cho ra khe 32px, đủ để mắt tách hai khối.

			Hàng cuối cùng vẫn cố ý ló ra một phần: đó là tín hiệu "còn nữa, cuộn xuống đi".
		]]
		Size = UDim2.fromOffset(584, 428),
		ZIndex = Tokens.Z.MODAL_CONTENT,
		[Children] = rows,
	})
end

--[[
	Nút STOP EMOTE nằm dưới danh sách, rộng gần trọn bảng — đúng chỗ và đúng khuôn nút hành động
	chính của `DailyModal` ("CLAIM DAY N": 66px cao, bo 16, viền 4, `Zoom` 1.08). Nó là hành động
	một-lần của cả bảng chứ không thuộc về hàng nào, nên không được trông giống nút của một hàng.
]]
local function buildStopButton()
	local hovered = Value(false)

	return Theme.MakeSurface({
		ClassName = "TextButton",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(PANEL_WIDTH // 2, 596),
		Size = UDim2.fromOffset(556, 66),
		ZIndex = Tokens.Z.MODAL_CONTENT + 2,
		Radius = 16,
		Border = Tokens.BORDER,
		Color = Color3.fromRGB(255, 104, 126),
		ColorB = Color3.fromRGB(196, 34, 70),
		Zoom = { Hovered = hovered, Scale = Tokens.HOVER_SCALE },
		Activated = function()
			Manager.CloseEmote()
			GamePackets.requestEmoteAction.send({ action = "stop", emoteId = "" })
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
					Size = UDim2.fromScale(1, 1),
					Text = "STOP EMOTE",
					Zoom = zoom,
					TextColor3 = Color3.new(1, 1, 1),
					MaxTextSize = 34,
					ZIndex = Tokens.Z.MODAL_CONTENT + 4,
				}),
			}
		end,
	})
end

function EmoteModal.Build()
	return ModalShell.Build({
		Id = "emote",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(28, 17, 62),
		HeaderColor = Color3.fromRGB(186, 90, 255),
		HeaderColorB = Color3.fromRGB(100, 50, 210),
		Icon = Theme.UI_ASSETS.Emotes,
		Title = "Emotes",
		TitleMaxTextSize = 50,
		OnClose = Manager.CloseEmote,
		Content = {
			-- Caption y=98, cùng vị trí với Quest/Shop/Roulette.
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(26, 98),
				Size = UDim2.fromOffset(300, 34),
				Text = "CHOOSE A MOVE",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(255, 226, 95),
				MaxTextSize = 26,
				ZIndex = Tokens.Z.MODAL_CONTENT,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(334, 98),
				Size = UDim2.fromOffset(272, 34),
				Text = "PRESS G  •  MOVING STOPS IT",
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Color3.fromRGB(200, 187, 255),
				MaxTextSize = 19,
				ZIndex = Tokens.Z.MODAL_CONTENT,
			}),
			buildList(),
			buildStopButton(),
		},
	})
end

return EmoteModal
