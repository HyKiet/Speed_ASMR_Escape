--!strict
--[[
	Zone10 RisingKillBlockScript — khối lava dâng/rơi trong tháp (v2: swept collision)
	Đặt làm con của Workspace.Zones.Zone10.Mechanics (Script chạy trên Server).
	(Bản gốc để version-control; bản chạy nằm trong .rbxlx do map không được Rojo sync.)

	===== v2 (2026-08-07) — ĐỘ CHÍNH XÁC =====
	User: "walkspeed cao hoặc gắn aura/trail thì bẫy không giết player". Hai lỗ hổng:

	1) CỔNG STAGE BẰNG Touched. Bản cũ đòi ActiveStage/CurrentStage == 10, chỉ được gán khi
	   Stage10Start.Touched nổ. Chạy nhanh — hoặc FPS thấp vì aura/trail, mà client là network
	   owner của nhân vật nên bước physics dài ra — thì bước nhảy qua hẳn tấm pad mỏng,
	   Touched KHÔNG nổ, và khối lava KHÔNG BAO GIỜ giết người chơi đó.
	   ⇒ Thêm cổng VỊ TRÍ: ai đang ở trong lòng tháp đều bị phán xử.

	2) LẤY MẪU RỜI RẠC. `GetPartsInPart(killBlock)` chỉ thử tại vị trí CUỐI frame của khối.
	   Khối rơi 350 studs/s = 5.8 studs/frame ở 60fps (11.7 nếu server tụt 30fps), người chơi
	   leo/chạy ngược lại còn cộng thêm. Khoảng trống giữa hai frame không ai kiểm tra.
	   ⇒ Nới hộp truy vấn phủ TRỌN quãng khối vừa đi trong frame (khối đi thẳng đứng nên chỉ
	     cần kéo dài hộp theo Y — chính xác tuyệt đối, không cần rải mẫu), CỘNG thêm quét
	     đoạn đường của người chơi để bắt cả trường hợp người chơi mới là bên đi nhanh.

	===== v3 (2026-08-12) — SIẾT CỬA SỔ LEO, VÌ GATE THẬT CHỈ CÓ 118 WS =====
	User: "test với speed thấp hơn vẫn qua dễ dàng". Đo lại từ đầu, và lần này đo cả hai vế:

	1) TỐC ĐỘ LEO THANG. `ObbyStair` là TrussPart cao 220 studs — người chơi LEO chứ không
	   chạy, nên WalkSpeed không vào thẳng phép tính. Đo trong Studio (đếm riêng những đoạn
	   thời gian thực sự ở state Climbing): **tốc độ leo = 0.53 × WalkSpeed**, nhất quán ở
	   cả WS 80 lẫn WS 155.

	2) CỬA SỔ AN TOÀN. Trong lòng tháp KHÔNG có chỗ trú: khối cao 236 studs quét trọn mặt cắt,
	   sàn đáy Y=0 cũng nằm trong đường đi của nó. Nên người chơi phải leo trọn 220 studs
	   trong đúng một cửa sổ: WAIT_BOTTOM + thời gian khối bò từ đáy lên tới đỉnh.

	Giải phương trình "chạm đỉnh trước khi mặt trên khối chạm tới mình":

	        c = 220·V_RISE / (223 + WAIT_BOTTOM·V_RISE)        (c = tốc độ leo cần có)

	Với 220 / 2.5s cũ ⇒ c = 62.6 ⇒ **gate 118 WS**, trong khi Bảng Chỉ Số Stage 10 ghi 154.
	Thừa 36 WS — đúng như user thấy.

	Sửa: WAIT_BOTTOM 2.5 → **1.75s**, GIỮ NGUYÊN V_RISE 220 (tốc độ khối là thứ đã hiệu chỉnh
	cho vừa mắt và cho cả tiếng rền/nện của client). ⇒ c = 79.6 ⇒ **gate 150 WS**, tức người
	chơi đạt Bảng (154) qua với biên ~3%, người thiếu chuẩn thì không.

	Vì sao KHÔNG hạ tiếp xuống 1.5s (gate 165): mức đó phạt cả người đã đạt chuẩn — đúng lỗi
	mà Zone 14 v1 từng mắc.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Bộ quét RIÊNG của bẫy này. KHÔNG dùng chung với bẫy khác: mỗi bẫy đều reset()
