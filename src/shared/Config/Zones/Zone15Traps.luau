--!strict
--[[
	Zone15Traps.luau — NGUỒN SỰ THẬT DUY NHẤT cho 3 bẫy của Stage 15.

	Gồm 3 phần:
	  (a) Thông số nhịp/kích thước của từng bẫy.
	  (b) HÀM TOÁN THUẦN suy ra trạng thái bẫy từ `workspace:GetServerTimeNow()`.
	      Server và client cùng require file này nên luôn ra CÙNG kết quả mà KHÔNG cần
	      replicate CFrame — 0 byte/khung hình.
	  (c) `Build()` dựng hình học bẫy. Gọi được từ cả server lúc chạy LẪN Studio Edit
	      (execute_luau) → chỉ có MỘT bản dựng duy nhất, map và game không bao giờ lệch nhau.

	ĐẶT BẪY BẰNG MARKER (quan trọng cho người dựng map):
	  Vị trí bẫy 1 & 2 lấy từ part mốc `Zone15.Mechanics.TrapMarkers.Trap1 / .Trap2`.
	  • Trục X cục bộ của marker (RightVector) = HƯỚNG CHẠY.
	  • Trục Z cục bộ (LookVector, cạnh dài 72) = BỀ NGANG hành lang.
	  Kéo/xoay marker trong Studio rồi xoá cụm bẫy cũ đi là bẫy dựng lại đúng chỗ mới.
	  `Build()` KHÔNG đụng vào cụm đã có sẵn → chỉnh tay trong Studio không bị ghi đè.

	Mỗi part bẫy mang attribute `HomeCF` = CFrame gốc. Client dời part cục bộ nên KHÔNG
	được lấy vị trí hiện thời làm gốc; luôn đọc `HomeCF`.
]]

local Zone15Traps = {}

-- WalkSpeed gợi ý của Stage 15 (Stages.STAGE_GATES[15].minWS) — mốc canh nhịp mọi bẫy.
Zone15Traps.REF_SPEED = 234
Zone15Traps.MARKER_FOLDER = "TrapMarkers"

-- smoothstep: đầu/cuối chậm, giữa nhanh → chuyển động đọc được bằng mắt ở tốc độ cao.
local function smooth(a: number): number
	if a <= 0 then
		return 0
	elseif a >= 1 then
		return 1
	end
	return a * a * (3 - 2 * a)
end
Zone15Traps.Smooth = smooth

--=====================================================================================
-- BẪY 1 — LASER SWEEP: 2 tia mảnh SÁT MẶT SÀN trượt tới-lui dọc đường chạy.
-- Chạy thẳng vào tia = chết; phải NHẢY qua. Hai tia lệch pha 180° nên chúng chụm vào
-- rồi tách ra như lưỡi kéo — người chơi đọc được khe an toàn từ xa.
--=====================================================================================
Zone15Traps.Sweep = {
	MarkerName = "Trap1",
	ClusterName = "LaserSweep",

	BeamSize = Vector3.new(3, 3, 72), -- X mỏng (dọc hướng chạy), Z = bề ngang hành lang
	BeamYOffset = 1.1, -- so với tâm marker → đáy tia nằm sát mặt sàn

	-- Offset = vị trí tâm quét, tính từ marker theo hướng chạy.
	Beams = {
		{ Offset = -60, Phase = 0 },
		{ Offset = 60, Phase = math.pi },
	},
	Amplitude = 60,
	Period = 2.8,

	-- VÙNG SÁT THƯƠNG (toạ độ cục bộ so với HomeCF của tia) — bám SÁT hộp tia nhìn thấy.
	-- Nhân vật cao ~5 studs, HumanoidRootPart nằm cách bàn chân 3 studs → tâm thân người
	-- = hrp.Y - 0.5, nửa chiều cao thân = 2.5. Cộng với nửa hộp tia (1.5 mỗi chiều):
	--   dọc  : 1.5 + 2.5 = 4.0   (nhảy cao hơn ~4 studs là chắc chắn thoát)
	--   dày  : 1.5 + 1.0 = 2.5   (1.0 = nửa bề dày thân người)
	--   ngang: 36 + 1.0 = 37     (đúng nửa chiều dài tia + nửa bề ngang thân)
	BodyCenterYOffset = -0.5,
	HalfWidth = 37,
	HalfHeight = 4.0,
	HalfThickness = 2.5,

	Color = Color3.fromRGB(255, 58, 92),
	ColorHot = Color3.fromRGB(255, 214, 96),
}

local SW = Zone15Traps.Sweep

-- Độ dời của tia thứ i so với tâm quét, theo hướng chạy (studs).
function Zone15Traps.SweepOffset(now: number, index: number): number
	local beam = SW.Beams[index]
	return SW.Amplitude * math.sin(now * (2 * math.pi / SW.Period) + beam.Phase)
