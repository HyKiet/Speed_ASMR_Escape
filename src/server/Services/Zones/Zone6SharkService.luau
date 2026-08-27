--!strict
--[[
	Zone6SharkService.luau — Server cho dàn cá mập breach Stage 6.

	THAY THẾ script inline `Workspace.Zones.Zone6.Mechanics.Zone6SharkScript` (2026-08-27).

	── VÌ SAO SERVER KHÔNG CÒN ANIMATE ─────────────────────────────────────────────────────
	Bản inline ghi `root.CFrame` mỗi Heartbeat cho 4 con cá. Part neo do script dời thì client
	KHÔNG nội suy — nó nhảy tới giá trị mới mỗi khi gói replicate tới, nên cú vọt (chuyển động
	nhanh nhất zone) đi theo nhịp MẠNG chứ không theo nhịp hình. Ở ping 350–400ms (đo
	2026-08-27) nó giật thành từng nấc, và stage đông người thì gói càng thưa.

	Trớ trêu: việc "chạm chết" đã tính Ở CLIENT từ lâu (`Zone6SharkController`) chính là để
	khớp với hình người chơi nhìn thấy — nhưng hình đó lại là hình ĐÃ TRỄ vì replicate. Cho
	client dựng luôn cả hình thì hai vế cùng đúng một lúc.

	Nhịp vốn đã là hàm THUẦN của thời gian (`(now + phase) % CYCLE`) nên client dựng lại được
	y hệt. Service này giờ chỉ: clone cá, neo mọi part, công bố tham số, rồi im lặng vĩnh viễn.
	KHÔNG có vòng lặp nào chạy sau khi dựng xong.

	── VÌ SAO LÀ SERVICE CHỨ KHÔNG PHẢI SCRIPT TRONG MAP ───────────────────────────────────
	Script inline nằm trong .rbxl nên không được Rojo sync và không có lịch sử git. Là
	ModuleScript dưới `src/server/Services` thì `init.server.luau` tự quét và nạp.
	Đổi lại phải tự tìm zone trong Workspace và chịu được việc map chưa nạp xong.

	Hợp đồng với client — attribute trên folder Sharks:
	    SharkArcTime / SharkDiveTime / SharkSpan / SharkParkY / SharkApexY / SharkBreachY
	    SharksReady : boolean — bật SAU CÙNG
	Trên từng model cá: Center (Vector3), Lat (Vector3), Phase (number), ParkCF (CFrame)
	Trên từng part cá:  HomeCF (CFrame bất biến — client dời part nên part.CFrame hết là gốc)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone6SharkService = {}

-- Giữ NGUYÊN mọi con số của bản inline: nhịp và độ khó của zone không đổi.
local SURFACE_Y = -22 -- mặt killblock (cá xuyên lên từ đây) — giữ để tài liệu hoá
local PARK_Y = -34 -- đỗ ẩn SÂU dưới killblock → player không thấy
local APEX_Y = 24 -- đỉnh cung
local SPAN = 14 -- nửa quãng ngang lướt qua lane
local ARC_TIME = 1.7 -- thời gian vọt (lên + xuống)
local DIVE_TIME = 1.5 -- thời gian ẩn dưới nước (cửa sổ an toàn cho player nhảy)
local BREACH_Y = 1 -- client chỉ tính chết khi cá cao hơn mức này
local CYCLE = ARC_TIME + DIVE_TIME

local RESOLVE_RETRY = 1

-- Mốc các đảo của Stage 6. Cá vọt qua KHE giữa hai đảo liên tiếp.
local ISLANDS = {
	Vector3.new(-5, 8, 1958),
	Vector3.new(-20, 8, 2065),
	Vector3.new(-124, 8, 2082),
	Vector3.new(-122, 8, 2201),
	Vector3.new(-20, 8, 2250),
}

type Gap = { center: Vector3, lat: Vector3 }

local function buildGaps(): { Gap }
	local gaps: { Gap } = {}
	for i = 1, #ISLANDS - 1 do
		local a, b = ISLANDS[i], ISLANDS[i + 1]
		local mid = (a + b) / 2
		local fwd = b - a
		fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
		-- Trục NGANG của khe: cá lướt dọc trục này khi vọt.
		local lat = Vector3.new(-fwd.Z, 0, fwd.X)
		table.insert(gaps, { center = Vector3.new(mid.X, 0, mid.Z), lat = lat })
	end
	return gaps
end

local function addTrail(root: BasePart)
	local tailZ = -root.Size.Z / 2
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, root.Size.Y * 0.35, tailZ)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBot"
	a1.Position = Vector3.new(0, -root.Size.Y * 0.35, tailZ)
	a1.Parent = root

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.5
	trail.MinLength = 0.05
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 200, 255)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.LightEmission = 0.65
	trail.Parent = root
