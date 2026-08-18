--!strict
-- Tô màu PadPart của 8 MultiplierPad theo trạng thái của localPlayer:
--   - ACTIVE  (đang ở pad này)         → vàng `Color3.fromRGB(255, 220, 0)`
--   - UNLOCKED (đã đạt/mở khóa, chưa ở) → xanh lá `Color3.fromRGB(80, 220, 80)`
--   - LOCKED   (chưa đạt)               → xám `Color3.fromRGB(110, 110, 110)`
--
-- Theo attribute `HighestPadIndex` do server phát. ⚠️ Từ 2026-08-10 attribute đó KHÔNG còn là
-- cột mốc vĩnh viễn nữa mà là mức Wins HIỆN TẠI với tới (xem MultiplierPadService): Wins tụt
-- xuống dưới ngưỡng thì pad tương ứng xám lại và server tự hạ người chơi về pad còn đủ.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Theme = require(script.Parent.Parent.HUD.Theme)
local Toast = require(script.Parent.Parent.HUD.Toast)

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
	if not config then
		return
	end

	--[[
		1. CHUÔNG MỞ KHOÁ — HAI NỐT ĐI LÊN (đổi 2026-08-14, user: "trùng với sound chúc mừng").

		Lịch sử của đúng một dòng SoundId này:
		  • 6085521634 — KHÔNG PHẢI Audio (là ảnh áo hoodie của 'mee9236'), câm suốt và không
		    log lỗi cho tới lúc Play() thật.
		  • 4612383790 — âm chúc mừng chung. Kêu được, nhưng nó là fanfare rebirth 1.71s: mở pad
		    nghe y hệt lúc rebirth thành công, mà mở pad thì người chơi CHƯA nhận được gì.
		  • Nay: `Theme.UI_ASSETS.UnlockSound`, ping 0.72s có sẵn trong client, phát hai lần —
		    nốt hai cao hơn quãng năm (1.5) và nhẹ hơn. Đi lên = "vừa mở ra", đi xuống = "hỏng";
		    một nốt đơn thì chỉ là tiếng thông báo chung chung không mang nghĩa gì.

		⚠️ ĐỪNG gán lại `CelebrationSound` vào đây. Âm chúc mừng thuộc về lúc NHẬN (banner
		rebirth/boost, thẻ Wins bay, trúng roulette) — pad mới mở là lời MỜI, không phải phần thưởng.
	]]
	local function playUnlockChime(pitch: number, volume: number, delaySeconds: number)
		task.delay(delaySeconds, function()
			local sound = Instance.new("Sound")
			sound.SoundId = Theme.UI_ASSETS.UnlockSound
			sound.PlaybackSpeed = pitch
			sound.Volume = volume
			sound.Parent = SoundService
			-- `PlayOnRemove` + Destroy ngay: âm vẫn kêu trọn vẹn mà không để lại instance nào
			-- phải chờ `Ended` rồi dọn — pad có thể mở dồn dập khi người chơi bùng Wins.
			sound.PlayOnRemove = true
			sound:Destroy()
		end)
	end
	playUnlockChime(1.0, 0.7, 0)
	playUnlockChime(1.5, 0.55, 0.11)

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
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255)),
			})
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.8),
				NumberSequenceKeypoint.new(0.8, 1.0),
				NumberSequenceKeypoint.new(1, 0.0),
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

	--[[
		3. BÁO TRÊN ĐỈNH MÀN HÌNH, KHÔNG PHẢI GIỮA (2026-08-10, user).

		Bản trước là chữ vàng khổng lồ giữa màn hình + mưa confetti toàn màn — đúng ngôn ngữ
		của "bạn vừa NHẬN được thứ gì đó". Nhưng đây chỉ là tin "bạn đủ điều kiện rồi, ra pad
		mà lấy": người chơi chưa nhận gì cả, và cái chữ to đó còn che mất chính khu pad họ cần
		nhìn để đi tới.

		Giờ dùng lại `Toast` — dải nhỏ trên đỉnh, có sẵn pill + icon + âm thanh + hàng đợi,
		nên tin này xếp hàng tử tế với mọi thông báo khác thay vì đè lên chúng. Cột lửa hạt
		ngay tại PadPart (mục 2 ở trên) vẫn giữ: đó mới là thứ chỉ ĐƯỜNG, và nó nằm trong thế
		giới chứ không che màn hình.
	]]
	Toast.Show(`Pad {padIndex} ready — step on it for +{config.speedPerStep} Speed/step`, "pad")
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
