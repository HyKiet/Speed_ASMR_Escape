--------------------------------------------------------------------------------
-- KeyboardASMR v5 — bản tham chiếu của Workspace.Lobby.ASMR.ASMR_Test.KeyBoard.KeyboardASMRClient
-- (script inline, KHÔNG được Rojo sync — sửa ở Studio, file này chỉ để đối chiếu)
--
-- Nâng cấp từ v4:
--  • FIX TRỄ NHỊP: preload của v4 KHÔNG BAO GIỜ chạy (hàm bọc PreloadAsync được
--    định nghĩa nhưng không được gọi) → phím lần đầu phát phải tải+decode ngay
--    lúc đạp. v5 preload + WARM (phát Volume=0 một lần) toàn bộ variant lúc load.
--  • SOUND POOL 32 Sound tái sử dụng — không Instance.new + Debris mỗi lần đạp,
--    phát tức thì, không GC churn.
--  • Bộ CLICK BÀN PHÍM CƠ mới 6 variant (ProSoundEffects CU Clicks 9116158528/
--    9116158927/9116158128/9116158896/9116157307/9116158538) + pitch ngẫu nhiên
--    nhẹ — mỗi bước một tiếng thock khác nhau, nghe cực đã.
--  • RGB GLOW theme "Plain": player đi đến đâu phím SÁNG đến đó — vầng cầu vồng
--    bán kính 8 studs quanh chân, phím bị đạp chớp sáng hẳn, tắt dần khi rời.
--  • Giữ nguyên kiến trúc v4: WalkSurface phẳng, lò xo giảm chấn, swept detection,
--    ngân sách sound toàn cục 20/0.1s.
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
-- [OPT-25P] hiệu ứng chỉ chạy khi gần camera + ngân sách sound toàn cục (20/0.1s cho cả map)
local __cam = workspace.CurrentCamera
local function __fxOK(pos, dist)
	if (__cam.CFrame.Position - pos).Magnitude > (dist or 90) then return false end
	local t = os.clock()
	local b = _G.__asmrSndBudget
	if not b or t - b.t > 0.1 then b = { t = t, n = 0 }; _G.__asmrSndBudget = b end
	if b.n >= 20 then return false end
	b.n += 1
	return true
end

local model = script.Parent
local themes = model:WaitForChild("Clicky Keyboard Asmr"):WaitForChild("Themes")

-- ===== tinh chỉnh =====
local CELL = 3               -- phím 3x3
local KEY_REACH = 1.9        -- bán kính vuông ăn phím quanh chân
local FOOT_DROP = 3.05       -- root -> chân
local Y_TOLERANCE = 2.8      -- lệch cao độ tối đa để tính là đứng trên phím
local PRESS_DEPTH = 0.9      -- phím lún SÂU
local PULSE = 0.14           -- phím giữ trạng thái nhấn bao lâu sau lần chạm cuối
local SAMPLE_STEP = 1.4      -- bước quét dọc đường di chuyển
local MAX_SAMPLES = 40
local MAX_SOUNDS_PER_FRAME = 8
-- lò xo: nhấn cứng-nhanh, nhả mềm-nảy
local PRESS_K, PRESS_D = 1400, 42
local RELEASE_K, RELEASE_D = 330, 13
-- RGB glow (chỉ theme Plain)
local GLOW_THEME = "Plain"
local GLOW_RADIUS = 8
local GLOW_Y_TOL = 4.2

-- Click bàn phím cơ ProSoundEffects (0.24–0.33s), đã verify IsLoaded 2026-07-15.
local CLICK_IDS = { 9116158528, 9116158927, 9116158128, 9116158896, 9116157307, 9116158538 }

-- ===== đợi phím replicate xong =====
local function countKeys()
	local n = 0
	for _, theme in themes:GetChildren() do
		for _, k in theme:GetChildren() do
			if k:IsA("MeshPart") then n += 1 end
		end
	end
	return n
end
do
	local last = -1
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		local n = countKeys()
		if n > 0 and n == last then break end
		last = n
		task.wait(0.35)
	end
end

-- ===== thu thập phím + spatial hash =====
local keys = {}   -- danh sách record
local grid = {}   -- ["cx,cz"] = {record...}
for _, theme in themes:GetChildren() do
	local glowable = theme.Name == GLOW_THEME
	for _, k in theme:GetChildren() do
		if k:IsA("MeshPart") then
			local rec = {
				part = k,
				rest = k.CFrame,
				x = k.Position.X,
				z = k.Position.Z,
				topY = k.Position.Y + k.Size.Y / 2,
				stars = k:FindFirstChild("Stars"),
				-- trạng thái lò xo
				depth = 0, vel = 0,
				pulseUntil = 0, down = false,
				-- RGB glow
				glowable = glowable,
				glow = 0, glowTarget = 0,
				restColor = k.Color,
				restMaterial = k.Material,
			}
			table.insert(keys, rec)
			local cell = math.floor(rec.x / CELL) .. "," .. math.floor(rec.z / CELL)
			grid[cell] = grid[cell] or {}
			table.insert(grid[cell], rec)
		end
	end
