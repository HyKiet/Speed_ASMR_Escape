--!strict
--[[
	ParkourConfig.luau — BẢNG TINH CHỈNH GAME FEEL (cảm giác tay)

	>>> ĐÂY LÀ FILE DUY NHẤT BẠN CẦN SỬA ĐỂ CHỈNH "CẢM GIÁC TAY" <<<

	"The Accessible Flow": hệ đã được TỐI GIẢN cho game thủ casual — chỉ còn
	  • Power Slide [C]
	  • Wall Run (tự động)
	cùng locomotion (Walk F / Sprint F). Mọi thông số vật lý, Animation ID, phím bấm ở đây.

	Đơn vị: Vận tốc = studs/giây · Lực (VectorForce) nhân theo AssemblyMass · Thời gian = giây ·
	Khoảng cách = studs · Góc = độ.
]]

local ParkourConfig = {}

-- =====================================================================
-- 0. PHÍM BẤM (Input)
-- =====================================================================
ParkourConfig.Keys = {
	Slide = Enum.KeyCode.C, -- Power Slide
	WallJump = Enum.KeyCode.Space, -- Nhảy bật khỏi tường (lúc đang Wall Run)
}

-- Phím tương đương trên tay cầm (gamepad). Đặt nil nếu không muốn hỗ trợ.
ParkourConfig.GamepadKeys = {
	Slide = Enum.KeyCode.ButtonL3,
	WallJump = Enum.KeyCode.ButtonA,
}

-- =====================================================================
-- 1. ANIMATION (chuẩn R15)
-- =====================================================================
ParkourConfig.Animations = {
	Slide = "rbxassetid://115997630662112",
}

-- Thời gian blend (fade) khi bật/tắt animation (giây). ~0.15 để Đi → Trượt hòa trộn mượt.
ParkourConfig.AnimFade = {
	Slide = 0.15,
	WallRunRight = 0.15,
	WallRunLeft = 0.15,
	WallRunRightIdle = 0.18,
	WallRunLeftIdle = 0.18,
	Default = 0.15, -- fade mặc định cho mọi anim không liệt kê ở trên
}

-- =====================================================================
-- 2. SPRINT (chạy nước rút tự động)
-- =====================================================================
ParkourConfig.Sprint = {
	-- Khi Humanoid.WalkSpeed VƯỢT ngưỡng này → thay anim chạy mặc định bằng "Sprint F".
	SpeedThreshold = 25,
}

-- =====================================================================
-- 2b. ACTIVE BRAKING (phanh chủ động khi thả phím di chuyển)
-- =====================================================================
ParkourConfig.Braking = {
	-- Bật/tắt toàn bộ cơ chế phanh.
	Enabled = true,

	-- Gia tốc phanh (studs/s²). Càng LỚN dừng càng "khựng"; 550 ≈ từ 250 studs/s
	-- về 0 trong ~0.45s → dừng gọn, hết "trôi băng" khi thả phím.
	BrakeAccel = 550,

	-- Chỉ phanh khi tốc độ ngang còn trên mức này; xuống dưới → triệt tiêu hẳn về 0.
	StopSpeedThreshold = 3.0,

	-- Không phanh nếu tốc độ dưới mức này (đi bộ chậm tự dừng tự nhiên, đỡ tốn constraint).
	MinSpeedToBrake = 6.0,

	-- Phanh ĐỘNG theo tốc độ: gia tốc phanh thực tế = max(BrakeAccel, tốc độ × hệ số này).
	-- Ở 250 studs/s → 250×3 = 750 studs/s² (dừng trong ~0.33s / ~42 studs thay vì 0.45s/57).
	-- Tốc độ càng cao phanh càng gắt → quãng trượt khi thả phím gần như KHÔNG đổi theo speed.
	BrakeAccelPerSpeed = 3.0,
}

-- =====================================================================
-- 2b2. TURN ASSIST (bẻ lái dính đường ở tốc độ cao)
-- =====================================================================
-- Ở 250 studs/s, đổi hướng WASD nhưng vận tốc cũ vẫn kéo theo quán tính → cua thành vòng
-- rộng, khó canh cửa/khe hẹp. Turn Assist XOAY vector vận tốc ngang về hướng phím đang bấm
-- (giữ nguyên độ lớn — không mất đà) khi đang chạy trên đất → cua gắt, đi đúng nét vẽ.
-- KHÔNG áp khi trên không / slide / wall-run → giữ nguyên vật lý bay obby & cơ chế zone.
ParkourConfig.TurnAssist = {
	Enabled = true,
	-- Tốc độ xoay (1/giây, exp smoothing). 9 ≈ bám hướng mới trong ~0.25s. Tăng = lái "arcade"
	-- hơn; giảm = giữ quán tính "vật lý" hơn.
	Rate = 9,
	-- Chỉ hỗ trợ khi tốc độ ngang vượt mức này (dưới ngưỡng humanoid tự xử tốt rồi).
	MinSpeed = 30,
}

