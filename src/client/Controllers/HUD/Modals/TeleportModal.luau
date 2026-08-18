--!strict
-- Modal Teleport: danh sách dọc từng hàng, CHỈ thanh toán bằng Wins.
--
-- 2026-08-07 (yêu cầu user): gỡ hẳn nút mua bằng Robux. Teleport là tiện ích rút ngắn
-- đường đi, không phải món kiếm tiền — bán bằng Robux làm loãng giá trị của Wins (thứ
-- người chơi cày cả buổi để có). Nút Wins nở rộng lấp chỗ trống của nút cũ.
-- Đường mua bằng Robux phía server (product) vẫn còn nguyên, chỉ là UI không gọi tới.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

local TeleportModal = {}

local PANEL_WIDTH = 632
local PANEL_HEIGHT = 680

type DestinationConfig = State.TeleportDestinationConfig

local function isDestinationVisible(destination: DestinationConfig): boolean
	return destination.targetPath ~= ""
end

--[[
	VIP Membership teleport miễn phí — CHỈ trong phạm vi đã từng đến (2026-08-12).

	Luật này phải khớp CHÍNH XÁC `TeleportService.tryPayWins`, nếu không UI và server nói hai
	điều khác nhau: hoặc hàng hiện "FREE" rồi server vẫn trừ Wins, hoặc UI chặn "không đủ Wins"
	trong khi server sẵn sàng cho đi miễn phí. Xem khối lý do dài ở phía server để hiểu vì sao
	miễn phí KHÔNG được phủ mọi stage.

	Nhận diện VIP qua `vipMultiplier` trong snapshot (server gửi 1.5 khi sở hữu pass) — không
	có cờ boolean riêng, và cũng không cần: đó là con số server đã tính, client chỉ đọc.
]]
local function stageNumberOf(destination: DestinationConfig): number?
	local text = destination.id:match("^stage_(%d+)$")
	return if text then tonumber(text) else nil
end

local function isFreeForVip(destination: DestinationConfig): boolean
	local snapshot = State.GetSnapshot()
	if snapshot.vipMultiplier <= 1 then
		return false
	end
	local stage = stageNumberOf(destination)
	return stage == nil or stage <= snapshot.highestCompletedStage + 1
end

local function requestWithWins(destination: DestinationConfig): boolean
	if not isFreeForVip(destination) and State.GetSnapshot().totalWins < destination.priceWins then
		Toast.Show("Not enough Wins")
		return false
	end

	GamePackets.requestTeleport.send({
		destinationId = destination.id,
		paymentKind = "wins",
	})
	return true
end

local function makeRow(destination: DestinationConfig)
	local colorA = destination.accentColor
	local colorB = colorA:Lerp(Color3.fromRGB(20, 30, 70), 0.5)
	local winsHovered = Value(false)

	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		LayoutOrder = destination.sortOrder,
		Size = UDim2.fromOffset(556, 98),
		ZIndex = 44,
		[Children] = {
			Theme.MakeCorner(16),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			Theme.MakeStandardStuds(16, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Teleport,
				Position = UDim2.fromOffset(12, 19),
				Size = UDim2.fromOffset(60, 60),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(82, 12),
				Size = UDim2.fromOffset(210, 44),
				Text = destination.name,
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 30,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(84, 56),
				Size = UDim2.fromOffset(208, 30),
				Text = destination.description,
				TextColor3 = Color3.fromRGB(255, 240, 130),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 20,
				ZIndex = 46,
			}),
			-- Nút Wins (xanh lá) — nút mua DUY NHẤT, nở rộng lấp chỗ nút Robux cũ.
			-- `MakeSurface` + `Zoom`: viền và chữ phóng cùng nhịp, nở đều 4 góc.
			Theme.MakeSurface({
				ClassName = "TextButton",
				Position = UDim2.fromOffset(300, 19),
				Size = UDim2.fromOffset(244, 60),
				ZIndex = 47,
				Radius = 12,
				Border = 4,
				Color = Color3.fromRGB(120, 240, 80),
				ColorB = Color3.fromRGB(40, 160, 36),
				GradientRotation = 0,
				Zoom = { Hovered = winsHovered, Scale = 1.08 },
				Activated = function()
					if requestWithWins(destination) then
						Manager.CloseTeleport()
					end
				end,
				MouseEnter = function()
					winsHovered:set(true)
				end,
				MouseLeave = function()
					winsHovered:set(false)
				end,
				Content = function(zoom)
					return {
						New("ImageLabel")({
							BackgroundTransparency = 1,
							Image = Theme.UI_ASSETS.Trophy,
							Position = UDim2.fromOffset(36, 14),
							Size = UDim2.fromOffset(32, 32),
							ZIndex = 49,
						}),
						Theme.MakeOutlineLabel({
							Position = UDim2.fromOffset(76, 6),
							Size = UDim2.fromOffset(148, 48),
							-- Computed chứ không phải chuỗi tĩnh: mua VIP giữa session thì mọi hàng
							-- phải đổi sang "FREE" ngay, không đợi đóng mở lại modal.
							Text = Computed(function()
								if destination.priceWins <= 0 or isFreeForVip(destination) then
									return "FREE"
								end
								return Theme.FormatInteger(destination.priceWins)
							end),
							TextXAlignment = Enum.TextXAlignment.Center,
							Zoom = zoom,
							MaxTextSize = 30,
							MinTextSize = 12,
							ZIndex = 49,
						}),
					}
				end,
			}),
		},
	})
end

local function buildList()
	local rows = {}
	local visibleCount = 0
	for _, destination in Constants.TELEPORT_DESTINATIONS do
		if isDestinationVisible(destination) then
			visibleCount += 1
			table.insert(rows, makeRow(destination))
		end
	end
	table.insert(
		rows,
		New("UIListLayout")({
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	)
	table.insert(
		rows,
		New("UIPadding")({
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		})
	)

	return New("ScrollingFrame")({
		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, visibleCount * 110 + 12),
		Position = UDim2.fromOffset(24, 110),
		ScrollBarImageColor3 = Color3.fromRGB(200, 222, 255),
		ScrollBarThickness = 10,
		Size = UDim2.fromOffset(584, 552),
		ZIndex = 44,
		[Children] = rows,
	})
end

function TeleportModal.Build()
	return ModalShell.Build({
		Id = "teleport",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(12, 35, 90),
		HeaderColor = Color3.fromRGB(94, 182, 255),
		HeaderColorB = Color3.fromRGB(28, 108, 226),
		Icon = Theme.UI_ASSETS.Teleport,
		Title = "Teleport",
		TitleMaxTextSize = 50,
		OnClose = Manager.CloseTeleport,
		Content = { buildList() },
	})
end

return TeleportModal
