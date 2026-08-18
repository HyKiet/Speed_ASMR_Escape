--!strict
-- Biển tên khu vực trong Lobby (Treadmills / Multiplier Pads / Leaderboards /
-- Trails & Auras / Group Chest / Feedback).
--
-- Chữ lớn nổi trên không, viền đen dày, gradient theo màu chủ đạo của khu — cùng ngôn
-- ngữ với biển Stage ngoài Obby. Biển dựng RUNTIME (không nằm trong .rbxlx) để chỉnh vị
-- trí/chữ chỉ cần sửa bảng `SIGNS` bên dưới.
--
-- VỊ TRÍ: biển đứng SÁT PHÍA SAU khu (mép xa spawn nhất), nhô lên khỏi nóc công trình —
-- nhìn từ lối vào thấy chữ làm phông nền cho cả khu, không che mặt tiền.
--
-- Hai mặt: mỗi biển có SurfaceGui trên cả Front và Back nên nhìn từ hướng nào cũng đọc
-- được. Part nền trong suốt hoàn toàn, không va chạm, không đổ bóng.

local Workspace = game:GetService("Workspace")

-- Điểm quy chiếu MẶC ĐỊNH để xoay biển: SpawnLocation của Lobby.
local VIEWER_ANCHOR = Vector3.new(-4, 0, 0)

