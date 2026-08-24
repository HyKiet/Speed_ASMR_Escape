--!strict
-- MelodyRun — port nguyên vẹn MelodyRunClient: ô đèn NGŨ CUNG, bước vào -> sáng Neon
-- + note piano pitch-shift 2^(semi/12); tốc độ cao -> swept + stagger 25ms = glissando.
-- PointLight lazy-create per ô giữ nguyên (≤64 ô, Brightness=0 khi tắt).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local MelodyRun = {}

local NOTE_ID = 121997668450827 -- piano note c5, 4.00s (đã đo 2026-08-05)
MelodyRun.soundIds = { NOTE_ID }
-- Nốt piano dài 4.00s và ngân chồng lên nhau là ĐÚNG bản chất đàn — nhưng SoundPool
-- mặc định chỉ 4 giọng/id nên nốt thứ 5 đã cắt ngang nốt thứ nhất. Glissando bắn tới 8
-- nốt/frame (MAX_NOTES_PER_FRAME) nên cần nhiều: 28 giọng ≈ 3.5 giây nốt chồng.
MelodyRun.voices = { [NOTE_ID] = 28 }
-- Mẫu là piano C5; ô cột 6–8 còn pitch-shift LÊN thêm một quãng tám nên đỉnh phổ rơi
-- đúng dải 4–8kHz — tai nghe ra "chói" chứ không phải "to". Cắt dải cao ngay tại giọng
-- (EqualizerSoundEffect gắn cố định, 0 chi phí runtime) là cách rẻ nhất để về chất ASMR;
-- kèm hạ nhẹ mid cho bớt gắt, giữ nguyên low để nốt vẫn có thân.
MelodyRun.voiceFx = { [NOTE_ID] = { low = 0, mid = -3, high = -16 } }

-- Bậc ngũ cung LEO LIÊN TỤC theo `Col`: col 1,2,3… → semi 0,2,4,7,9,12,14,16,19,21…
-- KHÔNG có chu kỳ trong công thức này — muốn cả zone là một thang đi lên duy nhất thì
-- builder phải phát Col TĂNG DẦN suốt chiều dài đường chạy (đừng cho Col lặp vòng).
local PENTA = { 0, 2, 4, 7, 9 }
-- Dịch cả thang xuống 1 quãng tám: Zone 13 dùng Col 1..10 ⇒ semi -12..+9 (C4→A5).
-- Cận trên +9 là mức pitch-shift tối đa còn nghe ra tiếng đàn; mẫu là C5 nên đẩy quá
-- +12 là bắt đầu chói lại (bài học 2026-08-06), đừng nới thang rộng hơn 10 bậc.
local OCTAVE_DOWN = -12
-- Cỡ lưới/vùng bắt ô ĐƯỢC ĐO TỪ Ô THẬT lúc attach, không hardcode nữa (2026-08-05).
-- Bản cũ chốt cứng CELL 4.5 và vùng bắt 2.3 studs — vừa khít ô 3.6 của Zone 13 lúc đó.
-- Zone 13 đổi sang ô 10.8 là hỏng cả hai: chỉ 4.6×4.6 giữa mỗi ô phản hồi (18% mặt ô),
-- và `bucketAt` chỉ tra ĐÚNG MỘT cell nên ô có tâm cách 5.4 studs nằm ở cell khác,
-- không bao giờ tìm thấy. Giờ vùng bắt = nửa cạnh ô, lưới = một cạnh ô, và tra 3×3 cell.
local CELL_MIN = 4.5
local FOOT_DROP = 3.2
local Y_TOL = 2.8
local MAX_NOTES_PER_FRAME = 8

