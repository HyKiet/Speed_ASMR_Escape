--!nocheck
--------------------------------------------------------------------------------
-- ASMRZoneBuilder v6 — REFERENCE (chạy từng phần qua execute_luau, Edit mode)
-- Rải sàn ASMR lên 15 Zone theo theme map, engine client duy nhất xử lý hiệu ứng
-- (src/client/Controllers/ASMR/). Kiến trúc: docs/asmr-engine-architecture.md.
--
-- QUY TẮC BẮT BUỘC (học từ "+1 Speed Keyboard Escape"):
--  • slimKey: MỌI phím clone ra zone phải ClearAllChildren — PHÍM TRẦN thuần túy.
--    KHÔNG SurfaceGui/TextLabel (45k gui = sụp UI render pipeline), KHÔNG Sound,
--    KHÔNG ParticleEmitter, KHÔNG Script. Âm thanh/hạt/lò xo = Engine trung tâm
--    (SoundPool 32 + ParticlePool 12) đảm nhiệm 100%.
--  • Lưới TOÀN CỤC per-part (không reset theo chunk → không seam).
--  • Section Model ≤48 studs, ModelStreamingMode=Atomic, tag "ASMRFloor",
--    attribute FloorType (+GlowTheme cho Keyboard, YTol cho Jelly/PopIt/BW zone).
--  • Y-placement theo MỐC MẶT ĐI BỘ template (surfRef):
--      PopIt 9.2 / BubbleWrap 9.2 / Clay 8.9 (sàn LÚN — không WalkSurface)
--      Keyboard: key bottom = topY+0.02, WalkSurface top = topY+0.54
--      Jelly: block bottom = topY+0.02, WalkSurface top = topY+3.14 (YTol 5.5)
--      Soap: bar bottom = topY+0.02, WalkSurface top = topY+1.64
--      Melody: tile bottom = topY+0.02, tile CanCollide=true (sàn TĨNH)
--  • Sàn ĐỘNG (flap Z14, ShrinkPlatform Z6, CrumblingBlock Z7, Section Z11):
--    KHÔNG WalkSurface, tile không collide (không phá bẫy).
--  • Cổng StageStart/Finish đã nâng +0.65 (chân trên WalkSurface không hụt Touched).
--  • Theme map: Z1 Plain·Z2 Clay·Z3 BW·Z4 Dark rainbow cell3·Z5 PopIt(SlideFloor)
--    ·Z6 Melody(Core)·Z7 Jelly(Crumble)·Z8 Dark grey 4.5·Z9 Aqua(WaterFloor)
--    ·Z11 Light Rainbow trong Section_N·Z12 Soap·Z13 Red With White 4.5
--    ·Z14 Clay(Start/End/40 flap)·Z15 Melody(đảo). Mọi Transition = Plain FULL cell3.
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local test = workspace.Lobby.ASMR.ASMR_Test
local kbThemes = test.KeyBoard["Clicky Keyboard Asmr"].Themes
local rng = Random.new(60718)

