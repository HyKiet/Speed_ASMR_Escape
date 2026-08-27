--!strict
--[[
	Zone10RisingBlockService.luau — khối lava dâng/rơi trong tháp Stage 10.

	THAY THẾ script inline `Workspace.Zones.Zone10.Mechanics.Zone10RisingKillBlockScript`
	(2026-08-27). Toàn bộ lịch sử v2→v5 của bản inline chép lại dưới đây vì mỗi mục là một
	cái bẫy đã dính rồi mới sửa — đừng "dọn cho gọn".

	===== v2 (2026-08-07) — ĐỘ CHÍNH XÁC =====
	User: "walkspeed cao hoặc gắn aura/trail thì bẫy không giết player". Hai lỗ hổng:

	1) CỔNG STAGE BẰNG Touched. Bản gốc đòi ActiveStage/CurrentStage == 10, chỉ được gán khi
	   Stage10Start.Touched nổ. Chạy nhanh — hoặc FPS thấp vì aura/trail, mà client là network
	   owner của nhân vật nên bước physics dài ra — thì bước nhảy qua hẳn tấm pad mỏng,
	   Touched KHÔNG nổ, và khối lava KHÔNG BAO GIỜ giết người chơi đó.
	   ⇒ Thêm cổng VỊ TRÍ: ai đang ở trong lòng tháp đều bị phán xử.

	2) LẤY MẪU RỜI RẠC. Phép thử cũ chỉ xét vị trí CUỐI frame của khối. Khối rơi 350 studs/s
	   = 5.8 studs/frame ở 60fps (11.7 nếu server tụt 30fps), người chơi leo/rơi ngược lại còn
	   cộng thêm. Khoảng trống giữa hai frame không ai kiểm tra.
	   ⇒ Hộp truy vấn phủ TRỌN quãng khối vừa đi trong frame (khối đi thẳng đứng nên chỉ cần
	     kéo dài hộp theo Y — chính xác tuyệt đối, không phải xấp xỉ), CỘNG thêm quét đoạn
	     đường của người chơi để bắt cả trường hợp người chơi mới là bên đi nhanh.

	===== v4 (2026-08-20) — BẮT RẺ HƠN =====
	`GetPartBoundsInBox` trước đây chạy MỖI FRAME cho mọi người trong bán kính 120 studs — kể
	cả khi khối ở đáy tháp còn người chơi ở trên nóc, cách nhau 200+ studs theo Y. Tháp cao
	340 studs, khối chỉ đi 223, nên phần lớn thời gian truy vấn đó chắc chắn rỗng. Giờ lọc sơ
	bộ theo Y trước. Lề 12 studs rộng gấp đôi chiều cao một nhân vật R15 nên không cắt nhầm ai.
	`inTower` GIỮ nguyên cổng XZ: nó còn là thứ nuôi dấu vết TrapSweep, cắt theo Y ở đây sẽ
	làm đoạn quét đứt đúng lúc người chơi rơi nhanh nhất.

	===== v5 (2026-08-27) — SERVER KHÔNG CÒN DỜI KHỐI =====
	User: "bẫy ở mọi zone giật giật khi stage đông người — không phải lag game, giống lag
	mạng". Ping đo được 390ms (PC) / ~350ms (iPhone 13).

	Đây là bẫy cuối cùng còn để server dời part thật, và tệ nhất về hình ảnh: khối rơi 350
	studs/s. Part neo do script dời thì client KHÔNG nội suy — nó nhảy thẳng tới giá trị mới
	mỗi khi gói replicate tới, nên cú rơi 0.64 giây chỉ hiện ra thành vài chục nấc; stage đông
	người thì gói còn thưa hơn. Đó chính xác là "giật như lag mạng" mà FPS không hề tụt.

	  • Chiều cao khối thành HÀM THUẦN của thời gian: `yFor(now - wakeAt)`. Server và client
	    (`Zone10RisingBlockController`) gọi CÙNG một hàm ⇒ khớp tuyệt đối, 0 byte replicate.
	  • Cổng ngủ/thức GIỮ NGUYÊN — khối vẫn reset về đáy khi zone trống, nên cửa sổ leo của
	    người vừa vào không đổi và gate 150 WS giữ nguyên. Server chỉ ghi MỘT attribute
	    `BlockWakeAt` mỗi lần ngủ↔thức: một gói cho cả chu kỳ, thay cho 60 gói mỗi giây.
	  • Phán xử vẫn Ở SERVER, vẫn swept, vẫn dùng hộp ẢO `sweptCF` — vốn đã không đọc
	    `killBlock.Position` từ đầu.

	⚠️ GỠ LƯỚI AN TOÀN `Touched` (thêm ở v4). BẮT BUỘC gỡ: server không dời khối nữa nên
	Touched sẽ nổ theo vị trí HOME chứ không theo chỗ khối đang hiện — đúng cái bẫy đã ghi cho
	sóng Zone 9. Mất mát bằng KHÔNG, vì lý do dựng nó ra đã sai ngay từ đầu: v4 lập luận "phép
	thử giải tích chỉ thấy player qua root", nhưng điều đó chỉ đúng với nhánh TrapSweep. Nhánh
	`GetPartBoundsInBox` bên dưới lọc theo CHARACTER rồi trả về BẤT KỲ part cơ thể nào nằm
	trong hộp swept — nó đã thấy tay/chân thò ra và tư thế ragdoll y hệt Touched, lại còn
	swept nên không thủng ở tốc độ cao.

	===== v6 (2026-08-27) — VÀO GIT =====
	Chuyển từ Script inline trong .rbxl sang ModuleScript dưới `src/server/Services` để Rojo
	sync và git theo dõi được (`init.server.luau` tự quét, không phải đăng ký ở đâu). Đổi lại
	không còn `script.Parent` để bám: phải tự tìm zone và chịu được việc map chưa nạp xong.

	KHÔNG đụng V_RISE/V_FALL/WAIT_* qua bất kỳ phiên bản nào ⇒ độ khó zone giữ nguyên.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Bộ quét RIÊNG của bẫy này. KHÔNG dùng chung với bẫy khác: mỗi bẫy đều reset() những player
