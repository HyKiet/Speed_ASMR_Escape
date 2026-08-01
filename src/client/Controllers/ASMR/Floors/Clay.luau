-- Clay — port nguyên vẹn ClayClient v2: ô bo góc squishy lún + phình ngang dưới chân,
-- hồi phục chậm (clay memory), âm nặn đất mịn.

local Clay = {}

-- Mix ASMR ÊM DỊU (user chê bản squelch/pop sắc quá): clay chính + Gooshy Grab mềm
-- + Slime 2 ướt trầm — không âm percussive
local SQUISH_SOUNDS = { 133081811995754, 9114631918, 76169806288463 }
Clay.soundIds = SQUISH_SOUNDS

-- v3 (2026-07-26, feedback user): "0.75 lún quá sâu" → thiết kế lại cho PHÊ + GÂY NGHIỆN:
--   • Lún vừa (0.48 ≈ ô còn hé trên sàn) nhưng NHÚN NHANH — cảm giác đàn hồi tức thì.
--   • Hồi phục kiểu THẠCH SỐNG: nảy vượt đà (overshoot) + rung tắt dần thay vì trồi đều
--     (đây là phần "nghiện" — mỗi bước chân để lại một nhịp nảy phía sau).
--   • Ô SÁNG LÊN khi bị đè (lit color) rồi nguội dần theo độ lún — mắt bám được vệt chân.
--   • RADIUS 9.5 > pitch 8.5 → ô kề bên lún nhẹ theo (falloff w²) = mặt sàn dập dềnh như sóng.
local RADIUS = 9.5 -- bán kính ảnh hưởng quanh chân (phủ nhẹ sang ô kề)
local MAX_SQUISH = 0.48 -- lún tối đa 48% chiều cao (ô 2.2 → còn hé 0.24 trên sàn)
local BULGE = 0.16 -- phình ngang khi lún (0.16×8=1.28 < khe pitch → không chồng ô)
local PRESS_RATE = 20 -- nhún gần như tức thì theo chân
local RECOVER_RATE = 2.4 -- trồi nhanh (đàn hồi), vệt còn lại do jiggle đảm nhiệm

-- Nhịp nảy khi chân rời ô (quyết định độ "phê"): lò xo cosine tắt dần —
-- disp = depth·exp(-DECAY·t)·cos(FREQ·t): bắt đầu đúng độ lún hiện tại, tự vượt đà
-- qua ÂM (ô phồng cao hơn kích thước nghỉ ~45% độ lún ở nhịp đầu) rồi rung tắt dần.
local JIGGLE_FREQ = 12 -- rad/s — nhịp nảy đầu sau ~0.26s
local JIGGLE_DECAY = 3.0 -- tắt sau ~3 nhịp
local LIT_MIX = 0.32 -- độ sáng lên khi đè hết cỡ (lerp về trắng ấm)
local LIT_COLOR = Color3.fromRGB(255, 244, 214)
local WRITE_EPS = 0.006 -- ngưỡng ghi property (bài học re-batch: đuôi hồi phục ghi mỗi frame = tụt FPS)

