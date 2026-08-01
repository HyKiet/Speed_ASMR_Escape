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
-- BẪY 2 — SHIFT BRIDGE: 2 tấm sàn lấp khe đã cắt sẵn trên đường chạy, trượt NGANG ra
-- khỏi lối đi theo nhịp. Tấm rời chỗ mà người chơi vẫn chạy tới = rơi xuống biển.
--=====================================================================================
Zone15Traps.Shuttle = {
	MarkerName = "Trap2",
	ClusterName = "ShiftBridge",

	-- Tấm sàn do người dựng map tự làm (Model nhiều part, đúng style sàn gốc) rồi đặt vào
	-- cụm ShiftBridge. Offset/PadSize bên dưới CHỈ dùng khi cụm còn rỗng và cần dựng bù.
	PadSize = Vector3.new(50, 4, 54), -- X dọc hướng chạy, Z ngang hành lang
	PadYOffset = -2, -- mặt tấm ngang mặt sàn (marker đặt ngang mặt sàn)

	-- Dir = chiều trượt ngang (±); Phase tính bằng GIÂY. Tấm gặp sau lệch pha đúng thời gian
	-- chạy từ tấm trước sang (47.7 studs ÷ 234) → giữ tốc độ là qua được cả hai.
	Pads = {
		{ Offset = -24, Dir = 1, Phase = 0 },
		{ Offset = 24, Dir = -1, Phase = 47.7 / 234 },
	},
	Amplitude = 60, -- tấm rộng 72, hành lang rộng 48 → trượt 60 là rời hẳn lối đi

	Cycle = 4.2,
	-- Mốc tỉ lệ: nằm yên tại chỗ (an toàn 1.43s) → trượt ra → nằm ngoài → trượt về
	InEnd = 0.34,
	OutEnd = 0.48,
	AwayEnd = 0.86,

	Color = Color3.fromRGB(96, 214, 255),
	ColorWarn = Color3.fromRGB(255, 138, 64),
}

local SH = Zone15Traps.Shuttle

-- 0 = nằm đúng chỗ (đi được), 1 = trượt ra hết (khe hở).
function Zone15Traps.ShuttleAlpha(now: number, index: number): number
	local p = ((now - SH.Pads[index].Phase) % SH.Cycle) / SH.Cycle
	if p < SH.InEnd then
		return 0
	elseif p < SH.OutEnd then
		return smooth((p - SH.InEnd) / (SH.OutEnd - SH.InEnd))
	elseif p < SH.AwayEnd then
		return 1
	end
	return 1 - smooth((p - SH.AwayEnd) / (1 - SH.AwayEnd))
end

-- Độ dời NGANG của tấm thứ i (studs, theo trục bề ngang hành lang).
function Zone15Traps.ShuttleOffset(now: number, index: number): number
	return SH.Pads[index].Dir * SH.Amplitude * Zone15Traps.ShuttleAlpha(now, index)
end

--=====================================================================================
-- BẪY 3 — SPLIT FLOOR: cầu cuối chặng gồm 2 LÀN song song (model có sẵn trong map).
-- Cả làn trượt NGANG ra khỏi đường như một khối, hai làn về hai phía ngược nhau:
--   Obby_Open1 (Z 3481, phía trái theo hướng chạy +X) → trượt -Z
--   Obby_Open2 (Z 3517, phía phải)                    → trượt +Z
-- Hai làn mở CÙNG LÚC → mất sạch mặt cầu 170 studs trong ~1.7s. Có 0.7s nhấp nháy báo trước.
--=====================================================================================
Zone15Traps.SplitFloor = {
	-- Dir = chiều trượt theo trục Z cục bộ của từng làn.
	Lanes = {
		{ Name = "Obby_Open1", Dir = -1 },
		{ Name = "Obby_Open2", Dir = 1 },
	},
	Slide = 40, -- làn rộng 36 → trượt 40 là rời hẳn khỏi đường chạy

	Cycle = 5.0,
	-- Mốc tính bằng GIÂY trong chu kỳ
	WarnStart = 2.6,
	OpenStart = 3.3,
	OpenFull = 3.65,
	CloseStart = 4.65,

	ColorWarn = Color3.fromRGB(255, 92, 48),
}

local F = Zone15Traps.SplitFloor

-- 0 = khép kín, 1 = mở hết.
function Zone15Traps.SplitAlpha(now: number): number
	local t = now % F.Cycle
	if t < F.OpenStart then
		return 0
	elseif t < F.OpenFull then
		return smooth((t - F.OpenStart) / (F.OpenFull - F.OpenStart))
	elseif t < F.CloseStart then
		return 1
	end
	return 1 - smooth((t - F.CloseStart) / (F.Cycle - F.CloseStart))
end

-- 0..1 cường độ cảnh báo (chỉ dùng cho màu, không ảnh hưởng va chạm).
function Zone15Traps.SplitWarn(now: number): number
	local t = now % F.Cycle
	if t < F.WarnStart or t >= F.OpenStart then
		return 0
	end
	return (t - F.WarnStart) / (F.OpenStart - F.WarnStart)
end

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
