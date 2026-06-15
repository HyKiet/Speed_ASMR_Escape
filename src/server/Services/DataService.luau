--!strict -- Bật chế độ kiểm tra kiểu dữ liệu của Luau.

-- game:GetService() là cách tốt nhất và an toàn nhất để lấy các dịch vụ hệ thống của Roblox.
local Players = game:GetService("Players") -- Quản lý tất cả người chơi trong game.
local RunService = game:GetService("RunService") -- Giúp kiểm tra xem game đang chạy trên Studio hay server thật.
local ServerScriptService = game:GetService("ServerScriptService") -- Thư mục chứa các script bảo mật chạy trên server.

-- Nạp cấu hình Constants dùng chung và thư viện ProfileStore để lưu trữ dữ liệu an toàn.
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

-- Định nghĩa kiểu dữ liệu (Luau Types) cho dễ lập trình và tránh nhầm lẫn biến.
type PlayerData = typeof(Constants.DATA_TEMPLATE)
type Profile = any

-- Tên cơ sở dữ liệu trên máy chủ Roblox. Nếu đổi tên này, toàn bộ người chơi sẽ chơi lại từ đầu (Reset Data).
local DATA_STORE_NAME = "SpeedEscape_Player_v1"
local STUDIO_TEST_TOTAL_WINS = 1000000
local STUDIO_TEST_SPEED = 150
local STUDIO_TEST_LEVEL = 73

-- Tạo một cửa hàng dữ liệu (Store) dựa trên cấu trúc DATA_TEMPLATE mặc định.
local playerStore = ProfileStore.New(DATA_STORE_NAME, Constants.DATA_TEMPLATE)

-- HỌC TẬP: Nếu đang chạy test trong Roblox Studio (RunService:IsStudio() == true),
-- chúng ta sẽ chuyển sang chế độ "Mock" (chạy trên bộ nhớ tạm RAM).
-- Điều này giúp kiểm thử dữ liệu nhanh hơn, không tốn tài nguyên mạng và không sợ làm hỏng dữ liệu thật của người chơi.
if RunService:IsStudio() then
	playerStore = playerStore.Mock
end

-- Bảng lưu trữ phiên dữ liệu đang hoạt động của mỗi người chơi.
local profiles: { [Player]: Profile } = {}
-- Bảng lưu trữ thư mục leaderstats để cập nhật điểm nhanh chóng.
local leaderstatsByPlayer: { [Player]: Folder } = {}

local DataService = {}

-- Hàm phụ trợ: Tạo nhanh một đối tượng Value (ví dụ IntValue, NumberValue) để hiển thị điểm lên bảng.
local function createValue(parent: Instance, className: string, name: string, value: any): Instance
	local instance = Instance.new(className)
	instance.Name = name
	local valueObject = instance :: any
	valueObject.Value = value
	instance.Parent = parent
	return instance
end

-- HỌC TẬP: Tạo thư mục "leaderstats" bên trong đối tượng Player.
-- Roblox có cơ chế mặc định: Bất kỳ thư mục nào tên đúng là "leaderstats" (chữ thường) 
-- chứa các đối tượng Value bên trong sẽ tự động được vẽ thành bảng xếp hạng ở góc trên bên phải màn hình game!
local function createLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Tạo 4 cột điểm hiển thị trên bảng: Speed, Wins, Level và Rebirths.
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

local function normalizeData(data: { [string]: any })
	readNumber(data, "Speed", 0)
	readNumber(data, "TotalWins", 0)
	readNumber(data, "CurrentRunWins", 0)
	readNumber(data, "Streak", 0)
	readNumber(data, "PersonalBestDistance", 0)
	readNumber(data, "PersonalBestRunWins", 0)
	readNumber(data, "TotalRuns", 0)
	readNumber(data, "TotalDonatedRobux", 0)
	readNumber(data, "HighestCompletedStage", 0)
	readNumber(data, "Rebirths", 0)
	readNumber(data, "Level", 1)
	readNumber(data, "XP", 0)
	readNumber(data, "CustomSpeedLimit", Constants.DEFAULT_WALK_SPEED)

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

	if RunService:IsStudio() then
		data.TotalWins = math.max(data.TotalWins, STUDIO_TEST_TOTAL_WINS)
		data.Speed = STUDIO_TEST_SPEED
		data.Level = STUDIO_TEST_LEVEL
		data.CustomSpeedLimit = Constants.GetMaxWalkSpeed(STUDIO_TEST_LEVEL)
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

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your data session ended. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	updateLeaderstats(player, profile.Data)
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("HighestCompletedStage", math.floor(readNumber(profile.Data, "HighestCompletedStage", 0)))
end

function DataService.Init() end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)

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
