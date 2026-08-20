--!strict
--[[
	Zone9 TsunamiScript — Tsunami Sprint (v6: swept collision + cổng vị trí)
	Đặt làm con của Workspace.Zones.Zone9.Mechanics.Tsunami (Script chạy trên Server).
	(Bản gốc để version-control; bản chạy nằm trong .rbxlx do map không được Rojo sync.)

	v4: deterministic clock, zero-replication. Server KHÔNG PivotTo model. Vị trí sóng =
	f(workspace:GetServerTimeNow()) → client dựng lại y hệt và render local.

	===== v6 (2026-08-07) — ĐỘ CHÍNH XÁC =====
	User: "walkspeed cao hoặc gắn aura/trail thì bẫy không giết player". Hai lỗ hổng:

	1) CỔNG STAGE BẰNG Touched — đây là lỗ CHÍNH của zone này. Bản cũ đòi
	   `ActiveStage == 9` (thậm chí không nhận CurrentStage như Zone 8), mà attribute đó chỉ
	   được gán khi Stage9Start.Touched nổ. Chạy nhanh — hoặc FPS thấp vì aura/trail, mà
	   client là network owner nên bước physics dài ra — thì bước nhảy qua hẳn tấm pad mỏng,
	   Touched KHÔNG nổ, và sóng KHÔNG BAO GIỜ giết người chơi đó. Chạy càng nhanh càng chắc
	   miễn nhiễm: đúng triệu chứng user mô tả.
	   ⇒ Thay bằng cổng VỊ TRÍ: ai đang ở trong lòng kênh đều bị sóng phán xử.
	     `immune` (đã cán đích) vẫn giữ nguyên vì đó là cờ AN TOÀN — hụt nó chỉ làm người
	     chơi bị giết chứ không làm bất tử.

	2) LẤY MẪU RỜI RẠC. Chỉ thử `|p.X − waveX| <= killHalf` tại vị trí hiện tại, mỗi frame
	   một lần. Khi người chơi chạy NGƯỢC vào sóng, tốc độ tiếp cận lên tới 230 + 250 = 480
	   studs/s = 8 studs/frame ở 60fps, và gấp đôi thế nếu server tụt 30fps — đủ để xuyên qua
	   bề dày sóng mà không frame nào thấy trùng.
	   ⇒ Quét cả đoạn player đi trong frame, đồng thời nội suy vị trí sóng tại từng mẫu.

	===== v7 (2026-08-12) — ĐOÀN 2 SÓNG, VÌ GATE THẬT CHỈ CÓ 96 WS =====
	User: "test với speed thấp hơn vẫn qua dễ dàng". Đo lại bằng mô phỏng đúng luật giết của
	chính file này (không phải bằng công thức): gate thật = **96 WS**, trong khi Bảng Chỉ Số
	Stage 9 ghi 138.

	Con số "157" ghi ở v5/v6 là SAI, và sai ở chỗ đáng ghi nhớ: nó lấy `LEN / CYCLE`, tức giả
	định người luồn đuôi sóng phải băng hết kênh trong ĐÚNG MỘT CHU KỲ. Thực tế người chơi
	được nhiều hơn thế nhiều:

	    thời gian thoát = (phần sweep còn lại)  +  RESPAWN_DELAY  +  (sóng mới bò từ home
	                       ~1.96s                    0.35s           về tới chỗ họ ~0.6s)

	Sóng sinh ở home = -137, tức **133 studs SAU LƯNG vạch xuất phát**, nên mỗi đợt mới phải
	đi 597 studs trong khi người chơi chỉ phải đi 464. Bước vào ngay sau đuôi sóng là ăn trọn
	530 studs quãng chạy đà của sóng — thừa sức đi bộ.

	Cách chữa: KHÔNG tăng WAVE_SPEED (230 là tốc độ đã hiệu chỉnh cho vừa mắt, đẩy lên 380 mới
	đạt gate mong muốn thì sóng nhanh tới mức không kịp thấy). Thay bằng **ĐOÀN 2 SÓNG** cách
	nhau nửa chu kỳ: luồn được đuôi sóng này thì sóng kế đã ở ngay sau lưng. Đo lại: gate
	**139 WS** ≈ đúng Bảng (138), y như cách Zone 7 khớp 105.7 ≈ 106.

	Bài học chung: gate của cơ chế TUẦN HOÀN không bao giờ là `LEN / CYCLE` — luôn phải trừ đi
	quãng chạy đà mà cơ chế tự cho không người chơi. Cách duy nhất đáng tin là mô phỏng lại
	đúng luật giết rồi quét dải WalkSpeed.

	===== v8 (2026-08-13) — QUAY VỀ MỘT SÓNG =====
	User bác đoàn 2 sóng: chỉ muốn MỘT sóng, tốc độ giữ nguyên 230. Toàn bộ máy móc đoàn sóng
	(WAVE_COUNT/WaveSpacing, vòng lặp nhiều sóng ở server, bản sao cục bộ ở client) ĐƯỢC GIỮ
	NGUYÊN — đổi đúng một hằng số là quay lại được, và client đọc `WaveCount` từ attribute nên
	tự khớp, không có sóng vô hình.

	Hệ quả phải biết: gate tụt từ 139 WS về **96 WS**, thấp hơn Bảng Chỉ Số Stage 9 (138) —
	tức Stage 9 giờ dễ hơn chuẩn. Đây là lựa chọn thiết kế của user, không phải hồi quy.

	===== v9 (2026-08-20) — "CHẠM SÓNG LÀ CHẾT" =====
	User: "test vượt qua zone 9 xong thì sóng thần không còn giết player nữa".

	Thủ phạm là cờ `immune` của v6 — nó LATCH VĨNH VIỄN. `Stage9Finish.Touched` bật nó lên,
	và thứ DUY NHẤT tắt được là `Stage9Start.Touched`, một tấm pad dày đúng 4 studs. Ai quay
	lại lòng kênh bằng checkpoint-respawn, teleport, hay chỉ chạy vòng lại đều KHÔNG chạm lại
	pad đó ⇒ bất tử với sóng cho tới hết phiên. Đúng triệu chứng user mô tả, và trớ trêu là nó
	tái lập đúng cái bệnh "cổng bằng Touched" mà v6 vừa chữa xong ở lỗ (1).

	Cờ đó còn THỪA: sóng biến mất đúng tại `finishX`, nên mọi chỗ sau vạch đích tự nó đã an
	toàn về HÌNH HỌC — không cần trạng thái nào ghi nhớ cả.
	⇒ Bỏ hẳn `immune` + hai handler Touched. Luật giết giờ gói trong MỘT câu, không trạng
	  thái, không lịch sử: **khối sóng có phủ lên thân nhân vật ở thời điểm này không.**

	Kèm hai chỗ chính xác hơn và một chỗ rẻ hơn:
	  • CỘNG NỬA BỀ DÀY THÂN. Root nằm giữa ngực; bản cũ so tâm root với hộp sóng nên mép
	    sóng quét qua vai/chân người chơi mà không tính là trúng.
	  • XÉT ĐỦ 3 TRỤC TẠI TỪNG MẪU. Bản cũ chỉ xét Y/Z ở vị trí CUỐI frame rồi quét riêng
	    trục X, nên đoạn quét nội suy có thể "trúng" ở một mẫu mà lúc đó người chơi thật ra
	    đang ở độ cao/làn khác.
	  • ĐỆM DÙNG LẠI. Bản cũ cấp phát hai bảng MỖI frame (120 bảng/giây rác cho GC server)
	    chỉ để chứa đúng WAVE_COUNT phần tử.

	⚠️ KHÔNG dùng `Touched` cho sóng như Zone 10 làm với KillBlock: server KHÔNG BAO GIỜ dời
	part sóng (kiến trúc zero-replication, part nằm nguyên ở home), nên Touched sẽ nổ theo vị
	trí HOME chứ không theo vị trí sóng đang hiện. Bẫy này bắt buộc phải phán xử giải tích.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Bộ quét RIÊNG của bẫy này. KHÔNG dùng chung với bẫy khác: mỗi bẫy đều reset()
