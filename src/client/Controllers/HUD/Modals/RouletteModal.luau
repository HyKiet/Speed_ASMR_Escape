--!strict
--[[
	RouletteModal.luau — Vòng quay May mắn (Speed Roulette).
	Bánh xe 8 ô (Config/Roulette) quay tròn giảm tốc dừng đúng ô trúng do SERVER quyết định.
	Vé: free 15 phút/vé (max 3, VIP rút còn 8 phút / cap 5), mua Robux 1/5/10 lượt.
	(Sửa 2026-08-23: dòng này từng ghi "Extra Spin gamepass quay đôi" — pass đó đã gỡ
	2026-07-31 và trong repo không còn logic quay đôi nào.)
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Products = require(ReplicatedStorage.Shared.Config.Economy.Products)
local ModalShell = require(script.Parent.Parent.Components.ModalShell)
local RouletteConfig = require(ReplicatedStorage.Shared.Config.Roulette)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)
local Tokens = require(script.Parent.Parent.Tokens)
local Toast = require(script.Parent.Parent.Toast)
local Manager = require(script.Parent.Manager)
local UIAnchors = require(script.Parent.Parent.UIAnchors)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Value = Fusion.Value

local localPlayer = Players.LocalPlayer

local SLOT_COUNT = #RouletteConfig.SLOTS
local SLOT_ANGLE = 360 / SLOT_COUNT
local WHEEL_SIZE = 400
local SLOT_RADIUS = 138
local SPIN_TIME = 4.2
local SPIN_EXTRA_TURNS = 4

local RouletteModal = {}

-- ⚠️ Đây là modal RỘNG NHẤT game. Nới nó thì phải nới `Tokens.SAFE_CONTENT_WIDTH` theo, nếu
-- không nó bị cắt mép trên máy màn hình nhỏ.
local PANEL_WIDTH = 1040
local PANEL_HEIGHT = 610

local wheelFrame: Frame? = nil
local currentRotation = 0
local spinRequestToken = 0

local function formatClock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", total // 60, total % 60)
end

-- ============================================================================
-- Wheel
-- ============================================================================

local function makeSlotCard(index: number)
	local slot = RouletteConfig.SLOTS[index]
	local theta = (index - 1) * SLOT_ANGLE
	local radians = math.rad(theta)
	local center = WHEEL_SIZE / 2
	local x = center + math.sin(radians) * SLOT_RADIUS
	local y = center - math.cos(radians) * SLOT_RADIUS

	return New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = slot.color,
		Position = UDim2.fromOffset(x, y),
		Rotation = theta,
		Size = UDim2.fromOffset(112, 84),
		ZIndex = 44,
		[Children] = {
			Theme.MakeCorner(12),
			Theme.MakeStroke(Color3.fromRGB(0, 0, 0), Tokens.BORDER),
			Theme.MakeGradientDynamic(slot.color, slot.color:Lerp(Color3.fromRGB(0, 0, 0), 0.4)),
			Theme.MakeStandardStuds(12, 45),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(4, 8),
				Size = UDim2.fromOffset(104, 46),
				Text = slot.label,
				MaxTextSize = 20,
				ZIndex = 46,
			}),
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(4, 52),
				Size = UDim2.fromOffset(104, 26),
				Text = slot.rarity,
				TextColor3 = Color3.fromRGB(255, 238, 70), -- Chữ % Vàng Neon Hoàng Gia rực rỡ nổi bật
				TextStrokeColor3 = Color3.fromRGB(15, 8, 28),
				MaxTextSize = 19,
				ZIndex = 46,
			}),
		},
	})
end

