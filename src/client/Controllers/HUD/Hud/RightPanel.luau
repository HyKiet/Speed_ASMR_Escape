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
local Responsive = require(script.Parent.Parent.Responsive)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
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

--[[
	Nút icon thô (`ImageButton`) KHÔNG đi qua `Theme.MakeSurface` nên không được luật ngón tay
	tự động phủ. Helper này dựng nút rồi gắn tay vùng chạm — chỉ 2 nút trong cột phải (Spin,
	Playtime) rơi vào diện này, nhưng cả hai đều là nút bấm thật.
]]
local function makeIconButton(props: { [any]: any }, activated: () -> ())
	local button = New("ImageButton")(props)
	Responsive.AttachHitArea(button, activated)
	return button
end

-- Ô nhập tốc độ: cùng lý do như trên, nhưng "bấm" ở đây nghĩa là đặt con trỏ vào ô.
local function makeSpeedInput(props: { [any]: any })
	local box = New("TextBox")(props)
	Responsive.AttachHitArea(box, function()
		(box :: TextBox):CaptureFocus()
	end)
	return box
end

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
	if m >= 60 then
		return 4
	elseif m >= 40 then
		return 3
	elseif m >= 20 then
		return 2
	else
		return 1
	end
end

--[[
	══ CUSTOM SPEED TỰ ÁP DỤNG — KHÔNG CÒN NÚT OK (user chốt 2026-08-15) ════════════════════

	Nút OK là một cú bấm thừa: người chơi gõ số xong đã coi như xong việc, phải với thêm sang
	một nút 66px nữa mới ăn. Giờ gõ tới đâu áp tới đó.

	⚠️ BẪY CHÍNH của kiểu tự-áp-dụng, và cách file này né:
	Người chơi muốn 52 thì trong lúc gõ có một khoảnh khắc ô chỉ có "5". Nếu cứ thế mà KẸP rồi
	GHI NGƯỢC vào ô, "5" bị kéo lên tốc độ tối thiểu và ô nhảy thành "16" ngay dưới ngón tay —
	không thể gõ nổi số nào có 2 chữ số. Vì vậy tách hẳn hai việc:
	  • `normalizeText = false` (lúc đang gõ): CHỈ gửi packet, TUYỆT ĐỐI không đụng vào chữ
	    trong ô. Người chơi vẫn thấy đúng cái mình gõ.
	  • `normalizeText = true` (lúc rời ô / bấm Enter): mới ghi lại con số đã kẹp.

	Kèm hai lớp chống spam: chờ `APPLY_DELAY` sau phím cuối, và bỏ qua nếu giá trị không đổi so
	với lần gửi trước — gõ "1", "12", "123" chỉ tốn đúng một gói tin.
]]
local APPLY_DELAY = 0.45
local applyToken = 0
local lastSentSpeed = -1

local function applyCustomSpeed(normalizeText: boolean)
	local snapshot = State.GetSnapshot()
	local requestedSpeed = tonumber(State.customSpeedDraft:get())

	-- Ô rỗng hoặc không phải số: lúc đang gõ thì kệ (người chơi vừa xoá sạch để gõ lại),
	-- lúc rời ô mới kéo về tốc độ đang chạy cho ô không đứng trơ ra.
	if not requestedSpeed then
		if normalizeText then
			State.SyncCustomSpeedDraft(snapshot.customSpeedLimit)
		end
		return
	end

	local clampedSpeed = math.clamp(math.floor(requestedSpeed), Constants.DEFAULT_WALK_SPEED, snapshot.maxWalkSpeed)

	-- Báo MỘT LẦN khi người chơi đòi cao hơn trần: im lặng kẹp xuống thì họ tưởng ô nhập hỏng.
	-- Chỉ báo lúc rời ô, không báo giữa lúc gõ (gõ "999" sẽ bắn 3 toast).
	if normalizeText and requestedSpeed > snapshot.maxWalkSpeed then
		Toast.Show(`Max speed is {math.floor(snapshot.maxWalkSpeed)}`)
	end

	if normalizeText then
		State.SyncCustomSpeedDraft(clampedSpeed)
	end

	if clampedSpeed == lastSentSpeed then
		return
	end
	lastSentSpeed = clampedSpeed
	GamePackets.requestCustomSpeed.send({
		walkSpeed = clampedSpeed,
	})
end

