--!strict
-- Pool 12 anchor di động, mỗi anchor mang sẵn 1 emitter cho từng preset (Rate=0, chỉ Emit).
-- Thay thế 720 emitter "Stars" per-phím + các emitter lazy-create rải rác của sàn cũ.
-- Thông số preset bê NGUYÊN từ emitter/code gốc để giữ đúng cảm giác.

local ParticlePool = {}

local POOL_N = 12

type Anchor = { part: BasePart, emitters: { [string]: ParticleEmitter } }
local anchors: { Anchor } = table.create(POOL_N)
local idx = 0

local function buildEmitters(parent: BasePart): { [string]: ParticleEmitter }
	local out: { [string]: ParticleEmitter } = {}

	-- stars — sao cầu vồng của phím keyboard (emitter "Stars" gốc trên từng phím)
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxassetid://3057073083"
	stars.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 0.996, 0.918)),
		ColorSequenceKeypoint.new(0.199, Color3.new(0.996, 1, 0.957)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 0.945, 0.663)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 0.643, 0.333)),
	})
	stars.Size = NumberSequence.new(0.4)
	stars.Lifetime = NumberRange.new(1.5)
	stars.Speed = NumberRange.new(5)
	stars.SpreadAngle = Vector2.new(40, 40)
	stars.Acceleration = Vector3.new(0, -10, 0)
	stars.RotSpeed = NumberRange.new(-100, 200)
	out.stars = stars

	-- puff — luồng khí trắng phụt lên khi nổ BubbleWrap (BubbleWrapClient v2)
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 2.6),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Lifetime = NumberRange.new(0.25, 0.4)
	puff.Speed = NumberRange.new(3, 7)
	puff.SpreadAngle = Vector2.new(35, 35)
	puff.EmissionDirection = Enum.NormalId.Top
	puff.Acceleration = Vector3.new(0, 6, 0)
	out.puff = puff

	-- sparks — tia lấp lánh văng ra khi nổ BubbleWrap
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255), Color3.fromRGB(255, 255, 255))
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Lifetime = NumberRange.new(0.3, 0.5)
	sparks.Speed = NumberRange.new(9, 16)
	sparks.SpreadAngle = Vector2.new(65, 65)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Acceleration = Vector3.new(0, -32, 0)
	sparks.RotSpeed = NumberRange.new(-180, 180)
	out.sparks = sparks

	-- dust — bụi cát KineticSand
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(222, 198, 155))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1.4),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(0.25, 0.45)
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.EmissionDirection = Enum.NormalId.Top
	out.dust = dust

	-- droplets — giọt nước bắn AquaRun (Speed gốc biến thiên 6..11+ratio*10 → chốt 6..14)
	local droplets = Instance.new("ParticleEmitter")
	droplets.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	droplets.Color = ColorSequence.new(Color3.fromRGB(160, 220, 255))
	droplets.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.12),
	})
	droplets.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	droplets.Lifetime = NumberRange.new(0.3, 0.5)
	droplets.Speed = NumberRange.new(6, 14)
	droplets.SpreadAngle = Vector2.new(55, 55)
	droplets.EmissionDirection = Enum.NormalId.Top
	droplets.Acceleration = Vector3.new(0, -55, 0)
	out.droplets = droplets

	-- ===== VIBE Zone 15 (2026-07-28) =====
	-- Ba preset dưới đây sao NGUYÊN thông số 3 emitter mẫu user dựng sẵn trong Workspace
	-- (`Fire-03.Main.Fire1`, `Water-01.Main.Water1`, `Lighting-01.Main.Lighting1`).
	-- Cả ba đều là flipbook Grid4x4 — thiếu `FlipbookLayout` thì texture hiện ra nguyên tấm
	-- sprite sheet 16 ô thay vì chạy hoạt ảnh, đây là chỗ dễ sai nhất khi chép tay.
	-- Rate/Enabled bị ép về 0/false ở cuối hàm; ta chỉ dùng `Emit()`.

	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxassetid://11395089850"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 125, 92))
	fire.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.69, 0),
		NumberSequenceKeypoint.new(0.86, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	fire.Size = NumberSequence.new(2)
	fire.Squash = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, -0.12),
	})
	fire.Lifetime = NumberRange.new(0.5)
	fire.Speed = NumberRange.new(1.5)
	fire.SpreadAngle = Vector2.new(-360, 360)
	fire.Drag = 5
	fire.Rotation = NumberRange.new(-360, 360)
	fire.RotSpeed = NumberRange.new(-30, 30)
	fire.ZOffset = 1
	fire.Brightness = 4.2
	fire.Orientation = Enum.ParticleOrientation.FacingCamera
	fire.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	out.fire = fire

	local water = Instance.new("ParticleEmitter")
	water.Texture = "rbxassetid://16664715772"
	water.Color = ColorSequence.new(Color3.fromRGB(0, 153, 255))
	water.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.06),
		NumberSequenceKeypoint.new(0.9, 0.51),
		NumberSequenceKeypoint.new(1, 1),
	})
	-- vòng nước loang: bắt đầu bé rồi nở ra — chính đường cong này tạo cảm giác "gợn sóng"
	water.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.94),
		NumberSequenceKeypoint.new(1, 2),
	})
	water.Lifetime = NumberRange.new(1)
	water.Speed = NumberRange.new(0)
	water.SpreadAngle = Vector2.new(10, 10)
	water.Rotation = NumberRange.new(-360, 360)
	water.RotSpeed = NumberRange.new(-20, 20)
	water.ZOffset = 1.7
	water.LightEmission = 0.3
	water.Brightness = 2
	water.Orientation = Enum.ParticleOrientation.FacingCamera
	water.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	out.water = water

	local lightning = Instance.new("ParticleEmitter")
	lightning.Texture = "rbxassetid://16664675233"
	-- Mẫu gốc màu xanh điện (0, 132, 255). Kéo về tím-lam cho khớp bàn phím navy-tím của
	-- vibe Lightning (ảnh tham chiếu của user) mà vẫn giữ độ chói LightEmission 1.
	lightning.Color = ColorSequence.new(Color3.fromRGB(150, 110, 255))
	lightning.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0.44),
		NumberSequenceKeypoint.new(0.49, 0),
		NumberSequenceKeypoint.new(0.76, 0.46),
		NumberSequenceKeypoint.new(1, 1),
	})
	lightning.Size = NumberSequence.new(2)
	lightning.Lifetime = NumberRange.new(0.6)
	lightning.Speed = NumberRange.new(0.001)
	lightning.SpreadAngle = Vector2.new(360, 360)
	lightning.Rotation = NumberRange.new(-360, 360)
	lightning.RotSpeed = NumberRange.new(0)
	lightning.ZOffset = 2
	lightning.LightEmission = 1
	lightning.Brightness = 10
	lightning.Orientation = Enum.ParticleOrientation.FacingCamera
	lightning.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	out.lightning = lightning

	for name, e in out do
		e.Name = name
		e.Rate = 0
		e.Enabled = false
		e.Parent = parent
	end
	return out
end

function ParticlePool.init(container: Instance)
	for i = 1, POOL_N do
		local part = Instance.new("Part")
		part.Name = "ASMRParticleAnchor"
		part.Size = Vector3.one * 0.2
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = CFrame.new(0, -500, 0)
		part.Parent = container
		anchors[i] = { part = part, emitters = buildEmitters(part) }
	end
end

-- Dịch anchor kế tiếp tới vị trí rồi Emit — emitter không bao giờ bị tạo/hủy runtime
function ParticlePool.emit(preset: string, pos: Vector3, count: number)
	idx = idx % POOL_N + 1
	local a = anchors[idx]
	a.part.Position = pos
	local e = a.emitters[preset]
	if e then
		e:Emit(count)
	end
end

return ParticlePool
