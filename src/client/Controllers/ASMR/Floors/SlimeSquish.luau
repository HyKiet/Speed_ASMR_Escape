-- SlimeSquish — 🟢 KHỐI JELLY TRONG SUỐT + SOFT BODY (Zone 14, theo ảnh mẫu user).
--
-- Look bắt buộc (ảnh mẫu): khối jelly Glass trong suốt, mặt trên PHẲNG TUYỆT ĐỐI (không sóng
-- tĩnh — user đã loại), mép bo tròn; player di chuyển tới đâu mặt jelly VÕNG XUỐNG quanh chân
-- tới đó rồi từ từ đầy lại. Chân lún trong jelly (Collider thấp hơn đỉnh khối).
--
-- Cách làm: mỗi model có 1 MeshPart `Tiles.SlimeTile` (spec + hình hiển thị trong Edit/server).
-- Client GIẤU nó bằng LocalTransparencyModifier=1 rồi dựng bản sao EditableMesh CÙNG kích
-- thước/màu/độ trong — mặt trên là lưới vertex CELL 3 để lõm cục bộ, thành + đáy khép khối
-- (DoubleSided nên không lo chiều mặt). Chỉ vertex quanh chân được ghi mỗi frame (active map
-- + ngưỡng), đứng yên ngoài sàn = 0 chi phí.
--
-- Hợp đồng model (tag ASMRFloor + FloorType="SlimeSquish", nên Atomic):
--   • `Tiles.SlimeTile` (MeshPart) — khối jelly gốc: kích thước/màu/Transparency là nguồn sự thật.
--   • `Collider` (BasePart, CanCollide) — mặt đi bộ thật, top thấp hơn đỉnh khối (chân lún).
-- Attribute tinh chỉnh (không cần sửa code): `Fillet`, `DentRadius`, `DentDepth`.

local AssetService = game:GetService("AssetService")

local SlimeSquish = {}

-- Palette slime êm (đã vet): random mỗi bước, binaural qua SoundPool.playStep
local STEP_SOUNDS = { 133222321566847, 76169806288463, 9114631918, 9114520014 }
SlimeSquish.soundIds = STEP_SOUNDS

local CELL = 3 -- cạnh ô lưới vertex mặt trên
-- ⚠️ Mesh của `Tiles.SlimeTile` KHÔNG deform được: `CreateEditableMeshAsync` trả
-- "no permission to load asset" với mesh không thuộc tài khoản đang chạy. Nên client dựng
-- khối bo mép riêng theo ĐÚNG size/màu/độ trong của tile (mesh gốc chỉ còn tác dụng ở
-- Edit/server view). Muốn dáng khác thì chỉnh 3 attribute, hoặc upload mesh vào chính
-- tài khoản game rồi mới deform trực tiếp được.
local FILLET = 2.2 -- bán kính bo mép (lip tròn dày như jelly trong ảnh)
-- 2026-07-26 (feedback user "lún cần nhanh + to hơn"): R 7→8.5, DEPTH 1.35→2.0, K 110→200
local DENT_R = 8.5 -- bán kính vết lõm quanh chân
local DENT_DEPTH = 2.0 -- độ sâu lõm tại tâm

-- ── SOFT BODY (mass-spring lattice trên lưới mặt trên) ──
-- Mỗi vertex = 1 chất điểm có lò xo về vị trí nghỉ + LIÊN KẾT với 4 vertex kề →
-- dậm chân tạo sóng gợn LAN RA, đáp mạnh làm cả vùng rung như thạch thật.
--   y'' = K·(target − y) + C·(trung bình kề − y) − D·y'
local SPRING_K = 200 -- lò xo về target (cứng = bám chân gần như tức thì)
local SPRING_D = 7 -- giảm chấn (< 2√K = dưới tới hạn → rung 3-4 nhịp kiểu jello)
local COUPLE_C = 230 -- liên kết vertex kề (tốc độ lan sóng)
local LAND_KICK = 30 -- studs/s vận tốc bơm vào mặt jelly khi đáp (nhân theo lực rơi)
local SPREAD_EPS = 0.04 -- |disp| vượt mức này thì đánh thức vertex kề (sóng lan)
local SLEEP_DISP = 0.012 -- ngủ khi lệch + vận tốc đều nhỏ
local SLEEP_VEL = 0.06
local MAX_ACTIVE = 1400 -- trần vertex sống (an toàn hiệu năng)
local MAX_DT = 1 / 30 -- kẹp dt tích phân (chống nổ khi frame hitch)

