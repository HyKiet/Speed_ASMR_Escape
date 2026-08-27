--!strict
--[[
	Zone9TsunamiService.luau — sóng thần Tsunami Sprint, Stage 9.

	THAY THẾ script inline `Workspace.Zones.Zone9.Mechanics.Tsunami.TsunamiScript` (2026-08-27).

	Kiến trúc (v4, giữ nguyên): đồng hồ tất định, zero-replication. Server KHÔNG `PivotTo`
	model sóng. Vị trí sóng = f(`workspace:GetServerTimeNow()`) → `Zone9TsunamiController`
	dựng lại y hệt và render local.

	===== v6 (2026-08-07) — ĐỘ CHÍNH XÁC =====
	1) CỔNG STAGE BẰNG Touched là lỗ CHÍNH của zone này. Bản cũ đòi `ActiveStage == 9`, mà
	   attribute đó chỉ được gán khi Stage9Start.Touched nổ. Chạy nhanh thì bước physics nhảy
	   qua hẳn tấm pad mỏng ⇒ Touched KHÔNG nổ ⇒ sóng KHÔNG BAO GIỜ giết người chơi đó. Chạy
	   càng nhanh càng chắc miễn nhiễm.
	   ⇒ Thay bằng cổng VỊ TRÍ (X-Z trong lòng kênh + Y quanh mực sóng).
	2) LẤY MẪU RỜI RẠC. Khi người chơi chạy NGƯỢC vào sóng, tốc độ tiếp cận lên tới
	   230 + 250 = 480 studs/s = 8 studs/frame ở 60fps, gấp đôi nếu server tụt 30fps — đủ để
	   xuyên qua bề dày sóng mà không frame nào thấy trùng.
	   ⇒ Quét cả đoạn player đi trong frame, đồng thời nội suy vị trí sóng tại từng mẫu.

	===== v9 (2026-08-20) — "CHẠM SÓNG LÀ CHẾT" =====
	User: "test vượt qua zone 9 xong thì sóng thần không còn giết player nữa".

	Thủ phạm là cờ `immune` của v6 — nó LATCH VĨNH VIỄN. `Stage9Finish.Touched` bật nó lên, và
	thứ DUY NHẤT tắt được là `Stage9Start.Touched`, một tấm pad dày đúng 4 studs. Ai quay lại
	lòng kênh bằng checkpoint-respawn, teleport, hay chỉ chạy vòng lại đều KHÔNG chạm lại pad
	đó ⇒ bất tử với sóng cho tới hết phiên. Trớ trêu là nó tái lập đúng cái bệnh "cổng bằng
	Touched" mà v6 vừa chữa xong ở lỗ (1).

	Cờ đó còn THỪA: sóng biến mất đúng tại `finishX`, nên mọi chỗ sau vạch đích tự nó đã an
	toàn về HÌNH HỌC.
	⇒ Bỏ hẳn `immune`. Luật giết gói trong MỘT câu, không trạng thái, không lịch sử:
	  **khối sóng có phủ lên thân nhân vật ở thời điểm này không.**

	Kèm hai chỗ chính xác hơn:
	  • CỘNG NỬA BỀ DÀY THÂN. Root nằm giữa ngực; bản cũ so tâm root với hộp sóng nên mép sóng
	    quét qua vai/chân người chơi mà không tính là trúng.
	  • XÉT ĐỦ 3 TRỤC TẠI TỪNG MẪU. Bản cũ chốt Y/Z ở vị trí CUỐI frame rồi chỉ quét riêng
	    trục X, nên một cú bật lên khỏi kênh giữa frame vẫn bị tính là trúng ở các mẫu sau.

	===== v10 (2026-08-27) — BÙ TRỄ MẠNG + VÀO GIT =====
	Ping thật 350–400ms. Sóng đi 230 studs/s, nên 195ms trễ = **45 studs** lệch giữa sóng mà
	server phán xử và sóng người chơi nhìn thấy — dày hơn cả thân sóng (29 studs). Tức là ở
	ping cao, "chạm sóng là chết" thành ra chết TRƯỚC khi sóng tới.
	⇒ Dựng sóng tại `now - LagComp.Delay(player)`. Xem Shared/Util/LagComp.
	Đồng thời chuyển từ script inline sang service Rojo để git quản lý được.

	⚠️ KHÔNG dùng `Touched` cho sóng như Zone 10 từng làm: server KHÔNG BAO GIỜ dời part sóng
	(part nằm nguyên ở home), nên Touched sẽ nổ theo vị trí HOME chứ không theo vị trí sóng
	đang hiện. Bẫy này bắt buộc phải phán xử giải tích.

	KHÔNG đụng WAVE_SPEED/RESPAWN_DELAY ⇒ gate tốc độ của zone giữ nguyên.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Bộ quét RIÊNG của bẫy này (xem TrapSweep — dùng chung bảng là xoá dấu vết của nhau).
local TrapSweep = require(ReplicatedStorage.Shared.Util.TrapSweep).new("Zone9Tsunami")
local LagComp = require(ReplicatedStorage.Shared.Util.LagComp)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone9TsunamiService = {}

