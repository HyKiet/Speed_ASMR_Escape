--!strict
--[[
	AreaSignService — biển tên khu vực trong Lobby (Treadmills / Multiplier Pads /
	Leaderboards / Trails & Auras / Group Chest / Feedback).

	Chữ lớn nổi trên không, viền đen dày, gradient theo màu chủ đạo của khu — cùng ngôn ngữ
	với biển Stage ngoài Obby. Biển dựng RUNTIME (không nằm trong .rbxl), hai mặt Front/Back
	nên nhìn từ hướng nào cũng đọc được. Part nền trong suốt, không va chạm, không đổ bóng.

	══ BIỂN BÁM THEO CỤM CÔNG TRÌNH, KHÔNG CÒN TOẠ ĐỘ CỨNG (2026-08-27) ═════════════════════

	Bản trước khai `position = Vector3(...)` cho từng biển. Cách đó hỏng theo đúng một kiểu,
	và nó đã hỏng thật: **ai đó dời cả Lobby ~95 studs trên trục Z**, sáu tấm biển ở nguyên
	chỗ cũ. Đo lúc phát hiện:

	    Treadmills      biển z = -107   ·  dàn máy giờ ở z = 1.5    → lệch ~108 studs
	    MultiplierPads  biển z = -25    ·  cụm pad giờ ở z = 70.1   → lệch ~95 studs
	    Trails & Auras  biển z = -9     ·  hai bệ giờ ở z = 85.7    → lệch ~95 studs

	(Cùng một lần dời đó cũng làm hỏng `OrbitCenter` của ba bệ Trail — xem
	`TrailShowcaseController`. Hai lỗi, một nguyên nhân: dữ liệu vị trí bị CHÉP ra khỏi map.)

	Giờ mỗi biển khai **cụm công trình của nó** thay vì toạ độ. Vị trí suy ra lúc chạy từ hộp
	bao thật của cụm:

	    tâm, nócY  =  hộp bao gộp của mọi BasePart trong `targets`
	    hướng      =  `facing` nếu có, không thì quay về SpawnLocation
	    vị trí     =  (tâm.X, nócY + clearance, tâm.Z)  −  hướng × setback

	Dời cụm trong Studio ⇒ biển tự đi theo, không phải sửa file này. Đó là toàn bộ mục đích.

	── HAI SỐ ĐO CỦA MỖI BIỂN ────────────────────────────────────────────────────────────────
	  `clearance` — nhô lên bao nhiêu stud TRÊN NÓC cụm (để chữ không bị chính công trình che).
	  `setback`   — lùi bao nhiêu stud RA SAU, tính ngược chiều `facing`. Số ÂM = nhô ra TRƯỚC
	                (cụm Leaderboard cần vậy: phía sau nó là tán cây, chữ bị nuốt).

	── ⚠️ VÌ SAO `facing` PHẢI KHAI TAY Ở BA CHỖ ────────────────────────────────────────────
	Mặc định biển quay về SpawnLocation. Ba ngoại lệ, mỗi cái một lý do đã phải trả giá:

	  • MultiplierPads → +X. Để mặc định thì biển quay chéo ~15° và một đầu của tấm rộng 52
	    stud văng ra SAU `Wall.Wall_Lobby` (đo lại 2026-08-27: tường ở x ≈ −96.2 suốt dải z
	    45→100). Người chơi đọc được đúng "…iplier Pads". Hướng +X đặt biển SONG SONG tường,
	    cách mặt tường 1.6 stud.
	  • GroupChest → −Z. Mặt rương (nắp + ổ khoá vàng) quay về −Z, không phải theo
	    `CFrame.LookVector` như bản 2026-07-29 đã tin nhầm và dựng biển ở cạnh bên rương.
	  • Leaderboards → trung bình 3 LookVector của các DisplayPanel (chúng xếp chéo nhau).
	    Phép quay không đổi khi tịnh tiến, nên vector này vẫn đúng sau khi cụm bị dời.

	Hai tường bên đã đo lại 2026-08-27: trái x ≈ −96.2, phải x ≈ +104.8, sau lưng treadmill
	z ≈ −25. Mọi biển dưới đây đều nằm trong khoảng đó.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Workspace = game:GetService("Workspace")

--[[
	Điểm quy chiếu để xoay biển. Đọc SpawnLocation THẬT lúc chạy chứ không hằng số hoá:
	hằng số là đúng cái đã làm hỏng cả sáu biển lần trước.

	Fallback chỉ dùng khi không tìm thấy spawn — xem `lobby-spawn-path`: spawn nằm ở
	`Workspace.Spawn`, NGOÀI Lobby.
]]
local FALLBACK_VIEWER = Vector3.new(3, 0, 94)

type SignConfig = {
	name: string,
	text: string,
	subText: string?,
	-- Đường dẫn (từ Workspace) tới cụm công trình. Nhiều đường ⇒ hộp bao GỘP lại.
	targets: { { string } },
	clearance: number,
	setback: number,
	width: number,
	height: number,
	colorA: Color3,
	colorB: Color3,
	facing: Vector3?,
}

local SIGNS: { SignConfig } = {
	{
		name = "TreadmillsSign",
		text = "Treadmills",
		targets = { { "Lobby", "Treadmills" } },
		clearance = 10,
		setback = 14,
		width = 48,
		height = 11,
		colorA = Color3.fromRGB(120, 240, 255),
		colorB = Color3.fromRGB(0, 132, 235),
	},
	{
		name = "MultiplierPadsSign",
		text = "Multiplier Pads",
		targets = { { "Lobby", "MultiplierPads" } },
		clearance = 9,
		-- 18 stud sau tâm cụm ⇒ x ≈ −94.6, cách tường (x ≈ −96.2) 1.6 stud. Xem khối ⚠️ ở đầu file.
		setback = 18,
		facing = Vector3.new(1, 0, 0),
		width = 52,
		height = 11,
		-- Hồng cánh sen: nền sau biển này là vách cỏ XANH, chữ xanh lá bị chìm hẳn.
		colorA = Color3.fromRGB(255, 160, 240),
		colorB = Color3.fromRGB(214, 40, 180),
	},
	{
		name = "LeaderboardsSign",
		text = "Leaderboards",
		targets = { { "Lobby", "LeaderBoard" } },
		clearance = 4,
		-- ÂM = nhô RA TRƯỚC mặt bảng: phía sau cụm là tán cây, để biển lùi ra sau là mất chữ.
		setback = -8,
		-- Trung bình 3 LookVector của Top_Speeds / Top_Donate / Top_Wins (chúng xếp chéo).
		facing = Vector3.new(0.825, 0, -0.565),
		width = 44,
		height = 10,
		colorA = Color3.fromRGB(255, 238, 110),
		colorB = Color3.fromRGB(255, 158, 26),
	},
	{
		name = "CosmeticsSign",
		text = "Trails & Auras",
		-- Hai bệ nằm chung một dải x nhưng cách nhau ~50 stud trên z ⇒ gộp hộp bao để biển
		-- đứng đúng giữa cả hai, thay vì bám một bệ và bỏ rơi bệ kia.
		targets = { { "Lobby", "TrailBase" }, { "Lobby", "AuraBase" } },
		clearance = 9,
		-- 16 stud ⇒ x ≈ 101.7, cách tường phải (x ≈ 104.8) 3.1 stud.
		setback = 16,
		width = 52,
		height = 11,
		colorA = Color3.fromRGB(220, 160, 255),
		colorB = Color3.fromRGB(118, 46, 220),
	},
	{
		name = "GroupChestSign",
		text = "Group Chest",
		targets = { { "Lobby", "GroupChest" } },
		clearance = 9,
		setback = 8,
		facing = Vector3.new(0, 0, -1),
		width = 44,
		height = 11,
		colorA = Color3.fromRGB(255, 138, 120),
		colorB = Color3.fromRGB(214, 26, 44),
	},
	{
		name = "FeedbackSign",
		text = "Feedback",
		-- Dòng phụ: mục đích là CHẶN dislike bốc đồng — nói thẳng "báo cho tụi mình" trước
		-- khi người chơi kịp bấm nút không thích trên trang game.
		subText = "Tell us here instead of disliking. Thanks!",
		targets = { { "Lobby", "Feedback" } },
		clearance = 8,
		setback = 6,
		width = 44,
		-- Cao hơn biển thường vì có thêm dòng phụ 2 dòng.
		height = 13,
		colorA = Color3.fromRGB(150, 255, 210),
		colorB = Color3.fromRGB(20, 175, 130),
	},
}

local PIXELS_PER_STUD = 24

local AreaSignService = {}

local function create(className: string, properties: { [string]: any }?, parent: Instance?): Instance
	local instance = Instance.new(className)
	if properties then
		for key, value in properties do
			(instance :: any)[key] = value
		end
	end
	instance.Parent = parent
	return instance
end

-- Một mặt biển: nhãn chữ TextScaled + viền đen + gradient dọc.
-- BẪY (đã dính ở biển Stage 15): đặt `TextWrapped = false` sẽ TẮT luôn TextScaled, chữ
-- teo lại cỡ mặc định. Cỡ chữ chốt bằng UITextSizeConstraint.MaxTextSize.
local function buildFace(part: BasePart, config: SignConfig, face: Enum.NormalId)
	local gui = create("SurfaceGui", {
		Name = "Face_" .. face.Name,
		Face = face,
		LightInfluence = 0,
		MaxDistance = 700,
		PixelsPerStud = PIXELS_PER_STUD,
		ResetOnSpawn = false,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		ZOffset = 0,
	}, part) :: SurfaceGui

	local hasSub = config.subText ~= nil

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromScale(0, 0),
		Size = if hasSub then UDim2.fromScale(1, 0.58) else UDim2.fromScale(1, 1),
		Text = config.text,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
	}, gui) :: TextLabel

	create("UITextSizeConstraint", {
		MaxTextSize = 200,
		MinTextSize = 24,
	}, label)

	if config.subText then
		-- Dòng phụ để TRẮNG NGÀ đặc (không gradient): gradient dọc trên chữ nhỏ làm nửa dưới
		-- tối lại và mất nét ở khoảng cách xa.
		local sub = create("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromScale(0.03, 0.58),
			Size = UDim2.fromScale(0.94, 0.38),
			Text = config.subText,
			TextColor3 = Color3.fromRGB(255, 252, 226),
			TextScaled = true,
			-- TextWrapped PHẢI để true: đặt false sẽ tắt luôn TextScaled (bẫy biển Stage 15).
			TextWrapped = true,
		}, gui) :: TextLabel

		create("UITextSizeConstraint", {
			MaxTextSize = 46,
			MinTextSize = 12,
		}, sub)

		create("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = Color3.fromRGB(18, 18, 30),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = 4,
		}, sub)
	end

	-- Gradient tô thân chữ (ApplyStrokeMode của UIStroke độc lập nên viền vẫn đen tuyền).
	create("UIGradient", {
		Color = ColorSequence.new(config.colorA, config.colorB),
		Rotation = 90,
	}, label)

	create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.fromRGB(18, 18, 30),
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = 7,
	}, label)
