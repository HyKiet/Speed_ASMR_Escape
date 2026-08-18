--!strict
--[[
	ReviveModal.luau — nút Revive gọn, sát mép trên màn hình. Hiện khi Humanoid.Died ở Stage 2-15.

	v2 (2026-07-28) — DỰNG LẠI ĐƠN GIẢN theo ảnh tham chiếu của user:
	chỉ còn MỘT nút xanh lá + tim đỏ + chữ "Revive" trắng viền đen, kèm badge giá Robux nhô
	ở góc trên-trái. Bản cũ có nguyên một panel tím chứa vòng đếm ngược + dòng
	"REVIVE? (Stage 15)" + nút — ba khối chữ cho một hành động duy nhất.

	Có gamepass Infinite Revives ⇒ ẩn badge giá, bấm là hồi sinh miễn phí (server tự duyệt
	lại quyền sở hữu — xem StageCheckpointService).

	Vẫn dùng Frame thường chứ không CanvasGroup: CanvasGroup làm Roblox render xỉn màu UI.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

local localPlayer = Players.LocalPlayer

local ReviveModal = {}

local BUTTON_WIDTH = 250
local BUTTON_HEIGHT = 76

-- Thanh đếm ngược nằm TRONG nút, sát đáy (nút đã ClipsDescendants nên bo góc tự cắt).
local TIMER_BAR_HEIGHT = 9
local TIMER_BAR_INSET = 8

-- Thanh chuyển màu theo thời gian còn lại: còn nhiều = vàng, sắp hết = đỏ.
local TIMER_COLOR_FULL = Color3.fromRGB(255, 224, 82)
local TIMER_COLOR_LOW = Color3.fromRGB(255, 72, 72)

-- Một nút cho hai đường: có gamepass thì hồi sinh MIỄN PHÍ, không thì mở prompt mua Robux.
local function onReviveClicked()
	if State.reviveFree:get() then
		GamePackets.requestRevive.send({ method = "free" })
		return
	end
	local productId = State.reviveRobuxProductId:get()
	if productId <= 0 then
		Toast.Show("Set revive product id before purchase", "revive")
		return
	end
	MarketplaceService:PromptProductPurchase(localPlayer, productId)
end

function ReviveModal.Build()
	local hovered = Value(false)

	return New("ScreenGui")({
		Name = "SpeedEscapeRevive",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 160,
		Parent = localPlayer:WaitForChild("PlayerGui"),
		[Children] = {
			-- Container KHÔNG clip để badge giá tràn được ra ngoài mép nút.
			New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Visible = State.reviveModalMounted,
				-- Neo theo TỈ LỆ màn hình: 3% từ mép trên, trượt nhẹ khi mở.
				Position = Computed(function()
					return UDim2.fromScale(0.5, 0.03 + 0.012 * (1 - State.reviveModalAnimation:get()))
				end),
				Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT),
				ZIndex = 151,
				[Children] = {
					New("UIScale")({ Scale = State.viewportScale }),

					-- Nút Revive: `MakeSurface` + `Zoom` — viền và chữ phóng cùng nhịp, nở đều 4 góc.
					Theme.MakeSurface({
						ClassName = "TextButton",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 152,
						Radius = 16,
						Border = 4,
						Color = Color3.fromRGB(134, 240, 108),
						ColorB = Color3.fromRGB(38, 158, 48),
						GradientRotation = 0,
						Zoom = { Hovered = hovered, Scale = 1.06 },
						Activated = onReviveClicked,
						MouseEnter = function()
							hovered:set(true)
						end,
						MouseLeave = function()
							hovered:set(false)
						end,
						Content = function(zoom)
							return {
								-- Tim đỏ: dùng emoji (Roblox render màu sẵn) — không phải đi tìm
								-- asset icon cho một biểu tượng phổ thông đến vậy.
								New("TextLabel")({
									BackgroundTransparency = 1,
									Font = Theme.FONT,
									Position = UDim2.fromOffset(14, 10),
									Size = UDim2.fromOffset(44, 44),
									Text = "❤️",
									TextScaled = true,
									ZIndex = 155,
								}),
								Theme.MakeOutlineLabel({
									Position = UDim2.fromOffset(64, 10),
									Size = UDim2.fromOffset(124, 44),
									Text = "Revive",
									TextXAlignment = Enum.TextXAlignment.Center,
									Zoom = zoom,
									MaxTextSize = 36,
									ZIndex = 155,
								}),

								-- Số giây nằm TRONG nút, không phải badge nổi phía trên: nút neo ở 3%
								-- mép trên màn hình nên mọi thứ tràn lên trên đều chui vào topbar Roblox.
								Theme.MakeOutlineLabel({
									Position = UDim2.fromOffset(190, 10),
									Size = UDim2.fromOffset(48, 44),
									Text = Computed(function()
										return `{State.reviveCountdown:get()}s`
									end),
									TextColor3 = Computed(function()
										return TIMER_COLOR_LOW:Lerp(
											TIMER_COLOR_FULL,
											State.reviveCountdownFraction:get()
										)
									end),
									TextXAlignment = Enum.TextXAlignment.Right,
									Zoom = zoom,
									MaxTextSize = 34,
									ZIndex = 155,
								}),

								-- Rãnh tối của thanh thời gian (luôn hiện, làm nền cho phần còn lại).
								New("Frame")({
									AnchorPoint = Vector2.new(0, 1),
									BackgroundColor3 = Color3.fromRGB(18, 52, 20),
									-- KHÔNG cắt con: con của khung `ClipsDescendants` không vẽ được ~1.6 px
									-- sát mép, để lại một dải màu rãnh ở đáy (xem `Theme.BAR_FILL_BLEED`).
									ClipsDescendants = false,
									Position = UDim2.new(0, TIMER_BAR_INSET, 1, -TIMER_BAR_INSET),
									Size = UDim2.new(1, -TIMER_BAR_INSET * 2, 0, TIMER_BAR_HEIGHT),
									ZIndex = 156,
									[Children] = {
										Theme.MakeCorner(TIMER_BAR_HEIGHT // 2),
										-- Phần còn lại: co theo reviveCountdownFraction (20Hz nên trôi mượt).
										Theme.MakeBarTrack({
											ZIndex = 157,
											Children = {
												New("Frame")({
													BackgroundColor3 = Computed(function()
														return TIMER_COLOR_LOW:Lerp(
															TIMER_COLOR_FULL,
															State.reviveCountdownFraction:get()
														)
													end),
													BorderSizePixel = 0,
													Position = Theme.BAR_FILL_POSITION,
													Size = Computed(function()
														return Theme.BarFillSize(State.reviveCountdownFraction:get())
													end),
													ZIndex = 157,
													[Children] = { Theme.MakeCorner(TIMER_BAR_HEIGHT // 2) },
												}),
											},
										}),
									},
								}),
							}
						end,
					}),

					-- Badge giá Robux — ký tự Unicode U+E002, nhô lên góc trên-trái, nghiêng nhẹ
					-- (đồng bộ với badge của nút x2 Speed). Có Infinite Revives thì ẩn hẳn.
					-- `MakePriceLabel`: xanh Robux + nhấp nháy chung nhịp với mọi nhãn giá khác.
					Theme.MakePriceLabel({
						Position = UDim2.fromOffset(-6, -22),
						Size = UDim2.fromOffset(130, 38),
						Rotation = -8,
						Visible = Computed(function()
							return not State.reviveFree:get()
						end),
						Text = Computed(function()
							return `{RobuxPrice.GLYPH}{State.reviveRobuxPrice:get()}`
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 32,
						ZIndex = 160,
					}),
				},
			}),
		},
	})
end

return ReviveModal
