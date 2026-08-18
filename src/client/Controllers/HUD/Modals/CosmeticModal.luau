--!strict
-- Modal Cosmetic: tab Trails / Auras, danh sách dọc từng hàng, mua/trang bị bằng Wins.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

local CosmeticModal = {}

local PANEL_WIDTH = 632
local PANEL_HEIGHT = 680

local TRAIL_COLORS = {
	{ Color3.fromRGB(84, 224, 113), Color3.fromRGB(27, 133, 75) },
	{ Color3.fromRGB(84, 176, 255), Color3.fromRGB(45, 86, 203) },
	{ Color3.fromRGB(183, 98, 255), Color3.fromRGB(101, 49, 196) },
	{ Color3.fromRGB(255, 91, 91), Color3.fromRGB(185, 31, 48) },
	{ Color3.fromRGB(255, 201, 75), Color3.fromRGB(210, 61, 157) },
	{ Color3.fromRGB(108, 76, 255), Color3.fromRGB(32, 22, 102) },
}

local AURA_COLORS = {
	{ Color3.fromRGB(255, 223, 92), Color3.fromRGB(221, 118, 34) },
	{ Color3.fromRGB(255, 104, 64), Color3.fromRGB(179, 30, 31) },
	{ Color3.fromRGB(92, 205, 255), Color3.fromRGB(52, 84, 211) },
	{ Color3.fromRGB(153, 93, 255), Color3.fromRGB(55, 23, 126) },
	{ Color3.fromRGB(255, 100, 212), Color3.fromRGB(68, 49, 178) },
}

local function getCardColors(category: string, index: number): (Color3, Color3)
	local colors = if category == "trail" then TRAIL_COLORS else AURA_COLORS
	local selected = colors[(index - 1) % #colors + 1]
	return selected[1], selected[2]
end

--[[
	Số đo của bốn ô hành động bên phải mỗi hàng. Cả bốn DÙNG CHUNG bề rộng và bo góc — đó là
	điều kiện để hàng nào cũng nhìn như hàng nào, bất kể món đó bán bằng Wins, bằng Robux, hay
	không bán được. Ô Equip cao gấp đôi vì nó chiếm chỗ của cả hai ô mua khi món đã sở hữu.
]]
local SLOT_WIDTH = 164
local SLOT_HEIGHT = 50
local EQUIP_HEIGHT = 116
local SLOT_RADIUS = 10
local SLOT_BORDER = 4

--[[
	Hàng ngang căn giữa trong lòng một ô (icon + số tiền).

	`AutomaticSize.X` trên khung bọc + `UIListLayout` ngang: cụm tự co đúng bề rộng nội dung rồi
	tự căn giữa, nên số tiền dài ngắn khác nhau (99 vs 1.25M) vẫn luôn nằm giữa ô.
]]
local function makeSlotRow(items: { any })
	local children: { any } = {
		New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for _, item in items do
		table.insert(children, item)
	end
	return New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 48,
		[Children] = children,
	})
end

