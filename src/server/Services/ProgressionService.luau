--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)

local DataService = require(script.Parent.DataService)

type PlayerData = typeof(Constants.DATA_TEMPLATE)

type TreadmillZone = {
	id: string,
	multiplier: number,
	cframe: CFrame,
	size: Vector3,
}

type PlayerSession = {
	lastPosition: Vector3?,
	lastRequestTime: { [string]: number },
	gamepassMultiplier: number?,
	activeTreadmillId: string,
	activeTreadmillMultiplier: number,
	isOnTreadmill: boolean,
	appliedTrailId: string?,
}

local treadmillZones: { TreadmillZone } = {}
local sessions: { [Player]: PlayerSession } = {}

local ProgressionService = {}
local STUDIO_TEST_SPEED_CAP = 150

local function getSession(player: Player): PlayerSession
	local session = sessions[player]
	if session then
		return session
	end

	session = {
		lastPosition = nil,
		lastRequestTime = {},
		gamepassMultiplier = nil,
		activeTreadmillId = "treadmill_1",
		activeTreadmillMultiplier = 1,
		isOnTreadmill = false,
		appliedTrailId = nil,
	}
	sessions[player] = session
	return session
end

local TRAIL_OBJECT_NAME = "SpeedEscapeEquippedTrail"
local TRAIL_ATTACHMENT_A_NAME = "SpeedEscapeTrailAttachmentA"
local TRAIL_ATTACHMENT_B_NAME = "SpeedEscapeTrailAttachmentB"

local TRAIL_VISUALS = {
	trail_green = {
		color = ColorSequence.new(Color3.fromRGB(79, 255, 111), Color3.fromRGB(13, 171, 65)),
		lifetime = 0.5,
		texture = "",
		textureLength = 1,
		widthScale = 1,
		lightEmission = 0.75,
	},
	trail_blue = {
		color = ColorSequence.new(Color3.fromRGB(89, 207, 255), Color3.fromRGB(43, 91, 255)),
		lifetime = 0.55,
		texture = "",
		textureLength = 1,
		widthScale = 1,
		lightEmission = 0.75,
	},
	trail_purple = {
		color = ColorSequence.new(Color3.fromRGB(207, 112, 255), Color3.fromRGB(98, 45, 255)),
		lifetime = 0.6,
		texture = "",
		textureLength = 1,
		widthScale = 1,
		lightEmission = 0.78,
	},
	trail_red = {
		color = ColorSequence.new(Color3.fromRGB(255, 95, 76), Color3.fromRGB(210, 24, 40)),
		lifetime = 0.6,
		texture = "",
		textureLength = 1,
		widthScale = 1,
		lightEmission = 0.78,
	},
	trail_rainbow = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 52, 52)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 176, 43)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 245, 65)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(58, 235, 82)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(65, 163, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(188, 81, 255)),
		}),
		lifetime = 0.72,
		texture = "",
		textureLength = 1,
		widthScale = 1.15,
		lightEmission = 0.9,
	},
	trail_galaxy = {
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 0, 128)),
			ColorSequenceKeypoint.new(0.18, Color3.fromRGB(42, 36, 255)),
			ColorSequenceKeypoint.new(0.46, Color3.fromRGB(186, 28, 255)),
			ColorSequenceKeypoint.new(0.72, Color3.fromRGB(255, 38, 194)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 245, 92)),
		}),
		lifetime = 1.35,
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		textureLength = 0.38,
		widthScale = 2.05,
		lightEmission = 1,
	},
}

local function isRateLimited(player: Player, key: string): boolean
	local session = getSession(player)
	local now = os.clock()
	local lastRequestTime = session.lastRequestTime[key] or 0
	if now - lastRequestTime < Constants.NETWORK_RATE_LIMIT_SECONDS then
		return true
	end

	session.lastRequestTime[key] = now
	return false
end