-- những player ngoài vùng của nó mỗi frame, chung bảng là xoá dấu vết của nhau
-- => đoạn quét luôn rỗng và swept thoái hoá về đúng phép thử điểm nó đang chữa.
local TrapSweep = require(ReplicatedStorage:WaitForChild("Shared").Util.TrapSweep).new("Zone9Tsunami")

local model = script.Parent
local mech = model.Parent
local zone = mech.Parent
local ground = zone:FindFirstChild("Ground")
local floor = ground and ground:FindFirstChild("WaterFloor")
local stageFinish = mech:FindFirstChild("Stage9Finish")

-- v7: 230 studs/s GIỮ NGUYÊN (tốc độ đã hiệu chỉnh cho vừa mắt). Thứ tạo ra gate là
-- WAVE_COUNT — xem khối v7 ở đầu file.
local WAVE_SPEED = 230
local RESPAWN_DELAY = 0.35
--[[
	Số sóng chạy đồng thời, cách nhau đều nhau CYCLE/WAVE_COUNT giây.

	**1 sóng → gate 96 WS** · 2 sóng → 139 · 3 sóng → 162 (đo bằng mô phỏng luật giết ở dưới,
	quét WalkSpeed 40→280 và thử MỌI thời điểm bước vào kênh).

	v8: user chốt 1 sóng (xem khối v8 ở đầu file). Bảng Chỉ Số Stage 9 ghi 138 nên zone này
	giờ nhẹ tay hơn chuẩn — cố ý.

	⚠️ Client (`Zone9TsunamiController`) đọc `WaveCount`/`WaveSpacing` để vẽ đủ số sóng. Đổi số
	ở đây mà client không đọc được thì có sóng VÔ HÌNH giết người chơi — lỗi tệ nhất có thể.
]]
local WAVE_COUNT = 1
local KILL_CD = 0.5
-- Bước rải mẫu swept (studs). Nhỏ hơn nhiều so với killHalf (>= 7) nên không thể lọt.
local SWEEP_STEP = 2.0