end


--[[
	Hộp bao GỘP của mọi BasePart trong các đường dẫn của một biển.

	Dùng hộp bao trục-thế-giới (không tính xoay của từng part) là CỐ Ý: ta chỉ cần tâm X/Z và
	độ cao nóc để đặt biển, còn hộp bao xoay-chuẩn của một cụm 147 part vừa đắt vừa không cho
	kết quả tốt hơn cho mục đích này.

	Trả về nil nếu không tìm thấy đường dẫn nào — gọi phía trên sẽ bỏ qua biển đó và warn to.
]]
local function measure(config: SignConfig): (Vector3?, number)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	local count = 0

	local function eat(part: BasePart)
		count += 1
		local half = part.Size / 2
		min = min:Min(part.Position - half)
		max = max:Max(part.Position + half)
	end

	for _, path in config.targets do
		local node: Instance? = Workspace
		for _, segment in path do
			node = node and node:FindFirstChild(segment)
		end
		if not node then
			warn(`[AreaSignService] {config.name}: không thấy Workspace.{table.concat(path, ".")}`)
			continue
		end
		if node:IsA("BasePart") then
			eat(node)
		end
		for _, d in node:GetDescendants() do
			if d:IsA("BasePart") then
				eat(d)
			end
		end
	end

	if count == 0 then
		return nil, 0
	end
	return (min + max) / 2, max.Y
