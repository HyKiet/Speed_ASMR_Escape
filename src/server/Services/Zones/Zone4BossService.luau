--!strict
--[[
	Zone4BossService.luau — MonkeyBoss đuổi người chơi trong arena Stage 4.

	Chuyển từ script inline Workspace.Zones.Zone4.Zone4BossScript sang Service (bootstrapper
	nạp, Rojo sync). Boss VẪN CHẠY TRÊN SERVER.

	MỤC TIÊU = NGƯỜI DẪN ĐẦU (đổi 2026-08-14, trước đây là người gần boss nhất): 3 người vào
	arena thì boss dí người gần Stage4Finish nhất, có mép 6 studs chống đổi mục tiêu liên tục.
	Phép thử chạm chết áp cho MỌI người trong sân, không riêng mục tiêu. Xem khối lý do ở
	`collectRunners` / `pickLeader`.

	TỐI ƯU so với bản cũ:
	  • Vòng đuổi fixed-timestep 30Hz thay vì mỗi Heartbeat 60Hz → nửa CPU.
	  • Cổng "ngủ": arena không có ứng viên → boss về nhà MỘT LẦN rồi ngồi im.
	  • Bỏ qua animation khi đang ngủ.
	  • (v3) Server KHÔNG `PivotTo` model nữa — nó công bố attribute `BossCF`, client vẽ.

	Vì sao KHÔNG deterministic-clock như các bẫy khác: boss là AI đuổi theo VỊ TRÍ NGƯỜI CHƠI
	(không suy được từ đồng hồ), nên buộc server tính. Nhưng "server TÍNH" khác "server VẼ" —
	xem khối ══ ngay dưới đây, đó mới là thứ quyết định boss nhìn có mượt hay không.
]]

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local LagComp = require(ReplicatedStorage.Shared.Util.LagComp)

local Zone4BossService = {}

--[[
	══ VÌ SAO KHÔNG PHẢI "NÂNG TICK LÊN 60Hz" (2026-08-27, user hỏi thẳng câu này) ═════════

	Câu hỏi: "có cách nào cho MonkeyBoss chạy 60fps không". Câu trả lời ngắn: **nâng nhịp
	server KHÔNG làm boss mượt hơn**, và ở ping của game (350–400ms) nó còn làm mọi thứ tệ đi.

	Lý do là thứ đã lặp lại ở mọi bẫy trong session này: part NEO do script dời KHÔNG được
	client nội suy. Client NHẢY thẳng tới giá trị mới mỗi khi gói replicate tới, và gói đó đi
	theo NHỊP GỬI CỦA MẠNG chứ không theo nhịp server hay nhịp hình. Nghĩa là:
	  • Server 30Hz hay 60Hz thì client vẫn nhận cùng chừng ấy gói ⇒ nhìn y hệt nhau.
	  • Cái thay đổi duy nhất là băng thông và CPU: gấp đôi, đổi lấy 0 pixel.

	CÁCH ĐÚNG (v3): tách AUTHORITY khỏi HÌNH.
	  • Server giữ nguyên 30Hz, vẫn là bên quyết định boss ở đâu và ai chết — nhưng KHÔNG
	    `PivotTo` model nữa. Nó công bố một CFrame duy nhất qua attribute `BossCF`.
	  • `Zone4BossController` phía client đọc `BossCF` rồi NỘI SUY MƯỢT tới đó mỗi
	    RenderStepped, và chỉ ghi `HumanoidRootPart.CFrame` — Motor6D + Animator tự đặt 8 part
	    còn lại. Kết quả là 60fps thật (hoặc bằng đúng FPS máy người chơi), bất kể gói tới thưa.

	KÈM THEO — BÙ TRỄ (`LagComp`): boss chạy 56 studs/s, nên ở 195ms trễ một chiều, con khỉ mà
	người chơi NHÌN THẤY ở sau con khỉ server đang phán xử tới **11 studs** — trong khi bán
	kính chạm chết chỉ 3.75. Tức là "chết khi boss còn cách xa cả thân người". Server giờ giữ
	một VÒNG ĐỆM LỊCH SỬ vị trí boss và phán xử chạm tại `now - delay(player)`, đúng khung
	hình người chơi đã thấy.

	HỆ QUẢ PHỤ TÍCH CỰC: `repairBossVisualIfNeeded` đã bỏ. Nó tồn tại vì các part rig trôi dần
	khỏi pivot sau nhiều lần `PivotTo` liên tiếp. Giờ client đặt lại root MỖI FRAME và Animator
	dựng lại toàn bộ Motor6D từ root đó, nên trôi là chuyện KHÔNG THỂ xảy ra về mặt cấu trúc.
]]
-- Bao nhiêu giây lịch sử vị trí boss cần giữ để bù trễ. Phải ≥ `LagComp.MAX_DELAY` (0.40)
-- + `VISUAL_SMOOTH_LAG`, cộng một chút lề cho nhịp tick.
local HISTORY_SECONDS = 0.6

