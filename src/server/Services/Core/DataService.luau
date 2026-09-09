--!strict
-- Server: nạp và migrate profile bằng ProfileStore, rồi cung cấp dữ liệu cho các service.
-- Leaderstats phản ánh profile; lần lưu cuối đóng dấu offline trước khi phiên kết thúc.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Env = require(ReplicatedStorage.Shared.Util.Env)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

type PlayerData = typeof(Constants.DATA_TEMPLATE)
type Profile = any

local DATA_STORE_NAME = Env.StoreName("SpeedEscape_Player_v1")

--[[
	HỒ SƠ TEST TRONG STUDIO — CÔNG TẮC
	==================================
	Studio dùng `playerStore.Mock` nên KHÔNG lưu gì cả, và mỗi lần Play là hồ sơ được bơm
	lại từ đầu theo hằng số dưới đây. Nghĩa là "xoá dữ liệu test" trong Studio là việc vô
	nghĩa: phiên sau nó tự mọc lại. Muốn đổi thì phải đổi ở ĐÂY.

	`STUDIO_FRESH_PLAYER = true`  → vào Studio là một NGƯỜI CHƠI MỚI TINH (0 Wins, Level 1).
	                                Dùng khi test FTUE: Daily ngày 1, tutorial 3 bước, mở
	                                khoá Pad 2, cảm giác tốc độ 60 giây đầu.
	`STUDIO_FRESH_PLAYER = false` → bơm 1M Wins / 500K Speed / Level 120. Dùng khi test
	                                nội dung cuối game: Stage 12-15, Rebirth, trail đắt.

	⚠️ Preset cũ (1M Wins) chính là thứ làm tutorial không bao giờ hiện trong Studio:
	`TutorialService` thấy `TotalWins > 0` là đánh dấu "người chơi cũ" và im lặng.
]]
local STUDIO_FRESH_PLAYER = true
local STUDIO_TEST_TOTAL_WINS = 1_000_000
local STUDIO_TEST_SPEED = 500_000
local STUDIO_TEST_LEVEL = 120

local playerStore = ProfileStore.New(DATA_STORE_NAME, Constants.DATA_TEMPLATE)
if RunService:IsStudio() then
	playerStore = playerStore.Mock
end

local profiles: { [Player]: Profile } = {}
local leaderstatsByPlayer: { [Player]: Folder } = {}

local DataService = {}

local function createValue(parent: Instance, className: string, name: string, value: any): Instance
	local instance = Instance.new(className)
	instance.Name = name;
	(instance :: any).Value = value
	instance.Parent = parent
	return instance
end

local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	createValue(leaderstats, "NumberValue", "Speed", 0)
	createValue(leaderstats, "NumberValue", "Wins", 0)
	createValue(leaderstats, "IntValue", "Level", 1)
	createValue(leaderstats, "IntValue", "Rebirths", 0)

	leaderstatsByPlayer[player] = leaderstats
end

local function readNumber(data: { [string]: any }, key: string, fallback: number): number
	local value = data[key]
	if typeof(value) == "number" and value == value then
		return value
	end
	data[key] = fallback
	return fallback
end

--[[
	Ngưỡng `requiredWins` của Multiplier Pad TRƯỚC 2026-09-06, khi pad còn là ngưỡng số dư ví.
	Chỉ dùng cho migration CORE_LOOP_VERSION 4 → 5: cấp miễn phí và vĩnh viễn mọi pad mà người
	chơi ĐANG dùng được, để không ai mất pad lúc chuyển sang mô hình mua đứt.

	⚠️ Đây là ảnh chụp lịch sử — KHÔNG đồng bộ với `Economy/MultiplierPads` nữa. Đừng "sửa cho
	khớp": khớp lại là migration cấp sai mức và người chơi cũ mất pad.
]]
local LEGACY_PAD_THRESHOLDS: { number } = { 0, 1, 15, 100, 500, 2500, 15000, 50000 }

