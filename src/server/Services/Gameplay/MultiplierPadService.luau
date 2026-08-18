--!strict
--[[
	Khi player chạm PadPart trong Workspace.MultiplierPads.Pad_{N}:
	  - Nếu TotalWins >= requiredWins: set ActivePadId attribute (client tô màu vàng/xanh)
	  - Nếu chưa đủ: gửi toast "Need X Wins"
	Pad mặc định = pad_1 (free) khi player join.

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
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

type PadConfig = Constants.MultiplierPadConfig

local TOUCH_COOLDOWN_SECONDS = 0.4
local ENFORCE_INTERVAL_SECONDS = 1
local PADS_FOLDER_NAME = "MultiplierPads"
local PAD_PART_NAME = "PadPart"

local lastTouchTime: { [Player]: number } = {}
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

	-- Chưa chọn pad nào (vừa vào game) → pad_1 như cũ. ⚠️ KHÔNG phát thẳng pad cao nhất đang
	-- đủ điều kiện: hàm này chỉ được phép HẠ, không được tặng — người chơi vẫn phải tự đi tới
	-- pad mà đứng lên, đó là cả nghi thức của khu Multiplier Pads.
	if current == 0 then
		applyPad(player, Constants.MULTIPLIER_PADS[1])
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

local function onPadTouched(config: PadConfig, hit: BasePart)
	local player = CharacterUtil.GetPlayerFromHit(hit)
	if not player then
		return
	end

	local now = os.clock()
	if now - (lastTouchTime[player] or 0) < TOUCH_COOLDOWN_SECONDS then
		return
	end
	lastTouchTime[player] = now

	-- Đã chọn pad này rồi → bỏ qua
	if player:GetAttribute("ActivePadId") == config.id then
		return
	end

	local data = DataService.GetData(player)
	if not data then
		return
	end

	local padIndex = padIndexFromId(config.id)
	local eligible = eligibleIndex(data)
	publishHighestPad(player, data, eligible)

	-- Chưa đủ Wins cho pad này → đứng lên cũng không được hưởng.
	if padIndex > eligible then
		GamePackets.toast.sendTo({
			kind = "pad",
			message = `Need {Constants.FormatNumber(config.requiredWins)} Wins`,
			amount = 0,
		}, player)
		return
	end

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

	padPart.Touched:Connect(function(hit: BasePart)
		if hit:IsA("BasePart") then
			onPadTouched(config, hit)
		end
	end)
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

	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(connectPad, child)
		end
	end)
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
		lastTouchTime[player] = nil
	end)

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