-- những player ngoài vùng của nó mỗi frame, chung bảng là xoá dấu vết của nhau
-- => đoạn quét luôn rỗng và swept thoái hoá về đúng phép thử điểm nó đang chữa.
local TrapSweep = require(ReplicatedStorage:WaitForChild("Shared").Util.TrapSweep).new("Zone10Rising")

local killBlock = script.Parent:WaitForChild("KillBlock") :: BasePart
local stageStart = script.Parent:WaitForChild("Stage10Start")

local STAGE = 10
local V_RISE = 220   -- Tuned rising speed (220 studs/s)
local V_FALL = 350   -- Falling speed (350 studs/s)
local Y_BOTTOM = -121 -- User's custom center Y position
local Y_TOP = 102    -- Touches Y = 220 finish platform (102 + 118 = 220)
local WAIT_TOP = 1.0
--[[
	Cửa sổ để vào chân tháp VÀ leo hết 220 studs — đây là con số quyết định độ khó của cả
	zone, không phải V_RISE (xem khối v3 ở đầu file).

	2.50s → gate 118 WS · **1.75s → gate 150** · 1.50s → gate 165. Bảng Chỉ Số Stage 10 = 154.

	⚠️ Đừng đọc nó là "thời gian nghỉ cho đẹp nhịp": mỗi 0.25s cắt đi ở đây là ~13 WS cộng vào
	yêu cầu của người chơi.
]]
local WAIT_BOTTOM = 1.75
local KILL_CD = 0.5
-- Ngoài tầm này KHÔNG ai đang ở tháp: khối lava nằm im dưới đáy, không replicate.
-- Người tới gần thì chu kỳ khởi động lại từ wait_bottom (luôn có cửa sổ vào chân tháp).
local WAKE_RADIUS = 260
local WAKE_RADIUS_SQ = WAKE_RADIUS * WAKE_RADIUS

-- Cổng vị trí (v2): bán kính lòng tháp. Hẹp hơn WAKE_RADIUS nhiều — đây là "ai bị phán xử",
-- còn WAKE_RADIUS chỉ là "có đánh thức bẫy không".
local TOWER_RADIUS = 120
local TOWER_RADIUS_SQ = TOWER_RADIUS * TOWER_RADIUS

-- Hộp thân người quy ước quanh HumanoidRootPart (cho các mẫu swept giữa 2 frame).
local BODY_HALF_WIDTH = 1.5
local BODY_HALF_HEIGHT = 2.5
local SWEEP_STEP = 2.0