local function makeRow(category: string, config: any, index: number)
	local colorA, colorB = getCardColors(category, index)
	-- Ảnh riêng của từng món (Trails.luau / Auras.luau). Món chưa có ảnh riêng (Frozen Bloom
	-- và 3 aura premium) rơi về icon chung để không bao giờ hiện ô trống.
	local fallbackIcon = if category == "trail" then Theme.UI_ASSETS.Trail else Theme.UI_ASSETS.Aura
	local icon: string = config.icon or fallbackIcon
	local btnWinsHovered = Value(false)
	local btnRobuxHovered = Value(false)
	local btnEquipHovered = Value(false)

	-- Bốn ô hành động đều hỏi đúng một câu này, nên hỏi một chỗ. Trước đây mỗi ô tự viết lại
	-- cùng ba dòng tra `unlockedTrails`/`unlockedAuras` — sửa luật sở hữu là phải sửa bốn chỗ.
	local function isUnlocked(): boolean
		local state = State.GetSnapshot()
		local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
		return unlocked[config.id] == true
	end

	local gamepassId: number = config.gamepassId or 0
	local robuxOnly: boolean = config.robuxOnly == true
	-- Món chỉ rơi từ Speed Roulette (Frozen Bloom): không có đường mua nào. Trước đây nó
	-- vẫn hiện nút Wins với giá 999.00M — con số chốt chặn của server bị lộ ra UI, người
	-- chơi tưởng là món cày được. Giờ ẩn cả hai nút, thay bằng nhãn "SPIN ONLY".
	local spinOnly: boolean = config.spinOnly == true
	-- Món chỉ rơi từ chuỗi điểm danh 7 ngày (Streak Aurora). Cùng cái bẫy như spinOnly
	-- nhưng ngược dấu: `priceWins = 0` nên nút Wins hiện ra là "🏆 0", trông y như hàng
	-- FREE — bấm vào thì server im lặng từ chối. Ẩn nút, thay bằng nhãn nguồn gốc.
	-- Vẫn CỐ Ý hiện món này trong danh sách dù chưa sở hữu: nó quảng cáo cho chuỗi điểm danh.
	local dailyOnly: boolean = config.dailyOnly == true
	--[[
		Nhãn NGUỒN GỐC của món không bán được.

		⚠️ `dailyOnly` KHÔNG đồng nghĩa với "chuỗi điểm danh 7 ngày" — nó chỉ có nghĩa "không
		bán bằng Wins lẫn Robux, chỉ được trao" (xem ProgressionService). Rookie Rocket dùng
		chung cờ đó nhưng đến từ Starter Pack, nên bản trước dán cho nó nhãn "DAY 7 STREAK" —
		chỉ sai người chơi đi cày một chuỗi bảy ngày để lấy món chỉ bán trong gói 99 R$.
		Món nào có nguồn riêng thì tự khai `sourceLabel`/`sourceIcon` trong config của nó.
	]]
	local lockedBadgeText = config.sourceLabel or (if dailyOnly then "DAY 7 STREAK" else "SPIN ONLY")
	local lockedBadgeIcon = config.sourceIcon or (if dailyOnly then Theme.UI_ASSETS.Daily else Theme.UI_ASSETS.Spin)

	-- Giá Robux hiển thị phải là giá THEO VÙNG của người đang xem. Trong lúc chờ fetch
	-- (hoặc khi chưa điền gamepassId) hiện tạm giá config — không bao giờ hiện "SOON".
	local fallbackPrice: number? = if (config.priceRobux or 0) > 0 then config.priceRobux else nil
	local robuxText = Value(RobuxPrice.FormatPrefixed(fallbackPrice))
	if gamepassId > 0 then
		task.spawn(function()
			local price = RobuxPrice.GetAsync(gamepassId)
			if price then
				robuxText:set(RobuxPrice.FormatPrefixed(price))
			end
		end)
	end
	-- Trạng thái nút: equipped / owned / locked
	local statusColorA = Computed(function()
		local state = State.GetSnapshot()
		local equippedId = if category == "trail" then state.equippedTrail else state.equippedAura
		local unlocked = if category == "trail" then state.unlockedTrails else state.unlockedAuras
		if equippedId == config.id then
			return Color3.fromRGB(78, 212, 80)
		end
		return if unlocked[config.id] then Color3.fromRGB(71, 172, 255) else Color3.fromRGB(255, 196, 56)
	end)

	return Theme.MakeSurface({
		LayoutOrder = index,
		Size = UDim2.fromOffset(556, 150),
		ZIndex = 44,
		Radius = 18,
		Border = 4,
		Color = colorA,
		ColorB = colorB,
		Content = {
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(16, 19),
				Size = UDim2.fromOffset(100, 100),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(130, 26),
				Size = UDim2.fromOffset(238, 44),
				Text = config.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 32,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(132, 76),
				Size = UDim2.fromOffset(236, 36),
				Text = `x{string.format("%.2f", config.multiplier)} Speed`,
				TextColor3 = Color3.fromRGB(255, 239, 112),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 26,
				ZIndex = 46,
			}),
			--[[
				Container nút bên phải — MỖI Ô LÀ MỘT `MakeSurface`, KHÔNG dựng tay nữa.

				── LỖI ĐÃ SỬA 2026-08-16: "ô đen che mất nút" ────────────────────────────────
				Bốn ô này trước đây mỗi cái là một `Frame` ĐEN bọc ngoài + một nút bên trong, và
				`Visible` chỉ đặt trên NÚT BÊN TRONG. Nút ẩn đi thì cái khung đen vẫn vẽ nguyên —
				đó chính là mấy hình chữ nhật đen user chụp lại. Tệ hơn: khung đen vẫn CHIẾM CHỖ
				trong `UIListLayout`, nên ô 116px cao phải chứa tới 4 khung (58+58+58+124) và mọi
				thứ bị đè lên nhau, thẻ trông như bị cắt cụt.

				`MakeSurface` đặt `Visible` lên khung NGOÀI nên ẩn là ẩn cả cụm và nhường luôn chỗ
				trong layout. Nó cũng dựng đúng cấu trúc viền-là-khối-hình-học mà cả HUD đang dùng
				(outer đen bo góc Radius+Border, fill màu thụt vào Border) — tức là bốn khối viết
				tay kia vốn đã là `MakeSurface` chép lại bằng tay, chỉ khác là chép thiếu `Visible`.

				`Outside = { HoverZoom }` chứ không nhét vào trong: `UIScale` phải nằm ở lớp ngoài
				để phóng cả viền lẫn ruột như một khối. Bản cũ nhét vào trong nên khi rê chuột chỉ
				ruột màu phình ra còn viền đen đứng yên.
			]]
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(372, 17),
				Size = UDim2.fromOffset(164, 116),
				ZIndex = 46,
				[Children] = {
					-- Căn giữa theo chiều dọc: hàng Standard có 2 ô xếp chồng lấp đầy, còn hàng
					-- Robux-only / Spin-only chỉ còn 1 ô CÙNG CỠ nên phải canh giữa.
					New("UIListLayout")({
						Padding = UDim.new(0, 16),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),

					-- ── Ô 1: mua bằng Wins ────────────────────────────────────────────────
					Theme.MakeSurface({
						ClassName = "TextButton",
						LayoutOrder = 1,
						Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT),
						ZIndex = 46,
						Radius = SLOT_RADIUS,
						Border = SLOT_BORDER,
						Color = Color3.fromRGB(110, 240, 130),
						ColorB = Color3.fromRGB(34, 162, 64),
						Visible = Computed(function()
							-- Món Robux-only / Spin-only không có đường mua bằng Wins.
							if robuxOnly or spinOnly or dailyOnly then
								return false
							end
							return not isUnlocked()
						end),
						Activated = function()
							local state = State.GetSnapshot()
							if state.totalWins < config.priceWins then
								Toast.Show("Not enough Wins")
								return
							end
							GamePackets.requestCosmeticAction.send({
								category = category,
								itemId = config.id,
							})
						end,
						MouseEnter = function()
							btnWinsHovered:set(true)
						end,
						MouseLeave = function()
							btnWinsHovered:set(false)
						end,
						Zoom = { Hovered = btnWinsHovered, Scale = 1.08 },
						Content = {
							makeSlotRow({
								New("ImageLabel")({
									BackgroundTransparency = 1,
									Image = Theme.UI_ASSETS.Trophy,
									LayoutOrder = 1,
									Size = UDim2.fromOffset(26, 26),
									ZIndex = 49,
								}),
								Theme.MakeOutlineLabel({
									AutomaticSize = Enum.AutomaticSize.X,
									LayoutOrder = 2,
									Position = UDim2.fromScale(0, 0),
									Size = UDim2.fromOffset(0, 46),
									Text = Theme.FormatInteger(config.priceWins),
									MaxTextSize = 22,
									ZIndex = 49,
								}),
							}),
						},
					}),

					-- ── Ô 2: mua bằng Robux ───────────────────────────────────────────────
					Theme.MakeSurface({
						ClassName = "TextButton",
						LayoutOrder = 2,
						Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT),
						ZIndex = 46,
						Radius = SLOT_RADIUS,
						Border = SLOT_BORDER,
						Color = Color3.fromRGB(255, 150, 214),
						ColorB = Color3.fromRGB(236, 64, 156),
						Visible = Computed(function()
							return not isUnlocked() and (gamepassId > 0 or robuxOnly)
						end),
						Activated = function()
							if gamepassId <= 0 then
								Toast.Show("Coming soon!")
								return
							end
							MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, gamepassId)
						end,
						MouseEnter = function()
							btnRobuxHovered:set(true)
						end,
						MouseLeave = function()
							btnRobuxHovered:set(false)
						end,
						Zoom = { Hovered = btnRobuxHovered, Scale = 1.08 },
						Content = {
							makeSlotRow({
								Theme.MakeOutlineLabel({
									AutomaticSize = Enum.AutomaticSize.X,
									LayoutOrder = 2,
									Position = UDim2.fromScale(0, 0),
									Size = UDim2.fromOffset(0, 46),
									Text = robuxText,
									MaxTextSize = 22,
									ZIndex = 49,
								}),
							}),
						},
					}),

					-- ── Ô 3: nhãn nguồn gốc (SPIN ONLY / DAY 7 STREAK) ────────────────────
					-- Không phải nút: món này không có đường mua nào cả.
					Theme.MakeSurface({
						LayoutOrder = 2,
						Size = UDim2.fromOffset(SLOT_WIDTH, SLOT_HEIGHT),
						ZIndex = 46,
						Radius = SLOT_RADIUS,
						Border = SLOT_BORDER,
						Color = Color3.fromRGB(168, 128, 255),
						ColorB = Color3.fromRGB(96, 48, 200),
						Visible = Computed(function()
							return (spinOnly or dailyOnly) and not isUnlocked()
						end),
						Content = {
							New("ImageLabel")({
								BackgroundTransparency = 1,
								Image = lockedBadgeIcon,
								Position = UDim2.fromOffset(8, 9),
								Size = UDim2.fromOffset(32, 32),
								ZIndex = 48,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(44, 8),
								Size = UDim2.fromOffset(112, 34),
								Text = lockedBadgeText,
								MaxTextSize = 22,
								ZIndex = 48,
							}),
						},
					}),

					-- ── Ô 4: Equip / Equipped (khi đã sở hữu) ─────────────────────────────
					Theme.MakeSurface({
						ClassName = "TextButton",
						LayoutOrder = 3,
						Size = UDim2.fromOffset(SLOT_WIDTH, EQUIP_HEIGHT),
						ZIndex = 46,
						Radius = SLOT_RADIUS + 4, -- ô cao gấp đôi nên bo góc rộng hơn một nhịp
						Border = SLOT_BORDER,
						-- Ô này CỐ Ý không có studs: nó là ô trạng thái, để trơn cho tách khỏi
						-- hai ô "mua" phía trên.
						Studs = false,
						Color = statusColorA,
						ColorB = Computed(function()
							return statusColorA:get():Lerp(Color3.fromRGB(0, 0, 0), 0.32)
						end),
						Visible = Computed(function()
							return isUnlocked()
						end),
						Activated = function()
							GamePackets.requestCosmeticAction.send({
								category = category,
								itemId = config.id,
							})
						end,
						MouseEnter = function()
							btnEquipHovered:set(true)
						end,
						MouseLeave = function()
							btnEquipHovered:set(false)
						end,
						Zoom = { Hovered = btnEquipHovered, Scale = 1.08 },
						Content = {
							Theme.MakeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = Computed(function()
									local state = State.GetSnapshot()
									local equippedId = if category == "trail"
										then state.equippedTrail
										else state.equippedAura
									return if equippedId == config.id then "EQUIPPED" else "EQUIP"
								end),
								MaxTextSize = 28,
								MinTextSize = 12,
								ZIndex = 49,
							}),
						},
					}),
				},
			}),
		},
	})