local function sanitize(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
end

-- PHÍM TRẦN: clone + tẩy sạch 100% instance con (SurfaceGui/Sound/Emitter/Script)
local function slimKey(src)
	local k = src:Clone()
	k:ClearAllChildren()
	sanitize(k)
	return k
end

local function aabb(part)
	local sz = part.Size
	local r = math.rad(part.Orientation.Y)
	local c, s = math.abs(math.cos(r)), math.abs(math.sin(r))
	return {
		cx = part.Position.X,
		cz = part.Position.Z,
		halfX = (c * sz.X + s * sz.Z) / 2,
		halfZ = (s * sz.X + c * sz.Z) / 2,
		topY = part.Position.Y + sz.Y / 2,
	}
end

local function newSection(parentF, name, floorType, attrs)
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m:SetAttribute("FloorType", floorType)
	for k, v in attrs or {} do
		m:SetAttribute(k, v)
	end
	m.Parent = parentF
	return m
end

local function addWalk(secModel, cx, cz, sx, sz, topY)
	local w = Instance.new("Part")
	w.Name = "WalkSurface"
	w.Size = Vector3.new(sx, 0.4, sz)
	w.CFrame = CFrame.new(cx, topY - 0.2, cz)
	w.Transparency = 1
	w.Anchored = true
	w.CanCollide = true
	w.CanTouch = false
	w.CanQuery = false
	w.CastShadow = false
	w.Parent = secModel
end

local keyCache = {}
local function themeKeys(tn)
	if not keyCache[tn] then
		local l = {}
		for _, k in kbThemes[tn]:GetChildren() do
			if k:IsA("MeshPart") then
				table.insert(l, k)
			end
		end
		keyCache[tn] = l
	end
	return keyCache[tn]
end

-- Keyboard full-coverage, lưới toàn cục, bucket 48, phím TRẦN qua slimKey
-- yawOff: zone dọc +Z = 180, hành lang +X = -90 (quy tắc hướng chữ session 9 —
-- giờ phím trần nên yaw chỉ còn ý nghĩa thẩm mỹ mesh)
local function tileKeyboard(asmrF, part, theme, cell, yawOff, walk, name)
	local box = aabb(part)
	local nx = math.max(1, math.ceil(box.halfX * 2 / 48))
	local nz = math.max(1, math.ceil(box.halfZ * 2 / 48))
	local sx, szz = box.halfX * 2 / nx, box.halfZ * 2 / nz
	local tpl = themeKeys(theme)
	local secs = {}
	local function themeFolderFor(ix, iz)
		local key = ix .. "," .. iz
		if not secs[key] then
			local m = newSection(asmrF, ("%s_%d_%d"):format(name, ix, iz), "Keyboard", { GlowTheme = theme })
			local wrap = Instance.new("Folder")
			wrap.Name = "Clicky Keyboard Asmr"
			wrap.Parent = m
			local tf = Instance.new("Folder")
			tf.Name = "Themes"
			tf.Parent = wrap
			local th = Instance.new("Folder")
			th.Name = theme
			th.Parent = tf
			if walk then
				addWalk(m, box.cx - box.halfX + sx * (ix + 0.5), box.cz - box.halfZ + szz * (iz + 0.5), sx, szz, box.topY + 0.54)
			end
			CollectionService:AddTag(m, "ASMRFloor")
			secs[key] = th
		end
		return secs[key]
	end
	local n = 0
	local x = box.cx - box.halfX + cell / 2 + 0.1
	while x <= box.cx + box.halfX - cell / 2 + 0.01 do
		local z = box.cz - box.halfZ + cell / 2 + 0.1
		while z <= box.cz + box.halfZ - cell / 2 + 0.01 do
			local ix = math.min(nx - 1, math.floor((x - (box.cx - box.halfX)) / sx))
			local iz = math.min(nz - 1, math.floor((z - (box.cz - box.halfZ)) / szz))
			local src = tpl[rng:NextInteger(1, #tpl)]
			local k = slimKey(src)
			k.CFrame = CFrame.new(x, box.topY + 0.02 + src.Size.Y / 2, z)
				* CFrame.Angles(0, math.rad(src.Orientation.Y + yawOff), 0)
			k.Parent = themeFolderFor(ix, iz)
			n += 1
			z += cell
		end
		x += cell
	end
	return n
end

-- Grid floor chung (PopIt/BW/Clay/Melody/Jelly): đặt theo surfRef template
local function gridFloor(asmrF, part, floorType, folderName, tplParts, cell, surfRef, name, opts)
	opts = opts or {}
	local box = aabb(part)
	local nx = math.max(1, math.ceil(box.halfX * 2 / 48))
	local nz = math.max(1, math.ceil(box.halfZ * 2 / 48))
	local sx, szz = box.halfX * 2 / nx, box.halfZ * 2 / nz
	local secs = {}
	local function folderFor(ix, iz)
		local key = ix .. "," .. iz
		if not secs[key] then
			local m = newSection(asmrF, ("%s_%d_%d"):format(name, ix, iz), floorType, opts.attrs)
			local fo = Instance.new("Folder")
			fo.Name = folderName
			fo.Parent = m
			if opts.walkOffset then
				addWalk(m, box.cx - box.halfX + sx * (ix + 0.5), box.cz - box.halfZ + szz * (iz + 0.5), sx, szz, box.topY + opts.walkOffset)
			end
			CollectionService:AddTag(m, "ASMRFloor")
			secs[key] = fo
		end
		return secs[key]
	end
	local n = 0
	local x = box.cx - box.halfX + cell / 2 + 0.1
	while x <= box.cx + box.halfX - cell / 2 + 0.01 do
		local z = box.cz - box.halfZ + cell / 2 + 0.1
		while z <= box.cz + box.halfZ - cell / 2 + 0.01 do
			local ix = math.min(nx - 1, math.floor((x - (box.cx - box.halfX)) / sx))
			local iz = math.min(nz - 1, math.floor((z - (box.cz - box.halfZ)) / szz))
			local src = tplParts[rng:NextInteger(1, #tplParts)]
			local c = src:Clone() -- non-keyboard GIỮ children (SpecialMesh của bubble)
			sanitize(c)
			if opts.collide then
				c.CanCollide = true
			end
			c.CFrame = CFrame.new(Vector3.new(x, box.topY + (src.Position.Y - surfRef), z))
				* (src.CFrame - src.CFrame.Position)
			c.Parent = folderFor(ix, iz)
			if opts.extraFn then
				opts.extraFn(c, x, z, box)
			end
			n += 1
			z += cell
		end
		x += cell
	end
	return n
end

return {
	sanitize = sanitize,
	slimKey = slimKey,
	aabb = aabb,
	newSection = newSection,
	addWalk = addWalk,
	tileKeyboard = tileKeyboard,
	gridFloor = gridFloor,
}
