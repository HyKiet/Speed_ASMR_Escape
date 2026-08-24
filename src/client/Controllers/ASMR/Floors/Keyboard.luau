--!strict
-- Keyboard — sàn phím ThockyKey: lún lò xo sâu, sao bùng nổ khi dậm (qua ParticlePool).
-- RGB GLOW ĐÃ XOÁ theo yêu cầu user 2026-07-24 (phím không đổi màu nữa).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundIds = require(ReplicatedStorage.Shared.Config.SoundIds)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Keyboard = {}

-- ÂM PHÍM CƠ v3 (2026-08-05) — PHỐI 3 LỚP thay vì phát 1 mẫu duy nhất.
-- Một cú gõ switch cơ ngoài đời gồm 3 sự kiện tách bạch, tai nghe ra ngay cả khi
-- không phân tích được: (1) thân "thock" trầm của keycap chạm đáy, (2) cái "tick"
-- sắc của lá đồng bật ngay đầu hành trình, (3) tiếng nhả khi lò xo đẩy keycap lên.
-- Bản cũ chỉ có (1) ⇒ nghe như gõ nhựa. Chồng đủ 3 lớp mới ra chất ASMR.
--
-- Nguồn lớp TICK/UP: ProSoundEffects (thư viện thương mại Roblox phát hành sẵn,
-- không phải upload cá nhân ⇒ không sợ bị gỡ). Đã đo 2026-08-05: 25/25 ID load OK.
--
-- ⚠️ 2026-08-07: đợt hoàn nguyên "hệ âm cũ" cho sàn ASMR (Clay Zone 2, SlimeJelly Zone 4 —
-- xem ghi chú trong hai file đó) KHÔNG áp dụng cho sàn phím. User nghe thử cả hai rồi chốt
-- RIÊNG sàn phím giữ bản v3 này. Đừng gộp sàn phím vào lần hoàn nguyên nào nữa.
--
-- CẢ 3 LỚP ĐỀU CỐ ĐỊNH cho mọi phím — xem khối hằng số ngay dưới.

-- MỌI ThockyKey PHÁT ĐÚNG MỘT TIẾNG NHƯ NHAU (chốt 2026-08-05 theo yêu cầu user).
-- Trước đây mỗi lần dẫm lại bốc ngẫu nhiên 1 trong 8 mẫu + rung cao độ, và có giai đoạn
-- còn gán nốt riêng theo vị trí phím. Bàn phím cơ thật thì mọi phím là cùng một switch
-- ⇒ cùng một tiếng. KHÔNG thêm biến thể nào vào đây nữa.
local BODY_ID = 127105730240202 -- Keyboard Click 0.277s (user chọn 2026-08-05)
-- ⚠️ TICK/RELEASE lấy từ `Config.SoundIds`, KHÔNG khai số ở đây: hai ID này dùng chung với
-- `Effects/KeyCapperSFXController` (tiếng gõ phím của HUD). Khai hai nơi thì sửa một chỗ
-- quên chỗ kia là hai âm lệch nhau mà không có lỗi nào báo.
local TICK_ID = SoundIds.KEYBOARD_TICK
local RELEASE_ID = SoundIds.KEYBOARD_RELEASE
-- Thay BODY_ID bằng một trong các mẫu đã đo (2026-08-05, tất cả load OK) nếu muốn đổi chất.
-- ĐỌC `Keyboard.voices` bên dưới trước khi đổi: mẫu càng DÀI càng cần nhiều giọng.
--   102855535543930 Creamy Keyboard 0.18s  113108830240353 Cream keyboard 0.21s
--   72826565018765  Keyboard Clicked 0.15s 125615721658437 keyboard b 0.20s
--   125027148509088 Keyboard g 0.21s       88838553648526  Keyboard h 0.19s
--   125236580407249 Keyboard j 0.23s       132465969238702 Keyboard button 0.21s