end

--[[
	Xếp thẻ theo SỨC MẠNH TĂNG DẦN, yếu nhất trên cùng (2026-08-09, user chốt).

	Thứ tự trong `Config/Economy/Trails.luau` và `Auras.luau` là thứ tự NHÓM (standard trước,
	premium sau), không phải thứ tự sức mạnh — nên bảng cũ nhảy lung tung: Pink x8 → Frozen
	Bloom x3.5 → Red Heart x25 → Flame x18 → Dark x12. Người chơi không đọc ra được cái nào
	mạnh hơn cái nào, mà đó chính là câu hỏi duy nhất họ đang có khi mở bảng này.

	Sắp ở TẦNG UI chứ không sắp lại file config: config còn mang ý nghĩa khác (comment nhóm,
	`id` khớp tên Folder trong AuraBase), và sắp ở đây thì thêm món mới vào bất kỳ chỗ nào
	trong config cũng tự vào đúng vị trí.

	`table.sort` KHÔNG ổn định, nên khi hai món trùng multiplier phải có khoá phụ (`name`) —
	nếu không thứ tự hai thẻ đó có thể đổi chỗ giữa các lần mở bảng.
]]
local function sortedByPower(catalog: { any }): { any }
	local ordered = table.clone(catalog)
	table.sort(ordered, function(a, b)
		local ma, mb = a.multiplier or 0, b.multiplier or 0
		if ma ~= mb then
			return ma < mb
		end
		return tostring(a.name) < tostring(b.name)
	end)
	return ordered
