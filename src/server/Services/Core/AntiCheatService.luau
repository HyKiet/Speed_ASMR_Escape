--!strict
--[[
	AntiCheatService.luau — Giám sát di chuyển server-side (25 player, chi phí O(n) thuần toán học).

	Cơ chế:
	  • Mỗi CHECK_INTERVAL, đo quãng đường X-Z player đi được kể từ lần đo trước.
	  • allowed = max(WalkSpeed_server × SPEED_HEADROOM, MIN_ALLOWED_SPEED) + allowance theo stage.
	  • Dịch chuyển 1 tick > allowed×dt + TELEPORT_SLACK  → TELEPORT HACK → giật ngược ngay.
	  • Tốc độ trung bình tick > allowed                   → 1 strike; đủ MAX_STRIKES trong
	    STRIKE_WINDOW → SPEED HACK → giật ngược về vị trí hợp lệ cuối cùng.
	  • WalkSpeed hack cục bộ trên client không đổi được giá trị server → bị bắt qua tọa độ.

	Whitelist teleport: mọi teleport HỢP LỆ do server thực hiện (TeleportService, checkpoint,
	revive, skip stage, respawn) phải gọi AntiCheatService.NoteTeleport(player) — player được
	miễn kiểm tra TELEPORT_GRACE giây rồi neo lại vị trí mới.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AntiCheatConfig = require(ReplicatedStorage.Shared.Config.AntiCheat)
local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)

type Entry = {
	lastPos: Vector3?, -- vị trí lần đo trước (nil = chưa neo)
	lastClock: number,
	validPos: Vector3?, -- vị trí hợp lệ cuối cùng (điểm giật ngược)
	strikes: { number }, -- os.clock() của từng strike trong cửa sổ
	bands: { number }, -- os.clock() của từng lần giật ngược (để leo thang → kill)
	graceUntil: number, -- miễn kiểm tra tới thời điểm này (sau teleport hợp lệ / respawn)
}

local entries: { [Player]: Entry } = {}

local AntiCheatService = {}

local function getEntry(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = {
			lastPos = nil,
			lastClock = os.clock(),
			validPos = nil,
			strikes = {},
			bands = {},
			graceUntil = 0,
		}
		entries[player] = entry
	end
	return entry
end

--[[
	DẤU VẾT CHẨN ĐOÁN (chỉ Studio) — xem `Controllers/Debug/RubberBandLogger`.

	Client thấy mình bị dời chỗ nhưng KHÔNG biết ai dời. Server thì biết, nên nó đóng dấu mốc
	thời gian lên chính Player; attribute nằm trên Instance nên client đọc được ngay.

	Dùng `workspace:GetServerTimeNow()` chứ KHÔNG dùng `os.clock()`: `os.clock()` đếm từ lúc
	tiến trình khởi động nên số của server và số của client là hai gốc khác nhau, so với nhau
	là vô nghĩa. `GetServerTimeNow` là đồng hồ chung của cả hai phía — cùng lý do mà mọi bẫy
	zone đang dùng nó.
]]
local IS_STUDIO = RunService:IsStudio()

local function stamp(player: Player, attribute: string, reason: string?)
	if not IS_STUDIO then
		return
	end
	player:SetAttribute(attribute, workspace:GetServerTimeNow())
	if reason then
		player:SetAttribute("DbgBandReason", reason)
	end
end

-- Gọi sau MỌI lần server chủ động đặt CFrame cho player (teleport/revive/spawn).
function AntiCheatService.NoteTeleport(player: Player)
	local entry = getEntry(player)
	entry.graceUntil = os.clock() + AntiCheatConfig.TELEPORT_GRACE
	entry.lastPos = nil
	entry.validPos = nil
	table.clear(entry.strikes)
	stamp(player, "DbgTeleportAt")
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function getAllowedSpeed(player: Player, humanoid: Humanoid): number
	local allowed = math.max(humanoid.WalkSpeed * AntiCheatConfig.SPEED_HEADROOM, AntiCheatConfig.MIN_ALLOWED_SPEED)

	local activeStage = player:GetAttribute("ActiveStage")
	if typeof(activeStage) == "number" then
		allowed += AntiCheatConfig.STAGE_EXTRA_ALLOWANCE[activeStage] or 0
	end

	return allowed
end

local function rubberBand(player: Player, entry: Entry, root: BasePart, reason: string)
	local target = entry.validPos
	if not target then
		return
	end

	if AntiCheatConfig.LOG_VIOLATIONS then
		warn(`[AntiCheat] {player.Name}: {reason} → giật ngược về vị trí hợp lệ`)
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.new(target) * root.CFrame.Rotation
	stamp(player, "DbgBandAt", reason)

	table.clear(entry.strikes)
	entry.lastPos = target
	entry.graceUntil = os.clock() + 0.5 -- tránh tự phạt lại ngay tick sau

	-- LEO THANG: hack dai dẳng (giữa các lần giật ngược vẫn tiến được) → kill nhân vật.
	local now = os.clock()
	for index = #entry.bands, 1, -1 do
		if now - entry.bands[index] > AntiCheatConfig.ESCALATION_WINDOW then
			table.remove(entry.bands, index)
		end
	end
	table.insert(entry.bands, now)

	if #entry.bands >= AntiCheatConfig.ESCALATION_BAND_COUNT then
		table.clear(entry.bands)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if AntiCheatConfig.LOG_VIOLATIONS then
				warn(`[AntiCheat] {player.Name}: vi phạm lặp lại → kill respawn`)
			end
			humanoid.Health = 0
		end
	end
end

local function pruneStrikes(entry: Entry, now: number)
	for index = #entry.strikes, 1, -1 do
		if now - entry.strikes[index] > AntiCheatConfig.STRIKE_WINDOW then
			table.remove(entry.strikes, index)
		end
	end
end

local function checkPlayer(player: Player, now: number)
	local humanoid, root = CharacterUtil.GetCharacterParts(player)
	if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then
		local entry = entries[player]
		if entry then
			entry.lastPos = nil
		end
		return
	end

	local entry = getEntry(player)
	local position = root.Position
	local dt = now - entry.lastClock
	entry.lastClock = now

	if now < entry.graceUntil or dt <= 0 then
		entry.lastPos = position
		entry.validPos = position
		return
	end

	local lastPos = entry.lastPos
	if not lastPos then
		-- Neo lần đầu (sau spawn/teleport/grace).
		entry.lastPos = position
		entry.validPos = position
		return
	end

	local allowed = getAllowedSpeed(player, humanoid)
	local traveled = horizontalDistance(position, lastPos)

	-- 1) TELEPORT HACK: nhảy vọt trong 1 tick, vượt xa mọi cơ chế hợp lệ.
	if traveled > allowed * dt + AntiCheatConfig.TELEPORT_SLACK then
		rubberBand(player, entry, root, `teleport {math.floor(traveled)} studs / {string.format("%.2f", dt)}s`)
		return
	end

	-- 2) SPEED HACK: tốc độ trung bình vượt ngưỡng → strike.
	local speed = traveled / dt
	if speed > allowed then
		pruneStrikes(entry, now)
		table.insert(entry.strikes, now)

		if AntiCheatConfig.LOG_VIOLATIONS then
			warn(
				`[AntiCheat] {player.Name}: strike {#entry.strikes}/{AntiCheatConfig.MAX_STRIKES} — {math.floor(speed)} > {math.floor(
					allowed
				)} studs/s`
			)
		end

		if #entry.strikes >= AntiCheatConfig.MAX_STRIKES then
			rubberBand(player, entry, root, `speed {math.floor(speed)} studs/s (allowed {math.floor(allowed)})`)
			return
		end

		-- Tick vi phạm: KHÔNG cập nhật validPos (giữ điểm giật ngược cũ).
		entry.lastPos = position
		return
	end

	-- Tick sạch: cập nhật cả 2 mốc.
	entry.lastPos = position
	entry.validPos = position
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function()
		AntiCheatService.NoteTeleport(player) -- spawn = teleport hợp lệ
	end)
	if player.Character then
		AntiCheatService.NoteTeleport(player)
	end
end

function AntiCheatService.Init() end

function AntiCheatService.Start()
	if not AntiCheatConfig.ENABLED then
		-- NoteTeleport vẫn phải gọi được (các service khác gọi vô điều kiện), chỉ là
		-- không có vòng kiểm tra nào chạy nên nó thành no-op.
		warn("[AntiCheat] ĐANG TẮT (AntiCheatConfig.ENABLED = false) — nhớ bật lại trước khi publish")
		return
	end

	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < AntiCheatConfig.CHECK_INTERVAL then
			return
		end
		accumulator = 0

		local now = os.clock()
		for _, player in Players:GetPlayers() do
			checkPlayer(player, now)
		end
	end)
end

return AntiCheatService
