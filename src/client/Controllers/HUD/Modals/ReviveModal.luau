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
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local localPlayer = Players.LocalPlayer

local ReviveModal = {}

local BUTTON_WIDTH = 250
local BUTTON_HEIGHT = 76

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

					New("TextButton")({
						AutoButtonColor = false,
						BackgroundColor3 = Color3.fromRGB(88, 214, 74),
						ClipsDescendants = true,
						Size = UDim2.fromScale(1, 1),
						Text = "",
						ZIndex = 152,
						[OnEvent("Activated")] = onReviveClicked,
						[OnEvent("MouseEnter")] = function()
							hovered:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							hovered:set(false)
						end,
						[Children] = {
							Theme.MakeCorner(16),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradient(Color3.fromRGB(134, 240, 108), Color3.fromRGB(38, 158, 48), 0),
							Theme.MakeStandardStuds(16, 153),
							Theme.HoverZoom(hovered, 1.06),
							-- Tim đỏ: dùng emoji (Roblox render màu sẵn) — không phải đi tìm
							-- asset icon cho một biểu tượng phổ thông đến vậy.
							New("TextLabel")({
								BackgroundTransparency = 1,
								Font = Enum.Font.GothamBlack,
								Position = UDim2.fromOffset(14, 14),
								Size = UDim2.fromOffset(48, 48),
								Text = "❤️",
								TextScaled = true,
								ZIndex = 155,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(70, 16),
								Size = UDim2.fromOffset(166, 44),
								Text = "Revive",
								TextXAlignment = Enum.TextXAlignment.Center,
								MaxTextSize = 36,
								TextStrokeThickness = 4,
								ZIndex = 155,
							}),
						},
					}),

					-- Badge giá Robux — ký tự Unicode U+E002, nhô lên góc trên-trái, nghiêng nhẹ
					-- (đồng bộ với badge của nút x2 Speed). Có Infinite Revives thì ẩn hẳn.
					Theme.MakeOutlineLabel({
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
						TextStrokeThickness = 4,
						ZIndex = 160,
					}),
				},
			}),
		},
	})
end

return ReviveModal