end

local function makeCatalog(category: string, catalog: { any })
	local cards = {}
	for index, config in sortedByPower(catalog) do
		table.insert(cards, makeRow(category, config, index))
	end
	table.insert(
		cards,
		New("UIListLayout")({
			Padding = UDim.new(0, 14),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	)
	table.insert(
		cards,
		New("UIPadding")({
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		})
	)

	return New("ScrollingFrame")({
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		--[[
			Chiều cao canvas phải tính theo chiều cao NGOÀI của thẻ, không phải chiều cao khai báo.
			Thẻ khai 150 nhưng `MakeSurface` vẽ viền ra ngoài nên nó chiếm 150 + 2×4 = 158, cộng
			khe 14 của `UIListLayout` thành 172 mỗi hàng. Con số cũ (164) thiếu 8px mỗi hàng, nên
			hàng cuối bị kẹt một phần dưới đáy khung và cuộn mãi không tới.
		]]
		CanvasSize = UDim2.fromOffset(0, #catalog * (150 + SLOT_BORDER * 2 + 14) + 12),
		Position = UDim2.fromOffset(24, 188),
		ScrollBarImageColor3 = Color3.fromRGB(236, 206, 255),
		ScrollBarThickness = 10,
		Size = UDim2.fromOffset(584, 470),
		Visible = Computed(function()
			return State.cosmeticCategory:get() == category
		end),
		ZIndex = 44,
		[Children] = cards,
	})
end

local function makeTab(category: string, label: string, position: UDim2, colorA: Color3, colorB: Color3)
	local hovered = Value(false)
	--[[
		Tab TRAILS / AURAS. Đổi từ `UIStroke` sang `MakeSurface` cùng đợt gom 2026-08-16: viền
		giờ là khối hình học (bốn cạnh dày bằng nhau tuyệt đối), và `Zoom` lo phần rê chuột —
		nở đều 4 góc, viền và chữ phóng cùng nhịp.

		Khai lệch +4 so với `position` để mép ngoài viền vẫn rơi đúng chỗ cũ.
	]]
	return Theme.MakeSurface({
		ClassName = "TextButton",
		Position = position + UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(278, 58),
		ZIndex = 45,
		Radius = 14,
		Border = 4,
		Color = Computed(function()
			return if State.cosmeticCategory:get() == category then colorA else Color3.fromRGB(96, 64, 132)
		end),
		ColorB = Computed(function()
			return if State.cosmeticCategory:get() == category then colorB else Color3.fromRGB(56, 34, 82)
		end),
		Zoom = { Hovered = hovered, Scale = 1.08 },
		Activated = function()
			State.cosmeticCategory:set(category)
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
					Text = label,
					Zoom = zoom,
					MaxTextSize = 32,
					MinTextSize = 14,
					ZIndex = 47,
				}),
			}
		end,
	})
end

function CosmeticModal.Build()
	return ModalShell.Build({
		Id = "cosmetic",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(30, 0, 40),
		HeaderColor = Color3.fromRGB(202, 124, 255),
		HeaderColorB = Color3.fromRGB(138, 46, 226),
		Icon = Theme.UI_ASSETS.Trail,
		Title = "Cosmetics",
		TitleMaxTextSize = 50,
		OnClose = Manager.CloseCosmetic,
		Content = {
			makeTab(
				"trail",
				"TRAILS",
				UDim2.fromOffset(24, 106),
				Color3.fromRGB(177, 106, 255),
				Color3.fromRGB(94, 55, 196)
			),
			makeTab(
				"aura",
				"AURAS",
				UDim2.fromOffset(322, 106),
				Color3.fromRGB(255, 104, 79),
				Color3.fromRGB(184, 36, 47)
			),
			makeCatalog("trail", Constants.TRAILS),
			makeCatalog("aura", Constants.AURAS),
		},
	})
end

return CosmeticModal
