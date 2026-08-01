--!nocheck
--------------------------------------------------------------------------------
-- Zone 15 — dựng WalkSurface cho mọi bàn phím ASMR (chạy qua execute_luau, Edit).
--
-- BỐI CẢNH: user tự sắp xếp lại/xoay/nghiêng các model KB15_* trong Zone15.ASMR.
-- Phím CanCollide=false nên mặt đi bộ phải là 1 part phẳng riêng — đúng quy ước
-- của `KB_Transition14To15` (bàn ngay trước Zone 15):
--      walkTop = keyTop - 0.97   (phím nhô 0.97 trên mặt đi, chìm 1.03 xuống dưới)
--
-- Mọi bàn đều có KHUNG RIÊNG (yaw 90/80, pitch ±30, roll 12/20) ⇒ WalkSurface phải
-- lấy rotation từ chính phím, và bounds tính trong KHÔNG GIAN BÀN, không phải AABB
-- thế giới (AABB của bàn nghiêng 30° sẽ thừa ra hàng chục stud ngoài mép).
--
-- WalkSurface cũng là KHUNG THAM CHIẾU của KeyboardLabelController v6 (suy hàng/cột
-- kí tự qua walk.CFrame:Inverse()) — không có nó thì bàn không bao giờ có chữ.
--
-- Idempotent: chạy lại là xoá WalkSurface cũ rồi dựng lại.
--------------------------------------------------------------------------------

local WALK_DROP = 0.97 -- keyTop - WALK_DROP = mặt đi bộ
local THICK = 0.4
local MIN_KEYS_FOR_COLLIDE = 4 -- bàn 1-2 phím (trang trí trên Gate) không được thành sàn

local asmr = workspace.Zones.Zone15.ASMR
local log, made, skipped = {}, 0, 0

for _, model in asmr:GetChildren() do
	local container = model:FindFirstChild("Clicky Keyboard Asmr")
	local themes = container and container:FindFirstChild("Themes")
	if not themes then
		continue
	end

	local keys = {}
	for _, theme in themes:GetChildren() do
		for _, k in theme:GetChildren() do
			if k:IsA("BasePart") then
				table.insert(keys, k)
			end
		end
	end
	if #keys == 0 then
		continue
	end

	-- WalkSurface do người/bản dựng cũ đặt tay (vd KB_Transition14To15, footprint nới rộng
	-- hơn vùng phím) thì GIỮ NGUYÊN — chỉ dựng lại cái do script này sinh (attr AutoWalk).
	local old = model:FindFirstChild("WalkSurface")
	if old then
		if not old:GetAttribute("AutoWalk") then
			table.insert(log, model.Name .. " — giữ WalkSurface có sẵn")
			continue
		end
		old:Destroy()
	end

	-- khung của bàn = rotation của phím (mọi phím trong 1 model cùng orientation)
	local rot = keys[1].CFrame.Rotation
	local inv = rot:Inverse()

	local minX, maxX, minY, maxY, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	local kx, ky, kz = 0, 0, 0
	for _, k in keys do
		local o = inv * k.Position
		minX, maxX = math.min(minX, o.X), math.max(maxX, o.X)
		minY, maxY = math.min(minY, o.Y), math.max(maxY, o.Y)
		minZ, maxZ = math.min(minZ, o.Z), math.max(maxZ, o.Z)
		kx, ky, kz = math.max(kx, k.Size.X), math.max(ky, k.Size.Y), math.max(kz, k.Size.Z)
	end

	local topLocal = (minY + maxY) / 2 + ky / 2 -- mặt trên phím trong khung bàn
	local centerLocal = Vector3.new((minX + maxX) / 2, topLocal - WALK_DROP - THICK / 2, (minZ + maxZ) / 2)

	local w = Instance.new("Part")
	w.Name = "WalkSurface"
	w.Size = Vector3.new(maxX - minX + kx, THICK, maxZ - minZ + kz)
	w.CFrame = rot + (rot * centerLocal)
	w.Transparency = 1
	w.Anchored = true
	w.CanCollide = #keys >= MIN_KEYS_FOR_COLLIDE
	w.CanTouch = false
	w.CanQuery = false
	w.CastShadow = false
	w.Massless = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w:SetAttribute("AutoWalk", true)
	w.Parent = model

	made += 1
	if not w.CanCollide then
		skipped += 1
	end
	table.insert(
		log,
		string.format(
			"%s keys=%d size=%.1fx%.1f walkTop=%.2f flat=%.3f coll=%s",
			model.Name,
			#keys,
			w.Size.X,
			w.Size.Z,
			(w.CFrame * Vector3.new(0, THICK / 2, 0)).Y,
			maxY - minY,
			tostring(w.CanCollide)
		)
	)
end

--------------------------------------------------------------------------------
-- PHẦN 2 — LabelYaw: hướng chữ trên phím (KeyboardLabelController đọc attribute này)
--
-- SurfaceGui Face=Top lấy "đỉnh chữ" theo trục -Z CỦA CHÍNH PHÍM. User xoay model tuỳ ý
-- (yaw 0/±90/80) nên chữ mỗi đoạn quay một kiểu. Quy ước chốt: **đỉnh chữ hướng theo
-- CHIỀU CHẠY** ⇒ nhìn dọc hành lang là chữ đọc xuôi (đã verify ảnh tại đoạn 1).
--     LabelYaw = deg(atan2((run × keyLook).Y, keyLook · run)) làm tròn về bội 90
--------------------------------------------------------------------------------

local function runDir(cx: number, cz: number): Vector3
	if cz < 3100 then
		return Vector3.new(1, 0, 0) -- đoạn 1: hành lang Z~3029, chạy +X
	end
	if cx < 3400 then
		return Vector3.new(0, 0, 1) -- đoạn 2: hành lang X~3300, chạy +Z
	end
	if cz > 3700 and cx < 5440 then
		return Vector3.new(1, 0, 0) -- đoạn 3: hành lang Z~3766, chạy +X
	end
	if cx >= 5440 and cx <= 5540 then
		return Vector3.new(0, 0, -1) -- khúc quẹo chéo Z3766 → Z3499
	end
	return Vector3.new(1, 0, 0) -- đoạn 4 + khu về đích
end

for _, model in asmr:GetChildren() do
	local w = model:FindFirstChild("WalkSurface")
	local cont = model:FindFirstChild("Clicky Keyboard Asmr")
	if not (w and cont) then
		continue
	end
	local key
	for _, themes in cont:GetChildren() do
		for _, theme in themes:GetChildren() do
			for _, k in theme:GetChildren() do
				if k:IsA("MeshPart") then
					key = k
					break
				end
			end
		end
	end
	if not key then
		continue
	end

	local d = runDir(w.Position.X, w.Position.Z)
	local u = key.CFrame.LookVector
	u = Vector3.new(u.X, 0, u.Z)
	u = if u.Magnitude < 1e-3 then Vector3.new(0, 0, -1) else u.Unit
	local ang = math.deg(math.atan2(d:Cross(u).Y, u:Dot(d)))
	model:SetAttribute("LabelYaw", (math.round(ang / 90) * 90) % 360)
end

return string.format("WalkSurface dựng %d (trong đó %d không collide)\n%s", made, skipped, table.concat(log, "\n"))
