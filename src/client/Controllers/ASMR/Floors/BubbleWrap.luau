-- BubbleWrap — port nguyên vẹn BubbleWrapClient v2: bóng nổ LÌ (bẹp + mờ), VFX khí trắng
-- + tia lấp lánh (giờ qua ParticlePool thay emitter lazy-create per-bóng), crinkle theo bước,
-- hết bóng/15s -> sóng tái phồng chạy từng hàng.

local TweenService = game:GetService("TweenService")

local BubbleWrap = {}

-- Mix ASMR: pop/suction/pacifier + 2 Mouth Pop PSE mới (đa chất liệu phê tai)
local POP_SOUNDS = { 9117848644, 9119669295, 9117183955, 9117019901, 9117020299 }
local CRINKLE = 9125723913
BubbleWrap.soundIds = { 9117848644, 9119669295, 9117183955, 9117019901, 9117020299, CRINKLE }

local FOOT_DROP = 3.2
-- Bán kính pop PHẢI theo cỡ bóng, không hardcode: Zone 3 đã đổi bóng 3.1→5 (pitch
-- 3.9→5.8) nên bán kính cũ 2.1 để hụt — đứng giữa 4 bóng thì không bóng nào nổ.
-- 0.82×cỡ ≈ nửa đường chéo ô ⇒ mọi vị trí chân luôn nổ ít nhất 1 bóng.
local POP_R_FACTOR = 0.82
local POP_R_MIN = 2.1

local POP_TI = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local INFLATE_TI = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function BubbleWrap.attach(model, engine)
	local FxBudget, SoundPool, ParticlePool, Bounds = engine.FxBudget, engine.SoundPool, engine.ParticlePool, engine.Bounds
	local self = { ready = false }
	-- Bản zone không có Base → box.topY = đỉnh bóng, cần tolerance rộng hơn (builder set YTol=4.2)
	local Y_TOL = model:GetAttribute("YTol") or 2.6

	local bubbles = {}
	local box
	local popR2 = POP_R_MIN * POP_R_MIN
	local poppedCount = 0
	local firstPopAt = nil
	local resetting = false

	task.spawn(function()
		local folder = model:WaitForChild("Bubbles", 10)
		if not folder then
			return
		end
		engine.Await.childrenStable(folder)
		for _, d in folder:GetChildren() do
			if d:IsA("BasePart") then
				table.insert(bubbles, {
					part = d,
					mesh = d:FindFirstChildOfClass("SpecialMesh"),
					restPos = d.Position,
					restColor = d.Color,
					restTransp = d.Transparency,
					popped = false,
				})
			end
		end
		table.sort(bubbles, function(a, b)
			if a.restPos.Z == b.restPos.Z then
				return a.restPos.X < b.restPos.X
			end
			return a.restPos.Z < b.restPos.Z
		end)
		local base = model:FindFirstChild("Base")
		box = if base and base:IsA("BasePart") then Bounds.ofBase(base, 2) else Bounds.ofParts(folder:GetChildren(), 2)
		if bubbles[1] then
			local r = math.max(POP_R_MIN, bubbles[1].part.Size.X * POP_R_FACTOR)
			popR2 = r * r
		end
		self.ready = box ~= nil and #bubbles > 0
		print("[ASMR BubbleWrap] sẵn sàng —", #bubbles, "bóng khí + pop VFX")
	end)

	local function sound(parent, id, vol, spMin, spMax)
		if not FxBudget.fxOK(parent.Position) then
			return
		end
		SoundPool.playStep(id, parent.Position, vol, spMin + math.random() * (spMax - spMin), 80)
	end

	local function popBubble(b)
		b.popped = true
		poppedCount += 1
		firstPopAt = firstPopAt or os.clock()
		local top = b.restPos + Vector3.new(0, b.part.Size.Y / 2, 0)
		ParticlePool.emit("puff", top, 5)
		ParticlePool.emit("sparks", top, 9)
		TweenService:Create(b.part, POP_TI, {
			Position = b.restPos - Vector3.new(0, 0.75, 0),
			Transparency = 0.72,
			Color = Color3.fromRGB(210, 214, 222),
		}):Play()
		if b.mesh then
			TweenService:Create(b.mesh, POP_TI, { Scale = Vector3.new(1.06, 0.1, 1.06) }):Play()
		end
		sound(b.part, POP_SOUNDS[math.random(#POP_SOUNDS)], 0.42, 1.2, 1.6)
	end

	local function resetWave()
		resetting = true
		task.spawn(function()
			for i, b in bubbles do
				if b.popped then
					b.popped = false
					TweenService:Create(b.part, INFLATE_TI, {
						Position = b.restPos,
						Transparency = b.restTransp,
						Color = b.restColor,
					}):Play()
					if b.mesh then
						TweenService:Create(b.mesh, INFLATE_TI, { Scale = Vector3.one }):Play()
					end
					ParticlePool.emit("puff", b.restPos, 2)
					if i % 3 == 0 then
						sound(b.part, POP_SOUNDS[math.random(#POP_SOUNDS)], 0.12, 0.6, 0.75)
					end
					if i % 9 == 0 then
						task.wait(0.05)
					end
				end
			end
			poppedCount = 0
			firstPopAt = nil
			resetting = false
		end)
	end

	local stepDist = 0
	local stepLast = nil

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end
		if foot then
			local pos = foot.pos
			if
				engine.Bounds.contains(box, pos)
				and math.abs((pos.Y - FOOT_DROP) - box.topY) <= Y_TOL
			then
				if not resetting then
					for _, b in bubbles do
						if not b.popped then
							local dx = b.restPos.X - pos.X
							local dz = b.restPos.Z - pos.Z
							if dx * dx + dz * dz <= popR2 then
								popBubble(b)
							end
						end
					end
				end
				if stepLast then
					local delta = pos - stepLast
					stepDist += Vector3.new(delta.X, 0, delta.Z).Magnitude
				end
				stepLast = pos
				if stepDist >= 2.6 then
					stepDist = 0
					sound(foot.root, CRINKLE, 0.16, 1.1, 1.45)
				end
			else
				stepLast = nil
				stepDist = 0
			end
		else
			stepLast = nil
			stepDist = 0
		end
		if not resetting and (poppedCount >= #bubbles or (firstPopAt and os.clock() - firstPopAt > 15 and poppedCount > 0)) then
			resetWave()
		end
	end

	function self.destroy() end

	return self
end

return BubbleWrap
