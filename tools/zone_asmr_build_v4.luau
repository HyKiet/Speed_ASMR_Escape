-- zone_asmr_build_v4.luau — bản tham chiếu ĐẦY ĐỦ của ServerStorage.ASMRZoneBuilder (v4, hiện hành)
-- Dùng: require(game.ServerStorage.ASMRZoneBuilder)({1..15}) trong Edit mode. Idempotent.
--
-- v4 (feedback user 2026-07-15: chữ ngược hướng + game siêu lag từ khi lát sàn):
--  • HƯỚNG CHỮ: keycap Face=Top, part identity → đỉnh chữ −Z (quy tắc decal: đỉnh ảnh quay về
--    Front của part). Zone dọc (chạy +Z): yaw 180° → đỉnh chữ +Z; hành lang ngang (z≈2980–3080,
--    x>50, chạy +X): yaw −90° (= orientation gốc boardwalk 0,−90,0) → đỉnh chữ +X.
--  • PERF (trước fix: 30k Sound + 31k ParticleEmitter + 30k SurfaceGui render vô hạn → FPS ~25):
--    - Xóa Sound con của key zone (v5 phát âm qua pool — Sound con là đồ thừa).
--    - Xóa Stars con; sparkle chuyển sang POOL 12 emitter trong KeyboardASMRClient v5.1
--      (playKey: rec.stars nếu có, không thì dời pool emitter tới phím rồi Emit).
--    - GIỮ SurfaceGui chữ nhưng MaxDistance=60 → chỉ render ~vài trăm gần camera (đo 279/12.423).
--    - Zone 11 (Section Persistent, luôn load mọi client): phím TRẦN ClearAllChildren
--      (bỏ ~20.7k instance thường trực) — vẫn lún + kêu pool + glow, không chữ (chạy 200 speed).
--  • Giữ từ v3: clone tile THẬT không resize; xóa base visible (clay UnderBase, popit Base+Rim,
--    bw/melody Base, jelly Tray, soap Tray+Collider) + patch __asmrBox; Zone 9 = 1 AquaRunFloor
--    resize; đáy tile = floorTop+0.02; mọi part non-collide/touch.

local Zones = workspace.Zones
local TESTROOT = workspace.Lobby.ASMR.ASMR_Test

-- Hướng chữ trên keycap theo trục chạy của part
local YAW_PLUS_Z = CFrame.Angles(0, math.pi, 0)
local YAW_PLUS_X = CFrame.Angles(0, -math.pi / 2, 0)
local function travelYaw(part)
	local p = part.Position
	if p.Z > 2980 and p.Z < 3080 and p.X > 50 then return YAW_PLUS_X end
	return YAW_PLUS_Z
end

-- PERF: bỏ Sound (thừa) + Stars (thay bằng pool v5.1); chữ giữ nhưng chỉ render gần
local function slimKey(k)
	local snd = k:FindFirstChild("Sound")
	if snd then snd:Destroy() end
	local st = k:FindFirstChild("Stars")
	if st then st:Destroy() end
	local gui = k:FindFirstChildOfClass("SurfaceGui")
	if gui then gui.MaxDistance = 60 end
end

local BOUNDS_FN = "local function __asmrBox(f) local x0,x1,z0,z1,y0=1e9,-1e9,1e9,-1e9,1e9 for _,t in f:GetChildren() do if t:IsA('BasePart') then x0=math.min(x0,t.Position.X-t.Size.X/2) x1=math.max(x1,t.Position.X+t.Size.X/2) z0=math.min(z0,t.Position.Z-t.Size.Z/2) z1=math.max(z1,t.Position.Z+t.Size.Z/2) y0=math.min(y0,t.Position.Y-t.Size.Y/2) end end return {Position=Vector3.new((x0+x1)/2,y0,(z0+z1)/2),Size=Vector3.new(x1-x0,2.4,z1-z0)} end\n"

local function partBounds(p)
	local sz = p.Size
	return p.Position.X, p.Position.Z, sz.X / 2, sz.Z / 2, p.Position.Y + sz.Y / 2
end

