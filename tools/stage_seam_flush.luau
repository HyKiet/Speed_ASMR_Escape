--[[
	stage_seam_flush.luau — vá mạch chạy tại mọi vạch Stage{N}Start / Stage{N}Finish.
	Chạy bằng execute_luau (Edit mode). Đã chạy thật 2026-07-28, kết quả: 29/30 vạch phẳng.

	VẤN ĐỀ ĐO ĐƯỢC
	  Mặt trên part vạch stage nằm THẤP HƠN WalkSurface của sàn ASMR hai bên 0.35–1.0 stud,
	  kéo dài 4–7 stud ngang trọn hành lang, ở CẢ 30 vạch. Chạy qua = tụt một bậc rồi leo
	  lại — ở 250+ WalkSpeed nhân vật rời mặt đất vài frame ⇒ khựng hình và đứt tiếng sàn
	  ASMR (vì WalkSurface gián đoạn). Đúng triệu chứng "chạy không liền mạch".

	BA PHA
	  1. NÂNG VẠCH — giữ đáy, tăng Size.Y cho mặt trên bằng mặt sàn cao nhất trong hai bên
	     (bỏ qua khi chênh > MAX_LIFT: đó là hố KillBlock / bậc xuống nước, thiết kế thật).
	     Nới thân dọc trục chạy nếu còn dải trũng hẹp dính liền (≤ MAX_WIDEN).
	  2. DỐC THOẢI — chỗ nào sàn ASMR (vd 9.00) nối nền obby (8.00) thì bậc là CHÊNH SÀN,
	     nâng vạch chỉ dời bậc chứ không xoá. Dựng part vô hình nghiêng ~5.7° phủ từ mép
	     rơi xuống nền thấp. Dốc luôn nằm SAU mép theo hướng chạy: đặt trước mép thì sàn
	     cao che mất, vô dụng.
	  3. LẤP KHE — khe hẹp (vài stud) hai bên vạch thì lấp phẳng ở cao độ sàn.

	RÀNG BUỘC SỐNG CÒN
	  Vạch Start có Touched (StageCheckpointService.onStageStartTouched) → người chơi phải
	  dẫm TRỰC TIẾP lên nó. Vì vậy KHÔNG bao giờ phủ dốc/cầu lên vạch Start (đây là lý do
	  không dùng phương án "bắc cầu vô hình qua khe" — cầu che tiếp xúc thì vạch Start chết
	  câm, mất tiến trình stage). Vạch Finish không có Touched nên phủ được.

	Hướng chạy suy từ (Stage{N}Finish.Position − Stage{N}Start.Position), KHÔNG suy từ hình
	học part — nhiều vạch xoay tuỳ ý, đoán sai chiều là ramp bậc lên thành bậc xuống.

	CÒN LẠI (cố ý bỏ): Zone1/Stage1Start rơi 1.40 tại d=−3 (mép Tray của sảnh xuống nền
	obby) — dốc ở đó chắc chắn đè lên vạch Start. Nằm trước vạch xuất phát, không nằm trong
	mạch chạy.
]]

local DRY_RUN = true
local MAX_LIFT = 2.5
local MAX_WIDEN = 3
local RAMP_LEN = 10
local MIN_DROP, MAX_DROP = 0.08, 2.2
local PROBE, STEP, EPS = 14, 0.25, 0.03

local rp = RaycastParams.new()
local log = {}

local function groundY(origin: Vector3, ignore: { Instance }?): (number?, Instance?)
	if ignore then
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = ignore
	else
		rp.FilterDescendantsInstances = {}
	end
	local r = workspace:Raycast(origin + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), rp)
	if not r then
		return nil, nil
	end
	return r.Position.Y, r.Instance
end

local function travelOf(mech: Instance, n: number): Vector3?
	local s = mech:FindFirstChild(`Stage{n}Start`)
	local f = mech:FindFirstChild(`Stage{n}Finish`)
	if not (s and f and s:IsA("BasePart") and f:IsA("BasePart")) then
		return nil
	end
	local v = f.Position - s.Position
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1 and v.Unit or nil
end

local function halfAlong(p: BasePart, travel: Vector3): number
	return (math.abs(p.Size.X * travel:Dot(p.CFrame.RightVector)) + math.abs(p.Size.Z * travel:Dot(p.CFrame.LookVector)))
		* 0.5
end

