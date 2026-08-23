--!strict
-- BgmController.luau — Bộ điều khiển nhạc nền liên tục cho game (Client-side)
-- Tự động nạp qua framework và phát nhạc nền chạy tuần hoàn.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local BgmController = {}

--[[
	ÂM LƯỢNG GỐC CỦA NHẠC NỀN — 0.025 → 0.45 (2026-08-22, user: "nhạc khá nhỏ, chỉnh về mức
	bình thường").

	Con số 0.025 cũ ra đời từ một lập luận đúng ("nhạc là Sound 2D không suy giảm theo khoảng
	cách nên nó át tiếng sàn ASMR") nhưng đã đi quá xa: tiếng sàn phát ở 0.5–1.15, nhạc ở
	0.025 là thấp hơn ~30 lần — không phải "nền", mà là im lặng.

	Giờ ĐÂY là mức BÌNH THƯỜNG của một Sound 2D (Sound.Volume mặc định của Roblox là 0.5), còn
	việc CÂN với tiếng sàn ASMR chuyển sang `AudioMixController.DEFAULT_MUSIC` (0.35) — tức là
	thành một thanh trượt trong Cài đặt mà người chơi kéo được, thay vì một hằng số chôn ở đây.
	Nghe thực tế = 0.45 × 0.35 ≈ 0.16.

	⚠️ ĐỔI SỐ NÀY THÌ PHẢI XEM LẠI `AudioMixController.DEFAULT_MUSIC`: hai con số nhân với
	nhau mới ra thứ người chơi nghe, sửa một mình con số này là lệch cả cán cân với ASMR.
]]
local BGM_VOLUME = 0.45

-- PLAYLIST (thay 2 bài ngày 2026-08-05 theo yêu cầu user).
-- Nguồn: APMOfficial (APM Music) — đây là thư viện NHẠC chính hãng trên Roblox.
-- Lưu ý: ProSoundEffects KHÔNG phát hành nhạc nền, thư viện của họ chỉ có hiệu ứng
-- (đã tra Creator Store 2026-08-05: mọi kết quả nhạc đều là APMOfficial/Distrokid).
--
-- Giữ "Paradise Falls" (bài user chấm) ở giữa; hai bài kia là bản nhạc KHÁC của APM,
-- chọn theo vai trò lounge/chill để không giành chỗ với tiếng ASMR.
-- Đã bỏ: 9043887091 "Lo-fi Chill A", 1848354536 "Relaxed Scene", và cả nhánh
-- Paradise Falls Alt1/Alt2 (user không muốn nghe lại cùng một bản nhạc).
--
-- LƯU Ý THẬT: loạt APM 18xxxxxxx trên Roblox KHÔNG có mô tả (đã tra GetProductInfo cho
-- 18 bài — trống hết), và tôi không nghe được, nên hai bài dưới là chọn theo TÊN + vai
-- trò chứ chưa ai thẩm định bằng tai. 8 ứng viên APM khác đã đo load OK nằm trong
-- `AllGameSounds_Review/3_Music/Ứng viên thay thế` — nghe rồi đổi ID thẳng vào đây.
-- Mọi ID dưới đây đã đo IsLoaded=true + TimeLength trong Studio 2026-08-05.
local PLAYLIST = {
	"rbxassetid://1839158106", -- Kendal Cafe    | APM | 120.4s
	"rbxassetid://1837879082", -- Paradise Falls | APM | 162.0s  ← bài user chấm
	"rbxassetid://1842600316", -- Sunday Vibe    | APM | 151.7s
}

local bgmSound: Sound? = nil
local currentTrackIndex = 1
local playToken = 0
-- Bật/tắt từ bảng Cài đặt (TopBarController). Khai báo TRƯỚC playNextTrack vì chính hàm
-- đó phải tự chặn: `Ended` của bài cuối vẫn bắn sau khi người chơi tắt nhạc.
local musicEnabled = true

local function playNextTrack()
	local sound = bgmSound
	if not sound or not musicEnabled then
		return
	end

	local trackId = PLAYLIST[currentTrackIndex]
	-- Chuyển mục chỉ số bài tiếp theo (tính trước để track hỏng cũng không kẹt vòng)
	currentTrackIndex = currentTrackIndex % #PLAYLIST + 1

	playToken += 1
	local token = playToken

	sound.SoundId = trackId
	sound.Volume = 0
	sound.TimePosition = 0
	sound.Looped = false -- Chơi hết bài để chuyển sang bài tiếp theo
	sound:Play()

	-- Fade in nhạc nền mượt mà trong 2 giây để tránh giật mình
	TweenService
		:Create(bgmSound, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = BGM_VOLUME })
		:Play()

	-- Watchdog: asset hỏng thì Ended KHÔNG BAO GIỜ bắn → nhạc nền chết lặng vĩnh viễn.
	-- Sau 6s chưa load được thì tự nhảy bài kế tiếp.
	task.delay(6, function()
		if token == playToken and bgmSound == sound and not sound.IsLoaded then
			warn(`[BgmController] Track {trackId} không load được — bỏ qua`)
			sound:Stop()
			playNextTrack()
		end
	end)
end

-- Tắt = dừng hẳn (không chỉ hạ volume) để không tốn CPU giải mã; bật lại phát bài kế tiếp.
function BgmController.SetEnabled(enabled: boolean)
	if musicEnabled == enabled then
		return
	end
	musicEnabled = enabled

	local sound = bgmSound
	if not sound then
		return
	end
	if enabled then
		playNextTrack()
	else
		playToken += 1 -- huỷ watchdog của bài đang phát
		sound:Stop()
	end
end

function BgmController.IsEnabled(): boolean
	return musicEnabled
end

function BgmController.Init()
	bgmSound = Instance.new("Sound")
	bgmSound.Name = "GameBackgroundMusic"
	bgmSound.Parent = SoundService

	bgmSound.Ended:Connect(function()
		playNextTrack()
	end)
end

function BgmController.Start()
	-- Chờ một chút sau khi vào game rồi bắt đầu phát nhạc
	task.delay(1, function()
		playNextTrack()
	end)
end

return BgmController
