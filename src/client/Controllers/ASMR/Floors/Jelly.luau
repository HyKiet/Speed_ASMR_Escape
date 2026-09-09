--!strict
-- Jelly — port nguyên vẹn JellyClient: khối thạch wobble lò xo tắt dần exp(-2.6t)·sin(13t),
-- nghiêng ngẫu nhiên, tiếng wobble board. Nhảy lên = rung mạnh, đi bộ = rung nhẹ liên tục.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Jelly = {}

-- Mix ASMR: 4 wobble board + slime ướt + mouth pop (đa chất liệu phê tai)
local WOBBLE_SOUNDS = { 9120783061, 9120784332, 9120784967, 9120783925, 76169806288463, 9117019903 }
Jelly.soundIds = WOBBLE_SOUNDS

local FOOT_DROP = 3.2

function Jelly.attach(model: Model, engine: any)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }
	-- bản zone không có Collider, box tính từ ĐỈNH block (cao 3.6) → cần tolerance rộng hơn.
	-- Builder set attribute YTol=5.5 (bài học zone v2: patch 3→5.5)
	local Y_TOL = (model:GetAttribute("YTol") or 3) :: number

	local blocks = {}
	local box

	self.initTask = task.spawn(function()
		local folder = model:WaitForChild("Blocks", 10)
		if not folder then
			return
		end
		engine.Await.childrenStable(folder)
		for _, b in folder:GetChildren() do
			if b:IsA("BasePart") then
				table.insert(blocks, {
					part = b,
					restPos = b.Position,
					restCFrame = b.CFrame,
					restSize = b.Size,
					bottomY = b.Position.Y - b.Size.Y / 2,
					amp = 0,
					t = 0,
					axis = Vector3.xAxis,
				})
			end
		end
		local collider = model:FindFirstChild("Collider")
		box = if collider and collider:IsA("BasePart")
			then Bounds.ofBase(collider, 2)
			else Bounds.ofParts(folder:GetChildren(), 2)
		self.ready = box ~= nil and #blocks > 0
		Log.Floor("Jelly", #blocks, model)
	end)

	local function playWobble(parent, vol, spMin, spMax)
		if not FxBudget.fxOK(parent.Position) then
			return
		end
		SoundPool.playStep(
			WOBBLE_SOUNDS[math.random(#WOBBLE_SOUNDS)],
			parent.Position,
			vol,
			spMin + math.random() * (spMax - spMin),
			90
		)
	end

	local function impulse(rec, strength, loud)
		rec.amp = math.min(rec.amp * math.exp(-2.6 * rec.t) + strength, 1.25)
		rec.t = 0
		local ang = math.random() * math.pi * 2
		rec.axis = Vector3.new(math.cos(ang), 0, math.sin(ang))
		if loud then
			playWobble(rec.part, 0.35 + 0.35 * math.min(strength, 1), 0.9, 1.2)
		end
	end

	local function nearestBlock(pos)
		local best, bd = nil, 1e9
		for _, rec in blocks do
			local dx = math.abs(pos.X - rec.restPos.X)
			local dz = math.abs(pos.Z - rec.restPos.Z)
			-- Tầm chạm giãn theo cỡ khối (bài học BubbleWrap POP_R2 / Keyboard reach):
			-- khối Zone 14 rộng 18–34 studs, giữ 6.8 cứng thì đứng giữa khối to là ngoài tầm
			-- → không bao giờ wobble. 6.8 vẫn là sàn dưới cho khối nhỏ 11×11 cũ.
			local rx = math.max(6.8, rec.restSize.X * 0.62)
			local rz = math.max(6.8, rec.restSize.Z * 0.62)
			if dx <= rx and dz <= rz then
				local d = dx * dx + dz * dz
				if d < bd then
					best, bd = rec, d
				end
			end
		end
		return best
	end

	local contact = nil
	local stepLast, stepDist = nil, 0

	function self.update(dt, _now, foot)
		if not self.ready then
			return
		end

		local rec = nil
		if foot then
			local pos: Vector3 = foot.pos
			if engine.Bounds.contains(box, pos) and math.abs((pos.Y - FOOT_DROP) - box.topY) < Y_TOL then
				rec = nearestBlock(pos)
			end
		end
		if rec ~= contact then
			if rec and foot then
				-- vừa đáp xuống khối mới: lực theo tốc độ rơi
				local vy = math.abs(foot.vel.Y)
				impulse(rec, math.clamp(0.45 + vy / 90, 0.45, 1.1), true)
				stepLast, stepDist = foot.pos, 0
			end
			contact = rec
		elseif rec and foot then
			if stepLast then
				local delta = foot.pos - stepLast
				stepDist += Vector3.new(delta.X, 0, delta.Z).Magnitude
			end
			stepLast = foot.pos
			if stepDist >= 2.6 then
				stepDist = 0
				impulse(rec, 0.22, math.random() < 0.5)
			end
		end

		for _, b in blocks do
			if b.amp > 0.008 then
				b.t += dt
				local decay = math.exp(-2.6 * b.t)
				local osc = b.amp * decay * math.sin(13 * b.t)
				local sy = 1 + 0.15 * osc
				local sxz = 1 - 0.09 * osc
				local size = Vector3.new(b.restSize.X * sxz, b.restSize.Y * sy, b.restSize.Z * sxz)
				b.part.Size = size
				b.part.CFrame = CFrame.new(b.restPos.X, b.bottomY + size.Y / 2, b.restPos.Z)
					* CFrame.fromAxisAngle(b.axis, 0.05 * osc)
				if b.amp * decay < 0.008 then
					b.amp = 0
					b.part.Size = b.restSize
					b.part.CFrame = CFrame.new(b.restPos)
				end
			end
		end
	end

	function self.destroy()
		self.ready = false
		engine.Await.cancel(self.initTask)
		for _, rec in blocks do
			rec.part.Size = rec.restSize
			rec.part.CFrame = rec.restCFrame
		end
		table.clear(blocks)
	end

	return self
end

return Jelly
