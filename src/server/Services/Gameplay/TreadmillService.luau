--!strict
--[[
	TreadmillService.luau — Kích hoạt farm Speed khi player đứng trên treadmill.

	KIẾN TRÚC MỚI (tối ưu cho 25 player):
	  • Client tự phát hiện đứng trên hitbox (kiểm tra AABB cục bộ, xem
	    TreadmillClientController) rồi gửi packet `treadmillContact { isOn }`.
	  • Server KHÔNG tin client: khi nhận isOn=true, tự tìm hitbox GẦN NHẤT và
	    validate khoảng cách (root nằm trong hitbox + margin). Không hợp lệ → bỏ qua.
	  • Vòng revalidate 1s CHỈ chạy trên các player đang farm: rời hitbox mà không
	    gửi packet "off" (hoặc spoof packet) → server tự tắt.

	So với bản cũ (GetPartsInPart mỗi 0.03s × mọi player × mọi hitbox), chi phí vật lý
	server = 0; chỉ còn vài phép toán vector khi có packet / mỗi giây cho người đang farm.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local TreadmillService = {}

local MODEL_TO_ID: { [string]: string } = {
	Treadmill_x1 = "treadmill_1",
	Treadmill_x3 = "treadmill_2",
	Treadmill_x9 = "treadmill_3",
	Treadmill_x25 = "treadmill_4",
	Treadmill_x100 = "treadmill_5",
}

-- Nới lỏng validate: client báo "đứng trên" được chấp nhận khi root nằm trong
-- hitbox mở rộng thêm margin này (bù trễ mạng ~0.2s ở tốc độ cao).
local HORIZONTAL_MARGIN = 6.0
local VERTICAL_MARGIN = 10.0
local REVALIDATE_INTERVAL = 1.0
local PACKET_MIN_INTERVAL = 0.1
local LOCKED_TOAST_COOLDOWN = 3.0

type TreadmillEntry = {
	id: string,
	multiplier: number,
	hitbox: BasePart,
}

local treadmills: { TreadmillEntry } = {}
local activeFarmers: { [Player]: TreadmillEntry } = {}
local lockedToastAt: { [Player]: number } = {}
local lastPacketAt: { [Player]: number } = {}

local DataService: any
local ProgressionService: any
local GamepassService: any
local TelemetryService: any

-- Root có nằm trong hitbox (theo hệ trục hitbox) + margin không? Thuần toán học, không physics query.
local function isWithinHitbox(root: BasePart, hitbox: BasePart): boolean
	local localPos = hitbox.CFrame:PointToObjectSpace(root.Position)
	local halfSize = hitbox.Size * 0.5
	return math.abs(localPos.X) <= halfSize.X + HORIZONTAL_MARGIN
		and math.abs(localPos.Z) <= halfSize.Z + HORIZONTAL_MARGIN
		and math.abs(localPos.Y) <= halfSize.Y + VERTICAL_MARGIN
end

local function findValidTreadmill(root: BasePart): TreadmillEntry?
	for _, entry in treadmills do
		if entry.hitbox.Parent and isWithinHitbox(root, entry.hitbox) then
			return entry
		end
	end
	return nil
end

local function setOff(player: Player)
	-- Đang farm mà tắt ⇒ vừa rời treadmill. Đây là bước 3 của phễu `CoreLoop`: ranh giới
	-- giữa "đang farm" và "bước vào obby" — chỗ nghi ngờ nhất trong 90 giây đầu.
	if activeFarmers[player] and TelemetryService then
		TelemetryService.CoreLoop(player, "LeaveTreadmill")
	end
	activeFarmers[player] = nil
	ProgressionService.SetTreadmillState(player, "treadmill_1", 1, false)
end

local function tryActivate(player: Player)
	local root = CharacterUtil.GetAliveRoot(player)
	if not root then
		setOff(player)
		return
	end

	local data = DataService.GetData(player)
	if not data then
		setOff(player)
		return
	end

	-- SERVER VALIDATE: client nói "đang đứng trên treadmill" — kiểm tra khoảng cách thật.
	local entry = findValidTreadmill(root)
	if not entry then
		setOff(player)
		return
	end

	-- Treadmill bị khoá: không farm, hiện prompt mua gamepass (throttle).
	if entry.id ~= "treadmill_1" and not data.UnlockedTreadmills[entry.id] then
		local now = os.clock()
		if now - (lockedToastAt[player] or 0) > LOCKED_TOAST_COOLDOWN then
			lockedToastAt[player] = now
			GamePackets.toast.sendTo({
				kind = "treadmill",
				message = "Purchase this treadmill to use it!",
				amount = 0,
			}, player)
			if GamepassService then
				GamepassService.PromptTreadmillPurchase(player, entry.id)
			end
		end
		setOff(player)
		return
	end

	activeFarmers[player] = entry
	if TelemetryService then
		TelemetryService.CoreLoop(player, "TreadmillStart")
		TelemetryService.CoreLoopV2(player, "TreadmillStart")
	end
	ProgressionService.SetTreadmillState(player, entry.id, entry.multiplier, true)
end

function TreadmillService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
	GamepassService = ServiceLocator.Find("GamepassService")
	TelemetryService = ServiceLocator.Find("TelemetryService")
end

function TreadmillService.Start()
	-- Scan Workspace descendants recursively to register all treadmills (Lobby, Zone 1, Zone 2, etc.)
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("Model") and MODEL_TO_ID[desc.Name] then
			local treadmillId = MODEL_TO_ID[desc.Name]
			local hitbox = desc:FindFirstChild("Hitbox")
			if not hitbox or not hitbox:IsA("BasePart") then
				warn(`[TreadmillService] Hitbox part not found in {desc.Name} at {desc:GetFullName()}`)
				continue
			end

			local config = Constants.GetTreadmillById(treadmillId)
			table.insert(treadmills, {
				id = treadmillId,
				multiplier = if config then config.multiplier else 1,
				hitbox = hitbox,
			})
		end
	end

	-- Trigger từ client (đã rate-limit); server validate lại toàn bộ.
	GamePackets.treadmillContact.listen(function(data, player)
		if not player or typeof(data.isOn) ~= "boolean" then
			return
		end

		local now = os.clock()
		if now - (lastPacketAt[player] or 0) < PACKET_MIN_INTERVAL then
			return
		end
		lastPacketAt[player] = now

		if data.isOn then
			tryActivate(player)
		else
			setOff(player)
		end
	end)

	-- Revalidate định kỳ CHỈ người đang farm: rời xa hitbox / chết → tự tắt.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < REVALIDATE_INTERVAL then
			return
		end
		accumulator = 0

		for player, entry in activeFarmers do
			local root = CharacterUtil.GetAliveRoot(player)
			if not root or not entry.hitbox.Parent or not isWithinHitbox(root, entry.hitbox) then
				setOff(player)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		activeFarmers[player] = nil
		lockedToastAt[player] = nil
		lastPacketAt[player] = nil
	end)
end

return TreadmillService