-- ===== CHẠY CÀNG NHANH NGHE CÀNG ĐÃ TAI (2026-08-05) =====
--
-- VẤN ĐỀ ĐO ĐƯỢC: mô phỏng `touchKeysAt` trên bàn thật cho ra nhịp gõ theo tốc độ —
--   WS  50 →  21 nhịp/giây      WS 150 →  65        WS 250 → 105
-- Tai người ngừng nghe ra SỰ KIỆN RỜI RẠC ở khoảng 30 nhịp/giây; trên mức đó các cú gõ
-- hoà vào nhau thành một tiếng rè có cao độ. Ở 250 WS ta đang bắn 105 nhịp/giây, gấp 3
-- lần ngưỡng ⇒ càng nhanh càng NHIỀU tiếng nhưng nghe càng ra tiếng ồn, không phải tiếng
-- gõ. Đây là lý do "walkspeed cao chạy trên sàn nghe không ASMR lắm".
--
-- CÁCH CHỮA: đổi hướng — chạy nhanh thì gõ ÍT hơn nhưng mỗi tiếng NẶNG hơn.
--   1) Chặn nhịp ở CLICK_RATE_* (tăng dần theo tốc độ). Ở tốc độ thấp nhịp tự nhiên đã
--      dưới ngưỡng nên không lọc gì cả — cảm giác "từng phím một" giữ nguyên.
--   2) Lấy chỗ trống đó bù vào chất tiếng: càng nhanh thì thân càng TRẦM và càng TO,
--      còn tick/nhả càng nhỏ lại (dày đặc tiếng treble là thứ gây chói và mệt tai).
-- Kết quả: 250 WS nghe thành một tràng thock trầm, nặng, có nhịp — thay vì tiếng rè.
--
-- KHÔNG nút nào ở đây phá tính đồng bộ: mọi phím vẫn dùng chung một mẫu và cùng một
-- công thức. Cái thay đổi là TỐC ĐỘ CỦA NGƯỜI CHƠI, không phải phím nào được gõ.

-- Nhịp gõ tối đa (tiếng/giây), TĂNG THEO TỐC ĐỘ.
--
-- CÁCH LÀM: token bucket, KHÔNG phải cổng "cách lần trước ≥ X giây".
-- Đã thử cổng thời gian trước và đo ra hỏng: nó bị lượng tử hoá theo khung hình (ở 60fps
-- chỉ ra được 60/n nhịp/giây) nên kết quả nhảy loạn và NGƯỢC — 250 WS ra 15.5 nhịp/giây
-- trong khi 180 WS được 21.5. Chạy nhanh hơn mà nghe thưa hơn là hỏng đúng thứ cần sửa.
-- Bucket cộng tín dụng theo THỜI GIAN THẬT nên nhịp trung bình đúng bằng ngưỡng, không
-- phụ thuộc fps hay việc mấy phím rơi chung một frame.
--
-- Trần tín dụng CLICK_BURST = 3, chọn bằng ĐO chứ không đoán. Trần thấp thì frame nào
-- chạm nhiều phím cùng lúc sẽ tiêu hết tín dụng rồi bỏ đói mấy frame kế, và nhịp thật
-- tụt xuống dưới ngưỡng rất xa. Đo bằng vòng Heartbeat, 4 giây mỗi mức (nhịp/giây):
--
--   WS   thô   BURST=1   BURST=2   BURST=3
--   50    26      9.8      18.7      19.8
--   100   49     18.9      23.0      24.1
--   150   67     15.4      25.9      26.2
--   200   85     19.3      27.9      28.1
--   250   78     15.1      22.3      26.4
--
-- BURST=3 là cấu hình duy nhất bám sát đường ngưỡng 20 → 30 và tăng đều theo tốc độ.
-- (Cột "thô" ở 250 thấp hơn 200 là do fps của chính máy đo tụt, không phải thuật toán.)
--
-- Ở tốc độ thấp nhịp tự nhiên đã gần ngưỡng nên bucket gần như không lọc gì —
-- cảm giác "từng phím một" giữ nguyên.
-- Đặt cả hai rất cao (999) là tắt hẳn cơ chế lọc.
local CLICK_RATE_SLOW, CLICK_RATE_FAST = 20, 30
local CLICK_BURST = 3

