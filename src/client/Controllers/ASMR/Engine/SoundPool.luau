--!strict
-- Bể giọng (voice) ASMR — MỖI SoundId có RIÊNG một nhóm Sound dựng sẵn từ lúc load.
--
-- VÌ SAO BỎ POOL 32 DÙNG CHUNG (bug "âm thanh sàn trễ", 2026-07-28):
--   Bản cũ giữ 32 Sound vô danh rồi mỗi bước chân lại GÁN LẠI `SoundId` + ĐỔI `Parent`
--   ngay trước `:Play()`. Với 8 biến thể ping-pong qua 32 ô, gần như KHÔNG lần nào ô được
--   chọn đang giữ đúng id cần phát ⇒ mỗi bước là một lần resolve asset + mở lại luồng phát,
--   `:Play()` bị treo tới khi asset sẵn sàng. Ở 250 studs/s người chơi đã chạy qua vài chục
--   studs trước khi tiếng kêu, nghe như "sàn trả lời chậm". PreloadAsync KHÔNG cứu được:
--   nó chỉ tải bytes, độ trễ nằm ở lần gán id kế tiếp.
--
-- Bản này: id -> N giọng, mỗi giọng là 1 Sound có SoundId CỐ ĐỊNH, Parent CỐ ĐỊNH
-- (Attachment riêng dưới Terrain). Lúc phát chỉ còn: dời Attachment + set Volume/Speed +
-- Play() ⇒ phát ngay trong frame, 0 Instance churn, 0 gán SoundId.

local ContentProvider = game:GetService("ContentProvider")

local SoundPool = {}

-- Số giọng/1 id: đủ cho các tiếng chồng nhau khi chạy nhanh (lát sàn dày ⇒ nhiều phím
-- cùng nhấn trong 1 frame) mà không cắt đuôi tiếng trước.
local VOICES_PER_ID = 4
local EAR_OFFSET = 4.5 -- studs lệch sang bên tai theo RightVector camera (binaural pan)

type Voice = { sound: Sound, anchor: Attachment }
type Bank = { voices: { Voice }, cursor: number }

local banks: { [number]: Bank } = {}
local fallback: Bank? = nil -- id lạ (không khai báo trong floor.soundIds) vẫn phát được

local function newVoice(id: number, container: Instance): Voice
	local anchor = Instance.new("Attachment")
	anchor.Name = "ASMRVoiceAnchor"
	anchor.Parent = workspace.Terrain

	local s = Instance.new("Sound")
	s.Name = "ASMRVoice_" .. id
	s.SoundId = if id > 0 then "rbxassetid://" .. id else ""
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	-- MinDistance rộng: tiếng bước chân phát ngay dưới chân, không muốn nó tụt âm lượng
	-- chỉ vì người chơi đã lướt qua vài chục studs trong lúc mẫu còn đang kêu.
	s.RollOffMinDistance = 30
	s.RollOffMaxDistance = 80
	s.Volume = 0
	s.Parent = anchor

	return { sound = s, anchor = anchor }
end

local function newBank(id: number, container: Instance): Bank
	local bank: Bank = { voices = table.create(VOICES_PER_ID), cursor = 0 }
	for _ = 1, VOICES_PER_ID do
		table.insert(bank.voices, newVoice(id, container))
	end
	return bank
end

function SoundPool.init(container: Instance, allIds: { number })
	for _, id in allIds do
		if not banks[id] then
			banks[id] = newBank(id, container)
		end
	end
	fallback = newBank(0, container)

	task.spawn(function()
		local assets = {}
		for _, id in allIds do
			table.insert(assets, "rbxassetid://" .. id)
		end
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
		-- WARM: PreloadAsync chỉ tải bytes; lần Play ĐẦU TIÊN của mỗi Sound vẫn phải decode.
		-- Vì giọng nào cũng giữ id cố định, chỉ cần chạy câm đúng 1 lượt ở đây là từ đó về
		-- sau mọi Play() đều tức thì.
		-- Hâm theo TỪNG BANK rồi tắt ngay: audio engine có trần số giọng phát đồng thời,
		-- bật cả vài trăm Sound một lúc thì phần dư bị bỏ qua và... vẫn chưa decode.
		for _, bank in banks do
			for _, v in bank.voices do
				v.sound.Volume = 0
				v.sound:Play()
			end
			task.wait(0.05)
			for _, v in bank.voices do
				v.sound:Stop()
			end
		end
	end)
end

local function takeVoice(id: number): Voice?
	local bank = banks[id]
	if not bank then
		-- id chưa khai báo: dùng bank dự phòng (có gán SoundId ⇒ vẫn trễ như bản cũ,
		-- nhưng chỉ xảy ra nếu floor quên đưa id vào `soundIds`).
		bank = fallback
		if not bank then
			return nil
		end
		bank.cursor = bank.cursor % VOICES_PER_ID + 1
		local v = bank.voices[bank.cursor]
		local url = "rbxassetid://" .. id
		if v.sound.SoundId ~= url then
			v.sound.SoundId = url
		end
		return v
	end
	bank.cursor = bank.cursor % VOICES_PER_ID + 1
	return bank.voices[bank.cursor]
end

local function fire(v: Voice, pos: Vector3, volume: number, speed: number, maxDist: number?)
	v.anchor.WorldPosition = pos
	v.sound.Volume = volume
	v.sound.PlaybackSpeed = speed
	local md = maxDist or 80
	if v.sound.RollOffMaxDistance ~= md then
		v.sound.RollOffMaxDistance = md
	end
	v.sound.TimePosition = 0
	v.sound:Play()
end

-- Giữ chữ ký cũ: `parent` chỉ dùng để lấy vị trí phát (Sound không còn đổi Parent nữa).
function SoundPool.play(id: number, parent: Instance, volume: number, speed: number, maxDist: number?)
	local v = takeVoice(id)
	if not v then
		return
	end
	local pos = if parent:IsA("BasePart") then parent.Position elseif parent:IsA("Attachment") then parent.WorldPosition else Vector3.zero
	fire(v, pos, volume, speed, maxDist)
end

-- Binaural footstep "Clean Your Brain": phát sound tại basePos lệch sang bên tai
-- pan ∈ [-1, 1] (âm = tai Trái, dương = tai Phải) theo RightVector của camera —
-- audio engine 3D của Roblox tự đảo kênh stereo, không cần EQ/plugin.
function SoundPool.playPanned(id: number, basePos: Vector3, volume: number, speed: number, pan: number, maxDist: number?)
	local v = takeVoice(id)
	if not v then
		return
	end
	local cam = workspace.CurrentCamera
	local right = if cam then cam.CFrame.RightVector else Vector3.xAxis
	fire(v, basePos + right * (pan * EAR_OFFSET), volume, speed, maxDist)
end

-- Binaural bước chân dùng CHUNG cho mọi sàn: tự đảo tai Trái ↔ Phải mỗi lần gọi
-- (mọi adapter chỉ cần đổi play() → playStep()).
local stepSide = false
function SoundPool.playStep(id: number, basePos: Vector3, volume: number, speed: number, maxDist: number?)
	stepSide = not stepSide
	SoundPool.playPanned(id, basePos, volume, speed, if stepSide then 0.85 else -0.85, maxDist)
end

return SoundPool
