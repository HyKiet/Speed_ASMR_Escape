--!strict
--[[
	AudioMixController.luau — bàn trộn âm thanh 4 kênh cho bảng Cài đặt (CLIENT-ONLY).

	VÌ SAO BẢN NÀY KHÁC "Audio.luau/AudioMixer" ĐÃ GỠ NGÀY 2026-08-05:
	  Bản cũ bắt MỌI controller phải gọi qua một helper chung để dựng Sound. Đó là lý do nó
	  chết: chỉ cần một controller quên gọi là tiếng đó nằm ngoài mixer, và cả 20 chỗ dựng
	  Sound trong game đều phải sửa theo.
	  Bản này KHÔNG đụng vào một dòng nào của các controller phát tiếng. Nó chỉ dựng sẵn 4
	  `SoundGroup` rồi TỰ ĐỘNG nhận nuôi mọi `Sound` xuất hiện trong game (SoundService,
	  Workspace, PlayerGui). Volume viết cứng trong từng controller giữ nguyên — SoundGroup
	  nhân thêm hệ số lên trên, nên tắt hết slider về 100% là game nghe y hệt bản QA.

	4 KÊNH:
	  master — trùm tất cả (KHÔNG phải một SoundGroup: xem `applyAll`)
	  music  — nhạc nền (Sound tên "GameBackgroundMusic" của BgmController)
	  asmr   — tiếng sàn ASMR (mọi giọng "ASMRVoice_*" của Engine/SoundPool)
	  sfx    — phần còn lại: UI click, toast, level-up, bẫy zone, quạt gió, treadmill…

	PHÂN LOẠI THEO TÊN chứ không theo vị trí: giọng ASMR nằm dưới Terrain (Attachment), tiếng
	zone nằm rải rác trong Workspace, tiếng UI thì lúc ở SoundService lúc ở PlayerGui — không
	có cây nào gom đủ. Tên thì SoundPool và BgmController đặt cố định, tra một lần là xong.

	KHÔNG LƯU QUA PHIÊN: giống Performance/Night Mode, chỉnh xong thoát game là về mặc định.
	Roblox không có local storage cho game; muốn lưu thì phải đẩy qua DataStore phía server.
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local AudioMixController = {}

export type Channel = "master" | "music" | "asmr" | "sfx"

local ASMR_PREFIX = "ASMRVoice_"
local BGM_NAME = "GameBackgroundMusic"

-- CHỈ 3 SoundGroup thật (music/asmr/sfx). KHÔNG có group "master".
-- ⚠️ `SoundGroup.SoundGroup` KHÔNG TỒN TẠI trên engine hiện tại (đã đo 2026-08-07: gán vào
-- báo "SoundGroup is not a valid member of SoundGroup") — nghĩa là SoundGroup KHÔNG lồng
-- nhau được, không có cách nào để một group cha nhân volume xuống group con. Vì vậy master
-- là một hệ số thuần Lua, nhân tay vào cả ba group mỗi lần đổi.
local groups: { [string]: SoundGroup } = {}
-- Mức người chơi đặt (0..1). `master` không phải group nên nhân tay vào cả ba (xem trên).
-- ⚠️ Kênh `sfx` KHÔNG còn slider trong Settings (gỡ 2026-08-09) nhưng PHẢI giữ nguyên nhóm:
-- mọi Sound không phải nhạc và không phải tiếng sàn đều chảy qua đây, bỏ nhóm đi là slider
-- Master mất quyền với tiếng UI, toast, level-up và bẫy zone. Nó đứng yên ở 1.
--[[
	MẶC ĐỊNH KÊNH NHẠC = 0.35, KHÔNG PHẢI 1 (2026-08-22, user).

	`BgmController.BGM_VOLUME` giờ là âm lượng BÌNH THƯỜNG của một Sound 2D (0.45) chứ không
	còn là 0.025 — con số cũ nhỏ tới mức nhạc thành ra không tồn tại. Chỗ cân bằng với tiếng
	sàn ASMR chuyển về ĐÂY, tức về một thanh trượt người chơi kéo được, thay vì bị chôn trong
	một hằng số mà chỉ lập trình viên mới với tới.

	0.35 × 0.45 ≈ 0.16 hiệu dụng. Tiếng sàn ASMR phát ở 0.5–1.15 (3D, RollOff 70) nên ở cự ly
	chân người nhạc nằm khoảng 1/5 tiếng sàn: nghe rõ là có nhạc, không giành chỗ với ASMR.
	Người muốn nhạc to cứ kéo lên 1 (0.45 hiệu dụng — đúng mức nhạc nền game thường).
]]
AudioMixController.DEFAULT_MUSIC = 0.35

local levels: { [string]: number } = { master = 1, music = AudioMixController.DEFAULT_MUSIC, asmr = 1, sfx = 1 }

local function applyAll()
	local master = levels.master
	for _, name in { "music", "asmr", "sfx" } do
		local group = groups[name]
		if group then
			group.Volume = master * levels[name]
		end
	end
end

-- ── Nhận nuôi Sound ──────────────────────────────────────────────────────────

local function channelFor(sound: Sound): string
	local name = sound.Name
	if string.sub(name, 1, #ASMR_PREFIX) == ASMR_PREFIX then
		return "asmr"
	elseif name == BGM_NAME then
		return "music"
	end
	return "sfx"
end

local function adopt(instance: Instance)
	-- So sánh ClassName thay vì IsA: hàm này chạy cho MỌI instance stream vào Workspace
	-- (hàng nghìn part mỗi lần đổi zone), nên phải rẻ nhất có thể. Sound không có lớp con.
	if instance.ClassName ~= "Sound" then
		return
	end
	local sound = instance :: Sound
	-- Đã thuộc nhóm nào đó rồi thì để yên — không cướp nhóm mà code khác cố tình gán.
	if sound.SoundGroup ~= nil then
		return
	end
	sound.SoundGroup = groups[channelFor(sound)]
end

local function sweep(root: Instance)
	for _, descendant in root:GetDescendants() do
		adopt(descendant)
	end
end

local function watch(root: Instance)
	sweep(root)
	root.DescendantAdded:Connect(adopt)
end

-- ── API cho SettingsModal ────────────────────────────────────────────────────

function AudioMixController.SetVolume(channel: Channel, level: number)
	levels[channel] = math.clamp(level, 0, 1)
	applyAll()
end

function AudioMixController.GetVolume(channel: Channel): number
	return levels[channel] or 1
end

-- ĐÃ GỠ 2026-08-09 (user chốt bỏ khỏi Settings): `SetMuteOnBlur`/`IsMuteOnBlur` + hai
-- connection `WindowFocusReleased`/`WindowFocused`. Không còn UI nào bật được nó, để lại
-- chỉ là hai handler chạy suốt đời mà cờ `muteOnBlur` vĩnh viễn false.

function AudioMixController.Init()
	for _, name in { "music", "asmr", "sfx" } do
		local group = Instance.new("SoundGroup")
		group.Name = "Mix_" .. name
		group.Volume = 1
		group.Parent = SoundService
		groups[name] = group
	end
	-- ⚠️ BẮT BUỘC: trước 2026-08-22 mọi kênh mặc định là 1 nên "dựng group xong là xong".
	-- Nay `music` mặc định 0.35 — không gọi `applyAll` ở đây thì mức mặc định chỉ có hiệu lực
	-- sau lần đầu người chơi kéo slider, tức là không bao giờ với đa số người chơi.
	applyAll()
end

function AudioMixController.Start()
	watch(SoundService)
	watch(Workspace)

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		watch(playerGui)
	end
end

return AudioMixController