local function buildWheel()
	local slotCards: { any } = {
		Theme.MakeCorner(WHEEL_SIZE / 2),
		Theme.MakeStroke(Color3.fromRGB(255, 222, 89), 6),
		Theme.MakeGradient(Color3.fromRGB(64, 26, 120), Color3.fromRGB(18, 8, 44), 45),
	}
	for index = 1, SLOT_COUNT do
		table.insert(slotCards, makeSlotCard(index))
	end
	-- Tâm bánh xe
	table.insert(
		slotCards,
		New("ImageLabel")({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Theme.UI_ASSETS.Spin,
			Position = UDim2.fromOffset(WHEEL_SIZE / 2, WHEEL_SIZE / 2),
			Size = UDim2.fromOffset(86, 86),
			ZIndex = 47,
		})
	)

	local wheel = New("Frame")({
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(30, 12, 60),
		Position = UDim2.fromOffset(250, 318),
		Rotation = 0,
		Size = UDim2.fromOffset(WHEEL_SIZE, WHEEL_SIZE),
		ZIndex = 43,
		[Children] = slotCards,
	}) :: Frame
	wheelFrame = wheel

	-- Kim chỉ (tam giác đỏ trên đỉnh, không xoay theo bánh)
	local pointer = Theme.MakeOutlineLabel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(250, 92),
		Size = UDim2.fromOffset(60, 44),
		Text = "▼",
		TextColor3 = Color3.fromRGB(255, 64, 64),
		MaxTextSize = 44,
		ZIndex = 49,
	})

	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.fromOffset(500, 560),
		ZIndex = 42,
		[Children] = {
			wheel,
			pointer,
		},
	})
end

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local ROULETTE_SPIN_SOUND = "rbxassetid://116441689318579"

local function playTickSound()
	local sound = Instance.new("Sound")
	sound.SoundId = ROULETTE_SPIN_SOUND
	sound.Volume = 0.65
	sound.PlaybackSpeed = 1.0 + (math.random(-4, 4) / 100)
	sound.Parent = SoundService
	sound.PlayOnRemove = true
	sound:Destroy()
end

local function playWinSound()
	local sound = Instance.new("Sound")
	sound.SoundId = Theme.UI_ASSETS.CelebrationSound
	sound.Volume = 0.8
	sound.PlaybackSpeed = 1.15
	sound.Parent = SoundService
	sound.PlayOnRemove = true
	sound:Destroy()
end

local idleConn: RBXScriptConnection? = nil

local function startIdleRotation()
	if idleConn then
		return
	end
	idleConn = RunService.RenderStepped:Connect(function(dt)
		if wheelFrame and wheelFrame.Parent and not State.rouletteSpinning:get() then
			wheelFrame.Rotation = (wheelFrame.Rotation + 18 * dt) % 360
			currentRotation = wheelFrame.Rotation
		end
	end)
end

local function stopIdleRotation()
	if idleConn then
		idleConn:Disconnect()
		idleConn = nil
	end
end

-- Quay bánh xe dừng đúng ô slotIndex, xong gọi onDone.
local function animateSpin(slotIndex: number, onDone: () -> ())
	stopIdleRotation()
	local wheel = wheelFrame
	if not wheel then
		onDone()
		return
	end

	currentRotation = wheel.Rotation
	local targetTheta = (slotIndex - 1) * SLOT_ANGLE
	local desired = -targetTheta % 360
	local delta = (desired - (currentRotation % 360)) % 360
	local target = currentRotation + SPIN_EXTRA_TURNS * 360 + delta
	currentRotation = target

	local lastSlotPassed = math.floor(wheel.Rotation / SLOT_ANGLE)
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		if not wheel or not wheel.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end
		local currentSlot = math.floor(wheel.Rotation / SLOT_ANGLE)
		if currentSlot ~= lastSlotPassed then
			lastSlotPassed = currentSlot
			playTickSound()
		end
	end)

	local tween = TweenService:Create(
		wheel,
		TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Rotation = target }
	)
	tween.Completed:Once(function()
		if connection then
			connection:Disconnect()
		end
		playWinSound()
		onDone()
		task.delay(1.5, function()
			if not State.rouletteSpinning:get() and State.rouletteModalMounted:get() then
				startIdleRotation()
			end
		end)
	end)
	tween:Play()
end