--[[
	TRỄ CỦA BỘ LỌC MƯỢT PHÍA CLIENT — hằng số này là HỢP ĐỒNG với `Zone4BossController`.
	Nó phải luôn bằng `1 / SMOOTH_K` bên đó. Đổi một vế mà quên vế kia là boss giết lệch.

	Vì sao đúng bằng 1/k, không phải một con số chọn tay: bộ lọc mũ
	`x ← x + (goal − x)·(1 − e^(−k·dt))` khi bám một mục tiêu đi ĐỀU với vận tốc v thì sai số
	xác lập đúng bằng `v/k`. Mà `v/k` chính là quãng đường mục tiêu đi trong `1/k` giây ⇒ hình
	người chơi thấy BẰNG tư thế server của `1/k` giây TRƯỚC. Boss chạy đều (CHASE_SPEED không
	đổi) nên xấp xỉ này đúng gần như tuyệt đối ở đây.

	Cộng với trễ mạng: người chơi ping 195ms nhìn thấy con boss của `now − 0.195 − 0.055`.
	Không cộng vế này thì ở 56 studs/s vẫn còn lệch 3 studs — gần bằng cả bán kính chạm chết
	3.75, tức là vẫn "chết khi boss chưa chạm tới".
]]
local VISUAL_SMOOTH_LAG = 1 / 18

local MECHANICS_NAME = "Mechanics"
local ARENA_FLOOR_NAME = "BossArenaFloor"
local START_GATE_NAME = "Stage4Start"
local FINISH_GATE_NAME = "Stage4Finish"
local KILL_FLOOR_NAME = "KillFloor"
local BOSS_NAME = "MonkeyBoss"
local RUN_ANIMATION_ID = "rbxassetid://132081122184261"

local STAGE_NUMBER = 4
local COMPLETE_STAGE = 5

local CHASE_SPEED = 56
local RETURN_SPEED = 72
local TOUCH_KILL_DISTANCE = 3.75
local KILL_COOLDOWN_SECONDS = 1.15
local ARENA_DETECTION_PADDING = 4
local TICK_RATE = 1 / 30 -- vòng đuổi 30Hz (đủ mượt cho NPC, nửa băng thông so với 60Hz)

local homePivot = CFrame.new(-4.211, 11.588, 1568.629)

local ARENA_MIN_X = -139
local ARENA_MAX_X = 131
local ARENA_MIN_Z = 1391
local ARENA_MAX_Z = 1746

local zone: Instance?
local mechanics: Instance?
local startGate: BasePart?
local finishGate: BasePart?
local killFloor: BasePart?
local boss: Model?
local bossTemplate: Model?
local runTrack: AnimationTrack?
local runTrackBoss: Model?
local runAnimation = Instance.new("Animation")
local lastKillTimes: { [Player]: number } = {}
local activeEncounterPlayers: { [Player]: boolean } = {}
local cachedArenaMinX = ARENA_MIN_X
local cachedArenaMaxX = ARENA_MAX_X
local cachedArenaMinZ = ARENA_MIN_Z
local cachedArenaMaxZ = ARENA_MAX_Z
local restingAtHome = false