local function getCharacterParts(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil, nil
	end

	return humanoid, root
end

local function clearTrailVisual(character: Model)
	for _, descendant in character:GetDescendants() do
		if
			descendant.Name == TRAIL_OBJECT_NAME
			or descendant.Name == TRAIL_ATTACHMENT_A_NAME
			or descendant.Name == TRAIL_ATTACHMENT_B_NAME
		then
			descendant:Destroy()
		end
	end
end

local function applyTrailVisual(player: Player, data: PlayerData)
	local session = getSession(player)
	local character = player.Character
	local _, root = getCharacterParts(player)
	if not character or not root then
		return
	end

	local trailId = data.EquippedTrail
	if session.appliedTrailId == trailId and root:FindFirstChild(TRAIL_OBJECT_NAME) then
		return
	end

	clearTrailVisual(character)
	session.appliedTrailId = trailId

	if trailId == "none" then
		return
	end

	local visual = TRAIL_VISUALS[trailId]
	if not visual then
		session.appliedTrailId = "none"
		return
	end

	local attachmentA = Instance.new("Attachment")
	attachmentA.Name = TRAIL_ATTACHMENT_A_NAME
	attachmentA.Position = Vector3.new(0, 1.6, 0.18)
	attachmentA.Parent = root

	local attachmentB = Instance.new("Attachment")
	attachmentB.Name = TRAIL_ATTACHMENT_B_NAME
	attachmentB.Position = Vector3.new(0, -1.7, 0.18)
	attachmentB.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = TRAIL_OBJECT_NAME
	trail.Attachment0 = attachmentA
	trail.Attachment1 = attachmentB
	trail.Color = visual.color
	trail.FaceCamera = true
	trail.Lifetime = visual.lifetime
	trail.LightEmission = visual.lightEmission
	trail.LightInfluence = 0
	trail.MinLength = 0.08
	trail.Texture = visual.texture
	trail.TextureLength = visual.textureLength
	trail.TextureMode = Enum.TextureMode.Wrap
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if trailId == "trail_galaxy" then 0 else 0.08),
		NumberSequenceKeypoint.new(0.72, if trailId == "trail_galaxy" then 0.02 else 0.22),
		NumberSequenceKeypoint.new(1, if trailId == "trail_galaxy" then 0.35 else 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, visual.widthScale),
		NumberSequenceKeypoint.new(0.65, visual.widthScale * 0.72),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = root
end

local function computeGamepassMultiplier(player: Player): number
	local session = getSession(player)
	if session.gamepassMultiplier then
		return session.gamepassMultiplier
	end

	local multiplier = 1
	local passMultipliers = {
		{ id = Constants.GAMEPASS_IDS.DoubleSpeed, multiplier = 2 },
		{ id = Constants.GAMEPASS_IDS.QuadSpeed, multiplier = 4 },
		{ id = Constants.GAMEPASS_IDS.OctaSpeed, multiplier = 8 },
	}

	for _, pass in passMultipliers do
		if pass.id > 0 then
			local success, ownsPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if success and ownsPass then
				multiplier *= pass.multiplier
			end
		end
	end

	session.gamepassMultiplier = multiplier
	return multiplier
end

local function getEffectiveMaxWalkSpeed(data: PlayerData): number
	return math.max(Constants.DEFAULT_WALK_SPEED, Constants.GetMaxWalkSpeed(data.Level))
end

local function applyWalkSpeed(player: Player, data: PlayerData)
	local humanoid = getCharacterParts(player)
	if not humanoid then
		return
	end

	local maxWalkSpeed = getEffectiveMaxWalkSpeed(data)
	local customSpeed = math.clamp(data.CustomSpeedLimit, Constants.DEFAULT_WALK_SPEED, maxWalkSpeed)
	data.CustomSpeedLimit = customSpeed
	humanoid.WalkSpeed = customSpeed
end

local function getTreadmillAtPosition(position: Vector3): (string, number, boolean)
	for _, zone in treadmillZones do
		local localPosition = zone.cframe:PointToObjectSpace(position)
		local halfSize = zone.size * 0.5
		if
			math.abs(localPosition.X) <= halfSize.X + 2
			and math.abs(localPosition.Z) <= halfSize.Z + 2
			and math.abs(localPosition.Y) <= halfSize.Y + Constants.TREADMILL_GAIN_RADIUS
		then
			return zone.id, zone.multiplier, true
		end
	end

	return "treadmill_1", 1, false
end

local function getGainMultiplier(player: Player, data: PlayerData): number
	local session = getSession(player)
	local configuredTreadmill = Constants.GetTreadmillById(data.EquippedTreadmill)
	local treadmillMultiplier = if configuredTreadmill then configuredTreadmill.multiplier else 1

	if session.activeTreadmillMultiplier > treadmillMultiplier then
		treadmillMultiplier = session.activeTreadmillMultiplier
	end

	return treadmillMultiplier
		* Constants.GetTrailMultiplier(data.EquippedTrail)
		* Constants.GetAuraMultiplier(data.EquippedAura)
		* Constants.GetRebirthMultiplier(data.Rebirths)
		* computeGamepassMultiplier(player)
