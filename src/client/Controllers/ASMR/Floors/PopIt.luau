--!strict
-- PopIt — port nguyên vẹn PopItClient: bước lên bong bóng -> lõm xuống + pop lách tách,
-- tự phồng lại 2.2–4.4s với tiếng trầm nhỏ. Sound qua SoundPool (hết Instance.new + Debris).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local TweenService = game:GetService("TweenService")

local PopIt = {}

type Bubble = {
	part: BasePart,
	mesh: SpecialMesh?,
	restScale: Vector3?,
	restPos: Vector3,
	restColor: Color3,
	popped: boolean,
	unpopTask: thread?,
}

-- Mix ASMR: pop/suction/pacifier/click + 2 Mouth Pop PSE mới (đa chất liệu phê tai)
local POP_SOUNDS = { 9117848644, 9119669295, 9117183955, 86707910685850, 9117019900, 9117020115 }
PopIt.soundIds = POP_SOUNDS

-- Bán kính pop PHẢI theo cỡ bubble, không hardcode: Zone 5 đã đổi bubble 3.5→5
-- (pitch 4.1→5.6) nên 2.15 cũ để hụt — đứng giữa 4 bubble thì không cái nào lõm.
-- 0.82×cỡ ≈ nửa đường chéo ô ⇒ mọi vị trí chân luôn ấn được ít nhất 1 bubble.
local POP_R_FACTOR = 0.82
local POP_R_MIN = 2.15
local UNPOP_MIN, UNPOP_MAX = 2.2, 4.4
-- lún sâu 1.5/2.6 = 58% chiều cao (cũ 0.95 = 37%) + mesh bẹp 0.16 phình ngang 1.14
-- → cú ấn "rõ ràng" theo yêu cầu user 2026-07-24
local POP_DEPTH = 1.5
local POP_SCALE = Vector3.new(1.14, 0.16, 1.14)
local FOOT_DROP = 3.2

local POP_TI = TweenInfo.new(0.11, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local UNPOP_TI = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

function PopIt.attach(model: Model, engine: any)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }
	-- Bản zone không có Base → box.topY = ĐỈNH bubble (cao 2.6) chứ không phải mặt sàn
	-- → builder set YTol=4.2. Bản test giữ mặc định 2.6 (mốc Base thấp).
	local Y_TOL = (model:GetAttribute("YTol") or 2.6) :: number

	local bubbles: { Bubble } = {}
	local tweens: { [Instance]: Tween } = {}
	local box
	local popR2 = POP_R_MIN * POP_R_MIN

	self.initTask = task.spawn(function()
		local folder = model:WaitForChild("Bubbles", 10)
		if not folder then
			return
		end
		engine.Await.childrenStable(folder)
		for _, d in folder:GetChildren() do
			if d:IsA("BasePart") and d.Name == "Bubble" then
				local mesh = d:FindFirstChildOfClass("SpecialMesh")
				table.insert(bubbles, {
					part = d,
					mesh = mesh,
					restScale = mesh and mesh.Scale,
					restPos = d.Position,
					restColor = d.Color,
					popped = false,
				})
			end
		end
		local base = model:FindFirstChild("Base")
		box = if base and base:IsA("BasePart") then Bounds.ofBase(base, 2) else Bounds.ofParts(folder:GetChildren(), 2)
		if bubbles[1] then
			local r = math.max(POP_R_MIN, bubbles[1].part.Size.X * POP_R_FACTOR)
			popR2 = r * r
		end
		self.ready = box ~= nil and #bubbles > 0
		Log.Floor("PopIt", #bubbles, model)
	end)

	local function playPop(parent: BasePart, speedMin: number, speedMax: number, volume: number)
		if not FxBudget.fxOK(parent.Position) then
			return
		end
		SoundPool.playStep(
			POP_SOUNDS[math.random(#POP_SOUNDS)],
			parent.Position,
			volume,
			speedMin + math.random() * (speedMax - speedMin),
			80
		)
	end

	local function playTween(target: Instance, info: TweenInfo, goal: { [string]: any })
		local previous = tweens[target]
		if previous then
			previous:Cancel()
			previous:Destroy()
		end
		local tween = TweenService:Create(target, info, goal)
		tweens[target] = tween
		tween:Play()
	end

	local function pop(b: Bubble)
		b.popped = true
		local c = b.restColor
		playTween(b.part, POP_TI, {
			Position = b.restPos - Vector3.new(0, POP_DEPTH, 0),
			Color = Color3.new(c.R * 0.55, c.G * 0.55, c.B * 0.55),
		})
		if b.mesh then
			playTween(b.mesh, POP_TI, { Scale = POP_SCALE })
		end
		playPop(b.part, 0.92, 1.35, 0.48)

		b.unpopTask = task.delay(UNPOP_MIN + math.random() * (UNPOP_MAX - UNPOP_MIN), function()
			b.unpopTask = nil
			if not self.ready or not b.popped then
				return
			end
			b.popped = false
			playTween(b.part, UNPOP_TI, { Position = b.restPos, Color = b.restColor })
			if b.mesh then
				playTween(b.mesh, UNPOP_TI, { Scale = Vector3.one })
			end
			playPop(b.part, 0.55, 0.72, 0.20) -- tiếng "phồng lại" trầm, nhỏ hơn
		end)
	end

	function self.update(_dt, _now, foot)
		if not (self.ready and foot) then
			return
		end
		local pos: Vector3 = foot.pos
		if not engine.Bounds.contains(box, pos) then
			return
		end
		if math.abs((pos.Y - FOOT_DROP) - box.topY) > Y_TOL then
			return
		end
		for _, b in bubbles do
			if not b.popped then
				local dx = b.restPos.X - pos.X
				local dz = b.restPos.Z - pos.Z
				if dx * dx + dz * dz <= popR2 then
					pop(b)
				end
			end
		end
	end

	function self.destroy()
		self.ready = false
		engine.Await.cancel(self.initTask)
		for _, tween in tweens do
			tween:Cancel()
			tween:Destroy()
		end
		-- Cancel không hoàn tác property; phải trả pose trước khi adapter khác nạp lại.
		for _, b in bubbles do
			engine.Await.cancel(b.unpopTask)
			b.part.Position = b.restPos
			b.part.Color = b.restColor
			if b.mesh and b.restScale then
				b.mesh.Scale = b.restScale
			end
		end
		table.clear(tweens)
		table.clear(bubbles)
	end

	return self
end

return PopIt
