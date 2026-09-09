--!strict
-- Âm thanh + hiệu ứng cho MỌI button trong toàn bộ UI (tự động, không cần sửa từng nút).
-- Quét PlayerGui + lắng nghe DescendantAdded → mọi GuiButton đều có:
--   • Hover  → phát tiếng "hover" (throttle chống spam)
--   • Click  → phát tiếng "click" + nhún nhẹ (press dip) bằng UIScale riêng (nhân với HoverZoom).

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")

local Theme = require(script.Parent.Parent.HUD.Theme)

local ButtonSFXController = {}

local localPlayer = Players.LocalPlayer

local HOVER_THROTTLE = 0.04
local PRESS_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local lastHoverAt = 0
local clickSound: Sound? = nil
local hoverSound: Sound? = nil
local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function makeSound(soundId: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local function playClick()
	if clickSound then
		clickSound.TimePosition = 0
		clickSound.PlaybackSpeed = 1.0 + (math.random(-5, 5) / 100)
		clickSound:Play()
	end
end

local function playHover()
	local now = os.clock()
	if now - lastHoverAt < HOVER_THROTTLE then
		return
	end
	lastHoverAt = now
	if hoverSound then
		hoverSound.TimePosition = 0
		-- 1.45 là di sản của thời hover dùng CHUNG mẫu với click (phải đẩy pitch lên mới
		-- phân biệt được). Giờ hover có mẫu riêng nên phát ở tốc độ gốc, chỉ rung nhẹ.
		hoverSound.PlaybackSpeed = 1.0 + (math.random(-6, 6) / 100)
		hoverSound:Play()
	end
end

local function pressEffect(button: GuiButton)
	local scale = button:FindFirstChild("ClickScale")
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = "ClickScale"
		scale.Parent = button
	end
	(scale :: UIScale).Scale = 0.9
	TweenService:Create(scale :: UIScale, PRESS_TWEEN, { Scale = 1 }):Play()
end

local function hook(obj: Instance)
	if hooked[obj] or not obj:IsA("GuiButton") then
		return
	end
	hooked[obj] = true
	obj.MouseButton1Down:Connect(function()
		playClick()
		pressEffect(obj)
	end)
	obj.MouseEnter:Connect(playHover)
end

function ButtonSFXController.Init() end

function ButtonSFXController.Start()
	clickSound = makeSound(Theme.UI_ASSETS.ClickSound, 0.5)
	-- Hover kêu suốt trong lúc rê chuột qua menu nên phải NHỎ hơn click rõ rệt,
	-- nếu không mỗi lần đi ngang 5 nút menu là 5 tiếng bấm giả.
	hoverSound = makeSound(Theme.UI_ASSETS.HoverSound, 0.22)
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ clickSound, hoverSound })
		end)
		-- Play câm 1 lượt: PreloadAsync chỉ tải bytes, lần Play đầu vẫn phải decode
		-- (cùng lý do đã ghi trong ASMR/Engine/SoundPool).
		for _, s in { clickSound, hoverSound } do
			if s then
				local vol = s.Volume
				s.Volume = 0
				s:Play()
				task.wait(0.05)
				s:Stop()
				s.Volume = vol
			end
		end
	end)

	local playerGui = localPlayer:WaitForChild("PlayerGui")
	for _, descendant in playerGui:GetDescendants() do
		hook(descendant)
	end
	playerGui.DescendantAdded:Connect(hook)
end

return ButtonSFXController