end

--=====================================================================================
-- KÍCH HOẠT THEO NGƯỜI CHƠI (2026-08-22, user) — dùng chung cho BẪY 2 và BẪY 3.
--
-- Trước đây hai bẫy này chạy theo NHỊP VÒNG LẶP của đồng hồ server: chúng mở/đóng mãi mãi
-- bất kể có ai hay không. Ở tốc độ Stage 15 (234 WS) người chơi tới nơi ở một pha ngẫu
-- nhiên — có lượt đi lọt không cần làm gì, có lượt chết mà chẳng hiểu vì sao. Bẫy không
-- DẠY được điều gì vì nó chẳng phản ứng với người chơi.
--
-- Giờ bẫy NGỦ (sàn kín, đi được) cho tới khi người chơi lại gần thì:
--     nhấp nháy ĐỎ (WarnSeconds) → trượt mở (OpenSeconds) → giữ hở (HoldSeconds)
--     → trượt về (CloseSeconds) → nghỉ (RearmSeconds) → sẵn sàng kích lại.
--
-- MẤU CHỐT LÀ BÁN KÍNH KÍCH TÍNH BẰNG GIÂY, KHÔNG PHẢI STUDS: `TriggerRadius(walkSpeed)`
-- = quãng đường người chơi đi trong `LeadSeconds`. Nên với MỌI tốc độ, bẫy luôn bắt đầu
-- nháy đúng ~0.95 giây trước khi họ tới, và mặt sàn biến mất ngay lúc họ đặt chân lên nếu
-- họ cứ thế lao tới. Muốn qua thì phải NHÌN: thấy nháy đỏ là ghìm lại, đợi tấm trượt về
-- rồi băng qua trong cửa sổ an toàn (`RearmSeconds` + `WarnSeconds` ≈ 1.75s).
--
-- ⚠️ Đây là trạng thái CỤC BỘ TỪNG CLIENT (bẫy 2 & 3 không có một dòng logic server nào —
-- chúng giết gián tiếp bằng cách để người chơi rơi xuống KillBlockGlobal). Nghĩa là mỗi
-- người thấy bẫy phản ứng với CHÍNH MÌNH, và người đứng xem thấy lệch pha với người đang
-- chạy. Đó là đánh đổi CÓ CHỦ Ý: đổi lại là 0 byte replication và bẫy công bằng với từng
-- người, thay vì một nhịp chung mà ai vào đúng pha xấu thì chịu.
--=====================================================================================
Zone15Traps.Trigger = {
	-- Người chơi còn ngần này GIÂY nữa thì tới bẫy ⇒ kích. Phải > WarnSeconds, phần dư
	-- (0.4s) là khoảng người chơi còn kịp phanh nếu họ đang để mắt.
	LeadSeconds = 0.95,
	-- Kẹp hai đầu: người mới (WalkSpeed 16) vẫn phải thấy bẫy động từ xa; người 1000+ WS thì
	-- không kích bẫy từ nửa zone bên kia.
	MinRadius = 110,
	MaxRadius = 460,

	WarnSeconds = 0.55,
	OpenSeconds = 0.30,
	HoldSeconds = 1.50,
	CloseSeconds = 0.50,
	RearmSeconds = 1.20,

	BlinkHz = 15,
	-- Đỏ báo động, dùng cho CẢ hai bẫy (bẫy 3 trước đây dùng cam 255,92,48 — chưa đủ hét lên).
	ColorAlarm = Color3.fromRGB(255, 38, 38),
}

local TR = Zone15Traps.Trigger

-- Tổng thời gian một lượt kích, tính từ lúc bắt đầu nháy tới lúc tấm về chỗ.
Zone15Traps.ARMED_SPAN = TR.WarnSeconds + TR.OpenSeconds + TR.HoldSeconds + TR.CloseSeconds

-- Bán kính kích (studs) ứng với tốc độ hiện tại. Xem khối lý do ở trên.
function Zone15Traps.TriggerRadius(walkSpeed: number): number
	return math.clamp(walkSpeed * TR.LeadSeconds, TR.MinRadius, TR.MaxRadius)
end

-- `elapsed` = giây kể từ lúc bẫy được kích. 0 = sàn kín (đi được), 1 = mở hết (khe hở).
function Zone15Traps.ArmedAlpha(elapsed: number): number
	local t = elapsed - TR.WarnSeconds
	if t <= 0 then
		return 0
	end
	if t < TR.OpenSeconds then
		return smooth(t / TR.OpenSeconds)
	end
	t -= TR.OpenSeconds
	if t < TR.HoldSeconds then
		return 1
	end
	t -= TR.HoldSeconds
	if t < TR.CloseSeconds then
		return 1 - smooth(t / TR.CloseSeconds)
	end
	return 0