-- Chốt an toàn cho vòng leo level của migration 4 → 5. Cao hơn hẳn trần thiết kế
-- (World 2 kết thúc ở Level 220) nên không tài khoản thật nào chạm tới.
local MIGRATION_LEVEL_CEILING = 1000

local function normalizeData(data: { [string]: any })
	readNumber(data, "Speed", 0)
	readNumber(data, "TotalWins", 0)
	readNumber(data, "CurrentRunWins", 0)
	readNumber(data, "Streak", 0)
	readNumber(data, "PersonalBestRunWins", 0)
	readNumber(data, "TotalDonatedRobux", 0)
	if typeof(data.hasClaimedGroupReward) ~= "boolean" then
		data.hasClaimedGroupReward = false
	end
	-- `profile:Reconcile()` đã điền khoá thiếu từ DataTemplate; guard này chỉ bắt trường hợp
	-- giá trị tồn tại nhưng SAI KIỂU, giống các boolean khác trong hàm này.
	if typeof(data.WelcomeSpinGranted) ~= "boolean" then
		data.WelcomeSpinGranted = false
	end
	--[[
		Starter Pack: mốc bắt đầu đếm 48h. Ghi ở đây (lúc nạp profile) chứ không phải lúc tạo
		profile mới, nên tài khoản CŨ — có từ trước khi gói này ra đời — cũng được tính giờ từ
		lần đăng nhập đầu tiên sau bản cập nhật. Họ chưa từng thấy gói, cắt luôn cửa sổ của họ
		là vừa mất doanh thu vừa vô lý.
	]]
	if typeof(data.FirstJoinTime) ~= "number" or data.FirstJoinTime <= 0 then
		data.FirstJoinTime = os.time()
	end
	if typeof(data.StarterPackBought) ~= "boolean" then
		data.StarterPackBought = false
	end

	local coreLoopVersion = readNumber(data, "CoreLoopVersion", 0)
	readNumber(data, "HighestCompletedStage", 0)
	readNumber(data, "Rebirths", 0)
	local level = readNumber(data, "Level", 1)
	readNumber(data, "XP", 0)
	--[[
		── CUSTOM SPEED RESET VỀ KỊCH TRẦN MỖI LẦN VÀO GAME (2026-08-27, yêu cầu user) ──────
		"Player thoát ra vào lại thì hệ thống tự động chỉnh speed cao nhất, để level lên thì
		speed tăng theo. Còn player tự chỉnh trong game thì giữ nguyên cho họ."

		Hai vế đó là HAI CHẾ ĐỘ, và chế độ được suy ra từ chính giá trị chứ không cần cờ riêng:
		  • `CustomSpeedLimit == trần`  ⇒ chế độ TỰ BÁM. `ProgressionService.addSpeed` thấy
		    `wasAtMax` nên mỗi lần lên level lại kéo lên trần mới.
		  • `CustomSpeedLimit <  trần`  ⇒ người chơi đã TỰ CHỌN. `wasAtMax` false ⇒ level lên
		    bao nhiêu cũng không đụng tới con số của họ.

		Vì vậy chỉ cần một việc ở đây: **luôn ghi đè về trần lúc nạp profile**, thay vì đọc lại
		giá trị đã lưu. Giá trị người chơi tự chỉnh do đó chỉ sống trong PHIÊN — đúng câu
		"trừ thoát game vào lại".

		⚠️ `CustomSpeedLimit` vẫn nằm trong DataTemplate và vẫn được ProfileStore lưu. KHÔNG gỡ:
		gỡ một field khỏi template là một lần migration cho toàn bộ profile hiện có, đổi lấy
		vài byte. Nó chỉ đơn giản là không còn được đọc lên nữa.
	]]
	data.CustomSpeedLimit = Constants.GetMaxWalkSpeed(level)

	if typeof(data.EquippedTreadmill) ~= "string" then
		data.EquippedTreadmill = "treadmill_1"
	end
	if typeof(data.EquippedTrail) ~= "string" then
		data.EquippedTrail = "none"
	end
	if typeof(data.EquippedAura) ~= "string" then
		data.EquippedAura = "none"
	end
	if typeof(data.UnlockedTreadmills) ~= "table" then
		data.UnlockedTreadmills = { treadmill_1 = true }
	end
	if typeof(data.UnlockedTrails) ~= "table" then
		data.UnlockedTrails = { none = true }
	end
	if typeof(data.UnlockedAuras) ~= "table" then
		data.UnlockedAuras = { none = true }
	end
	if typeof(data.UnlockedEmotes) ~= "table" then
		data.UnlockedEmotes = {}
	end
	local questIndex = readNumber(data, "QuestIndex", 0)
	data.QuestIndex = math.max(0, math.floor(questIndex))
	local questProgress = readNumber(data, "QuestProgress", 0)
	data.QuestProgress = math.max(0, questProgress)
	data.DailyQuestSeed = math.max(0, math.floor(readNumber(data, "DailyQuestSeed", 0)))
	if typeof(data.DailyQuestProgress) ~= "table" then
		data.DailyQuestProgress = { 0, 0, 0 }
	end
	if typeof(data.DailyQuestClaimedAt) ~= "table" then
		data.DailyQuestClaimedAt = { 0, 0, 0 }
	end
	for index = 1, 3 do
		data.DailyQuestProgress[index] = math.max(0, tonumber(data.DailyQuestProgress[index]) or 0)
		data.DailyQuestClaimedAt[index] = math.max(0, math.floor(tonumber(data.DailyQuestClaimedAt[index]) or 0))
	end
	data.DailyQuestRewardWins = math.max(0, readNumber(data, "DailyQuestRewardWins", 0))
	data.DailyQuestRewardSpeed = math.max(0, readNumber(data, "DailyQuestRewardSpeed", 0))

	--[[
		Pad đã sở hữu. Chỉ TĂNG, không bao giờ giảm — xem `Economy/MultiplierPads`.
	]]
	data.HighestPadIndex = math.clamp(math.floor(readNumber(data, "HighestPadIndex", 1)), 1, #Constants.MULTIPLIER_PADS)
	data.LifetimeStreak = math.max(0, math.floor(readNumber(data, "LifetimeStreak", 0)))

	--[[
		══ MIGRATION CORE_LOOP_VERSION 4 → 5 (2026-09-06, GDD 3.0) ═══════════════════════════

		Hai việc, cả hai đều CHỈ ĐƯỢC NỚI — không tài khoản nào được tụt sau khi chạy.

		1. PAD: cấp miễn phí và vĩnh viễn mọi pad mà `TotalWins` hiện tại đủ theo bảng NGƯỠNG CŨ.
		   Trước bản này pad là ngưỡng số dư ví, nên người có 50.000 Wins ĐANG dùng được Pad 8.
		   Không cấp bù là cướp pad của họ ngay lúc chuyển sang mô hình mua đứt.

		2. ĐƯỜNG CONG XP: tính lại Level/XP từ tổng Speed đã tích luỹ trong chu kỳ trùng sinh
		   hiện tại. `data.Speed` chính là tổng XP đã kiếm kể từ lần trùng sinh gần nhất —
		   `ProgressionService.addSpeed` cộng cùng lượng vào cả hai, và trùng sinh reset cả hai
		   về 0. Đường cong mới rẻ hơn đường cũ ở MỌI level trong tầm chơi được, nên phép tính
		   lại này chỉ có thể đẩy Level LÊN.

		⚠️ Phải kẹp lại `CustomSpeedLimit` SAU khi tính lại Level, nếu không người chơi vừa lên
		level nhưng vẫn bị kẹp theo trần cũ.
	]]
	if coreLoopVersion < 5 then
		local totalWins = readNumber(data, "TotalWins", 0)
		local grantedPad = 1
		for index, threshold in LEGACY_PAD_THRESHOLDS do
			if totalWins >= threshold then
				grantedPad = index
			else
				break
			end
		end
		if grantedPad > data.HighestPadIndex then
			data.HighestPadIndex = grantedPad
		end

		--[[
			Leo cộng dồn MỘT LẦN thay vì gọi `GetCumulativeXP` trong vòng lặp — hàm đó tự leo
			từ level 1 nên viết kiểu ngây thơ là O(n²) ngay trên đường nạp profile.

			⚠️ `MIGRATION_LEVEL_CEILING` là chốt an toàn, không phải trần thiết kế. `Speed`
			đọc từ profile có thể là `inf`/NaN (hỏng dữ liệu, hoặc bản cũ ghi lỗi); thiếu chốt
			này thì `while` không bao giờ thoát và người chơi đó treo vĩnh viễn ở màn nạp.
		]]
		local accumulated = math.max(0, readNumber(data, "Speed", 0))
		local newLevel = 1
		local cumulative = 0
		while newLevel < MIGRATION_LEVEL_CEILING do
			local nextCumulative = cumulative + Constants.GetRequiredXP(newLevel)
			if nextCumulative > accumulated then
				break
			end
			cumulative = nextCumulative
			newLevel += 1
		end
		if newLevel > data.Level then
			data.Level = newLevel
		end
		data.XP = math.max(0, accumulated - Constants.GetCumulativeXP(data.Level))
		data.CustomSpeedLimit = Constants.GetMaxWalkSpeed(data.Level)
	end

	if coreLoopVersion < Constants.CORE_LOOP_VERSION then
		data.CoreLoopVersion = Constants.CORE_LOOP_VERSION
	end

	if RunService:IsStudio() and not STUDIO_FRESH_PLAYER then
		data.TotalWins = math.max(data.TotalWins, STUDIO_TEST_TOTAL_WINS)
		data.Speed = STUDIO_TEST_SPEED
		data.Level = STUDIO_TEST_LEVEL
		data.XP = 0
		data.CustomSpeedLimit = Constants.GetMaxWalkSpeed(STUDIO_TEST_LEVEL)
		data.UnlockedTreadmills = { treadmill_1 = true }
		data.UnlockedTrails = { none = true }
		data.UnlockedAuras = { none = true }
		data.EquippedTreadmill = "treadmill_1"
		data.EquippedTrail = "none"
		data.EquippedAura = "none"
	end
end

local function updateLeaderstats(player: Player, data: PlayerData)
	local leaderstats = leaderstatsByPlayer[player]
	if not leaderstats then
		return
	end

	local speed = leaderstats:FindFirstChild("Speed") :: NumberValue?
	local wins = leaderstats:FindFirstChild("Wins") :: NumberValue?
	local level = leaderstats:FindFirstChild("Level") :: IntValue?
	local rebirths = leaderstats:FindFirstChild("Rebirths") :: IntValue?

	if speed then
		speed.Value = math.floor(data.Speed)
	end
	if wins then
		wins.Value = math.floor(data.TotalWins)
	end
	if level then
		level.Value = math.floor(data.Level)
	end
	if rebirths then
		rebirths.Value = math.floor(data.Rebirths)
	end
end

local function loadPlayer(player: Player)
	createLeaderstats(player)

	local profile = playerStore:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if not profile then
		player:Kick("Could not load your data. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	normalizeData(profile.Data)

	local profileJanitor = Janitor.new()
	-- PlayerRemoving và BindToClose có thể chạy sau callback đóng phiên của ProfileStore.
	-- OnLastSave chạy trước lần ghi cuối cho cả EndSession và shutdown; callback này không yield.
	profileJanitor:Add(
		profile.OnLastSave:Connect(function()
			profile.Data.LastOnlineTime = os.time()
		end),
		"Disconnect"
	)
	profileJanitor:Add(
		profile.OnSessionEnd:Connect(function()
			profileJanitor:Sweep()
			profiles[player] = nil
			player:Kick("Your data session ended. Please rejoin.")
		end),
		"Disconnect"
	)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	updateLeaderstats(player, profile.Data)
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("HighestCompletedStage", math.floor(readNumber(profile.Data, "HighestCompletedStage", 0)))
	-- Chấm đỏ "vừa trúng aura Legendary" sống qua lần thoát game — xem `RouletteService`.
	player:SetAttribute("UnseenAuraUnlock", profile.Data.UnseenAuraUnlock == true)
end

--[[
	[Studio-only test hook] TRẢ NGƯỜI CHƠI VỀ TÀI KHOẢN MỚI TINH.

	Đặt attribute `StudioResetData` = 1 lên Player ⇒ ghi đè toàn bộ profile bằng
	`Constants.DATA_TEMPLATE`, rồi đá ra để lần vào lại là một người chơi hoàn toàn mới —
	Speed 0, 0 Wins, chưa cosmetic, và tutorial chạy lại từ bước 1.

	── VÌ SAO ĐÁ RA THAY VÌ ĐỒNG BỘ LẠI TẠI CHỖ ──────────────────────────────────────────────
	Trạng thái người chơi nằm rải ở rất nhiều nơi: leaderstats, chừng chục attribute, snapshot
	client, bộ đếm của TutorialService, cache cosmetic ở client… Ghép tay từng chỗ là chắc chắn
	sót một cái, và cái sót đó lại trông y như một con bug thật lúc nghiệm thu. Nạp lại profile
	từ đầu là đường đi mà game vốn đã chạy đúng mỗi ngày.

	⚠️ Studio-only, và có `RunService:IsStudio()` chặn: hook này XOÁ SẠCH dữ liệu, không có
	đường hoàn lại. Tuyệt đối không được để nó sống ở bản Live.
]]
local function watchResetHook(player: Player)
	player:GetAttributeChangedSignal("StudioResetData"):Connect(function()
		if not player:GetAttribute("StudioResetData") then
			return
		end
		player:SetAttribute("StudioResetData", nil)

		local profile = profiles[player]
		if not profile or not profile:IsActive() then
			return
		end

		-- Ghi đè TỪNG KHOÁ chứ không gán bảng mới: `profile.Data` là bảng ProfileStore đang theo
		-- dõi để lưu; thay tham chiếu là nó lưu tiếp bảng cũ.
		for key in profile.Data do
			profile.Data[key] = nil
		end
		for key, value in Constants.DATA_TEMPLATE :: { [string]: any } do
			profile.Data[key] = if typeof(value) == "table" then table.clone(value) else value
		end

		profile:Save()
		warn(
			`[DataService] ĐÃ RESET dữ liệu của {player.Name} về mặc định — đá ra để nạp lại.`
		)
		player:Kick("Dữ liệu đã reset về mặc định. Vào lại game để chơi như người mới.")
	end)
end

function DataService.Init() end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)

	if RunService:IsStudio() then
		for _, player in Players:GetPlayers() do
			watchResetHook(player)
		end
		Players.PlayerAdded:Connect(watchResetHook)
	end

	Players.PlayerRemoving:Connect(function(player)
		player:SetAttribute("ProfileLoaded", false)
		leaderstatsByPlayer[player] = nil

		local profile = profiles[player]
		if profile then
			profiles[player] = nil
			profile:EndSession()
		end
	end)
end

function DataService.GetData(player: Player): PlayerData?
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return nil
	end
	return profile.Data
end

function DataService.IsLoaded(player: Player): boolean
	return DataService.GetData(player) ~= nil
end

function DataService.UpdateLeaderstats(player: Player)
	local data = DataService.GetData(player)
	if data then
		updateLeaderstats(player, data)
	end
end

return DataService
