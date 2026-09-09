--!strict
-- SquishFloor — lõi dùng chung cho họ sàn squish thuần toán học Part.Size + Position
-- (Honeycomb / IceFracture / SlimeJelly): lún theo khoảng cách chân, phình ngang,
-- hồi phục exponential — KHÔNG EditableMesh, KHÔNG Bone, không tạo vertex mới.
--
-- Binaural "Clean Your Brain" (TikTok trend): mỗi bước dậm chân đảo pan Trái ↔ Phải
-- (sound đặt lệch sang bên tai theo RightVector của camera), pitch random 0.94–1.06.
-- Nhịp bước tỉ lệ tốc độ chạy, trần 15 bước/giây → hiệu ứng xoa màng nhĩ L-R-L-R.
--
-- Hiệu năng: chỉ tính cho LocalPlayer (foot context của engine), cull toàn sàn khi
-- camera ra ngoài 90 studs (snap mọi ô về rest đúng 1 lần rồi ngủ ~0 chi phí).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local SquishFloor = {}

local MAX_STEP_RATE = 15 -- trần bước/giây (trend chuẩn 10–15/s khi chạy nhanh)
local CULL_DIST = 90 -- bán kính camera-cull toàn sàn (studs)

function SquishFloor.make(cfg)
	local NAME = cfg.name
	local SOUND_IDS = cfg.soundIds
	local RADIUS = cfg.radius or 5.6 -- bán kính ảnh hưởng quanh chân
	-- Cỡ ô mà `radius` ở trên được tinh chỉnh cho. Nếu đặt, bán kính TỰ CO GIÃN theo cỡ ô
	-- thật: phóng to ô mà giữ bán kính cũ thì đứng giữa 2 ô là ngoài tầm → không ô nào lún
	-- (đã dính ở Zone 8/11 khi vịt 3.9 → 6.2).
	local RADIUS_REF = cfg.radiusRef
	local MAX_SQUISH = cfg.maxSquish -- lún tối đa (% chiều cao)
	local BULGE = cfg.bulge or 0 -- phình ngang khi lún
	local PRESS_RATE = cfg.pressRate or 15
	local RECOVER_RATE = cfg.recoverRate
	local STRIDE_MIN = cfg.strideMin or 2.2 -- studs/bước tối thiểu (đi bộ)
	local STRIDE_DIV = cfg.strideDiv or 13 -- bước/giây tiệm cận khi chạy nhanh
	local VOL_ENTER = cfg.volumeEnter or 0.65
	local VOL_STEP = cfg.volumeStep or 0.55
	local PITCH_MIN = cfg.pitchMin or 0.94
	local PITCH_MAX = cfg.pitchMax or 1.06
	-- Trục "cao" của ô. "X" = ép cứng (cylinder dựng đứng, trục cao = Size.X);
	-- "auto"/nil = TỰ DÒ từ ô đầu tiên (chiều mỏng nhất giữa X và Y chính là chiều cao).
	-- Auto cần thiết vì cùng một loại sàn có thể tồn tại 2 dạng hình học: Zone 8/11 đã đổi
	-- từ Part Cylinder (mỏng theo X) sang MeshPart Duck (mỏng theo Y), trong khi bản test
	-- ở lobby vẫn là cylinder — hardcode 1 trục là ép sai trục ở một trong hai.
	local HEIGHT_AXIS = cfg.heightAxis
	-- màu ô khi lún hết cỡ (Color lerp theo độ lún — 0 instance thêm); nil = giữ màu
	local LIT_COLOR = cfg.litColor
	-- rung dư chấn khi chân rời ô: {amp, freq, decay} — ô nảy sin tắt dần quanh đường hồi phục
	local JIG = cfg.jiggle

	-- ===== ĐỒNG BỘ + THEO TỐC ĐỘ (2026-08-05, tuỳ chọn) =====
	-- Cùng học thuyết đã chốt cho sàn phím: mọi ô phát ĐÚNG một tiếng như nhau (không bốc
	-- ngẫu nhiên mẫu, không rung cao độ), và chất tiếng đổi theo TỐC ĐỘ người chơi chứ
	-- không theo ô nào bị dẫm.
	--   uniformSound = true  → luôn dùng SOUND_IDS[1], bỏ random mẫu + random pitch
	--   speedMix = { volFast, pitchSlow, pitchFast } → càng nhanh càng to và càng trầm
	-- Cả hai MẶC ĐỊNH TẮT: engine này còn chạy SqueakyDuck / Orbeez, các sàn đó chưa được
	-- yêu cầu đổi nên phải giữ nguyên hành vi cũ. (Học thuyết âm 1-mẫu đã bị bác 2 lần cho
	-- sàn ASMR nói chung — ngoại lệ duy nhất còn giữ là sàn phím.)
	local UNIFORM = cfg.uniformSound == true
	local SPEED_MIX = cfg.speedMix

	local floor = {}
	floor.soundIds = SOUND_IDS
	-- Rút về 1 mẫu là số giọng thật tụt 4 lần (xem ASMR/Engine/SoundPool). Sàn nào bật
	-- uniformSound BẮT BUỘC khai `voices`, nếu không giọng bị cướp giữa chừng khi chạy nhanh.
	floor.voices = cfg.voices

	local function lerp(a, b, t)
		return a + (b - a) * t
	end

	function floor.attach(model, engine)
		local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
		local self = { ready = false }

		local records = {}
		local box, centerY
		local cullCenter, cullReach
		local HEIGHT_X = HEIGHT_AXIS == "X"
		local radius = RADIUS

		self.initTask = task.spawn(function()
			local folder = model:WaitForChild("Tiles", 10)
			if not folder then
				return
			end
			engine.Await.childrenStable(folder)
			local first = folder:FindFirstChildWhichIsA("BasePart")
			if HEIGHT_AXIS == nil or HEIGHT_AXIS == "auto" then
				HEIGHT_X = first ~= nil and first.Size.X < first.Size.Y
			end
			if RADIUS_REF and first then
				-- mặt sàn của ô = 2 chiều KHÔNG phải chiều cao
				local fp = if HEIGHT_X
					then math.max(first.Size.Y, first.Size.Z)
					else math.max(first.Size.X, first.Size.Z)
				radius = RADIUS * (fp / RADIUS_REF)
			end
			for _, t in folder:GetChildren() do
				if t:IsA("BasePart") then
					local height = if HEIGHT_X then t.Size.X else t.Size.Y
					table.insert(records, {
						part = t,
						restPos = t.Position,
						restSize = t.Size,
						restColor = t.Color,
						rot = t.CFrame.Rotation,
						bottomY = t.Position.Y - height / 2,
						cur = 0,
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
			if box then
				cullCenter = Vector3.new(box.cx, box.topY, box.cz)
				cullReach = CULL_DIST + math.max(box.halfX, box.halfZ)
			end
			self.ready = box ~= nil and #records > 0
			Log.Floor(NAME, #records, model)
		end)

		local function applyDeform(rec, v)
			local sy = 1 - MAX_SQUISH * v
			local sxz = 1 + BULGE * v
			local size, height
			if HEIGHT_X then
				size = Vector3.new(rec.restSize.X * sy, rec.restSize.Y * sxz, rec.restSize.Z * sxz)
				height = size.X
			else
				size = Vector3.new(rec.restSize.X * sxz, rec.restSize.Y * sy, rec.restSize.Z * sxz)
				height = size.Y
			end
			rec.part.Size = size
			rec.part.CFrame = CFrame.new(rec.restPos.X, rec.bottomY + height / 2, rec.restPos.Z) * rec.rot
			if LIT_COLOR then
				rec.part.Color = rec.restColor:Lerp(LIT_COLOR, v)
			end
		end

		local function resetAll()
			for _, rec in records do
				if rec.cur > 0 or rec.jamp then
					rec.cur = 0
					rec.lastW = 0
					rec.jamp = nil
					rec.peak = nil
					rec.part.Size = rec.restSize
					rec.part.CFrame = CFrame.new(rec.restPos) * rec.rot
					if LIT_COLOR then
						rec.part.Color = rec.restColor
					end
				end
			end
		end

		local onFloor = false
		local stepLast, stepDist = nil, 0
		local lastStepT = 0
		local anyActive = false

		-- Chế độ CŨ: mỗi bước rút ngẫu nhiên 1 âm trong palette trộn của sàn, pitch random.
		-- Chế độ UNIFORM: một mẫu duy nhất, cao độ do TỐC ĐỘ quyết định (xem khối cấu hình).
		-- Cả hai đều binaural đảo tai L↔R qua SoundPool.playStep.
		local function playStep(foot, now, volume)
			if now - lastStepT < 1 / MAX_STEP_RATE then
				return
			end
			lastStepT = now
			if not FxBudget.fxOK(foot.pos) then
				return
			end

			if not UNIFORM then
				SoundPool.playStep(
					SOUND_IDS[math.random(#SOUND_IDS)],
					foot.pos,
					volume,
					PITCH_MIN + math.random() * (PITCH_MAX - PITCH_MIN),
					80
				)
				return
			end

			local t = math.clamp(foot.ratio or 0, 0, 1)
			local pitch, vol = 1, volume
			if SPEED_MIX then
				pitch = lerp(SPEED_MIX.pitchSlow, SPEED_MIX.pitchFast, t)
				vol = volume * lerp(1, SPEED_MIX.volFast, t)
			end
			SoundPool.playStep(SOUND_IDS[1], foot.pos, vol, pitch, 80)
		end

		function self.update(dt, now, foot)
			if not self.ready then
				return
			end

			-- camera-cull toàn sàn: ngoài 90 studs → snap về rest 1 lần rồi ngủ
			if not FxBudget.nearCamera(cullCenter, cullReach) then
				if anyActive then
					resetAll()
					anyActive = false
				end
				onFloor = false
				return
			end

			-- vị trí chân nếu đang đứng trên sàn (điều kiện Y như Clay: rel.Y ∈ (-1, 9))
			local footPos = nil
			if foot then
				local pos = foot.pos
				local relY = pos.Y - centerY
				if engine.Bounds.contains(box, pos) and relY > -1 and relY < 9 then
					footPos = pos
					if not onFloor then
						onFloor = true
						stepLast, stepDist = pos, 0
						playStep(foot, now, VOL_ENTER)
					end
					if stepLast then
						local delta = pos - stepLast
						stepDist += Vector3.new(delta.X, 0, delta.Z).Magnitude
					end
					stepLast = pos
					-- sải chân dài ra theo tốc độ → nhịp bước tiệm cận STRIDE_DIV/giây
					local speed = Vector3.new(foot.vel.X, 0, foot.vel.Z).Magnitude
					local stride = math.max(STRIDE_MIN, speed / STRIDE_DIV)
					if stepDist >= stride then
						stepDist = 0
						playStep(foot, now, VOL_STEP)
					end
				else
					onFloor = false
				end
			else
				onFloor = false
			end

			local pressA = 1 - math.exp(-PRESS_RATE * dt)
			local recA = 1 - math.exp(-RECOVER_RATE * dt)
			local r2 = radius * radius
			local active = false

			for _, rec in records do
				local target = 0
				if footPos then
					local dx = footPos.X - rec.restPos.X
					local dz = footPos.Z - rec.restPos.Z
					local d2 = dx * dx + dz * dz
					if d2 < r2 then
						local w = 1 - d2 / r2
						target = w * w
					end
				end
				local cur = rec.cur
				if target ~= cur or cur > 0.001 or rec.jamp then
					local a = if target > cur then pressA else recA
					local new = cur + (target - cur) * a
					-- snap sớm 0.03 (lún <3% mắt không thấy) — cắt đuôi hồi phục dài
					if new < 0.03 and target == 0 then
						new = 0
					end
					rec.cur = new
					local disp = new
					-- jiggle: nhớ đỉnh lún khi nhấn, chân rời → rung sin tắt dần quanh hồi phục
					if JIG then
						if target > 0 then
							if new > (rec.peak or 0) then
								rec.peak = new
							end
						elseif rec.peak and rec.peak > 0.08 then
							rec.jt = 0
							rec.jamp = rec.peak * JIG.amp
							rec.peak = nil
						end
						local jamp = rec.jamp
						if jamp then
							rec.jt += dt
							local env = jamp * math.exp(-JIG.decay * rec.jt)
							if env < 0.012 then
								rec.jamp = nil
							else
								disp = math.clamp(new + env * math.sin(JIG.freq * rec.jt), 0, 1)
							end
						end
					end
					-- chỉ ghi Size/CFrame khi thay đổi đủ lớn (~7mm): ghi part mỗi frame
					-- là chi phí render re-batch — thủ phạm tụt FPS đo được ở boss arena
					local lw = rec.lastW or -1
					if disp ~= lw and (disp == 0 or math.abs(disp - lw) > 0.008) then
						rec.lastW = disp
						applyDeform(rec, disp)
					end
					if new > 0 or rec.jamp then
						active = true
					end
				end
			end
			anyActive = active
		end

		function self.destroy()
			self.ready = false
			engine.Await.cancel(self.initTask)
			resetAll()
			table.clear(records)
		end

		return self
	end

	return floor
end

return SquishFloor
