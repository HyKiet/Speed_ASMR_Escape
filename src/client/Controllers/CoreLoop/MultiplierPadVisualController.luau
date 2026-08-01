--!strict
-- Tô màu PadPart của 8 MultiplierPad theo trạng thái của localPlayer:
--   - ACTIVE  (đang ở pad này)         → vàng `Color3.fromRGB(255, 220, 0)`
--   - UNLOCKED (đã đạt/mở khóa, chưa ở) → xanh lá `Color3.fromRGB(80, 220, 80)`
--   - LOCKED   (chưa đạt)               → xám `Color3.fromRGB(110, 110, 110)`
--
-- Theo TIẾN ĐỘ tuần tự (HighestPadIndex), KHÔNG theo Wins hiện tại (Wins có thể tụt khi tiêu).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)

local MultiplierPadVisualController = {}

local PADS_FOLDER_NAME = "MultiplierPads"
local PAD_PART_NAME = "PadPart"
local REFRESH_INTERVAL = 0.18

local COLOR_ACTIVE = Color3.fromRGB(255, 220, 0)
local COLOR_ELIGIBLE = Color3.fromRGB(80, 220, 80)
local COLOR_LOCKED = Color3.fromRGB(110, 110, 110)

local TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local localPlayer = Players.LocalPlayer
local lastColor: { [BasePart]: Color3 } = {}
local lastRefreshAt = 0

local function getHighestPadIndex(): number
	local v = localPlayer:GetAttribute("HighestPadIndex")
	if typeof(v) == "number" then
		return math.floor(v)
	end
	return 1
end

local function padIndexFromId(id: string): number
	local n = id:match("^pad_(%d+)$")
	return n and tonumber(n) or 1
end

local function getPadIdForPart(padPart: BasePart): string?
	local id = padPart:GetAttribute("PadId")
	if typeof(id) == "string" then
		return id
	end
	local padModel = padPart.Parent
	if not padModel then
		return nil
	end
	local n = padModel.Name:match("^Pad_?(%d+)$")
	return n and `pad_{n}`
end

-- Play a highly satisfying, addictive level-up visual and audio celebration
local function playUnlockCelebration(padIndex: number)
	local config = Constants.GetMultiplierPadById(`pad_{padIndex}`)
	if not config then return end

	-- 1. Play success chime SFX
	-- ⚠️ ID cũ 6085521634 KHÔNG PHẢI Audio (là ảnh áo hoodie của 'mee9236') — sound câm suốt,
	-- không log lỗi cho tới khi Play() thật. Đổi sang ID Level Up thật, cùng ID với
	-- Theme.UI_ASSETS.LevelUpSound (group sở hữu, đã xác nhận IsA Audio + đang phát tốt).
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://89481514209130" -- Level Up (group, xem Theme.UI_ASSETS.LevelUpSound)
	sound.Volume = 0.75
	sound.Parent = SoundService
	sound:Play()
	task.spawn(function()
		sound.Ended:Wait()
		sound:Destroy()
	end)

	-- 2. Physical Fountain of Sparkles at the unlocked PadPart
	task.spawn(function()
		local folder = Workspace:FindFirstChild(PADS_FOLDER_NAME, true)
		local padModel = folder and folder:FindFirstChild(`Pad_{padIndex}`)
		local padPart = padModel and padModel:FindFirstChild(PAD_PART_NAME)
		if padPart and padPart:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Position = Vector3.new(0, 0.5, 0)
			att.Parent = padPart

			local emitter = Instance.new("ParticleEmitter")
			emitter.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 0, 191)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255))
			})
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.8),
				NumberSequenceKeypoint.new(0.8, 1.0),
				NumberSequenceKeypoint.new(1, 0.0)
			})
			emitter.Texture = "rbxassetid://258122939" -- Star Sparkle
			emitter.Lifetime = NumberRange.new(1.2, 2.0)
			emitter.Rate = 0
			emitter.Speed = NumberRange.new(18, 38)
			emitter.SpreadAngle = Vector2.new(45, 45)
			emitter.Acceleration = Vector3.new(0, -28, 0) -- fountain fall down
			emitter.Parent = att

			emitter:Emit(70)

			task.wait(2.2)
			att:Destroy()
		end
	end)

	-- 3. Confetti Rain and Elastic Text Pop on screen
	task.spawn(function()
		local playerGui = localPlayer:WaitForChild("PlayerGui")
		local old = playerGui:FindFirstChild("PadUnlockCelebration")
		if old then old:Destroy() end

		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "PadUnlockCelebration"
		screenGui.DisplayOrder = 1000
		screenGui.IgnoreGuiInset = true
		screenGui.Parent = playerGui

		-- Text Container
		local container = Instance.new("Frame")
		container.AnchorPoint = Vector2.new(0.5, 0.5)
		container.BackgroundTransparency = 1
		container.Position = UDim2.fromScale(0.5, 0.38)
		container.Size = UDim2.fromOffset(500, 150)
		container.Parent = screenGui

		local title = Instance.new("TextLabel")
		title.AnchorPoint = Vector2.new(0.5, 0.5)
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0.5, 0.3)
		title.Size = UDim2.fromScale(0, 0) -- Starts minimized
		title.Font = Enum.Font.GothamBlack
		title.Text = "NEW PAD UNLOCKED!"
		title.TextColor3 = Color3.fromRGB(255, 220, 0) -- Gold neon
		title.TextScaled = true
		title.Parent = container

		local tStroke = Instance.new("UIStroke")
		tStroke.Thickness = 4.5
		tStroke.Color = Color3.fromRGB(0, 0, 0)
		tStroke.Parent = title

		local sub = Instance.new("TextLabel")
		sub.AnchorPoint = Vector2.new(0.5, 0.5)
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0.5, 0.7)
		sub.Size = UDim2.fromScale(0, 0)
		sub.Font = Enum.Font.GothamBold
		sub.Text = `+{config.speedPerStep} Speed / Step`
		sub.TextColor3 = Color3.fromRGB(0, 255, 255) -- Cyan neon
		sub.TextScaled = true
		sub.Parent = container

		local sStroke = Instance.new("UIStroke")
		sStroke.Thickness = 3.5
		sStroke.Color = Color3.fromRGB(0, 0, 0)
		sStroke.Parent = sub

		-- Elastic Pop In Tweens
		TweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(1, 0.45)
		}):Play()
		
		task.wait(0.15)
		TweenService:Create(sub, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.8, 0.35)
		}):Play()

		-- Generate Raining Confetti Frame Pieces
		local colors = {
			Color3.fromRGB(255, 60, 60),
			Color3.fromRGB(255, 220, 0),
			Color3.fromRGB(60, 255, 60),
			Color3.fromRGB(60, 200, 255),
			Color3.fromRGB(255, 60, 255),
			Color3.fromRGB(0, 255, 255)
		}

		for i = 1, 55 do
			local piece = Instance.new("Frame")
			piece.BackgroundColor3 = colors[math.random(1, #colors)]
			piece.BorderSizePixel = 0
			
			local width = math.random(12, 24)
			local height = math.random(6, 14)
			piece.Size = UDim2.fromOffset(width, height)
			
			local startX = math.random(0, 100) / 100
			piece.Position = UDim2.fromScale(startX, -0.05)
			piece.Rotation = math.random(0, 360)
			piece.Parent = screenGui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.2, 0)
			corner.Parent = piece

			-- Animate gravity fall
			local targetX = startX + (math.random(-12, 12) / 100)
			local duration = math.random(18, 28) / 10
			local rotSpeed = math.random(-360, 360)

			TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(targetX, 1.05),
				Rotation = piece.Rotation + rotSpeed
			}):Play()

			task.delay(duration, function()
				piece:Destroy()
			end)
		end

		-- Clean up central titles
		task.wait(2.2)
		TweenService:Create(title, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(0, 0)
		}):Play()
		TweenService:Create(sub, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(0, 0)
		}):Play()
		
		task.wait(0.5)
		screenGui:Destroy()
	end)
