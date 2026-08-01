--!strict
-- HUD đáy: Speed text, multiplier breakdown, XP bar (có Tween mượt).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children
local Computed = Fusion.Computed
local New = Fusion.New
local Tween = Fusion.Tween

local BottomHud = {}

type MultiplierRow = {
	text: string,
}

local function formatMultiplier(value: number): string
	return `x{string.format("%.1f", value)}`
end

local function addComponent(parts: { string }, label: string, value: number)
	table.insert(parts, `{label} {formatMultiplier(value)}`)
end

local function getSpeedBuffBreakdown()
	local state = State.GetSnapshot()

	return {
		premiumMultiplier = math.max(1, state.premiumMultiplier),
		cosmeticMultiplier = math.max(1, state.cosmeticMultiplier),
		rebirthMultiplier = math.max(1, state.rebirthMultiplier),
		treadmillMultiplier = math.max(1, state.treadmillMultiplier),
		speedPassMultiplier = math.max(1, state.speedPassMultiplier),
		vipMultiplier = math.max(1, state.vipMultiplier),
		trailMultiplier = math.max(1, state.trailMultiplier),
		auraMultiplier = math.max(1, state.auraMultiplier),
		totalMultiplier = state.gainMultiplier,
	}
end

BottomHud.GetSpeedBuffBreakdown = getSpeedBuffBreakdown

local function getMultiplierRows(): { MultiplierRow }
	local breakdown = getSpeedBuffBreakdown()
	local premiumParts = {}
	addComponent(premiumParts, "Treadmill", breakdown.treadmillMultiplier)
	addComponent(premiumParts, "Pass", breakdown.speedPassMultiplier)
	addComponent(premiumParts, "VIP", breakdown.vipMultiplier)

	local gearParts = {}
	addComponent(gearParts, "Trail", breakdown.trailMultiplier)
	addComponent(gearParts, "Aura", breakdown.auraMultiplier)

	return {
		{
			text = `Premium {formatMultiplier(breakdown.premiumMultiplier)}\n({table.concat(premiumParts, " + ")})`,
		},
		{
			text = `Gear {formatMultiplier(breakdown.cosmeticMultiplier)} ({table.concat(gearParts, " + ")})`,
		},
		{
			text = `Progress {formatMultiplier(breakdown.rebirthMultiplier)} (Rebirth {formatMultiplier(breakdown.rebirthMultiplier)})`,
		},
		{
			text = `Total {formatMultiplier(breakdown.totalMultiplier)}`,
		},
	}
end

local function getMultiplierRowText(index: number): string
	local row = getMultiplierRows()[index]
	return if row then row.text else ""
end

-- Tiến độ THẬT của level hiện tại. `data.XP` bị trừ đi mỗi lần lên level
-- (ProgressionService: `data.XP -= GetRequiredXP(level)`) nên `xp / requiredXP` chính là
-- phần đã đi được của riêng level này — không cần trừ mốc tích luỹ.
-- Dòng Event: giải thích phần hệ số mà 3 dòng Premium/Gear/Progress KHÔNG cover.
-- Trước đây người chơi thấy "Total x2.0" trong khi cả ba dòng kia đều x1.0 và không hiểu
-- x2 ở đâu ra — hệ số event nằm trong rổ liveOps, chưa từng được hiện ở đâu cả.
-- Rỗng ⇒ không có event ⇒ label tự ẩn.
local function getEventRowText(): string
	local name = State.eventName:get()
	if name == "" then
		return ""
	end

	local speedMult = State.eventSpeedMultiplier:get()
	local winsMult = State.eventWinsMultiplier:get()

	-- Event có thể chỉ nhân Wins (speed = 1). Nếu chỉ xét speed thì đúng loại event đó
	-- lại không hiện dòng nào — người chơi không biết mình đang được x2 Wins.
	if speedMult > 1 and winsMult > 1 then
		return `Event {formatMultiplier(speedMult)} Speed · {formatMultiplier(winsMult)} Wins ({name})`
	elseif speedMult > 1 then
		return `Event {formatMultiplier(speedMult)} ({name})`
	elseif winsMult > 1 then
		return `Event {formatMultiplier(winsMult)} Wins ({name})`
	end
	return ""
end

local function getLevelProgress(): number
	local state = State.GetSnapshot()
	if state.requiredXP <= 0 then
		return 0
	end
	return math.clamp(state.xp / state.requiredXP, 0, 1)
end

local function makeMultiplierLabel(index: number, position: UDim2, alignment: Enum.TextXAlignment, color: Color3)
	return Theme.MakeOutlineLabel({
		Position = position,
		Size = UDim2.fromOffset(390, 46),
		Text = Computed(function()
			return getMultiplierRowText(index)
		end),
		Visible = Computed(function()
			return getMultiplierRowText(index) ~= ""
		end),
		TextColor3 = color,
		MaxTextSize = 24,
		MinTextSize = 8,
		TextXAlignment = alignment,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
	})
