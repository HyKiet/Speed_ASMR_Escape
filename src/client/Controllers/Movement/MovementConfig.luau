--!strict
--[[
	MovementConfig.luau — BẢNG TINH CHỈNH CẢM GIÁC DI CHUYỂN

	>>> ĐÂY LÀ FILE DUY NHẤT CẦN SỬA ĐỂ CHỈNH "CẢM GIÁC TAY" <<<

	Đơn vị: vận tốc = studs/s · gia tốc = studs/s² · thời gian = giây · khoảng cách = studs.

	Hệ này thay cho thư mục Parkour/ cũ. Xem đầu MovementController.luau để biết vì sao
	phải viết lại thay vì vá tiếp.
]]

local MovementConfig = {}

-- =====================================================================
-- 0. PHÍM BẤM
-- =====================================================================
MovementConfig.Keys = {
	Slide = Enum.KeyCode.C,
}

MovementConfig.GamepadKeys = {
	Slide = Enum.KeyCode.ButtonL3,
}

-- =====================================================================
-- 1. ANIMATION
-- =====================================================================
MovementConfig.Animations = {
	Slide = "rbxassetid://115997630662112",
}

MovementConfig.AnimFade = {
	Slide = 0.15,
	Default = 0.15,
}

-- =====================================================================
-- 2. TRẠNG THÁI
-- =====================================================================
MovementConfig.States = {
	Grounded = "Grounded",
	Sliding = "Sliding",
}

-- =====================================================================
-- 3. PHANH (thả phím thì dừng gọn thay vì trôi băng)
-- =====================================================================
-- Không dùng constraint: khi MoveDirection = 0 thì Humanoid KHÔNG chủ động ghi vận tốc,
-- nên hãm thẳng vào AssemblyLinearVelocity sau bước physics là đủ và rẻ hơn hẳn.
MovementConfig.Brake = {
	Enabled = true,
	-- Gia tốc hãm nền (studs/s²) — quyết định độ "khựng" ở tốc độ thấp.
	Accel = 550,

	--[[
		QUÃNG DỪNG MỤC TIÊU (studs). Gia tốc hãm thực = max(Accel, v²/(2·D)) nên ở tốc
		độ cao quãng dừng bị ghim quanh D thay vì phình theo v².

		Bản cũ dùng `AccelPerSpeed = 3.0` (accel tỉ lệ BẬC NHẤT với v) và ghi trong
		comment là "quãng trượt gần như không đổi" — sai: đo ra 13 studs @120 nhưng 42
		studs @250, gấp 3.2 lần. Muốn quãng dừng thật sự ổn định thì gia tốc phải tỉ lệ
		với v², vì quãng dừng = v²/(2·a).

		20 studs ≈ hơn hai ô sàn phím: đủ để cảm thấy có trọng lượng, đủ ngắn để canh
		điểm đáp obby ở 250 WS.
	]]
	TargetStopDistance = 20,
	-- Dưới ngưỡng này thì triệt tiêu hẳn về 0 (khỏi rê những stud cuối).
	StopThreshold = 3.0,
	-- Trên ngưỡng này mới bắt đầu hãm (đi bộ chậm để humanoid tự xử).
	MinSpeed = 6.0,
}

-- =====================================================================
-- 4. BÁM ĐƯỜNG (trần tốc độ khi chạy trên đất)
-- =====================================================================
-- Vận tốc NGANG thừa (do va đập, do đáp obby, do bị vật thể đẩy) bị cắt ngay khi
-- chạm đất → nhân vật "dính đất", không trôi quá đà.
MovementConfig.Grip = {
	Enabled = true,
	MaxSpeedFactor = 1.08,
	MinCeiling = 20,
}

-- =====================================================================
-- 5. BẺ LÁI (dễ điều khiển ở tốc độ cao)
-- =====================================================================
-- Ở 250 studs/s, quán tính kéo cú cua thành vòng rộng. Xoay vector vận tốc về hướng
-- phím đang bấm (GIỮ NGUYÊN độ lớn, không mất đà) → cua gắt, đi đúng nét.
MovementConfig.Steering = {
	Enabled = true,
	-- Tốc độ xoay (1/s, exponential smoothing). Cao = arcade hơn, thấp = nặng quán tính hơn.
	GroundRate = 9,
	-- Trên không cho lái nhẹ hơn để vẫn còn cảm giác vật lý khi nhảy obby.
	AirRate = 2.5,
	-- Dưới ngưỡng tốc độ này thì humanoid tự xoay tốt rồi, không cần can thiệp.
	MinSpeed = 30,
}