-- Gõ xong `APPLY_DELAY` giây không gõ nữa thì tự áp dụng.
local function scheduleAutoApply()
	applyToken += 1
	local token = applyToken
	task.delay(APPLY_DELAY, function()
		if token == applyToken then
			applyCustomSpeed(false)
		end
	end)
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
		-- Toàn bộ cột phải giờ là MỘT chồng dọc; vị trí lấy từ bảng slot dùng chung
		-- (xem `Theme.RIGHT_STACK`). Root neo ở đỉnh chồng, con xếp theo offset slot.
		Position = Computed(function()
			return Theme.RightSlotPosition("starterPack")
		end),
		Size = UDim2.fromOffset(Theme.RIGHT_COLUMN_WIDTH, 688),
		[Children] = {
			-- (2026-07-29) Nút Feedback đã GỠ khỏi HUD theo yêu cầu. Hòm thư
			-- `Workspace.Feedback.Mailbox` + biển khu vực trong lobby vẫn còn, và
			-- `CoreLoop/FeedbackPromptController` vẫn dùng được nếu muốn gắn lại chỗ khác.

			-- Nút Speed Roulette (icon + đếm ngược vé free, giống Playtime Boost) — TRÊN Playtime.
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(166, Theme.RIGHT_STACK.spin),
				Size = UDim2.fromOffset(120, 130),

				[Children] = {
					makeIconButton({
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
					}, Manager.ToggleRoulette),
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
					-- Badge số vé. Dựng bằng `MakeSurface` (2026-08-16) thay vì tự chồng "khung đen +
					-- ruột": chỉ khối đi qua `MakeSurface` mới được kẹp SÀN độ dày viền theo px thật,
					-- nên trên cửa sổ nhỏ viền không mỏng tới mức biến mất.
					Theme.MakeSurface({
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(102, 14),
						Size = UDim2.fromOffset(38, 38),
						ZIndex = 6,
						Radius = 19,
						Border = Tokens.BORDER,
						Studs = false,
						Color = Color3.fromRGB(226, 35, 55),
						Visible = Computed(function()
							return State.rouletteTickets:get() > 0
						end),
						Content = {
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
				Position = UDim2.fromOffset(166, Theme.RIGHT_STACK.playtime),
				Size = UDim2.fromOffset(120, 110),
				[Children] = {
					--[[
						⚠️ Bảng giải thích Playtime Boost trước đây CHỈ hiện khi RÊ CHUỘT — tức là
						người chơi mobile không có cách nào đọc được nó, mà mobile là phần lớn
						người chơi. Trên cảm ứng không tồn tại trạng thái "rê", nên chạm = bật/tắt.
					]]
					makeIconButton({
						BackgroundTransparency = 1,
						Image = "rbxassetid://105847442035004",
						Position = UDim2.fromOffset(10, 0),
						Size = UDim2.fromOffset(100, 100),
						[OnEvent("MouseEnter")] = function()
							hoveredPlaytime:set(true)
						end,
						[OnEvent("MouseLeave")] = function()
							hoveredPlaytime:set(false)
						end,
					}, function()
						hoveredPlaytime:set(not hoveredPlaytime:get(false))
					end),
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
					Theme.MakeSurface({
						Position = UDim2.fromOffset(-440, -30),
						Size = UDim2.fromOffset(420, 160),
						Visible = hoveredPlaytime,
						ZIndex = 50,
						Radius = 12,
						Border = Tokens.BORDER,
						Studs = false,
						Color = Color3.fromRGB(0, 0, 0),
						-- Trong suốt NHẸ (user 2026-08-20). Phải hạ cả hai lớp: chỉ hạ
						-- `FillTransparency` thì khung ngoài vẫn đen đặc phủ trọn ô và bảng
						-- trông kín mít y như cũ — xem `BorderTransparency` trong Theme.
						-- Chữ giữ nguyên độ đục + đã có viền nên vẫn đọc rõ trên nền sáng.
						FillTransparency = 0.6,
						BorderTransparency = 0.4,
						Content = {
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
			-- Phóng đặt ở container để badge phóng cùng nút. `MakeZoomHost` (không phải
			-- `HoverZoom` trực tiếp): container neo (0,0) nên `UIScale` gắn thẳng lên nó chỉ nở
			-- về phải + xuống dưới — xem khối lý do ở `Theme.MakeZoomHost`.
			Theme.MakeZoomHost({
				-- Cỡ theo ảnh tham chiếu (2026-07-28): 286×110 cũ quá to so với panel Custom
				-- Speed ngay dưới; rút còn 214×70, canh phải theo cột.
				Position = UDim2.fromOffset(Theme.RIGHT_COLUMN_WIDTH - 214, Theme.RIGHT_STACK.speedPromo),
				Size = UDim2.fromOffset(214, 70),
				Visible = Computed(function()
					return promoTierIndex:get() > 0
				end),
				Zoom = { Hovered = hoveredPromo, Scale = 1.05 },
				Children = {

					-- 1) HÀO QUANG — nằm DƯỚI nút, to hơn nút nên phải ở ngoài (nút clip).
					Theme.MakeSunburst({
						Position = UDim2.fromOffset(107, 35),
						Size = UDim2.fromOffset(230, 230),
						ZIndex = 1,
					}),

					-- 2) NÚT — nền kiểu mới `Theme.MakeSurface` (viền là khối hình học, không
					-- phải UIStroke). Xem chú thích dài ở `Theme.MakeSurface` để biết vì sao.
					Theme.MakeSurface({
						ClassName = "TextButton",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 2,
						Radius = 18,
						Color = Computed(function()
							return getPromoTier().colorA
						end),
						ColorB = Computed(function()
							return getPromoTier().colorB
						end),
						GradientRotation = 0,
						Activated = function()
							local tier = Theme.SPEED_PASS_TIERS[promoTierIndex:get()]
							if tier then
								MarketplaceService:PromptGamePassPurchase(localPlayer, tier.passId)
							end
						end,
						MouseEnter = function()
							hoveredPromo:set(true)
						end,
						MouseLeave = function()
							hoveredPromo:set(false)
						end,
						Content = {
							-- 3) icon GIÀY — DƯỚI chữ (đổi từ tia sét theo yêu cầu user 2026-07-28).
							-- ⚠️ LUÔN là icon giày CHUNG, KHÔNG dùng `tier.icon` (2026-08-09,
							-- user chốt): icon riêng từng bậc đã có sẵn chữ "x2/x4/x8" in trên
							-- thân giày, đặt cạnh nhãn "x2 Speed" của nút là lặp số hai lần
							-- trong một ô 214px. Icon riêng chỉ dùng ở banner chúc mừng (chỗ đó
							-- không có nhãn nào khác) — xem BoostCelebration.
							New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = Theme.UI_ASSETS.Shoe,
								Position = UDim2.fromOffset(36, 35),
								Size = UDim2.fromOffset(52, 52),
								ZIndex = 4,
							}),
							-- 4) chữ — bên PHẢI icon (nút 214 rộng: icon 10..62, chữ 66..206).
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
					-- `MakePriceLabel`: xanh Robux + nhấp nháy (xem Theme). Đây là badge giá của
					-- cả ba bậc x2/x4/x8 vì promo xoay vòng qua `getPromoTier()`.
					Theme.MakePriceLabel({
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
						ZIndex = 20,
					}),
				},
			}),
			--[[
				CUSTOM SPEED — CÙNG KHỔ VỚI NÚT x2 SPEED (user chốt 2026-08-15).

				Trước đây panel này rộng 286 (nguyên bề ngang cột) × cao 172, đứng ngay cạnh nút
				x2 Speed chỉ 214×70 — hai khối lệch nhau gần một phần ba bề ngang nên cột phải
				trông như hai cụm khác nhau bị ghép lại. Giờ rộng ĐÚNG 214 như nút x2 Speed và
				căn cùng mép phải; chiều cao rút 172 → 138 bằng cách gom hai dòng chữ ở trên lại
				và thu ô nhập + nút OK theo tỉ lệ.

				Bố cục bên trong (panel 214×118), gọn còn BA tầng thay vì bốn:
				  tiêu đề 6..30 · ô nhập TRÀN NGANG 34..86 · dòng trạng thái 90..112
				Ô nhập chiếm nguyên bề ngang (190px thay vì 116px) vì giờ nó là thứ DUY NHẤT
				phải bấm trúng — vùng chạm rộng gần gấp đôi, quan trọng nhất trên mobile.
				Dòng "Max" và "Current" gộp làm một để bỏ được một tầng chữ.
			]]
			--[[
				Cả panel lẫn ô nhập bên trong đều dựng bằng `Theme.MakeSurface` (nền kiểu mới):
				viền là khối hình học, không còn `UIStroke`. Ô nhập là chỗ user khoanh đỏ
				2026-08-15 — nó là một khối trắng nhỏ nằm trên nền xanh nên viền lệch bao nhiêu
				cũng lộ ra hết.

				Viền nằm PHÍA NGOÀI ô khai báo nên toạ độ con giữ nguyên số cũ.
			]]
			Theme.MakeSurface({
				Position = UDim2.fromOffset(Theme.RIGHT_COLUMN_WIDTH - 214, Theme.RIGHT_STACK.customSpeed),
				Size = UDim2.fromOffset(214, 118),
				ZIndex = 1,
				Radius = 14,
				Color = Color3.fromRGB(34, 198, 255),
				ColorB = Color3.fromRGB(0, 95, 230),
				Content = {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(12, 6),
						Size = UDim2.fromOffset(190, 24),
						Text = "Custom Speed",
						MaxTextSize = 22,
						ZIndex = 4,
					}),
					Theme.MakeSurface({
						Position = UDim2.fromOffset(12, 34),
						Size = UDim2.fromOffset(190, 52),
						ZIndex = 4,
						Radius = 10,
						Border = Theme.BORDER_INNER,
						Color = Color3.fromRGB(235, 239, 242),
						-- Ô nhập cố ý KHÔNG có hoa văn: nền phải sạch để con số dễ đọc.
						Studs = false,
						Content = {
							--[[
								Ô nhập cao 52 design px ⇒ 23 px thật trên điện thoại: chưa tới nửa
								ngưỡng ngón tay. `MakeSurface` không phủ hộ được vì đây là `TextBox`
								chứ không phải nút có `Activated`, nên gắn tay — lớp chạm gọi
								`CaptureFocus()` để bàn phím ảo bật lên đúng như chạm thẳng vào ô.
							]]
							makeSpeedInput({
								BackgroundTransparency = 1,
								ClearTextOnFocus = false,
								Font = Theme.FONT,
								PlaceholderText = "Speed",
								Size = UDim2.fromScale(1, 1),
								Text = State.customSpeedDraft,
								TextColor3 = Color3.fromRGB(40, 46, 70),
								TextScaled = true,
								TextStrokeTransparency = 1,
								ZIndex = 6,
								--[[
							CHẶN CHỮ VÀ KÝ HIỆU NGAY TẠI ĐÂY (user chốt 2026-08-15).

							`OnChange("Text")` chạy sau MỖI ký tự, kể cả ký tự dán từ clipboard và
							ký tự do bàn phím ảo mobile bắn vào, nên lọc ở đây là chốt chặn duy
							nhất cần có — không có đường nào lọt vào `applyCustomSpeed` mà chưa
							qua bộ lọc này.

							`%d` = chỉ giữ chữ số: chặn luôn cả dấu trừ, dấu chấm và dấu cách, nên
							không bao giờ có tốc độ âm hay số thập phân. Cắt 5 chữ số vì trần tốc
							độ của game không bao giờ chạm 6 chữ số, mà để dài hơn thì `TextScaled`
							bóp chữ bé xíu không đọc nổi.
						]]
								[OnChange("Text")] = function(text: string)
									local digitsOnly = string.gsub(text, "%D", "")
									digitsOnly = string.sub(digitsOnly, 1, 5)
									if State.customSpeedDraft:get() ~= digitsOnly then
										State.customSpeedDraft:set(digitsOnly)
									end
									scheduleAutoApply()
								end,
								[OnEvent("Focused")] = function()
									State.isEditingCustomSpeed = true
								end,
								-- Rời ô HOẶC bấm Enter đều rơi vào đây (Roblox bắn `FocusLost` cho
								-- cả hai), nên không cần bắt phím Enter riêng.
								[OnEvent("FocusLost")] = function()
									State.isEditingCustomSpeed = false
									applyToken += 1 -- huỷ lần tự-áp-dụng đang chờ, tránh gửi hai lần
									applyCustomSpeed(true)
								end,
								[Children] = {
									Theme.MakeTextSizeConstraint(34, 12),
								},
							}),
						},
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(12, 90),
						Size = UDim2.fromOffset(190, 22),
						Text = Computed(function()
							local snapshot = State.GetSnapshot()
							return `Now {math.floor(snapshot.customSpeedLimit)}  ·  Max {math.floor(
								snapshot.maxWalkSpeed
							)}`
						end),
						TextColor3 = Color3.fromRGB(255, 238, 89),
						MaxTextSize = 18,
						ZIndex = 4,
					}),
				},
			}),
		},
	})
end

return RightPanel