end

-- 0..1 cường độ nháy đỏ (chỉ màu, không ảnh hưởng va chạm). Nháy MẠNH DẦN về cuối để đoạn
-- cuối cùng trước khi sàn mở là đoạn chói nhất — người chơi đọc được "sắp rồi" chứ không chỉ
-- "đang có gì đó nhấp nháy".
function Zone15Traps.ArmedWarn(elapsed: number, now: number): number
	if elapsed < 0 or elapsed >= TR.WarnSeconds then
		return 0
	end
	local ramp = 0.35 + 0.65 * (elapsed / TR.WarnSeconds)
	return ramp * (0.5 + 0.5 * math.sin(now * (2 * math.pi * TR.BlinkHz) * 0.5))
end

--=====================================================================================
-- BẪY 2 — SHIFT BRIDGE: 2 tấm sàn lấp khe đã cắt sẵn trên đường chạy, trượt NGANG ra
-- khỏi lối đi khi người chơi tới gần. Tấm rời chỗ mà người chơi vẫn chạy tới = rơi xuống biển.
--=====================================================================================
Zone15Traps.Shuttle = {
	MarkerName = "Trap2",
	ClusterName = "ShiftBridge",

	-- Tấm sàn do người dựng map tự làm (Model nhiều part, đúng style sàn gốc) rồi đặt vào
	-- cụm ShiftBridge. Offset/PadSize bên dưới CHỈ dùng khi cụm còn rỗng và cần dựng bù.
	PadSize = Vector3.new(50, 4, 54), -- X dọc hướng chạy, Z ngang hành lang
	PadYOffset = -2, -- mặt tấm ngang mặt sàn (marker đặt ngang mặt sàn)

	-- Dir = chiều trượt ngang (±); Delay = giây TRỄ so với lúc bẫy được kích. Tấm gặp sau mở
	-- muộn đúng thời gian chạy từ tấm trước sang (47.7 studs ÷ 234) → hai tấm mở nối đuôi
	-- nhau theo đúng nhịp chân người chơi, không phải mở đồng loạt.
	Pads = {
		{ Offset = -24, Dir = 1, Delay = 0 },
		{ Offset = 24, Dir = -1, Delay = 47.7 / 234 },
	},
	Amplitude = 60, -- tấm rộng 72, hành lang rộng 48 → trượt 60 là rời hẳn lối đi

	Color = Color3.fromRGB(96, 214, 255),
}

local SH = Zone15Traps.Shuttle

-- Độ dời NGANG của tấm thứ i (studs, theo trục bề ngang hành lang).
-- `elapsed` = giây kể từ lúc CỤM được kích; mỗi tấm tự trừ phần trễ của nó.
function Zone15Traps.ShuttleOffset(elapsed: number, index: number): number
	local pad = SH.Pads[index]
	return pad.Dir * SH.Amplitude * Zone15Traps.ArmedAlpha(elapsed - pad.Delay)
end

--=====================================================================================
-- BẪY 3 — SPLIT FLOOR: cầu cuối chặng gồm 2 LÀN song song (model có sẵn trong map).
-- Cả làn trượt NGANG ra khỏi đường như một khối, hai làn về hai phía ngược nhau:
--   Obby_Open1 (Z 3481, phía trái theo hướng chạy +X) → trượt -Z
--   Obby_Open2 (Z 3517, phía phải)                    → trượt +Z
-- Hai làn mở CÙNG LÚC → mất sạch mặt cầu 170 studs. Kích khi người chơi tới gần, có
-- `Trigger.WarnSeconds` nhấp nháy đỏ báo trước (xem khối KÍCH HOẠT THEO NGƯỜI CHƠI ở trên).
--=====================================================================================
Zone15Traps.SplitFloor = {
	-- Dir = chiều trượt theo trục Z cục bộ của từng làn.
	Lanes = {
		{ Name = "Obby_Open1", Dir = -1 },
		{ Name = "Obby_Open2", Dir = 1 },
	},
	Slide = 40, -- làn rộng 36 → trượt 40 là rời hẳn khỏi đường chạy

	ColorWarn = TR.ColorAlarm,
}

local F = Zone15Traps.SplitFloor

--=====================================================================================
-- DỰNG HÌNH HỌC — dùng chung cho server (runtime) và Studio Edit (bake vào map).
--=====================================================================================

local function getMarker(zone: Instance, name: string): BasePart?
	local mechanics = zone:FindFirstChild("Mechanics")
	local folder = mechanics and mechanics:FindFirstChild(Zone15Traps.MARKER_FOLDER)
	local marker = folder and folder:FindFirstChild(name)
	return if marker and marker:IsA("BasePart") then marker else nil