end

local function resolve(): number?
	local zones = Workspace:FindFirstChild("Zones")
	local zone6 = zones and zones:FindFirstChild("Zone6")
	local mechanics = zone6 and zone6:FindFirstChild("Mechanics")
	local sharks = mechanics and mechanics:FindFirstChild("Sharks")
	local template = ServerStorage:FindFirstChild("SharkTemplate")
	if not sharks or not template or not template:IsA("Model") or not template.PrimaryPart then
		return nil
	end

	-- Dọn cá của lần dựng trước (Studio playtest lặp lại, hoặc service bị chạy hai lần).
	for _, old in sharks:GetChildren() do
		old:Destroy()
	end

	local gaps = buildGaps()
	for i, gap in gaps do
		local model = template:Clone()
		model.Name = "Shark_" .. i

		-- Đặt cá vào tư thế ĐỖ TRƯỚC khi ghi HomeCF: client dựng `rel` từ ParkCF nên hai cái
		-- bắt buộc phải chụp cùng một khoảnh khắc, nếu không cá lệch khỏi trục ngay frame đầu.
		local parkPos = gap.center + Vector3.new(0, PARK_Y, 0)
		local parkCF = CFrame.lookAt(parkPos, parkPos - gap.lat)
		model:PivotTo(parkCF)

		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				-- NEO HẾT (bản inline chỉ neo PrimaryPart): client dời TỪNG part một, part
				-- không neo sẽ bị solver vật lý kéo lại và cá rã ra.
				part.Anchored = true
				-- Sát thương tính bằng hình học ở client → part không cần va chạm/truy vấn.
				part.CanCollide = false
				part.CanTouch = false
				part:SetAttribute("HomeCF", part.CFrame)
			end
		end

		local root = model.PrimaryPart
		if root then
			addTrail(root)
		end

		model:SetAttribute("Center", gap.center)
		model:SetAttribute("Lat", gap.lat)
		-- Rải pha đều quanh chu kỳ để bốn con không cùng vọt một lúc.
		model:SetAttribute("Phase", (i - 1) * (CYCLE / #gaps))
		model:SetAttribute("ParkCF", parkCF)
		model.Parent = sharks
	end

	sharks:SetAttribute("SharkArcTime", ARC_TIME)
	sharks:SetAttribute("SharkDiveTime", DIVE_TIME)
	sharks:SetAttribute("SharkSpan", SPAN)
	sharks:SetAttribute("SharkParkY", PARK_Y)
	sharks:SetAttribute("SharkApexY", APEX_Y)
	sharks:SetAttribute("SharkBreachY", BREACH_Y)
	sharks:SetAttribute("SharkSurfaceY", SURFACE_Y)
	-- Bật SAU CÙNG: client thấy cờ là chắc chắn mọi cá + attribute đã có.
	sharks:SetAttribute("SharksReady", true)

	return #gaps
end

function Zone6SharkService.Init() end

function Zone6SharkService.Start()
	task.spawn(function()
		local n = resolve()
		while not n do
			task.wait(RESOLVE_RETRY)
			n = resolve()
		end
		Log.Boot(`[Zone6SharkService] {n} cá mập — client tự vẽ (0 replication)`)
	end)
end

return Zone6SharkService
