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
--
-- 4 chỉ đủ khi sàn có NHIỀU id luân phiên (8 id × 4 = 32 giọng thật). Sàn nào rút về
-- một mẫu duy nhất thì 4 giọng là quá ít: giọng bị cướp lại trước khi mẫu kêu xong nên
-- người chơi chỉ nghe được phần đầu. Đo trên sàn phím (mẫu 0.18s): ở 300 WS có 120
-- lượt nhấn/giây, 4 giọng ⇒ mỗi mẫu chỉ kêu được 19% rồi bị cắt — nghe như mất tiếng.
-- Sàn như vậy khai báo `Floor.voices = { [id] = n }`, xem SoundPool.init.
local VOICES_PER_ID = 4
local EAR_OFFSET = 4.5 -- studs lệch sang bên tai theo RightVector camera (binaural pan)
--[[
	TRẦN GÓC PAN (2026-08-21).

	`EAR_OFFSET` là khoảng cách TUYỆT ĐỐI (studs), nhưng tai nghe ra GÓC chứ không nghe ra
	studs: cùng 4.5 studs lệch ngang thì ở camera thứ ba (≈15 studs) chỉ là ~17°, còn khi
	người chơi zoom sát/vào góc nhìn thứ nhất (CameraMinZoomDistance = 0.5, xem
	`Effects/SpeedVFXController`) thì listener nằm ngay trên đầu nhân vật và 4.5 studs lệch
	ngang thành gần 90° — audio engine đổ trọn tiếng sang MỘT bên tai. Bước chân đảo tai
	luân phiên lúc đó không còn là "binaural", nó là tiếng nhảy hẳn trái ↔ hẳn phải.

	Kẹp offset theo khoảng cách tới listener: offset ≤ d × MAX_PAN_TAN ⇒ góc pan không bao
	giờ vượt ~18°. Ở camera thứ ba bình thường (d ≥ 14) phép kẹp KHÔNG đụng gì (14 × 0.325 =
	4.55 > 4.5), nên mọi sàn giữ nguyên cảm giác đã chốt; nó chỉ hạ tay khi camera lại gần.
]]
local MAX_PAN_TAN = 0.325 -- tan(18°)

type Voice = { sound: Sound, anchor: Attachment }
type Bank = { voices: { Voice }, cursor: number, size: number }
-- Gain dB cho EqualizerSoundEffect gắn CỐ ĐỊNH lên từng giọng của một id.
-- Dùng cho mẫu bị chói ở dải cao (nốt piano pitch-shift lên là ví dụ kinh điển):
-- hạ HighGain nghe mềm hẳn, đúng chất ASMR, mà không cần đổi file audio.
export type VoiceFx = { low: number?, mid: number?, high: number? }

local banks: { [number]: Bank } = {}
local fallback: Bank? = nil -- id lạ (không khai báo trong floor.soundIds) vẫn phát được

local function newVoice(id: number, container: Instance, fx: VoiceFx?): Voice
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

	if fx then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = fx.low or 0
		eq.MidGain = fx.mid or 0
		eq.HighGain = fx.high or 0
		eq.Parent = s
	end

	return { sound = s, anchor = anchor }
end

local function newBank(id: number, container: Instance, size: number?, fx: VoiceFx?): Bank
	local n = size or VOICES_PER_ID
	local bank: Bank = { voices = table.create(n), cursor = 0, size = n }
	for _ = 1, n do
		table.insert(bank.voices, newVoice(id, container, fx))
	end
	return bank
end

-- `voiceCounts` (tuỳ chọn): id -> số giọng, cho sàn cần nhiều giọng hơn mặc định.
-- `voiceFx` (tuỳ chọn): id -> gain EQ, cho mẫu cần làm mềm dải cao.
function SoundPool.init(
	container: Instance,
	allIds: { number },
	voiceCounts: { [number]: number }?,
	voiceFx: { [number]: VoiceFx }?
)
	for _, id in allIds do
		if not banks[id] then
			banks[id] = newBank(id, container, voiceCounts and voiceCounts[id], voiceFx and voiceFx[id])
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
		bank.cursor = bank.cursor % bank.size + 1
		local v = bank.voices[bank.cursor]
		local url = "rbxassetid://" .. id
		if v.sound.SoundId ~= url then
			v.sound.SoundId = url
		end
		return v
	end
	bank.cursor = bank.cursor % bank.size + 1
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
	local pos = if parent:IsA("BasePart")
		then parent.Position
		elseif parent:IsA("Attachment") then parent.WorldPosition
		else Vector3.zero
	fire(v, pos, volume, speed, maxDist)
end

-- Binaural footstep "Clean Your Brain": phát sound tại basePos lệch sang bên tai
-- pan ∈ [-1, 1] (âm = tai Trái, dương = tai Phải) theo RightVector của camera —
-- audio engine 3D của Roblox tự đảo kênh stereo, không cần EQ/plugin.
function SoundPool.playPanned(
	id: number,
	basePos: Vector3,
	volume: number,
	speed: number,
	pan: number,
	maxDist: number?
)
	local v = takeVoice(id)
	if not v then
		return
	end
	local cam = workspace.CurrentCamera
	local right = if cam then cam.CFrame.RightVector else Vector3.xAxis
	-- Xem khối `MAX_PAN_TAN`: kẹp theo khoảng cách tới listener để góc pan có trần.
	local ear = EAR_OFFSET
	if cam then
		ear = math.min(ear, (cam.CFrame.Position - basePos).Magnitude * MAX_PAN_TAN)
	end
	fire(v, basePos + right * (pan * ear), volume, speed, maxDist)
end

--[[
	Binaural bước chân dùng CHUNG cho mọi sàn: tự đảo tai Trái ↔ Phải mỗi lần gọi
	(mọi adapter chỉ cần đổi play() → playStep()).

	`panScale` (tuỳ chọn, mặc định 1) — ĐỘ RỘNG stereo của riêng một sàn.

	Vì sao cần knob theo TỪNG SÀN chứ không một số chung: mức đảo tai đọc ra là "êm" hay là
	"ngoáy trái-phải" phụ thuộc vào việc người chơi nghe nó BAO LÂU, chứ không phụ thuộc con số.
	Sàn trong zone dài vài chục studs — chạy 100–250 WS thì nghe chưa tới 2 giây rồi sang sàn
	khác, ±0.85 ở đó là chi tiết ASMR đúng như đã chốt. Sàn cát Lobby thì trải 5.180 ô kín cả
	sảnh, người chơi đứng/đi trên nó HÀNG PHÚT trong lúc nền âm hoàn toàn yên tĩnh — cùng một
	±0.85 nghe liên tục vài phút thì não ngừng nghe ra "bước chân" và bắt đầu nghe ra cái máy
	đảo kênh. Đây là lý do user báo riêng sàn Lobby, hai lần, dù mọi sàn dùng chung một hàm.

	⚠️ 0 = tắt hẳn pan (phát ngay dưới chân, giữa hai tai). Đừng đổi mặc định 1 ở đây để "sửa
	một thể cho mọi sàn" — các sàn zone đã được user nghe và chốt.
]]
local stepSide = false
function SoundPool.playStep(
	id: number,
	basePos: Vector3,
	volume: number,
	speed: number,
	maxDist: number?,
	panScale: number?
)
	stepSide = not stepSide
	local swing = 0.85 * (panScale or 1)
	SoundPool.playPanned(id, basePos, volume, speed, if stepSide then swing else -swing, maxDist)
end

return SoundPool