end

local function viewerAnchor(): Vector3
	local spawn = Workspace:FindFirstChild("Spawn")
	if spawn then
		if spawn:IsA("BasePart") then
			return spawn.Position
		elseif spawn:IsA("Model") then
			return spawn:GetPivot().Position
		end
	end
	warn("[AreaSignService] Không thấy Workspace.Spawn — biển xoay theo toạ độ dự phòng.")
	return FALLBACK_VIEWER
end

-- Trả về nil nếu cụm công trình không tồn tại (đã warn trong `measure`).
local function buildSign(config: SignConfig, parent: Instance, viewer: Vector3): BasePart?
	local center, roofY = measure(config)
	if not center then
		return nil
	end

	--[[
		Hướng mặt Front. Mặc định quay về spawn; `facing` ghi đè (ba chỗ, lý do ở đầu file).

		`.Unit` trên vector phẳng XZ chứ không phải vector 3D: lấy cả thành phần Y vào sẽ làm
		tấm biển NGHIÊNG theo độ cao chênh lệch giữa nó và spawn.
	]]
	local raw = config.facing or (viewer - center)
	local flat = Vector3.new(raw.X, 0, raw.Z)
	local facing = if flat.Magnitude > 1e-4 then flat.Unit else Vector3.new(0, 0, 1)

	-- Lùi RA SAU = ngược chiều nhìn. setback âm ⇒ nhô ra trước (cụm Leaderboard).
	local position = Vector3.new(center.X, roofY + config.clearance, center.Z) - facing * config.setback

	local part = create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Locked = true,
		Material = Enum.Material.SmoothPlastic,
		Name = config.name,
		Size = Vector3.new(config.width, config.height, 0.2),
		Transparency = 1,
	}, parent) :: BasePart

	-- Front = mặt -Z của part = LookVector; Back lo nốt hướng ngược lại.
	part.CFrame = CFrame.lookAt(position, position + facing)

	buildFace(part, config, Enum.NormalId.Front)
	buildFace(part, config, Enum.NormalId.Back)

	return part