-- `facing`: hướng mặt Front của biển. Bỏ trống ⇒ quay về `VIEWER_ANCHOR`.
-- Khu nào có hướng nhìn RIÊNG (rương quay mặt về -X, cụm leaderboard xếp chéo) thì phải
-- chỉ định tay, nếu không biển sẽ lệch khỏi tâm khu khi người chơi đứng đúng mặt tiền.
-- `subText`: dòng phụ nhỏ NGAY DƯỚI chữ lớn (hiện chỉ biển Feedback dùng). Có subText thì
-- chữ chính co lại còn 58% chiều cao biển để nhường chỗ — nên biển nào dùng phải khai báo
-- `height` cao hơn bình thường, nếu không chữ chính teo đi trông như lỗi.
type SignConfig = {
	name: string,
	text: string,
	subText: string?,
	position: Vector3,
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
		-- Sau dàn treadmill (z ≈ -104.6), cao hơn nóc máy (y ≈ 24).
		position = Vector3.new(4.5, 34, -107),
		width = 48,
		height = 11,
		colorA = Color3.fromRGB(120, 240, 255),
		colorB = Color3.fromRGB(0, 132, 235),
	},
	{
		name = "MultiplierPadsSign",
		text = "Multiplier Pads",
		--[[
			ĐO LẠI 2026-08-14 (user: biển lệch khỏi tâm khu). Bản cũ ở z = -9 — đó là toạ độ
			của HÀNG PAD ĐẦU TIÊN (Pad_1/Pad_5 @ z ≈ -7), không phải tâm khu. Cả cụm trải dài
			z từ -58.2 tới 8.3, nên biển đứng lệch hẳn 16 stud về một đầu.

			Số đo thật của `Workspace.Lobby.MultiplierPads` (37 part):
			  bbox  min (-92.0, 10.0, -58.2)  →  max (-61.2, 19.9, 8.3)
			  tâm   (-76.6, 14.9, -25.0)      nóc y = 19.9
			⇒ z = -25 (đúng tâm), x = -95 (lùi ~18 stud ra sau tâm theo trục khu→spawn nên
			  không che mặt tiền), y = 29 (trên nóc pad tầng trên ~9 stud).

			⚠️ `facing` PHẢI KHAI BÁO TAY, và đây là lý do (mất một vòng mới ra):
			Để trống thì biển tự quay về `VIEWER_ANCHOR` (-4, 0, 0). Từ (-95, -25) hướng đó
			chéo ~15°, nên tấm biển rộng 52 stud bị XOAY và một đầu văng tới x = -101.9 — trong
			khi `Workspace.Wall.Wall_Lobby` là một mặt phẳng đứng ở x ≈ -96.6 (đo bằng raycast,
			đều suốt z từ -55 tới +5). Đầu đó chui hẳn ra SAU tường, và người chơi đọc được đúng
			"…iplier Pads": bốn chữ đầu bị chính bức tường nuốt mất.

			Hướng +X cho biển nằm SONG SONG với tường ở x = -95 (cách mặt tường 1.6 stud), nên
			cả 52 stud chiều ngang đều nằm trước tường. Nó cũng là hướng đúng về mặt thị giác:
			người chơi từ spawn đi tới nhìn theo -X, tức nhìn thẳng vào mặt biển.
		]]
		position = Vector3.new(-95, 29, -25),
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
		-- ĐO LẠI 2026-08-10 (user dời cụm bảng): tâm 3 DisplayPanel = trung bình của
		-- (-91.1, 35.2) / (-83.2, 62.6) / (-61.4, 81.0) ⇒ (-78.6, 59.6); nóc bảng y ≈ 30.7
		-- (tâm 21.36 + nửa chiều cao 18.77). Biển nhô ~10 stud RA TRƯỚC theo hướng mặt bảng
		-- để không bị chính bảng/tán cây phía sau nuốt chữ.
		position = Vector3.new(-70.3, 38, 54),
		-- Trung bình 3 LookVector: (1,0,0) + (0.842,0,-0.540) + (0.328,0,-0.945), chuẩn hoá.
		facing = Vector3.new(0.825, 0, -0.565),
		width = 44,
		height = 10,
		colorA = Color3.fromRGB(255, 238, 110),
		colorB = Color3.fromRGB(255, 158, 26),
	},
	{
		name = "CosmeticsSign",
		-- TrailBase (z -4..33) và AuraBase (z -51..-20) nằm chung một dải x 73..99 →
		-- một biển chung ở giữa, lùi ra sau cả hai.
		text = "Trails & Auras",
		position = Vector3.new(102, 29, -9),
		width = 52,
		height = 11,
		colorA = Color3.fromRGB(220, 160, 255),
		colorB = Color3.fromRGB(118, 46, 220),
	},
	{
		name = "GroupChestSign",
		text = "Group Chest",
		-- ⚠️ 2026-07-29: bản cũ tin vào `RegularChest.CFrame.LookVector` (-X) nên biển đứng
		-- ở CẠNH BÊN rương, người chơi không bao giờ thấy. MẶT RƯƠNG (nắp + ổ khoá vàng)
		-- thật ra quay về **-Z** — kiểm bằng screen_capture 4 hướng: chỉ hướng nhìn từ
		-- z≈46 về +Z mới thấy mặt trước, hai cây dừa ôm hai bên, biển xanh bên phải.
		-- Biển lùi 6 stud ra SAU rương (+Z), cao 33 (nóc rương ≈ 24.3) nên nổi trên nền
		-- đồi xanh + trời, đứng trước rương nhìn lên là chữ nằm chính giữa.
		position = Vector3.new(68, 33, 87.5),
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
		subText = "Not happy with something? Please don't dislike —\ntell us here and we'll fix it fast. Thank you!",
		-- ĐO LẠI 2026-08-10 (user dời hòm thư): `Workspace.Feedback.Mailbox` @(-65.0, 13.8,
		-- -70.4), nóc y ≈ 17.7. Biển lùi 6 stud RA SAU hòm thư theo trục hòm-thư→spawn
		-- (spawn ≈ (3.1, -12)) nên đứng đọc prompt vẫn thấy chữ nằm trên hòm thư.
		position = Vector3.new(-69.5, 26, -74.3),
		-- Cao hơn biển cũ vì có thêm dòng phụ 2 dòng.
		width = 44,
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

local function buildSign(config: SignConfig, parent: Instance): BasePart
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

	-- Front (mặt -Z của part) = LookVector; Back lo nốt hướng ngược lại.
	local facing = config.facing
	local target = if facing
		then config.position + Vector3.new(facing.X, 0, facing.Z).Unit * 10
		else Vector3.new(VIEWER_ANCHOR.X, config.position.Y, VIEWER_ANCHOR.Z)
	part.CFrame = CFrame.lookAt(config.position, Vector3.new(target.X, config.position.Y, target.Z))

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

	local root = create("Folder", { Name = "AreaSigns" }, lobby)
	for _, config in SIGNS do
		buildSign(config, root)
	end

	print(`[AreaSignService] Đã dựng {#SIGNS} biển khu vực.`)
end

return AreaSignService