-- =====================================================================
-- 2b3. ANTI-FLING (chống văng xoáy khi va đập)
-- =====================================================================
-- Va đập mạnh (tông khối vật lý, bị vật thể đẩy) có thể bơm vận tốc GÓC khổng lồ vào
-- nhân vật → xoay tít + văng quỹ đạo loạn. Kẹp vận tốc góc lại là hết xoáy;
-- vận tốc NGANG thừa đã có Grip cắt khi chạm đất.
ParkourConfig.AntiFling = {
	Enabled = true,
	-- Trần vận tốc góc (rad/s). Xoay người bình thường của humanoid < 10; vượt 18 chắc chắn
	-- là đang bị văng xoáy → giữ lại mỗi trục Y (xoay ngang), triệt tiêu lộn nhào.
	MaxAngularSpeed = 18,

	-- ── WALL GUARD: chống văng khi TÔNG TƯỜNG ở tốc độ cao ──
	-- Cơ chế văng: lao 250 studs/s vào tường, engine giải xuyên thấu bằng một XUNG đẩy
	-- ngược + hất lên trong 1 tick vật lý → nhân vật bắn lên trời/bật ngược. Grip không
	-- cứu được vì ngay sau cú hất người đã Ở TRÊN KHÔNG (Grip chỉ chạy khi Grounded).
	-- Wall Guard xử TRƯỚC + SAU: (1) raycast theo hướng vận tốc, thấy tường đứng trong
	-- tầm nhìn-trước → CẮT thành phần vận tốc lao vào tường (đỡ đập); (2) mở "cửa sổ
	-- hậu va chạm" — trong cửa sổ này kẹp vận tốc bật lên + vận tốc ngang về trần Grip
	-- kể cả khi đang trên không.
	WallGuard = {
		Enabled = true,
		-- Chỉ dò khi tốc độ ngang vượt mức này (đi chậm tông tường không văng nổi).
		MinSpeed = 45,
		-- Tầm nhìn-trước = tốc độ × giá trị này (giây), tối thiểu 3 studs.
		-- 0.06 @250 = 15 studs — đủ sớm để cắt vận tốc trước khi engine kịp sinh xung.
		ProbeAhead = 0.06,
		-- Trần vận tốc BẬT LÊN (trục Y) trong cửa sổ hậu va chạm. 26 < JumpPower nên
		-- không phá cú nhảy chủ động; xung hất 60-120 của engine thì bị cắt sạch.
		MaxBounceUp = 26,
		-- Cửa sổ hậu va chạm (giây) tính từ frame cuối cùng còn thấy tường trước mặt.
		PostHitWindow = 0.35,
	},
}

-- =====================================================================
-- 2c. GRIP (chống trôi quá đà + chống VĂNG khi tông vật thể)
-- =====================================================================
-- Khi đang CHẠY TRÊN ĐẤT (Grounded), ghì vận tốc ngang không vượt WalkSpeed × factor.
-- Vận tốc THỪA (do tông tường/khối bị đẩy, do quán tính đáp obby, do momentum) bị cắt
-- ngay → nhân vật "dính đất", điều khiển chính xác, không văng tứ tung.
-- CHỈ áp khi Grounded + trạng thái Grounded (KHÔNG đụng slide / wall-run / trên không →
-- giữ nguyên spring Zone13, wind Zone12, đà nhảy obby).
ParkourConfig.Grip = {
	Enabled = true,
	-- Trần vận tốc ngang = WalkSpeed × hệ số này. 1.08 = cho phép nhỉnh 8% (đủ mượt,
	-- vẫn cắt được cú văng lớn). Muốn "dính" gắt hơn hạ về 1.0.
	MaxSpeedFactor = 1.08,
	-- Sàn tuyệt đối: luôn cho phép tới mức này dù WalkSpeed thấp (tránh ghì cứng lúc speed nhỏ).
	MinCeiling = 20,
}

