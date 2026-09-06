--!strict
-- Các hằng số tinh chỉnh nhịp game (rate, interval, ngưỡng).
-- CORE_LOOP_VERSION bump khi đổi công thức quan trọng — DataService sẽ migrate.

local Tuning = {
	-- 4 → 5 (2026-09-06, GDD 3.0): đường cong XP hai băng + pad chuyển từ ngưỡng ví sang mua
	-- vĩnh viễn. Cả hai đều cần migration trong `DataService.normalizeData`.
	CORE_LOOP_VERSION = 5,
	BASE_SPEED_GAIN = 1,
	--[[
		6 → 14 (2026-08-27). PHẢI KHỚP `StarterPlayer.CharacterWalkSpeed` trong map.

		Hằng số này đeo hai vai cùng lúc, và cả hai đều muốn 14:
		  • Giá trị StarterPlayer cấp cho nhân vật vừa spawn/hồi sinh. Ở 6 thì mỗi lần hồi sinh
		    người chơi cầm lái một nhân vật bò 6 studs/s trong ~40–270 ms trước khi
		    `ProgressionService.applyWalkSpeed` kịp chạy (đo 2026-08-19). Bằng 14 thì khoảng
		    bò đó biến mất cả về con số lẫn cảm giác.
		  • Sàn kẹp của `CustomSpeedLimit`. Trần Level 1 giờ là 14, nên để sàn ở 6 chỉ tạo ra
		    một dải 6–13 mà không ai muốn dùng và người chơi mới thì không chọn được gì cả.

		⚠️ Đổi số này mà quên đổi `StarterPlayer.CharacterWalkSpeed` trong map (hoặc ngược lại)
		là hai nguồn sự thật lệch nhau — lỗi sẽ hiện ra dưới dạng "hồi sinh xong bị đơ một nhịp",
		đúng cái bug đã mất công truy 2026-08-19.
	]]
	DEFAULT_WALK_SPEED = 14,
	--[[
		12 → 14 (2026-08-27). Đây là con số CHỐNG NGÃ, không phải một nấc cân bằng tự do.

		Tầm nhảy = WalkSpeed × 0,542 s (JumpHeight 7.2, Gravity 196.2). Hố rộng nhất ở Stage 1
		là 6,5 studs ⇒ ở WS 12 tầm nhảy đúng bằng 6,50: BIÊN ĐỘ BẰNG KHÔNG, mỗi cú nhảy là một
		lần tung đồng xu. Phễu Onboarding đo được đúng hệ quả đó: 0,87^6 = 43,4% so với
		FirstStageClear thật là 43,89%. Ở WS 14 tầm nhảy thành 7,59 ⇒ dư 1,09 studs.

		Trần 250 vẫn giữ nguyên: `GetMaxWalkSpeed` kẹp bằng `math.min(250, …)` nên với base 14
		và +2/level thì trần chạm ở Level 119 thay vì 120. Không có gì phải sửa thêm.

		⚠️ ĐỔI SỐ NÀY = ĐỔI TẦM NHẢY CỦA CẢ 15 ZONE. Trước khi hạ xuống lại, phải đo lại hố
		rộng nhất của mọi stage (raycast dọc trục chạy, chỉ tính bề mặt yHit > 0) và giữ luật:
		hố ≤ WalkSpeed_trần_của_stage × 0,542 − 2 studs.
	]]
	BASE_MAX_WALK_SPEED = 14,
	WALK_SPEED_PER_LEVEL = 2,
	SPEED_GAIN_INTERVAL = 0.35,
	MIN_MOVEMENT_FOR_SPEED_GAIN = 1.5,
	TREADMILL_GAIN_RADIUS = 5,
	NETWORK_RATE_LIMIT_SECONDS = 0.4,
	XP_CONVERSION_RATE = 1,
}

return Tuning
