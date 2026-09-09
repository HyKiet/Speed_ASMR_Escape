--!strict
-- Mua và phát emote. Server giữ quyền sở hữu/khu vực; client chỉ dựng animation.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Emotes = require(ReplicatedStorage.Shared.Config.Economy.Emotes)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

type ActiveEmote = { emoteId: string, startedOnTreadmill: boolean }

local EmoteService = {}
local DataService: any
local TelemetryService: any
local active: { [Player]: ActiveEmote } = {}
local pendingState: { [Player]: boolean } = {}
local byId: { [string]: any } = {}
local scanAccumulator = 0
local zonesFolder: Instance? = nil
local floorRaycastParams = RaycastParams.new()
floorRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
floorRaycastParams.IgnoreWater = true

local function sendState(player: Player)
	local data = DataService.GetData(player)
	if not data then
		pendingState[player] = true
		return
	end
	pendingState[player] = nil
	GamePackets.emoteState.sendTo({ unlocked = data.UnlockedEmotes }, player)
end

local function stopEmote(player: Player)
	if not active[player] then
		return
	end
	active[player] = nil
	GamePackets.emoteBroadcast.sendToAll({
		userId = player.UserId,
		action = "stop",
		emoteId = "",
	})
end

local function canPlay(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not humanoid
		or humanoid.Health <= 0
		or humanoid.FloorMaterial == Enum.Material.Air
		or not root
		or not root:IsA("BasePart")
	then
		return false
	end

	local activeStage = player:GetAttribute("ActiveStage")
	if typeof(activeStage) ~= "number" or activeStage <= 0 then
		return true
	end

	-- ActiveStage ghi stage gần nhất, không phải lúc nào cũng phản ánh vị trí hiện tại: player có thể
	-- chạy ngược từ zone về Lobby mà không đi qua luồng teleport reset attribute. Xác minh mặt sàn
	-- ngay dưới chân đúng lúc nhận packet Play; raycast một lần, không thêm query vào vòng 10Hz.
	floorRaycastParams.FilterDescendantsInstances = { character :: Model }
	local floorHit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), floorRaycastParams)
	if not zonesFolder or not floorHit or floorHit.Instance:IsDescendantOf(zonesFolder) then
		return false
	end

	-- Đã đứng trên sàn ngoài toàn bộ Workspace.Zones: sửa luôn state session bị stale để mọi hệ thống
	-- đọc ActiveStage sau đó cùng thấy player đã rời Obby.
	player:SetAttribute("ActiveStage", 0)
	player:SetAttribute("CurrentStage", 0)
	return true
end

local function buy(player: Player, emoteId: string)
	local config = byId[emoteId]
	local data = DataService.GetData(player)
	if not config or not data then
		return
	end
	if data.UnlockedEmotes[emoteId] then
		sendState(player)
		return
	end
	if data.TotalWins < config.priceWins then
		GamePackets.toast.sendTo({ kind = "emote", message = "Not enough Wins", amount = 0 }, player)
		return
	end

	-- Không yield giữa đọc → kiểm → trừ → trao: giao dịch nguyên tử trong VM Luau.
	data.TotalWins -= config.priceWins
	data.UnlockedEmotes[emoteId] = true
	local questService = ServiceLocator.Find("QuestService")
	if questService then
		questService.Record(player, "cosmetic_purchase", 1)
	end
	if TelemetryService then
		TelemetryService.Economy(player, "Sink", config.priceWins, data.TotalWins, "emote")
		TelemetryService.Once(player, "FirstEmotePurchase", 1)
	end
	DataService.UpdateLeaderstats(player)
	GamePackets.toast.sendTo({ kind = "emote", message = `Purchased {config.displayName}`, amount = 0 }, player)
	sendState(player)
end

local function play(player: Player, emoteId: string)
	local data = DataService.GetData(player)
	if not byId[emoteId] or not data or not data.UnlockedEmotes[emoteId] then
		return
	end
	if not canPlay(player) then
		GamePackets.toast.sendTo({ kind = "emote", message = "Emotes are disabled in Obby", amount = 0 }, player)
		return
	end
	stopEmote(player)
	active[player] = {
		emoteId = emoteId,
		startedOnTreadmill = player:GetAttribute("TreadmillFarming") == true,
	}
	local questService = ServiceLocator.Find("QuestService")
	if questService then
		questService.Record(player, "emote_use", 1)
	end
	GamePackets.emoteBroadcast.sendToAll({
		userId = player.UserId,
		action = "play",
		emoteId = emoteId,
	})
end

function EmoteService.Init()
	DataService = ServiceLocator.Get("DataService")
	TelemetryService = ServiceLocator.Find("TelemetryService")
	zonesFolder = workspace:FindFirstChild("Zones")
	if not zonesFolder then
		warn("[EmoteService] Missing Workspace.Zones; stale ActiveStage cannot be position-verified")
	end
	for _, config in Emotes.CATALOG do
		byId[config.id] = config
	end
end

function EmoteService.Start()
	GamePackets.requestEmoteAction.listen(function(payload, player)
		if not player or NetRateLimit.ShouldDrop(player, "emoteAction", 0.2) then
			return
		end
		if payload.action == "buy" then
			buy(player, payload.emoteId)
		elseif payload.action == "play" then
			play(player, payload.emoteId)
		elseif payload.action == "stop" then
			stopEmote(player)
		elseif payload.action == "state" then
			sendState(player)
		end
	end)

	local function queueState(player: Player)
		pendingState[player] = true
	end
	for _, player in Players:GetPlayers() do
		queueState(player)
	end
	Players.PlayerAdded:Connect(queueState)
	Players.PlayerRemoving:Connect(function(player)
		stopEmote(player)
		pendingState[player] = nil
	end)

	-- Một vòng tập trung cho mọi người chơi; tối đa 10Hz, không tạo loop theo player.
	RunService.Heartbeat:Connect(function(deltaTime: number)
		scanAccumulator += deltaTime
		if scanAccumulator < 0.1 then
			return
		end
		scanAccumulator = 0
		for player in pendingState do
			if DataService.IsLoaded(player) then
				sendState(player)
			end
		end
		for player, emote in active do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if
				not humanoid
				or humanoid.Health <= 0
				or humanoid.MoveDirection.Magnitude > 0.05
				or humanoid.FloorMaterial == Enum.Material.Air
				or (emote.startedOnTreadmill and player:GetAttribute("TreadmillFarming") ~= true)
			then
				stopEmote(player)
			end
		end
	end)
end

return EmoteService