local FOOT_DROP = 3.2 -- root.Y − 3.2 ≈ cao độ bàn chân
local Y_TOL = 4.5

function SlimeSquish.attach(model, engine)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }

	-- Per-model override (chỉnh trong Studio, không cần sửa code)
	local fillet = tonumber(model:GetAttribute("Fillet")) or FILLET
	local dentR = tonumber(model:GetAttribute("DentRadius")) or DENT_R
	local dentDepth = tonumber(model:GetAttribute("DentDepth")) or DENT_DEPTH

	local box = nil
	local walkTop = 0
	local tile: MeshPart? = nil
	local skin: MeshPart? = nil
	local em = nil
	-- Chống build "zombie": watchdog engine có thể detach/re-attach TRONG LÚC coroutine build
	-- cũ còn treo ở WaitForChild/CreateMeshPartAsync — không có cờ này thì instance cũ tỉnh dậy
	-- tạo skin THỨ HAI đè lên bản mới (đã dính: Slime14_1 ×2 skin, 1 model mất skin).
	local destroyed = false

	-- lưới mặt trên
	local nx, nz = 0, 0
	local px, pz = 1, 1
	local x0, z0 = 0, 0 -- mép tây/bắc lưới (world)
	local center = Vector3.zero
	local vids, nids, rest = {}, {}, {}
	local disp, vel = {}, {} -- trạng thái soft body: độ lệch xuống (+) và vận tốc từng vertex
	local active: { [string]: boolean } = {}
	local activeCount = 0

	local function edgeDrop(wx: number, wz: number, minX: number, maxX: number, minZ: number, maxZ: number): number
		-- bo mép: vertex trong dải fillet quanh rìa tụt xuống theo cung 1/4 tròn
		local d = math.min(wx - minX, maxX - wx, wz - minZ, maxZ - wz)
		if d >= fillet then
			return 0
		end
		local e = fillet - math.max(d, 0)
		return fillet - math.sqrt(math.max(fillet * fillet - e * e, 0))
	end

	local function build(): boolean
		local t = tile :: MeshPart
		local size = t.Size
		center = t.Position
		local topY = center.Y + size.Y / 2
		local bottomY = center.Y - size.Y / 2
		local minX, maxX = center.X - size.X / 2, center.X + size.X / 2
		local minZ, maxZ = center.Z - size.Z / 2, center.Z + size.Z / 2

		nx = math.max(math.floor(size.X / CELL + 0.5), 2)
		nz = math.max(math.floor(size.Z / CELL + 0.5), 2)
		px, pz = size.X / nx, size.Z / nz
		x0, z0 = minX, minZ
		table.clear(active)
		activeCount = 0

		local ok, emOrErr = pcall(function()
			return AssetService:CreateEditableMesh()
		end)
		if not ok then
			warn("[ASMR SlimeSquish] CreateEditableMesh lỗi:", emOrErr)
			return false
		end
		em = emOrErr

		-- 1) MẶT TRÊN: lưới phẳng (chỉ mép bo tròn) — mọi tọa độ LOCAL quanh tâm khối
		vids, nids, rest, disp, vel = {}, {}, {}, {}, {}
		for i = 0, nx do
			vids[i], nids[i], rest[i], disp[i], vel[i] = {}, {}, {}, {}, {}
			for j = 0, nz do
				local wx, wz = x0 + i * px, z0 + j * pz
				local ry = topY - edgeDrop(wx, wz, minX, maxX, minZ, maxZ)
				rest[i][j] = ry
				disp[i][j] = 0
				vel[i][j] = 0
				vids[i][j] = em:AddVertex(Vector3.new(wx - center.X, ry - center.Y, wz - center.Z))
				nids[i][j] = em:AddNormal(Vector3.yAxis)
			end
		end
		for i = 0, nx - 1 do
			for j = 0, nz - 1 do
				local f1 = em:AddTriangle(vids[i][j], vids[i][j + 1], vids[i + 1][j])
				em:SetFaceNormals(f1, { nids[i][j], nids[i][j + 1], nids[i + 1][j] })
				local f2 = em:AddTriangle(vids[i + 1][j], vids[i][j + 1], vids[i + 1][j + 1])
				em:SetFaceNormals(f2, { nids[i + 1][j], nids[i][j + 1], nids[i + 1][j + 1] })
			end
		end

		-- 2) THÀNH + ĐÁY: vòng perimeter mặt trên nối xuống vòng đáy, đáy fan về tâm.
		-- DoubleSided trên part nên thứ tự đỉnh tam giác không thành vấn đề.
		local ring = {} -- {i, j} theo chu vi
		for i = 0, nx do
			table.insert(ring, { i, 0 })
		end
		for j = 1, nz do
			table.insert(ring, { nx, j })
		end
		for i = nx - 1, 0, -1 do
			table.insert(ring, { i, nz })
		end
		for j = nz - 1, 1, -1 do
			table.insert(ring, { 0, j })
		end

		local botVids, botNids = {}, {}
		for k, ij in ring do
			local wx, wz = x0 + ij[1] * px, z0 + ij[2] * pz
			botVids[k] = em:AddVertex(Vector3.new(wx - center.X, bottomY - center.Y, wz - center.Z))
			local out = Vector3.new(wx - center.X, 0, wz - center.Z)
			botNids[k] = em:AddNormal(if out.Magnitude > 1e-3 then out.Unit else Vector3.xAxis)
		end
		local n = #ring
		for k = 1, n do
			local k2 = k % n + 1
			local a, b = ring[k], ring[k2]
			local ta, tb = vids[a[1]][a[2]], vids[b[1]][b[2]]
			local na, nb = nids[a[1]][a[2]], nids[b[1]][b[2]]
			local f1 = em:AddTriangle(ta, tb, botVids[k])
			em:SetFaceNormals(f1, { na, nb, botNids[k] })
			local f2 = em:AddTriangle(tb, botVids[k2], botVids[k])
			em:SetFaceNormals(f2, { nb, botNids[k2], botNids[k] })
		end
		local botCenter = em:AddVertex(Vector3.new(0, bottomY - center.Y, 0))
		local botCenterN = em:AddNormal(Vector3.new(0, -1, 0))
		for k = 1, n do
			local k2 = k % n + 1
			local f = em:AddTriangle(botCenter, botVids[k2], botVids[k])
			em:SetFaceNormals(f, { botCenterN, botNids[k2], botNids[k] })
		end

		local okPart, partOrErr = pcall(function()
			-- selene: allow(undefined_variable) — `Content` là global Roblox, selene stdlib chưa cập nhật
			return AssetService:CreateMeshPartAsync(Content.fromObject(em))
		end)
		if not okPart then
			warn("[ASMR SlimeSquish] CreateMeshPartAsync lỗi:", partOrErr)
			return false
		end
		local part = partOrErr
		if destroyed then
			part:Destroy()
			return false
		end
		part.Name = "SlimeSquishSkin"
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.DoubleSided = true
		-- look = COPY Y NGUYÊN từ khối gốc (Glass trong suốt như ảnh)
		part.Material = t.Material
		part.Transparency = t.Transparency
		part.Color = t.Color
		part.Reflectance = t.Reflectance
		part.CFrame = CFrame.new(center)

		local folder = workspace:FindFirstChild("SlimeSquishSkins")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "SlimeSquishSkins"
			folder.Parent = workspace
		end
		-- dọn MỌI skin cùng Owner ngay trước khi gắn (kể cả skin do bản attach trước để lại)
		for _, c in folder:GetChildren() do
			if c:GetAttribute("Owner") == model:GetFullName() then
				c:Destroy()
			end
		end
		part:SetAttribute("Owner", model:GetFullName())
		part.Parent = folder
		skin = part

		-- giấu khối gốc CHỈ trên client này (stream-out/in tự sạch, server/Edit giữ nguyên hình)
		t.LocalTransparencyModifier = 1
		return true
	end

	task.spawn(function()
		local tilesFolder = model:WaitForChild("Tiles", 10)
		local collider = model:WaitForChild("Collider", 10)
		if destroyed or not (tilesFolder and collider and collider:IsA("BasePart")) then
			return
		end
		engine.Await.childrenStable(tilesFolder)
		if destroyed then
			return
		end
		local t = tilesFolder:FindFirstChild("SlimeTile")
		if not (t and t:IsA("MeshPart")) then
			return
		end
		tile = t

		walkTop = collider.Position.Y + collider.Size.Y / 2
		box = Bounds.ofBase(collider, 4)

		self.ready = build() and box ~= nil
		if self.ready then
			print(("[ASMR SlimeSquish] khối jelly sẵn sàng — lưới %dx%d, lõm R%.1f sâu %.2f"):format(nx, nz, dentR, dentDepth))
		end
	end)

	local function playSquish(pos: Vector3, vol: number)
		if not FxBudget.fxOK(pos) then
			return
		end
		SoundPool.playStep(STEP_SOUNDS[math.random(#STEP_SOUNDS)], pos, vol, 0.86 + math.random() * 0.18, 80)
	end

	local function writeVertex(i: number, j: number)
		local y = rest[i][j] - disp[i][j]
		local wx, wz = x0 + i * px, z0 + j * pz
		em:SetPosition(vids[i][j], Vector3.new(wx - center.X, y - center.Y, wz - center.Z))
	end

	local function writeNormal(i: number, j: number)
		local function yAt(ii: number, jj: number): number
			ii = math.clamp(ii, 0, nx)
			jj = math.clamp(jj, 0, nz)
			return rest[ii][jj] - disp[ii][jj]
		end
		local ddx = (yAt(i + 1, j) - yAt(i - 1, j)) / (2 * px)
		local ddz = (yAt(i, j + 1) - yAt(i, j - 1)) / (2 * pz)
		em:SetNormal(nids[i][j], Vector3.new(-ddx, 1, -ddz).Unit)
	end

	local function wake(i: number, j: number)
		local key = i .. "," .. j
		if not active[key] and activeCount < MAX_ACTIVE then
			active[key] = true
			activeCount += 1
		end
	end

	local onFloor = false
	local stepLast, stepDist = nil, 0
	local lastDebugT = 0

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		-- debug/QA: số vertex đang mô phỏng + độ lún sâu nhất (throttle 0.3s).
		-- Đây là cách DUY NHẤT quan sát trạng thái EditableMesh từ ngoài adapter.
		if now - lastDebugT > 0.3 then
			lastDebugT = now
			if model:GetAttribute("SSActive") ~= activeCount then
				model:SetAttribute("SSActive", activeCount)
			end
			local deepest = 0
			for key in active do
				local sep = string.find(key, ",", 1, true) :: number
				local i = tonumber(string.sub(key, 1, sep - 1)) :: number
				local j = tonumber(string.sub(key, sep + 1)) :: number
				if disp[i][j] > deepest then
					deepest = disp[i][j]
				end
			end
			model:SetAttribute("SSDepth", math.floor(deepest * 100) / 100)
		end

		local footPos: Vector3? = nil
		local landVy = 0
		if foot then
			local pos = foot.pos
			if engine.Bounds.contains(box, pos) and math.abs((pos.Y - FOOT_DROP) - walkTop) < Y_TOL then
				footPos = pos
				if not onFloor then
					onFloor = true
					stepLast, stepDist = pos, 0
					-- lực đáp: vận tốc rơi bơm thẳng vào mặt jelly → splash rung lan
					landVy = math.clamp(math.abs(foot.vel.Y), 0, 60)
					playSquish(pos, 0.55 + 0.3 * (landVy / 60))
				end
				if stepLast then
					local d = pos - stepLast
					stepDist += Vector3.new(d.X, 0, d.Z).Magnitude
				end
				stepLast = pos
				if stepDist >= 2.2 then
					stepDist = 0
					playSquish(pos, 0.55)
				end
			else
				onFloor = false
			end
		else
			onFloor = false
		end

		-- soft body ngủ toàn phần + không chân trên sàn → 0 chi phí
		if footPos == nil and activeCount == 0 then
			return
		end

		local h = math.min(dt, MAX_DT) -- kẹp bước tích phân (chống nổ khi frame hitch)
		local r2 = dentR * dentR

		-- 1) đánh thức vùng quanh chân (+ bơm xung đáp nếu vừa chạm)
		if footPos then
			local iMin = math.max(math.floor((footPos.X - dentR - x0) / px), 0)
			local iMax = math.min(math.ceil((footPos.X + dentR - x0) / px), nx)
			local jMin = math.max(math.floor((footPos.Z - dentR - z0) / pz), 0)
			local jMax = math.min(math.ceil((footPos.Z + dentR - z0) / pz), nz)
			for i = iMin, iMax do
				for j = jMin, jMax do
					local dx = x0 + i * px - footPos.X
					local dz = z0 + j * pz - footPos.Z
					local d2 = dx * dx + dz * dz
					if d2 < r2 then
						wake(i, j)
						if landVy > 0 then
							local w = 1 - d2 / r2
							vel[i][j] += LAND_KICK * (landVy / 60) * w * w
						end
					end
				end
			end
		end

		-- 2) tích phân mass-spring: lò xo về target + liên kết 4 kề + giảm chấn
		local touched = {}
		local spread = {} -- vertex kề cần đánh thức (không sửa `active` khi đang duyệt)
		for key in active do
			local sep = string.find(key, ",", 1, true) :: number
			local i = tonumber(string.sub(key, 1, sep - 1)) :: number
			local j = tonumber(string.sub(key, sep + 1)) :: number

			-- target lõm dưới chân (0 khi chân rời)
			local target = 0
			if footPos then
				local dx = x0 + i * px - footPos.X
				local dz = z0 + j * pz - footPos.Z
				local d2 = dx * dx + dz * dz
				if d2 < r2 then
					local w = 1 - d2 / r2
					target = dentDepth * w * w
				end
			end

			-- laplacian rời rạc: kéo về trung bình 4 vertex kề → sóng lan
			local dc = disp[i][j]
			local sum, cnt = 0, 0
			if i > 0 then
				sum += disp[i - 1][j]
				cnt += 1
			end
			if i < nx then
				sum += disp[i + 1][j]
				cnt += 1
			end
			if j > 0 then
				sum += disp[i][j - 1]
				cnt += 1
			end
			if j < nz then
				sum += disp[i][j + 1]
				cnt += 1
			end
			local lap = sum / cnt - dc

			local v = vel[i][j] + (SPRING_K * (target - dc) + COUPLE_C * lap - SPRING_D * vel[i][j]) * h
			local d = math.clamp(dc + v * h, -0.9, dentDepth + 0.8)
			vel[i][j] = v
			disp[i][j] = d

			if target == 0 and math.abs(d) < SLEEP_DISP and math.abs(v) < SLEEP_VEL then
				-- ngủ: về đúng nghỉ, ghi lần cuối
				disp[i][j] = 0
				vel[i][j] = 0
				active[key] = nil
				activeCount -= 1
			elseif math.abs(d) > SPREAD_EPS then
				-- sóng đủ mạnh → đánh thức 4 kề để tiếp tục lan
				table.insert(spread, i)
				table.insert(spread, j)
			end

			writeVertex(i, j)
			touched[key] = true
			for di = -1, 1 do
				for dj = -1, 1 do
					local ni, nj = i + di, j + dj
					if ni >= 0 and ni <= nx and nj >= 0 and nj <= nz then
						touched[ni .. "," .. nj] = true
					end
				end
			end
		end
		for k = 1, #spread, 2 do
			local i, j = spread[k], spread[k + 1]
			if i > 0 then
				wake(i - 1, j)
			end
			if i < nx then
				wake(i + 1, j)
			end
			if j > 0 then
				wake(i, j - 1)
			end
			if j < nz then
				wake(i, j + 1)
			end
		end

		for key in touched do
			local sep = string.find(key, ",", 1, true) :: number
			writeNormal(tonumber(string.sub(key, 1, sep - 1)) :: number, tonumber(string.sub(key, sep + 1)) :: number)
		end
	end

	function self.destroy()
		destroyed = true
		if skin then
			skin:Destroy()
			skin = nil
		end
		if tile then
			tile.LocalTransparencyModifier = 0
		end
	end

	return self
end

return SlimeSquish
