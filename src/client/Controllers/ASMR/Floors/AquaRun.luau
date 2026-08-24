--!strict
-- AquaRun — port nguyên vẹn AquaRunClient: splash pitch/volume theo VẬN TỐC THẬT,
-- vòng sóng lan (animate thủ công) + giọt nước bắn.
-- Nâng cấp so bản cũ: vòng sóng dùng POOL 40 part tái sử dụng (không Instance.new/Destroy
-- mỗi splash), giọt nước qua ParticlePool preset "droplets".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local AquaRun = {}

-- Mix ASMR: 5 splash vũng nước + bubble bloop + wood bowl blip (đa chất liệu phê tai)
local SPLASH_SOUNDS = { 9117941991, 9117940312, 9117942473, 9117940443, 9119293555, 9112751536, 9120519525 }
AquaRun.soundIds = SPLASH_SOUNDS

local RIPPLE_N = 40
local RIPPLE_LIFE = 0.7
local FOOT_DROP = 3.2
local Y_TOL = 2.6

function AquaRun.attach(model, engine)
	local FxBudget, SoundPool, ParticlePool, Bounds =
		engine.FxBudget, engine.SoundPool, engine.ParticlePool, engine.Bounds
	local self = { ready = false }

	local box, waterY
	local ripples = table.create(RIPPLE_N) -- pool: {part, t, grow}; t >= RIPPLE_LIFE = rảnh
	local rippleIdx = 0
	local anyRippleActive = false

	task.spawn(function()
		local basin = model:WaitForChild("Basin", 10)
		local surface = model:WaitForChild("WaterSurface", 10)
		if not (basin and surface) then
			return
		end
		box = Bounds.ofBase(basin, 2)
		waterY = surface.Position.Y + surface.Size.Y / 2
		for i = 1, RIPPLE_N do
			local r = Instance.new("Part")
			r.Name = "Ripple"
			r.Shape = Enum.PartType.Cylinder
			r.Size = Vector3.new(0.1, 1.4, 1.4)
			r.Color = Color3.fromRGB(215, 245, 255)
			r.Material = Enum.Material.Glass
			r.Transparency = 1
			r.Anchored = true
			r.CanCollide = false
			r.CanTouch = false
			r.CanQuery = false
			r.CastShadow = false
			r.CFrame = CFrame.new(0, -500, 0)
			r.Parent = model
			ripples[i] = { part = r, t = RIPPLE_LIFE, grow = 0 }
		end
		self.ready = true
		Log.Floor("AquaRun", RIPPLE_N, model)
	end)

	local function splashSound(parent, ratio)
		if not FxBudget.fxOK(parent.Position) then
			return
		end
		SoundPool.playStep(
			SPLASH_SOUNDS[math.random(#SPLASH_SOUNDS)],
			parent.Position,
			0.35 + ratio * 0.4,
			0.9 + ratio * 0.4 + (math.random() * 0.12 - 0.06),
			90
		)
	end

	local function spawnRipple(pos, ratio)
		if not FxBudget.nearCamera(pos, 140) then
			return
		end
		rippleIdx = rippleIdx % RIPPLE_N + 1
		local rp = ripples[rippleIdx]
		rp.t = 0
		rp.grow = 7 + ratio * 9
		rp.part.CFrame = CFrame.new(pos.X, waterY + 0.06, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		rp.part.Size = Vector3.new(0.1, 1.4, 1.4)
		rp.part.Transparency = 0.35
		anyRippleActive = true
	end

	local function spawnDroplets(pos, ratio)
		if not FxBudget.nearCamera(pos, 110) then
			return
		end
		ParticlePool.emit("droplets", Vector3.new(pos.X, waterY + 0.3, pos.Z), 5 + math.floor(ratio * 7))
	end

	local onFloorState = nil

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		if foot then
			local pos = foot.pos
			if not engine.Bounds.contains(box, pos) or math.abs((pos.Y - FOOT_DROP) - box.topY) > Y_TOL then
				onFloorState = nil
			else
				local ratio = foot.ratio
				local st = onFloorState
				if not st then
					st = { lastPos = pos, dist = 0, cooldown = 0 }
					onFloorState = st
					-- tiếng "lội xuống nước" đầu tiên
					splashSound(foot.root, math.max(ratio, 0.4))
					spawnRipple(pos, 0.6)
					spawnDroplets(pos, 0.6)
				end
				st.cooldown = math.max(0, st.cooldown - dt)
				local delta = pos - st.lastPos
				st.lastPos = pos
				st.dist += Vector3.new(delta.X, 0, delta.Z).Magnitude
				if st.dist >= 2.0 and st.cooldown <= 0 then
					st.dist = 0
					st.cooldown = 0.08 -- không quá ~12 splash/s dù tốc độ khủng
					splashSound(foot.root, ratio)
					spawnRipple(pos, ratio)
					spawnDroplets(pos, ratio)
				end
			end
		else
			onFloorState = nil
		end

		-- animate vòng sóng (thủ công, trên pool)
		if anyRippleActive then
			local stillActive = false
			for _, rp in ripples do
				if rp.t < RIPPLE_LIFE then
					rp.t += dt
					if rp.t >= RIPPLE_LIFE then
						rp.part.Transparency = 1
						rp.part.CFrame = CFrame.new(0, -500, 0)
					else
						stillActive = true
						local d = 1.4 + rp.grow * rp.t
						rp.part.Size = Vector3.new(0.1, d, d)
						rp.part.Transparency = 0.35 + 0.65 * (rp.t / RIPPLE_LIFE)
					end
				end
			end
			anyRippleActive = stillActive
		end
	end

	function self.destroy() end

	return self
end

return AquaRun
