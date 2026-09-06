--!strict
-- Cụm nút menu trái (Wins counter + Rebirth/Shop/Cosmetics/Teleport).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Responsive = require(script.Parent.Parent.Responsive)
local UIAnchors = require(script.Parent.Parent.UIAnchors)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Manager = require(script.Parent.Parent.Modals.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

local SoundService = game:GetService("SoundService")

local LeftMenu = {}

--[[
	══ CỠ Ô MENU TRÁI — MỘT CHỖ DUY NHẤT ═══════════════════════════════════════════════════

	Trước đây năm con số 254 / 478 / 610 / 122 / 112 nằm rải rác sáu chỗ trong file, và chúng
	phụ thuộc lẫn nhau (bề rộng cột = 2 ô + khe, chiều cao lưới = 4 hàng + 3 khe…). Đổi cỡ ô
	là phải sửa tay cả sáu, sót một chỗ thì cụm menu lệch hoặc bị cắt.

	Giờ chỉ `CELL_W`/`CELL_H` là số thật, phần còn lại SUY RA. User 2026-08-16 xin "to một chút":
	122×112 → 134×124 (+10%).

	⚠️ `COLUMN_H` dùng cho cả phép căn giữa lẫn `Theme.GetRaiseOffset` trên màn hình nhỏ — nó
	PHẢI bằng chiều cao thật của cụm, nếu không cụm menu bị đẩy lệch trên tablet/điện thoại.
]]
local CELL_W, CELL_H = 134, 124
local CELL_GAP = 10
local COLUMN_W = CELL_W * 2 + CELL_GAP
-- Chiều cao hai dòng đếm (Wins + Rebirths) nằm phía trên lưới.
local GRID_TOP = 136
--[[
	⚠️ 4 → 3 HÀNG (2026-08-21). Lưới có ĐÚNG 6 nút (Daily · Rebirth · Shop · Cosmetics ·
	Teleport · Codes) trên 2 cột ⇒ 3 hàng. Số 4 là tàn dư từ hồi còn nút Feedback (gỡ
	2026-07-29) và nó khai khống chiều cao cụm đúng một hàng: đo được ở Studio, khung menu
	trái cao 662 design px trong khi nội dung thật chỉ tới 528 — thừa 134 px trống ở đáy.

	Không ai nhìn ra vì khung trong suốt. Nhưng nó là con số mà cột phải soi gương theo để
	căn giữa, nên sai ở đây là cột phải lệch xuống 67 px và trông "không đối xứng".
]]
-- Daily và Emotes đã chuyển lên hàng icon cạnh Spin, nên menu trái trở lại đúng 3 hàng.
local GRID_ROWS = 3
local GRID_H = CELL_H * GRID_ROWS + CELL_GAP * (GRID_ROWS - 1)
local COLUMN_H = GRID_TOP + GRID_H

-- Cột phải soi gương theo chiều cao này (xem `Theme.RightColumnOrigin`). Ghi vào Theme thay vì
-- chép số sang bên đó: chiều cao cụm suy ra từ cỡ ô, đổi cỡ ô là hai bên phải đổi cùng lúc.
Theme.LEFT_MENU_HEIGHT = COLUMN_H

local winsScaleGoal = Value(1)

local winsScale = Fusion.Tween(winsScaleGoal, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
local winsContainer: Frame? = nil

local lastWins = 0
local function setupWinsObserver()
	Fusion.Observer(Computed(function()
		return State.GetSnapshot().totalWins
	end)):onChange(function()
		local currentWins = State.GetSnapshot().totalWins
		if lastWins > 0 and currentWins > lastWins and winsContainer and winsContainer.Parent then
			-- 1. Scale pulse
			winsScaleGoal:set(1.22)
			task.delay(0.2, function()
				winsScaleGoal:set(1)
			end)

			-- 2. Chime sound
			-- ⚠️ ID cũ 131686958279369 KHÔNG PHẢI Audio — chính là ảnh icon "Small Wins Pack"
			-- trong Theme.SHOP_CATALOG.products (copy nhầm), sound câm suốt không log lỗi.
			-- Dùng lại Theme.UI_ASSETS.CelebrationSound cho nhất quán với BoostCelebration.
			task.spawn(function()
				local sound = Instance.new("Sound")
				sound.SoundId = Theme.UI_ASSETS.CelebrationSound
				sound.Volume = 0.55
				sound.PlaybackSpeed = 1.25
				sound.Parent = SoundService
				sound.PlayOnRemove = true
				sound:Destroy()
			end)

			-- ĐÃ GỠ (2026-08-07, yêu cầu user): popup "+N Wins!" bay lên cạnh huy hiệu.
			-- Nó trùng lặp với thẻ WinsFlight giữa màn hình + toast trên đỉnh (3 thông báo cho
			-- cùng một sự kiện), và còn đè lên chính con số Wins đang nhảy.
		end
		lastWins = currentWins
	end)
end

--[[
	NEO CỦA CẢ CỤM — MỘT ĐỊNH NGHĨA DUY NHẤT.

	Trước 2026-08-17 công thức vị trí bị CHÉP ra hai chỗ (`Build` và `GetWinsBadgeCenter`), mỗi
	chỗ một nhánh `if scale < 0.75 then <công thức mobile> else <toạ độ PC gõ tay 28/236>`, kèm
	comment "sửa một chỗ phải sửa cả hai". Giờ cả hai đọc chung bảng này, và luật neo nằm trong
	`Responsive` chứ không nằm trong từng cụm HUD.

	Cụm bám MÉP TRÁI màn hình, cách 28 design px — đúng như bản vẽ 1920×1080, và trên máy 16:9 nó
	ra đúng x = 28. Trên máy rộng hơn, cụm đi theo mép trái thật thay vì đứng yên giữa màn hình
	(xem `HUD/Responsive`, quy tắc 2).

	── CHIỀU DỌC: NEO MÉP TRÊN, KHÔNG CĂN GIỮA (user 2026-08-17: "vướng nút di chuyển") ───────
	Đo trên máy cảm ứng (viewport 801×392): cần điều khiển của Roblox chiếm y 241..315 px thật,
	trong khi cụm này căn giữa thì trải từ 126 tới 332 — hai hàng nút cuối (Teleport/Codes) nằm
	đè lên vòng joystick.

	Neo mép trên với lề 100 kéo cụm lên 100 design px (PC: y 236 → 136; điện thoại: đáy cụm từ
	332 lên 297 px thật). ⚠️ KHÔNG kéo lên được nữa: `Screen().Top` đã gồm topbar, hạ lề xuống
	dưới ~60 là huy hiệu Wins bắt đầu chạm topbar trên điện thoại.

	⚠️ Cụm cao 632 design (≈206 px thật ở tỉ lệ 0.33) mà khoảng trống phía trên joystick chỉ có
	≈175 px — nên KHÔNG có giá trị lề nào tránh joystick hoàn toàn. Muốn hết hẳn thì phải rút bớt
	số hàng nút, đó là đổi thiết kế chứ không phải chỉnh responsive.
]]
--[[
	Neo phải TÍNH LẠI MỖI LẦN GỌI, không được là bảng hằng nữa (2026-08-21).

	`MarginY` giờ đến từ `Theme.ClusterTopMargin()` — mốc dọc DÙNG CHUNG với cột phải, để hai
	bên màn hình luôn bắt đầu cùng một độ cao ("đối xứng", user chốt). Giá trị đó phụ thuộc
	tỉ lệ màn hình và chiều cao topbar nên KHÔNG chốt được lúc require.
]]
local function anchor()
	return {
		X = "left" :: "left",
		Y = "top" :: "top",
		Width = COLUMN_W,
		Height = COLUMN_H,
		--[[
			⚠️ HẰNG SỐ 28, KHÔNG phải `Theme.EdgeMargin()` (user chốt 2026-08-22).
			Lề tự-tính chỉ áp cho HÀNG NGANG trên cùng — thử áp cho cả menu trái/cột phải một
			vòng thì hai cụm bên bị đẩy 28 → 57 px và user bác ngay: "menu trái phải giữ nguyên
			bản cũ". Hai cụm bên đã cân với vùng chạm ngón cái từ 2026-08-17, đừng đụng vào.
		]]
		MarginX = Theme.EDGE_MARGIN,
		MarginY = Theme.ClusterTopMargin(),
	}
end

--[[
	VỊ TRÍ TÂM HUY HIỆU WINS trong toạ độ thiết kế 1920×1080.

	`WinsFlight` cần điểm này làm ĐÍCH cho thẻ chúc mừng bay tới. Không đọc
	`winsContainer.AbsolutePosition` vì đó là pixel màn hình thật, còn thẻ bay nằm trong lớp
	đã bị `UIScale` co lại — hai hệ toạ độ khác nhau, ghép vào là lệch đúng bằng hệ số scale.
	Lấy đúng neo của cụm rồi cộng offset của icon cúp (đặt tại (0,3), cỡ 56×56 ⇒ tâm (28, 31)).
]]
function LeftMenu.GetWinsBadgeCenter(): Vector2
	local origin = Responsive.AnchorPos(anchor())
	return Vector2.new(origin.X.Offset + 28, origin.Y.Offset + 31)
end

-- Nhịp phồng của huy hiệu Wins. `WinsFlight` gọi đúng lúc thẻ bay CHẠM huy hiệu, để cú nảy
-- trùng khoảnh khắc va chạm (lệch vài chục ms là mắt đọc ra thành hai sự kiện rời rạc).
function LeftMenu.PulseWins()
	winsScaleGoal:set(1.34)
	task.delay(0.24, function()
		winsScaleGoal:set(1)
	end)
end

local function makeWinsDisplay()
	local frame = New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(COLUMN_W, 62),
		ZIndex = 12,
		[Children] = {
			New("UIScale")({
				Scale = winsScale,
			}),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = Theme.UI_ASSETS.Trophy,
				Position = UDim2.fromOffset(0, 3),
				Size = UDim2.fromOffset(56, 56),
				ZIndex = 12,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(62, 4),
				Size = UDim2.fromOffset(182, 54),
				Text = Computed(function()
					return Theme.FormatInteger(State.GetSnapshot().totalWins)
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 40,
				ZIndex = 13,
			}),
		},
	})
	winsContainer = frame
	setupWinsObserver()
	return frame