-- =====================================================================
-- 3. POWER SLIDE [C] (trượt gia tốc)
-- =====================================================================
ParkourConfig.Slide = {
	-- Vận tốc trượt khởi điểm = WalkSpeed hiện tại * hệ số này (>1 = lao nhanh hơn chạy thường).
	InitialSpeedMultiplier = 1.45,

	-- Trần & sàn vận tốc trượt khởi điểm.
	MinInitialSpeed = 28,
	MaxInitialSpeed = 320,

	-- Ma sát: mỗi giây mất bao nhiêu stud/s (LỚN = trượt ngắn; NHỎ = trượt xa "như băng").
	Friction = 48,

	-- Vận tốc rớt dưới mức này → tự đứng dậy chạy tiếp.
	EndSpeed = 14,

	-- Thời gian trượt TỐI THIỂU (giây) — chống lỗi "chưa kịp thấy anim đã đứng dậy".
	MinDuration = 0.55,

	-- Giới hạn thời gian trượt tối đa (an toàn).
	MaxDuration = 1.6,

	-- Cooldown giữa 2 lần trượt (giây).
	Cooldown = 0.35,

	-- ── Thu nhỏ Hitbox để chui cổng/laser thấp ──
	-- HỆ SỐ hạ HipHeight khi trượt (nhân với HipHeight GỐC). Đừng quá thấp kẻo chân xuyên sàn.
	-- HipHeight được nâng DẦN về gốc khi slide chậm lại → đứng lên KHÔNG bị chìm xuống đất.
	HipHeightFactor = 0.5,

	-- Cho bẻ lái nhẹ trong lúc trượt (0 = không lái được).
	SteerStrength = 0.12,

	-- ── CHỐNG VĂNG NGƯỜI: blockcast dò vật cản phía trước mỗi frame ──
	-- Sắp đụng vật cản trong khoảng này (studs) → NGẮT trượt + triệt tiêu vận tốc ngay.
	CollisionLookAhead = 5.0,

	-- Kích thước khối blockcast (rộng, cao, dày) — quét bằng đúng thân người khi cúi,
	-- bắt được cả vật cản nhỏ/lệch tâm mà raycast đơn bỏ sót.
	BlockcastSize = Vector3.new(3.4, 2.6, 0.6),

	-- Gia tốc tối đa LinearVelocity được phép dùng để duy trì trượt (studs/s²).
	-- HỮU HẠN thay vì vô cực: khi kẹt vào khối vật lý, constraint không còn "ủi"
	-- xuyên vật cản với lực vô hạn → hết văng tứ tung.
	MaxSlideAccel = 900,

	-- Trần vận tốc bay LÊN (trục Y) khi đang trượt. Cấn dốc/cạnh khối làm vận tốc
	-- chuyển thành hướng lên vượt mức này → kẹp lại ngay (chống phóng lên trời).
	MaxUpwardVelocity = 12,

	-- Vận tốc ngang THỰC TẾ tụt dưới (slideSpeed × tỷ lệ này) sau grace → coi như bị
	-- vật cản chặn → ngắt trượt cứng (chống rung lắc khi bị kẹt vào khối).
	ObstructionSpeedFraction = 0.45,
	ObstructionGrace = 0.18, -- giây đầu slide bỏ qua check trên (vận tốc chưa kịp tăng)

	-- ── Particle ma sát dưới chân ──
	Particle = {
		Rate = 60,
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(4, 9),
		SizeStud = 1.4,
		Color = Color3.fromRGB(255, 235, 170),
		SpreadDeg = 28,
	},
}

-- =====================================================================
-- 4. WALL RUN (chạy trên tường — tự động)
-- =====================================================================
ParkourConfig.WallRun = {
	-- Khoảng cách raycast quét sang hông để dò tường (studs).
	DetectDistance = 3.2,

	-- Chỉ wall run khi vận tốc ngang thực tế > ngưỡng này (phải đang "có đà").
	MinSpeedToStart = 18,

	-- Vận tốc chạy dọc theo tường (stud/s).
	RunSpeed = 60,

	-- ── Bám tường bằng "gap controller" (giữ KHOẢNG CÁCH thay vì ép thẳng vào tường) ──
	WallGap = 1.8,
	StickStiffness = 9, -- độ "cứng" kéo về đúng WallGap (1/giây)
	MaxStickSpeed = 14, -- trần vận tốc bám (chống rung)

	-- ── Trọng lực (khử bằng VectorForce dạng PD: feed-forward + hãm vận tốc) ──
	GravityCancel = 1.0, -- % trọng lực được triệt tiêu (1.0 = lơ lửng hoàn toàn)
	VerticalDamp = 12, -- hãm vận tốc đứng về mục tiêu (chống GIẬT trục Y lúc vào tường)
	SlideDownAccel = 16, -- tốc độ "tụt dần" mục tiêu, tăng theo thời gian

	-- Thời gian wall run (CHẠY) tối đa trước khi tự rớt (giây) — chỉ tính lúc DI CHUYỂN.
	MaxDuration = 1.5,

	-- Thời gian ĐỨNG/BÁM tường (cling) tối đa khi không di chuyển (giây).
	ClingMaxDuration = 2.5,

	-- Sau khi rời 1 tường, chờ bao lâu mới bám LẠI cùng phía (giây) — phục vụ wall-bounce.
	SameSideCooldown = 0.25,

	-- Góc nghiêng người (lean) áp vào tường (deg) — anim đã có lean sẵn nên để thấp.
	LeanDeg = 8,

	-- Độ "nhạy" xoay người (AlignOrientation responsiveness).
	OrientResponsiveness = 35,

	-- ── Wall Jump (nhấn Space lúc đang wall run) ──
	JumpOutSpeed = 55, -- bật RA khỏi tường (theo pháp tuyến)
	JumpUpSpeed = 48, -- bật LÊN
	JumpForwardSpeed = 38, -- bật TỚI TRƯỚC (giữ đà)
}

-- =====================================================================
-- 5. STATE MACHINE — tên các trạng thái parkour
-- =====================================================================
ParkourConfig.States = {
	Grounded = "Grounded", -- bình thường / sprint
	Sliding = "Sliding",
	WallRunning = "WallRunning",
}

return ParkourConfig
