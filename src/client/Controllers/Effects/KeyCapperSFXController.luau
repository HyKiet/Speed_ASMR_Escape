--!strict
-- Ghép sàn phím KeyCapper (Workspace.KeyCapperKeys) vào ĐÚNG hệ âm bàn phím cơ của game.
--
-- KeyCapper là runtime của plugin bên thứ ba (sebattfg, v0.5.17) và chỉ phát ĐÚNG MỘT
-- Sound cho mỗi lần bấm — xem `ReplicatedStorage.KeyCapper.Detection.Keycap:Press()`.
-- Hệ âm của game thì có 3 lớp (thân / tick lá đồng / nhả), khớp với ASMR/Floors/Keyboard.
--
-- PHÂN CÔNG:
--   • LỚP THÂN  — để KeyCapper tự phát. Đã trỏ về đúng mẫu của game bằng attribute
--     `SoundIds` trên `ReplicatedStorage.KeyCapperGroups.Default` (đây là ô mà panel của
--     plugin ghi vào, nên chỉnh ở đó thì KHÔNG bị mất khi plugin cập nhật — tuyệt đối
--     không sửa `KeyCapper.Config`, file đó do plugin sở hữu và sẽ bị ghi đè).
--     Cùng chỗ đó đã đặt `PitchJitter = 0`; mặc định plugin để 0.5 tức ±50% cao độ ngẫu
--     nhiên mỗi lần bấm, trái hẳn yêu cầu "mọi phím phát y hệt nhau".
--   • LỚP TICK + NHẢ — controller này, bám vào `KeyCapper.KeyPressed`. Đó là điểm mở rộng
--     CÔNG KHAI plugin ghi trong Config.lua, nên không đụng gì vào code của plugin.
--
-- Không thấy KeyCapper thì controller tự tắt, không cảnh báo — nhiều place không có nó.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KeyCapperSFXController = {}

-- Dùng chung nguồn với `ASMR/Floors/Keyboard.luau` qua `Config.SoundIds` — trước đây hai
-- file cùng khai số và chỉ có một dòng comment nhắc "đổi ở đó thì đổi cả ở đây", tức là
-- dựa vào trí nhớ. Giờ chỉ còn một chỗ để đổi.
local SoundIds = require(ReplicatedStorage.Shared.Config.SoundIds)

local TICK_ID = SoundIds.KEYBOARD_TICK
local RELEASE_ID = SoundIds.KEYBOARD_RELEASE

-- KeyCapper phát lớp thân ở `Config.SOUND_VOLUME` = 0.5; hai hằng số dưới là TỈ LỆ so
-- với thân, lấy nguyên từ Keyboard.luau (TICK_VOL 0.34 / RELEASE_VOL ≈ 0.28 so với thân).
local BODY_VOLUME = 0.5
local TICK_VOL = BODY_VOLUME * 0.34
local TICK_PITCH = 1.44
local RELEASE_VOL = BODY_VOLUME * 0.36
local RELEASE_PITCH = 1.78

-- Sàn ASMR hạ lớp thân xuống 0.92 cho đục/thocky hơn. KeyCapper tự phát lớp thân và
-- KHÔNG có ô nào chỉnh được PlaybackSpeed (chỉ có PitchJitter, mà jitter phải để 0),
-- nên lớp thân bên này vẫn ở 1.00 — hai bàn sẽ hơi khác chất. Muốn khớp tuyệt đối thì
-- phải upload một bản mẫu đã hạ tông sẵn rồi trỏ `SoundIds` vào đó.

-- Khớp `Config.SOUND_MAX_DISTANCE` = 120 để 3 lớp cùng tắt dần theo một nhịp; lớp nhả
-- gần hơn một chút đúng như tỉ lệ 70/55 bên sàn ASMR.
local TICK_MAX_DIST = 120
local RELEASE_MAX_DIST = 95

-- KeyCapper KHÔNG bắn sự kiện lúc nhả phím (chỉ có `KeyPressed`), nên lớp nhả buộc phải
-- hẹn giờ. 0.085s lấy từ sàn ASMR — ở đó đo được keycap về tới vị trí nghỉ quanh mốc này.
-- Đặt 0 để tắt hẳn lớp nhả nếu nghe thấy thừa.
local RELEASE_DELAY = 0.085

-- Số giọng: bàn KeyCapper lát phím cách nhau 3.15 studs, chạy 250 WS (cap của game) là
-- ~79 lượt bấm/giây. Giọng cần = lượt/giây × độ-dài-mẫu ⇒ tick 79 × 0.203 ≈ 16.
local TICK_VOICES = 16
local RELEASE_VOICES = 8

