-- kb_sound_audition — nghe thử âm ThockyKey (dán vào Command Bar, chế độ Edit).
--
-- Script tự tìm một bàn phím THẬT trong workspace rồi "đi bộ" dọc bàn, phát tiếng tại
-- đúng toạ độ từng phím, dùng CÙNG bộ hằng số với `ASMR/Floors/Keyboard.luau`.
-- ListenerType để nguyên mặc định của Roblox — script này không đụng tới nó.
--
--   A = BẢN CŨ  — bốc ngẫu nhiên 1 trong 8 mẫu + rung cao độ ⇒ mỗi phím một tiếng khác.
--   B = HIỆN TẠI — một tiếng duy nhất cho mọi phím, 3 lớp thân + tick + nhả.
--
-- Chỉnh khối hằng số bên dưới rồi chạy lại; chốt được số nào thì chép sang hằng số cùng
-- tên trong `src/client/Controllers/ASMR/Floors/Keyboard.luau`.

local WALKSPEED = 60 -- studs/s. Hạ xuống 30–40 để soi kỹ từng tiếng gõ.

-- ==== khớp với Keyboard.luau ====
local BODY_ID = 127105730240202 -- Keyboard Click 0.277s
local TICK_ID = 9113140795
local RELEASE_ID = 9116157307
local TICK_VOL = 0.34
local TICK_PITCH = 1.52
local RELEASE_VOL = 0.2
local RELEASE_PITCH = 1.78
local PITCH_JITTER = 0.0
-- ================================

-- chỉ dùng cho vế A, để tái hiện cái cũ mà so
local OLD_BODY_IDS = {
	102855535543930,
	113108830240353,
	-- (mẫu mới 127105730240202 không nằm ở đây: vế A là để so với bản bốc ngẫu nhiên cũ)
	72826565018765,
	125615721658437,
	125027148509088,
	88838553648526,
	125236580407249,
	132465969238702,
}

local EAR_OFFSET = 4.5 -- khớp SoundPool
local PAN = 0.85
local RELEASE_DELAY = 0.085 -- phím bật lại — khớp lò xo RELEASE_K/D của sàn

local ContentProvider = game:GetService("ContentProvider")

-- ===== tìm bàn phím thật =====
local function findWrap(root, depth)
	for _, c in root:GetChildren() do
		if c.Name == "Clicky Keyboard Asmr" then
			return c
		end
		if depth < 6 then
			local r = findWrap(c, depth + 1)
			if r then
				return r
			end
		end
	end
	return nil
end

local wrap = findWrap(workspace, 0)
if not wrap then
	error("[KB audition] không thấy bàn phím nào trong workspace (streaming đang giấu?)")
end

local keys = {}
for _, theme in wrap.Themes:GetChildren() do
	for _, k in theme:GetChildren() do
		if k:IsA("MeshPart") then
			table.insert(keys, k)
		end
	end
end

-- chọn MỘT hàng phím chạy dọc trục dài của bàn = đúng đường người chơi đi
local x0, x1, z0, z1 = 1e9, -1e9, 1e9, -1e9
for _, k in keys do
	x0, x1 = math.min(x0, k.Position.X), math.max(x1, k.Position.X)
	z0, z1 = math.min(z0, k.Position.Z), math.max(z1, k.Position.Z)
end
local runAlongX = (x1 - x0) >= (z1 - z0)
local laneValue = if runAlongX then (z0 + z1) / 2 else (x0 + x1) / 2

local path = {}
for _, k in keys do
	local lanePos = if runAlongX then k.Position.Z else k.Position.X
	if math.abs(lanePos - laneValue) <= 2.6 then
		table.insert(path, k)
	end
end
table.sort(path, function(a, b)
	return (if runAlongX then a.Position.X else a.Position.Z) < (if runAlongX then b.Position.X else b.Position.Z)
end)
print(("[KB audition] %s — %d phím trên đường đi"):format(wrap.Parent:GetFullName(), #path))

-- ===== bể giọng (1 Sound cố định / id, đúng như SoundPool) =====
local folder = workspace:FindFirstChild("KBAudition")
if folder then
	folder:Destroy()
end
folder = Instance.new("Folder")
folder.Name = "KBAudition"
folder.Parent = workspace

local voices: { [number]: Sound } = {}
local all = {}
local ids = { BODY_ID, TICK_ID, RELEASE_ID }
for _, id in OLD_BODY_IDS do
	table.insert(ids, id)
end
for _, id in ids do
	if not voices[id] then
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.one
		part.Parent = folder

		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 30
		s.RollOffMaxDistance = 70
		s.Volume = 0
		s.Parent = part
		voices[id] = s
		table.insert(all, s)
	end
end
pcall(function()
	ContentProvider:PreloadAsync(all)
end)
for _, s in all do
	s:Play()
end
task.wait(0.3)
for _, s in all do
	s:Stop()
end

local function fire(id: number, pos: Vector3, vol: number, pitch: number, pan: number, maxD: number)
	local cam = workspace.CurrentCamera
	local right = if cam then cam.CFrame.RightVector else Vector3.xAxis
	local s = voices[id]
	s.Parent.Position = pos + right * (pan * EAR_OFFSET)
	s.RollOffMaxDistance = maxD
	s.Volume = vol
	s.PlaybackSpeed = pitch
	s.TimePosition = 0
	s:Play()
end

local ear = false
local function stroke(key: BasePart, newWay: boolean)
	ear = not ear
	local pan = if ear then PAN else -PAN
	local pos = key.Position
	local vol = 0.5 + (WALKSPEED / 250) * 0.45

	if not newWay then
		-- BẢN CŨ: mẫu + cao độ ngẫu nhiên mỗi lần dẫm
		fire(OLD_BODY_IDS[math.random(#OLD_BODY_IDS)], pos, vol, 0.94 + math.random() * 0.56, pan, 70)
		return
	end

	local pitch = if PITCH_JITTER > 0 then 1 + (math.random() * 2 - 1) * PITCH_JITTER else 1
	fire(BODY_ID, pos, vol, pitch, pan, 70)
	fire(TICK_ID, pos, vol * TICK_VOL, pitch * TICK_PITCH, pan, 70)
	task.delay(RELEASE_DELAY, function()
		fire(RELEASE_ID, pos, RELEASE_VOL, RELEASE_PITCH, pan, 55)
	end)
end

local function run(label: string, newWay: boolean)
	print("[KB audition] " .. label)
	for i, key in path do
		stroke(key, newWay)
		local nxt = path[i + 1]
		task.wait(if nxt then (nxt.Position - key.Position).Magnitude / WALKSPEED else 0)
	end
end

task.spawn(function()
	print(("[KB audition] đi dọc bàn @ %d WS"):format(WALKSPEED))
	run("A — BẢN CŨ (mẫu + cao độ ngẫu nhiên mỗi phím)", false)
	task.wait(1.2)
	run("B — HIỆN TẠI (mọi ThockyKey một tiếng y hệt nhau)", true)
	task.wait(1.2)
	folder:Destroy()
	print("[KB audition] xong — chỉnh hằng số ở đầu file rồi chạy lại để so tiếp")
end)
