-- build_asmr_squish_floors.luau — dựng 3 sàn ASMR squish trong Workspace.Lobby.ASMR.ASMR_Test,
-- lấp 3 slot trống trên Boardwalk (hàng sàn dọc trục X, Z=126, slot cách 44 studs):
--   💧 CrystalDropFloor (FloorType=CrystalDrop) X=308 — ô pha lê Glass sáng bừng khi dậm, plink giọt nước
--   🦆 SqueakyDuckFloor (FloorType=SqueakyDuck) X=352 — đĩa cao su vàng vịt, squeeze toy chít chít
--   🧽 SlimeJellyFloor  (FloorType=SlimeJelly)  X=484 — khối slime bóng xanh lá
--
-- Chạy qua execute_luau (MCP) hoặc paste vào Command Bar. Idempotent. Nhớ SAVE PLACE.
--
-- Chuẩn hiệu năng (khớp adapter SquishFloor phía client):
--   • Tile: Anchored, CanCollide/CanTouch/CanQuery=false, CastShadow=false, thuần BasePart
--     — KHÔNG SurfaceGui/Sound/Script/ParticleEmitter con.
--   • Mỗi model 1 "Collider" đi được (36×0.9×36, cao độ y hệt ClayFloor).
--   • Tag "ASMRFloor" + attribute FloorType → engine client tự attach.

local CollectionService = game:GetService("CollectionService")

local asmrTest = workspace:WaitForChild("Lobby"):WaitForChild("ASMR"):WaitForChild("ASMR_Test")
local clayCollider = asmrTest.ClayFloor.Collider -- chuẩn cao độ chung của hàng sàn
local COL_Y = clayCollider.Position.Y -- 8.45
local TOP_Y = COL_Y + clayCollider.Size.Y / 2 -- 8.9: mặt trên collider, tile nổi +0.02
local ROW_Z = 126
local FLOOR_W = 36

-- Sign mẫu để nhân bản biển tên
local signTemplate
for _, c in asmrTest:GetChildren() do
	if c.Name == "Sign" and math.abs(c.Position.X - 132) < 1 then
		signTemplate = c
		break
	end
end

local function stripFlags(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
end

local function makeFloor(name, floorType, signText, colliderColor, colliderMat, cx)
	local old = asmrTest:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	-- dọn sign cũ cùng vị trí (nếu chạy lại)
	for _, c in asmrTest:GetChildren() do
		if c.Name == "Sign" and math.abs(c.Position.X - cx) < 1 then
			c:Destroy()
		end
	end

	local model = Instance.new("Model")
	model.Name = name
	-- Atomic: StreamingEnabled — sàn xa spawn phải stream về nguyên khối, nếu không
	-- Tiles rỗng khi client attach (bài học MelodyRun/SlimeJelly 0 ô)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local collider = Instance.new("Part")
	collider.Name = "Collider"
	collider.Size = Vector3.new(FLOOR_W, clayCollider.Size.Y, FLOOR_W)
	collider.Position = Vector3.new(cx, COL_Y, ROW_Z)
	collider.Anchored = true
	collider.CanCollide = true
	collider.CanTouch = false
	collider.CastShadow = false
	collider.Color = colliderColor
	collider.Material = colliderMat
	collider.Parent = model

	local tiles = Instance.new("Folder")
	tiles.Name = "Tiles"
	tiles.Parent = model

	model.Parent = asmrTest
	model:SetAttribute("FloorType", floorType)
	CollectionService:AddTag(model, "ASMRFloor")

	if signTemplate then
		local sign = signTemplate:Clone()
		sign.Position = Vector3.new(cx, signTemplate.Position.Y, signTemplate.Position.Z)
		local label = sign:FindFirstChildWhichIsA("TextLabel", true)
		if label then
			label.Text = signText
		end
		sign.Parent = asmrTest
	end
	return model, tiles
end

local rng = Random.new(20260718)

-- ============ 💧 CrystalDropFloor @ X=308: ô pha lê Glass sáng bừng khi dậm ============
do
	local CX = 308
	local model, tiles = makeFloor(
		"CrystalDropFloor", "CrystalDrop", "CRYSTAL DROP",
		Color3.fromRGB(30, 48, 74), Enum.Material.Slate, CX
	)
	local TILE, PITCH, H = 3.6, 4.0, 1.0
	local half = FLOOR_W / 2 - TILE / 2
	local n = 0
	for x = -half, half, PITCH do
		for z = -half, half, PITCH do
			local gem = Instance.new("Part")
			gem.Name = "Crystal"
			gem.Size = Vector3.new(TILE, H, TILE)
			gem.CFrame = CFrame.new(CX + x, TOP_Y + 0.02 + H / 2, ROW_Z + z)
				* CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0)
			-- tông pha lê xanh sâu — khi dậm sẽ Lerp lên cyan sáng (adapter litColor)
			gem.Color = Color3.fromRGB(40 + rng:NextInteger(0, 45), 90 + rng:NextInteger(0, 60), 200 + rng:NextInteger(0, 55))
			gem.Material = Enum.Material.Glass
			gem.Transparency = 0.25
			gem.Reflectance = 0.18
			stripFlags(gem)
			gem.Parent = tiles
			n += 1
		end
	end
	print(("[Builder] %s — %d ô pha lê"):format(model.Name, n))