end

local function getCosmeticConfig(category: string, itemId: string): any?
	local catalog = if category == "trail" then Constants.TRAILS elseif category == "aura" then Constants.AURAS else nil
	if not catalog then
		return nil
	end

	for _, config in catalog do
		if config.id == itemId then
			return config
		end
	end

	return nil
end

local function buildSnapshot(player: Player, data: PlayerData)
	local session = getSession(player)
	local maxWalkSpeed = getEffectiveMaxWalkSpeed(data)
	local requiredRebirthLevel = Constants.GetRequiredLevelForRebirth(data.Rebirths)
	local requiredXP = Constants.GetRequiredXP(data.Level)

	return {
		isLoaded = true,
		speed = data.Speed,
		totalWins = data.TotalWins,
		currentRunWins = data.CurrentRunWins,
		streak = math.clamp(math.floor(data.Streak), 0, 65535),
		personalBestDistance = data.PersonalBestDistance,
		personalBestRunWins = data.PersonalBestRunWins,
		totalRuns = math.clamp(math.floor(data.TotalRuns), 0, 4294967295),
		highestCompletedStage = math.clamp(math.floor((data :: any).HighestCompletedStage or 0), 0, 65535),
		level = math.clamp(math.floor(data.Level), 0, 65535),
		xp = data.XP,
		requiredXP = requiredXP,
		rebirths = math.clamp(math.floor(data.Rebirths), 0, 65535),
		maxWalkSpeed = maxWalkSpeed,
		customSpeedLimit = data.CustomSpeedLimit,
		gainMultiplier = getGainMultiplier(player, data),
		treadmillMultiplier = session.activeTreadmillMultiplier,
		isOnTreadmill = session.isOnTreadmill,
		canRebirth = data.Level >= requiredRebirthLevel,
		requiredRebirthLevel = math.clamp(requiredRebirthLevel, 0, 65535),
		activeTreadmillId = session.activeTreadmillId,
		equippedTrail = data.EquippedTrail,
		equippedAura = data.EquippedAura,
		unlockedTrails = data.UnlockedTrails,
		unlockedAuras = data.UnlockedAuras,
	}
end

local function sendSnapshot(player: Player)
	local data = DataService.GetData(player)
	if not data then
		GamePackets.profileSnapshot.sendTo({
			isLoaded = false,
			speed = 0,
			totalWins = 0,
			currentRunWins = 0,
			streak = 0,
			personalBestDistance = 0,
			personalBestRunWins = 0,
			totalRuns = 0,
			highestCompletedStage = 0,
			level = 1,
			xp = 0,
			requiredXP = Constants.GetRequiredXP(1),
			rebirths = 0,
			maxWalkSpeed = Constants.DEFAULT_WALK_SPEED,
			customSpeedLimit = Constants.DEFAULT_WALK_SPEED,
			gainMultiplier = 1,
			treadmillMultiplier = 1,
			isOnTreadmill = false,
			canRebirth = false,
			requiredRebirthLevel = Constants.GetRequiredLevelForRebirth(0),
			activeTreadmillId = "treadmill_1",
			equippedTrail = "none",
			equippedAura = "none",
			unlockedTrails = { none = true },
			unlockedAuras = { none = true },
		}, player)
		return
	end

	GamePackets.profileSnapshot.sendTo(buildSnapshot(player, data), player)
end

local function addSpeed(player: Player, data: PlayerData, amount: number)
	if amount <= 0 then
		return
	end

	local previousMaxWalkSpeed = getEffectiveMaxWalkSpeed(data)
	local wasUsingMaxWalkSpeed = data.CustomSpeedLimit >= previousMaxWalkSpeed

	local appliedAmount = amount
	if RunService:IsStudio() then
		appliedAmount = math.max(0, math.min(amount, STUDIO_TEST_SPEED_CAP - data.Speed))
	end
	if appliedAmount <= 0 then
		applyWalkSpeed(player, data)
		DataService.UpdateLeaderstats(player)
		sendSnapshot(player)
		return
	end

	data.Speed += appliedAmount
	data.XP += appliedAmount * Constants.XP_CONVERSION_RATE

	while data.XP >= Constants.GetRequiredXP(data.Level) do
		data.XP -= Constants.GetRequiredXP(data.Level)
		data.Level += 1
	end

	if wasUsingMaxWalkSpeed then
		data.CustomSpeedLimit = getEffectiveMaxWalkSpeed(data)
	end

	applyWalkSpeed(player, data)
	DataService.UpdateLeaderstats(player)
	sendSnapshot(player)
