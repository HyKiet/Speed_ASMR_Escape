--!strict
-- Bản mẫu dữ liệu mặc định cho mỗi tài khoản người chơi.
-- Bump Tuning.CORE_LOOP_VERSION khi đổi schema để DataService chạy migration logic.

local DataTemplate = {
	Speed = 0,
	TotalWins = 0,
	CurrentRunWins = 0,
	Streak = 0,
	PersonalBestDistance = 0,
	PersonalBestRunWins = 0,
	TotalRuns = 0,
	TotalDonatedRobux = 0,
	hasClaimedGroupReward = false,
	hasConfirmedLikeGroupReward = false,
	CoreLoopVersion = 0,
	HighestCompletedStage = 0,
	Rebirths = 0,
	Level = 1,
	XP = 0,
	-- Pad cao nhất ĐÃ MỞ KHÓA (mua tuần tự, không cắt ngang). pad_1 free => mặc định 1.
	HighestPadIndex = 1,
	EquippedTreadmill = "treadmill_1",
	EquippedTrail = "none",
	EquippedAura = "none",
	CustomSpeedLimit = 12,
	-- Daily login (7-Day hardcore streak)
	DailyStreakDay = 0, -- số ngày đã nhận trong chuỗi hiện tại (0..7)
	DailyLastClaimDay = 0, -- số thứ tự ngày (os.time // 86400) của lần nhận gần nhất
	-- Auto-Rebirth (gamepass): bật sẵn khi mua pass, người chơi tự tắt được khi muốn dừng
	-- ở một level cao để chạy obby thay vì bị reset ngay lúc đủ điều kiện.
	AutoRebirthEnabled = true,
	-- Speed Roulette
	SpinTickets = 0, -- vé quay hiện có (free tích tối đa 3, mua Robux/daily cộng thêm)
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