-- v6: kênh lấy theo Z của model (user đặt tay trong Edit là nguồn sự thật).
local channelZ = model:GetPivot().Position.Z
local channelWidth = floor and floor.Size.Z or 90
local finishX = stageFinish.Position.X

local homePivot = model:GetPivot()
local baseY = homePivot.Position.Y
local baseRot = homePivot.Rotation

for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then d.Anchored = true end
end
local _, boxSize = model:GetBoundingBox()
local killHalf = math.max(7, boxSize.X * 0.5)

-- Nửa bề dày THÂN nhân vật (v9). Root nằm giữa ngực, nên đây là vế biến "tâm root trùng
-- hộp sóng" thành "thân người chơi CHẠM hộp sóng" — đúng câu user yêu cầu.
local BODY_HALF_X = 2
local BODY_HALF_Y = 3
local BODY_HALF_Z = 2

-- Hộp sóng THẬT + thân người. `GetBoundingBox` trả về tâm hộp, mà pivot của model trùng
-- tâm đó, nên `baseY` dùng được làm tâm cho cả trục Y lẫn Z.
local hitHalfX = killHalf + BODY_HALF_X
local hitHalfZ = boxSize.Z * 0.5 + BODY_HALF_Z
-- Cổng theo CHIỀU CAO (v6). Bản cũ không có, vì nó dựa vào `ActiveStage == 9` để lọc.
-- Bỏ cổng attribute đó rồi thì BẮT BUỘC phải chặn theo Y, nếu không người đứng trên cầu/
-- nền cao vắt qua cùng dải X-Z cũng bị sóng dưới lòng kênh giết oan.
-- v9: lấy đúng nửa chiều cao hộp + thân người thay cho lề +8 chọn tay.
local killHalfY = boxSize.Y * 0.5 + BODY_HALF_Y

-- home = ĐÚNG vị trí user đặt model trong Edit (yêu cầu user 2026-07-25).
local homeX = homePivot.Position.X

local SWEEP_DURATION = math.max(0.1, (finishX - homeX) / WAVE_SPEED)
local CYCLE = SWEEP_DURATION + RESPAWN_DELAY

-- Hợp đồng chia sẻ với Zone9TsunamiController (client).
zone:SetAttribute("WaveSpeed", WAVE_SPEED)
zone:SetAttribute("WaveHomeX", homeX)
zone:SetAttribute("WaveFinishX", finishX)
zone:SetAttribute("WaveY", baseY)
zone:SetAttribute("WaveZ", channelZ)
zone:SetAttribute("WaveRot", baseRot)
zone:SetAttribute("WaveCycle", CYCLE)
zone:SetAttribute("WaveSweepDuration", SWEEP_DURATION)
zone:SetAttribute("WaveCount", WAVE_COUNT)
zone:SetAttribute("WaveSpacing", CYCLE / WAVE_COUNT)

--[[
	VÙNG PHÁN XỬ = LÒNG KÊNH, không hơn. Đây là thứ thay thế cờ `immune` của v6: cùng tác
	dụng "cán đích là an toàn", nhưng suy ra từ VỊ TRÍ nên không quên, không latch, và
	quay lại kênh là lập tức bị phán xử lại.

	VÌ SAO CẮT Ở ĐÚNG `finishX` CHỨ KHÔNG PHẢI `finishX + hitHalfX`:
	`WaterFloor` trải X = [-150, 458] rồi hết; `Stage9Finish` ở 460 là mép thoát. Nhưng thân
	sóng dày 29 studs, nên ở nhịp cuối của lượt quét nó còn phủ tới X = 474 — trùm hẳn lên
	vạch đích. Đo trong Studio 2026-08-20: ngồi đúng X = 460 thì chết trong vòng 1.2s. Tức là
	"cán đích xong chết ngay trên pad" — đúng cái cảm giác tệ mà v6 dựng `immune` để tránh,
	và lần này nó không còn cờ nào đỡ nữa.
	⇒ Hợp đồng gameplay lấy theo KÊNH NƯỚC, không theo phần thân sóng thò ra khỏi kênh trong
	  ~60ms cuối: ra khỏi kênh (X >= finishX) là thoát. Còn ở trong kênh thì chạm sóng là
	  chết — lần này và MỌI lần sau.
]]
local minX, maxX = math.min(homeX, finishX) - hitHalfX, math.max(homeX, finishX)
local halfChannel = channelWidth * 0.5 + 8

