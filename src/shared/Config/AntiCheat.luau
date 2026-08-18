--!strict
-- Bảng tinh chỉnh Anti-Cheat (server-side movement validation).
--
-- Nguyên tắc: phát hiện dựa trên TỌA ĐỘ X-Z do server quan sát — client không thể giả mạo.
-- Ngưỡng phải đủ RỘNG để không phạt oan cơ chế hợp lệ (Slide ×1.45, Wall Run 60,
-- Zone 12 gió đẩy 180 studs/s, Zone 13 lò xo văng người) nhưng đủ CHẶT để chặn
-- speed hack / teleport hack / fly hack theo phương ngang.

local AntiCheatConfig = {
	--[[
		BẬT LẠI 2026-08-18 sau khi QA xác minh được exploit thật: client tự đặt
		`Humanoid.WalkSpeed = 5000` và giữ nguyên sau 6 giây — server không hề kéo về.

		(Trước đó tắt từ 2026-08-03 để test di chuyển.)

		── ĐỐI CHIẾU NGƯỠNG TRƯỚC KHI BẬT (làm 2026-08-18) ────────────────────────────────
		Trần WalkSpeed hợp lệ = 250 (`Formulas.GetMaxWalkSpeed` kẹp cứng), nên mức cho phép
		cao nhất = 250 × 1.75 = 437 studs/s, cộng allowance riêng của zone. Đối chiếu với mọi
		cơ chế đẩy hợp lệ đang có:
		  • Slide `InitialSpeedMultiplier` = 1.45  < SPEED_HEADROOM 1.75 ✓
		  • Wall run 60, slide sàn 28             < MIN_ALLOWED_SPEED 65 ✓
		  • Zone 12 `WIND_VELOCITY` = 170         < allowance 220 ✓
		  • Zone 14 gió 30 + 130 = 160            < allowance 210 ✓
		  • Zone 13 lò xo                          → allowance 280 ✓
		Không tìm thấy băng chuyền / `AssemblyLinearVelocity` bề mặt nào trong repo, nên không
		có nguồn dịch chuyển "không do WalkSpeed" nào khác cần nới.

		⚠️ CÒN PHẢI NGHIỆM THU BẰNG PLAYTEST: Zone 15 KHÔNG có entry trong
		`STAGE_EXTRA_ALLOWANCE`. Nó chỉ an toàn nếu SplitFloor/ShiftBridge là sàn dịch chuyển
		bằng CFrame chậm. Chạy thật qua Zone 15 và soi log `[AntiCheat]` trước khi publish —
		nếu thấy giật ngược oan thì thêm `[15] = <studs/s của sàn> + 60`.
	]]
	ENABLED = true,

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