function Clay.attach(model, engine)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }

	-- Per-model override: zone khác nhau chỉ khác ĐỘ LÚN (yêu cầu user cho Zone 14 slime —
	-- cùng cảm giác squish Zone 2, lún sâu hơn). Không set attribute thì dùng mặc định.
	local maxSquish = tonumber(model:GetAttribute("MaxSquish")) or MAX_SQUISH
	local bulge = tonumber(model:GetAttribute("Bulge")) or BULGE

	local records = {}
	local box, centerY

	task.spawn(function()
		local folder = model:WaitForChild("Tiles", 10)
		if not folder then
			return
		end
		engine.Await.childrenStable(folder)
		for _, t in folder:GetChildren() do
			if t:IsA("BasePart") then
				table.insert(records, {
					part = t,
					restPos = t.Position,
					restSize = t.Size,
					restColor = t.Color,
					bottomY = t.Position.Y - t.Size.Y / 2,
					-- Ô TO (Zone 14 dùng 4 tấm ~153×66): đo khoảng cách chân tới VÙNG THÂN ô
					-- (AABB co lại còn lõi, mép chừa 8) thay vì tới tâm — tấm to mà đo tâm thì
					-- đứng giữa tấm đã ngoài RADIUS, không bao giờ lún. Ô 8×8 → inset 0 →
					-- hành vi Y HỆT bản cũ (Zone 2 không đổi cảm giác).
					insetX = math.max((t.Size.X - 8) / 2, 0),
					insetZ = math.max((t.Size.Z - 8) / 2, 0),
					cur = 0, -- mức lún "cốt" (0..1) đang theo đuổi
					relAmp = 0, -- mức lún tại thời điểm chân rời — biên độ jiggle
					relT = 0, -- thời gian từ lúc chân rời (chạy nhịp nảy)
					lastW = -1, -- giá trị disp đã GHI lần cuối (ngưỡng WRITE_EPS)
				})
			end
		end
		local collider = model:FindFirstChild("Collider")
		if collider and collider:IsA("BasePart") then
			box = Bounds.ofBase(collider, 4)
			centerY = collider.Position.Y
		else
			box = Bounds.ofParts(folder:GetChildren(), 4)
			centerY = box and box.topY
		end
		self.ready = box ~= nil and #records > 0
		print("[ASMR Clay] sẵn sàng —", #records, "ô bo góc squishy")
	end)

	local function playSquish(parent: BasePart, volume: number, speedMin: number, speedMax: number)
		if not FxBudget.fxOK(parent.Position) then
			return
		end
		-- pitch ×0.9 + volume ×0.85: đục và êm hơn (feedback "sắc quá")
		SoundPool.playStep(
			SQUISH_SOUNDS[math.random(#SQUISH_SOUNDS)],
			parent.Position,
			volume * 0.85,
			(speedMin + math.random() * (speedMax - speedMin)) * 0.9,
			80
		)
	end

	local onFloor = false
	local stepLast, stepDist = nil, 0

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		-- vị trí chân nếu đang đứng trên sàn (giữ điều kiện Y của bản gốc: rel.Y ∈ (-1, 9))
		local footPos: Vector3? = nil
		if foot then
			local pos = foot.pos
			local relY = pos.Y - centerY
			if engine.Bounds.contains(box, pos) and relY > -1 and relY < 9 then
				footPos = pos
				if not onFloor then
					onFloor = true
					stepLast, stepDist = pos, 0
					playSquish(foot.root, 0.65, 0.75, 0.95)
				end
				if stepLast then
					local delta = pos - stepLast
					stepDist += Vector3.new(delta.X, 0, delta.Z).Magnitude
				end
				stepLast = pos
				if stepDist >= 2.2 then
					stepDist = 0
					playSquish(foot.root, 0.55, 0.8, 1.25)
				end
			else
				onFloor = false
			end
		else
			onFloor = false
		end

		local pressA = 1 - math.exp(-PRESS_RATE * dt)
		local recA = 1 - math.exp(-RECOVER_RATE * dt)
		local r2 = RADIUS * RADIUS

		for _, rec in records do
			-- target = mức lún theo khoảng cách chân tới VÙNG THÂN ô (ô 8×8: inset=0 = tới tâm)
			local target = 0
			if footPos then
				local dx = math.max(math.abs(footPos.X - rec.restPos.X) - rec.insetX, 0)
				local dz = math.max(math.abs(footPos.Z - rec.restPos.Z) - rec.insetZ, 0)
				local d2 = dx * dx + dz * dz
				if d2 < r2 then
					local w = 1 - d2 / r2
					target = w * w
				end
			end

			-- disp = mức lún hiển thị (cho phép ÂM → ô phồng vượt kích thước nghỉ = cú "bật nảy")
			local disp
			local cur = rec.cur
			if target > 0 then
				-- đang bị đè: nhún nhanh theo chân, nạp biên độ nảy cho lúc rời
				local a = if target > cur then pressA else recA
				cur += (target - cur) * a
				rec.cur = cur
				rec.relAmp = cur
				rec.relT = 0
				disp = cur
			elseif rec.relAmp > 0.02 then
				-- chân đã rời: lò xo cosine tắt dần — trồi lên, VƯỢT ĐÀ phồng cao hơn mặt
				-- nghỉ một nhịp rồi rung nhỏ dần về 0 (recA không dùng ở nhánh này).
				rec.relT += dt
				local env = rec.relAmp * math.exp(-JIGGLE_DECAY * rec.relT)
				if env < 0.006 then
					rec.relAmp = 0
					rec.cur = 0
					disp = 0
				else
					disp = env * math.cos(JIGGLE_FREQ * rec.relT)
					rec.cur = math.max(disp, 0) -- để cú đè kế tiếp blend mượt từ vị trí thật
				end
			else
				rec.cur = 0
				disp = 0
			end
			disp = math.clamp(disp, -0.2, 1)

			-- Ngưỡng ghi: đuôi hồi phục li ti mà ghi Size/Color mỗi frame là render re-batch tụt FPS.
			if math.abs(disp - rec.lastW) > WRITE_EPS or (disp == 0 and rec.lastW ~= 0) then
				rec.lastW = disp
				local sy = 1 - maxSquish * disp
				local sxz = 1 + bulge * disp
				local size = Vector3.new(rec.restSize.X * sxz, rec.restSize.Y * sy, rec.restSize.Z * sxz)
				rec.part.Size = size
				rec.part.Position = Vector3.new(rec.restPos.X, rec.bottomY + size.Y / 2, rec.restPos.Z)
				-- ô sáng lên theo mức lún rồi nguội dần — mắt bám được vệt chân
				local lit = math.clamp(disp, 0, 1) * LIT_MIX
				rec.part.Color = rec.restColor:Lerp(LIT_COLOR, lit)
			end
		end
	end

	function self.destroy() end

	return self
end

return Clay