-- ngoài vùng của nó mỗi frame, chung bảng là xoá dấu vết của nhau => đoạn quét luôn rỗng và
-- swept âm thầm thoái hoá về đúng phép thử điểm mà nó đang chữa.
local TrapSweep = require(ReplicatedStorage.Shared.Util.TrapSweep).new("Zone10Rising")
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone10RisingBlockService = {}

local V_RISE = 220
local V_FALL = 350
local Y_BOTTOM = -121
local Y_TOP = 102
local WAIT_TOP = 1.0
-- v3 (2026-08-12): 2.5 → 1.75s. Đây mới là con số quyết định độ khó của zone, không phải
-- V_RISE. Người chơi LEO thang truss với tốc độ = 0.53 × WalkSpeed (đo trong Studio), và
-- trong lòng tháp không có chỗ trú, nên phải leo trọn 220 studs trong cửa sổ
-- WAIT_BOTTOM + (223 / V_RISE). Giải ra: c = 220·V / (223 + W·V).
--   2.50s → gate 118 WS · 1.75s → gate 150 · 1.50s → gate 165 (Bảng Chỉ Số Stage 10 = 154).
-- Mỗi 0.25s cắt ở đây ≈ +13 WS yêu cầu. Đừng chỉnh cho "đẹp nhịp".
local WAIT_BOTTOM = 1.75
local KILL_CD = 0.5
local WAKE_RADIUS = 260
local WAKE_RADIUS_SQ = WAKE_RADIUS * WAKE_RADIUS

-- Cổng vị trí (v2): bán kính lòng tháp — "ai bị phán xử".
-- WAKE_RADIUS rộng hơn nhiều và chỉ trả lời "có đánh thức bẫy không".
local TOWER_RADIUS = 120
local TOWER_RADIUS_SQ = TOWER_RADIUS * TOWER_RADIUS

local BODY_HALF_WIDTH = 1.5
local BODY_HALF_HEIGHT = 2.5
local SWEEP_STEP = 2.0
-- Lề lọc sơ bộ theo Y trước khi truy vấn không gian (v4). Nhân vật R15 cao ~5.5 studs nên 12
-- là gấp đôi — không thể cắt nhầm ai, mà cắt được phần lớn các frame.
local QUERY_MARGIN_Y = 12

local RESOLVE_RETRY = 1