-- Cùng lý do với `KeyCapper.Style.SoundGate`: hai bản sao của CÙNG một mẫu cách nhau vài
-- ms không nghe ra thành hai tiếng gõ, mà comb-filter với nhau thành một tiếng rỗng, méo.
-- Hai phím dính nhau trong một tick là chuyện thường (bàn chân phủ 2 cap), nên chặn.
local MIN_INTERVAL = 0.015

type Bank = { voices: { Sound }, cursor: number, lastPlay: number }

local banks: { [number]: Bank } = {}
local connection: RBXScriptConnection? = nil

local function newBank(id: number, count: number, maxDist: number, container: Instance): Bank
	local bank: Bank = { voices = table.create(count), cursor = 0, lastPlay = 0 }
	for i = 1, count do
		local part = Instance.new("Part")
		part.Name = ("KeyCapperVoice_%d_%d"):format(id, i)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one
		part.Parent = container

		-- SoundId CỐ ĐỊNH cả đời giọng. Gán lại id ngay trước :Play() là nguyên nhân của
		-- bug "âm sàn trả lời chậm" đã sửa ở ASMR/Engine/SoundPool — không lặp lại ở đây.
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. id
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = maxDist
		sound.Volume = 0
		sound.Parent = part

		table.insert(bank.voices, sound)
	end
	return bank
end

local function play(id: number, pos: Vector3, volume: number, pitch: number)
	local bank = banks[id]
	if not bank then
		return
	end
	local now = os.clock()
	if now - bank.lastPlay < MIN_INTERVAL then
		return
	end
	bank.lastPlay = now

	bank.cursor = bank.cursor % #bank.voices + 1
	local sound = bank.voices[bank.cursor]
	local part = sound.Parent :: BasePart
	part.Position = pos
	sound.Volume = volume
	sound.PlaybackSpeed = pitch
	sound.TimePosition = 0
	sound:Play()
end

function KeyCapperSFXController.Init() end

function KeyCapperSFXController.Start()
	local keyCapper = ReplicatedStorage:FindFirstChild("KeyCapper")
	local keyPressed = keyCapper and keyCapper:FindFirstChild("KeyPressed")
	if not (keyPressed and keyPressed:IsA("BindableEvent")) then
		return -- place này không cài KeyCapper
	end

	local container = Instance.new("Folder")
	container.Name = "KeyCapperSFXRuntime"
	container.Parent = workspace

	banks[TICK_ID] = newBank(TICK_ID, TICK_VOICES, TICK_MAX_DIST, container)
	banks[RELEASE_ID] = newBank(RELEASE_ID, RELEASE_VOICES, RELEASE_MAX_DIST, container)

	-- WARM: PreloadAsync chỉ tải bytes, lần :Play() ĐẦU của mỗi Sound vẫn phải decode.
	-- Chạy câm từng bank một — bật vài chục Sound cùng lúc thì phần dư bị audio engine bỏ
	-- qua và vẫn chưa decode (cùng bài học đã ghi trong ASMR/Engine/SoundPool).
	task.spawn(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({
				"rbxassetid://" .. TICK_ID,
				"rbxassetid://" .. RELEASE_ID,
			})
		end)
		for _, bank in banks do
			for _, sound in bank.voices do
				sound.Volume = 0
				sound:Play()
			end
			task.wait(0.05)
			for _, sound in bank.voices do
				sound:Stop()
			end
			bank.lastPlay = 0 -- đừng để lượt hâm chiếm mất khe MIN_INTERVAL đầu tiên
		end
	end)

	connection = (keyPressed :: BindableEvent).Event:Connect(function(model: Model)
		if typeof(model) ~= "Instance" then
			return
		end
		local hitbox = model:FindFirstChild("Hitbox")
		if not (hitbox and hitbox:IsA("BasePart")) then
			return
		end
		local pos = hitbox.Position

		-- tick phát CÙNG frame với thân ⇒ tai gộp thành một tiếng gõ có đầu sắc
		play(TICK_ID, pos, TICK_VOL, TICK_PITCH)

		if RELEASE_DELAY > 0 then
			task.delay(RELEASE_DELAY, function()
				play(RELEASE_ID, pos, RELEASE_VOL, RELEASE_PITCH)
			end)
		end
	end)
end

function KeyCapperSFXController.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return KeyCapperSFXController
