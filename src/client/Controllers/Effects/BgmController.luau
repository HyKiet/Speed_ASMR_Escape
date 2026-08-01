--!strict
-- BgmController.luau — Bộ điều khiển nhạc nền liên tục cho game (Client-side)
-- Tự động nạp qua framework và phát nhạc nền chạy tuần hoàn.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local BgmController = {}

-- Danh sách các bản nhạc nền điện tử, chạy tốc độ cao, sôi động (APM Licensed Music miễn phí của Roblox)
-- 1837879003 / 1840618037 / 1843415711 đã bị gỡ: asset không phải Sound ("Asset type does
-- not match requested type" trong console mỗi lần tới lượt phát). Mọi ID dưới đây đã
-- verify IsLoaded=true trong Studio 2026-07-15.
local PLAYLIST = {
	"rbxassetid://9043887091", -- 136.9s
	"rbxassetid://1837879082", -- 162.0s
	"rbxassetid://1848354536", -- 97.0s
}

local bgmSound: Sound? = nil
local currentTrackIndex = 1
local playToken = 0
-- Bật/tắt từ bảng Cài đặt (TopBarController). Khai báo TRƯỚC playNextTrack vì chính hàm
-- đó phải tự chặn: `Ended` của bài cuối vẫn bắn sau khi người chơi tắt nhạc.
local musicEnabled = true

local function playNextTrack()
	local sound = bgmSound
	if not sound or not musicEnabled then return end

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
	TweenService:Create(bgmSound, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0.04 }):Play()

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
