--!nocheck
--------------------------------------------------------------------------------
-- kb_board_merge_fill — chạy qua execute_luau (Edit mode), IDEMPOTENT.
-- Chuẩn hoá MỌI bàn phím ASMR trong Workspace (`KB_Platform_*`, `KB_Transition*`,
-- `KB_Part*`) theo bản user tự tinh chỉnh trên `KB_Platform_1` (2026-07-24).
--
--  1. GỘP section: `<base>_<ix>_<iz>` → một model `<base>` (1 Themes, 1 WalkSurface).
--  2. LẤP ĐẦY: lát lại toàn bộ lưới nx×nz — tái dùng phím cũ, thiếu thì clone.
--     Transition trước đây bị thủng lỗ (vd 2To3 chỉ 329/384 ô).
--     ⚠️ pitch phải suy từ KHOẢNG CÁCH THẬT giữa các phím ((max−min)/(số vị trí−1)),
--     KHÔNG lấy key.Size — phím Zone 1 bound 5.5 nhưng pitch 5.
--  3. WALKSURFACE theo quy tắc user:
--        đáy  = mặt sàn = keyBottom + 0.03
--        dày  = keyHeight / 2     → top = mặt sàn + keyHeight/2
--     ⇒ chân lún đúng NỬA thân phím (platform: đáy 8.0, top 9.0, phím cao 2).
--     Footprint = HỢP các WalkSurface cũ, nới ra nếu hụt vùng phím hơn 1 stud
--     (Transition7To8 từng có 1 section không WalkSurface → walk chỉ rộng 36/72).
--     Riêng KB_Platform_*: trục Z bám đúng vùng phím + dày 1 (bản user chỉnh tay).
--
-- Backup: `ServerStorage.KB_Backup_PreTransitionFill`.
-- ⚠️ Model gộp rộng >48 studs, vượt ngưỡng khuyến nghị của ModelStreamingMode.Atomic
--    — chấp nhận đổi lấy "dễ quản lý" theo yêu cầu user.
--------------------------------------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local KEY_CONTAINER = "Clicky Keyboard Asmr"
local BACKUP_NAME = "KB_Backup_PreTransitionFill"

local old = ServerStorage:FindFirstChild(BACKUP_NAME)
if old then
	old:Destroy()
end
local bk = Instance.new("Folder")
bk.Name = BACKUP_NAME

local groups = {}
for _, m in CollectionService:GetTagged("ASMRFloor") do
	if
		m:IsA("Model")
		and m:GetAttribute("FloorType") == "Keyboard"
		and m:IsDescendantOf(workspace) -- KHÔNG đụng bản backup trong ServerStorage
	then
		local base = string.match(m.Name, "^(KB_.+)_%d+_%d+$") or string.match(m.Name, "^(KB_[%a_]+_?%d*)$")
		if base then
			groups[base] = groups[base] or {}
			table.insert(groups[base], m)
			local c = m:Clone()
			c.Parent = bk
		end
	end
end
bk.Parent = ServerStorage

local function collectKeys(sec)
	local keys, themeName = {}, nil
	local wrap = sec:FindFirstChild(KEY_CONTAINER)
	local themes = wrap and wrap:FindFirstChild("Themes")
	if not themes then
		return keys, nil
	end
	for _, th in themes:GetChildren() do
		for _, k in th:GetChildren() do
			if k:IsA("BasePart") then
				themeName = themeName or th.Name
				table.insert(keys, k)
			end
		end
	end
	return keys, themeName
end

