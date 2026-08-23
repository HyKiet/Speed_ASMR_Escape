--!strict
--[[
	RightPanel.luau — CỘT DỌC góc phải: x2/x4/x8 Speed · x2 Wins · Custom Speed.

	Ba ô ĐIỀU KHIỂN/MUA. Ba món "ngó rồi bấm" (Starter Pack · Spin · Playtime) đã chuyển lên
	HÀNG NGANG sát mép trên từ 2026-08-21 — xem `Hud/TopRightRow.luau` và khối lý do dài ở
	`Theme.RIGHT_COLUMN_WIDTH`. Tóm tắt: chồng dọc 5 ô cũ cao 654 design px và cái đuôi của nó
	đè lên nút nhảy mobile + nút SLIDE mới.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local Ownership = require(script.Parent.Parent.Ownership)
local Responsive = require(script.Parent.Parent.Responsive)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Toast)

local localPlayer = Players.LocalPlayer

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local OnChange = Fusion.OnChange
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value

local RightPanel = {}

-- Ô nhập tốc độ KHÔNG đi qua `Theme.MakeSurface` nên không được luật ngón tay tự động phủ;
-- gắn tay vùng chạm, và "bấm" ở đây nghĩa là đặt con trỏ vào ô.
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

-- Pass x2 Wins: một pass duy nhất, không có bậc. Nút tự ẩn khi đã sở hữu, hoặc khi pass chưa
-- được tạo trên Creator Dashboard (`GAMEPASS_IDS.DoubleWins == 0`).
local WINS_PASS_ID = Constants.GAMEPASS_IDS.DoubleWins
local ownsWinsPass = Ownership.Owns(WINS_PASS_ID)

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
	local hoveredPromo = Value(false)
	local hoveredWins = Value(false)

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

	--[[
		══ CHỒNG DỌC TỰ CO LẠI KHI MỘT Ô BIẾN MẤT (user chốt 2026-08-21) ═══════════════════

		`stackLayout` là NGUỒN DUY NHẤT của cả ba toạ độ y lẫn chiều cao cột. Nó phụ thuộc
		đúng hai `Value` — bậc pass speed đang chào bán và quyền sở hữu pass Wins — nên mua
		xong là Fusion tự tính lại, cột tự khít và tự căn lại giữa màn hình.

		⚠️ Điều kiện `Visible` của mỗi ô PHẢI trùng khít với cờ truyền vào đây. Lệch một cái
		là ô hiện nhưng không được chừa chỗ (đè lên ô dưới), hoặc chừa chỗ cho một ô vô hình —
		tức là quay lại đúng cái lỗ mà thay đổi này sinh ra để xoá.
	]]
	local stackLayout = Computed(function()
		return Theme.RightColumnLayout({
			speedPromo = promoTierIndex:get() > 0,
			winsPromo = WINS_PASS_ID > 0 and not ownsWinsPass:get(),
			customSpeed = true,
		})
	end)

	return New("Frame")({
		BackgroundTransparency = 1,
		-- Root neo ở ĐỈNH chồng dọc (chồng thì neo GIỮA màn hình theo chiều dọc); con xếp
		-- theo `stackLayout.Y`.
		Position = Computed(function()
			return Theme.RightColumnOrigin(stackLayout:get().Height)
		end),
		Size = Computed(function()
			return UDim2.fromOffset(Theme.RIGHT_COLUMN_WIDTH, stackLayout:get().Height)
		end),
		[Children] = {
			-- (2026-07-29) Nút Feedback đã GỠ khỏi HUD theo yêu cầu. Hòm thư
			-- `Workspace.Feedback.Mailbox` + biển khu vực trong lobby vẫn còn, và
			-- `CoreLoop/FeedbackPromptController` vẫn dùng được nếu muốn gắn lại chỗ khác.

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
				Position = Computed(function()
					return UDim2.fromOffset(0, stackLayout:get().Y.speedPromo)
				end),
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
				══ NÚT x2 WINS — gamepass mới (user chốt 2026-08-21) ═══════════════════════════

				Dựng theo ĐÚNG khuôn nút speed promo ngay trên (cùng `MakeZoomHost`, cùng cỡ
				214×70, cùng thứ tự lớp hào quang < nút < icon < chữ < badge giá) — hai ô nằm
				chồng nhau trong cùng một cột thì lệch một chi tiết nào cũng lộ ngay.

				KHÁC ở hai chỗ, và cả hai đều có lý do:
				  1. KHÔNG có bậc. Speed có ba pass nên nút phải xoay vòng qua bậc rẻ nhất chưa
				     mua; Wins chỉ có MỘT pass ⇒ hai trạng thái, hiện hoặc ẩn.
				  2. Icon là CÚP (`UI_ASSETS.Trophy`), không phải giày. Cố ý KHÔNG dùng
				     `UI_ASSETS.BoostWins`: icon đó đã in sẵn chữ "x2" trên thân, đặt cạnh nhãn
				     "x2 Wins" là lặp số hai lần trong một ô 214px — đúng cái bẫy đã ghi ở nút
				     speed khi user bỏ `tier.icon` ngày 2026-08-09.

				ẨN khi: đã sở hữu pass, HOẶC pass chưa được tạo trên Creator Dashboard (id = 0).
				Vế thứ hai quan trọng: `PromptGamePassPurchase` với id 0 chỉ ném lỗi câm, người
				chơi bấm mà không có gì xảy ra. Thà không có nút còn hơn có nút chết.
			]]
			Theme.MakeZoomHost({
				Position = Computed(function()
					return UDim2.fromOffset(0, stackLayout:get().Y.winsPromo)
				end),
				Size = UDim2.fromOffset(214, 70),
				Visible = Computed(function()
					return WINS_PASS_ID > 0 and not ownsWinsPass:get()
				end),
				Zoom = { Hovered = hoveredWins, Scale = 1.05 },
				Children = {
					Theme.MakeSunburst({
						Position = UDim2.fromOffset(107, 35),
						Size = UDim2.fromOffset(230, 230),
						ZIndex = 1,
					}),
					Theme.MakeSurface({
						ClassName = "TextButton",
						Size = UDim2.fromScale(1, 1),
						ZIndex = 2,
						Radius = 18,
						Color = Theme.WINS_PASS.colorA,
						-- Dải tím→hồng thay cho cặp hai màu — xem khối lý do ở `Theme.WINS_PASS`
						-- (kể cả vì sao bản cầu vồng bảy sắc đã bị bác).
						Gradient = Theme.WINS_PASS.gradient,
						GradientRotation = Theme.WINS_PASS.gradientRotation,
						Activated = function()
							if WINS_PASS_ID > 0 then
								MarketplaceService:PromptGamePassPurchase(localPlayer, WINS_PASS_ID)
							end
						end,
						MouseEnter = function()
							hoveredWins:set(true)
						end,
						MouseLeave = function()
							hoveredWins:set(false)
						end,
						Content = {
							New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Image = Theme.UI_ASSETS.Trophy,
								Position = UDim2.fromOffset(36, 35),
								Size = UDim2.fromOffset(52, 52),
								ZIndex = 4,
							}),
							Theme.MakeOutlineLabel({
								Position = UDim2.fromOffset(66, 14),
								Size = UDim2.fromOffset(140, 42),
								Text = Theme.WINS_PASS.label,
								MaxTextSize = 34,
								ZIndex = 5,
							}),
						},
					}),
					Theme.MakePriceLabel({
						Position = UDim2.fromOffset(-6, -22),
						Size = UDim2.fromOffset(130, 38),
						Rotation = -8,
						Text = `{RobuxPrice.GLYPH}{Theme.WINS_PASS.priceRobux}`,
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
				Position = Computed(function()
					return UDim2.fromOffset(0, stackLayout:get().Y.customSpeed)
				end),
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
