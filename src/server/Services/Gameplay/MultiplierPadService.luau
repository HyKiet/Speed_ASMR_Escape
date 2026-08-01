--!strict
-- Khi player chạm PadPart trong Workspace.MultiplierPads.Pad_{N}:
-- - Nếu TotalWins >= requiredWins: set ActivePadId attribute (client tô màu vàng/xanh)
-- - Nếu chưa đủ: gửi toast "Need X Wins"
-- Pad mặc định = pad_1 (free) khi player join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

type PadConfig = Constants.MultiplierPadConfig

local TOUCH_COOLDOWN_SECONDS = 0.4
local PADS_FOLDER_NAME = "MultiplierPads"
local PAD_PART_NAME = "PadPart"

local lastTouchTime: { [Player]: number } = {}
local DataService
local ProgressionService

local MultiplierPadService = {}

-- pad_3 -> 3. Trả về index trong bảng config (cũng là số thứ tự pad).
local function padIndexFromId(id: string): number
	local n = id:match("^pad_(%d+)$")
	return n and tonumber(n) or 1
end

-- Đồng bộ attribute HighestPadIndex (client đọc để tô màu vàng/xanh/xám).
local function publishHighestPad(player: Player, data: any)
	local highest = math.floor(data.HighestPadIndex or 1)
	if highest < 1 then
		highest = 1
		data.HighestPadIndex = 1
	end
	player:SetAttribute("HighestPadIndex", highest)
end

local function applyPad(player: Player, config: PadConfig)
	player:SetAttribute("ActivePadId", config.id)
	ProgressionService.SetActivePad(player, config.id, config.speedPerStep)
end

local function ensureDefaultPad(player: Player)
	local data = DataService.GetData(player)
	if data then
		publishHighestPad(player, data)
	end

	local current = player:GetAttribute("ActivePadId")
	if typeof(current) ~= "string" then
		applyPad(player, Constants.MULTIPLIER_PADS[1])
	else
		local config = Constants.GetMultiplierPadById(current)
		if config then
			ProgressionService.SetActivePad(player, config.id, config.speedPerStep)
		else
			applyPad(player, Constants.MULTIPLIER_PADS[1])
		end
	end
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
	local highest = math.floor(data.HighestPadIndex or 1)

	if padIndex <= highest then
		-- Pad đã mở khóa → chỉ chuyển active (miễn phí), không cần Wins.
		applyPad(player, config)
		GamePackets.toast.sendTo({
			kind = "pad",
			message = `Active Pad: +{config.speedPerStep}/step`,
			amount = 0,
		}, player)
		ProgressionService.SendSnapshot(player)
		return
	end

	if padIndex > highest + 1 then
		-- BẮT BUỘC MUA TUẦN TỰ: không cho cắt ngang.
		GamePackets.toast.sendTo({
			kind = "pad",
			message = `Unlock Pad {highest + 1} first!`,
			amount = 0,
		}, player)
		return
	end

	-- padIndex == highest + 1: pad kế tiếp → cần đủ Wins để mở khóa.
	if data.TotalWins < config.requiredWins then
		GamePackets.toast.sendTo({
			kind = "pad",
			message = `Need {Constants.FormatNumber(config.requiredWins)} Wins`,
			amount = 0,
		}, player)
		return
	end

	data.HighestPadIndex = padIndex
	publishHighestPad(player, data)
	applyPad(player, config)
	GamePackets.toast.sendTo({
		kind = "pad",
		message = `Unlocked Pad +{config.speedPerStep}/step!`,
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
end

function MultiplierPadService.Start()
	bootstrapPads()

	for _, player in Players:GetPlayers() do
		ensureDefaultPad(player)
	end

	Players.PlayerAdded:Connect(function(player)
		-- Đợi data load xong rồi áp pad mặc định
		task.defer(function()
			repeat task.wait(0.1) until DataService.IsLoaded(player) or player.Parent ~= Players
			if player.Parent == Players then
				ensureDefaultPad(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTouchTime[player] = nil
	end)
end

return MultiplierPadService