--[[
	Tư thế boss do SERVER quyết định. Từ v3 đây là NGUỒN SỰ THẬT duy nhất — không đọc
	`model:GetPivot()` nữa, vì server không còn dời model (client mới là bên vẽ), nên GetPivot
	sẽ mãi trả về vị trí lúc dựng.
]]
local bossCFrame = homePivot

-- Vòng đệm lịch sử cho bù trễ: (giờ server, vị trí). Ở 30Hz × 0.6s là ~18 phần tử.
type Snapshot = { t: number, p: Vector3 }
local history: { Snapshot } = {}

runAnimation.Name = "MonkeyBossRun"
runAnimation.AnimationId = RUN_ANIMATION_ID

local function findMechanicsAncestor(instance: Instance): Instance?
	local current = instance.Parent
	while current do
		if current.Name == MECHANICS_NAME and current:IsA("Folder") then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Không còn `script.Parent` (service nằm ở ServerScriptService, không phải trong Zone4).
-- Tìm zone qua Stage4Start rồi lần ngược lên Mechanics/Zone.
local function resolveBossZoneAndMechanics(): (Instance?, Instance?)
	local startGateInstance = Workspace:FindFirstChild(START_GATE_NAME, true)
	if startGateInstance then
		local foundMechanics = findMechanicsAncestor(startGateInstance)
		local foundZone = foundMechanics and foundMechanics.Parent
		if foundMechanics and foundZone then
			return foundZone, foundMechanics
		end
	end
	return nil, nil
end

local function refreshArenaBounds()
	local arenaFloor = if zone then zone:FindFirstChild(ARENA_FLOOR_NAME, true) else nil
	if arenaFloor and arenaFloor:IsA("BasePart") then
		local halfSizeX = arenaFloor.Size.X * 0.5
		local halfSizeZ = arenaFloor.Size.Z * 0.5
		cachedArenaMinX = arenaFloor.Position.X - halfSizeX
		cachedArenaMaxX = arenaFloor.Position.X + halfSizeX
		cachedArenaMinZ = arenaFloor.Position.Z - halfSizeZ
		cachedArenaMaxZ = arenaFloor.Position.Z + halfSizeZ
	end
end

local function isPositionInsideArena(position: Vector3, padding: number?): boolean
	local arenaPadding = padding or ARENA_DETECTION_PADDING
	return position.X >= cachedArenaMinX - arenaPadding
		and position.X <= cachedArenaMaxX + arenaPadding
		and position.Z >= cachedArenaMinZ - arenaPadding
		and position.Z <= cachedArenaMaxZ + arenaPadding
end

local function shouldChasePlayer(player: Player, position: Vector3): boolean
	local currentStage = player:GetAttribute("CurrentStage")
	if currentStage == STAGE_NUMBER then
		return activeEncounterPlayers[player] == true and isPositionInsideArena(position)
	end
	if type(currentStage) == "number" and currentStage >= COMPLETE_STAGE then
		return isPositionInsideArena(position, 0)
	end
	return false
end

local function killCharacter(player: Player, character: Model)
	local now = os.clock()
	local lastKillTime = lastKillTimes[player] or 0
	if now - lastKillTime < KILL_COOLDOWN_SECONDS then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		lastKillTimes[player] = now
		humanoid.Health = 0
	end
end

local function configureBoss(model: Model)
	model.Name = BOSS_NAME
	model:SetAttribute("EncounterState", "Idle")

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
	end

	if humanoid then
		humanoid.AutoRotate = false
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.WalkSpeed = 0
		if not humanoid:FindFirstChildOfClass("Animator") then
			local animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.Anchored = (descendant.Name == "HumanoidRootPart")
			if not descendant.Anchored then
				pcall(function()
					descendant:SetNetworkOwner(nil)
				end)
			end
		end
	end
end

