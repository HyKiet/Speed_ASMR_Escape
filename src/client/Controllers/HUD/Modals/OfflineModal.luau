--!strict
--[[
	OfflineModal — "Offline Speed": nhận số Speed treadmill đã cày lúc người chơi vắng mặt.

	══ VÌ SAO CÓ NÚT DOUBLE IT ═════════════════════════════════════════════════════════════
	Khoảnh khắc người chơi vừa quay lại và đang NHÌN con số của chính mình là điểm bán hàng
	tự nhiên nhất trong cả game: món hàng đã có sẵn giá trị hiển thị, không cần thuyết phục.
	Bản đầu của tính năng cộng thẳng Speed rồi hiện một banner — tức là vứt đi đúng khoảnh
	khắc đó.

	Giá + lý do chọn 19 R$ (chứ không phải 9) nằm ở `Config/Economy/Products`.

	══ ⚠️ BA CHỐT AN TOÀN ══════════════════════════════════════════════════════════════════

	1. CLIENT KHÔNG BAO GIỜ GỬI CON SỐ. `requestOfflineClaim` là gói rỗng; số tiền nằm ở
	   `PendingOfflineSpeed` trong profile và chỉ server đọc. `State.offlineSpeed` ở đây thuần
	   để VẼ.

	2. NÚT KHOÁ NGAY KHI BẤM (`busy`). Không có chốt này thì bấm nhanh hai lần gửi hai gói —
	   server có chặn (xoá pending trước khi cộng) nhưng người chơi vẫn thấy modal đứng im một
	   nhịp rồi mới đóng, đọc như là đơ.

	3. `productId = 0` ⇒ CHƯA TẠO trên Creator Dashboard. Bấm Double It sẽ ra toast thay vì
	   hộp thoại mua — cùng cách xử lý với `SPIN_PACKS` hồi chưa có ID. KHÔNG được để nó gọi
	   `PromptProductPurchase(0)`: hộp thoại lỗi của Roblox không nói được gì cho người chơi.

	══ NÚT DOUBLE ẨN KHI PHẦN THƯỞNG QUÁ NHỎ ═══════════════════════════════════════════════
	Dưới `OFFLINE_DOUBLE_MIN_SPEED` thì chỉ hiện Claim, và Claim giãn ra chiếm trọn bề ngang.
	Chào bán 19 R$ để nhân đôi 500 Speed vừa xúc phạm vừa phản tác dụng: nó dạy người chơi
	rằng nút Double không đáng bấm, và bài học đó dính luôn cho lần thật sự đáng bấm.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local OfflineConfig = require(ReplicatedStorage.Shared.Config.OfflineEarnings)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Products = require(ReplicatedStorage.Shared.Config.Economy.Products)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)

local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

local localPlayer = Players.LocalPlayer

local OfflineModal = {}

local PANEL_WIDTH = 620
--[[
	Chiều cao = header + 4 khối nội dung + lề đáy.

	⚠️ MỌI toạ độ Y dưới đây tính TỪ MÉP TRÊN VỎ, không phải từ dưới header. `ModalShell` đặt
	header CHỒNG LÊN phần trên của panel (`Tokens.MODAL.HEADER_HEIGHT` = 84), nên nội dung khai
	ở y < 84 sẽ bị header nuốt — đã dính đúng lỗi này lúc nghiệm thu 2026-08-27: dòng "While
	offline you made:" biến mất và "You were away…" bị cắt cụt một nửa.

	`CONTENT_TOP` là con số chống lại chuyện đó. Thêm khối mới thì cộng dồn từ nó.
]]
local CONTENT_TOP = 100
local PANEL_HEIGHT = 508

-- Chốt an toàn 2: khoá nút ngay khi bấm, mở lại khi modal đóng.
local busy = Value(false)

local function durationText(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return `You were away {hours}h {minutes}m`
	end
	return `You were away {minutes}m`
end

local function claim()
	if busy:get() then
		return
	end
	busy:set(true)
	GamePackets.requestOfflineClaim.send({})
end

local function double()
	if busy:get() then
		return
	end
	-- Chốt an toàn 3: chưa có Product ID thì nói thẳng, đừng mở hộp thoại lỗi của Roblox.
	if Products.OFFLINE_DOUBLE_PRODUCT_ID <= 0 then
		Toast.Show("Double It chưa có Product ID!", "error")
		return
	end
	MarketplaceService:PromptProductPurchase(localPlayer, Products.OFFLINE_DOUBLE_PRODUCT_ID)
end

local function buildContent(): { any }
	local claimHovered = State.offlineClaimHovered
	local doubleHovered = State.offlineDoubleHovered

	-- Có đủ lớn để chào bán Double không (xem khối lý do ở đầu file).
	local showDouble = Computed(function()
		--[[
			NGƯỠNG TƯƠNG ĐỐI (GDD 3.0 §7.7). Số tuyệt đối 5.000 Speed là vô nghĩa với người chơi
			R10 — nút chào bán 6 R$ cho một phần thưởng không đáng nhìn, và một khi họ học được
			nút Double không đáng bấm thì lần thật sự đáng bấm cũng bị bỏ qua.

			Giữ CẢ sàn tuyệt đối: người chơi mới có quãng đường rất ngắn nên riêng phần trăm sẽ
			cho nút hiện ra với vài trăm Speed.
		]]
		local reward = State.offlineSpeed:get()
		if reward < Products.OFFLINE_DOUBLE_MIN_SPEED then
			return false
		end
		local snapshot = State.GetSnapshot()
		local climb = math.max(0, Constants.GetCumulativeXP(snapshot.requiredRebirthLevel) - snapshot.speed)
		return climb <= 0 or reward >= climb * Products.OFFLINE_DOUBLE_MIN_REBIRTH_FRACTION
	end)

	return {
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(0, CONTENT_TOP),
			Size = UDim2.fromOffset(PANEL_WIDTH, 46),
			Text = "While offline you made:",
			TextColor3 = Color3.fromRGB(255, 213, 74),
			MaxTextSize = 40,
			ZIndex = 45,
		}),

		-- Dòng phụ: nói rõ ĐÃ VẮNG BAO LÂU, để con số phía dưới có ngữ cảnh thay vì rơi từ trời.
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(0, CONTENT_TOP + 48),
			Size = UDim2.fromOffset(PANEL_WIDTH, 28),
			Text = Computed(function()
				return durationText(State.offlineSeconds:get())
			end),
			TextColor3 = Color3.fromRGB(198, 210, 240),
			MaxTextSize = 24,
			ZIndex = 45,
		}),

		-- Thẻ vàng: icon giày + con số. Đây là thứ duy nhất người chơi thật sự nhìn.
		Theme.MakeSurface({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(PANEL_WIDTH / 2, CONTENT_TOP + 90),
			Size = UDim2.fromOffset(468, 140),
			ZIndex = 44,
			Radius = 22,
			Border = Tokens.BORDER,
			Color = Color3.fromRGB(255, 214, 82),
			ColorB = Color3.fromRGB(238, 140, 20),
			Content = function()
				return {
					New("ImageLabel")({
						BackgroundTransparency = 1,
						Image = Theme.UI_ASSETS.Shoe,
						Position = UDim2.fromOffset(26, 24),
						Size = UDim2.fromOffset(92, 92),
						ZIndex = 46,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(130, 22),
						Size = UDim2.fromOffset(310, 96),
						Text = Computed(function()
							return `+{Format.Number(State.offlineSpeed:get())}`
						end),
						MaxTextSize = 76,
						ZIndex = 46,
					}),
				}
			end,
		}),

		-- CLAIM. Giãn hết bề ngang khi không có nút Double bên cạnh.
		Theme.MakeSurface({
			ClassName = "TextButton",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = Computed(function()
				return if showDouble:get()
					then UDim2.fromOffset(PANEL_WIDTH / 2 - 124, CONTENT_TOP + 254)
					else UDim2.fromOffset(PANEL_WIDTH / 2, CONTENT_TOP + 254)
			end),
			Size = Computed(function()
				return if showDouble:get() then UDim2.fromOffset(232, 86) else UDim2.fromOffset(400, 86)
			end),
			ZIndex = 45,
			Radius = 18,
			Border = Tokens.BORDER,
			Color = Computed(function()
				if busy:get() then
					return Color3.fromRGB(110, 130, 112)
				end
				return if claimHovered:get() then Color3.fromRGB(150, 250, 140) else Color3.fromRGB(108, 240, 130)
			end),
			ColorB = Computed(function()
				return if busy:get() then Color3.fromRGB(56, 72, 58) else Color3.fromRGB(30, 150, 72)
			end),
			Zoom = { Hovered = claimHovered, Scale = 1.06 },
			Activated = claim,
			MouseEnter = function()
				claimHovered:set(true)
			end,
			MouseLeave = function()
				claimHovered:set(false)
			end,
			Content = function(zoom)
				return {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						Text = "Claim",
						Zoom = zoom,
						MaxTextSize = 44,
						ZIndex = 47,
					}),
				}
			end,
		}),

		-- DOUBLE IT.
		Theme.MakeSurface({
			ClassName = "TextButton",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(PANEL_WIDTH / 2 + 124, CONTENT_TOP + 254),
			Size = UDim2.fromOffset(232, 86),
			Visible = showDouble,
			ZIndex = 45,
			Radius = 18,
			Border = Tokens.BORDER,
			Color = Computed(function()
				if busy:get() then
					return Color3.fromRGB(120, 96, 140)
				end
				return if doubleHovered:get() then Color3.fromRGB(216, 130, 255) else Color3.fromRGB(186, 90, 255)
			end),
			ColorB = Computed(function()
				return if busy:get() then Color3.fromRGB(66, 44, 84) else Color3.fromRGB(108, 26, 176)
			end),
			Zoom = { Hovered = doubleHovered, Scale = 1.06 },
			Activated = double,
			MouseEnter = function()
				doubleHovered:set(true)
			end,
			MouseLeave = function()
				doubleHovered:set(false)
			end,
			Content = function(zoom)
				return {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 1),
						--[[
							Giá đọc từ config: gõ tay ở đây là một ngày nào đó UI nói dối.

							`\u{E002}` là ký tự Robux trong font của Roblox — dùng đúng quy ước
							đang có ở ShopModal / RouletteModal / RebirthModal. Chữ "R$" viết
							thường dài hơn và làm nhãn xuống hàng trên nút rộng 232px.
						]]
						Text = `Double It \u{E002}{Products.OFFLINE_DOUBLE_PRICE_ROBUX}`,
						Zoom = zoom,
						MaxTextSize = 32,
						ZIndex = 47,
					}),
				}
			end,
		}),

		-- Dòng chân: nhắc cơ chế, để lần sau người chơi biết vì sao nên quay lại.
		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(0, CONTENT_TOP + 358),
			Size = UDim2.fromOffset(PANEL_WIDTH, 30),
			Text = `Your treadmill keeps running up to {math.floor(OfflineConfig.MAX_SECONDS / 3600)}h while you're away`,
			TextColor3 = Color3.fromRGB(198, 210, 240),
			MaxTextSize = 24,
			ZIndex = 45,
		}),
	}
end

--[[
	Gói `offlineEarnings` từ server. `speed = 0` là tín hiệu ĐÓNG (server vừa phát thưởng xong),
	nên client không phải tự đoán thời điểm — xem chú thích của packet trong `GamePackets`.
]]
function OfflineModal.OnState(data: { speed: number, seconds: number })
	State.offlineSpeed:set(math.floor(data.speed))
	State.offlineSeconds:set(math.floor(data.seconds))
	if data.speed > 0 then
		busy:set(false)
		Manager.OpenOffline()
	else
		Manager.CloseOffline()
	end
end

function OfflineModal.Build()
	return ModalShell.Build({
		Id = "offline",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(22, 34, 22),
		PanelTransparency = 0.18,
		HeaderColor = Color3.fromRGB(255, 205, 46),
		HeaderColorB = Color3.fromRGB(255, 150, 20),
		Icon = Theme.UI_ASSETS.Daily,
		Title = "Offline Speed",
		OnClose = Manager.CloseOffline,
		Content = buildContent(),
	})
end

return OfflineModal