-- =====================================================================
-- 6. CHỐNG VĂNG
-- =====================================================================
--[[
	NGUYÊN TẮC: KHÔNG BAO GIỜ can thiệp TRƯỚC va chạm.

	Bản trước quét khối theo hướng vận tốc rồi cắt đà khi thấy tường phía trước. Đúng về
	mặt vật lý nhưng SAI về cảm giác chơi: chạy gần vật thể là bị ghì chậm, trong khi
	game này sống bằng tốc độ. Đã gỡ bỏ hoàn toàn.

	Nay chỉ còn xử lý HẬU va chạm, và chỉ để cú văng NHẸ đi chứ không triệt tiêu:

	  1. Kẹp vận tốc góc — luôn bật, rẻ. Đây chính là thứ gây cảm giác "văng tứ tung":
	     va đập bơm angular velocity khổng lồ làm nhân vật xoay tít rồi bay loạn quỹ đạo.
	     Cắt xoáy là hết loạn, mà không đụng gì tới tốc độ chạy.

	  2. Giảm nhẹ cú văng — phát hiện xung va chạm (vận tốc đổi đột ngột trong MỘT bước
	     physics), xác nhận đúng là đụng tường đứng bằng MỘT tia bắn NGẮN tại đúng thời
	     điểm đó, rồi hạ cú bật xuống mức "văng nhẹ". Vì tia chỉ bắn khi đã va chạm nên
	     không có chuyện player bị ghì lúc đang tới gần vật thể.
]]
MovementConfig.AntiFling = {
	Enabled = true,

	-- Trần vận tốc góc (rad/s). Xoay bình thường của humanoid < 10.
	MaxAngularSpeed = 18,

	--[[
		Ngưỡng nhận biết XUNG va chạm: vận tốc đổi bấy nhiêu studs/s trong một bước
		physics. Tăng tốc thường của humanoid và trọng lực chỉ đổi vài studs/s mỗi bước,
		nên 60 là mốc chỉ cú đâm mới đạt được.
	]]
	ImpactDeltaSpeed = 60,
	-- Chỉ xét khi trước đó đang thực sự có đà (đi bộ đụng tường thì không văng nổi).
	ImpactMinSpeed = 60,
	-- Tia xác nhận bắn theo hướng đang lao, ngắn thôi vì đã chạm rồi.
	ImpactProbeDistance = 8,

	-- ── MỨC "VĂNG NHẸ" sau khi xác nhận đụng tường ──
	-- Trần vận tốc bật LÊN. 18 đủ để thấy nảy một cái, không đủ để bay lên trời
	-- (xung của engine khi giải xuyên thấu thường 60–120).
	BounceMaxUp = 18,
	-- Trần vận tốc NGANG ngay sau cú đâm (gồm cả bật ngược).
	BounceMaxSpeed = 60,

	-- |normal.Y| dưới mức này thì coi là TƯỜNG ĐỨNG (dốc thoải vẫn chạy lên bình thường).
	VerticalWallDot = 0.4,

	--[[
		Các stage CỐ Ý văng người — miễn trừ hoàn toàn, không đụng vào.

		Lò xo Zone 13, gió Zone 12, quạt Zone 14 đều bơm vận tốc lớn có chủ đích; nếu hạ
		xuống mức "văng nhẹ" thì hỏng cơ chế zone. Danh sách này khớp với
		AntiCheatConfig.STAGE_EXTRA_ALLOWANCE — hai chỗ cùng nói về một sự thật: đây là
		những zone mà vận tốc bất thường là HỢP LỆ.
	]]
	LauncherStages = { [12] = true, [13] = true, [14] = true } :: { [number]: boolean },

	--[[
		3. BẬT CÓC KHI ĐANG BÁM ĐẤT (2026-08-08).

		Triệu chứng: chạy 100–250 WS trên đường bằng, cán phải một mép sàn / vạch Stage /
		khe giữa hai part là bị bắn thẳng lên trời rồi rơi vào zone chết. Engine giải va
		chạm với cạnh khối bằng cách đẩy nhân vật RA — ở tốc độ này thành phần đẩy LÊN có
		thể tới hơn 100 studs/s chỉ trong một bước physics.

		`dampImpact` phía trên KHÔNG bắt được ca này: nó đòi tia xác nhận trúng TƯỜNG ĐỨNG,
		mà mép sàn/khe hở thì tia bắn ngang không trúng gì cả.

		Kẹp theo ĐỘ ĐỔI ĐỘT NGỘT chứ không theo vận tốc tuyệt đối — đây là điểm mấu chốt để
		không phá dốc: chạy 250 WS lên dốc 30° thì vy ≈ 125 studs/s nhưng nó lên TỪ TỪ qua
		nhiều frame, còn cú cấn mép thì nhảy vọt trong đúng một bước.

		Miễn trừ: đang trong LauncherStages, hoặc vừa nhảy trong vòng `JumpGrace` giây.
	]]
	-- vy tăng bấy nhiêu studs/s trong MỘT bước physics thì coi là cú bật cóc.
	GroundPopDeltaUp = 45,
	-- Kẹp vy về mức này. Vẫn dương (nhân vật nhấc nhẹ qua mép, không khựng lại).
	GroundPopMaxUp = 16,
	-- Sau khi bấm nhảy, bao lâu thì mới kẹp trở lại.
	JumpGrace = 0.35,
}