--[[
	── NHỊP KHỐI, DẠNG HÀM THUẦN (v5) ──────────────────────────────────────────────────────
	Máy trạng thái cũ (`wait_bottom → rise → wait_top → fall`) viết lại thành một hàm của thời
	gian đã trôi kể từ lúc bẫy THỨC. `Zone10RisingBlockController` chép NGUYÊN hàm này — đây
	là hợp đồng: sửa một vế mà không sửa vế kia là hình và phán xử lệch nhau.

	Thứ tự pha bắt buộc giữ nguyên: bẫy luôn thức ở ĐÁY và cho người chơi trọn WAIT_BOTTOM
	trước khi khối bắt đầu dâng — đó chính là cửa sổ mà gate 150 WS được tính ra từ đó.
]]
local TRAVEL = Y_TOP - Y_BOTTOM
local RISE_T = TRAVEL / V_RISE
local FALL_T = TRAVEL / V_FALL
local CYCLE = WAIT_BOTTOM + RISE_T + WAIT_TOP + FALL_T

local function yFor(elapsed: number): number
	local t = elapsed % CYCLE
	if t < WAIT_BOTTOM then
		return Y_BOTTOM
	end
	t -= WAIT_BOTTOM
	if t < RISE_T then
		return Y_BOTTOM + V_RISE * t
	end
	t -= RISE_T
	if t < WAIT_TOP then
		return Y_TOP
	end
	return Y_TOP - V_FALL * (t - WAIT_TOP)
end

local BODY = {
	HumanoidRootPart = true,
	Head = true,
	Torso = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftArm = true,
	RightArm = true,
	LeftLeg = true,
	RightLeg = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
}

local lastKill: { [Player]: number } = {}

local mechanics: Instance? = nil
local killBlock: BasePart? = nil
local basePos = Vector3.zero
local blockHalf = Vector3.zero
local awake = false
local wakeAt = 0
local currentY = Y_BOTTOM

-- ===== Zero-GC scratch =====
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = false
local activeChars: { Instance } = {}
local inTower: { Player } = {}

local function playerFromPart(part: BasePart): (Player?, Humanoid?)
	if not BODY[part.Name] then
		return nil, nil
	end
	local character = part:FindFirstAncestorOfClass("Model")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return Players:GetPlayerFromCharacter(character), humanoid
end

local function kill(player: Player, humanoid: Humanoid)
	local now = os.clock()
	if now - (lastKill[player] or 0) < KILL_CD then
		return
	end
	lastKill[player] = now
	humanoid.Health = 0
	TrapSweep.reset(player)
end

local function anyoneNear(): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
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

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone10 = zones and zones:FindFirstChild("Zone10")
	local mech = zone10 and zone10:FindFirstChild("Mechanics")
	local block = mech and mech:FindFirstChild("KillBlock")
	if not mech or not block or not block:IsA("BasePart") then
		return false
	end

	mechanics = mech
	killBlock = block
	basePos = block.Position
	blockHalf = block.Size * 0.5

	block.Anchored = true
	block.CanCollide = false
	-- v5: server KHÔNG dời khối nữa nên Touched sẽ nổ ở vị trí HOME, không phải chỗ khối đang
	-- hiện. Tắt hẳn (xem khối ⚠️ ở đầu file).
	block.CanTouch = false
	block.CanQuery = true
	-- Ghim khối ở đáy trên server một lần rồi để yên vĩnh viễn. Client mới là bên vẽ.
	block.Position = Vector3.new(basePos.X, Y_BOTTOM, basePos.Z)

	-- Hợp đồng với Zone10RisingBlockController. Ghi MỘT LẦN, không đổi nữa.
	mech:SetAttribute("BlockBaseX", basePos.X)
	mech:SetAttribute("BlockBaseZ", basePos.Z)
	mech:SetAttribute("BlockYBottom", Y_BOTTOM)
	mech:SetAttribute("BlockYTop", Y_TOP)
	mech:SetAttribute("BlockVRise", V_RISE)
	mech:SetAttribute("BlockVFall", V_FALL)
	mech:SetAttribute("BlockWaitTop", WAIT_TOP)
	mech:SetAttribute("BlockWaitBottom", WAIT_BOTTOM)
	-- `BlockWakeAt` = giờ server lúc bẫy thức (nil khi đang ngủ). Đây là attribute DUY NHẤT
	-- còn thay đổi lúc chạy, và nó chỉ đổi mỗi lần zone chuyển ngủ↔thức.
	mech:SetAttribute("BlockWakeAt", nil)
	mech:SetAttribute("BlockReady", true)

	--[[
		v6: KHÔNG còn handler `Stage10Start.Touched` gán ActiveStage/CurrentStage.
		`StageCheckpointService` đã sở hữu việc đó và làm đầy đủ hơn hẳn: kiểm tra khoảng cách
		(`isTouchNearPart`), ghi HighestCompletedStage, đồng bộ attribute, và có cả vòng dò
		theo VỊ TRÍ cho trường hợp walkspeed cao nhảy qua tấm pad. Bản inline chỉ là bản sao
		thô ghi đè thẳng attribute — chạy song song thì nó còn ghi đè ngược logic của service
		(vd người vừa teleport lên stage 12 quét qua Stage10Start bị kéo về 10).

		Bẫy này vốn đã KHÔNG phụ thuộc attribute stage nữa từ v2 (cổng vị trí), nên bỏ đi
		không mất gì.
	]]
	return true