-- v7 (2026-08-12): 230 studs/s GIỮ NGUYÊN. Thứ tạo ra gate là WAVE_COUNT.
-- Đo lại bằng mô phỏng đúng luật giết bên dưới: 1 sóng chỉ cho gate 96 WS (Bảng Chỉ Số
-- Stage 9 = 138). Công thức cũ "LEN/CYCLE = 157" SAI vì bỏ quên quãng chạy đà: sóng sinh ở
-- home = -137, tức 133 studs SAU LƯNG vạch xuất phát, nên ai bước vào ngay sau đuôi sóng
-- được tặng ~530 studs quãng đường của sóng.
-- 1 sóng → 96 · 2 sóng → 139 · 3 sóng → 162. v8 chốt 1 sóng (nhẹ tay hơn Bảng 138 — cố ý).
local WAVE_SPEED = 230
local RESPAWN_DELAY = 0.35
-- ⚠️ Client đọc WaveCount/WaveSpacing để vẽ đủ số sóng. Sửa số này mà client đọc hụt thì có
-- sóng VÔ HÌNH giết người chơi.
local WAVE_COUNT = 1
local KILL_CD = 0.5
local SWEEP_STEP = 2.0
local RESOLVE_RETRY = 1

-- Nửa bề dày THÂN nhân vật (v9). Root nằm giữa ngực, nên đây là vế biến "tâm root trùng hộp
-- sóng" thành "thân người chơi CHẠM hộp sóng" — đúng câu user yêu cầu.
local BODY_HALF_X = 2
local BODY_HALF_Y = 3
local BODY_HALF_Z = 2

local model: Model? = nil
local channelZ, baseY, homeX, finishX = 0, 0, 0, 0
local hitHalfX, hitHalfZ, killHalfY = 0, 0, 0
local minX, maxX, halfChannel = 0, 0, 0
local SWEEP_DURATION, CYCLE, SPACING = 1, 1, 1

local lastKill: { [Player]: number } = {}

-- Đệm DÙNG LẠI cho vị trí đầu/cuối frame của từng sóng. Bản cũ cấp phát hai bảng mới mỗi
-- Heartbeat chỉ để chứa WAVE_COUNT phần tử — 120 bảng/giây rác cho GC của server.
local fronts = table.create(WAVE_COUNT)
local backs = table.create(WAVE_COUNT)

-- Vị trí sóng thứ `index` (0 = sóng dẫn đầu) tại `now`, hoặc nil nếu sóng đó đang ở pha
-- "wait" (đã ra khỏi kênh, chưa hồi sinh) — lúc đó nó không có sát thương.
local function waveAt(now: number, index: number): number?
	local t = (now - index * SPACING) % CYCLE
	if t >= SWEEP_DURATION then
		return nil
	end
	return homeX + WAVE_SPEED * t
end

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone9")
	local mech = zone and zone:FindFirstChild("Mechanics")
	local tsunami = mech and mech:FindFirstChild("Tsunami")
	local ground = zone and zone:FindFirstChild("Ground")
	local floor = ground and ground:FindFirstChild("WaterFloor")
	local stageFinish = mech and mech:FindFirstChild("Stage9Finish")
	if not zone or not tsunami or not tsunami:IsA("Model") then
		return false
	end
	if not stageFinish or not stageFinish:IsA("BasePart") then
		return false
	end

	model = tsunami
	local homePivot = tsunami:GetPivot()
	channelZ = homePivot.Position.Z
	baseY = homePivot.Position.Y
	homeX = homePivot.Position.X
	finishX = stageFinish.Position.X
	local channelWidth = (floor and floor:IsA("BasePart")) and floor.Size.Z or 90

	for _, d in tsunami:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local _, boxSize = tsunami:GetBoundingBox()
	local killHalf = math.max(7, boxSize.X * 0.5)

	-- Hộp sóng THẬT + thân người. `GetBoundingBox` trả về tâm hộp, mà pivot của model trùng
	-- tâm đó, nên `baseY` dùng được làm tâm cho cả trục Y lẫn Z.
	hitHalfX = killHalf + BODY_HALF_X
	hitHalfZ = boxSize.Z * 0.5 + BODY_HALF_Z
	-- Cổng theo CHIỀU CAO (v6). Bỏ cổng attribute rồi thì BẮT BUỘC chặn theo Y, nếu không
	-- người đứng trên cầu/nền cao vắt qua cùng dải X-Z cũng bị sóng dưới lòng kênh giết oan.
	killHalfY = boxSize.Y * 0.5 + BODY_HALF_Y

	SWEEP_DURATION = math.max(0.1, (finishX - homeX) / WAVE_SPEED)
	CYCLE = SWEEP_DURATION + RESPAWN_DELAY
	SPACING = CYCLE / WAVE_COUNT

	--[[
		VÙNG PHÁN XỬ = LÒNG KÊNH, không hơn. Đây là thứ thay thế cờ `immune` của v6: cùng tác
		dụng "cán đích là an toàn", nhưng suy ra từ VỊ TRÍ nên không quên, không latch, và
		quay lại kênh là lập tức bị phán xử lại.

		VÌ SAO CẮT Ở ĐÚNG `finishX` CHỨ KHÔNG PHẢI `finishX + hitHalfX`:
		`WaterFloor` trải X = [-150, 458] rồi hết; `Stage9Finish` ở 460 là mép thoát. Nhưng
		thân sóng dày 29 studs, nên ở nhịp cuối của lượt quét nó còn phủ tới X = 474 — trùm
		hẳn lên vạch đích. Đo trong Studio 2026-08-20: ngồi đúng X = 460 thì chết trong 1.2s.
		Tức "cán đích xong chết ngay trên pad" — đúng cảm giác tệ mà v6 dựng `immune` để tránh.
		⇒ Hợp đồng gameplay lấy theo KÊNH NƯỚC, không theo phần thân sóng thò ra khỏi kênh
		  trong ~60ms cuối.
	]]
	minX, maxX = math.min(homeX, finishX) - hitHalfX, math.max(homeX, finishX)
	halfChannel = channelWidth * 0.5 + 8

	-- Hợp đồng với Zone9TsunamiController.
	zone:SetAttribute("WaveSpeed", WAVE_SPEED)
	zone:SetAttribute("WaveHomeX", homeX)
	zone:SetAttribute("WaveFinishX", finishX)
	zone:SetAttribute("WaveY", baseY)
	zone:SetAttribute("WaveZ", channelZ)
	zone:SetAttribute("WaveRot", homePivot.Rotation)
	zone:SetAttribute("WaveCycle", CYCLE)
	zone:SetAttribute("WaveSweepDuration", SWEEP_DURATION)
	zone:SetAttribute("WaveCount", WAVE_COUNT)
	zone:SetAttribute("WaveSpacing", SPACING)
	return true
