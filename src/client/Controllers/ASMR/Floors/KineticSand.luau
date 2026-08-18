--!strict
-- KineticSand — port nguyên vẹn KineticSandClient (bản ASMR_Test): vết chân khắc vào cát
-- (lún 0.42 + sẫm màu cát nén), giữ 3.5–6s rồi đầy lại; swept stamping; crunch + bụi cát.
-- Bụi qua ParticlePool preset "dust" (bản cũ đã dùng 1 emitter chung — giữ nguyên hành vi).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundIds = require(ReplicatedStorage.Shared.Config.SoundIds)

local KineticSand = {}

-- ⚠️ Âm cát lấy từ `Config.SoundIds` — dùng chung với `KineticSandLive`. Xem lý do ở đó.
local CRUNCH = SoundIds.SAND_CRUNCH
local DIRT = SoundIds.SAND_DIRT
KineticSand.soundIds = { CRUNCH[1], CRUNCH[2], CRUNCH[3], CRUNCH[4], DIRT }

local CELL = 3
local DEPTH = 0.42
local PRESS_RATE = 22
local RISE_RATE = 0.9
local HOLD_MIN, HOLD_MAX = 3.5, 6
local WET = Color3.fromRGB(176, 148, 104) -- màu cát bị nén
local FOOT_DROP = 3.2
local Y_TOL = 2.8

function KineticSand.attach(model, engine)
	local FxBudget, SoundPool, ParticlePool, Bounds =
		engine.FxBudget, engine.SoundPool, engine.ParticlePool, engine.Bounds
	local self = { ready = false }

	local grid
	local box, surfY
	local active = {}

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
					holdUntil = 0,
				})
			end
		end
		local tray = model:FindFirstChild("Tray")
		box = if tray and tray:IsA("BasePart") then Bounds.ofBase(tray, 2) else Bounds.ofParts(folder:GetChildren(), 2)
		-- Bounds.ofParts trả nil khi Tiles rỗng → phải chốt `ready` TRƯỚC khi đọc box.topY,
		-- nếu không sàn rỗng sẽ ném "attempt to index nil with 'topY'" lúc nạp.
		self.ready = box ~= nil and n > 0
		if not self.ready then
			return
		end
		surfY = if tray and tray:IsA("BasePart") then tray.Position.Y + tray.Size.Y / 2 + 0.6 else box.topY
		print("[ASMR KineticSand] sẵn sàng —", n, "ô cát, footprint memory")
	end)

	local function crunch(parent, ratio)
		if not FxBudget.fxOK(parent.Position) then
			return
		end
		local id = math.random() < 0.25 and DIRT or CRUNCH[math.random(#CRUNCH)]
		SoundPool.playStep(
			id,
			parent.Position,
			0.4 + ratio * 0.3,
			0.9 + ratio * 0.3 + (math.random() * 0.14 - 0.07),
			70
		)
	end

	local function stampAt(px, pz, now)
		local bucket = grid:bucketAt(px, pz)
		if not bucket then
			return
		end
		for _, rec in bucket do
			if math.abs(px - rec.restPos.X) <= 2 and math.abs(pz - rec.restPos.Z) <= 2 then
				rec.holdUntil = now + HOLD_MIN + math.random() * (HOLD_MAX - HOLD_MIN)
				active[rec] = true
			end
		end
	end

	local onFloorState = nil -- {dist, cd} khi đang trên sàn
	local lastPos = nil

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		if foot then
			local pos = foot.pos
			if not engine.Bounds.contains(box, pos) or math.abs((pos.Y - FOOT_DROP) - surfY) > Y_TOL then
				onFloorState = nil
				lastPos = nil
			else
				stampAt(pos.X, pos.Z, now)
				-- swept: vết chân liên tục cả khi phóng nhanh
				if lastPos then
					local delta = pos - lastPos
					local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
					if dist > 1.5 and dist < 120 then
						local steps = math.min(math.floor(dist / 1.5), 30)
						for i = 1, steps do
							local sp = lastPos:Lerp(pos, i / (steps + 1))
							stampAt(sp.X, sp.Z, now)
						end
					end
				end
				lastPos = pos

				local ratio = foot.ratio
				local st = onFloorState
				if not st then
					st = { dist = 0, last = pos, cd = 0 }
					onFloorState = st
					crunch(foot.root, math.max(ratio, 0.3))
				end
				st.cd = math.max(0, st.cd - dt)
				local d = pos - st.last
				st.last = pos
				st.dist += Vector3.new(d.X, 0, d.Z).Magnitude
				if st.dist >= 2.0 and st.cd <= 0 then
					st.dist = 0
					st.cd = 0.09
					crunch(foot.root, ratio)
					if FxBudget.fxOK(pos, 100) then
						ParticlePool.emit("dust", Vector3.new(pos.X, surfY + 0.2, pos.Z), 3 + math.floor(ratio * 4))
					end
				end
			end
		else
			onFloorState = nil
			lastPos = nil
		end

		-- animate CHỈ các ô active
		local pressA = 1 - math.exp(-PRESS_RATE * dt)
		local riseA = 1 - math.exp(-RISE_RATE * dt)
		for rec in active do
			local target = now < rec.holdUntil and 1 or 0
			local a = target > rec.depth and pressA or riseA
			local nd = rec.depth + (target - rec.depth) * a
			if target == 0 and nd < 0.01 then
				rec.depth = 0
				rec.part.Position = rec.restPos
				rec.part.Color = rec.dry
				active[rec] = nil
			else
				rec.depth = nd
				rec.part.Position = rec.restPos - Vector3.new(0, DEPTH * nd, 0)
				rec.part.Color = rec.dry:Lerp(WET, nd * 0.85)
			end
		end
	end

	function self.destroy() end

	return self
end

return KineticSand