local function footprint(model, tileFolderName)
	local cont = tileFolderName and model:FindFirstChild(tileFolderName) or model
	local x0, x1, z0, z1, ymin = 1e9, -1e9, 1e9, -1e9, 1e9
	local function scan(c)
		for _, t in c:GetChildren() do
			if t:IsA("BasePart") then
				x0 = math.min(x0, t.Position.X - t.Size.X / 2); x1 = math.max(x1, t.Position.X + t.Size.X / 2)
				z0 = math.min(z0, t.Position.Z - t.Size.Z / 2); z1 = math.max(z1, t.Position.Z + t.Size.Z / 2)
				ymin = math.min(ymin, t.Position.Y - t.Size.Y / 2)
			end
		end
	end
	if cont:IsA("BasePart") then scan(model) else scan(cont) end
	return (x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, ymin
end

local function setVisualFlags(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
end

local function newRoot(zone)
	local f = zone:FindFirstChild("ASMRFloors")
	if not f then f = Instance.new("Folder"); f.Name = "ASMRFloors"; f.Parent = zone end
	return f
end

local function findParts(zone, names)
	local out = {}
	for _, n in names do
		for _, d in zone:GetDescendants() do
			if d:IsA("BasePart") and d.Name == n then table.insert(out, d) end
		end
	end
	return out
end

-- cfg: model, tiles, del={names}, patchFolder (Base->folder), patchTray (Tray->folder), jelly
local function tileModel(root, cfg, part)
	local src = TESTROOT[cfg.model]
	local cx, cz, fW, fD, tileBottom = footprint(src, cfg.tiles)
	local pcx, pcz, phx, phz, ptop = partBounds(part)
	local px0, px1, pz0, pz1 = pcx - phx, pcx + phx, pcz - phz, pcz + phz
	local dy = ptop + 0.02 - tileBottom
	local placed = 0
	local gx = px0 + fW / 2
	while gx - fW / 2 < px1 - 0.5 do
		local gz = pz0 + fD / 2
		while gz - fD / 2 < pz1 - 0.5 do
			local clone = src:Clone()
			local off = Vector3.new(gx - cx, dy, gz - cz)
			for _, p in clone:GetDescendants() do
				if p:IsA("BasePart") then setVisualFlags(p); p.CFrame = p.CFrame + off end
			end
			local tf = clone:FindFirstChild(cfg.tiles)
			local kept = 0
			for _, t in tf:GetChildren() do
				if t:IsA("BasePart") then
					if t.Position.X < px0 - 0.5 or t.Position.X > px1 + 0.5
						or t.Position.Z < pz0 - 0.5 or t.Position.Z > pz1 + 0.5 then
						t:Destroy()
					else kept += 1 end
				end
			end
			if kept == 0 then
				clone:Destroy()
			else
				if cfg.del then
					for _, nm in cfg.del do
						local d = clone:FindFirstChild(nm)
						while d do d:Destroy(); d = clone:FindFirstChild(nm) end
					end
				end
				local sc = clone:FindFirstChildWhichIsA("Script")
				if sc then
					local s = sc.Source
					if cfg.jelly then s = s:gsub("%- topY%) < 3 then", "- topY) < 5.5 then") end
					if cfg.patchFolder then s = s:gsub('local base = model:WaitForChild%("Base"%)', BOUNDS_FN .. 'local base = __asmrBox(model:WaitForChild("' .. cfg.patchFolder .. '"))') end
					if cfg.patchTray then s = s:gsub('local tray = model:WaitForChild%("Tray"%)', BOUNDS_FN .. 'local tray = __asmrBox(model:WaitForChild("' .. cfg.patchTray .. '"))') end
					sc.Source = s
				end
				clone.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				clone.Parent = root
				placed += 1
			end
			gz += fD
		end
		gx += fW
	end
	return placed
end

-- Zone 9: 1 AquaRunFloor resize vừa zone (bỏ Edge, resize Basin+WaterSurface)
local function zone9Aqua(root, part)
	local pcx, pcz, phx, phz, ptop = partBounds(part)
	local clone = TESTROOT.AquaRunFloor:Clone()
	for _, e in clone:GetChildren() do
		if e:IsA("BasePart") and e.Name == "Edge" then e:Destroy() end
	end
	local W, D = phx * 2 - 6, phz * 2 - 6
	local basin = clone:FindFirstChild("Basin")
	local ws = clone:FindFirstChild("WaterSurface")
	basin.Size = Vector3.new(W, basin.Size.Y, D)
	basin.CFrame = CFrame.new(pcx, ptop + 0.05 - basin.Size.Y / 2, pcz)
	ws.Size = Vector3.new(W - 1, ws.Size.Y, D - 1)
	ws.CFrame = CFrame.new(pcx, ptop + 0.3, pcz)
	for _, p in clone:GetDescendants() do if p:IsA("BasePart") then setVisualFlags(p) end end
	clone.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	clone.Parent = root
	return 1
end

local function makeKeyboardScript(themeName)
	local sc = TESTROOT.KeyBoard.KeyboardASMRClient:Clone()
	sc.Source = sc.Source:gsub('local GLOW_THEME = "Plain"', 'local GLOW_THEME = "' .. themeName .. '"')
	return sc
end

-- keyboard: GIỮ children (chữ SurfaceGui + Sound + Stars)
local function tileKeyboard(root, sectionName, themeName, parts)
	local src = TESTROOT.KeyBoard["Clicky Keyboard Asmr"].Themes[themeName]
	local srcKeys = {}
	for _, k in src:GetChildren() do if k:IsA("MeshPart") then table.insert(srcKeys, k) end end
	local halfH = srcKeys[1].Size.Y / 2
	local m = Instance.new("Model")
	m.Name = sectionName
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local clicky = Instance.new("Folder"); clicky.Name = "Clicky Keyboard Asmr"; clicky.Parent = m
	local themes = Instance.new("Folder"); themes.Name = "Themes"; themes.Parent = clicky
	local tf = Instance.new("Folder"); tf.Name = themeName; tf.Parent = themes
	local CELL = 3
	local idx = 0
	for _, part in parts do
		local yaw = travelYaw(part)
		local pcx, pcz, phx, phz, ptop = partBounds(part)
		local nx = math.max(1, math.floor((phx * 2 - 0.5) / CELL))
		local nz = math.max(1, math.floor((phz * 2 - 0.5) / CELL))
		local x0 = pcx - (nx - 1) * CELL / 2
		local z0 = pcz - (nz - 1) * CELL / 2
		local ky = ptop + 0.02 + halfH
		for ix = 0, nx - 1 do
			for iz = 0, nz - 1 do
				idx += 1
				local k = srcKeys[(idx - 1) % #srcKeys + 1]:Clone()
				slimKey(k)
				setVisualFlags(k)
				k.CFrame = CFrame.new(x0 + ix * CELL, ky, z0 + iz * CELL) * yaw
				k.Parent = tf
			end
		end
	end
	local sc = makeKeyboardScript(themeName)
	sc.Parent = m
	m.Parent = root
	return idx
end

local function zone11(root)
	local sections = Zones.Zone11.Ground.Sections
	local src = TESTROOT.KeyBoard["Clicky Keyboard Asmr"].Themes["Light Rainbow"]
	local srcKeys = {}
	for _, k in src:GetChildren() do if k:IsA("MeshPart") then table.insert(srcKeys, k) end end
	local halfH = srcKeys[1].Size.Y / 2
	local CELL = 3
	local idx = 0
	for _, sec in sections:GetChildren() do
		if sec:IsA("Model") and sec.Name:find("Section_") then
			sec.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			for _, d in sec:GetChildren() do if d.Name == "ASMRKey" then d:Destroy() end end
			local road = sec:FindFirstChild("RoadPart")
			if road then
				local pcx, pcz, phx, phz, ptop = partBounds(road)
				local nx = math.max(1, math.floor((phx * 2 - 0.5) / CELL))
				local nz = math.max(1, math.floor((phz * 2 - 0.5) / CELL))
				local x0 = pcx - (nx - 1) * CELL / 2
				local z0 = pcz - (nz - 1) * CELL / 2
				local ky = ptop + 0.02 + halfH
				for ix = 0, nx - 1 do
					for iz = 0, nz - 1 do
						idx += 1
						local k = srcKeys[(idx - 1) % #srcKeys + 1]:Clone()
						k:ClearAllChildren() -- Persistent: phím trần, không gánh instance thường trực
						k.Name = "ASMRKey"
						setVisualFlags(k)
						k.CFrame = CFrame.new(x0 + ix * CELL, ky, z0 + iz * CELL) * YAW_PLUS_X
						k.Parent = sec
					end
				end
			end
		end
	end
	local m = Instance.new("Model"); m.Name = "ASMR_Keyboard_LightRainbow"; m.Parent = root
	local sc = makeKeyboardScript("Light Rainbow")
	local s = sc.Source
	s = s:gsub('local themes = model:WaitForChild%("Clicky Keyboard Asmr"%):WaitForChild%("Themes"%)',
		'local themes = workspace:WaitForChild("Zones"):WaitForChild("Zone11"):WaitForChild("Ground"):WaitForChild("Sections")')
	s = s:gsub('if k:IsA%("MeshPart"%) then', 'if k:IsA("MeshPart") and k.Name == "ASMRKey" then')
	sc.Source = s
	sc.Parent = m
	return idx
end

local STRIPS = {
	[1]={"Transition1To2","Stage1Start","Stage1Finish"},[2]={"Transition2To3","Stage2Start","Stage2Finish"},
	[3]={"Transition3To4","Stage3Start","Stage3Finish"},[4]={"Transition4To5","Stage4Start","Stage4Finish"},
	[5]={"Transition5To6","Stage5Start","Stage5Finish"},[6]={"Transition6To7","Stage6Start","Stage6Finish"},
	[7]={"Transition7To8","Stage7Start","Stage7Finish"},[8]={"Stage8Start","Stage8Finish"},
	[9]={"Transition8To9","Stage9Start","Stage9Finish"},[10]={"Transition9To10","Stage10Start","Stage10Finish"},
	[11]={"Transition10To11","Stage11Start","Stage11Finish"},[12]={"Transition11To12","Stage12Start","Stage12Finish"},
	[13]={"Transition12To13","Stage13Start","Stage13Finish"},[14]={"Transition13To14","Stage14Start","Stage14Finish"},
	[15]={"Transition14To15","Stage15Start","Stage15Finish"},
}

local CFG = {
	clay = { model="ClayFloor", tiles="Tiles", del={"UnderBase"} },
	popit = { model="PopItFloor", tiles="Bubbles", del={"Base","Rim"}, patchFolder="Bubbles" },
	bubblewrap = { model="BubbleWrapFloor", tiles="Bubbles", del={"Base"}, patchFolder="Bubbles" },
	melody = { model="MelodyRunFloor", tiles="Tiles", del={"Base"}, patchFolder="Tiles" },
	jelly = { model="JellyFloor", tiles="Blocks", del={"Tray"}, jelly=true },
	soap = { model="SoapFloor", tiles="Bars", del={"Tray","Collider"}, patchTray="Bars" },
}

local function buildZone(zi)
	local zone = Zones["Zone" .. zi]
	local old = zone:FindFirstChild("ASMRFloors")
	if old then old:Destroy() end
	local root = newRoot(zone)
	local rep = {}
	if zi == 1 then
		table.insert(rep, "kb=" .. tileKeyboard(root, "ASMR_Keyboard_Plain", "Plain",
			findParts(zone, {"Platform_1","Platform_2","Platform_3","Platform_4","Platform_5","Platform_6"})))
	elseif zi == 2 then
		local n = 0
		for _, p in findParts(zone, {"Platform_1","Platform_2","Platform_3","Platform_4","Platform_5","Platform_6"}) do n += tileModel(root, CFG.clay, p) end
		table.insert(rep, "clay=" .. n)
	elseif zi == 3 then
		table.insert(rep, "bw=" .. tileModel(root, CFG.bubblewrap, findParts(zone, {"Track3C"})[1]))
	elseif zi == 4 then
		table.insert(rep, "kb=" .. tileKeyboard(root, "ASMR_Keyboard_DarkRainbow", "Dark rainbow", findParts(zone, {"BossArenaFloor"})))
	elseif zi == 5 then
		table.insert(rep, "popit=" .. tileModel(root, CFG.popit, findParts(zone, {"SlideFloor"})[1]))
	elseif zi == 6 then
		local n = 0
		for _, p in findParts(zone, {"Core"}) do n += tileModel(root, CFG.melody, p) end
		table.insert(rep, "melody=" .. n)
	elseif zi == 7 then
		local n = 0
		for _, p in findParts(zone, {"CrumblingBlock"}) do n += tileModel(root, CFG.jelly, p) end
		table.insert(rep, "jelly=" .. n)
	elseif zi == 8 then
		table.insert(rep, "kb=" .. tileKeyboard(root, "ASMR_Keyboard_DarkGrey", "Dark grey Theme", findParts(zone, {"ArenaFloor"})))
	elseif zi == 9 then
		table.insert(rep, "aqua=" .. zone9Aqua(root, findParts(zone, {"WaterFloor"})[1]))
	elseif zi == 11 then
		table.insert(rep, "kbBridge=" .. zone11(root))
	elseif zi == 12 then
		table.insert(rep, "soap=" .. tileModel(root, CFG.soap, findParts(zone, {"Platform_12"})[1]))
	elseif zi == 13 then
		table.insert(rep, "kb=" .. tileKeyboard(root, "ASMR_Keyboard_RedWhite", "Red With White", findParts(zone, {"Platform_13"})))
	elseif zi == 14 then
		local n = 0
		for _, p in findParts(zone, {"StartFloor","EndFloor"}) do n += tileModel(root, CFG.clay, p) end
		table.insert(rep, "clay=" .. n)
	elseif zi == 15 then
		local n = 0
		for _, p in findParts(zone, {"P0_RunUp","I1","I2","I3","I4","I5","I6","StartStrip","ExitBridge"}) do n += tileModel(root, CFG.melody, p) end
		table.insert(rep, "melody=" .. n)
	end
	local strips = findParts(zone, STRIPS[zi])
	if #strips > 0 then
		table.insert(rep, "strips=" .. tileKeyboard(root, "ASMR_Keyboard_Strips", "Plain", strips))
	end
	return "Zone" .. zi .. ": " .. table.concat(rep, ", ")
end

return function(list)
	local out = {}
	for _, zi in list do table.insert(out, buildZone(zi)) end
	return table.concat(out, "\n")
end