local function stopRunAnimation()
	if runTrack then
		runTrack:Stop(0.18)
		runTrack = nil
		runTrackBoss = nil
	end
end

local function loadRunTrack(model: Model): AnimationTrack?
	if runTrack and runTrackBoss == model then
		return runTrack
	end
	stopRunAnimation()

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local track = animator:LoadAnimation(runAnimation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement
	runTrack = track
	runTrackBoss = model
	return track
end

local function warmRunAnimation(model: Model)
	local track = loadRunTrack(model)
	if not track then
		return
	end
	track:Play(0)
	track:AdjustSpeed(0)
	track:Stop(0)
	track:AdjustSpeed(1)
end

local function playRunAnimation(model: Model)
	local track = loadRunTrack(model)
	if track and not track.IsPlaying then
		track:Play(0.08)
	end
end

local function findBossModel(): Model?
	local currentZone = zone
	if not currentZone then
		return nil
	end
	local currentMechanics = mechanics

	if currentMechanics then
		local existingInMechanics = currentMechanics:FindFirstChild(BOSS_NAME, true)
		if existingInMechanics and existingInMechanics:IsA("Model") then
			return existingInMechanics
		end
	end

	local existingInZone = currentZone:FindFirstChild(BOSS_NAME)
	if existingInZone and existingInZone:IsA("Model") then
		return existingInZone
	end

	local existingInWorkspace = Workspace:FindFirstChild(BOSS_NAME, true)
	if existingInWorkspace and existingInWorkspace:IsA("Model") then
		existingInWorkspace.Parent = currentMechanics or currentZone
		return existingInWorkspace
	end

	if bossTemplate then
		local clone = bossTemplate:Clone()
		clone.Parent = currentMechanics or currentZone
		return clone
	end

	return nil
end

local function ensureBoss(): Model?
	local model = boss
	if model and model.Parent and model:FindFirstChild("HumanoidRootPart") then
		return model
	end

	stopRunAnimation()
	model = findBossModel()
	if not model then
		return nil
	end

	configureBoss(model)
	boss = model

	if not bossTemplate then
		homePivot = model:GetPivot()
		bossTemplate = model:Clone()
		bossTemplate.Parent = nil
	end

	-- Đặt boss về nhà MỘT LẦN trên server rồi để yên vĩnh viễn: từ v3 client mới là bên vẽ
	-- (xem khối lý do ở đầu file). Công bố ngay `BossCF` để client có cái để bám từ frame đầu.
	model:PivotTo(homePivot)
	bossCFrame = homePivot
	table.clear(history)
	model:SetAttribute("BossHome", homePivot)
	model:SetAttribute("BossCF", homePivot)
	model:SetAttribute("BossChaseSpeed", CHASE_SPEED)
	model:SetAttribute("BossReady", true)
	warmRunAnimation(model)
	return model
end

--[[
	QUÉT MỘT LƯỢT CHO CẢ TICK (viết lại 2026-08-14 — user báo boss hỏng khi có 2 client).

	Bản cũ có hai khuyết tật chỉ lộ ra khi arena có từ 2 người:

	  1. NHẮM NGƯỜI GẦN NHẤT, TÍNH LẠI MỖI TICK. Hai người chạy song song thì mỗi lần ai đó
	     nhích lên nửa stud là boss quay ngoắt sang người kia — 30 lần mỗi giây. Nhìn từ client
	     là con khỉ rung lắc tại chỗ giữa hai người và không đuổi kịp ai cả.
	  2. CHỈ MỤC TIÊU MỚI CHẾT ĐƯỢC. Phép thử khoảng cách chạm chỉ chạy trên đúng cái root vừa
	     chọn, nên người thứ hai đứng LỌT TRONG con khỉ vẫn sống nhăn — đúng cái "vào zone mà
	     nó không hoạt động" user thấy.

	Giờ quét một lượt duy nhất mỗi tick, dựng danh sách ứng viên rồi dùng lại cho CẢ hai việc
	(chọn mục tiêu + phép thử chạm), thay vì hai vòng lặp Players riêng.
]]
-- Khoảng cách BỎ QUA CHIỀU CAO: boss chạy trên mặt sàn phẳng, chênh lệch Y (nhảy, đứng trên
-- bục) không được tính vào phép thử chạm lẫn phép đo thứ hạng.
local function getFlatDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

type Runner = { player: Player, character: Model, root: BasePart, position: Vector3 }

local runnerBuffer: { Runner } = {}

local function collectRunners(): { Runner }
	table.clear(runnerBuffer)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local position = root.Position
			if shouldChasePlayer(player, position) then
				table.insert(runnerBuffer, {
					player = player,
					character = character,
					root = root,
					position = position,
				})
			end
		end
	end
	return runnerBuffer
end

--[[
	MỤC TIÊU = NGƯỜI DẪN ĐẦU (chốt với user 2026-08-14), đo bằng khoảng cách còn lại tới
	Stage4Finish — ai gần đích nhất thì bị dí. Vì sao không phải người gần boss nhất:

	  • Ổn định. Thứ hạng trong cuộc đua đổi vài lần một ván, không phải 30 lần một giây, nên
	    boss chạy thành một đường liền mạch thay vì rung giữa hai người.
	  • Đúng vai của con boss. Nó là hình phạt dành cho người sắp thắng, nên người bị bỏ lại
	    có cửa bắt kịp — đó mới là thứ làm arena đáng chạy khi đông người.

	`LEAD_SWITCH_MARGIN`: người mới phải vượt người đang bị dí ÍT NHẤT 6 studs mới giành được
	sự chú ý. Không có mép này thì hai người chạy ngang nhau lại quay về đúng bệnh rung lắc cũ,
	chỉ là đổi trục đo.
]]
local LEAD_SWITCH_MARGIN = 6

local currentTargetPlayer: Player? = nil

local function scoreForRunner(runner: Runner, bossPosition: Vector3): number
	local gate = finishGate
	if gate then
		return getFlatDistance(runner.position, gate.Position)
	end
	-- Không tìm thấy cổng đích (map chưa nạp xong): quay về luật gần-nhất cho boss vẫn có việc.
	return getFlatDistance(runner.position, bossPosition)
end

local function pickLeader(runners: { Runner }, bossPosition: Vector3): Runner?
	local best: Runner? = nil
	local bestScore = math.huge
	local incumbent: Runner? = nil
	local incumbentScore = math.huge

	for _, runner in runners do
		local score = scoreForRunner(runner, bossPosition)
		if score < bestScore then
			best, bestScore = runner, score
		end
		if runner.player == currentTargetPlayer then
			incumbent, incumbentScore = runner, score
		end
	end

	-- Người đang bị dí vẫn còn trong sân và chưa bị vượt quá mép → giữ nguyên mục tiêu.
	if incumbent and bestScore > incumbentScore - LEAD_SWITCH_MARGIN then
		return incumbent
	end

	currentTargetPlayer = if best then best.player else nil
	return best
end

--[[
	Công bố tư thế boss cho client + ghi vào lịch sử bù trễ.

	`BossCF` là attribute DUY NHẤT thay đổi lúc chạy. Nó thay cho việc `PivotTo` model mỗi
	tick — xem khối lý do ở đầu file.
]]
local function publishPose(model: Model, cframe: CFrame, now: number)
	bossCFrame = cframe
	model:SetAttribute("BossCF", cframe)

	table.insert(history, { t = now, p = cframe.Position })
	-- Cắt phần quá hạn từ đầu. Bảng chỉ ~18 phần tử nên `table.remove(1)` là rẻ.
	while #history > 1 and now - history[1].t > HISTORY_SECONDS do
		table.remove(history, 1)
	end
end

--[[
	Vị trí boss tại `at` (giờ server), nội suy tuyến tính giữa hai mẫu lịch sử gần nhất.
	Ngoài tầm lịch sử thì kẹp về mẫu đầu/cuối — an toàn hơn ngoại suy, vì ngoại suy ở đây sẽ
	tạo ra một con boss chưa từng tồn tại ở đâu cả.
]]
local function positionAt(at: number): Vector3
	local n = #history
	if n == 0 then
		return bossCFrame.Position
	end
	if at >= history[n].t then
		return history[n].p
	end
	if at <= history[1].t then
		return history[1].p
	end
	for i = n - 1, 1, -1 do
		local a, b = history[i], history[i + 1]
		if at >= a.t then
			local span = b.t - a.t
			local alpha = if span > 1e-6 then (at - a.t) / span else 0
			return a.p:Lerp(b.p, alpha)
		end
	end
	return history[1].p
end

local function advanceToward(current: CFrame, targetPosition: Vector3, speed: number, deltaTime: number): CFrame
	local currentPosition = current.Position
	local flatTarget = Vector3.new(targetPosition.X, homePivot.Position.Y, targetPosition.Z)
	local offset = flatTarget - currentPosition
	if offset.Magnitude < 0.05 then
		return current
	end

	local stepDistance = speed * deltaTime
	local nextPosition = if offset.Magnitude <= stepDistance
		then flatTarget
		else currentPosition + offset.Unit * stepDistance

	nextPosition = Vector3.new(
		math.clamp(nextPosition.X, cachedArenaMinX, cachedArenaMaxX),
		homePivot.Position.Y,
		math.clamp(nextPosition.Z, cachedArenaMinZ, cachedArenaMaxZ)
	)

	local lookTarget = Vector3.new(flatTarget.X, nextPosition.Y, flatTarget.Z)
	local lookOffset = lookTarget - nextPosition
	if lookOffset.Magnitude > 0.05 then
		return CFrame.lookAt(nextPosition, lookTarget)
	end
	return CFrame.new(nextPosition) * (current - currentPosition)
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		activeEncounterPlayers[player] = nil
		-- Chết trong sân là mất suất bị dí: nhả mục tiêu ngay để boss chuyển sang người còn
		-- sống ở tick kế, thay vì chờ mép LEAD_SWITCH_MARGIN của một cái xác.
		if currentTargetPlayer == player then
			currentTargetPlayer = nil
		end
	end)