local report = {}
for base, secs in groups do
	table.sort(secs, function(a, b)
		return a.Name < b.Name
	end)

	local keys, themeName, walkRef = {}, nil, nil
	for _, s in secs do
		local ks, tn = collectKeys(s)
		themeName = themeName or tn
		for _, k in ks do
			table.insert(keys, k)
		end
		local w = s:FindFirstChild("WalkSurface")
		if w and not walkRef then
			walkRef = w
		end
	end
	if #keys == 0 then
		continue
	end
	themeName = themeName or "Plain"

	-- mọi phép tính chạy trong KHÔNG GIAN LOCAL của bàn → đúng cả hành lang xoay
	local rot = (walkRef and walkRef.CFrame.Rotation) or keys[1].CFrame.Rotation
	local inv = rot:Inverse()
	local tpl, keySize, keyRot = keys[1], keys[1].Size, keys[1].CFrame.Rotation

	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local setX, setZ, nx, nz, ly = {}, {}, 0, 0, 0
	for _, k in keys do
		local o = inv * k.Position
		minX, maxX = math.min(minX, o.X), math.max(maxX, o.X)
		minZ, maxZ = math.min(minZ, o.Z), math.max(maxZ, o.Z)
		local kx, kz = math.round(o.X * 10), math.round(o.Z * 10)
		if not setX[kx] then
			setX[kx] = true
			nx += 1
		end
		if not setZ[kz] then
			setZ[kz] = true
			nz += 1
		end
		ly += o.Y
	end
	ly /= #keys
	local pitchX = if nx > 1 then (maxX - minX) / (nx - 1) else keySize.X
	local pitchZ = if nz > 1 then (maxZ - minZ) / (nz - 1) else keySize.Z

	local merged = secs[1]
	merged.Name = base
	merged.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	merged:SetAttribute("FloorType", "Keyboard")
	if not CollectionService:HasTag(merged, "ASMRFloor") then
		CollectionService:AddTag(merged, "ASMRFloor")
	end
	local wrap = merged:FindFirstChild(KEY_CONTAINER)
	if not wrap then
		wrap = Instance.new("Folder")
		wrap.Name = KEY_CONTAINER
		wrap.Parent = merged
	end
	local themes = wrap:FindFirstChild("Themes")
	if not themes then
		themes = Instance.new("Folder")
		themes.Name = "Themes"
		themes.Parent = wrap
	end
	local themeFolder = themes:FindFirstChild(themeName)
	if not themeFolder then
		themeFolder = Instance.new("Folder")
		themeFolder.Name = themeName
		themeFolder.Parent = themes
	end

	local before, want, idx = #keys, nx * nz, 0
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			idx += 1
			local k = keys[idx]
			if not k then
				k = tpl:Clone()
				k:ClearAllChildren() -- PHÍM TRẦN: không SurfaceGui/Sound/Emitter/Script
			end
			local wp = rot * Vector3.new(minX + i * pitchX, ly, minZ + j * pitchZ)
			k.CFrame = CFrame.new(wp) * keyRot
			k.Anchored, k.CanCollide, k.CanTouch, k.CanQuery, k.CastShadow = true, false, false, false, false
			k.Parent = themeFolder
		end
	end
	for i = want + 1, #keys do
		keys[i]:Destroy()
	end

	local wx0, wx1, wz0, wz1 = math.huge, -math.huge, math.huge, -math.huge
	for _, s in secs do
		for _, c in s:GetChildren() do
			if c.Name == "WalkSurface" and c:IsA("BasePart") then
				local lc = inv * c.Position
				wx0, wx1 = math.min(wx0, lc.X - c.Size.X / 2), math.max(wx1, lc.X + c.Size.X / 2)
				wz0, wz1 = math.min(wz0, lc.Z - c.Size.Z / 2), math.max(wz1, lc.Z + c.Size.Z / 2)
				c:Destroy()
			end
		end
	end
	-- vùng phím (mốc để nới walk khi hụt)
	local kx0, kx1 = minX - keySize.X / 2, maxX + keySize.X / 2
	local kz0, kz1 = minZ - keySize.Z / 2, maxZ + keySize.Z / 2
	if wx0 == math.huge then
		wx0, wx1, wz0, wz1 = kx0, kx1, kz0, kz1
	else
		if kx0 < wx0 - 1 then
			wx0 = kx0
		end
		if kx1 > wx1 + 1 then
			wx1 = kx1
		end
		if kz0 < wz0 - 1 then
			wz0 = kz0
		end
		if kz1 > wz1 + 1 then
			wz1 = kz1
		end
	end

	local floorTop = (rot * Vector3.new(0, ly, 0)).Y - keySize.Y / 2 + 0.03
	local thick = keySize.Y / 2
	if string.match(base, "^KB_Platform_%d+$") then
		wz0, wz1 = kz0, kz1 -- bản user chỉnh tay: Z bám đúng vùng phím
		thick = 1
	end

	local cw = rot * Vector3.new((wx0 + wx1) / 2, ly, (wz0 + wz1) / 2)
	local walk = Instance.new("Part")
	walk.Name = "WalkSurface"
	walk.Size = Vector3.new(wx1 - wx0, thick, wz1 - wz0)
	walk.CFrame = CFrame.new(cw.X, floorTop + thick / 2, cw.Z) * rot
	walk.Transparency, walk.Anchored, walk.CanCollide = 1, true, true
	walk.CanTouch, walk.CanQuery, walk.CastShadow = false, false, false
	walk.Parent = merged

	for i = 2, #secs do
		CollectionService:RemoveTag(secs[i], "ASMRFloor")
		secs[i]:Destroy()
	end

	table.insert(
		report,
		("%s: %d->%d phím (%dx%d pitch %.1f/%.1f) walkTop=%.2f dày=%.2f walk=%.0fx%.0f"):format(
			base,
			before,
			want,
			nx,
			nz,
			pitchX,
			pitchZ,
			floorTop + thick,
			thick,
			wx1 - wx0,
			wz1 - wz0
		)
	)
end

table.sort(report)
for _, line in report do
	print("[KB] " .. line)
end
print(("[KB] XONG — %d bàn"):format(#report))
