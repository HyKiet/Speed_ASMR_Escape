--!strict
-- Server: xác minh group, trao quà một lần qua ProgressionService và gửi trạng thái cho modal.
-- ProximityPrompt và ByteNet cùng đi qua kiểm tra phiên và giới hạn tần suất.
--[[
	Group Chest: quà tham gia group, cache trạng thái group và gắn ProximityPrompt cho rương lobby.

	══ ĐIỀU KIỆN DUY NHẤT = VÀO GROUP (bỏ vế "Like Game" 2026-08-24) ═══════════════════════

	Trước đây quà đòi HAI thứ: vào group **và** "xác nhận đã like game". Vế thứ hai đã bị gỡ
	vì nó không có thật ở cả hai đầu:

	  • **Không xác minh được.** Roblox không expose API server-side nào cho biết một player
	    đã like experience hay chưa. Server chỉ bật một cờ khi client bảo nó bật.
	  • **Không làm gì cả.** Nút "Like Game" bên client không mở giao diện like — nó chỉ gửi
	    gói tin bật cờ. Người chơi bấm xong tưởng mình đã like, thực tế không.
	  • **Tự bật.** Nút gộp "JOIN + LIKE + CLAIM" gọi `confirmLike()` ngay dòng đầu, vô điều
	    kiện. Nên điều kiện đó chưa từng chặn được ai — nó là hình thức thuần tuý.

	Ngoài ra thưởng cho hành vi like/favorite là vùng rủi ro chính sách của Roblox (thưởng cho
	vào group thì không). Gỡ hẳn vừa đúng với thứ đang thực sự xảy ra, vừa tránh vùng đó.

	Phần thưởng GIỮ NGUYÊN (5.000 Speed + 10 Wins + 10% Wins vĩnh viễn + tag [Fan]): trước
	giờ mọi người bấm nút đều nhận đủ, nên đây không phải cắt quà mà là bỏ một cái cổng giả.

	Điều kiện còn lại là điều kiện THẬT: `player:IsInGroup()` do server tự hỏi Roblox, client
	không nói dối được.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local GroupChestConfig = require(ReplicatedStorage.Shared.Config.GroupChest)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local CHEST_MODEL_NAME = "GroupChest"
local PROMPT_NAME = "GroupChestPrompt"
local CLAIM_COOLDOWN_SECONDS = 1.25

type PlayerData = {
	Speed: number,
	hasClaimedGroupReward: boolean,
}

local DataService
local ProgressionService

local isGroupMemberByPlayer: { [Player]: boolean } = {}
local claimCooldownByPlayer: { [Player]: number } = {}
local promptJanitor = Janitor.new()

local GroupChestService = {}

local function sendToast(player: Player, message: string, amount: number?)
	GamePackets.toast.sendTo({
		kind = "groupChest",
		message = message,
		amount = amount or 0,
	}, player)
end

local function computeGroupMembership(player: Player): boolean
	local success, result = pcall(function()
		return player:IsInGroupAsync(GroupChestConfig.GROUP_ID)
	end)

	if not success then
		warn(`[GroupChestService] Không kiểm tra được group cho {player.Name}: {tostring(result)}`)
		return false
	end

	return result == true
end

local function cachePlayer(player: Player)
	if player.Parent ~= Players then
		return
	end
	local isMember = computeGroupMembership(player)
	-- Truy vấn Roblox có thể yield sau PlayerRemoving; không tạo lại cache của người đã rời.
	if player.Parent ~= Players then
		return
	end
	isGroupMemberByPlayer[player] = isMember
	player:SetAttribute("IsGroupMember", isMember)
end

local function sendState(player: Player)
	local data: PlayerData? = DataService.GetData(player)
	GamePackets.groupChestState.sendTo({
		isGroupMember = GroupChestService.IsGroupMember(player),
		hasClaimed = if data then data.hasClaimedGroupReward else false,
	}, player)
end

local function getOrCreatePrompt(chest: Instance): ProximityPrompt?
	local existingPrompt = chest:FindFirstChildWhichIsA("ProximityPrompt", true)
	if existingPrompt then
		return existingPrompt
	end

	local promptParent = chest:FindFirstChildWhichIsA("BasePart", true)
	if not promptParent then
		warn("[GroupChestService] GroupChest không có BasePart để gắn ProximityPrompt.")
		return nil
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "Claim"
	prompt.ObjectText = "Group Chest"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptParent
	return prompt
end

local function canAttemptClaim(player: Player): boolean
	local now = os.clock()
	local lastAttempt = claimCooldownByPlayer[player] or 0
	if now - lastAttempt < CLAIM_COOLDOWN_SECONDS then
		return false
	end

	claimCooldownByPlayer[player] = now
	return true
end

function GroupChestService.IsGroupMember(player: Player): boolean
	local cached = isGroupMemberByPlayer[player]
	if cached ~= nil then
		return cached
	end

	cachePlayer(player)
	return isGroupMemberByPlayer[player] == true
end

function GroupChestService.RefreshGroupMembership(player: Player): boolean
	cachePlayer(player)
	return isGroupMemberByPlayer[player] == true
end

function GroupChestService.OpenChest(player: Player)
	if player.Parent ~= Players or NetRateLimit.ShouldDrop(player, "groupChestState") then
		return
	end
	GroupChestService.RefreshGroupMembership(player)
	if player.Parent == Players then
		sendState(player)
	end
end

function GroupChestService.TryClaim(player: Player): boolean
	if player.Parent ~= Players or not canAttemptClaim(player) then
		return false
	end

	local data: PlayerData? = DataService.GetData(player)
	if not data then
		sendToast(player, "Data still loading")
		return false
	end

	if not GroupChestService.IsGroupMember(player) then
		sendToast(player, "Join the Roblox group first!")
		sendState(player)
		return false
	end

	-- Xác minh group có thể yield; chỉ sửa đúng profile vẫn thuộc phiên đang hoạt động.
	if player.Parent ~= Players or DataService.GetData(player) ~= data then
		return false
	end
	if data.hasClaimedGroupReward then
		sendToast(player, "Group chest already claimed")
		sendState(player)
		return false
	end

	-- Cờ nhận quà được set trước khi cộng thưởng để chống double-trigger trong cùng frame.
	data.hasClaimedGroupReward = true
	local granted = ProgressionService.GrantSpeed(player, GroupChestConfig.STARTER_SPEED_REWARD)
	if not granted then
		data.hasClaimedGroupReward = false
		sendToast(player, "Could not claim right now")
		return false
	end

	--[[
		Wins TRAO NGAY (2026-08-10): xem khối cân bằng trong `Config/GroupChest.luau`.
		Cộng SAU khi Speed đã vào chắc chắn — `GrantSpeed` là bước duy nhất có thể thất bại và
		phải rollback cờ; đảo thứ tự thì lỡ Speed hỏng là người chơi đã ôm Wins mà rương vẫn
		mở lại được.

		`AwardWins` tự nhân x1.1 của chính buff group này (ProgressionService), nên số vào túi
		là 11 chứ không phải 10 — không sửa: người vừa join group hưởng buff ngay từ đồng Wins
		đầu tiên là đúng, và chênh 1 Win không đụng tới phép tính "13 < 15" đã chốt.
	]]
	ProgressionService.AwardWins(player, GroupChestConfig.INSTANT_WINS_REWARD, "groupChest")

	-- Toast này là thứ kích hoạt thẻ chúc mừng bay (HUDController lọc kind == "groupChest"
	-- kèm amount > 0), nên `amount` phải là con số ĐÁNG khoe nhất: Speed.
	sendToast(player, "Speed from Group Chest", GroupChestConfig.STARTER_SPEED_REWARD)
	sendState(player)
	return true
end

local function bindChestPrompt()
	promptJanitor:Sweep()
	local chest = Workspace:FindFirstChild(CHEST_MODEL_NAME, true)
	if not chest then
		warn(`[GroupChestService] Không tìm thấy Workspace.{CHEST_MODEL_NAME}.`)
		return
	end

	local prompt = getOrCreatePrompt(chest)
	if not prompt then
		return
	end

	promptJanitor:Add(prompt.Triggered:Connect(function(player: Player)
		GroupChestService.OpenChest(player)
	end))
	promptJanitor:Add(prompt.Destroying:Connect(function()
		promptJanitor:Sweep()
	end))
end

function GroupChestService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
end

function GroupChestService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(cachePlayer, player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(cachePlayer, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		isGroupMemberByPlayer[player] = nil
		claimCooldownByPlayer[player] = nil
	end)

	bindChestPrompt()

	GamePackets.requestGroupChestState.listen(function(_request, player)
		if player then
			GroupChestService.OpenChest(player)
		end
	end)

	-- TryClaim đã tự có cooldown riêng (canAttemptClaim / CLAIM_COOLDOWN_SECONDS),
	-- nên không cần khoác thêm rate-limit chung ở đây.
	GamePackets.requestGroupChestClaim.listen(function(_request, player)
		if player then
			GroupChestService.TryClaim(player)
		end
	end)
end

return GroupChestService