-- Chất tiếng nội suy theo `speedRatio` (0 = đứng yên, 1 = 250 WS, cap cứng của game).
-- Thân TRẦM dần: bàn phím được khen "thocky/creamy" là bàn có trọng âm thấp, đục.
local BODY_PITCH_SLOW, BODY_PITCH_FAST = 0.96, 0.86
-- Thân TO dần. Vượt 1.0 là hợp lệ (Sound.Volume tới 10) — chạy hết tốc phải nghe đầm.
local BODY_VOL_SLOW, BODY_VOL_FAST = 0.5, 1.15
-- Tick NHỎ dần: ở tốc độ thấp nó là cái đầu sắc làm tiếng gõ rõ; ở tốc độ cao hàng chục
-- transient treble/giây chồng lên nhau chỉ còn là tiếng xì chói.
local TICK_VOL_SLOW, TICK_VOL_FAST = 0.38, 0.18
local TICK_PITCH = 1.44
-- Nhả cũng nhỏ dần: chạy nhanh thì cú nhả của phím này đè lên cú nhấn của phím kế và
-- chỉ làm đục thêm. Ở tốc độ thấp thì đây mới là chi tiết đặc sản của ASMR bàn phím.
local RELEASE_VOL_SLOW, RELEASE_VOL_FAST = 0.3, 0.14
local RELEASE_PITCH = 1.78

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
-- Rung cao độ mỗi lần gõ. ĐỂ 0 = đồng bộ tuyệt đối, mọi phím y hệt nhau — đây là thứ
-- user muốn. Nâng lên 0.02–0.03 nếu nghe thấy máy móc quá, nhưng cao hơn nữa là quay
-- lại đúng cái bug "mỗi phím một tiếng".
local PITCH_JITTER = 0.0
-- Nhả phím rẻ hơn nhấn (không hạt, không lò xo) nhưng chạy nhanh vẫn nhả hàng chục
-- phím/frame; giữ trần riêng để lớp này luôn là lớp mỏng phía sau, không thành ồn.
local MAX_RELEASE_PER_FRAME = 3

Keyboard.soundIds = { BODY_ID, TICK_ID, RELEASE_ID }

-- SỐ GIỌNG (bug "chạy nhanh gần như không nghe thấy tiếng", đo 2026-08-05).
-- Mặc định SoundPool là 4 giọng/id. Hồi còn bốc ngẫu nhiên 8 mẫu thì lớp thân có thật
-- 8 × 4 = 32 giọng nên không sao; rút về MỘT mẫu là tụt còn 4. Đo trên bàn thật:
--   WS 100 → 43 lượt nhấn/s ⇒ 4 giọng bị cướp lại mỗi 93ms, mẫu chỉ kêu được nửa đầu
--   WS 250 → 105 lượt/s     ⇒ cướp lại mỗi 38ms — mất hẳn thân thock
--
-- CÔNG THỨC: số giọng cần = nhịp-gõ/giây × độ-dài-mẫu-KHI-PHÁT.
-- Nhịp gõ giờ bị chặn ở CLICK_RATE_FAST (30) chứ không còn là 76-105 của 250 WS nữa.
-- Thân: 0.277s ở cao độ thấp nhất 0.86 ⇒ kêu 0.322s ⇒ 30 × 0.322 = 10. Để 24 lấy biên.
-- ĐỔI BODY_ID sang mẫu dài hơn, hạ BODY_PITCH_FAST, hay nâng CLICK_RATE_FAST
-- đều phải tính lại con số này.
--
-- Đây KHÔNG phải thêm biến thể: mọi giọng trong một bank đều giữ cùng một SoundId.
Keyboard.voices = {
	[BODY_ID] = 24, -- lớp chính, phải nguyên vẹn (0.322s ở cao độ thấp nhất)
	[TICK_ID] = 12, -- chỉ là đầu transient, lại nhỏ dần khi chạy nhanh
	[RELEASE_ID] = 8, -- đã bị chặn 3/frame, lại là lớp nhỏ nhất
}

-- Bên tai luân phiên như bản gốc (binaural bước chân). Giữ ở SCOPE MODULE để chuỗi
-- trái-phải liền mạch khi bước từ bàn này sang bàn kế. 3 lớp của CÙNG một cú gõ phải
-- dùng CHUNG một pan — gọi playStep 3 lần sẽ ném thân sang trái, tick sang phải và xé
-- đôi tiếng gõ, nên ở đây tự quản pan rồi gọi playPanned.
local earSide = false