local BODY = {
	HumanoidRootPart = true, Head = true, Torso = true, UpperTorso = true, LowerTorso = true,
	LeftArm = true, RightArm = true, LeftLeg = true, RightLeg = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local lastKill: { [Player]: number } = {}

local function playerFromPart(part: BasePart): (Player?, Humanoid?)
	if not BODY[part.Name] then return nil, nil end
	local c = part:FindFirstAncestorOfClass("Model")
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if not h or h.Health <= 0 then return nil, nil end
	return Players:GetPlayerFromCharacter(c), h
end

local function kill(plr: Player, h: Humanoid)
	local now = os.clock()
	if now - (lastKill[plr] or 0) < KILL_CD then return end
	lastKill[plr] = now
	h.Health = 0
	TrapSweep.reset(plr)
end

-- Initialize KillBlock
killBlock.Anchored = true
killBlock.CanCollide = false
killBlock.CanTouch = true
killBlock.CanQuery = true

local basePos = killBlock.Position
local blockHalf = killBlock.Size * 0.5
local currentY = Y_BOTTOM
killBlock.Position = Vector3.new(basePos.X, currentY, basePos.Z)

local phase = "wait_bottom"
local timer = WAIT_BOTTOM
local awake = false

local function anyoneNear(): boolean
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local dx = root.Position.X - basePos.X
			local dz = root.Position.Z - basePos.Z
			if dx * dx + dz * dz <= WAKE_RADIUS_SQ then
				return true
			end
		end
	end
	return false
end

-- Handle start checkpoint touched (vẫn giữ để HUD/checkpoint hoạt động — chỉ là KHÔNG còn
-- là điều kiện duy nhất để bẫy có hiệu lực).
if stageStart then
	stageStart.Touched:Connect(function(hit)
		local c = hit:FindFirstAncestorOfClass("Model")
		local plr = c and Players:GetPlayerFromCharacter(c)
		if plr then
			plr:SetAttribute("ActiveStage", STAGE)
			plr:SetAttribute("CurrentStage", STAGE)
		end
	end)
end

-- ===== Zero-GC scratch =====
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = false
local activeChars: { Instance } = {}
local inTower: { Player } = {}

RunService.Heartbeat:Connect(function(dt)
	if not anyoneNear() then
		-- NGỦ: hạ khối về đáy đúng một lần rồi ngừng hẳn (nhìn từ xa thấy bẫy đứng im).
		if awake then
			awake = false
			phase = "wait_bottom"
			timer = WAIT_BOTTOM
			currentY = Y_BOTTOM
			killBlock.Position = Vector3.new(basePos.X, currentY, basePos.Z)
		end
		return
	end
	awake = true

	local prevY = currentY
	if phase == "wait_bottom" then
		timer -= dt
		if timer <= 0 then phase = "rise" end
	elseif phase == "rise" then
		currentY = math.min(Y_TOP, currentY + V_RISE * dt)
		killBlock.Position = Vector3.new(basePos.X, currentY, basePos.Z)
		if currentY >= Y_TOP then
			phase = "wait_top"
			timer = WAIT_TOP
		end
	elseif phase == "wait_top" then
		timer -= dt
		if timer <= 0 then phase = "fall" end
	elseif phase == "fall" then
		currentY = math.max(Y_BOTTOM, currentY - V_FALL * dt)
		killBlock.Position = Vector3.new(basePos.X, currentY, basePos.Z)
		if currentY <= Y_BOTTOM then
			phase = "wait_bottom"
			timer = WAIT_BOTTOM
		end
	end

	-- CỔNG VỊ TRÍ: ai đang trong lòng tháp (không cần attribute stage).
	table.clear(activeChars)
	table.clear(inTower)
	local n = 0
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r and r:IsA("BasePart") then
			local dx = r.Position.X - basePos.X
			local dz = r.Position.Z - basePos.Z
			if dx * dx + dz * dz <= TOWER_RADIUS_SQ then
				n += 1
				activeChars[n] = c :: Instance
				table.insert(inTower, plr)
			else
				TrapSweep.reset(plr)
			end
		end
	end
	if n == 0 then return end

	-- HỘP SWEPT của khối: phủ trọn quãng nó vừa đi trong frame. Khối đi thẳng đứng nên chỉ
	-- cần kéo dài theo Y quanh trung điểm — chính xác tuyệt đối, không phải xấp xỉ.
	local travel = math.abs(currentY - prevY)
	local midY = (currentY + prevY) * 0.5
	local sweptSize = Vector3.new(killBlock.Size.X, killBlock.Size.Y + travel, killBlock.Size.Z)
	local sweptCF = CFrame.new(basePos.X, midY, basePos.Z)

	params.FilterDescendantsInstances = activeChars
	for _, part in Workspace:GetPartBoundsInBox(sweptCF, sweptSize, params) do
		local plr, h = playerFromPart(part)
		if plr and h then kill(plr, h) end
	end

	-- Người chơi mới là bên đi nhanh (rơi/leo/bị bắn): quét đoạn đường của họ so với hộp
	-- swept của khối ở trên.
	local halfY = sweptSize.Y * 0.5
	for _, plr in inTower do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r and r:IsA("BasePart") then
			local pos = r.Position
			local from, steps = TrapSweep.segment(plr, pos, SWEEP_STEP, travel)
			local delta = pos - from
			for i = 0, steps do
				local sp = from + delta * (i / steps)
				if
					math.abs(sp.X - basePos.X) <= blockHalf.X + BODY_HALF_WIDTH
					and math.abs(sp.Z - basePos.Z) <= blockHalf.Z + BODY_HALF_WIDTH
					and math.abs(sp.Y - midY) <= halfY + BODY_HALF_HEIGHT
				then
					kill(plr, h)
					break
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastKill[plr] = nil
end)
