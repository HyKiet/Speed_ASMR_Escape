--!strict
-- Bản mẫu dữ liệu mặc định cho mỗi tài khoản người chơi.
-- Bump Tuning.CORE_LOOP_VERSION khi đổi schema để DataService chạy migration logic.

local DataTemplate = {
	Speed = 0,
	TotalWins = 0,
	CurrentRunWins = 0,
	Streak = 0,
	PersonalBestRunWins = 0,
	TotalDonatedRobux = 0,
	hasClaimedGroupReward = false,
	-- Vé quay chào mừng đã phát chưa (một lần cho mỗi tài khoản) — xem RouletteService.
	WelcomeSpinGranted = false,
	CoreLoopVersion = 0,
	HighestCompletedStage = 0,
	Rebirths = 0,
	Level = 1,
	XP = 0,
	--[[
		Pad cao nhất ĐÃ MUA — SỞ HỮU VĨNH VIỄN (GDD 3.0 §5.1).

		Từ 2026-09-06 đây lại là nguồn chân lý thật sự. Giữa 2026-08-22 và 2026-09-06 trường này
		chỉ là bản sao của "pad cao nhất mà số dư ví với tới", tính lại mỗi lần gọi — nên tiêu
		Wins làm người chơi tụt pad. Giờ nó chỉ tăng, không bao giờ giảm.
	]]
	HighestPadIndex = 1,
	EquippedTreadmill = "treadmill_1",
	EquippedTrail = "none",
	EquippedAura = "none",
	-- Khớp `Tuning.BASE_MAX_WALK_SPEED` (trần của Level 1). Giá trị này gần như không bao giờ
	-- được đọc: `DataService.normalizeData` ghi đè về trần mỗi lần nạp profile.
	CustomSpeedLimit = 14,
	--[[
		Mốc `os.time()` lúc rời game gần nhất — nguồn duy nhất của Treadmill Offline.
		0 = chưa từng ghi (tài khoản có trước tính năng) ⇒ OfflineEarningsService bỏ qua lượt
		đầu và chỉ bắt đầu tính từ lần thoát kế tiếp. Xem `Config/OfflineEarnings.luau`.
	]]
	LastOnlineTime = 0,
	--[[
		Speed offline ĐÃ TÍNH nhưng người chơi CHƯA bấm nhận.

		Nằm trong profile chứ không phải bộ nhớ phiên: người chơi đóng modal rồi thoát game
		không được mất phần thưởng của mình. Cộng dồn qua nhiều phiên nếu họ cứ lờ đi.

		Đây cũng là con số mà nút "Double It" nhân đôi — server đọc TỪ ĐÂY chứ không tin số
		client gửi lên.
	]]
	PendingOfflineSpeed = 0,
	--[[
		Vừa trúng aura Legendary 1% ở vòng quay mà CHƯA mở tab Auras xem.

		Nằm trong profile chứ không phải bộ nhớ phiên: trúng xong thoát game rồi mai vào lại thì
		chấm đỏ vẫn còn — người chơi không mất dấu món đồ hiếm nhất mình vừa có. Xoá khi họ mở
		tab Auras (`requestClearAuraDot`).
	]]
	UnseenAuraUnlock = false,
	-- Daily login (7-Day hardcore streak)
	DailyStreakDay = 0, -- số ngày đã nhận trong chuỗi hiện tại (0..7)
	-- Tổng số ngày điểm danh liên tục qua MỌI vòng 7 ngày. Không trao thưởng — chỉ để người đi
	-- 40 ngày liền có một con số để khoe, và để đo được nhóm gắn bó nhất. Reset cùng lúc với
	-- `DailyStreakDay` khi lỡ một ngày.
	LifetimeStreak = 0,
	DailyLastClaimDay = 0, -- số thứ tự ngày (os.time // 86400) của lần nhận gần nhất
	-- Auto-Rebirth (gamepass): bật sẵn khi mua pass, người chơi tự tắt được khi muốn dừng
	-- ở một level cao để chạy obby thay vì bị reset ngay lúc đủ điều kiện.
	AutoRebirthEnabled = true,
	-- Tutorial người chơi mới. `TutorialStep` = số bước ĐÃ xong (0..TUTORIAL_STEP_COUNT);
	-- `TutorialRewarded` chốt phần thưởng chỉ phát một lần, dù hoàn thành hay bấm Skip.
	-- Tách hai cờ vì người bấm Skip vẫn nhận thưởng nhưng KHÔNG được tính là đã đi hết
	-- phễu onboarding — số liệu phễu sẽ vô nghĩa nếu trộn hai nhóm này.
	TutorialStep = 0,
	TutorialSkipped = false,
	TutorialRewarded = false,
	-- Quest Chain sau tutorial. 0 = chưa khởi tạo; QuestService tự đặt vào mắt xích phù hợp
	-- với tiến trình hiện có mà không phát lại thưởng của các quest đã vượt qua.
	QuestIndex = 0,
	QuestProgress = 0,
	-- Daily Quests take over the same HUD after Quest Chain. Seed is the UTC day
	-- number; progress/claim arrays always have exactly three server-owned slots.
	DailyQuestSeed = 0,
	DailyQuestProgress = { 0, 0, 0 },
	DailyQuestClaimedAt = { 0, 0, 0 },
	DailyQuestRewardWins = 0,
	DailyQuestRewardSpeed = 0,
	-- Quyền sở hữu lưu bằng id ổn định, tách khỏi Animation assetId để asset có thể thay.
	UnlockedEmotes = {} :: { [string]: boolean },
	-- Speed Roulette
	SpinTickets = 0, -- vé quay hiện có (free tích tối đa 3, mua Robux/daily cộng thêm)
	--[[
		Starter Pack "Rookie Rocket" (xem Config/Economy/StarterPack.luau).
		`FirstJoinTime` = os.time() lần đầu profile được nạp; 0 = chưa ghi (tài khoản cũ có
		từ trước khi có gói này — DataService điền lúc load nên họ vẫn có đủ 48h).
		`StarterPackBought` vừa là cờ chống mua lần hai, vừa là nguồn của buff x2 Speed vĩnh
		viễn (ProgressionService đọc trực tiếp).
	]]
	FirstJoinTime = 0,
	StarterPackBought = false,
	UnlockedTreadmills = {
		["treadmill_1"] = true,
	} :: { [string]: boolean },
	UnlockedTrails = {
		["none"] = true,
	} :: { [string]: boolean },
	UnlockedAuras = {
		["none"] = true,
	} :: { [string]: boolean },
	RedeemedCodes = {} :: { [string]: boolean },
}

return DataTemplate