end

local function tintPad(padPart: BasePart, targetColor: Color3)
	if lastColor[padPart] and lastColor[padPart] == targetColor then
		return
	end
	lastColor[padPart] = targetColor

	TweenService:Create(padPart, TWEEN_INFO, { Color = targetColor }):Play()

	for _, child in padPart:GetChildren() do
		if child:IsA("Texture") or child:IsA("Decal") then
			TweenService:Create(child, TWEEN_INFO, { Color3 = targetColor }):Play()
		end
	end
end

local cachedPadsFolder: Instance? = nil

local function refreshAll()
	if not cachedPadsFolder or not cachedPadsFolder.Parent then
		cachedPadsFolder = Workspace:FindFirstChild(PADS_FOLDER_NAME, true)
	end
	local folder = cachedPadsFolder
	if not folder then
		return
	end
	local activeId = localPlayer:GetAttribute("ActivePadId")
	local highest = getHighestPadIndex()

	for _, padModel in folder:GetChildren() do
		if not padModel:IsA("Model") then
			continue
		end
		local padPart = padModel:FindFirstChild(PAD_PART_NAME)
		if not padPart or not padPart:IsA("BasePart") then
			continue
		end

		local padId = getPadIdForPart(padPart)
		if not padId then
			continue
		end

		local config = Constants.GetMultiplierPadById(padId)
		if not config then
			continue
		end

		local targetColor: Color3
		if padId == activeId then
			targetColor = COLOR_ACTIVE
		elseif padIndexFromId(padId) <= highest then
			targetColor = COLOR_ELIGIBLE
		else
			targetColor = COLOR_LOCKED
		end

		tintPad(padPart, targetColor)
	end
end


local function bootstrap()
	-- Folder giờ nằm trong Workspace.Lobby — chờ bằng poll đệ quy thay vì WaitForChild trực tiếp.
	local deadline = os.clock() + 15
	while os.clock() < deadline and not Workspace:FindFirstChild(PADS_FOLDER_NAME, true) do
		task.wait(0.25)
	end
	refreshAll()
end

function MultiplierPadVisualController.Init() end

function MultiplierPadVisualController.Start()
	bootstrap()

	local lastHighest = getHighestPadIndex()

	localPlayer:GetAttributeChangedSignal("ActivePadId"):Connect(refreshAll)
	localPlayer:GetAttributeChangedSignal("HighestPadIndex"):Connect(function()
		refreshAll()
		local currentHighest = getHighestPadIndex()
		if currentHighest > lastHighest then
			playUnlockCelebration(currentHighest)
		end
		lastHighest = currentHighest
	end)

	local function watchLeaderstats()
		local leaderstats = localPlayer:FindFirstChild("leaderstats") or localPlayer:WaitForChild("leaderstats", 10)
		if not leaderstats then
			return
		end
		local wins = leaderstats:FindFirstChild("Wins")
		if wins and wins:IsA("NumberValue") then
			wins:GetPropertyChangedSignal("Value"):Connect(refreshAll)
		end
	end
	task.spawn(watchLeaderstats)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if now - lastRefreshAt < REFRESH_INTERVAL then
			return
		end
		lastRefreshAt = now
		refreshAll()
	end)
end

return MultiplierPadVisualController