function MelodyRun.attach(model, engine)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }

	local records = {}
	local grid
	local box, topY
	-- Vùng bắt tính RIÊNG THEO TỪNG TRỤC: ô Zone 13 là 50×24 (chữ nhật), dùng chung nửa
	-- cạnh LỚN cho cả hai trục thì ô với tay 25 studs sang ngang trong khi nó chỉ sâu 12 —
	-- ô hàng trên/dưới tranh nhau bàn chân vô cớ.
	local reachX, reachZ = 2.3, 2.3 -- đo lại lúc attach
	local lightRange = 9 -- theo cỡ ô, đo lại lúc attach
	local glowing = {} -- set các rec đang sáng

	task.spawn(function()
		local folder = model:WaitForChild("Tiles", 10)
		if not folder then
			return
		end
		engine.Await.childrenStable(folder)
		-- Đo cỡ ô thật rồi mới dựng lưới: ô 3.6 → reach 1.95 / cell 4.5 (như cũ),
		-- ô 10.8 → reach 5.55 / cell 11.1. Cùng một code chạy đúng cho cả hai.
		local sample = folder:FindFirstChildWhichIsA("BasePart")
		if sample then
			reachX = sample.Size.X * 0.5 + 0.15
			reachZ = sample.Size.Z * 0.5 + 0.15
			-- CHẶN TRẦN tầm đèn: ô Zone 13 giờ rộng 50 studs, cứ nhân 2.6 là ra PointLight
			-- Range 65 — vài chục đèn cỡ đó chồng nhau là gánh nặng render vô ích vì ánh
			-- sáng đã loang quá xa mặt ô. 34 đủ phủ trọn một ô to nhất.
			lightRange = math.clamp(math.max(reachX, reachZ) * 2.6, 9, 34)
		end
		grid = engine.SpatialGrid.new(math.max(CELL_MIN, math.max(reachX, reachZ) * 2))
		for _, t in folder:GetChildren() do
			if t:IsA("BasePart") then
				local col = t:GetAttribute("Col") or 1
				local hue = t:GetAttribute("Hue") or 0
				local semi = PENTA[(col - 1) % 5 + 1] + 12 * math.floor((col - 1) / 5) + OCTAVE_DOWN
				local rec = {
					part = t,
					dim = t.Color,
					bright = Color3.fromHSV(hue, 0.6, 1),
					semi = semi,
					glow = 0,
					light = nil,
				}
				table.insert(records, rec)
				grid:insert(t.Position.X, t.Position.Z, rec)
			end
		end
		local base = model:FindFirstChild("Base")
		box = if base and base:IsA("BasePart") then Bounds.ofBase(base, 2) else Bounds.ofParts(folder:GetChildren(), 2)
		topY = records[1] and (records[1].part.Position.Y + records[1].part.Size.Y / 2) or (box and box.topY) or 9.6
		self.ready = box ~= nil and #records > 0
		Log.Floor("MelodyRun", #records, model)
	end)

	-- Quét 3×3 cell chứ KHÔNG `bucketAt` (1 cell): ô không bao giờ căn khớp biên cell, nên
	-- đứng gần mép ô là rơi sang cell bên cạnh và tra 1 cell sẽ trả về nil — mặt sàn thủng
	-- lỗ chỗ. 9 bucket vẫn là O(1), chi phí không đáng kể.
	local function tileAt(px, pz)
		local best, bd
		grid:query(px, pz, 1, function(rec)
			local dx = math.abs(px - rec.part.Position.X)
			local dz = math.abs(pz - rec.part.Position.Z)
			if dx <= reachX and dz <= reachZ then
				local d = dx * dx + dz * dz
				if not bd or d < bd then
					bd, best = d, rec
				end
			end
		end)
		return best
	end

	-- Van tiết lưu nhịp: ô to rồi thì ở 250 WS vẫn còn ~14 nốt/giây, mà glissando quét
	-- có thể dồn cả chùm vào một frame. Ép mỗi nốt cách nhau ≥ MIN_NOTE_GAP; nốt nào phải
	-- xếp hàng quá LATE_DROP thì BỎ HẲN (xếp hàng dài sẽ thành tiếng đàn lệch khỏi bàn chân).
	local MIN_NOTE_GAP = 0.075
	local LATE_DROP = 0.22
	local nextNoteAt = 0

	-- Khoá lặp theo CAO ĐỘ, không theo ô. Hai lý do một ô kêu hai lần mà khoá-theo-ô không
	-- bắt được: (1) đúng ranh giới hai cột, khoảng cách tới hai tâm bằng nhau nên `rec` nhấp
	-- nháy A→B→A trong vài frame; (2) một cột có nhiều ô cùng hàng ngang, đổi hàng là đổi
	-- `rec` nhưng vẫn cùng nốt. Khoá theo semi trị cả hai, và đúng thứ ta muốn về mặt nhạc:
	-- thang leo không bao giờ đọc lại một bậc ngay sau chính nó.
	local RETRIGGER_LOCK = 0.35
	local lastSemiAt = {}

	local function playNote(rec, ratio, delaySec)
		local now = os.clock()
		local at = math.max(now + (delaySec or 0), nextNoteAt)
		if at - now > LATE_DROP then
			return
		end
		if at - (lastSemiAt[rec.semi] or -math.huge) < RETRIGGER_LOCK then
			return
		end
		lastSemiAt[rec.semi] = at
		nextNoteAt = at + MIN_NOTE_GAP
		task.delay(at - now, function()
			if not FxBudget.fxOK(rec.part.Position, 150) then
				return
			end
			-- sáng đèn
			rec.glow = 1
			glowing[rec] = true
			rec.part.Material = Enum.Material.Neon
			rec.part.Color = rec.bright
			if not rec.light then
				local l = Instance.new("PointLight")
				l.Color = rec.bright
				l.Range = lightRange
				l.Brightness = 0
				l.Parent = rec.part
				rec.light = l
			end
			rec.light.Brightness = 3.5
			-- note pitch ngũ cung
			SoundPool.playStep(
				NOTE_ID,
				rec.part.Position,
				-- 0.5→0.85 (bản 2026-08-05) là quá to cho một mẫu ngân 4s chồng 28 giọng:
				-- tổng năng lượng cộng dồn thành ồn. Hạ về 0.30→0.40 — vẫn nghe rõ hơn hẳn
				-- mốc câm 0.22 cũ, nhưng đủ nhẹ để làm nền ASMR.
				0.3 + ratio * 0.1,
				math.pow(2, rec.semi / 12) * (1 + (math.random() * 0.01 - 0.005)),
				90
			)
		end)
	end

	local currentTile = nil
	local lastPos = nil

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		local rec = nil
		local onFloor = false
		local ratio = 0
		if foot then
			local pos = foot.pos
			if engine.Bounds.contains(box, pos) and math.abs((pos.Y - FOOT_DROP) - topY) < Y_TOL then
				onFloor = true
				ratio = foot.ratio
				rec = tileAt(pos.X, pos.Z)
			end

			-- swept glissando: kích hoạt các ô NHẢY CÓC qua giữa 2 frame.
			-- Loại trừ CẢ `rec` (ô đang đứng, do khối dưới lo) LẪN `currentTile` (ô vừa rời —
			-- lúc này currentTile còn là ô của frame trước vì nó chỉ được gán lại ở dưới).
			-- Thiếu vế thứ hai là mỗi nốt kêu ĐÚNG HAI LẦN khi bước sang ô kế: nghe thành
			-- "sol sol la la" thay vì thang leo sạch (đo được ở Zone 13 ngày 2026-08-06).
			if onFloor and lastPos then
				local delta = pos - lastPos
				local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if dist > 3 and dist < 120 then
					local hit, order = {}, {}
					local steps = math.min(math.floor(dist / 2), 24)
					for i = 1, steps do
						local sp = lastPos:Lerp(pos, i / (steps + 1))
						local r = tileAt(sp.X, sp.Z)
						if r and not hit[r] and r ~= rec and r ~= currentTile then
							hit[r] = true
							table.insert(order, r)
						end
					end
					for i, r in order do
						if i > MAX_NOTES_PER_FRAME then
							break
						end
						playNote(r, ratio, (i - 1) * 0.05) -- stagger 50ms = glissando thong thả
					end
				end
			end
			lastPos = onFloor and pos or nil
		else
			lastPos = nil
		end

		if rec ~= currentTile then
			currentTile = rec
			if rec then
				playNote(rec, ratio, 0)
			end
		end

		-- fade đèn (thủ công, không TweenService)
		for g in glowing do
			g.glow -= dt / 0.85
			if g.glow <= 0 then
				g.glow = 0
				glowing[g] = nil
				g.part.Material = Enum.Material.SmoothPlastic
				g.part.Color = g.dim
				if g.light then
					g.light.Brightness = 0
				end
			else
				local a = g.glow
				g.part.Color = g.dim:Lerp(g.bright, a)
				if g.light then
					g.light.Brightness = 3.5 * a
				end
				if a < 0.55 and g.part.Material == Enum.Material.Neon then
					g.part.Material = Enum.Material.SmoothPlastic
				end
			end
		end
	end

	function self.destroy() end

	return self
end

return MelodyRun