end

function AreaSignService.Start()
	local lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then
		warn("[AreaSignService] Không tìm thấy Workspace.Lobby — bỏ qua biển khu vực.")
		return
	end

	-- Dựng lại từ đầu mỗi lần chạy: tránh nhân đôi khi Rojo sync/hot-reload.
	local existing = lobby:FindFirstChild("AreaSigns")
	if existing then
		existing:Destroy()
	end

	local viewer = viewerAnchor()
	local root = create("Folder", { Name = "AreaSigns" }, lobby)
	local built = 0
	for _, config in SIGNS do
		local sign = buildSign(config, root, viewer)
		if sign then
			built += 1
			--[[
				In TOẠ ĐỘ ĐÃ SUY RA, không phải chỉ đếm số biển.

				Đây là dòng log duy nhất phát hiện được chuyện "cụm bị dời, biển đi theo nhưng
				tới chỗ vô lý" (ví dụ ai đó bỏ quên một part ở xa trong Folder làm hộp bao phình
				ra). Đếm suông thì lần lệch 95 stud vừa rồi vẫn sẽ in ra "đã dựng 6 biển".
			]]
			Log.Boot(
				("[AreaSignService] %-20s @ (%.1f, %.1f, %.1f)"):format(
					config.name,
					sign.Position.X,
					sign.Position.Y,
					sign.Position.Z
				)
			)
		end
	end

	Log.Boot(`[AreaSignService] Đã dựng {built}/{#SIGNS} biển khu vực (bám theo cụm công trình).`)
end

return AreaSignService