end

-- HỌC TẬP: Vòng lặp chính xử lý tiến trình Speed của từng người chơi.
-- Vòng lặp này chạy độc lập cho mỗi Player bằng task.spawn.
local function runProgressionLoop(player: Player)
	local session = getSession(player)

	-- Điều kiện lặp: Trong khi Player vẫn nằm trong dịch vụ Players (tức là họ chưa thoát game).
	-- Đây là cách viết cực kỳ quan trọng để Tránh Rò Rỉ Bộ Nhớ (Memory Leak). Nếu player thoát, vòng lặp tự động dừng!
	while player.Parent == Players do
		local data = DataService.GetData(player)
		local humanoid, root = getCharacterParts(player)

		-- Chỉ cộng Speed nếu dữ liệu đã tải xong, nhân vật tồn tại và nhân vật còn sống (Health > 0).
		if data and humanoid and root and humanoid.Health > 0 then
			applyTrailVisual(player, data)

			-- 1. Kiểm tra xem người chơi có đang đứng trên Máy chạy bộ nào không
			local treadmillId, treadmillMultiplier, isOnTreadmill = getTreadmillAtPosition(root.Position)
			session.activeTreadmillId = treadmillId
			session.activeTreadmillMultiplier = treadmillMultiplier
			session.isOnTreadmill = isOnTreadmill

			-- 2. Đo đạc khoảng cách di chuyển của người chơi giữa 2 lần kiểm tra (Vector Math)
			local lastPosition = session.lastPosition
			session.lastPosition = root.Position

			-- Tính độ dài khoảng cách di chuyển (Magnitude) của vector hiệu (Vị trí mới - Vị trí cũ)
			local movedDistance = if lastPosition then (root.Position - lastPosition).Magnitude else 0
			
			-- 3. Kiểm tra xem người chơi có đang di chuyển thật sự không:
			-- humanoid.MoveDirection.Magnitude > 0.05: Người chơi đang bấm WASD hoặc cần gạt Analog điện thoại.
			-- movedDistance >= Constants.MIN_MOVEMENT_FOR_SPEED_GAIN: Người chơi có sự di chuyển thực tế (phòng trường hợp bị trượt hoặc lực đẩy vật lý).
			-- isOnTreadmill: Hoặc người chơi đang đứng trên máy chạy bộ (kể cả đứng im cũng được tính điểm).
			local isActivelyMoving = humanoid.MoveDirection.Magnitude > 0.05
				or movedDistance >= Constants.MIN_MOVEMENT_FOR_SPEED_GAIN
				or isOnTreadmill

			-- 4. Nếu đang di chuyển, tiến hành cộng Speed dựa trên hệ số nhân!
			if isActivelyMoving then
				local amount = Constants.BASE_SPEED_GAIN * getGainMultiplier(player, data)
				addSpeed(player, data, amount)
			else
				-- Nếu đứng im trên đất thường, chúng ta chỉ cập nhật lại WalkSpeed của họ (đảm bảo đồng bộ).
				applyWalkSpeed(player, data)
			end
		end

		-- Dừng vòng lặp một chút (ở đây là 0.35 giây) trước khi lặp lại.
		-- Không được bỏ task.wait() vì nếu không có nó, vòng lặp sẽ chạy hàng triệu lần mỗi giây làm treo (Crash) Server ngay lập tức!
		task.wait(Constants.SPEED_GAIN_INTERVAL)
	end
end

local function cacheTreadmillZones()
	table.clear(treadmillZones)

	local multiplierToId = {
		[1] = "treadmill_1",
		[3] = "treadmill_2",
		[9] = "treadmill_3",
		[25] = "treadmill_4",
		[100] = "treadmill_5",
	}

	for _, instance in Workspace:GetChildren() do
		local multiplierText = instance.Name:match("^Treadmill_x(%d+)$")
		if instance:IsA("Model") and multiplierText then
			local multiplier = tonumber(multiplierText)
			local treadmillId = multiplier and multiplierToId[multiplier]
			if treadmillId and multiplier then
				local cframe, size = instance:GetBoundingBox()
				table.insert(treadmillZones, {
					id = treadmillId,
					multiplier = multiplier,
					cframe = cframe,
					size = size,
				})
			end
		end
	end