end
Zone15Traps.GetMarker = getMarker

local function trapsFolder(zone: Instance): Folder
	local mechanics = zone:FindFirstChild("Mechanics") :: Instance
	local existing = mechanics:FindFirstChild("Traps")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Traps"
	folder.Parent = mechanics
	return folder
end

local function newCluster(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	-- Zone 15 nằm rất xa spawn: StreamingEnabled sẽ nạp lẻ từng part và client render
	-- thiếu mảnh. Atomic buộc cả cụm bẫy vào/ra bộ nhớ như một khối.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = parent
	return model
end

-- Neo CFrame gốc vào attribute: client dời part cục bộ nên vị trí hiện thời KHÔNG còn là gốc.
local function anchorHome(part: BasePart, home: CFrame, index: number)
	part.CFrame = home
	part:SetAttribute("HomeCF", home)
	part:SetAttribute("TrapIndex", index)
end
Zone15Traps.AnchorHome = anchorHome

local function buildSweep(zone: Instance, traps: Folder): string
	if traps:FindFirstChild(SW.ClusterName) then
		return "LaserSweep: đã có, bỏ qua"
	end
	local marker = getMarker(zone, SW.MarkerName)
	if not marker then
		return `LaserSweep: THIẾU marker {SW.MarkerName}`
	end

	local cluster = newCluster(traps, SW.ClusterName)
	local base = marker.CFrame * CFrame.new(0, SW.BeamYOffset, 0)
	for index, beam in SW.Beams do
		local part = Instance.new("Part")
		part.Name = `Beam{index}`
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false -- sát thương do service phân xử, không dùng Touched
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Color = SW.Color
		part.Transparency = 0.15
		part.Size = SW.BeamSize
		part.Parent = cluster
		anchorHome(part, base * CFrame.new(beam.Offset, 0, 0), index)
		if index == 1 then
			cluster.PrimaryPart = part
		end
	end
	return `LaserSweep: đã dựng {#SW.Beams} tia`
end

local function buildShuttle(zone: Instance, traps: Folder): string
	local existing = traps:FindFirstChild(SH.ClusterName)
	if existing and #existing:GetChildren() > 0 then
		return "ShiftBridge: đã có tấm sàn, bỏ qua"
	end
	local marker = getMarker(zone, SH.MarkerName)
	if not marker then
		return `ShiftBridge: THIẾU marker {SH.MarkerName}`
	end
	if existing then
		existing:Destroy()
	end

	local cluster = newCluster(traps, SH.ClusterName)
	local base = marker.CFrame * CFrame.new(0, SH.PadYOffset, 0)
	for index, pad in SH.Pads do
		local part = Instance.new("Part")
		part.Name = `Pad{index}`
		part.Anchored = true
		part.CanCollide = true -- người chơi ĐỨNG lên: client render local nên vẫn đỡ được
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Metal
		part.Color = SH.Color
		part.Size = SH.PadSize
		part.Parent = cluster
		anchorHome(part, base * CFrame.new(pad.Offset, 0, 0), index)
		if index == 1 then
			cluster.PrimaryPart = part
		end
	end
	return `ShiftBridge: đã dựng {#SH.Pads} tấm`
end

-- Bẫy 3 dùng model có sẵn trong map → chỉ cần neo HomeCF + chiều trượt của TỪNG LÀN.
-- SlideDir luôn ghi đè: đây là thứ quyết định làn nào mở sang bên nào, phải theo đúng config.
-- HomeCF chỉ ghi lần đầu, để người dựng map kéo lại cửa mà không bị reset về chỗ cũ... nhưng
-- nếu part đã bị dời thật thì HomeCF cũ sai → xoá attribute HomeCF là nó neo lại chỗ mới.
local function anchorSplitFloor(zone: Instance): string
	local ground = zone:FindFirstChild("Ground")
	if not ground then
		return "SplitFloor: thiếu Ground"
	end
	local count = 0
	for _, lane in F.Lanes do
		local model = ground:FindFirstChild(lane.Name)
		if model then
			for _, child in model:GetChildren() do
				if child:IsA("BasePart") then
					if child:GetAttribute("HomeCF") == nil then
						child:SetAttribute("HomeCF", child.CFrame)
					end
					child:SetAttribute("SlideDir", lane.Dir)
					count += 1
				end
			end
		end
	end
	return `SplitFloor: neo {count} part (2 làn trượt ngược chiều)`
end

-- Trả về log để gọi từ Studio Edit còn thấy được chuyện gì đã xảy ra.
function Zone15Traps.Build(zone: Instance): string
	local traps = trapsFolder(zone)
	return table.concat({
		buildSweep(zone, traps),
		buildShuttle(zone, traps),
		anchorSplitFloor(zone),
	}, "\n")
end

return Zone15Traps