-- HUDController gọi khi nhận spinResult từ server.
function RouletteModal.OnSpinResult(data: { slotIndex: number, rewardText: string, tickets: number })
	animateSpin(data.slotIndex, function()
		State.rouletteSpinning:set(false)
		local wonSlot = RouletteConfig.SLOTS[data.slotIndex]
		local text = if wonSlot then `Won {wonSlot.label}!` else data.rewardText
		State.rouletteResultText:set(text)

		--[[
			BANNER CHÚC MỪNG CHỈ DÀNH CHO FROZEN BLOOM (chốt lại 2026-08-14 sau khi user xem thử
			bản chúc mừng cho mọi ô).

			Bảy ô còn lại KHÔNG có banner, và đó là chủ ý: vòng quay được bấm liên tục, ô thường
			nhất rơi 25% số lượt. Cho nó cùng màn banner + confetti với jackpot 1% thì trong một
			buổi chơi người ta thấy màn ăn mừng vài chục lần — đúng cách làm cho lần trúng Frozen
			Bloom thật sự mất thiêng. Phần thưởng thường vẫn được báo bằng dòng kết quả ngay dưới
			bánh xe + Toast của server.

			⚠️ Đừng "cải tiến" bằng cách mở banner cho ô hiếm nhì/ba: đã thử phân tầng theo trọng
			số và user bác. Ranh giới là AURA, không phải độ hiếm.
		]]
		if wonSlot and wonSlot.kind == "aura" then
			local BoostCelebration = require(script.Parent.Parent.BoostCelebration)
			BoostCelebration.TriggerPurchase("FROZEN BLOOM", `ULTRA RARE LEGENDARY AURA ({wonSlot.rarity})!`)
		end
	end)
end

-- ============================================================================
-- Controls
-- ============================================================================

local function requestSpin()
	if State.rouletteSpinning:get() then
		return
	end
	if State.rouletteTickets:get() <= 0 then
		Toast.Show("No Spin Tickets! Buy or wait for a free one.", "roulette")
		return
	end
	State.rouletteSpinning:set(true)
	spinRequestToken += 1
	local token = spinRequestToken
	State.rouletteResultText:set("")
	GamePackets.requestSpin.send({})

	-- An toàn: nếu server không phản hồi (lag), mở khóa sau 8s.
	task.delay(8, function()
		-- Timeout lượt trước không được mở khoá lượt quay mới.
		if token == spinRequestToken and State.rouletteSpinning:get() then
			State.rouletteSpinning:set(false)
		end
	end)
end

local function makeBuyButton(pack: Products.SpinPack, order: number)
	local hovered = Value(false)
	return Theme.MakeSurface({
		ClassName = "TextButton",
		LayoutOrder = order,
		Size = UDim2.fromOffset(142, 54),
		ZIndex = 45,
		Radius = 12,
		Border = 4,
		Color = Color3.fromRGB(85, 190, 255),
		ColorB = Color3.fromRGB(28, 100, 210),
		GradientRotation = 0,
		Zoom = { Hovered = hovered, Scale = 1.08 },
		Activated = function()
			if pack.productId <= 0 then
				Toast.Show("Spin pack chưa có Product ID!", "roulette")
				return
			end
			MarketplaceService:PromptProductPurchase(localPlayer, pack.productId)
		end,
		MouseEnter = function()
			hovered:set(true)
		end,
		MouseLeave = function()
			hovered:set(false)
		end,
		Content = function(zoom)
			return {
				Theme.MakeOutlineLabel({
					Position = UDim2.fromOffset(0, 2),
					Size = UDim2.fromOffset(142, 28),
					Text = `{pack.spins} SPIN{if pack.spins > 1 then "S" else ""}`,
					Zoom = zoom,
					MaxTextSize = 22,
					ZIndex = 47,
				}),
				Theme.MakeOutlineLabel({
					Position = UDim2.fromOffset(0, 28),
					Size = UDim2.fromOffset(142, 26),
					Text = `\u{E002} {pack.priceRobux}`,
					TextColor3 = Color3.fromRGB(190, 255, 170),
					Zoom = zoom,
					MaxTextSize = 20,
					ZIndex = 47,
				}),
			}
		end,
	})
end

