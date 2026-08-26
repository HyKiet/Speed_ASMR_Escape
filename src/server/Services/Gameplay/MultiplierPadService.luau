--!strict
--[[
	Khi player đặt chân lên PadPart trong Workspace.MultiplierPads.Pad_{N} (nhận diện bằng
	quét hình học mỗi frame — xem khối `ENTER_MARGIN_STUDS` bên dưới, KHÔNG dùng `Touched`):
	  - Nếu TotalWins >= requiredWins: set ActivePadId attribute (client tô màu vàng/xanh)
	  - Nếu chưa đủ: gửi toast "Need X Wins"
	Pad mặc định khi player join = pad CAO NHẤT mà số Wins hiện tại với tới (2026-08-22).
	Nhưng mặc định KHÔNG PHẢI là ép buộc: người chơi tự chọn lại pad nào cũng được trong số
	pad đã mở — lên pad cao hơn thì ăn ngay khi chạm, xuống pad thấp hơn thì phải ĐỨNG YÊN
	trên đó ~1.2 giây (xem `DOWNGRADE_DWELL_SECONDS`) để không bị đổi nhầm lúc chạy ngang qua.

	── MỞ KHOÁ LÀ TRẠNG THÁI, KHÔNG PHẢI CỘT MỐC (chốt 2026-08-10, user) ─────────────────
	Trước đây `HighestPadIndex` là cột mốc VĨNH VIỄN: đạt 15 Wins một lần là giữ Pad 3 mãi
	mãi. Mà Wins TIÊU ĐƯỢC (teleport, pad tính phí ở ProgressionService) nên người chơi có
	thể đứng trên pad +5/step với 0 Wins trong túi — hưởng sức mạnh mình không còn nuôi nổi.

	Giờ quyền dùng pad được tính LẠI theo số Wins HIỆN TẠI:
	  - `eligibleIndex(data)` = pad cao nhất mà Wins hiện tại với tới.
	  - Wins tụt xuống dưới ngưỡng ⇒ `enforcePad` tự HẠ người chơi về đúng pad họ còn đủ,
	    kèm toast giải thích (im lặng hạ cấp thì họ chỉ thấy "sao tự nhiên farm chậm đi").
	  - `data.HighestPadIndex` giữ nguyên tên (client đọc để tô màu) nhưng đổi vai: từ cột
	    mốc đã lưu thành BẢN SAO của mức đang đủ điều kiện.

	Ngưỡng `requiredWins` tăng dần đều theo pad nên không cần luật "mua tuần tự" nữa: đủ Wins
	cho pad N thì đương nhiên đủ cho mọi pad dưới N.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

type PadConfig = Constants.MultiplierPadConfig

local ENFORCE_INTERVAL_SECONDS = 1
local PADS_FOLDER_NAME = "MultiplierPads"
local PAD_PART_NAME = "PadPart"

--[[
	NHẬN DIỆN BẰNG QUÉT MỖI FRAME, KHÔNG DÙNG `Touched` NỮA (2026-08-26, user: "nhận diện
	player quá chậm, phải gần như tức thì").

	`Touched` chậm vì ba lẽ, cộng dồn lại thành cảm giác "dậm mãi không ăn":
	  1. Nó là sự kiện VẬT LÝ, chỉ bắn khi engine giải xong va chạm và replicate về server —
	     độ trễ tự nhiên đã vài chục ms, và PadPart chỉ dày 0.4 stud nên nhiều frame nhân vật
	     "trượt" qua mà không sinh cặp va chạm nào.
	  2. Bản cũ còn khoá thêm `TOUCH_COOLDOWN_SECONDS = 0.4` DÙNG CHUNG cho mọi pad: đi từ
	     Pad_1 sang Pad_2 trong vòng 0.4 giây là cú chạm thứ hai bị nuốt sạch, người chơi phải
	     bước ra rồi bước lại.
	  3. Đứng YÊN thì `Touched` không bắn thêm lần nào — pad bỏ lỡ cú chạm đầu là im luôn.

	Giờ mỗi frame `Heartbeat` quét vị trí HumanoidRootPart của những người đang ở trong khu
	pad, so với hình hộp của từng PadPart ⇒ độ trễ = 1 frame (~16ms) thay vì 0.4-0.5 giây, và
	không còn phụ thuộc vào việc engine có sinh ra sự kiện va chạm hay không.

	RẺ: chỉ những người nằm trong bán kính cụm pad mới được xét (`clusterRadius`), mỗi lượt là
	vài phép đổi hệ toạ độ trên 8 pad.
]]
local ENTER_MARGIN_STUDS = 1.5
-- Rời pad phải nới rộng hơn lúc vào (trễ nãi): nhân vật đứng yên vẫn rung vài phần mười
-- stud, không có khoảng đệm này thì hàng đợi "đứng lại = chọn" bị huỷ giữa chừng.
local EXIT_MARGIN_STUDS = 3
local PAD_HEIGHT_STUDS = 9
-- Bán kính cụm pad được nới thêm chừng này để người đang lao tới vẫn được xét từ trước.
local CLUSTER_PADDING_STUDS = 60
--[[
	QUÉT PHẢI LÀ SWEPT, KHÔNG PHẢI ĐIỂM RỜI RẠC.

	Ở 250 WalkSpeed nhân vật đi 4 stud mỗi frame 60fps (8+ stud nếu server tụt 30fps), trong
	khi pad chỉ rộng 5.5 stud — kiểm mỗi vị trí hiện tại là có frame nhảy thẳng qua pad mà
	không lần nào rơi vào trong. Nên mỗi frame kiểm cả ĐOẠN từ vị trí frame trước tới vị trí
	hiện tại, lấy mẫu cách nhau `SWEEP_STEP_STUDS`. (Cùng bài học với bẫy zone: xem
	`TrapSweep`.)
]]
local SWEEP_STEP_STUDS = 1.5
local SWEEP_MAX_SAMPLES = 16

local DOWNGRADE_DWELL_SECONDS = 1.2

type PadEntry = {
	config: PadConfig,
	padPart: BasePart,
	index: number,
	-- Hình học cache lại (xem `refreshPadGeometry`).
	cframe: CFrame,
	position: Vector3,
	halfX: number,
	halfZ: number,
}

type PendingSelect = {
	entry: PadEntry,
	since: number,
}

local HINT_COOLDOWN_SECONDS = 20

local padEntries: { PadEntry } = {}
local clusterCenter: Vector3? = nil
local clusterRadius = 0
-- Khai báo trước: `connectPad` móc vào tín hiệu đổi vị trí pad và gọi ngược lên hàm này.
local recomputeCluster: () -> ()

local lastHintTime: { [Player]: number } = {}
local pendingSelect: { [Player]: PendingSelect } = {}
-- Pad người chơi đang đứng ở frame trước: chỉ xử lý lúc ĐỔI (vào pad mới), không phải mỗi frame.
local occupiedPadId: { [Player]: string } = {}
local lastRootPosition: { [Player]: Vector3 } = {}
local DataService
local ProgressionService
local TutorialService

local MultiplierPadService = {}

-- pad_3 -> 3. Trả về index trong bảng config (cũng là số thứ tự pad).
local function padIndexFromId(id: string): number
	local n = id:match("^pad_(%d+)$")
	return n and tonumber(n) or 1
end

-- Pad cao nhất mà số Wins HIỆN TẠI với tới. Ngưỡng tăng dần nên gặp pad đầu tiên không đủ
-- là dừng được luôn.
local function eligibleIndex(data: any): number
	local wins = tonumber(data.TotalWins) or 0
	local best = 1
	for index, config in Constants.MULTIPLIER_PADS do
		if wins >= config.requiredWins then
			best = index
		else
			break
		end
	end
	return best
end

-- Đồng bộ attribute HighestPadIndex (client đọc để tô màu vàng/xanh/xám).
local function publishHighestPad(player: Player, data: any, eligible: number)
	data.HighestPadIndex = eligible
	if player:GetAttribute("HighestPadIndex") ~= eligible then
		player:SetAttribute("HighestPadIndex", eligible)
	end
end

local function applyPad(player: Player, config: PadConfig)
	player:SetAttribute("ActivePadId", config.id)
	ProgressionService.SetActivePad(player, config.id, config.speedPerStep)
end

local function activeIndex(player: Player): number
	local current = player:GetAttribute("ActivePadId")
	if typeof(current) == "string" then
		return padIndexFromId(current)
	end
	return 0 -- chưa có pad nào ⇒ luôn cần áp pad mặc định
end

--[[
	Bắt trạng thái pad khớp với số Wins hiện tại. Gọi được liên tục: chỉ ĐỘNG VÀO khi người
	chơi đang đứng ở pad cao hơn mức họ còn đủ Wins.
]]
local function enforcePad(player: Player, announce: boolean)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	local eligible = eligibleIndex(data)
	publishHighestPad(player, data, eligible)

	local current = activeIndex(player)

	--[[
		Chưa chọn pad nào (vừa vào game) → phát THẲNG pad cao nhất đang đủ Wins.

		⚠️ Đảo luật 2026-08-22 (user). Trước đây chỗ này áp cứng pad_1 với lý do "người chơi
		phải tự đi tới pad mà đứng lên mới là nghi thức của khu Multiplier Pads". Nghi thức đó
		chỉ đúng LẦN ĐẦU: `ActivePadId` là attribute (không nằm trong ProfileStore) nên thoát
		game vào lại là mất sạch, và người chơi 200k Wins bị ném về +1/step mà không có một
		dòng nào báo — họ tưởng game hỏng hoặc mất tiến trình.

		Đây KHÔNG phải "tặng": `eligible` được tính lại từ Wins HIỆN TẠI mỗi lần gọi, đúng cái
		mức mà chính họ đi lên pad kia cũng sẽ nhận được. Wins tụt là vòng canh bên dưới vẫn hạ
		xuống như cũ. Người chơi mới có 0 Wins ⇒ eligible = 1 ⇒ vẫn là pad_1, tutorial bước 2
		("đi tới Pad 2") không đổi một chút nào.
	]]
	if current == 0 then
		applyPad(player, Constants.MULTIPLIER_PADS[eligible])
		ProgressionService.SendSnapshot(player)
		return
	end

	if current <= eligible then
		return
	end

	local config = Constants.MULTIPLIER_PADS[eligible]
	applyPad(player, config)

	if announce then
		GamePackets.toast.sendTo({
			kind = "pad",
			message = `Not enough Wins — Pad +{config.speedPerStep}/step active`,
			amount = 0,
		}, player)
	end
	ProgressionService.SendSnapshot(player)
end

local function ensureDefaultPad(player: Player)
	local current = player:GetAttribute("ActivePadId")
	if typeof(current) == "string" then
		local config = Constants.GetMultiplierPadById(current)
		if config then
			ProgressionService.SetActivePad(player, config.id, config.speedPerStep)
		end
	end
	-- Không báo toast lúc vào game: người chơi chưa làm gì để mà bị "hạ cấp" trước mắt họ.
	enforcePad(player, false)
end

--[[
	Hình học pad được CACHE (pad là part neo cứng, cả đời không nhúc nhích).

	Lý do: đọc `.CFrame` / `.Size` / `.Position` là qua ranh giới Luau↔C++, và trong vòng quét
	mỗi frame đó mới là phần đắt nhất — đắt hơn cả phép toán vector. Đo trong Studio: cache
	xong, một lượt quét cho người đang đứng giữa khu pad rẻ đi khoảng 3 lần.

	Ai đổi vị trí/kích thước pad lúc runtime thì `refreshPadGeometry` được gọi lại qua
	`GetPropertyChangedSignal` — không có nó thì pad dời đi mà vùng nhận diện đứng yên tại chỗ
	cũ, đúng kiểu lỗi im lặng khó lần nhất.
]]
local function refreshPadGeometry(entry: PadEntry)
	local padPart = entry.padPart
	local size = padPart.Size
	entry.cframe = padPart.CFrame
	entry.position = padPart.Position
	entry.halfX = size.X / 2
	entry.halfZ = size.Z / 2
end

-- Một ĐIỂM có nằm trên mặt pad không (hệ quy chiếu của chính pad, nên pad xoay kiểu gì cũng
-- đúng).
local function isPointOnPad(entry: PadEntry, position: Vector3, margin: number): boolean
	local offset = entry.cframe:PointToObjectSpace(position)
	return math.abs(offset.X) <= entry.halfX + margin
		and math.abs(offset.Z) <= entry.halfZ + margin
		and offset.Y > -PAD_HEIGHT_STUDS
		and offset.Y < PAD_HEIGHT_STUDS
end

--[[
	Khoảng cách từ TÂM PAD tới đoạn đường đi. Đây là bộ lọc rẻ tiền chạy TRƯỚC phép lấy mẫu:
	pad nào xa hơn bán kính bao của nó thì loại ngay bằng vài phép toán, khỏi phải lấy mẫu
	dọc đoạn. Với bố cục 8 pad thì mỗi frame chỉ còn đúng 1 pad phải lấy mẫu thật.
]]
local function distanceToSegment(point: Vector3, from: Vector3, to: Vector3): number
	local delta = to - from
	local lengthSquared = delta:Dot(delta)
	if lengthSquared <= 1e-6 then
		return (point - from).Magnitude
	end
	local t = math.clamp((point - from):Dot(delta) / lengthSquared, 0, 1)
	return (point - (from + delta * t)).Magnitude
end

-- Cả ĐOẠN ĐƯỜNG đi trong frame vừa rồi có quét qua pad không (xem `SWEEP_STEP_STUDS`).
local function segmentHitsPad(entry: PadEntry, from: Vector3, to: Vector3, margin: number): boolean
	-- Bán kính bao của pad (nửa đường chéo hộp) + mép nới: lọc rẻ trước khi lấy mẫu.
	local reachX = entry.halfX + margin
	local reachZ = entry.halfZ + margin
	local reach = math.sqrt(reachX * reachX + reachZ * reachZ + PAD_HEIGHT_STUDS * PAD_HEIGHT_STUDS)
	if distanceToSegment(entry.position, from, to) > reach then
		return false
	end

	if isPointOnPad(entry, to, margin) then
		return true
	end

	local delta = to - from
	local distance = delta.Magnitude
	if distance <= SWEEP_STEP_STUDS then
		return false
	end

	local samples = math.min(math.ceil(distance / SWEEP_STEP_STUDS), SWEEP_MAX_SAMPLES)
	for i = 1, samples - 1 do
		if isPointOnPad(entry, from + delta * (i / samples), margin) then
			return true
		end
	end
	return false
end

-- Người chơi có còn ĐỨNG TRÊN pad này không (dùng cho hàng đợi "đứng lại = chọn").
local function isStandingOnPad(player: Player, entry: PadEntry): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return isPointOnPad(entry, root.Position, EXIT_MARGIN_STUDS)
end

-- Pad mà người chơi vừa đặt chân lên trong frame này. Trùng nhiều pad (không xảy ra với bố
-- cục hiện tại, pad cách nhau 12 stud) thì lấy pad có tâm gần nhất.
local function findPadAt(from: Vector3, to: Vector3): PadEntry?
	local best: PadEntry? = nil
	local bestDistance = math.huge
	for _, entry in padEntries do
		if entry.padPart.Parent and segmentHitsPad(entry, from, to, ENTER_MARGIN_STUDS) then
			local distance = (entry.padPart.Position - to).Magnitude
			if distance < bestDistance then
				best = entry
				bestDistance = distance
			end
		end
	end
	return best
end

-- Vòng đếm giờ cho pad THẤP hơn: đủ `DOWNGRADE_DWELL_SECONDS` đứng yên thì đổi thật.
local function tickPendingSelect(player: Player)
	local pending = pendingSelect[player]
	if not pending then
		return
	end

	if not isStandingOnPad(player, pending.entry) then
		pendingSelect[player] = nil
		return
	end

	if os.clock() - pending.since < DOWNGRADE_DWELL_SECONDS then
		return
	end

	pendingSelect[player] = nil

	-- Wins có thể đã tụt trong lúc đứng ⇒ kiểm lại quyền dùng pad trước khi áp.
	local data = DataService.GetData(player)
	if not data or pending.entry.index > eligibleIndex(data) then
		return
	end

	applyPad(player, pending.entry.config)
	GamePackets.toast.sendTo({
		kind = "pad",
		message = `Active Pad: +{pending.entry.config.speedPerStep}/step`,
		amount = 0,
	}, player)
	ProgressionService.SendSnapshot(player)
end

--[[
	Người chơi vừa ĐẶT CHÂN LÊN một pad (biên "ngoài pad → trong pad" do `scanPlayers` bắt).
	Không còn cooldown nào cả: đi từ Pad_1 sang Pad_2 trong nửa giây vẫn ăn cả hai.
]]
local function onPadEntered(player: Player, entry: PadEntry)
	local config = entry.config

	-- Đã chọn pad này rồi → bỏ qua
	if player:GetAttribute("ActivePadId") == config.id then
		return
	end

	local data = DataService.GetData(player)
	if not data then
		return
	end

	local now = os.clock()
	local padIndex = entry.index
	local eligible = eligibleIndex(data)
	publishHighestPad(player, data, eligible)

	--[[
		ĐI QUA PAD THẤP HƠN KHÔNG PHẢI LÀ CHỌN NÓ (2026-08-26, user báo qua video quay trên
		điện thoại: "mở khoá tới Pad 5 rồi mà Pad 1 vẫn vàng").

		Hình học của khu pad là thủ phạm: hai dãy pad nằm dọc x=-71.6 (Pad 1-4) và x=-84.6
		(Pad 5-8), lối vào DUY NHẤT là cái dốc ở z≈2.75 — tức mọi người chơi muốn lên tầng
		trên đều phải GIẪM QUA Pad_1 (z=-7). Bản thân phép nhận diện (Touched ngày trước,
		quét hình học bây giờ) không phân biệt "đứng lên để chọn" với "chạy ngang qua", nên
		mỗi lần đi vào khu này người chơi bị tự hạ về +1/step.

		Và nó hạ VĨNH VIỄN: `enforcePad` cố tình chỉ HẠ (`current <= eligible` là thoát sớm),
		nên không có gì kéo họ trở lại pad 5. Người chơi chỉ thấy Pad 1 sáng vàng và tốc độ
		farm tụt xuống 1/50 mà không một dòng nào giải thích.

		⚠️ SỬA LẠI 2026-08-26 (user): bản trước BỎ QUA HẲN pad thấp hơn với lý do "không ai
		muốn chọn pad yếu hơn". Sai — đó là cấm người chơi tự chọn pad. Có lý do thật để
		xuống: xem lại pad mình vừa mở, đứng cùng bạn, hoặc chỉ vì muốn thế. Game chọn giúp
		pad cao nhất lúc vào, nhưng quyền chọn vẫn phải nằm ở người chơi.

		Cách phân biệt "chọn" với "chạy ngang qua" là THỜI GIAN ĐỨNG, không phải cấm đoán:
		xuống pad thấp hơn chỉ ăn khi đứng yên đủ `DOWNGRADE_DWELL_SECONDS` (xem
		`tickPendingSelect`). Người chạy lên dốc giẫm qua Pad_1 rời pad sau ~0.2s ⇒ không đổi
		gì, đúng như bản vá cũ; người muốn xuống thật chỉ cần đứng lại một nhịp.

		⚠️ Tutorial vẫn phải báo NGAY khi chạm (không đợi đứng đủ giờ): người đã ở Pad 3+ mà
		quay lại giẫm Pad 2 thì bước 2 vẫn phải tính là xong, nếu không họ kẹt tutorial.
	]]
	-- Chưa đủ Wins cho pad này → đứng lên cũng không được hưởng.
	if padIndex > eligible then
		pendingSelect[player] = nil
		GamePackets.toast.sendTo({
			kind = "pad",
			message = `Need {Constants.FormatNumber(config.requiredWins)} Wins`,
			amount = 0,
		}, player)
		return
	end

	if padIndex < activeIndex(player) then
		if padIndex >= 2 and TutorialService then
			TutorialService.Notify(player, "Pad2")
		end

		local pending = pendingSelect[player]
		if not pending or pending.entry.padPart ~= entry.padPart then
			pendingSelect[player] = {
				config = config,
				entry = entry,
				since = now,
			}
			--[[
				Nói thẳng luật ra, nếu không người chơi đứng lên mà không thấy gì đổi sẽ tưởng
				pad hỏng.

				Nhưng CÓ HẠN GIỜ: lối vào khu bắt buộc giẫm qua Pad_1, nên không chặn thì mỗi
				lần đi vào là một cái toast — đúng kiểu nhắc nhở làm người ta ghét cả tính năng.
			]]
			if now - (lastHintTime[player] or -math.huge) >= HINT_COOLDOWN_SECONDS then
				lastHintTime[player] = now
				GamePackets.toast.sendTo({
					kind = "pad",
					message = `Stand here to switch to +{config.speedPerStep}/step`,
					amount = 0,
				}, player)
			end
		end
		return
	end

	pendingSelect[player] = nil
	applyPad(player, config)
	-- Bước 2 tutorial: đã dùng được Pad 2 — hiểu cơ chế "Wins đổi lấy sức mạnh".
	if padIndex >= 2 and TutorialService then
		TutorialService.Notify(player, "Pad2")
	end
	GamePackets.toast.sendTo({
		kind = "pad",
		message = `Active Pad: +{config.speedPerStep}/step`,
		amount = 0,
	}, player)
	ProgressionService.SendSnapshot(player)
end

local function connectPad(padModel: Instance)
	if padModel.Name == "BasePads" then
		return
	end
	local padNumberText = padModel.Name:match("^Pad_?(%d+)$")

	local padId = padNumberText and `pad_{padNumberText}`
	local config = padId and Constants.GetMultiplierPadById(padId)
	if not config then
		warn(`[MultiplierPadService] {padModel.Name} không có config trùng id`)
		return
	end

	local padPart = padModel:FindFirstChild(PAD_PART_NAME)
	if not padPart or not padPart:IsA("BasePart") then
		warn(`[MultiplierPadService] {padModel.Name} thiếu PadPart`)
		return
	end

	padPart:SetAttribute("PadId", config.id)
	padPart:SetAttribute("SpeedPerStep", config.speedPerStep)
	padPart:SetAttribute("RequiredWins", config.requiredWins)

	for _, existing in padEntries do
		if existing.padPart == padPart then
			return
		end
	end
	local entry: PadEntry = {
		config = config,
		padPart = padPart,
		index = padIndexFromId(config.id),
		cframe = padPart.CFrame,
		position = padPart.Position,
		halfX = padPart.Size.X / 2,
		halfZ = padPart.Size.Z / 2,
	}
	-- Pad dời/đổi cỡ lúc runtime thì vùng nhận diện phải đi theo, nếu không nó nằm lại chỗ cũ.
	padPart:GetPropertyChangedSignal("CFrame"):Connect(function()
		refreshPadGeometry(entry)
		recomputeCluster()
	end)
	padPart:GetPropertyChangedSignal("Size"):Connect(function()
		refreshPadGeometry(entry)
	end)
	table.insert(padEntries, entry)
end

--[[
	Hình cầu bao cả cụm pad. Vòng quét mỗi frame chỉ xét người nằm trong đây, nên phần lớn
	người chơi (đang chạy obby, đang ở treadmill) chỉ tốn đúng một phép trừ vector.
]]
function recomputeCluster()
	if #padEntries == 0 then
		clusterCenter = nil
		clusterRadius = 0
		return
	end

	local sum = Vector3.zero
	for _, entry in padEntries do
		sum += entry.padPart.Position
	end
	local center = sum / #padEntries

	local radius = 0
	for _, entry in padEntries do
		radius = math.max(radius, (entry.padPart.Position - center).Magnitude)
	end

	clusterCenter = center
	clusterRadius = radius + CLUSTER_PADDING_STUDS
end

local function bootstrapPads()
	local folder = Workspace:FindFirstChild(PADS_FOLDER_NAME, true)
	if not folder then
		warn(`[MultiplierPadService] Workspace.{PADS_FOLDER_NAME} không tồn tại`)
		return
	end

	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			connectPad(child)
		end
	end
	recomputeCluster()

	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(function()
				connectPad(child)
				recomputeCluster()
			end)
		end
	end)
end

--[[
	MỘT FRAME MỘT LƯỢT QUÉT — trái tim của phép nhận diện tức thì.

	Mỗi người chơi ở trong cụm pad: lấy đoạn đường đi từ frame trước tới giờ, tìm pad mà đoạn
	đó quét qua, và CHỈ xử lý khi pad đó KHÁC pad của frame trước (biên vào pad). Nhờ vậy
	đứng yên trên pad không bắn lại `onPadEntered` lần nào, mà bước chân lên là ăn ngay frame
	đó.
]]
local function scanPlayer(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		occupiedPadId[player] = nil
		lastRootPosition[player] = nil
		pendingSelect[player] = nil
		return
	end

	local position = root.Position
	local previous = lastRootPosition[player] or position
	lastRootPosition[player] = position

	-- Ở xa cụm pad: dọn trạng thái rồi thôi.
	local center = clusterCenter
	if center and (position - center).Magnitude > clusterRadius and (previous - center).Magnitude > clusterRadius then
		occupiedPadId[player] = nil
		pendingSelect[player] = nil
		return
	end

	local entry = findPadAt(previous, position)
	local padId = entry and entry.config.id
	if padId ~= occupiedPadId[player] then
		occupiedPadId[player] = padId
		if entry then
			onPadEntered(player, entry)
		end
	end

	tickPendingSelect(player)
end

local function scanPlayers()
	for _, player in Players:GetPlayers() do
		local ok, err = pcall(scanPlayer, player)
		if not ok then
			pendingSelect[player] = nil
			warn(`[MultiplierPadService] quét pad lỗi cho {player.Name}: {err}`)
		end
	end
end

function MultiplierPadService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
	-- Find: tutorial là thứ phụ, thiếu nó thì pad vẫn phải chạy.
	TutorialService = ServiceLocator.Find("TutorialService")
end

function MultiplierPadService.Start()
	bootstrapPads()

	for _, player in Players:GetPlayers() do
		ensureDefaultPad(player)
	end

	Players.PlayerAdded:Connect(function(player)
		-- Đợi data load xong rồi áp pad mặc định
		task.defer(function()
			repeat
				task.wait(0.1)
			until DataService.IsLoaded(player) or player.Parent ~= Players
			if player.Parent == Players then
				ensureDefaultPad(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastHintTime[player] = nil
		pendingSelect[player] = nil
		occupiedPadId[player] = nil
		lastRootPosition[player] = nil
	end)

	-- Nhận diện: mỗi frame một lượt (xem `scanPlayers`). Đây là thứ thay cho `Touched`.
	RunService.Heartbeat:Connect(scanPlayers)

	--[[
		Vòng canh: Wins bị TIÊU ở nhiều nơi (TeleportService, pad tính phí trong
		ProgressionService, và bất cứ thứ gì thêm sau này). Móc vào từng chỗ tiêu là kiểu hỏng
		âm thầm — quên một chỗ là người chơi giữ được pad không còn nuôi nổi, mà chẳng ai thấy.
		Quét 1 giây/lần rẻ hơn nhiều so với việc phải nhớ luật này ở mọi service tương lai, và
		`enforcePad` không làm gì khi trạng thái đã đúng.
	]]
	task.spawn(function()
		while true do
			task.wait(ENFORCE_INTERVAL_SECONDS)
			for _, player in Players:GetPlayers() do
				if DataService.IsLoaded(player) then
					local ok, err = pcall(enforcePad, player, true)
					if not ok then
						warn(`[MultiplierPadService] enforcePad lỗi cho {player.Name}: {err}`)
					end
				end
			end
		end
	end)
end

return MultiplierPadService