-- Bucket cũng ở SCOPE MODULE: Zone 15 lát 56 bàn liền nhau, bucket riêng từng bàn thì
-- lúc bước qua ranh giới hai bàn cùng nhả một tiếng và nhịp vọt gấp đôi đúng chỗ người
-- chơi đang chạy nhanh nhất.
local clickCredit = CLICK_BURST
local lastCreditAt = os.clock()

-- VIBE (2026-07-28) — Zone 15 chia 3 đoạn Fire / Water / Lightning bằng attribute `Vibe`
-- trên MODEL bàn (do `tools/zone15_vibes.luau` gán). Bàn không có attribute (các zone khác)
-- giữ nguyên hiệu ứng sao cầu vồng cũ, nên thay đổi này không đụng tới zone nào khác.
local VIBE_FX = {
	Fire = "fire",
	Water = "water",
	Lightning = "lightning",
}
local DEFAULT_FX = "stars"

local CELL = 3
local KEY_REACH = 1.9
local FOOT_DROP = 3.05
local Y_TOLERANCE = 2.8
-- Độ lún DỰ PHÒNG, chỉ dùng khi không dò ra mặt đất (lobby, sàn bắc qua vực).
-- Trong 15 zone, độ lún thật do `GroundLimit` quyết định lúc attach — xem khối tính
-- `pressDepth` bên dưới. Đây từng là hằng số duy nhất, hợp lý khi người chơi còn đứng
-- trên WalkSurface (lưng chừng thân phím, chỉ còn 0.97 stud phím nhô trên mũi chân).
local PRESS_DEPTH = 0.9
local PULSE = 0.14
local SAMPLE_STEP = 1.4
local MAX_SAMPLES = 40
local MAX_SOUNDS_PER_FRAME = 8
--[[
	LÒ XO PHÍM — VÌ SAO PHẢI TÍCH PHÂN GIẢM CHẤN KIỂU ẨN (bug "phím nảy liên tục", video
	test.mp4 quay trên Redmi A2+, 2026-08-21).

	Vòng tích phân ở cuối file kẹp `step = min(dt, 1/30)`. Trên máy khoẻ (60fps) step =
	0,0167 nên không sao, nhưng máy yếu tụt xuống ≤ 30fps là step chạm trần 0,0333 — và ở
	đúng đó, sơ đồ Euler nửa-ẩn cũ VỠ:

	    v += (k·(target − x) − d·v)·h        với k = 1400, d = 42, h = 1/30
	    ⇒ hệ số nhân của v là (1 − d·h) = 1 − 1,4 = −0,4   (đổi dấu mỗi bước!)
	    ⇒ trị riêng của ma trận (x, v): λ = 0,31 và λ = −1,27

	|λ| = 1,27 > 1 nghĩa là biên độ NHÂN LÊN 1,27 lần mỗi frame — phân kỳ, không phải dao
	động tắt dần. Hai hậu quả, và cả hai đều thấy trong video:

	  1. NHÌN: `rec.depth` phóng to vô hạn, chỉ có biến `depth` dùng để ghi CFrame mới bị
	     `math.clamp(-0.12, 1.08)` — nên phím nhảy giữa hai đầu kẹp mỗi frame, đúng cái
	     "nảy liên tục" user thấy.
	  2. LAG (nặng hơn): điều kiện nhả `|depth| < 0.004` KHÔNG BAO GIỜ đúng nữa, phím không
	     bao giờ rời `activeKeys`. Mỗi phím người chơi từng dẫm qua sẽ ghi CFrame mãi mãi,
	     mỗi frame, tới hết phiên. Chạy hết Zone 1 + Zone 15 là hàng nghìn phím kẹt như vậy
	     ⇒ máy yếu vào vòng xoáy tử thần: fps thấp → lò xo vỡ → thêm phím kẹt → fps thấp hơn.
	     Đây chính là phần "Redmi lag khá nhiều" mà máy khoẻ không dính vì không bao giờ
	     chạm trần step.

	CÁCH SỬA: giải phần giảm chấn theo kiểu ẨN — chia cho (1 + d·h) thay vì nhân (1 − d·h).
	Hệ số này luôn nằm trong (0, 1) với mọi h > 0 nên không đời nào đổi dấu.

	ĐO LẠI (mô phỏng 200 frame, giữ phím lún — đỉnh lún, 1.0 = chạm đáy):
	                      60fps            30fps
	    explicit (cũ)     1,043            3,4 × 10²⁰   ← phân kỳ
	    implicit (mới)    1,184            1,259
	    exp(−d·h)         1,204            1,556
	Chọn `implicit` vì nó vọt lố ÍT NHẤT trong hai bản ổn định. Phần vọt lố thêm so với bản
	cũ (1,043 → 1,184) không nhìn thấy được: dòng ghi CFrame vốn đã kẹp `depth` ở 1,08, tức
	chênh 0,03 stud so với trước.

	Chi phí: 0 — vẫn một phép chia thay cho một phép nhân, không thêm vòng lặp con.
]]
local PRESS_K, PRESS_D = 1400, 42
-- RELEASE_D 13→30 (ratio 0.36→0.83): phím nhả 1 nhịp nảy mềm thay vì rung 3-4 nhịp
-- ("nhấp nhấp nảy nảy" khi đứng/lướt trên phím — bug report 2026-07-19)
local RELEASE_K, RELEASE_D = 330, 30
-- hysteresis: phím ĐANG lún được giữ pulse với vùng chạm rộng hơn — chân nhích nhẹ
-- quanh mép không gây chu kỳ nhả/nhấn lại
local HOLD_SLACK_XZ = 0.55
local HOLD_SLACK_Y = 0.8

