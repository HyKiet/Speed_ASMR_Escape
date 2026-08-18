--!strict
-- Modal Rebirth: tăng Rebirths cố định khi đủ Level.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local Products = require(ReplicatedStorage.Shared.Config.Economy.Products)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local localPlayer = Players.LocalPlayer

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Tween = Fusion.Tween
local Value = Fusion.Value

local RebirthModal = {}

--[[
	860 × 644 (thu nhỏ 2026-08-16 theo yêu cầu user).

	Bố cục trong modal này là toạ độ TUYỆT ĐỐI nên đổi cỡ vỏ là phải tính lại từng số. Khung
	quy chiếu mới, mọi con số bên dưới bám theo nó:
	    lề hai bên 40 · khe giữa hai cột 20 · nội dung rộng 780 · mỗi cột 380
	    hàng dọc: nhãn 106 · thẻ 158 · cảnh báo 282 · thanh 326 · nút 424 · hàng Auto 546
	    (hàng Auto cao 92 ⇒ kết thúc 638, chừa 6 lề đáy)
]]
local PANEL_WIDTH = 860
local PANEL_HEIGHT = 644

--[[
	HAI THẺ SPEED + MŨI TÊN GIỮA (chỉnh 2026-08-16: user "chỉnh 2 khung nhỏ ngắn lại để mũi tên
	có chỗ hiển thị").

	Bản trước hai thẻ rộng 380, khe giữa chỉ 20 — mà thẻ còn có viền vẽ RA NGOÀI 4px mỗi bên nên
	khe nhìn thấy chỉ còn 12px, trong khi mũi tên ">" là một ô 80px. Kết quả: mũi tên nằm ĐÈ lên
	cả hai thẻ, gần như không đọc ra.

	Giờ khe rộng `ARROW_GAP` = 80, thẻ co lại cho vừa:
	    lề 40 · thẻ 350 · khe 80 · thẻ 350 · lề 40  = 860 ✓
	Mũi tên rộng 76 nằm giữa khe (392..468), cách viền mỗi thẻ ~6px.
]]
local ARROW_GAP = 80
local SPEED_CARD_W = (PANEL_WIDTH - 40 * 2 - ARROW_GAP) // 2
local SPEED_CARD_X2 = 40 + SPEED_CARD_W + ARROW_GAP
-- Tâm khe giữa hai thẻ.
local ARROW_CX = 40 + SPEED_CARD_W + ARROW_GAP // 2

-- Giá Auto-Rebirth phải là giá THEO VÙNG của người đang xem (xem RobuxPrice.luau), nên
-- fetch một lần lúc load rồi bơm vào Value; trong lúc chờ hiện giá config làm tạm.
local AUTO_REBIRTH_PASS_ID = Constants.GAMEPASS_IDS.AutoRebirth or 0
local autoRebirthPriceText = Value(RobuxPrice.FormatPrefixed(99))
if AUTO_REBIRTH_PASS_ID > 0 then
	task.spawn(function()
		local price = RobuxPrice.GetAsync(AUTO_REBIRTH_PASS_ID)
		if price then
			autoRebirthPriceText:set(RobuxPrice.FormatPrefixed(price))
		end
	end)
end

local function makeSpeedCard(position: UDim2, speedText: any)
	return New("Frame")({
		BackgroundColor3 = Color3.fromRGB(220, 40, 50),
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(SPEED_CARD_W, 116),
		ZIndex = 42,
		[Children] = {
			Theme.MakeCorner(14),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(Color3.fromRGB(250, 70, 80), Color3.fromRGB(180, 20, 30)),
			Theme.MakeStandardStuds(14, 44),
			-- icon giày chìm dưới text, xoay nhẹ
			New("ImageLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Shoe,
				Position = UDim2.fromScale(0.5, 0.52),
				Rotation = 12,
				Size = UDim2.fromOffset(80, 80),
				ZIndex = 45,
			}),
			-- text đè lên icon giày
			Theme.MakeOutlineLabel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Text = speedText,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				MaxTextSize = 44,
				ZIndex = 46,
			}),
		},
	})
end

