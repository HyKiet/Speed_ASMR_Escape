--!strict
--[[
	StarterPackModal.luau — chi tiết gói "Rookie Rocket", mở từ ICON góc phải trên
	(`Hud/StarterPackCard`). Tách khỏi icon ngày 2026-08-12: HUD chỉ gây tò mò (hình gói,
	−90%, đồng hồ), còn chỗ bày hàng và nút mua nằm ở đây.

	── BỐ CỤC BÁN HÀNG ──────────────────────────────────────────────────────────────────
	  1. Header vàng chuẩn của game + huy hiệu "−90%" và đồng hồ ngay dưới: người chơi mở ra
	     là gặp lý do vội trước, danh sách hàng sau.
	  2. Bốn THẺ phần thưởng (không phải bốn dòng chữ): mỗi món một icon, mắt đếm được "bốn
	     món" trong một nhịp nhìn, thay vì phải đọc.
	  3. Nút mua to hết bề ngang, giá gốc gạch ngang đứng NGAY CẠNH giá thật — tách hai con
	     số ra hai đầu là mất luôn cảm giác "rẻ".

	Modal TỰ ĐÓNG khi gói hết hiệu lực (mua xong / hết giờ / server tắt gói): `Shared.Available`
	là nguồn sự thật duy nhất, dùng chung với icon. Không có nó thì mua xong modal vẫn nằm đó
	mời mua tiếp.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local RobuxPrice = require(ReplicatedStorage.Shared.Util.RobuxPrice)
local StarterPackConfig = require(ReplicatedStorage.Shared.Config.Economy.StarterPack)
local TrailsConfig = require(ReplicatedStorage.Shared.Config.Economy.Trails)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local Shared = require(script.Parent.Parent.Hud.StarterPackShared)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Manager = require(script.Parent.Manager)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Observer = Fusion.Observer

local StarterPackModal = {}

local PANEL_WIDTH = 760
local PANEL_HEIGHT = 560

--[[
	Trail độc quyền của gói — TÊN và ẢNH đọc thẳng từ `Config/Economy/Trails`, không gõ tay.
	Thẻ này và hàng tương ứng trong CosmeticModal phải là CÙNG một món trong mắt người chơi:
	trước đây thẻ ghi "Rookie Trail" + icon trail chung, còn menu Cosmetics ghi "Rookie Rocket"
	+ ảnh riêng — mua xong đi tìm trong tủ đồ thì không nhận ra mình vừa mua cái gì.
]]
local function findTrail(id: string)
	for _, trail in TrailsConfig do
		if trail.id == id then
			return trail
		end
	end
	return nil
end

local ROOKIE_TRAIL = findTrail(StarterPackConfig.TRAIL_ID)
local ROOKIE_TRAIL_NAME = if ROOKIE_TRAIL then ROOKIE_TRAIL.name else "Rookie Rocket"
local ROOKIE_TRAIL_ICON = (ROOKIE_TRAIL and ROOKIE_TRAIL.icon) or Theme.UI_ASSETS.Trail

-- Một thẻ phần thưởng: icon trên, tên món ở giữa, dòng phụ nhỏ bên dưới.
local function makeRewardCard(
	position: UDim2,
	icon: string,
	title: string,
	subtitle: string,
	colorA: Color3,
	colorB: Color3
)
	return New("Frame")({
		BackgroundColor3 = colorA,
		ClipsDescendants = true,
		Position = position,
		Size = UDim2.fromOffset(164, 178),
		ZIndex = 43,
		[Children] = {
			Theme.MakeCorner(16),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
			Theme.MakeGradient(colorA, colorB),
			Theme.MakeStandardStuds(16, 45),
			New("ImageLabel")({
				BackgroundTransparency = 1,
				Image = icon,
				Position = UDim2.fromOffset(46, 14),
				Size = UDim2.fromOffset(72, 72),
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(8, 94),
				Size = UDim2.fromOffset(148, 44),
				Text = title,
				TextColor3 = Color3.fromRGB(255, 245, 128),
				MaxTextSize = 28,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(8, 140),
				Size = UDim2.fromOffset(148, 28),
				Text = subtitle,
				TextColor3 = Color3.fromRGB(255, 226, 216),
				MaxTextSize = 18,
				ZIndex = 46,
			}),
		},
	})
end

--[[
	"−90%" ngồi trong header, cạnh nút X: nó là lý do mở modal, không được lẫn xuống giữa danh
	sách hàng. Vì có nó chen vào nên header này là chỗ DUY NHẤT phải truyền `TitleWidth` — mọi
	modal khác để `ModalShell` tự tính bề rộng tiêu đề tới sát nút X.
]]
local function buildDiscountBadge()
	return Theme.MakeOutlineLabel({
		Position = UDim2.fromOffset(524, 11),
		Size = UDim2.fromOffset(120, 62),
		Rotation = -6,
		Text = `-{StarterPackConfig.DISCOUNT_PERCENT}%`,
		TextColor3 = Color3.fromRGB(226, 40, 96),
		TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
		MaxTextSize = 46,
		ZIndex = Tokens.Z.MODAL_HEADER_CONTENT,
	})
end

local function buildContent(): { any }
	local buyHovered = State.starterPackBuyHovered

	return {

		-- Đồng hồ đếm lùi: cùng một con số với icon trên HUD (chung `StarterPackShared`).
		Theme.MakeSurface({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(PANEL_WIDTH * 0.5, 104),
			Size = UDim2.fromOffset(420, 46),
			ZIndex = 43,
			Radius = 12,
			Border = Tokens.BORDER,
			Studs = false,
			Color = Color3.fromRGB(26, 14, 24),
			FillTransparency = 0.15,
			Content = {
				Theme.MakeOutlineLabel({
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, 1),
					Text = Computed(function()
						return `OFFER ENDS IN {Shared.FormatCountdown(Shared.SecondsLeft())}`
					end),
					TextColor3 = Color3.fromRGB(255, 236, 140),
					MaxTextSize = 30,
					ZIndex = 44,
				}),
			},
		}),

		makeRewardCard(
			UDim2.fromOffset(28, 168),
			Theme.UI_ASSETS.Trophy,
			`+{Theme.FormatInteger(StarterPackConfig.WINS)}`,
			"Wins instantly",
			Color3.fromRGB(255, 186, 69),
			Color3.fromRGB(226, 112, 24)
		),
		makeRewardCard(
			UDim2.fromOffset(208, 168),
			Theme.UI_ASSETS.Shoe,
			`x{StarterPackConfig.SPEED_MULTIPLIER} Speed`,
			"forever",
			Color3.fromRGB(120, 214, 255),
			Color3.fromRGB(32, 108, 214)
		),
		makeRewardCard(
			UDim2.fromOffset(388, 168),
			Theme.UI_ASSETS.Spin,
			`{StarterPackConfig.SPINS} Spins`,
			"Speed Roulette",
			Color3.fromRGB(196, 142, 255),
			Color3.fromRGB(104, 40, 200)
		),
		makeRewardCard(
			UDim2.fromOffset(568, 168),
			ROOKIE_TRAIL_ICON,
			ROOKIE_TRAIL_NAME,
			"Trail — EXCLUSIVE",
			Color3.fromRGB(255, 118, 150),
			Color3.fromRGB(190, 26, 76)
		),

		Theme.MakeOutlineLabel({
			Position = UDim2.fromOffset(30, 360),
			Size = UDim2.fromOffset(PANEL_WIDTH - 60, 30),
			Text = `Also includes x2 Wins for {StarterPackConfig.BOOST_WINS_SECONDS // 60} minutes — one purchase, once only.`,
			TextColor3 = Color3.fromRGB(255, 226, 226),
			MaxTextSize = 24,
			ZIndex = 42,
		}),

		-- Nút mua: giá gốc gạch ngang (RichText <s>) đứng cạnh giá thật.
		-- `MakeSurface` + `Zoom`: viền và chữ phóng cùng nhịp, nở đều 4 góc.
		Theme.MakeSurface({
			ClassName = "TextButton",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(PANEL_WIDTH * 0.5, 412),
			Size = UDim2.fromOffset(560, 92),
			ZIndex = 45,
			Radius = 16,
			Border = 4,
			Color = Computed(function()
				return if buyHovered:get() then Color3.fromRGB(150, 255, 186) else Color3.fromRGB(120, 245, 160)
			end),
			ColorB = Color3.fromRGB(28, 160, 78),
			Zoom = { Hovered = buyHovered, Scale = 1.05 },
			Activated = function()
				GamePackets.requestStarterPackPurchase.send({})
			end,
			MouseEnter = function()
				buyHovered:set(true)
			end,
			MouseLeave = function()
				buyHovered:set(false)
			end,
			Content = function(zoom)
				return {
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(24, 26),
						Size = UDim2.fromOffset(180, 40),
						RichText = true,
						Text = `<s>{RobuxPrice.GLYPH}{StarterPackConfig.ORIGINAL_PRICE_ROBUX}</s>`,
						TextColor3 = Color3.fromRGB(232, 232, 232),
						TextXAlignment = Enum.TextXAlignment.Left,
						Zoom = zoom,
						MaxTextSize = 34,
						ZIndex = 48,
					}),
					-- Giá thật để TRẮNG (không dùng `MakePriceLabel`): nền nút đã là xanh
					-- Robux rồi, chữ xanh trên nền xanh thì đọc không ra.
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(216, 16),
						Size = UDim2.fromOffset(320, 60),
						Text = `GET IT — {RobuxPrice.GLYPH}{StarterPackConfig.PRICE_ROBUX}`,
						TextXAlignment = Enum.TextXAlignment.Right,
						Zoom = zoom,
						MaxTextSize = 46,
						ZIndex = 48,
					}),
				}
			end,
		}),
	}
