--!strict
-- Panel phải (2x Speed promo + ô nhập Custom Speed).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local Ownership = require(script.Parent.Parent.Ownership)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Parent.Modals.Manager)

local localPlayer = Players.LocalPlayer

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnChange = Fusion.OnChange
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local RightPanel = {}

-- Tier speed pass ĐANG chào bán = pass rẻ nhất player CHƯA sở hữu (1..3; 0 = đã own hết).
-- Quyền sở hữu do `HUD/Ownership` giữ (dùng chung với ShopModal) — trước đây file này tự
-- hỏi `UserOwnsGamePassAsync` một kiểu riêng, nên Shop và promo có thể lệch nhau.
local promoTierIndex = Value(1)

local function refreshPromoTier()
	local passIds = {}
	for _, tier in Theme.SPEED_PASS_TIERS do
		table.insert(passIds, tier.passId)
	end
	promoTierIndex:set(Ownership.FirstUnowned(passIds))
end

local function getPromoTier()
	local index = promoTierIndex:get()
	return Theme.SPEED_PASS_TIERS[index] or Theme.SPEED_PASS_TIERS[#Theme.SPEED_PASS_TIERS]
end

local function formatPlaytime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02d:%02d", m, s)
end

local function getPlaytimeMultiplier(seconds: number): number
	local m = math.floor(seconds / 60)
	if m >= 60 then return 4
	elseif m >= 40 then return 3
	elseif m >= 20 then return 2
	else return 1 end
end

local function submitCustomSpeed()
	local requestedSpeed = tonumber(State.customSpeedDraft:get())
	if not requestedSpeed then
		State.SyncCustomSpeedDraft(State.GetSnapshot().customSpeedLimit)
		Toast.Show("Enter a valid speed")
		return
	end

	local clampedSpeed = math.clamp(
		math.floor(requestedSpeed),
		Constants.DEFAULT_WALK_SPEED,
		State.GetSnapshot().maxWalkSpeed
	)
	State.SyncCustomSpeedDraft(clampedSpeed)
	GamePackets.requestCustomSpeed.send({
		walkSpeed = clampedSpeed,
	})
end

function RightPanel.Build()
	local hoveredPlaytime = Value(false)
	local hoveredSpin = Value(false)
	local hoveredPromo = Value(false)

	refreshPromoTier()
	-- Mua xong pass → cập nhật tier chào bán tiếp theo. (Ownership tự cập nhật state của nó
	-- qua cùng sự kiện này; ở đây chỉ cần tính lại tier nào đang được chào.)
	State.sweeper:Add(MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, purchased)
		if player == localPlayer and purchased then
			task.defer(refreshPromoTier)
		end
	end))
	-- Trả lời của `UserOwnsGamePassAsync` tới sau vài trăm ms; quét lại vài nhịp đầu để
	-- promo không kẹt ở x2 khi người chơi thực ra đã sở hữu x2 từ trước.
	task.spawn(function()
		for _ = 1, 6 do
			task.wait(0.5)
			refreshPromoTier()
		end
	end)

	return New("Frame")({
		BackgroundTransparency = 1,
		Position = Computed(function()
			local _, top, right, bottom, scale = Theme.GetVisibleDesignBounds()
			local x = if scale < 0.75 then right - 286 - (14 / scale) else 1608
			local y = if scale < 0.75 then top + ((bottom - top - 310) * 0.5) else 355
			return UDim2.fromOffset(x, y)
		end),
		Size = UDim2.fromOffset(286, 310),
		[Children] = {
			-- (2026-07-29) Nút Feedback đã GỠ khỏi HUD theo yêu cầu. Hòm thư
			-- `Workspace.Feedback.Mailbox` + biển khu vực trong lobby vẫn còn, và
			-- `CoreLoop/FeedbackPromptController` vẫn dùng được nếu muốn gắn lại chỗ khác.

			-- Nút Speed Roulette (icon + đếm ngược vé free, giống Playtime Boost) — TRÊN Playtime.
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(166, -302),
				Size = UDim2.fromOffset(120, 130),

				[Children] = {
					New("ImageButton")({
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
					}),
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
					-- Badge số vé
					New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(226, 35, 55),
						Position = UDim2.fromOffset(102, 14),
						Size = UDim2.fromOffset(38, 38),
						Visible = Computed(function()
							return State.rouletteTickets:get() > 0
						end),
						ZIndex = 6,
						[Children] = {
							Theme.MakeCorner(19),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 3),
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

			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(166, -160),
				Size = UDim2.fromOffset(120, 110),
				[Children] = {
					New("ImageButton")({
						BackgroundTransparency = 1,
						Image = "rbxassetid://105847442035004",
						Position = UDim2.fromOffset(10, 0),
						Size = UDim2.fromOffset(100, 100),
						[OnEvent("Activated")] = function()
						end,
						[OnEvent("MouseEnter")] = function()
							hoveredPlaytime:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							hoveredPlaytime:set(false)
						end,
					}),
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
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.25,
						Position = UDim2.fromOffset(-440, -30),
						Size = UDim2.fromOffset(420, 160),
						Visible = hoveredPlaytime,
						ZIndex = 50,
						[Children] = {
							Theme.MakeCorner(12),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 3),
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

			-- Promo speed pass: hiện pass RẺ NHẤT chưa sở hữu, màu đổi theo tier
			-- (x2 cam-vàng → x4 tím → x8 đỏ). Own hết → ẩn.
			--
			-- THỨ TỰ LỚP (chốt theo ảnh tham chiếu của user, 2026-07-28):
			--   hào quang  <  NÚT  <  icon sét  <  chữ  <  giá Robux
			-- Giá Robux phải ĐÈ LÊN GÓC TRÊN-TRÁI, tràn ra ngoài mép nút — mà nút có
			-- `ClipsDescendants` (cần thiết để gradient/studs không lòi ra khỏi bo góc) nên
			-- badge KHÔNG thể là con của nút, nếu không sẽ bị cắt cụt. Vì vậy bọc tất cả
			-- trong một Frame container: hào quang và badge là ANH EM của nút, không phải con.
			-- HoverZoom cũng chuyển lên container để badge phóng to cùng nút.
			New("Frame")({
				BackgroundTransparency = 1,
				-- Cỡ theo ảnh tham chiếu (2026-07-28): 286×110 cũ quá to so với panel Custom
				-- Speed ngay dưới; rút còn 214×70, canh phải theo cột.
				Position = UDim2.fromOffset(286 - 214, 0),
				Size = UDim2.fromOffset(214, 70),
				Visible = Computed(function()
					return promoTierIndex:get() > 0
				end),
				[Children] = {
					Theme.HoverZoom(hoveredPromo, 1.05),

					-- 1) HÀO QUANG — nằm DƯỚI nút, to hơn nút nên phải ở ngoài (nút clip).
					Theme.MakeSunburst({
						Position = UDim2.fromOffset(107, 35),
						Size = UDim2.fromOffset(230, 230),
						ZIndex = 1,
					}),

					-- 2) NÚT
					New("TextButton")({
						BackgroundColor3 = Computed(function()
							return getPromoTier().colorA
						end),
						ClipsDescendants = true,
						Size = UDim2.fromScale(1, 1),
						Text = "",
						ZIndex = 2,
						[OnEvent("Activated")] = function()
							local tier = Theme.SPEED_PASS_TIERS[promoTierIndex:get()]
							if tier then
								MarketplaceService:PromptGamePassPurchase(localPlayer, tier.passId)
							end
						end,
						[OnEvent("MouseEnter")] = function()
							hoveredPromo:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							hoveredPromo:set(false)
						end,
						[Children] = {
							Theme.MakeCorner(18),
							-- Viền 5px = ĐÚNG chuẩn `Theme.MakeButton` (menu trái, nút OK, modal).
							-- Đã thử 3px cho mảnh hơn nhưng nút lệch hẳn khỏi phần còn lại của HUD.
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 5),
							Theme.MakeGradientDynamic(
								Computed(function()
									return getPromoTier().colorA
								end),
								Computed(function()
									return getPromoTier().colorB
								end),
								0
							),
							Theme.MakeStandardStuds(18, 3),
							-- 3) icon GIÀY — DƯỚI chữ (đổi từ tia sét theo yêu cầu user 2026-07-28)
							New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = Theme.UI_ASSETS.Shoe,
								Position = UDim2.fromOffset(36, 35),
								Size = UDim2.fromOffset(52, 52),
								ZIndex = 4,
							}),
							-- 4) chữ — bên PHẢI icon (nút 214 rộng: icon 10..62, chữ 66..206).
							-- Bản đầu để chữ bắt đầu ở x=44 nên nó đè kín icon giày.
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(66, 14),
								Size = UDim2.fromOffset(140, 42),
								Text = Computed(function()
									return getPromoTier().label
								end),
								MaxTextSize = 34,
								ZIndex = 5,
							}),
						},
					}),

					-- 5) GIÁ ROBUX — ký tự UNICODE U+E002 (glyph riêng của font Roblox), KHÔNG
					-- phải ImageLabel: chữ và số nằm chung một TextLabel nên luôn cùng cỡ, cùng
					-- viền, cùng nghiêng. Nghiêng nhẹ -8° cho giống nhãn dán như trong ảnh.
					Theme.MakeOutlineLabel({
						-- Badge nhô LÊN TRÊN mép nút (ảnh tham chiếu: phần lớn nằm ngoài nút),
						-- không nằm gọn trong góc.
						Position = UDim2.fromOffset(-6, -22),
						Size = UDim2.fromOffset(130, 38),
						Rotation = -8,
						Text = Computed(function()
							return `{RobuxPrice.GLYPH}{getPromoTier().priceRobux}`
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 30,
						TextStrokeThickness = 4,
						ZIndex = 20,
					}),
				},
			}),
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(15, 164, 255),
				ClipsDescendants = true,
				-- Nút promo rút từ 110 → 70 cao, kéo panel này lên theo cho khỏi hở một mảng.
				Position = UDim2.fromOffset(0, 92),
				Size = UDim2.fromOffset(286, 172),
				[Children] = {
					Theme.MakeCorner(18),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 5),
					Theme.MakeGradient(Color3.fromRGB(34, 198, 255), Color3.fromRGB(0, 95, 230)),
					Theme.MakeStandardStuds(18, 1),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(16, 8),
						Size = UDim2.fromOffset(254, 32),
						Text = "Custom Speed",
						MaxTextSize = 28,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(16, 38),
						Size = UDim2.fromOffset(254, 24),
						Text = Computed(function()
							return `Your Max Speed: {math.floor(State.GetSnapshot().maxWalkSpeed)}`
						end),
						TextColor3 = Color3.fromRGB(255, 238, 89),
						MaxTextSize = 18,
					}),
					New("TextBox")({
						BackgroundColor3 = Color3.fromRGB(235, 239, 242),
						ClearTextOnFocus = false,
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(14, 72),
						Size = UDim2.fromOffset(152, 58),
						Text = State.customSpeedDraft,
						TextColor3 = Color3.fromRGB(80, 80, 100),
						TextScaled = true,
						TextStrokeTransparency = 1,
						[OnChange("Text")] = function(text: string)
							local digitsOnly = string.gsub(text, "[^%d]", "")
							if State.customSpeedDraft:get() ~= digitsOnly then
								State.customSpeedDraft:set(digitsOnly)
							end
						end,
						[OnEvent("Focused")] = function()
							State.isEditingCustomSpeed = true
						end,
						[OnEvent("FocusLost")] = function()
							State.isEditingCustomSpeed = false
							submitCustomSpeed()
						end,
						[Children] = {
							Theme.MakeCorner(10),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							New("UITextSizeConstraint")({
								MaxTextSize = 34,
								MinTextSize = 12,
							}),
						},
					}),
					New("TextButton")({
						AutoButtonColor = true,
						BackgroundColor3 = Color3.fromRGB(75, 222, 61),
						Font = Enum.Font.GothamBlack,
						Position = UDim2.fromOffset(174, 72),
						Size = UDim2.fromOffset(98, 58),
						Text = "OK",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
						TextStrokeTransparency = 0,
						[OnEvent("Activated")] = submitCustomSpeed,
						[Children] = {
							Theme.MakeCorner(12),
							Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
							Theme.MakeGradient(Color3.fromRGB(88, 230, 68), Color3.fromRGB(34, 155, 33)),
							Theme.MakeStandardStuds(12),
							New("UITextSizeConstraint")({
								MaxTextSize = 32,
								MinTextSize = 12,
							}),
						},
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(14, 138),
						Size = UDim2.fromOffset(258, 24),
						Text = Computed(function()
							return `Current Speed: {math.floor(State.GetSnapshot().customSpeedLimit)}`
						end),
						MaxTextSize = 18,
					}),
				},
			}),
		},
	})
end

return RightPanel