end

local function connectStageGates()
	local currentStartGate = startGate
	local currentFinishGate = finishGate
	local currentKillFloor = killFloor
	if not currentStartGate or not currentFinishGate then
		return
	end

	currentStartGate.Touched:Connect(function(hit: BasePart)
		local player = CharacterUtil.GetPlayerFromHit(hit)
		if not player then
			return
		end
		local currentStage = player:GetAttribute("CurrentStage")
		if type(currentStage) ~= "number" or currentStage < STAGE_NUMBER then
			player:SetAttribute("CurrentStage", STAGE_NUMBER)
		end
		activeEncounterPlayers[player] = true
		restingAtHome = false -- có người vào sân → đánh thức boss
	end)

	currentFinishGate.Touched:Connect(function(hit: BasePart)
		local player = CharacterUtil.GetPlayerFromHit(hit)
		if player then
			activeEncounterPlayers[player] = nil
			if player:GetAttribute("CurrentStage") == STAGE_NUMBER then
				player:SetAttribute("CurrentStage", COMPLETE_STAGE)
			end
		end
	end)

	if currentKillFloor then
		currentKillFloor.Touched:Connect(function(hit: BasePart)
			local character = CharacterUtil.GetCharacterFromHit(hit)
			local player = if character then Players:GetPlayerFromCharacter(character) else nil
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if player and character and root and root:IsA("BasePart") and shouldChasePlayer(player, root.Position) then
				killCharacter(player, character)
			end
		end)
	end