end

function StarterPackModal.Build()
	--[[
		Gói hết hiệu lực trong lúc modal đang mở (mua xong, hoặc đồng hồ chạy về 0) thì đóng
		luôn. `Observer` chứ không phải `Computed`: đây là một HÀNH ĐỘNG (gọi Manager), không
		phải một giá trị được vẽ ra — nhét task.spawn vào Computed là Fusion chạy nó lại mỗi
		lần re-evaluate.
	]]
	State.sweeper:Add(Observer(Shared.Available):onChange(function()
		if not Shared.Available:get() and State.starterPackModalVisible:get() then
			Manager.CloseStarterPack()
		end
	end))

	return ModalShell.Build({
		Id = "starterPack",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(58, 18, 34),
		PanelTransparency = 0.15,
		HeaderColor = Color3.fromRGB(255, 238, 77),
		HeaderColorB = Color3.fromRGB(255, 162, 28),
		Icon = Theme.UI_ASSETS.StarterPack,
		Title = "Starter Pack",
		-- Chừa chỗ cho nhãn "−90%" bắt đầu ở x = 524.
		TitleWidth = 410,
		HeaderExtra = { buildDiscountBadge() },
		OnClose = Manager.CloseStarterPack,
		Content = buildContent(),
	})
end

return StarterPackModal