end

local function tick(dt: number)
	local tsunami = model
	if not tsunami then
		return
	end
	if not tsunami:IsDescendantOf(Workspace) then
		model = nil
		return
	end

	local now = Workspace:GetServerTimeNow()

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local p = root.Position
			if
				p.X >= minX
				and p.X < maxX
				and math.abs(p.Z - channelZ) <= halfChannel
				and math.abs(p.Y - baseY) <= killHalfY
			then
				--[[
					BÙ TRỄ (v10): `p` là ảnh chụp cách đây `delay` giây. Sóng đi 230 studs/s
					nên ở 195ms nó đã đi 45 studs — dày hơn cả thân sóng. Phải dựng sóng tại
					`now - delay` thì mới đúng khung hình người chơi đã thấy.
				]]
				local tEnd = now - LagComp.Delay(player)

				-- Vị trí ĐẦU và CUỐI frame của TỪNG sóng đang hiện, ở thang thời gian đã bù.
				local live = 0
				for i = 0, WAVE_COUNT - 1 do
					local wx = waveAt(tEnd, i)
					if wx then
						live += 1
						fronts[live] = wx
						-- Kẹp về homeX nếu frame này vắt qua ranh giới chu kỳ (sóng vừa hồi
						-- sinh — không được nội suy ngược từ cuối kênh về đầu kênh).
						backs[live] = math.max(wx - WAVE_SPEED * dt, homeX)
					end
				end

				if live == 0 then
					TrapSweep.segment(player, p, SWEEP_STEP, 0) -- vẫn ghi dấu vết cho frame sau
				else
					-- Quãng sóng đi trong frame này — dùng để chọn số mẫu.
					local travel = fronts[1] - backs[1]
					local from, steps = TrapSweep.segment(player, p, SWEEP_STEP, travel)
					local delta = p - from
					local hit = false
					for i = 0, steps do
						local alpha = i / steps
						local sp = from + delta * alpha
						-- NARROW PHASE ĐỦ 3 TRỤC ngay tại mẫu (v9). Bản cũ chốt Y/Z một lần ở
						-- vị trí CUỐI frame rồi chỉ nội suy trục X, nên một cú bật lên khỏi
						-- kênh giữa frame vẫn bị tính là trúng ở các mẫu phía sau.
						if math.abs(sp.Z - channelZ) <= hitHalfZ and math.abs(sp.Y - baseY) <= killHalfY then
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
					if hit and now - (lastKill[player] or 0) >= KILL_CD then
						lastKill[player] = now
						humanoid.Health = 0
						TrapSweep.reset(player)
					end
				end
			else
				TrapSweep.reset(player)
			end
		end
	end
end

function Zone9TsunamiService.Init() end

function Zone9TsunamiService.Start()
	task.spawn(function()
		while not resolve() do
			task.wait(RESOLVE_RETRY)
		end
		RunService.Heartbeat:Connect(tick)
		Log.Boot(`[Zone9TsunamiService] {WAVE_COUNT} sóng {WAVE_SPEED} studs/s — client render, server bù trễ`)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKill[player] = nil
	end)
end

return Zone9TsunamiService
