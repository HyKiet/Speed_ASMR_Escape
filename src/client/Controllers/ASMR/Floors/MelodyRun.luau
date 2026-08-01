-- MelodyRun — port nguyên vẹn MelodyRunClient: ô đèn NGŨ CUNG, bước vào -> sáng Neon
-- + note piano pitch-shift 2^(semi/12); tốc độ cao -> swept + stagger 25ms = glissando.
-- PointLight lazy-create per ô giữ nguyên (≤64 ô, Brightness=0 khi tắt).

local MelodyRun = {}

local NOTE_ID = 121997668450827 -- ASMR_PianoNote có sẵn của project
MelodyRun.soundIds = { NOTE_ID }

local PENTA = { 0, 2, 4, 7, 9 }
local CELL = 4.5
local FOOT_DROP = 3.2
local Y_TOL = 2.8
local MAX_NOTES_PER_FRAME = 8

function MelodyRun.attach(model, engine)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }

	local records = {}
	local grid
	local box, topY
	local glowing = {} -- set các rec đang sáng

	task.spawn(function()
		local folder = model:WaitForChild("Tiles", 10)
		if not folder then
			return
		end
		engine.Await.childrenStable(folder)
		grid = engine.SpatialGrid.new(CELL)
		for _, t in folder:GetChildren() do
			if t:IsA("BasePart") then
				local col = t:GetAttribute("Col") or 1
				local hue = t:GetAttribute("Hue") or 0
				local semi = PENTA[(col - 1) % 5 + 1] + 12 * math.floor((col - 1) / 5)
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
		print("[ASMR MelodyRun] sẵn sàng —", #records, "ô ngũ cung glissando")
	end)

	local function tileAt(px, pz)
		local bucket = grid:bucketAt(px, pz)
		if not bucket then
			return nil
		end
		local best, bd
		for _, rec in bucket do
			local dx = math.abs(px - rec.part.Position.X)
			local dz = math.abs(pz - rec.part.Position.Z)
			if dx <= 2.3 and dz <= 2.3 then
				local d = dx * dx + dz * dz
				if not bd or d < bd then
					bd, best = d, rec
				end
			end
		end
		return best
	end

	local function playNote(rec, ratio, delaySec)
		task.delay(delaySec or 0, function()
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
				l.Range = 9
				l.Brightness = 0
				l.Parent = rec.part
				rec.light = l
			end
			rec.light.Brightness = 3.5
			-- note pitch ngũ cung
			SoundPool.playStep(
				NOTE_ID,
				rec.part.Position,
				0.22 + ratio * 0.13,
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

			-- swept glissando: kích hoạt các ô dọc đường chạy giữa 2 frame
			if onFloor and lastPos then
				local delta = pos - lastPos
				local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if dist > 3 and dist < 120 then
					local hit, order = {}, {}
					local steps = math.min(math.floor(dist / 2), 24)
					for i = 1, steps do
						local sp = lastPos:Lerp(pos, i / (steps + 1))
						local r = tileAt(sp.X, sp.Z)
						if r and not hit[r] and r ~= rec then
							hit[r] = true
							table.insert(order, r)
						end
					end
					for i, r in order do
						if i > MAX_NOTES_PER_FRAME then
							break
						end
						playNote(r, ratio, (i - 1) * 0.025) -- stagger 25ms = glissando
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