end

function BottomHud.Build()
	return New("Frame")({
		BackgroundTransparency = 1,
		Position = Computed(function()
			local left, _, right, bottom, scale = Theme.GetVisibleDesignBounds()
			local x = left + ((right - left - 1160) * 0.5)
			local y = if scale < 0.75 then bottom - 158 - (12 / scale) else 872
			return UDim2.fromOffset(x, y)
		end),
		Size = UDim2.fromOffset(1160, 158),
		[Children] = {
			-- Băng-rôn Event: đặt TRÊN cả cụm (y âm), giữa màn, vàng — vừa giải thích Total,
			-- vừa là chỗ quảng cáo event. Ẩn hẳn khi không có event nên không tốn chỗ.
			Theme.MakeOutlineLabel({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(580, -56),
				Size = UDim2.fromOffset(700, 40),
				Text = Computed(getEventRowText),
				Visible = Computed(function()
					return getEventRowText() ~= ""
				end),
				TextColor3 = Color3.fromRGB(255, 214, 64),
				MaxTextSize = 28,
				MinTextSize = 10,
				ZIndex = 2,
			}),
			Theme.MakeOutlineLabel({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(580, -4),
				Size = UDim2.fromOffset(440, 66),
				Text = Computed(function()
					return `{Theme.FormatInteger(State.GetSnapshot().speed)} Speed`
				end),
				MaxTextSize = 46,
				ZIndex = 2,
			}),
			makeMultiplierLabel(1, UDim2.fromOffset(0, -18), Enum.TextXAlignment.Left, Color3.fromRGB(255, 91, 245)),
			makeMultiplierLabel(2, UDim2.fromOffset(0, 28), Enum.TextXAlignment.Left, Color3.fromRGB(58, 255, 92)),
			makeMultiplierLabel(3, UDim2.fromOffset(770, -18), Enum.TextXAlignment.Right, Color3.fromRGB(88, 245, 255)),
			makeMultiplierLabel(4, UDim2.fromOffset(770, 28), Enum.TextXAlignment.Right, Color3.fromRGB(255, 224, 96)),
			New("Frame")({
				BackgroundColor3 = Color3.fromRGB(196, 147, 85),
				ClipsDescendants = true,
				Position = UDim2.fromOffset(0, 76),
				Size = UDim2.fromOffset(1158, 74),
				[Children] = {
					Theme.MakeCorner(12),
					Theme.MakeStroke(Color3.fromRGB(0, 0, 0), 4),
					Theme.MakeGradient(Color3.fromRGB(222, 176, 111), Color3.fromRGB(165, 112, 59)),
					Theme.MakeStudsPattern(0.84, 1),
					New("Frame")({
						BackgroundColor3 = Color3.fromRGB(242, 199, 132),
						BorderSizePixel = 0,
						-- ⚠️ 2026-07-29: bản cũ có `progress = math.max(progress, 0.035)` —
						-- một cái SÀN GIẢ. Ở Level 120 (72K/2.45B ⇒ 0,003%) thanh vẫn đầy 3,5%,
						-- người chơi tưởng sắp lên level trong khi còn cả tỉ XP. Bỏ hẳn sàn đó:
						-- bề rộng giờ ĐÚNG TỈ LỆ. (2026-07-31: gỡ nhãn phần trăm ở giữa thanh —
						-- số XP "x / y" bên phải đã nói đủ, thêm "0.0000%" chỉ làm rối.)
						Size = Tween(
							Computed(function()
								return UDim2.fromScale(getLevelProgress(), 1)
							end),
							TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
						),
						[Children] = {
							Theme.MakeCorner(12),
							Theme.MakeStandardStuds(12),
						},
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(26, 8),
						Size = UDim2.fromOffset(340, 58),
						Text = Computed(function()
							return `Level {State.GetSnapshot().level}`
						end),
						TextXAlignment = Enum.TextXAlignment.Left,
						MaxTextSize = 42,
						ZIndex = 3,
					}),
					Theme.MakeOutlineLabel({
						Position = UDim2.fromOffset(760, 10),
						Size = UDim2.fromOffset(370, 54),
						Text = Computed(function()
							local state = State.GetSnapshot()
							return `{Theme.FormatInteger(state.xp)} / {Theme.FormatInteger(state.requiredXP)}`
						end),
						TextXAlignment = Enum.TextXAlignment.Right,
						MaxTextSize = 34,
						ZIndex = 3,
					}),
				},
			}),
		},
	})
end

return BottomHud
