--!strict
-- KineticSandLive — port CRATER v3 (Lobby.ASMR.Live full-floor 5180 ô) sang engine ASMR chung.
-- Giữ NGUYÊN chức năng bản KineticSandClient v3:
--   • Vết CRATER: tâm lún + viền phồng (RIM), sẫm màu cát ướt.
--   • Đi bộ vết chân so le trái/phải; chạy nhanh rãnh liền; đứng yên vẫn hằn vết (idle).
--   • Cao độ chân theo Humanoid.HipHeight (đúng mọi avatar cao/thấp).
-- Khác v3 ở HẠ TẦNG (nhẹ hơn, hết lag): dùng SpatialGrid O(1) thay vì tự băm chuỗi,
--   SoundPool/ParticlePool/FxBudget dùng chung (0 Instance churn), và chạy trong MỘT Heartbeat
--   duy nhất của engine thay vì một vòng lặp riêng cho 5180 ô.
--
-- vì sao đây là bản riêng chứ không tái dùng KineticSand.luau: sàn 144-ô ASMR_Test dùng bản
-- lún phẳng đơn giản; sàn Live cần crater+rim+so le nên tách module để không đổi sàn kia.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundIds = require(ReplicatedStorage.Shared.Config.SoundIds)

local KineticSandLive = {}

-- ⚠️ Âm cát lấy từ `Config.SoundIds` — dùng chung với `KineticSand`. Xem lý do ở đó.
local CRUNCH = SoundIds.SAND_CRUNCH
local DIRT = SoundIds.SAND_DIRT
KineticSandLive.soundIds = { CRUNCH[1], CRUNCH[2], CRUNCH[3], CRUNCH[4], DIRT }

local CELL = 3
local DEPTH = 0.5
local RIM = 0.13
local RIM_END = 0.28
local PRESS_RATE = 26
local RISE_RATE = 0.85
local HOLD_MIN, HOLD_MAX = 3.5, 6
local MAX_ACTIVE = 1500
local ANIM_HZ = 1 / 30 -- máy yếu: animate 30fps là đủ mượt
local WET = Color3.fromRGB(176, 148, 104)

-- Hình dạng crater theo độ sâu chuẩn hoá d (0..1): trả về (offsetY, wetRatio).
-- d nhỏ = phần viền phồng lên (RIM), d lớn = lòng chảo lún xuống (−DEPTH).
local function shape(d: number): (number, number)
	if d <= RIM_END then
		return RIM * (d / RIM_END), 0
	end
	local s = (d - RIM_END) / (1 - RIM_END)
	return RIM - (RIM + DEPTH) * s, s
end