end

function Zone4BossService.Init()
	local foundZone, foundMechanics = resolveBossZoneAndMechanics()
	if not foundZone or not foundMechanics then
		warn("[Zone4BossService] Không tìm thấy Zone4/Mechanics qua Stage4Start")
		return
	end

	zone = foundZone
	mechanics = foundMechanics
	refreshArenaBounds()

	local foundStartGate = foundMechanics:FindFirstChild(START_GATE_NAME)
	local foundFinishGate = foundMechanics:FindFirstChild(FINISH_GATE_NAME)
	local foundKillFloor = foundMechanics:FindFirstChild(KILL_FLOOR_NAME)
	if foundStartGate and foundStartGate:IsA("BasePart") then
		startGate = foundStartGate
	end
	if foundFinishGate and foundFinishGate:IsA("BasePart") then
		finishGate = foundFinishGate
	end
	if foundKillFloor and foundKillFloor:IsA("BasePart") then
		killFloor = foundKillFloor
	end

	connectStageGates()
end

function Zone4BossService.Start()
	if not zone or not mechanics or not startGate or not finishGate then
		return
	end

	local model = ensureBoss()
	if not model then
		warn("[Zone4BossService] MonkeyBoss model không tìm thấy")
		return
	end

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ runAnimation })
		end)
		warmRunAnimation(model)
	end)

	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		activeEncounterPlayers[player] = nil
		lastKillTimes[player] = nil
		-- Người rời server mà vẫn là mục tiêu thì `pickLeader` giữ mãi một Player đã chết —
		-- boss đứng im chờ một người không còn tồn tại.
		if currentTargetPlayer == player then
			currentTargetPlayer = nil
		end
	end)

	print(
		"[Zone4BossService] MonkeyBoss sẵn sàng — server dí người gần nhất, 30Hz, ngủ khi sân trống"
	)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		accumulator += deltaTime
		if accumulator < TICK_RATE then
			return
		end
		local step = accumulator
		accumulator = 0

		local activeBoss = ensureBoss()
		if not activeBoss then
			return
		end

		local now = Workspace:GetServerTimeNow()
		local bossPivot = bossCFrame
		local runners = collectRunners()
		local leader = pickLeader(runners, bossPivot.Position)

		if leader then
			restingAtHome = false
			activeBoss:SetAttribute("EncounterState", "Chasing")
			playRunAnimation(activeBoss)
			publishPose(activeBoss, advanceToward(bossPivot, leader.position, CHASE_SPEED, step), now)

			--[[
				Phép thử chạm chạy trên MỌI người trong sân, không riêng người đang bị dí. Boss
				là một khối thịt đặc: ai lao vào nó cũng phải chết, kể cả người nó đang quay lưng
				lại. Bản cũ chỉ thử đúng mục tiêu nên người thứ hai đi xuyên qua boss vô sự.

				BÙ TRỄ (v3): mỗi người so với vị trí boss tại `now - delay` của CHÍNH HỌ — đúng
				khung hình họ đã thấy khi `runner.position` được chụp. Boss đi 56 studs/s nên ở
				195ms đó là 11 studs, gấp 3 lần bán kính chạm chết 3.75: không bù thì người ping
				cao chết khi con khỉ trên màn hình còn cách cả thân người.
			]]
			for _, runner in runners do
				local bossThen = positionAt(now - LagComp.Delay(runner.player) - VISUAL_SMOOTH_LAG)
				if getFlatDistance(runner.position, bossThen) <= TOUCH_KILL_DISTANCE then
					killCharacter(runner.player, runner.character)
				end
			end
			return
		end

		-- Không có ứng viên: về nhà rồi NGỦ, không PivotTo lại mỗi frame.
		currentTargetPlayer = nil
		if restingAtHome then
			return
		end

		local current = bossCFrame
		if (homePivot.Position - current.Position).Magnitude > 0.05 then
			activeBoss:SetAttribute("EncounterState", "Returning")
			playRunAnimation(activeBoss)
			publishPose(activeBoss, advanceToward(current, homePivot.Position, RETURN_SPEED, step), now)
		else
			activeBoss:SetAttribute("EncounterState", "Idle")
			publishPose(activeBoss, homePivot, now)
			stopRunAnimation()
			restingAtHome = true
		end
	end)
end

return Zone4BossService
