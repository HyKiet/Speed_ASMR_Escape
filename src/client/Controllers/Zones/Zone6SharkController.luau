--!strict
--[[
	Zone6SharkController — v2 (2026-08-27): CLIENT TỰ VẼ cá mập Zone 6, và tự phán xử.

	── VÌ SAO ĐỔI ──────────────────────────────────────────────────────────────────────────
	v1 chỉ làm phần "chạm chết", còn hình cá do SERVER ghi `root.CFrame` mỗi Heartbeat rồi
	replicate về. Ý đồ của v1 là "tính chết theo đúng vị trí cá mà người chơi ĐANG NHÌN THẤY"
	— nhưng vị trí đó lại là vị trí ĐÃ TRỄ một chiều mạng, và part neo do script dời thì client
	không nội suy: nó NHẢY mỗi khi gói tới. Ở ping 390ms (user đo 2026-08-27) cú vọt của cá
	giật thành từng nấc, và stage càng đông người thì gói càng thưa, giật càng rõ. Đây đúng là
	thứ user mô tả: "không phải lag game, giống lag mạng".

	v2 đưa cá về đúng kiến trúc chung của game (Zone 2/3/8/9/11/12/15): nhịp vốn đã là một hàm
	THUẦN của thời gian, nên client dựng lại được y hệt từ đồng hồ tất định. Server chỉ clone
	cá + công bố tham số rồi im (xem tools/zone6_shark_inline.luau). Kết quả:
	  • 0 byte replicate, cú vọt mượt tuyệt đối bất kể ping.
	  • Hình và phán xử giờ dùng CHUNG một phép tính, nên "khớp hình" là đúng theo định nghĩa
	    chứ không còn là xấp xỉ.

	Kill = set Humanoid.Health = 0 của CHÍNH mình (client sở hữu nhân vật → replicate).
	Tự sát môi trường không phải lỗ hổng (chỉ hại chính mình). 0 packet, 0 chi phí server.

	⚠️ StreamingEnabled: KHÔNG dùng `model:PivotTo()` ở client. Part stream về lẻ tẻ tại vị trí
	HOME của server trong lúc model client đã trôi ⇒ PivotTo ghim vĩnh viễn offset sai đó (đã
	dính ở sóng Zone 9). Nhớ `rel` từ attribute BẤT BIẾN rồi ghi `part.CFrame = rootCF * rel`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ZoneLod = require(script.Parent.ZoneLod)

local Zone6SharkController = {}

local KILL_R = 8 -- bán kính chạm thân cá (cá to → hitbox rộng cho công bằng)
-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed — xem ZoneLod.
-- Khe giữa hai đảo rộng ~110 studs nên 300 phủ được cả cụm cá lân cận.
local RENDER_RADIUS = 300
local RESOLVE_INTERVAL = 0.5

type Part = { part: BasePart, rel: CFrame }
type Shark = {
	root: BasePart,
	parts: { Part },
	center: Vector3,
	lat: Vector3,
	phase: number,
	parkCF: CFrame,
	awake: boolean,
	nextFar: number,
	-- Vị trí/tư thế của frame gần nhất, do CHÍNH controller này tính. Phép phán xử đọc từ
	-- đây chứ không đọc `root.CFrame`: hai thứ luôn bằng nhau, nhưng đọc biến rẻ hơn và
	-- không phụ thuộc vào việc part đã stream về hay chưa.
	cf: CFrame,
	halfLen: number,
	breaching: boolean,
}

-- Tham số nhịp, server công bố (giữ y hệt bản v1 nên độ khó không đổi).
local arcTime, diveTime, span, parkY, apexY, breachY = 1.7, 1.5, 14, -34, 24, 1
local cycle = arcTime + diveTime

local player = Players.LocalPlayer
local sharks: { Shark } = {}
local sharksFolder: Instance? = nil

local function distToSeg(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom < 1e-4 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / denom, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

--[[
	Tư thế của một con cá tại thời điểm `now`. CHÉP NGUYÊN công thức của Zone6SharkScript v1
	— đây là hợp đồng: đổi một dòng ở đây mà không đổi bên kia là cá bơi sai nhịp so với thiết
	kế của zone.

	Trả về (CFrame, đang-vọt-lên-khỏi-mặt-nước).
]]
local function poseAt(shark: Shark, now: number): (CFrame, boolean)
	local u = now + shark.phase
	local ct = u % cycle
	if ct > arcTime then
		-- ẩn sâu dưới killblock
		return shark.parkCF, false
	end

	local ph = math.pi * (ct / arcTime)
	-- xen kẽ hướng lướt mỗi chu kỳ (qua trái ↔ qua phải)
	local dir = if math.floor(u / cycle) % 2 == 0 then 1 else -1
	-- NGANG: ease cos → chậm lúc rẽ nước, nhanh ở đỉnh (breach duyên dáng)
	local slat = (-span * math.cos(ph)) * dir
	-- DỌC: nửa cung sin từ PARK (ẩn) lên APEX
	local y = parkY + (apexY - parkY) * math.sin(ph)
	local pos = shark.center + shark.lat * slat + Vector3.new(0, y, 0)

	-- vận tốc để xoay đầu
	local vLat = shark.lat * (span * math.pi * math.sin(ph) * dir)
	local vY = (apexY - parkY) * math.pi * math.cos(ph)
	local vel = vLat + Vector3.new(0, vY, 0)
	if vel.Magnitude < 0.01 then
		vel = shark.lat * dir
	end
	-- đầu (+Z) dẫn hướng → lookAt target = pos - vel; thêm NGHIÊNG thân theo bề ngang
	local roll = math.clamp(-(vLat.Magnitude / 40) * dir, -0.5, 0.5)
	return CFrame.lookAt(pos, pos - vel.Unit) * CFrame.Angles(0, 0, roll), y > breachY
end

local function getNumberAttr(inst: Instance, name: string, fallback: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else fallback
end

local function resolve()
	table.clear(sharks)

	local zones = Workspace:FindFirstChild("Zones")
	local zone6 = zones and zones:FindFirstChild("Zone6")
	local mech = zone6 and zone6:FindFirstChild("Mechanics")
	local folder = mech and mech:FindFirstChild("Sharks")
	if not folder or folder:GetAttribute("SharksReady") ~= true then
		return
	end
	sharksFolder = folder

	arcTime = getNumberAttr(folder, "SharkArcTime", arcTime)
	diveTime = getNumberAttr(folder, "SharkDiveTime", diveTime)
	span = getNumberAttr(folder, "SharkSpan", span)
	parkY = getNumberAttr(folder, "SharkParkY", parkY)
	apexY = getNumberAttr(folder, "SharkApexY", apexY)
	breachY = getNumberAttr(folder, "SharkBreachY", breachY)
	cycle = arcTime + diveTime

	for _, model in folder:GetChildren() do
		local root = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChild("SharkRoot"))
		local center = model:GetAttribute("Center")
		local lat = model:GetAttribute("Lat")
		local parkCF = model:GetAttribute("ParkCF")
		local phase = model:GetAttribute("Phase")
		if
			root
			and root:IsA("BasePart")
			and typeof(center) == "Vector3"
			and typeof(lat) == "Vector3"
			and typeof(parkCF) == "CFrame"
			and type(phase) == "number"
		then
			local parts: { Part } = {}
			for _, part in model:GetDescendants() do
				-- `HomeCF` là CFrame BẤT BIẾN do server ghi lúc cá còn ở tư thế đỗ. KHÔNG đọc
				-- `part.CFrame`: client đã dời part rồi, lấy nhầm là cá rã dần từng frame.
				local home = part:IsA("BasePart") and part:GetAttribute("HomeCF")
				if part:IsA("BasePart") and typeof(home) == "CFrame" then
					table.insert(parts, { part = part, rel = parkCF:ToObjectSpace(home) })
				end
			end
			if #parts > 0 then
				table.insert(sharks, {
					root = root,
					parts = parts,
					center = center,
					lat = lat,
					phase = phase,
					parkCF = parkCF,
					awake = false,
					nextFar = 0,
					cf = parkCF,
					halfLen = root.Size.Z * 0.5,
					breaching = false,
				})
			end
		end
	end
end

-- Số part cá ĐÃ stream về. So với số đã cache mỗi vòng poll: `resolve()` chạy sớm chỉ bắt
-- được vài con, phần stream sau sẽ không bao giờ được vẽ (đã dính ở Zone 14 + 15).
local function streamedPartCount(): number
	local folder = sharksFolder
	if not folder or not folder:IsDescendantOf(Workspace) then
		return -1
	end
	local n = 0
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("HomeCF") ~= nil then
			n += 1
		end
	end
	return n
end

local function cachedPartCount(): number
	local n = 0
	for i = 1, #sharks do
		n += #sharks[i].parts
	end
	return n
end

local function alive(): boolean
	return #sharks > 0 and sharks[1].root:IsDescendantOf(Workspace)
end

local function writePose(shark: Shark, cf: CFrame)
	for i = 1, #shark.parts do
		local rec = shark.parts[i]
		rec.part.CFrame = cf * rec.rel
	end
end

local function step()
	if not alive() then
		return
	end
	if not ZoneLod.Root() then
		return
	end
	local pos = ZoneLod.RootPosition()
	local now = ZoneLod.Now()
	local radiusSq = ZoneLod.RadiusSq(RENDER_RADIUS)

	-- Cull theo TỪNG con: dải Zone 6 trải ~300 studs, người chơi luôn gần một khe và xa các
	-- khe còn lại.
	for i = 1, #sharks do
		local shark = sharks[i]
		local dx, dz = pos.X - shark.center.X, pos.Z - shark.center.Z
		local distSq = dx * dx + dz * dz
		if distSq <= radiusSq then
			local shouldStep: boolean
			shouldStep, shark.nextFar = ZoneLod.ShouldStepFar(distSq, now, shark.nextFar)
			if shouldStep then
				local cf, breaching = poseAt(shark, now)
				shark.cf = cf
				shark.breaching = breaching
				writePose(shark, cf)
			end
			shark.awake = true
		elseif shark.awake then
			-- Ngủ: hạ cá về tư thế đỗ (ẩn sâu dưới killblock) ĐÚNG MỘT LẦN. Bỏ qua bước này
			-- thì cá treo lơ lửng giữa cung khi nhìn từ xa.
			shark.awake = false
			shark.cf = shark.parkCF
			shark.breaching = false
			writePose(shark, shark.parkCF)
		end
	end
end

local dead = false

local function judge()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and root:IsA("BasePart")) or hum.Health <= 0 then
		dead = false
		return
	end
	if dead then
		return
	end

	local pos = root.Position
	for i = 1, #sharks do
		local shark = sharks[i]
		-- Chỉ cá đã nhô khỏi mặt nước mới giết. `breaching` do CHÍNH `step` ở trên tính, nên
		-- nó luôn thuộc cùng một khung hình với hình người chơi thấy.
		if shark.breaching then
			local cf = shark.cf
			local half = shark.halfLen
			local nose = cf * Vector3.new(0, 0, half)
			local tail = cf * Vector3.new(0, 0, -half)
			if distToSeg(pos, nose, tail) <= KILL_R then
				dead = true
				hum.Health = 0
				break
			end
		end
	end
end

function Zone6SharkController.Init() end

function Zone6SharkController.Start()
	RunService.RenderStepped:Connect(step)
	RunService.Heartbeat:Connect(judge)

	task.spawn(function()
		while true do
			-- Re-resolve khi mất tham chiếu HOẶC khi streaming vừa nạp thêm part cá.
			if not alive() or cachedPartCount() ~= streamedPartCount() then
				resolve()
			end
			task.wait(RESOLVE_INTERVAL)
		end
	end)

	Log.Boot("[Zone6SharkController] v2 — client tự vẽ + tự phán xử (0 replication)")
end

return Zone6SharkController