local function buildContent(): { any }
	return {
		-- ── Before / After labels ────────────────────────────────────
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(40, 106),
			Size = UDim2.fromOffset(SPEED_CARD_W, 44),
			Text = "Before",
			TextXAlignment = Enum.TextXAlignment.Center,
			MaxTextSize = 36,
			ZIndex = 42,
		}),
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(SPEED_CARD_X2, 106),
			Size = UDim2.fromOffset(SPEED_CARD_W, 44),
			Text = "After",
			TextXAlignment = Enum.TextXAlignment.Center,
			MaxTextSize = 36,
			ZIndex = 42,
		}),

		-- ── Speed cards ──────────────────────────────────────────────
		makeSpeedCard(
			UDim2.fromOffset(40, 158),
			Computed(function()
				return `Speed: x{string.format("%.1f", Constants.GetRebirthMultiplier(State.GetSnapshot().rebirths))}`
			end)
		),

		-- Big arrow between cards
		New("TextLabel")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Theme.FONT,
			Position = UDim2.fromOffset(ARROW_CX, 216),
			Size = UDim2.fromOffset(ARROW_GAP - 4, 80),
			Text = ">",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0,
			ZIndex = 44,
			[Children] = {
				Theme.MakeTextSizeConstraint(72, 20),
			},
		}),

		makeSpeedCard(
			UDim2.fromOffset(SPEED_CARD_X2, 158),
			Computed(function()
				return `Speed: x{string.format("%.1f", Constants.GetRebirthMultiplier(State.GetSnapshot().rebirths + 1))}`
			end)
		),

		-- ── Warning ──────────────────────────────────────────────────
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(40, 282),
			Size = UDim2.fromOffset(780, 38),
			Text = "Rebirth resets your speed level!",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			MaxTextSize = 28,
			ZIndex = 42,
		}),

		--[[
			── Thanh tiến trình Level ────────────────────────────────────────────────────────

			LỖI ĐÃ SỬA 2026-08-16 (user: "hiệu ứng thanh tiến trình level bị thiếu"): bản cũ dựng
			viền bằng một Frame ĐEN ĐẶC đặt đè lên (`ZIndex 45` > `42/43` của rãnh và miếng chạy),
			với một Frame trong suốt bên trong để "khoét ruột". Nhưng Frame trong suốt KHÔNG đục
			được lỗ trên cha — cái nền đen của cha vẫn vẽ kín, nên nó phủ trọn cả rãnh lẫn miếng
			chạy vàng. Thanh vì thế luôn hiện ra là một khối đen tuyền, đúng như ảnh user gửi.

			Giờ dùng `MakeSurface`: viền là KHỐI HÌNH HỌC bao ngoài (không đè lên ruột), và ruột
			đã sẵn `ClipsDescendants` nên vẫn giữ được mẹo tràn 1px của `Theme.BarFillSize`.
		]]
		Theme.MakeSurface({
			Position = UDim2.fromOffset(44, 330),
			Size = UDim2.fromOffset(772, 82),
			ZIndex = 42,
			Radius = 14,
			Border = 4,
			Color = Color3.fromRGB(80, 10, 15),
			-- Rãnh không cắt con — xem `Theme.BAR_FILL_BLEED`: con của khung `ClipsDescendants`
			-- không vẽ được ~1.6 px sát mép, để lại một dải đỏ sẫm ở đáy thanh vàng.
			ClipContent = false,
			Content = {
				Theme.MakeBarTrack({
					ZIndex = 43,
					Children = {
						New("Frame")({
							BackgroundColor3 = Color3.fromRGB(240, 200, 30),
							Position = Theme.BAR_FILL_POSITION,
							Size = Tween(
								Computed(function()
									local state = State.GetSnapshot()
									return Theme.BarFillSize(math.clamp(state.level / state.requiredRebirthLevel, 0, 1))
								end),
								TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
							),
							ZIndex = 43,
							[Children] = {
								Theme.MakeCorner(14),
								Theme.MakeGradient(Color3.fromRGB(255, 232, 58), Color3.fromRGB(205, 152, 12), 0),
								-- Cùng lý do với thanh XP đáy màn hình: miếng chạy phải mượn lưới ô của
								-- rãnh, tự chốt lưới thì ô bị kéo giãn dần khi thanh dài ra.
								Theme.MakeBarFillStuds(0.86, 44, 14),
							},
						}),
					},
				}),
				Theme.MakeOutlineLabel({
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					Text = Computed(function()
						local s = State.GetSnapshot()
						return `Level {s.level} / {s.requiredRebirthLevel}`
					end),
					MaxTextSize = 44,
					ZIndex = 46,
				}),
			},
		}),

		--[[
			── BA NÚT CỦA REBIRTH: CÙNG MỘT KHUÔN ──────────────────────────────────────────────

			User 2026-08-16: "3 button hiệu ứng không đồng bộ". Đo lại thì đúng — và lệch nặng hơn
			vẻ ngoài: nút Rebirth và nút Skip KHÔNG hề có hiệu ứng rê chuột nào (chỉ đổi màu nền),
			còn nút ON/OFF của Auto-Rebirth thì có `HoverZoom` nhưng đặt bên trong nút nên viền
			đứng im. Giờ cả ba đi qua `MakeSurface` + `Zoom`, đúng khuôn nút CLAIM của Daily:
			phóng đều 4 góc, viền và chữ phóng cùng nhịp.

			Toạ độ khai báo lệch +4 so với bản cũ vì `MakeSurface` vẽ viền RA NGOÀI ô khai báo —
			mép ngoài vẫn rơi đúng (40, 436) và (486, 436) như trước, không xê dịch bố cục.
		]]
		Theme.MakeSurface({
			ClassName = "TextButton",
			Position = UDim2.fromOffset(44, 428),
			Size = UDim2.fromOffset(392, 110),
			ZIndex = 45,
			Radius = 16,
			Border = 4,
			Color = Computed(function()
				if not State.GetSnapshot().canRebirth then
					return Color3.fromRGB(100, 30, 30)
				end
				return Color3.fromRGB(255, 240, 100)
			end),
			ColorB = Computed(function()
				if not State.GetSnapshot().canRebirth then
					return Color3.fromRGB(70, 18, 18)
				end
				return Color3.fromRGB(240, 150, 0)
			end),
			Zoom = { Hovered = State.rebirthConfirmHovered, Scale = 1.08 },
			Activated = function()
				local state = State.GetSnapshot()
				if state.canRebirth then
					GamePackets.requestRebirth.send({})
					Manager.CloseRebirth()
				else
					Toast.Show(`Need Level {state.requiredRebirthLevel}`)
				end
			end,
			MouseEnter = function()
				State.rebirthConfirmHovered:set(true)
			end,
			MouseLeave = function()
				State.rebirthConfirmHovered:set(false)
			end,
			Content = function(zoom)
				return {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = Computed(function()
							local state = State.GetSnapshot()
							return if state.canRebirth then "Rebirth" else `Need Level {state.requiredRebirthLevel}`
						end),
						Zoom = zoom,
						MaxTextSize = 50,
						ZIndex = 47,
					}),
				}
			end,
		}),

		-- ── SKIP button ───────────────────────────────────────────────
		Theme.MakeSurface({
			ClassName = "TextButton",
			Position = UDim2.fromOffset(464, 428),
			Size = UDim2.fromOffset(352, 110),
			ZIndex = 45,
			Radius = 16,
			Border = 4,
			Color = Color3.fromRGB(255, 190, 80),
			ColorB = Color3.fromRGB(220, 100, 10),
			Zoom = { Hovered = State.rebirthSkipHovered, Scale = 1.08 },
			Activated = function()
				if Products.SKIP_REBIRTH_PRODUCT_ID <= 0 then
					Toast.Show("Set Skip Rebirth Product ID!")
					return
				end
				MarketplaceService:PromptProductPurchase(localPlayer, Products.SKIP_REBIRTH_PRODUCT_ID)
			end,
			MouseEnter = function()
				State.rebirthSkipHovered:set(true)
			end,
			MouseLeave = function()
				State.rebirthSkipHovered:set(false)
			end,
			Content = function(zoom)
				return {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = `Skip (\u{E002} 149)`,
						Zoom = zoom,
						MaxTextSize = 44,
						ZIndex = 47,
					}),
				}
			end,
		}),

		-- ── AUTO-REBIRTH (gamepass) ───────────────────────────────────
		-- Đặt ở ĐÂY chứ không phải trong Shop: đây là nơi người chơi đang nhìn thanh
		-- "Level x / y" và nghĩ về việc trùng sinh — bán đúng lúc có nhu cầu.
		-- Ba trạng thái: CHƯA MUA (hiện giá, bấm = prompt) / ON / OFF.
		-- Công tắc ON-OFF là bắt buộc, không phải màu mè: người chơi cần dừng auto để
		-- giữ Level cao mà chạy obby, nếu không mua pass xong lại thành bất tiện.
		Theme.MakeSurface({
			Position = UDim2.fromOffset(44, 550),
			Size = UDim2.fromOffset(772, 84),
			ZIndex = 42,
			Radius = 14,
			Border = Tokens.BORDER,
			Color = Color3.fromRGB(70, 12, 16),
			Content = {
				New("ImageLabel")({
					BackgroundTransparency = 1,
					-- ĐÚNG icon Auto-Rebirth của thẻ trong Shop (2026-08-09). Trước đây dùng
					-- `UI_ASSETS.Rebirth` nên cùng một món mà hai chỗ hai hình: người chơi
					-- xem Shop rồi mở bảng Rebirth không nhận ra đó là thứ mình vừa xem.
					Image = Theme.UI_ASSETS.AutoRebirth,
					Position = UDim2.fromOffset(12, 10),
					Size = UDim2.fromOffset(64, 64),
					ZIndex = 44,
				}),
				Theme.MakeOutlineLabel({
					Position = UDim2.fromOffset(88, 8),
					Size = UDim2.fromOffset(400, 38),
					Text = "Auto-Rebirth",
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 34,
					ZIndex = 44,
				}),
				Theme.MakeOutlineLabel({
					Position = UDim2.fromOffset(88, 44),
					Size = UDim2.fromOffset(400, 32),
					Text = Computed(function()
						local state = State.GetSnapshot()
						if not state.ownsAutoRebirth then
							return "Rebirth automatically at required level"
						end
						return if state.autoRebirthEnabled
							then "Active — rebirths the moment you qualify"
							else "Paused — keep your level for the obby"
					end),
					TextColor3 = Color3.fromRGB(255, 214, 120),
					TextXAlignment = Enum.TextXAlignment.Left,
					MaxTextSize = 24,
					ZIndex = 44,
				}),
				-- Nút thứ ba: cùng khuôn với nút Rebirth và Skip ở trên. Khai lệch +4 để
				-- mép ngoài viền vẫn rơi đúng (624, 12) như bản cũ.
				Theme.MakeSurface({
					ClassName = "TextButton",
					Position = UDim2.fromOffset(568, 16),
					Size = UDim2.fromOffset(186, 52),
					ZIndex = 45,
					Radius = 12,
					Border = 4,
					Color = Computed(function()
						local state = State.GetSnapshot()
						if not state.ownsAutoRebirth then
							return Color3.fromRGB(236, 64, 156)
						end
						return if state.autoRebirthEnabled
							then Color3.fromRGB(64, 200, 96)
							else Color3.fromRGB(96, 96, 110)
					end),
					ColorB = Computed(function()
						local state = State.GetSnapshot()
						if not state.ownsAutoRebirth then
							return Color3.fromRGB(158, 26, 100)
						end
						return if state.autoRebirthEnabled
							then Color3.fromRGB(30, 132, 58)
							else Color3.fromRGB(58, 58, 70)
					end),
					Zoom = { Hovered = State.rebirthAutoHovered, Scale = 1.08 },
					Activated = function()
						local state = State.GetSnapshot()
						if not state.ownsAutoRebirth then
							if AUTO_REBIRTH_PASS_ID <= 0 then
								Toast.Show("Set Auto-Rebirth Pass ID!")
								return
							end
							MarketplaceService:PromptGamePassPurchase(localPlayer, AUTO_REBIRTH_PASS_ID)
							return
						end
						GamePackets.requestAutoRebirthToggle.send({
							enabled = not state.autoRebirthEnabled,
						})
					end,
					MouseEnter = function()
						State.rebirthAutoHovered:set(true)
					end,
					MouseLeave = function()
						State.rebirthAutoHovered:set(false)
					end,
					Content = function(zoom)
						return {
							Theme.MakeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = Computed(function()
									local state = State.GetSnapshot()
									if not state.ownsAutoRebirth then
										return autoRebirthPriceText:get()
									end
									return if state.autoRebirthEnabled then "ON" else "OFF"
								end),
								Zoom = zoom,
								MaxTextSize = 34,
								ZIndex = 47,
							}),
						}
					end,
				}),
			},
		}),
	}
end

function RebirthModal.Build()
	return ModalShell.Build({
		Id = "rebirth",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		--[[
			KHÔNG `Scale` (bỏ 2026-08-16). `UIScale` co CẢ độ dày viền: 4 × 0.85 = 3.40px, trong
			khi mọi modal khác là 4.00px — đo trong Studio thấy đúng 10 phần tử 3.40px và tất cả
			đều thuộc modal này. User đã chốt lấy viền của Cosmetic (4.00) làm chuẩn cho cả HUD,
			nên modal nào còn `UIScale` là modal đó tự phá chuẩn.

			920×668 vẽ 1:1 vẫn lọt màn hình (trần là 700 — xem `Tokens.SAFE_CONTENT_HEIGHT`).
		]]
		PanelColor = Color3.fromRGB(40, 0, 0),
		HeaderColor = Color3.fromRGB(255, 230, 80),
		HeaderColorB = Color3.fromRGB(255, 150, 10),
		Icon = Theme.UI_ASSETS.Lightning,
		Title = "Rebirth",
		OnClose = Manager.CloseRebirth,
		Content = buildContent(),
	})
end

return RebirthModal