end

function ProgressionService.Init()
	cacheTreadmillZones()
end

function ProgressionService.Start()
	GamePackets.requestSnapshot.listen(function(_data, player: Player)
		if isRateLimited(player, "snapshot") then
			return
		end
		sendSnapshot(player)
	end)

	GamePackets.requestCustomSpeed.listen(function(data, player: Player)
		if isRateLimited(player, "customSpeed") then
			return
		end

		local profileData = DataService.GetData(player)
		if
			not profileData
			or typeof(data.walkSpeed) ~= "number"
			or data.walkSpeed ~= data.walkSpeed
			or math.abs(data.walkSpeed) == math.huge
		then
			return
		end

		local maxWalkSpeed = getEffectiveMaxWalkSpeed(profileData)
		profileData.CustomSpeedLimit = math.clamp(
			math.floor(data.walkSpeed),
			Constants.DEFAULT_WALK_SPEED,
			maxWalkSpeed
		)
		applyWalkSpeed(player, profileData)
		sendSnapshot(player)
	end)

	GamePackets.requestRebirth.listen(function(_data, player: Player)
		if isRateLimited(player, "rebirth") then
			return
		end

		local data = DataService.GetData(player)
		if not data then
			return
		end

		local requiredLevel = Constants.GetRequiredLevelForRebirth(data.Rebirths)
		if data.Level < requiredLevel then
			return
		end

		data.Speed = 0
		data.Level = 1
		data.XP = 0
		data.Rebirths += 1
		data.CustomSpeedLimit = Constants.DEFAULT_WALK_SPEED

		applyWalkSpeed(player, data)
		DataService.UpdateLeaderstats(player)
		GamePackets.toast.sendTo({
			kind = "rebirth",
			message = "Rebirth complete",
			amount = data.Rebirths,
		}, player)
		sendSnapshot(player)
	end)

	GamePackets.requestCosmeticAction.listen(function(request, player: Player)
		if isRateLimited(player, "cosmeticAction") then
			return
		end

		local data = DataService.GetData(player)
		if not data or typeof(request.category) ~= "string" or typeof(request.itemId) ~= "string" then
			return
		end

		local config = getCosmeticConfig(request.category, request.itemId)
		if not config then
			return
		end

		local unlockedItems = if request.category == "trail" then data.UnlockedTrails else data.UnlockedAuras
		local wasUnlocked = unlockedItems[request.itemId] == true
		if not unlockedItems[request.itemId] then
			if data.TotalWins < config.priceWins then
				GamePackets.toast.sendTo({
					kind = "cosmetic",
					message = "Not enough Wins",
					amount = 0,
				}, player)
				return
			end

			data.TotalWins -= config.priceWins
			unlockedItems[request.itemId] = true
		end

		if request.category == "trail" then
			data.EquippedTrail = if data.EquippedTrail == request.itemId then "none" else request.itemId
			applyTrailVisual(player, data)
		else
			data.EquippedAura = if data.EquippedAura == request.itemId then "none" else request.itemId
		end

		DataService.UpdateLeaderstats(player)
		GamePackets.toast.sendTo({
			kind = "cosmetic",
			message = if wasUnlocked then "Equipped" else "Purchased",
			amount = 0,
		}, player)
		sendSnapshot(player)
	end)

	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			local session = getSession(player)
			session.appliedTrailId = nil
			task.delay(0.25, function()
				local data = DataService.GetData(player)
				if data then
					applyTrailVisual(player, data)
				end
			end)
		end)
	end

	for _, player in Players:GetPlayers() do
		watchCharacter(player)
		task.spawn(runProgressionLoop, player)
	end

	Players.PlayerAdded:Connect(function(player)
		watchCharacter(player)
		task.spawn(runProgressionLoop, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

function ProgressionService.AwardWins(player: Player, amount: number, reason: string?)
	local data = DataService.GetData(player)
	if not data or amount <= 0 then
		return false
	end

	data.TotalWins += amount
	data.CurrentRunWins += amount
	data.PersonalBestRunWins = math.max(data.PersonalBestRunWins, data.CurrentRunWins)
	DataService.UpdateLeaderstats(player)
	GamePackets.toast.sendTo({
		kind = reason or "wins",
		message = "Wins earned",
		amount = amount,
	}, player)
	sendSnapshot(player)
	return true
end

function ProgressionService.SendSnapshot(player: Player)
	sendSnapshot(player)
end

return ProgressionService
