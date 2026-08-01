--!strict
-- Bảng tinh chỉnh Anti-Cheat (server-side movement validation).
--
-- Nguyên tắc: phát hiện dựa trên TỌA ĐỘ X-Z do server quan sát — client không thể giả mạo.
-- Ngưỡng phải đủ RỘNG để không phạt oan cơ chế hợp lệ (Slide ×1.45, Wall Run 60,
-- Zone 12 gió đẩy 180 studs/s, Zone 13 lò xo văng người) nhưng đủ CHẶT để chặn
-- speed hack / teleport hack / fly hack theo phương ngang.

local AntiCheatConfig = {
	-- Chu kỳ kiểm tra vị trí mỗi player (giây). 0.4s × 25 player = chi phí không đáng kể.
	CHECK_INTERVAL = 0.4,

	-- Hệ số nới so với WalkSpeed server cấp. Slide = ×1.45 nên 1.75 dư an toàn.
	SPEED_HEADROOM = 1.75,

	-- Sàn tốc độ cho phép (studs/s) — che các cơ chế cố định không phụ thuộc WalkSpeed
	-- (slide tối thiểu 28, wall run 60) ở level thấp khi WalkSpeed còn nhỏ.
	MIN_ALLOWED_SPEED = 65,

	-- Nới thêm theo stage đang chơi (studs/s) — các zone có cơ chế đẩy/văng hợp lệ.
	-- Key = ActiveStage attribute (server-set), value = allowance cộng thêm.
	STAGE_EXTRA_ALLOWANCE = {
		[12] = 220, -- Wind Tunnel: gió dịch chuyển 180 studs/s (client-side CFrame)
		[13] = 280, -- Spring Fling: lò xo văng người tốc độ cao
		[14] = 210, -- Quạt gió: đẩy ngang tối đa 160 studs/s (nền 30 + phạt 130 khi thiếu chuẩn)
	} :: { [number]: number },

	-- VI PHẠM TỐC ĐỘ (speed hack): vượt allowed × 1 → tính 1 strike.
	-- Đủ MAX_STRIKES trong STRIKE_WINDOW giây → giật ngược về vị trí hợp lệ cuối.
	MAX_STRIKES = 3,
	STRIKE_WINDOW = 8.0,

	-- VI PHẠM TELEPORT: dịch chuyển 1 tick vượt (allowed × dt + TELEPORT_SLACK) studs
	-- → giật ngược NGAY (không cần đủ strikes).
	TELEPORT_SLACK = 50,

	-- Sau khi server chủ động teleport (stage, revive, lobby, spawn) → miễn kiểm tra
	-- trong khoảng grace này rồi mới neo lại vị trí.
	TELEPORT_GRACE = 1.5,

	-- LEO THANG: hack kéo dài vẫn tiến được ~40% quãng đường giữa các lần giật ngược.
	-- Đủ số lần giật ngược trong cửa sổ → kill nhân vật (respawn lobby, mất tiến trình stage).
	ESCALATION_BAND_COUNT = 3,
	ESCALATION_WINDOW = 30.0,

	-- Log cảnh báo ra console server khi phát hiện vi phạm (tắt khi release nếu ồn).
	LOG_VIOLATIONS = true,
}

return AntiCheatConfig