--== PHA 1: nâng vạch cho bằng mặt sàn ==============================================
local function lift(zone: Instance, p: BasePart, travel: Vector3)
	local half = halfAlong(p, travel)
	local myTop = p.Position.Y + p.Size.Y * 0.5

	local sides = {}
	for _, sign in { -1, 1 } do
		local level, d = nil, half + 0.5
		while d <= PROBE do
			local y, inst = groundY(p.Position + travel * (sign * d), { p })
			if y and inst and not inst:IsDescendantOf(p) then
				level = y
				break
			end
			d += STEP
		end
		table.insert(sides, { level = level, sign = sign })
	end

	local target = myTop
	for _, s in sides do
		if s.level and s.level > target + EPS and s.level - myTop <= MAX_LIFT then
			target = s.level
		end
	end
	local amount = target - myTop
	if amount <= EPS then
		return
	end

	local back, fwd = 0, 0
	for _, s in sides do
		local d, covered, recovered = half + STEP, 0, false
		while d <= half + MAX_WIDEN do
			local y = groundY(p.Position + travel * (s.sign * d), { p })
			if not y or y >= target - EPS or target - y > MAX_LIFT then
				recovered = true
				break
			end
			covered = d
			d += STEP
		end
		-- hết cữ nới mà sàn vẫn thấp ⇒ đó là sàn khác cao độ, để pha 2 lo bằng dốc
		if recovered and covered > 0 then
			if s.sign < 0 then
				back = covered - half + STEP
			else
				fwd = covered - half + STEP
			end
		end
	end

	table.insert(log, ("NÂNG %s/%s  %.2f -> %.2f (+%.2f) nới %.2f/%.2f"):format(zone.Name, p.Name, myTop, target, amount, back, fwd))
	if DRY_RUN then
		return
	end

	local size = Vector3.new(p.Size.X, p.Size.Y + amount, p.Size.Z)
	local pos = p.Position + Vector3.new(0, amount * 0.5, 0)
	local extra = back + fwd
	if extra > 0 then
		local localDir = p.CFrame:VectorToObjectSpace(travel)
		if math.abs(localDir.X) > math.abs(localDir.Z) then
			size = Vector3.new(size.X + extra, size.Y, size.Z)
		else
			size = Vector3.new(size.X, size.Y, size.Z + extra)
		end
		pos += travel * ((fwd - back) * 0.5)
	end
	p.Size = size
	p.Position = pos
end

--== PHA 2: dốc thoải cho các bậc tụt còn lại =======================================
local function ramps(zone: Instance, p: BasePart, travel: Vector3, mech: Instance)
	local half = halfAlong(p, travel)
	local isStart = p.Name:match("Start$") ~= nil
	local prevY, idx = nil, 0

	for _, c in mech:GetChildren() do
		if c.Name:match("^SeamRamp_" .. p.Name) and not DRY_RUN then
			c:Destroy()
		end
	end

	for d = -12, 12, STEP do
		local y = groundY(p.Position + travel * d)
		if prevY and y then
			local drop = prevY - y
			if drop >= MIN_DROP and drop <= MAX_DROP then
				-- mép trên = mẫu CAO cuối cùng, dốc dính liền, không để hở 0.2 ở đầu dốc
				local d0 = d - STEP
				if isStart and d0 < half - 0.02 then
					table.insert(log, ("BỎ QUA %s/%s d=%+.2f rơi %.2f (dốc sẽ đè vạch Start)"):format(zone.Name, p.Name, d, drop))
				else
					local len = RAMP_LEN
					for k = STEP, RAMP_LEN, STEP do
						local yy = groundY(p.Position + travel * (d + k))
						if not yy or yy > y + 0.05 then
							len = math.max(k + STEP, 2)
							break
						end
					end
					idx += 1
					table.insert(log, ("DỐC  %s/%s d=%+.2f rơi %.2f dài %.2f"):format(zone.Name, p.Name, d, drop, len))
					if not DRY_RUN then
						local a = p.Position + travel * d0 + Vector3.new(0, prevY - p.Position.Y, 0)
						local b = p.Position + travel * (d0 + len) + Vector3.new(0, y - p.Position.Y, 0)
						local mid = (a + b) * 0.5
						local ramp = Instance.new("Part")
						ramp.Name = `SeamRamp_{p.Name}_{idx}`
						ramp.Anchored, ramp.CanCollide, ramp.Transparency = true, true, 1
						ramp.TopSurface, ramp.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
						ramp.Size = Vector3.new((b - a).Magnitude, 0.4, math.max(p.Size.X, p.Size.Z))
						-- lookAt đặt trục X dọc dốc; hạ tâm 0.2 để MẶT TRÊN đi qua đúng hai mốc
						ramp.CFrame = CFrame.lookAt(mid, mid + (b - a).Unit)
							* CFrame.Angles(0, math.rad(90), 0)
							- Vector3.new(0, 0.2, 0)
						ramp.Parent = mech
					end
				end
			end
		end
		prevY = y
	end
end

for n = 1, 15 do
	local zone = workspace.Zones:FindFirstChild(`Zone{n}`)
	local mech = zone and zone:FindFirstChild("Mechanics")
	local travel = mech and travelOf(mech, n)
	if zone and mech and travel then
		for _, p in mech:GetChildren() do
			if p:IsA("BasePart") and (p.Name:match("Start$") or p.Name:match("Finish$")) then
				lift(zone, p, travel)
			end
		end
		for _, p in mech:GetChildren() do
			if p:IsA("BasePart") and (p.Name:match("Start$") or p.Name:match("Finish$")) then
				ramps(zone, p, travel, mech)
			end
		end
	end
end

-- PHA 3 làm riêng: khe hẹp Zone15Finish (Part@199.5x hai bên vạch) — lấp phẳng ở 200.65.
-- Đã dựng SeamFill_Stage15Finish trong Studio; giữ ghi chú ở đây để dựng lại nếu cần.

return ("%s\n%s"):format(DRY_RUN and "== DRY RUN ==" or "== ĐÃ ÁP DỤNG ==", table.concat(log, "\n"))