end

local function tick()
	local block = killBlock
	local mech = mechanics
	if not block or not mech then
		return
	end
	if not block:IsDescendantOf(Workspace) then
		killBlock = nil
		return
	end

	local now = Workspace:GetServerTimeNow()

	if not anyoneNear() then
		if awake then
			awake = false
			currentY = Y_BOTTOM
			mech:SetAttribute("BlockWakeAt", nil)
		end
		return
	end
	if not awake then
		awake = true
		wakeAt = now
		currentY = Y_BOTTOM
		-- Một gói duy nhất cho cả chu kỳ. Client dựng lại toàn bộ chuyển động từ đây.
		mech:SetAttribute("BlockWakeAt", wakeAt)
	end

	local prevY = currentY
	currentY = yFor(now - wakeAt)

	-- HỘP SWEPT của khối: phủ trọn quãng nó vừa đi trong frame. Khối đi thẳng đứng nên chỉ
	-- cần kéo dài theo Y quanh trung điểm — chính xác tuyệt đối, không phải xấp xỉ.
	local travel = math.abs(currentY - prevY)
	local midY = (currentY + prevY) * 0.5
	local sweptSize = Vector3.new(block.Size.X, block.Size.Y + travel, block.Size.Z)
	local halfY = sweptSize.Y * 0.5

	table.clear(activeChars)
	table.clear(inTower)
	local n = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local rp = root.Position
			local dx = rp.X - basePos.X
			local dz = rp.Z - basePos.Z
			if dx * dx + dz * dz <= TOWER_RADIUS_SQ then
				table.insert(inTower, player)
				-- Lọc sơ bộ theo Y (v4): chỉ ai ở gần tầm khối mới đáng để truy vấn không gian.
				-- `inTower` ở trên KHÔNG lọc theo Y — nó nuôi dấu vết TrapSweep, cắt là đứt
				-- đoạn quét đúng lúc người chơi rơi nhanh nhất.
				if math.abs(rp.Y - midY) <= halfY + QUERY_MARGIN_Y then
					n += 1
					activeChars[n] = character :: Instance
				end
			else
				TrapSweep.reset(player)
			end
		end
	end
	if #inTower == 0 then
		return
	end

	if n > 0 then
		-- Hộp ẢO: dựng từ `basePos` + `midY`, KHÔNG đọc `killBlock.Position` (từ v5 part đứng
		-- yên ở đáy). Truy vấn này thấy MỌI part cơ thể trong hộp — đây là thứ thay Touched.
		local sweptCF = CFrame.new(basePos.X, midY, basePos.Z)
		params.FilterDescendantsInstances = activeChars
		for _, part in Workspace:GetPartBoundsInBox(sweptCF, sweptSize, params) do
			local player, humanoid = playerFromPart(part)
			if player and humanoid then
				kill(player, humanoid)
			end
		end
	end

	-- Người chơi mới là bên đi nhanh (rơi/leo/bị bắn): quét đoạn đường của họ so với hộp
	-- swept của khối ở trên.
	for _, player in inTower do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local pos = root.Position
			local from, steps = TrapSweep.segment(player, pos, SWEEP_STEP, travel)
			local delta = pos - from
			for i = 0, steps do
				local sp = from + delta * (i / steps)
				if
					math.abs(sp.X - basePos.X) <= blockHalf.X + BODY_HALF_WIDTH
					and math.abs(sp.Z - basePos.Z) <= blockHalf.Z + BODY_HALF_WIDTH
					and math.abs(sp.Y - midY) <= halfY + BODY_HALF_HEIGHT
				then
					kill(player, humanoid)
					break
				end
			end
		end
	end
end

function Zone10RisingBlockService.Init() end

function Zone10RisingBlockService.Start()
	task.spawn(function()
		while not resolve() do
			task.wait(RESOLVE_RETRY)
		end
		RunService.Heartbeat:Connect(tick)
		Log.Boot("[Zone10RisingBlockService] client tự vẽ khối (0 replication), server phán xử swept")
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKill[player] = nil
	end)
end

return Zone10RisingBlockService