end

-- ============ 🦆 SqueakyDuckFloor @ X=352: đĩa cao su vàng vịt, cylinder dựng đứng ============
do
	local CX = 352
	local model, tiles = makeFloor(
		"SqueakyDuckFloor", "SqueakyDuck", "DUCK SQUEAK",
		Color3.fromRGB(255, 140, 25), Enum.Material.SmoothPlastic, CX
	)
	local DIA, H = 3.9, 1.6
	local DX, DZ = 4.15, 3.6 -- lưới offset: hàng lẻ dịch DX/2 cho ken dày
	local half = FLOOR_W / 2 - DIA / 2
	local n, row = 0, 0
	local z = -half
	while z <= half do
		local x = -half + ((row % 2 == 1) and DX / 2 or 0)
		while x <= half do
			local duck = Instance.new("Part")
			duck.Shape = Enum.PartType.Cylinder
			duck.Name = "Duck"
			duck.Size = Vector3.new(H, DIA, DIA) -- trục cylinder = X → dựng đứng bằng rotation
			duck.CFrame = CFrame.new(CX + x, TOP_Y + 0.02 + H / 2, ROW_Z + z) * CFrame.Angles(0, 0, math.rad(90))
			-- vàng vịt cao su bóng, rải vài đĩa cam mỏ vịt
			duck.Color = if rng:NextNumber() < 0.12
				then Color3.fromRGB(255, 138 + rng:NextInteger(0, 25), 25)
				else Color3.fromRGB(255, 200 + rng:NextInteger(0, 35), 20 + rng:NextInteger(0, 40))
			duck.Material = Enum.Material.SmoothPlastic
			duck.Reflectance = 0.1
			stripFlags(duck)
			duck.Parent = tiles
			n += 1
			x += DX
		end
		row += 1
		z += DZ
	end
	print(("[Builder] %s — %d đĩa cao su vịt"):format(model.Name, n))
end

-- ============ 🧽 SlimeJellyFloor @ X=484: khối slime bóng xanh lá ============
do
	local CX = 484
	local model, tiles = makeFloor(
		"SlimeJellyFloor", "SlimeJelly", "SLIME SQUISH",
		Color3.fromRGB(40, 90, 35), Enum.Material.Grass, CX
	)
	local TILE, PITCH, H = 4.0, 4.15, 1.6
	local half = FLOOR_W / 2 - TILE / 2
	local n = 0
	for x = -half, half, PITCH do
		for z = -half, half, PITCH do
			local slime = Instance.new("Part")
			slime.Name = "Slime"
			slime.Size = Vector3.new(TILE, H, TILE)
			slime.Position = Vector3.new(CX + x, TOP_Y + 0.02 + H / 2, ROW_Z + z)
			slime.Color = Color3.fromRGB(85 + rng:NextInteger(0, 45), 220 + rng:NextInteger(0, 35), 60 + rng:NextInteger(0, 50))
			slime.Material = if rng:NextNumber() < 0.25 then Enum.Material.Neon else Enum.Material.SmoothPlastic
			slime.Transparency = 0.15
			slime.Reflectance = 0.06
			stripFlags(slime)
			slime.Parent = tiles
			n += 1
		end
	end
	print(("[Builder] %s — %d khối slime"):format(model.Name, n))
end

print("[Builder] Xong 3 sàn squish mới trong ASMR_Test — nhớ SAVE PLACE!")
