-- Keyboard — port KeyboardASMRClient v5: lún lò xo sâu, click cơ ProSoundEffects
-- + pitch random, sao bùng nổ khi dậm (qua ParticlePool).
-- RGB GLOW ĐÃ XOÁ theo yêu cầu user 2026-07-24 (phím không đổi màu nữa).

local Keyboard = {}

-- BÀN PHÍM CƠ v2 (2026-07-27): bộ mẫu "creamy/thocky" — mỗi file là MỘT cú nhấn đơn
-- 0.15–0.23s, gọn và đầy, thay bộ Rapid Typing cũ (0.24–0.73s, có đuôi ring dài nên khi
-- chạy nhanh các tiếng chồng lên nhau thành rào rào thay vì lộp cộp rời rạc).
local CLICK_IDS = {
	102855535543930, -- Creamy Keyboard 0.18s
	113108830240353, -- Cream keyboard 0.21s
	72826565018765, -- Keyboard Clicked ASMR 0.15s
	125615721658437, -- keyboard b 0.20s
	125027148509088, -- Keyboard g 0.21s
	88838553648526, -- Keyboard h 0.19s
	125236580407249, -- Keyboard j 0.23s
	132465969238702, -- Keyboard button 0.21s
}
Keyboard.soundIds = CLICK_IDS

-- VIBE (2026-07-28) — Zone 15 chia 3 đoạn Fire / Water / Lightning bằng attribute `Vibe`
-- trên MODEL bàn (do `tools/zone15_vibes.luau` gán). Bàn không có attribute (các zone khác)
-- giữ nguyên hiệu ứng sao cầu vồng cũ, nên thay đổi này không đụng tới zone nào khác.
local VIBE_FX = {
	Fire = "fire",
	Water = "water",
	Lightning = "lightning",
}
local DEFAULT_FX = "stars"

-- Cao độ theo HÀNG phím: chạy ngang bàn phím là ra một chuỗi nốt đi lên/xuống thay vì
-- tiếng lộp cộp ngẫu nhiên — đây là thứ làm sàn phím "nghe muốn đi lại mãi".
-- Ngũ cung (không có nốt nghịch tai) trải trên 5 hàng, lặp lại nếu bàn phím nhiều hàng hơn.
local ROW_PITCH = { 0.94, 1.06, 1.19, 1.33, 1.5 }

local CELL = 3
local KEY_REACH = 1.9
local FOOT_DROP = 3.05
local Y_TOLERANCE = 2.8
local PRESS_DEPTH = 0.9
local PULSE = 0.14
local SAMPLE_STEP = 1.4
local MAX_SAMPLES = 40
local MAX_SOUNDS_PER_FRAME = 8
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

		-- Gán nốt cho từng phím theo HÀNG (trục ngắn của bàn = hướng có ít hàng hơn).
		-- Tính MỘT LẦN lúc attach; runtime chỉ đọc rec.pitch, không tốn gì thêm.
		local spanX, spanZ = x1 - x0, z1 - z0
		local rowAlongZ = spanZ <= spanX
		local rowSpan = math.max(if rowAlongZ then spanZ else spanX, 1e-3)
		local rowBase = if rowAlongZ then z0 else x0
		local rowCount = math.max(math.floor(rowSpan / CELL + 0.5), 1)
		for _, rec in keys do
			local along = (if rowAlongZ then rec.z else rec.x) - rowBase
			local row = math.floor(along / rowSpan * rowCount + 0.5)
			rec.pitch = ROW_PITCH[row % #ROW_PITCH + 1]
		end

		self.ready = true
		print(("[ASMR Keyboard] sẵn sàng — %d phím, %d hàng nốt"):format(#keys, rowCount + 1))
	end)

	local function playKey(rec, speedRatio, volScale)
		if not FxBudget.fxOK(rec.part.Position, 80) then
			return
		end
		ParticlePool.emit(fx, Vector3.new(rec.x, rec.topY + 0.2, rec.z), fxCount)
		SoundPool.playStep(
			CLICK_IDS[math.random(#CLICK_IDS)],
			rec.part.Position,
			(0.5 + speedRatio * 0.45) * volScale,
			-- nốt của HÀNG (cố định theo phím) + rung nhẹ ngẫu nhiên cho khỏi máy móc.
			-- KHÔNG cộng speedRatio nữa: chạy nhanh mà pitch trôi lên thì mất luôn giai điệu.
			(rec.pitch or 1) * (0.97 + math.random() * 0.06),
			70
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
			local acc = k * (target - rec.depth) - d * rec.vel
			rec.vel += acc * step
			rec.depth += rec.vel * step
			if pressed and math.abs(1 - rec.depth) < 0.008 and math.abs(rec.vel) < 0.06 then
				rec.depth = 1
				rec.vel = 0
				rec.settled = true
				rec.part.CFrame = rec.rest * CFrame.new(0, -PRESS_DEPTH, 0)
			elseif not pressed and math.abs(rec.depth) < 0.004 and math.abs(rec.vel) < 0.05 then
				rec.depth = 0
				rec.vel = 0
				rec.settled = false
				rec.part.CFrame = rec.rest
				activeKeys[rec] = nil
			else
				rec.settled = false
				local depth = math.clamp(rec.depth, -0.12, 1.08) -- cho phép nảy quá đà nhẹ
				rec.part.CFrame = rec.rest * CFrame.new(0, -PRESS_DEPTH * depth, 0)
			end
		end
	end

	function self.destroy() end

	return self
end

return Keyboard