local function buildRightColumn()
	local spinHovered = State.rouletteSpinHovered

	local buyButtons: { any } = {
		New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for order, pack in Products.SPIN_PACKS do
		table.insert(buyButtons, makeBuyButton(pack, order))
	end

	return New("Frame")({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(520, 108),
		Size = UDim2.fromOffset(480, 470),
		ZIndex = 42,
		[Children] = {
			-- Số vé
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 10),
				Size = UDim2.fromOffset(480, 56),
				Text = Computed(function()
					return `🎟️ Tickets: {State.rouletteTickets:get()}`
				end),
				MaxTextSize = 44,
				ZIndex = 45,
			}),
			-- Đếm ngược vé free
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 70),
				Size = UDim2.fromOffset(480, 34),
				Text = Computed(function()
					local base = State.rouletteNextFreeSeconds:get()
					if base < 0 then
						return "Free ticket stock FULL (3/3)"
					end
					local elapsed = State.boostClockNow:get() - State.rouletteNextFreeReceivedAt:get()
					local left = math.max(0, base - elapsed)
					return `Next free ticket in {formatClock(left)}`
				end),
				TextColor3 = Color3.fromRGB(180, 240, 255),
				MaxTextSize = 24,
				ZIndex = 45,
			}),
			-- Kết quả gần nhất
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 146),
				Size = UDim2.fromOffset(480, 40),
				Text = State.rouletteResultText,
				TextColor3 = Color3.fromRGB(140, 255, 170),
				MaxTextSize = 28,
				ZIndex = 45,
			}),
			-- Nút SPIN. Bọc `UIAnchors.Keep` để tutorial bước 5/5 chiếu spotlight vào đúng đây
			-- sau khi người chơi mở modal (xem `TutorialController.runSpinFinale`).
			UIAnchors.Keep(
				"rouletteSpinButton",
				Theme.MakeSurface({
					ClassName = "TextButton",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromOffset(240, 200),
					Size = UDim2.fromOffset(360, 84),
					ZIndex = 45,
					Radius = 18,
					Border = Tokens.BORDER,
					Color = Computed(function()
						return if State.rouletteSpinning:get() or State.rouletteTickets:get() <= 0
							then Color3.fromRGB(110, 80, 124)
							else Color3.fromRGB(108, 240, 130)
					end),
					ColorB = Computed(function()
						return if State.rouletteSpinning:get() or State.rouletteTickets:get() <= 0
							then Color3.fromRGB(66, 44, 84)
							else Color3.fromRGB(30, 150, 72)
					end),
					Zoom = { Hovered = spinHovered, Scale = 1.06 },
					Activated = requestSpin,
					MouseEnter = function()
						spinHovered:set(true)
					end,
					MouseLeave = function()
						spinHovered:set(false)
					end,
					Content = function(zoom)
						return {
							Theme.MakeOutlineLabel({
								Position = UDim2.fromScale(0, 0),
								Size = UDim2.fromScale(1, 1),
								Text = Computed(function()
									if State.rouletteSpinning:get() then
										return "SPINNING..."
									end
									return "SPIN (1 🎟️)"
								end),
								Zoom = zoom,
								MaxTextSize = 42,
								ZIndex = 47,
							}),
						}
					end,
				})
			),
			-- Tiêu đề mua thêm
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 310),
				Size = UDim2.fromOffset(480, 30),
				Text = "BUY MORE SPINS",
				TextColor3 = Color3.fromRGB(255, 205, 46),
				MaxTextSize = 24,
				ZIndex = 45,
			}),
			New("Frame")({
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 348),
				Size = UDim2.fromOffset(480, 62),
				ZIndex = 44,
				[Children] = buyButtons,
			}),
			-- Ghi chú free
			Theme.MakeOutlineLabel({
				Position = UDim2.fromOffset(0, 420),
				Size = UDim2.fromOffset(480, 26),
				Text = "Free: +1 ticket / 15 min online (stock 3) + Day 7 login",
				TextColor3 = Color3.fromRGB(210, 210, 235),
				MaxTextSize = 18,
				ZIndex = 45,
			}),
		},
	})
end

-- ============================================================================
-- Panel
-- ============================================================================

function RouletteModal.Build()
	return ModalShell.Build({
		Id = "roulette",
		Width = PANEL_WIDTH,
		Height = PANEL_HEIGHT,
		PanelColor = Color3.fromRGB(16, 6, 36),
		PanelTransparency = 0.24,
		-- Header tím neon — theo shop-style chuẩn.
		HeaderColor = Color3.fromRGB(210, 130, 255),
		HeaderColorB = Color3.fromRGB(110, 40, 220),
		Icon = Theme.UI_ASSETS.Spin,
		Title = "Speed Roulette",
		OnClose = Manager.CloseRoulette,
		Content = {
			buildWheel(),
			buildRightColumn(),
		},
	})
end

Fusion.Observer(State.rouletteModalMounted):onChange(function()
	if State.rouletteModalMounted:get() then
		startIdleRotation()
	else
		stopIdleRotation()
	end
end)

return RouletteModal