-- =====================================================================
-- 6b. CHỐNG NGÃ (topple / ragdoll)
-- =====================================================================
--[[
	Ở 100–250 WS, thứ người chơi kêu nhiều nhất KHÔNG phải bay lên trời mà là "tự nhiên
	nằm sõng soài rồi bò dậy mất 2 giây". Đó là máy trạng thái của Humanoid: va chạm mạnh
	hoặc mô-men xoắn lớn đẩy nó sang `FallingDown`/`Ragdoll`, rồi phải đi qua `GettingUp`
	mới chạy tiếp được — trong một game đua tốc độ thì đó là mất lượt.

	Cách chữa RẺ VÀ TRIỆT ĐỂ NHẤT: tắt hẳn mấy trạng thái đó bằng `SetStateEnabled`.
	Humanoid không còn đường nào để "nằm xuống" nữa nên nó luôn đứng thẳng chạy tiếp.

	KHÔNG ảnh hưởng trải nghiệm:
	  • Chết vẫn chết bình thường — `Dead` không nằm trong danh sách, kill block/zone trap
	    giết bằng Health chứ không bằng trạng thái ngã.
	  • Nhảy, rơi, leo, bơi, slide đều không đụng tới ba trạng thái này.
	  • `PlatformStanding` không có chỗ nào trong game dùng (đã rà toàn repo) — tắt để
	    không ai vô tình đóng băng điều khiển của người chơi.

	`Massless` cho accessory: mũ/cánh/ba lô là khối lượng nằm CAO trên trục, chính là cánh
	tay đòn làm nhân vật lật. Bỏ khối lượng của chúng thì hình dáng avatar giữ nguyên mà
	quán tính xoay giảm hẳn. Chỉ chạm vào nhân vật CỦA MÌNH và chỉ ở client (client là chủ
	sở hữu vật lý của chính nó nên đây là nguồn sự thật).
]]
MovementConfig.AntiTopple = {
	Enabled = true,
	DisabledStates = {
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.PlatformStanding,
	},
	MasslessAccessories = true,
}

-- =====================================================================
-- 7. SLIDE [C]
-- =====================================================================
MovementConfig.Slide = {
	InitialSpeedMultiplier = 1.45,
	MinInitialSpeed = 28,
	MaxInitialSpeed = 320,

	-- Ma sát: mỗi giây mất bấy nhiêu studs/s.
	Friction = 48,
	-- Tụt dưới mức này thì đứng dậy chạy tiếp.
	EndSpeed = 14,

	MinDuration = 0.55,
	MaxDuration = 1.6,
	Cooldown = 0.35,

	-- Hạ hồ sơ va chạm còn một nửa khi trượt (R15 chuẩn: 2.0 → 1.0).
	-- ⚠️ 2026-08-21: `Zone5SlideController` KHÔNG còn suy ra "đang slide" từ HipHeight nữa
	-- (ngưỡng tuyệt đối 1.6 giết chết mọi avatar Rthro cao — xem khối lý do trong file đó).
	-- Nó đọc `MovementSlide.SLIDING_ATTRIBUTE`, nên số này giờ thuần tuý là chuyện hình học
	-- vật lý: đổi nó chỉ ảnh hưởng chui khe THẬT, không ảnh hưởng cổng nào.
	HipHeightFactor = 0.5,

	-- Cho bẻ lái nhẹ trong lúc trượt.
	SteerStrength = 0.12,

	-- ── DỪNG KHI ẤN LÙI ──
	-- Hướng phím ngược hướng trượt quá mức này (tích vô hướng) → dừng trượt NGAY.
	-- -0.45 ≈ bấm lệch hơn 117° so với hướng đang trượt, tức rõ ràng là muốn phanh lại.
	BackwardStopDot = -0.45,
	-- Bỏ qua vài phần giây đầu để cú bấm còn sót của lần trước không cắt slide vừa mở.
	BackwardStopGrace = 0.12,

	-- Gia tốc tối đa constraint được phép dùng. HỮU HẠN để khi cấn vật cản nó không
	-- ủi xuyên với lực vô hạn — đó chính là nguồn văng của bản cũ.
	MaxAccel = 900,

	-- Trần vận tốc bay LÊN khi đang trượt (cấn dốc/cạnh khối hay biến đà thành phóng lên trời).
	MaxUpwardVelocity = 12,

	-- Vận tốc thực tụt sâu dưới vận tốc lệnh (sau grace) = đang bị nghẽn → dừng cứng.
	ObstructionSpeedFraction = 0.45,
	ObstructionGrace = 0.18,

	Particle = {
		Rate = 60,
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(4, 9),
		SizeStud = 1.4,
		Color = Color3.fromRGB(255, 235, 170),
		SpreadDeg = 28,
	},
}

return MovementConfig