function Keyboard.attach(model, engine)
	local FxBudget, SoundPool, ParticlePool = engine.FxBudget, engine.SoundPool, engine.ParticlePool
	local self = { ready = false }

	local keys, grid, region
	local activeKeys = {} -- set phím đang animate lò xo
	-- Chốt lại lúc attach theo mặt đất thật dưới bàn — xem khối tính ở cuối task.spawn.
	local pressDepth = PRESS_DEPTH

	-- đọc 1 lần lúc attach: vibe không đổi trong đời một bàn
	local fx = VIBE_FX[tostring(model:GetAttribute("Vibe"))] or DEFAULT_FX
	-- VFX vibe là flipbook to (size 2, life 0.5–1s) nên 1 hạt/phím là đủ dày; sao cầu vồng
	-- bé hơn nên vẫn giữ 2 như cũ.
	local fxCount = if fx == DEFAULT_FX then 2 else 1

	task.spawn(function()
		local wrap = model:WaitForChild("Clicky Keyboard Asmr", 10)
		local themes = wrap and wrap:WaitForChild("Themes", 10)
		if not themes then
			warn("[ASMR Keyboard] không tìm thấy Themes:", model:GetFullName())
			return
		end
		-- đợi phím replicate ổn định (đếm MeshPart tới khi không đổi)
		local last = -1
		local deadline = os.clock() + 25
		while os.clock() < deadline do
			local n = 0
			for _, theme in themes:GetChildren() do
				for _, k in theme:GetChildren() do
					if k:IsA("MeshPart") then
						n += 1
					end
				end
			end
			if n > 0 and n == last then
				break
			end
			last = n
			task.wait(0.35)
		end

		keys = {}
		grid = engine.SpatialGrid.new(CELL)
		for _, theme in themes:GetChildren() do
			for _, k in theme:GetChildren() do
				if k:IsA("MeshPart") then
					local rec = {
						part = k,
						rest = k.CFrame,
						x = k.Position.X,
						z = k.Position.Z,
						-- vùng chạm theo KÍCH THƯỚC phím (phím 3→1.9 như cũ, phím 5→3.15)
						reach = math.max(KEY_REACH, k.Size.X * 0.63),
						topY = k.Position.Y + k.Size.Y / 2,
						depth = 0,
						vel = 0,
						pulseUntil = 0,
						down = false,
					}
					table.insert(keys, rec)
					grid:insert(rec.x, rec.z, rec)
				end
			end
		end
		local x0, x1, z0, z1 = 1e9, -1e9, 1e9, -1e9
		for _, rec in keys do
			x0 = math.min(x0, rec.x)
			x1 = math.max(x1, rec.x)
			z0 = math.min(z0, rec.z)
			z1 = math.max(z1, rec.z)
		end
		region = { x0 = x0 - 10, x1 = x1 + 10, z0 = z0 - 10, z1 = z1 + 10 }

		-- KHÔNG còn gán nốt/mẫu riêng cho từng phím: mọi phím dùng chung BODY_ID + TICK_ID
		-- ở đầu file. Vị trí phím vẫn là thứ phân biệt tiếng này với tiếng kia, nhưng bằng
		-- KHÔNG GIAN (tai nghe từ nhân vật + rolloff gần) chứ không bằng cao độ.

		-- ĐỘ LÚN THEO MẶT ĐẤT (2026-08-04). Người chơi giờ đứng trên Ground thật, không
		-- còn trên WalkSurface cắt ngang thân phím: phím cao 2.0 stud nhô trọn quanh chân.
		-- Giữ nguyên 0.9 thì phím dưới chân vẫn cao hơn mũi chân 1.07 stud ⇒ nhân vật lún
		-- vào bàn phím tới đầu gối. Lún tới sát đất (còn hở 0.15) mới ra đúng cảm giác
		-- "bàn phím rẽ ra dưới chân" mà vẫn không có phím nào biến mất xuống dưới nền.
		--
		-- Đo tại phím GIỮA bàn: một bàn nằm trọn trên một mảng nền, không cần dò từng phím
		-- (19k phím ⇒ 19k raycast lúc load). Bàn nào không dò ra nền (lobby, bàn bắc qua
		-- vực) thì GroundLimit trả nil và bàn đó giữ nguyên 0.9 như trước.
		local mid = keys[math.max(#keys // 2, 1)]
		if mid then
			local groundTop = engine.GroundLimit.topUnder(model, mid.part.Position, mid.topY - mid.part.Size.Y)
			pressDepth = engine.GroundLimit.maxSink(mid.topY, groundTop) or PRESS_DEPTH
		end

		self.ready = true
		Log.Floor("Keyboard", #keys, model)
	end)

	local function playKey(rec, speedRatio, volScale)
		if not FxBudget.fxOK(rec.part.Position, 80) then
			return
		end
		-- Hạt VẪN nổ cho mọi phím (hình ảnh không được thưa đi), chỉ TIẾNG mới bị chặn nhịp.
		ParticlePool.emit(fx, Vector3.new(rec.x, rec.topY + 0.2, rec.z), fxCount)

		-- Chất tiếng theo tốc độ: nhanh = trầm hơn, to hơn, ít treble hơn, gõ thưa hơn.
		local t = math.clamp(speedRatio, 0, 1)

		-- TOKEN BUCKET — xem khối CLICK_RATE_* ở đầu file. Phím bị chặn vẫn lún, vẫn nổ
		-- hạt, chỉ là không góp thêm một tiếng vào đám đã quá dày.
		local now = os.clock()
		clickCredit =
			math.min(clickCredit + (now - lastCreditAt) * lerp(CLICK_RATE_SLOW, CLICK_RATE_FAST, t), CLICK_BURST)
		lastCreditAt = now
		if clickCredit < 1 then
			return
		end
		clickCredit -= 1
		rec.sounded = true -- để lớp nhả biết cú nhấn này CÓ kêu

		earSide = not earSide
		local pan = if earSide then 0.85 else -0.85
		rec.pan = pan -- lớp nhả phải ra đúng bên tai đã nhấn

		local pos = rec.part.Position
		local pitch = if PITCH_JITTER > 0 then 1 + (math.random() * 2 - 1) * PITCH_JITTER else 1

		local bodyVol = lerp(BODY_VOL_SLOW, BODY_VOL_FAST, t) * volScale
		local bodyPitch = lerp(BODY_PITCH_SLOW, BODY_PITCH_FAST, t)
		rec.relVol = lerp(RELEASE_VOL_SLOW, RELEASE_VOL_FAST, t)

		-- lớp 1: thân thock — cao độ thấp dần kéo cả phổ xuống cho đục và có trọng lượng
		SoundPool.playPanned(BODY_ID, pos, bodyVol, pitch * bodyPitch, pan, 70)
		-- lớp 2: tick lá đồng — cùng vị trí, cùng tai, cùng frame ⇒ tai gộp thành MỘT
		-- tiếng gõ có đầu sắc, không nghe ra là hai mẫu.
		SoundPool.playPanned(TICK_ID, pos, bodyVol * lerp(TICK_VOL_SLOW, TICK_VOL_FAST, t), pitch * TICK_PITCH, pan, 70)
	end

	local function playRelease(rec)
		-- Cú nhấn bị cổng chặn nhịp lọc đi thì cú nhả cũng phải im. Nếu không, phím "câm"
		-- vẫn kêu lúc bật lên và ta chỉ đổi tiếng rè này lấy tiếng rè khác.
		if not rec.sounded then
			return
		end
		rec.sounded = false
		-- `nearCamera` chứ KHÔNG `fxOK`: lớp nhả là lớp phụ của một cú nhấn ĐÃ được ngân
		-- sách duyệt, không phải hiệu ứng mới. Tính nó vào ngân sách 20-sound/0.1s là ăn
		-- gấp đôi suất, và ở tốc độ cao chính lớp nhả lại đá văng lớp thân của phím kế.
		if not FxBudget.nearCamera(rec.part.Position, 80) then
			return
		end
		-- 55 < 70 của thân: tiếng nhả là chi tiết dưới chân, không cần vọng xa
		SoundPool.playPanned(
			RELEASE_ID,
			rec.part.Position,
			rec.relVol or RELEASE_VOL_SLOW,
			RELEASE_PITCH,
			rec.pan or 0,
			55
		)
	end

	local function touchKeysAt(px, py, pz, now, touched)
		local footY = py - FOOT_DROP
		local map, cell = grid.map, grid.cell
		local cx, cz = math.floor(px / cell), math.floor(pz / cell)
		for dx = -1, 1 do
			for dz = -1, 1 do
				local bucket = map[(cx + dx) .. "," .. (cz + dz)]
				if bucket then
					for _, rec in bucket do
						-- phím đang lún: nới vùng chạm (hysteresis) để không nhả/nhấn lại liên hồi
						local sxz = if rec.down then rec.reach + HOLD_SLACK_XZ else rec.reach
						local sy = if rec.down then Y_TOLERANCE + HOLD_SLACK_Y else Y_TOLERANCE
						if
							math.abs(px - rec.x) <= sxz
							and math.abs(pz - rec.z) <= sxz
							and math.abs(footY - rec.topY) <= sy
						then
							rec.pulseUntil = now + PULSE
							if not rec.down then
								touched[rec] = true
							end
						end
					end
				end
			end
		end
	end

	local lastPos = nil

	-- Bảng gom phím-vừa-chạm DÙNG LẠI giữa các frame. Zone 15 lát kín ⇒ tới 56 bàn phím
	-- cùng sống một lúc; cấp phát `{}` mỗi frame cho mỗi bàn là 56 bảng rác/frame,
	-- đủ để GC giật đúng lúc chạy nhanh nhất.
	local touched = {}

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		-- EARLY-OUT rẻ nhất có thể: chân ngoài hộp bao VÀ không phím nào đang nhún
		-- ⇒ thoát ngay, không đụng tới bảng nào. Đây là trạng thái của ~55/56 bàn mỗi frame.
		local inRegion = false
		if foot then
			local p = foot.pos
			inRegion = p.X >= region.x0 and p.X <= region.x1 and p.Z >= region.z0 and p.Z <= region.z1
		end
		if not inRegion then
			lastPos = nil
			if next(activeKeys) == nil then
				return
			end
		end

		-- 1) INPUT: gom mọi phím bị chạm frame này (swept đầy đủ)
		local ratio = 0
		if inRegion and foot then
			local pos = foot.pos
			ratio = foot.ratio
			touchKeysAt(pos.X, pos.Y, pos.Z, now, touched)
			if lastPos then
				local delta = pos - lastPos
				local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if dist > SAMPLE_STEP and dist < 150 then
					local steps = math.min(math.floor(dist / SAMPLE_STEP), MAX_SAMPLES)
					for i = 1, steps do
						local sp = lastPos:Lerp(pos, i / (steps + 1))
						touchKeysAt(sp.X, sp.Y, sp.Z, now, touched)
					end
				end
			end
			lastPos = pos
		end

		-- 2) SOUND: phát cho phím vừa nhấn, throttle + chia volume khi burst
		local burst = 0
		for _ in touched do
			burst += 1
		end
		if burst > 0 then
			local volScale = burst > MAX_SOUNDS_PER_FRAME and (MAX_SOUNDS_PER_FRAME / burst) or 1
			local played = 0
			for rec in touched do
				rec.down = true
				activeKeys[rec] = true
				if played < MAX_SOUNDS_PER_FRAME then
					played += 1
					playKey(rec, ratio, math.max(volScale, 0.45))
				end
			end
			table.clear(touched)
		end

		-- 3) SPRING ANIMATOR: tích phân lò xo cho mọi phím đang sống
		local step = math.min(dt, 1 / 30)
		local releasedThisFrame = 0
		for rec in activeKeys do
			local pressed = now < rec.pulseUntil
			if not pressed and rec.down then
				rec.down = false
			end
			local target = pressed and 1 or 0
			local k, d
			if pressed then
				k, d = PRESS_K, PRESS_D
			else
				k, d = RELEASE_K, RELEASE_D
			end
			-- phím GIỮ lún đã ổn định: khóa depth=1, không tích phân/ghi CFrame mỗi frame
			-- (đứng yên trên phím = 0 property write, hết rung vi mô)
			if pressed and rec.settled then
				continue
			end
			-- Giảm chấn ẨN (xem khối dài ở hằng số PRESS_K): chia cho (1 + d·h), KHÔNG nhân
			-- (1 − d·h) — đó là dòng làm phím nảy vĩnh viễn ở fps thấp.
			rec.vel = (rec.vel + k * (target - rec.depth) * step) / (1 + d * step)
			rec.depth += rec.vel * step
			-- LƯỚI AN TOÀN: kẹp CHÍNH `rec.depth` (bản cũ chỉ kẹp biến tạm dùng để ghi CFrame,
			-- nên trạng thái thật vẫn phóng đi được và phím không bao giờ đủ điều kiện nhả).
			-- Giới hạn rộng hơn biên nảy quá đà hợp lệ (−0.12 … 1.08) nên không cắt mất độ nảy.
			if rec.depth < -0.5 or rec.depth > 1.5 then
				rec.depth = math.clamp(rec.depth, -0.5, 1.5)
				rec.vel = 0
			end
			if pressed and math.abs(1 - rec.depth) < 0.008 and math.abs(rec.vel) < 0.06 then
				rec.depth = 1
				rec.vel = 0
				rec.settled = true
				rec.part.CFrame = rec.rest * CFrame.new(0, -pressDepth, 0)
			elseif not pressed and math.abs(rec.depth) < 0.004 and math.abs(rec.vel) < 0.05 then
				rec.depth = 0
				rec.vel = 0
				rec.settled = false
				rec.part.CFrame = rec.rest
				activeKeys[rec] = nil
				-- LỚP 3 phát ĐÚNG lúc keycap chạm lại vị trí nghỉ, không phải lúc nhấc chân:
				-- tiếng nhả khớp với hình ảnh phím bật lên thì não mới nghe ra là "lò xo",
				-- lệch vài chục ms là thành tiếng gõ thừa.
				if releasedThisFrame < MAX_RELEASE_PER_FRAME then
					releasedThisFrame += 1
					playRelease(rec)
				end
			else
				rec.settled = false
				local depth = math.clamp(rec.depth, -0.12, 1.08) -- cho phép nảy quá đà nhẹ
				rec.part.CFrame = rec.rest * CFrame.new(0, -pressDepth * depth, 0)
			end
		end
	end

	function self.destroy() end

	return self
end

return Keyboard