end

local __REGION
do
	local x0, x1, z0, z1 = 1e9, -1e9, 1e9, -1e9
	for _, rec in keys do
		x0 = math.min(x0, rec.x); x1 = math.max(x1, rec.x)
		z0 = math.min(z0, rec.z); z1 = math.max(z1, rec.z)
	end
	__REGION = { x0 = x0 - 10, x1 = x1 + 10, z0 = z0 - 10, z1 = z1 + 10 }
end

-- ===== âm thanh: preload + WARM + pool =====
local POOL_N = 32
local pool = table.create(POOL_N)
local poolIdx = 0
for i = 1, POOL_N do
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. CLICK_IDS[(i - 1) % #CLICK_IDS + 1]
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 18
	s.RollOffMaxDistance = 70
	s.Parent = model
	pool[i] = s
end
task.spawn(function()
	local assets = {}
	for _, id in CLICK_IDS do table.insert(assets, "rbxassetid://" .. id) end
	pcall(function() ContentProvider:PreloadAsync(assets) end)
	-- WARM: phát 1 lần Volume=0 để audio engine decode sẵn — hết trễ lần phát đầu
	for _, id in CLICK_IDS do
		local w = Instance.new("Sound")
		w.SoundId = "rbxassetid://" .. id
		w.Volume = 0
		w.Parent = model
		w:Play()
		Debris:AddItem(w, 1.5)
	end
end)

-- Sparkle POOL (v5.1): phím zone không mang ParticleEmitter riêng (tiết kiệm ~30k instance) —
-- 12 emitter dùng chung dời tới phím vừa nhấn rồi Emit. Phím lobby có Stars thì dùng như cũ.
local STAR_N = 12
local starPool, starIdx = {}, 0
for i = 1, STAR_N do
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.4
	holder.CFrame = CFrame.new(0, -500, 0)
	holder.Parent = model
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
	em.Lifetime = NumberRange.new(0.25, 0.45)
	em.Speed = NumberRange.new(2.5, 5)
	em.SpreadAngle = Vector2.new(55, 55)
	em.EmissionDirection = Enum.NormalId.Top
	em.LightEmission = 1
	em.LightInfluence = 0
	em.Rate = 0
	em.Parent = holder
	starPool[i] = { holder = holder, em = em }
end

local function playKey(rec, speedRatio, volScale)
	if not __fxOK(rec.part.Position, 80) then return end
	if rec.stars then
		rec.stars:Emit(2)
	else
		starIdx = starIdx % STAR_N + 1
		local sp = starPool[starIdx]
		sp.holder.CFrame = CFrame.new(rec.x, rec.topY + 0.35, rec.z)
		sp.em:Emit(2)
	end
	poolIdx = poolIdx % POOL_N + 1
	local s = pool[poolIdx]
	if s.IsPlaying then s:Stop() end
	s.SoundId = "rbxassetid://" .. CLICK_IDS[math.random(#CLICK_IDS)]
	s.Volume = (0.5 + speedRatio * 0.45) * volScale
	s.PlaybackSpeed = 0.94 + speedRatio * 0.3 + (math.random() * 0.16 - 0.08)
	s.Parent = rec.part
	s:Play()
end

-- ===== dò phím quanh 1 điểm chân =====
local function touchKeysAt(px, py, pz, now, touched)
	local footY = py - FOOT_DROP
	local cx, cz = math.floor(px / CELL), math.floor(pz / CELL)
	for dx = -1, 1 do
		for dz = -1, 1 do
			local bucket = grid[(cx + dx) .. "," .. (cz + dz)]
			if bucket then
				for _, rec in bucket do
					if math.abs(px - rec.x) <= KEY_REACH
						and math.abs(pz - rec.z) <= KEY_REACH
						and math.abs(footY - rec.topY) <= Y_TOLERANCE then
						rec.pulseUntil = now + PULSE
						if not rec.down then touched[rec] = true end
					end
				end
			end
		end
	end
end

-- ===== vòng chính =====
local activeKeys = {}    -- set phím đang animate lò xo
local glowActive = {}    -- set phím đang sáng RGB
local lastPos = {}       -- [player] = Vector3

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()

	-- 1) INPUT: gom mọi phím bị chạm frame này (swept đầy đủ)
	local touched = {}   -- set rec vừa chuyển 0->1 (để phát sound)
	local ratioByRec = {}
	-- [LOCAL-ONLY] chỉ render hiệu ứng sàn của CHÍNH MÌNH
	for _, plr in { Players.LocalPlayer } do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (root and hum and hum.Health > 0) then
			lastPos[plr] = nil
			continue
		end
		local pos = root.Position
		if pos.X < __REGION.x0 or pos.X > __REGION.x1 or pos.Z < __REGION.z0 or pos.Z > __REGION.z1 then
			lastPos[plr] = nil
			continue
		end
		local vel = root.AssemblyLinearVelocity
		local ratio = math.clamp(Vector3.new(vel.X, 0, vel.Z).Magnitude / 250, 0, 1)

		local newTouched = {}
		touchKeysAt(pos.X, pos.Y, pos.Z, now, newTouched)
		local lp = lastPos[plr]
		if lp then
			local delta = pos - lp
			local dist = Vector3.new(delta.X, 0, delta.Z).Magnitude
			if dist > SAMPLE_STEP and dist < 150 then
				local steps = math.min(math.floor(dist / SAMPLE_STEP), MAX_SAMPLES)
				for i = 1, steps do
					local sp = lp:Lerp(pos, i / (steps + 1))
					touchKeysAt(sp.X, sp.Y, sp.Z, now, newTouched)
				end
			end
		end
		lastPos[plr] = pos
		for rec in newTouched do
			touched[rec] = true
			ratioByRec[rec] = math.max(ratioByRec[rec] or 0, ratio)
		end

		-- 1b) RGB GLOW target: vầng sáng quanh chân trên theme Plain
		local footY = pos.Y - FOOT_DROP
		local cx, cz = math.floor(pos.X / CELL), math.floor(pos.Z / CELL)
		local r = math.ceil(GLOW_RADIUS / CELL)
		for dx = -r, r do
			for dz = -r, r do
				local bucket = grid[(cx + dx) .. "," .. (cz + dz)]
				if bucket then
					for _, rec in bucket do
						if rec.glowable and math.abs(footY - rec.topY) <= GLOW_Y_TOL then
							local ddx, ddz = pos.X - rec.x, pos.Z - rec.z
							local d = math.sqrt(ddx * ddx + ddz * ddz)
							if d < GLOW_RADIUS then
								local t = 1 - d / GLOW_RADIUS
								local target = math.min(t * t * 1.35, 1)
								if target > rec.glowTarget then rec.glowTarget = target end
								glowActive[rec] = true
							end
						end
					end
				end
			end
		end
	end

	-- 2) SOUND: phát cho phím vừa nhấn, throttle + chia volume khi burst
	local burst = 0
	for rec in touched do burst += 1 end
	if burst > 0 then
		local volScale = burst > MAX_SOUNDS_PER_FRAME and (MAX_SOUNDS_PER_FRAME / burst) or 1
		local played = 0
		for rec in touched do
			rec.down = true
			activeKeys[rec] = true
			if rec.glowable then
				rec.glow = 1 -- phím bị đạp chớp sáng NGAY
				glowActive[rec] = true
			end
			if played < MAX_SOUNDS_PER_FRAME then
				played += 1
				playKey(rec, ratioByRec[rec] or 0, math.max(volScale, 0.45))
			end
		end
	end

	-- 3) SPRING ANIMATOR: tích phân lò xo cho mọi phím đang sống
	local step = math.min(dt, 1 / 30)
	for rec in activeKeys do
		local pressed = now < rec.pulseUntil
		if not pressed and rec.down then rec.down = false end
		local target = pressed and 1 or 0
		local k, d
		if pressed then k, d = PRESS_K, PRESS_D else k, d = RELEASE_K, RELEASE_D end
		local acc = k * (target - rec.depth) - d * rec.vel
		rec.vel += acc * step
		rec.depth += rec.vel * step
		if not pressed and math.abs(rec.depth) < 0.004 and math.abs(rec.vel) < 0.05 then
			rec.depth = 0
			rec.vel = 0
			rec.part.CFrame = rec.rest
			activeKeys[rec] = nil
		else
			local depth = math.clamp(rec.depth, -0.12, 1.08) -- cho phép nảy quá đà nhẹ
			rec.part.CFrame = rec.rest * CFrame.new(0, -PRESS_DEPTH * depth, 0)
		end
	end

	-- 4) RGB GLOW ANIMATOR: sáng nhanh, tắt mềm, hue cầu vồng chảy theo vị trí
	local clockHue = now * 0.13
	for rec in glowActive do
		local target = rec.glowTarget
		rec.glowTarget = 0
		local a = if target > rec.glow
			then 1 - math.exp(-14 * dt)
			else 1 - math.exp(-2.4 * dt)
		rec.glow += (target - rec.glow) * a
		if rec.glow < 0.015 and target == 0 then
			rec.glow = 0
			glowActive[rec] = nil
			rec.part.Color = rec.restColor
			rec.part.Material = rec.restMaterial
		else
			local hue = (clockHue + (rec.x + rec.z) * 0.018) % 1
			local bright = Color3.fromHSV(hue, 0.72, 1)
			rec.part.Color = rec.restColor:Lerp(bright, math.min(rec.glow, 1))
			rec.part.Material = if rec.glow > 0.22 then Enum.Material.Neon else rec.restMaterial
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastPos[plr] = nil
end)

print(("[ASMR Keyboard] v5 sẵn sàng — %d phím | %d click variant + pool %d | RGB glow '%s'"):format(
	#keys, #CLICK_IDS, POOL_N, GLOW_THEME))