function KineticSandLive.attach(model, engine)
	local FxBudget, SoundPool, ParticlePool, Bounds =
		engine.FxBudget, engine.SoundPool, engine.ParticlePool, engine.Bounds
	local self = { ready = false }

	local grid
	local box, surfY
	local active = {}
	local numActive = 0

	task.spawn(function()
		local folder = model:WaitForChild("Tiles", 10)
		if not folder then
			return
		end
		engine.Await.childrenStable(folder)

		grid = engine.SpatialGrid.new(CELL)
		local n = 0
		for _, t in folder:GetChildren() do
			if t:IsA("BasePart") then
				n += 1
				grid:insert(t.Position.X, t.Position.Z, {
					part = t,
					restPos = t.Position,
					dry = t.Color,
					depth = 0,
					amp = 0,
					holdUntil = 0,
				})
			end
		end

		local tray = model:FindFirstChild("Tray")
		box = if tray and tray:IsA("BasePart") then Bounds.ofBase(tray, 2) else Bounds.ofParts(folder:GetChildren(), 2)
		-- Không Tray mà folder cũng rỗng (streaming đưa Model tới trước con của nó) thì
		-- Bounds.ofParts trả nil → `box.topY` ném lỗi, adapter chết giữa chừng và sàn câm luôn.
		if tray and tray:IsA("BasePart") then
			surfY = tray.Position.Y + tray.Size.Y / 2 + 0.6
		elseif box then
			surfY = box.topY
		else
			return -- watchdog engine sẽ attach lại khi tile đã tới
		end
		self.ready = box ~= nil and n > 0
		print("[ASMR KineticSandLive] sẵn sàng —", n, "ô cát | crater+rim | engine chung")
	end)

	local function crunch(root, ratio)
		if not FxBudget.fxOK(root.Position) then
			return
		end
		local id = math.random() < 0.25 and DIRT or CRUNCH[math.random(#CRUNCH)]
		SoundPool.playStep(id, root.Position, 0.4 + ratio * 0.3, 0.9 + ratio * 0.3 + (math.random() * 0.14 - 0.07), 70)
	end

	-- Đóng dấu crater bán kính R quanh (px,pz): mỗi ô trong tầm nhận biên độ amp theo khoảng cách.
	local function stampCrater(px: number, pz: number, now: number, speedRatio: number)
		local R = 4.2 - 2.0 * math.clamp(speedRatio, 0, 1)
		grid:query(px, pz, 2, function(rec)
			local dx, dz = rec.restPos.X - px, rec.restPos.Z - pz
			local f = 1 - math.sqrt(dx * dx + dz * dz) / R
			if f > 0.03 then
				local amp = f ^ 0.75
				if amp > rec.amp then
					rec.amp = amp
				end
				local hu = now + HOLD_MIN + math.random() * (HOLD_MAX - HOLD_MIN)
				if hu > rec.holdUntil then
					rec.holdUntil = hu
				end
				if not active[rec] and numActive < MAX_ACTIVE then
					active[rec] = true
					numActive += 1
				end
			end
		end)
	end

	local st = nil -- trạng thái bước chân: { dist, last, cd, side, idle }
	local lastPos = nil
	local animAcc = 0

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		-- ===== stamp theo chân người chơi =====
		local onFloor = false
		if foot then
			local root = foot.root
			local pos = foot.pos
			-- Cao độ CHÂN theo avatar thật (HipHeight); R6 HipHeight=0 → fallback 3.0.
			local hum = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
			local hip = hum and hum.HipHeight or 0
			local feetOffset = hip > 0 and (hip + root.Size.Y * 0.5) or 3.0
			local feetY = pos.Y - feetOffset

			if engine.Bounds.contains(box, pos) and math.abs(feetY - surfY) <= 3 then
				onFloor = true
				local ratio = foot.ratio
				local vel = foot.vel
				local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude

				if not st then
					st = { dist = 0, last = pos, cd = 0, side = 1, idle = 0 }
					stampCrater(pos.X, pos.Z, now, ratio)
					crunch(root, math.max(ratio, 0.3))
				end

				-- swept: chạy nhanh vẫn hằn rãnh liền, không đứt quãng
				if lastPos and speed > 26 then
					local delta = pos - lastPos
					local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
					if dist > 1.5 and dist < 120 then
						local steps = math.min(math.floor(dist / 2), 20)
						for i = 1, steps do
							local sp = lastPos:Lerp(pos, i / (steps + 1))
							stampCrater(sp.X, sp.Z, now, ratio)
						end
					end
				end
				lastPos = pos

				-- đứng yên vẫn để lại dấu chân
				st.idle -= dt
				if speed <= 0.5 and st.idle <= 0 then
					st.idle = 0.8
					stampCrater(pos.X, pos.Z, now, 0)
				end

				st.cd = math.max(0, st.cd - dt)
				local d = pos - st.last
				st.last = pos
				st.dist += Vector3.new(d.X, 0, d.Z).Magnitude
				if st.dist >= 2.0 and st.cd <= 0 then
					st.dist = 0
					st.cd = 0.09
					if speed > 0.5 and speed <= 26 then
						-- đi bộ: đặt vết so le sang trái/phải theo hướng đi
						st.side = -st.side
						local dir = Vector3.new(vel.X, 0, vel.Z)
						local rightV = dir.Unit:Cross(Vector3.yAxis)
						local fp = pos + rightV * (0.8 * st.side)
						stampCrater(fp.X, fp.Z, now, 0)
					else
						stampCrater(pos.X, pos.Z, now, ratio)
					end
					crunch(root, ratio)
					if FxBudget.fxOK(pos, 100) then
						ParticlePool.emit("dust", Vector3.new(pos.X, surfY + 0.2, pos.Z), 3 + math.floor(ratio * 5))
					end
				end
			end
		end

		if not onFloor then
			st = nil
			lastPos = nil
		end

		-- ===== animate CHỈ ô active, throttle 30Hz =====
		animAcc += dt
		if animAcc < ANIM_HZ then
			return
		end
		local stepDt = animAcc
		animAcc = 0
		local pressA = 1 - math.exp(-PRESS_RATE * stepDt)
		local riseA = 1 - math.exp(-RISE_RATE * stepDt)
		for rec in active do
			local target = now < rec.holdUntil and rec.amp or 0
			local a = target > rec.depth and pressA or riseA
			local nd = rec.depth + (target - rec.depth) * a
			if target == 0 and nd < 0.01 then
				rec.depth = 0
				rec.amp = 0
				rec.part.Position = rec.restPos
				rec.part.Color = rec.dry
				active[rec] = nil
				numActive -= 1
			else
				rec.depth = nd
				local off, wet = shape(nd)
				rec.part.Position = rec.restPos + Vector3.new(0, off, 0)
				rec.part.Color = rec.dry:Lerp(WET, wet * 0.85)
			end
		end
	end

	function self.destroy() end

	return self
end

return KineticSandLive