end

local function makeRebirthsDisplay()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.fromOffset(COLUMN_W, 62),
		[Children] = {
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = "rbxassetid://103236589125008",
				Position = UDim2.fromOffset(0, 3),
				Size = UDim2.fromOffset(56, 56),
				ZIndex = 12,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(62, 4),
				Size = UDim2.fromOffset(182, 54),
				Text = Computed(function()
					return Theme.FormatInteger(State.GetSnapshot().rebirths)
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				MaxTextSize = 40,
				ZIndex = 13,
			}),
		},
	})
end

function LeftMenu.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		ZIndex = 10,
		Position = Computed(function()
			return Responsive.AnchorPos(anchor())
		end),
		Size = UDim2.fromOffset(COLUMN_W, COLUMN_H),
		[Children] = {
			makeWinsDisplay(),
			makeRebirthsDisplay(),
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, GRID_TOP),
				Size = UDim2.fromOffset(COLUMN_W, GRID_H),
				ZIndex = 10,
				[Children] = {
					--[[
						CỠ Ô ĐO TỪ ẢNH THAM CHIẾU (user gửi 2026-08-15, ảnh chụp ngang 1920): nút
						rộng ~122, cao ~112, khe ngang ~10, khe dọc ~10. Bản cũ 130×130 — to hơn
						khoảng 8% mỗi chiều nên cụm menu ăn nhiều màn hình hơn hẳn game tham chiếu,
						và ô VUÔNG khiến chữ dài ("Cosmetics", "Teleport") phải co nhỏ lại.

						Ô hơi chữ nhật (rộng > cao) cho chữ thêm chỗ mà không tốn thêm chiều cao.
						Nội dung nút đo theo TỈ LỆ ô (xem `Theme.MakeMenuButton`) nên đổi hai con số
						dưới đây là đủ — không phải chỉnh gì trong Theme.

						Số đo thật nằm ở `CELL_W`/`CELL_H` đầu file; mọi kích thước khác suy ra từ đó.
					]]
					New("UIGridLayout")({
						CellPadding = UDim2.fromOffset(CELL_GAP, CELL_GAP),
						CellSize = UDim2.fromOffset(CELL_W, CELL_H),
						FillDirectionMaxCells = 2,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					-- RED DOT: chỉ 2 nút này có, vì chỉ 2 việc này là "người chơi đang bỏ lỡ
					-- thứ MIỄN PHÍ đã sẵn sàng". Shop/Cosmetics/Teleport/Codes luôn có thứ để
					-- bấm nên gắn chấm vào đó là chấm đỏ vĩnh viễn — mắt sẽ học cách lờ đi và
					-- cả hệ thống mất tác dụng.
					-- Đăng ký điểm neo để tutorial chiếu spotlight vào ĐÚNG ô này (xem
					-- `HUD/UIAnchors`): một dòng ngay cạnh chỗ dựng nút, không phải đi dò cây.
					UIAnchors.Keep(
						"questButton",
						Theme.MakeMenuButton(
							"Quest",
							Theme.UI_ASSETS.Quest,
							Color3.fromRGB(255, 203, 54),
							Color3.fromRGB(225, 116, 28),
							Manager.ToggleQuest,
							State.questClaimable
						)
					),
					Theme.MakeMenuButton(
						"Rebirth",
						Theme.UI_ASSETS.Rebirth,
						Color3.fromRGB(255, 230, 80),
						Color3.fromRGB(255, 150, 10),
						Manager.ToggleRebirth,
						-- Đã đủ level để rebirth mà chưa bấm.
						Computed(function()
							return State.GetSnapshot().canRebirth == true
						end)
					),
					-- Shop KHÔNG gắn chấm đỏ (lý do ngay trên) nhưng vẫn là nút cần được nhìn
					-- thấy nhất, nên dùng hào quang xoay: hút mắt bằng CHUYỂN ĐỘNG chứ không
					-- phải bằng tín hiệu "bạn đang bỏ lỡ thứ gì đó" — hào quang không nói dối
					-- khi người chơi chẳng bỏ lỡ gì cả. Chỉ MỘT nút được bật.
					Theme.MakeMenuButton(
						"Shop",
						Theme.UI_ASSETS.Shop,
						Color3.fromRGB(255, 110, 80),
						Color3.fromRGB(255, 195, 55),
						Manager.ToggleShop,
						nil,
						true
					),
					Theme.MakeMenuButton(
						"Cosmetics",
						Theme.UI_ASSETS.Cosmetics,
						Color3.fromRGB(186, 90, 255),
						Color3.fromRGB(100, 50, 210),
						function()
							Manager.ToggleCosmetic("trail")
						end,
						--[[
							Chấm đỏ THỨ BA của lưới, và nó không phá luật "chỉ gắn chấm vào thứ
							MIỄN PHÍ đang bị bỏ lỡ" ở khối trên: aura Legendary 1% vừa rơi vào tay
							người chơi và họ chưa nhìn thấy nó lần nào. Chấm tắt ngay khi mở tab
							AURAS, nên nó không bao giờ thành chấm đỏ vĩnh viễn.
						]]
						Computed(function()
							return State.auraUnlockDot:get()
						end)
					),
					Theme.MakeMenuButton(
						"Teleport",
						Theme.UI_ASSETS.Teleport,
						Color3.fromRGB(68, 210, 255),
						Color3.fromRGB(30, 120, 210),
						Manager.ToggleTeleport
					),
					Theme.MakeMenuButton(
						"Codes",
						Theme.UI_ASSETS.Code,
						Color3.fromRGB(72, 220, 130),
						Color3.fromRGB(26, 140, 72),
						Manager.ToggleCode
					),
				},
			}),
		},
	})
end

return LeftMenu
