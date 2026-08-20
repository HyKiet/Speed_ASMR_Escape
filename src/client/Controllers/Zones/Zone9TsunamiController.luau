--!strict
--[[
	Zone9TsunamiController.luau — render local sóng Tsunami Stage 9.

	Server không PivotTo model (xem Zone9.Mechanics.Tsunami.TsunamiScript): vị trí sóng suy ra
	từ workspace:GetServerTimeNow() nên client dựng lại y hệt → 0 byte CFrame replication cho
	~15 part mỗi frame.

	v4 (2026-07-22): GỠ TOÀN BỘ rig hạt bọt/khói theo yêu cầu. Rig cũ chạy 3 ParticleEmitter
	(~230 hạt/giây, texture smoke_main) + 1 PointLight bám theo sóng — đây là khoản nặng nhất
	của zone này trên máy yếu, và bản thân khối sóng đã đủ rõ. Bỏ luôn nên không còn gì để cull.

	v7 (2026-08-12): ĐOÀN NHIỀU SÓNG. Server chạy `WAVE_COUNT` sóng cách đều nhau `WaveSpacing`
	giây (xem TsunamiScript v7 — 1 sóng cho gate chỉ 96 WS, quá thấp so với Bảng 138). Model
	trong map chỉ có MỘT bộ part, nên các sóng sau được dựng bằng BẢN SAO CỤC BỘ: clone từng
	part vào một Folder riêng của client, không neo vào map, không va chạm, không truy vấn.

	⚠️ Số sóng vẽ ra PHẢI khớp `WaveCount` của server. Vẽ thiếu = có sóng vô hình giết người
	chơi — lỗi tệ nhất mà một cơ chế bẫy có thể mắc. Vì thế client đọc thẳng attribute chứ
	không giữ hằng số riêng.

	v8 (2026-08-13): server quay về `WAVE_COUNT = 1` theo yêu cầu user. File này KHÔNG đổi —
	đó chính là phần thưởng của việc đọc attribute: `waveCount = 1` ⇒ không clone bản sao nào,
	`echoFolder` không bao giờ được tạo, vòng lặp chạy đúng một lượt.

	v5 (2026-07-26): FIX SÓNG MÉO HÌNH trên client. Bản cũ `model:PivotTo(...)` mỗi frame:
	dưới StreamingEnabled, part stream về LẺ TẺ tại vị trí HOME của server (server không bao
	giờ dời part) trong khi model client đã trôi giữa sweep → offset tương đối của part mới
	so với pivot bị SAI, PivotTo giữ nguyên cái sai đó vĩnh viễn → khối sóng rách/vặn
	(nhìn từ Server view thì lành lặn vì server không move gì). Fix: ghi nhớ offset của
	TỪNG part so với HOME CFrame (tính từ attribute — bất biến) ngay lúc part stream về,
	rồi mỗi frame set part.CFrame = waveCF × offset. Part về muộn bao nhiêu cũng đúng hình.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ZoneLod = require(script.Parent.ZoneLod)

-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed — xem ZoneLod.
-- Sóng thần đặc biệt cần tầm xa: nó ĐUỔI người chơi 118 studs/s, thấy nó từ sớm mới canh
-- được nhịp xuất phát.
local RENDER_RADIUS = 420

local Zone9TsunamiController = {}

local model: Model? = nil
local waveSpeed, homeX, finishX, baseY, channelZ = 0, 0, 0, 0, 0
local baseRot = CFrame.identity
local homeCF = CFrame.identity -- CFrame pivot lúc sóng ở home (nguồn sự thật cho offset part)
local cycle, sweepDuration = 1, 1

-- `echoes` = bản sao cục bộ của part này, mỗi phần tử là một sóng phía sau (sóng 1, 2, ...).
type PartRecord = { rel: CFrame, transparency: number, echoes: { BasePart } }
local partRecords: { [BasePart]: PartRecord } = {}
local hidden = false
local nextFarStep = 0

local waveCount = 1
local waveSpacing = 0
local echoFolder: Folder? = nil
-- Sóng nào đang ẩn (pha "wait"). index 1 = sóng dẫn đầu (part gốc), 2.. = bản sao.
local waveHidden: { boolean } = {}

local ready = false
local connection: RBXScriptConnection? = nil
local descAddedConn: RBXScriptConnection? = nil

--[[
	Đăng ký một part của sóng: chốt offset so với homeCF, rồi dựng bản sao cho các sóng phía
	sau. Bản sao là VẬT TRANG TRÍ thuần tuý — server phán xử theo đồng hồ, không theo part —
	nên phải tắt hết va chạm/truy vấn để không ai vấp vào một cái bóng.
]]
function registerPart(d: BasePart)
	if partRecords[d] ~= nil then
		return
	end
	local echoes: { BasePart } = {}
	if waveCount > 1 then
		if not echoFolder then
			local folder = Instance.new("Folder")
			folder.Name = "Zone9TsunamiEchoes"
			folder.Parent = Workspace
			echoFolder = folder
		end
		for _ = 2, waveCount do
			local clone = d:Clone()
			-- Xoá mọi thứ có thể chạy/kêu trong bản sao: nó chỉ là hình.
			for _, sub in clone:GetDescendants() do
				if sub:IsA("LuaSourceContainer") or sub:IsA("Sound") then
					sub:Destroy()
				end
			end
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = false
			clone.Parent = echoFolder
			table.insert(echoes, clone)
		end
	end
	partRecords[d] = {
		-- d.CFrame lúc này là CFrame home do server replicate (server không move part).
		rel = homeCF:ToObjectSpace(d.CFrame),
		transparency = d.Transparency,
		echoes = echoes,
	}
	if hidden then
		d.Transparency = 1
		for _, e in echoes do
			e.Transparency = 1
		end
	end
end

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone9")
	local mech = zone and zone:FindFirstChild("Mechanics")
	local found = mech and mech:FindFirstChild("Tsunami")
	if not (zone and found and found:IsA("Model")) then
		return false
	end

	local speedAttr = zone:GetAttribute("WaveSpeed")
	local cycleAttr = zone:GetAttribute("WaveCycle")
	local rotAttr = zone:GetAttribute("WaveRot")
	if typeof(speedAttr) ~= "number" or typeof(cycleAttr) ~= "number" or typeof(rotAttr) ~= "CFrame" then
		return false
	end

	model = found
	waveSpeed = speedAttr
	cycle = cycleAttr
	baseRot = rotAttr
	-- Mặc định 1 sóng: bản map cũ chưa có hai attribute này. Nhưng nếu server v7 đang chạy mà
	-- client đọc hụt thì sóng sau thành vô hình, nên KHÔNG bịa giá trị — chỉ ngã về đúng
	-- hành vi cũ khi attribute thật sự không tồn tại.
	local countAttr = zone:GetAttribute("WaveCount")
	waveCount = if typeof(countAttr) == "number" then math.max(1, math.floor(countAttr)) else 1
	local spacingAttr = zone:GetAttribute("WaveSpacing")
	waveSpacing = if typeof(spacingAttr) == "number" then spacingAttr else cycle / waveCount
	homeX = zone:GetAttribute("WaveHomeX") :: number
	finishX = zone:GetAttribute("WaveFinishX") :: number
	baseY = zone:GetAttribute("WaveY") :: number
	channelZ = zone:GetAttribute("WaveZ") :: number
	sweepDuration = zone:GetAttribute("WaveSweepDuration") :: number
	homeCF = CFrame.new(homeX, baseY, channelZ) * baseRot

	table.clear(partRecords)
	if echoFolder then
		echoFolder:Destroy()
	end
	echoFolder = nil
	table.clear(waveHidden)

	-- Đăng ký part NGAY khi stream về (poll 0.5s chỉ là lưới an toàn) — part mới phải được
	-- chốt offset trước khi step() kịp thấy nó nằm chỏng chơ ở home giữa lúc sóng đang chạy.
	if descAddedConn then
		descAddedConn:Disconnect()
	end
	descAddedConn = found.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			registerPart(d)
		end
	end)
	return true
end

-- StreamingEnabled: part của sóng stream về LẺ TẺ sau khi resolve() chạy. Mỗi part mới
-- phải được đăng ký NGAY tại vị trí server (= vị trí home) để chốt offset so với homeCF;
-- từ đó về sau client tự đặt CFrame cho nó — part về muộn không bao giờ lệch hình nữa.
local function refreshParts()
	local target = model
	if not target then
		return
	end
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") then
			registerPart(d)
		end
	end
end

-- Ẩn/hiện TOÀN BỘ đoàn sóng (dùng khi ra ngoài tầm nhìn).
local function setHidden(state: boolean)
	if hidden == state then
		return
	end
	hidden = state
	table.clear(waveHidden)
	for part, rec in partRecords do
		part.Transparency = state and 1 or rec.transparency
		for _, e in rec.echoes do
			e.Transparency = state and 1 or rec.transparency
		end
	end
end

-- Ẩn/hiện MỘT sóng trong đoàn (index 1 = part gốc, 2.. = bản sao). Mỗi sóng có pha riêng nên
-- lúc sóng này đang quét thì sóng kia có thể đang ở pha chờ và phải biến mất.
local function setWaveHidden(index: number, state: boolean)
	if waveHidden[index] == state then
		return
	end
	waveHidden[index] = state
	for part, rec in partRecords do
		if index == 1 then
			part.Transparency = state and 1 or rec.transparency
		else
			local echo = rec.echoes[index - 1]
			if echo then
				echo.Transparency = state and 1 or rec.transparency
			end
		end
	end
end

local function step()
	local target = model
	-- StreamingEnabled=true: model có thể bị dỡ khi đi xa → resolve lại, đừng chết cứng.
	if not target or not target:IsDescendantOf(Workspace) then
		model = nil
		hidden = false
		ready = false
		table.clear(partRecords)
		table.clear(waveHidden)
		-- Bản sao KHÔNG nằm trong model gốc nên streaming không dọn hộ: tự xoá, nếu không
		-- mỗi lần ra vào zone lại bỏ lại một đoàn sóng ma đứng im giữa kênh.
		if echoFolder then
			echoFolder:Destroy()
			echoFolder = nil
		end
		if descAddedConn then
			descAddedConn:Disconnect()
			descAddedConn = nil
		end
		return
	end

	-- Gốc nhân vật tra MỘT lần mỗi frame cho cả bảy controller bẫy, không phải mỗi
	-- controller một lần `FindFirstChild` — xem `ZoneLod.Root`.
	if not ZoneLod.Root() then
		return
	end
	local rootPos = ZoneLod.RootPosition()

	local dx = rootPos.X - (homeX + finishX) * 0.5
	local dz = rootPos.Z - channelZ
	local distSq = dx * dx + dz * dz
	if distSq > ZoneLod.RadiusSq(RENDER_RADIUS) then
		-- SLEEP: quá xa, ngừng cập nhật vị trí — nhưng PHẢI ẩn sóng trước.
		setHidden(true)
		return
	end

	local now = ZoneLod.Now()
	local shouldStep: boolean
	shouldStep, nextFarStep = ZoneLod.ShouldStepFar(distSq, now, nextFarStep)
	if not shouldStep then
		return
	end

	-- Còn trong tầm: bỏ cờ ẩn-toàn-đoàn, từ đây mỗi sóng tự quyết theo pha của nó.
	setHidden(false)

	for index = 1, waveCount do
		local t = (now - (index - 1) * waveSpacing) % cycle
		if t >= sweepDuration then
			setWaveHidden(index, true)
		else
			setWaveHidden(index, false)
			local waveCF = CFrame.new(homeX + waveSpeed * t, baseY, channelZ) * baseRot
			for part, rec in partRecords do
				if index == 1 then
					part.CFrame = waveCF * rec.rel
				else
					local echo = rec.echoes[index - 1]
					if echo then
						echo.CFrame = waveCF * rec.rel
					end
				end
			end
		end
	end
end

function Zone9TsunamiController.Init() end

function Zone9TsunamiController.Start()
	connection = RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			if not ready then
				ready = resolve()
			end
			if ready then
				refreshParts()
			end
			task.wait(0.5)
		end
	end)
end

function Zone9TsunamiController.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Zone9TsunamiController