local lastKill: { [Player]: number } = {}

local SPACING = CYCLE / WAVE_COUNT

-- Vị trí sóng thứ `index` (0 = sóng dẫn đầu) tại thời điểm `now`, hoặc nil nếu sóng đó đang
-- ở pha "wait" (đã ra khỏi kênh, chưa hồi sinh) — lúc đó nó không có sát thương.
local function waveAt(now: number, index: number): number?
	local t = (now - index * SPACING) % CYCLE
	if t >= SWEEP_DURATION then return nil end
	return homeX + WAVE_SPEED * t
end

-- Đệm DÙNG LẠI cho vị trí đầu/cuối frame của từng sóng. Bản cũ cấp phát hai bảng mới mỗi
-- Heartbeat chỉ để chứa WAVE_COUNT phần tử — 120 bảng/giây rác cho GC của server, không
-- đổi lấy gì cả.
local fronts = table.create(WAVE_COUNT)
local backs = table.create(WAVE_COUNT)

RunService.Heartbeat:Connect(function(dt)
	local now = Workspace:GetServerTimeNow()

	-- Gom vị trí ĐẦU và CUỐI frame của TỪNG sóng. Sóng nào đang ẩn thì bỏ qua hẳn.
	local live = 0
	for i = 0, WAVE_COUNT - 1 do
		local wx = waveAt(now, i)
		if wx then
			live += 1
			fronts[live] = wx
			-- Vị trí ở ĐẦU frame. Kẹp về homeX nếu frame này vắt qua ranh giới chu kỳ
			-- (sóng vừa hồi sinh — không được nội suy ngược từ cuối kênh về đầu kênh).
			backs[live] = math.max(wx - WAVE_SPEED * dt, homeX)
		end
	end
	if live == 0 then return end

	-- Quãng sóng đi trong frame này — dùng để chọn số mẫu (xem TrapSweep.segment).
	local travel = fronts[1] - backs[1]

	for _, plr in Players:GetPlayers() do
		-- CỔNG VỊ TRÍ (v6): trong lòng kênh là bị phán xử, không cần attribute stage.
		-- v9: và KHÔNG còn cờ `immune` nào chen vào giữa nữa.
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r and r:IsA("BasePart") then
			local p = r.Position
			if
				p.X >= minX
				and p.X < maxX
				and math.abs(p.Z - channelZ) <= halfChannel
				and math.abs(p.Y - baseY) <= killHalfY
			then
				-- SWEPT: quét đoạn người chơi đi, sóng cũng chạy theo cùng alpha.
				-- Số mẫu lấy theo cái lớn hơn giữa hai quãng đường. Mọi sóng đang hiện
				-- đều được thử trên CÙNG các mẫu đó.
				local from, steps = TrapSweep.segment(plr, p, SWEEP_STEP, travel)
				local delta = p - from
				local hit = false
				for i = 0, steps do
					local alpha = i / steps
					local sp = from + delta * alpha
					-- NARROW PHASE ĐỦ 3 TRỤC ngay tại mẫu (v9). Bản cũ chốt Y/Z một lần ở vị
					-- trí CUỐI frame rồi chỉ nội suy trục X, nên một cú bật lên khỏi kênh giữa
					-- frame vẫn bị tính là trúng ở các mẫu phía sau.
					if
						math.abs(sp.Z - channelZ) <= hitHalfZ
						and math.abs(sp.Y - baseY) <= killHalfY
					then
						for w = 1, live do
							local wx = backs[w] + (fronts[w] - backs[w]) * alpha
							if math.abs(sp.X - wx) <= hitHalfX then
								hit = true
								break
							end
						end
					end
					if hit then
						break
					end
				end
				if hit and now - (lastKill[plr] or 0) >= KILL_CD then
					lastKill[plr] = now
					h.Health = 0
					TrapSweep.reset(plr)
				end
			else
				TrapSweep.reset(plr) -- ngoài kênh: cắt dấu vết
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastKill[plr] = nil
end)
