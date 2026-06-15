--!strict
--[[
	Constants.luau
	Chứa toàn bộ hằng số cấu hình Game Balancing của SpeedEscape.
	Tất cả các thông số như Tốc độ, Wins, Rebirth, Trails, Auras, Gamepass, Level
	đều được định nghĩa tập trung tại đây để dễ dàng cân chỉnh.
]]

local Constants = {}

-- ============================================================================
-- 1. BẢN MẪU DỮ LIỆU NGƯỜI CHƠI (DATA TEMPLATE)
-- Định nghĩa các thuộc tính lưu trữ cho mỗi tài khoản người chơi.
-- ============================================================================
Constants.DATA_TEMPLATE = {
	Speed = 0,                             -- Điểm Speed tích lũy (số lớn, tăng khi chạy/đi trên máy chạy bộ)
	TotalWins = 0,                         -- Tổng số Wins (Cúp) người chơi đã tích lũy (dùng mua Trails/Auras)
	CurrentRunWins = 0,                    -- Số Wins tích lũy trong vòng chạy hiện tại của Stage 5
	Streak = 0,                            -- Chuỗi thắng liên tục khi tiếp đất thành công ở Stage 5
	PersonalBestDistance = 0,              -- Khoảng cách bay xa nhất từ trước đến nay (Studs)
	PersonalBestRunWins = 0,               -- Kỷ lục số Wins nhận được nhiều nhất trong 1 lần nhảy
	TotalRuns = 0,                         -- Tổng số lần thực hiện cú nhảy ở Stage 5
	TotalDonatedRobux = 0,                 -- Tổng số Robux người chơi đã quyên góp (nếu có tính năng Donate)
	Rebirths = 0,                          -- Số lần Trùng Sinh (Rebirth). Mỗi lần Trùng Sinh sẽ reset Speed/Level về 1 nhưng tăng hệ số nhân vĩnh viễn.
	Level = 1,                             -- Cấp độ hiện tại của người chơi (Level càng cao chạy càng nhanh)
	XP = 0,                                -- Điểm kinh nghiệm hiện tại (1 Speed nhận được = 1 XP)
	EquippedTreadmill = "treadmill_1",     -- ID Máy chạy bộ đang trang bị (Mặc định là Máy Gỗ)
	EquippedTrail = "none",                -- ID Vệt sáng chân đang trang bị ("none" là không trang bị)
	EquippedAura = "none",                 -- ID Hào quang đang trang bị ("none" là không trang bị)
	CustomSpeedLimit = 6,                  -- Tốc độ chạy thực tế mà người chơi tự cài đặt (không vượt quá giới hạn Level)
	UnlockedTreadmills = {                 -- Danh sách các máy chạy bộ đã mở khóa (dưới dạng bảng tra cứu nhanh key-value)
		["treadmill_1"] = true
	} :: { [string]: boolean },
	UnlockedTrails = {                     -- Danh sách Trails đã mở khóa
		["none"] = true
	} :: { [string]: boolean },
	UnlockedAuras = {                      -- Danh sách Auras đã mở khóa
		["none"] = true
	} :: { [string]: boolean },
}

-- ============================================================================
-- 2. CẤU HÌNH MÁY CHẠY BỘ (TREADMILLS / MULTIPLIER PADS)
-- ============================================================================
export type TreadmillConfig = {
	id: string,
	name: string,
	multiplier: number,      -- Hệ số nhân tốc độ của máy chạy bộ (Ví dụ: x3 nghĩa là đi 1 bước nhận 3 Speed)
	priceRobux: number,      -- Giá mua nhanh bằng Robux (0 nghĩa là miễn phí)
}

Constants.TREADMILLS = {
	{ id = "treadmill_1", name = "Wood Treadmill",      multiplier = 1.0,    priceRobux = 0 },
	{ id = "treadmill_2", name = "Gold Treadmill",      multiplier = 3.0,    priceRobux = 29 },
	{ id = "treadmill_3", name = "Green Treadmill",     multiplier = 9.0,    priceRobux = 99 },
	{ id = "treadmill_4", name = "Pink Treadmill",      multiplier = 25.0,   priceRobux = 249 },
	{ id = "treadmill_5", name = "Red Admin Treadmill", multiplier = 100.0,  priceRobux = 499 },
} :: { TreadmillConfig }

-- Các hằng số tốc độ di chuyển và thời gian
Constants.BASE_SPEED_GAIN = 1              -- Lượng Speed cơ bản nhận được mỗi bước chạy trên đất thường
Constants.DEFAULT_WALK_SPEED = 6           -- Tốc độ chạy mặc định của người chơi mới (Roblox mặc định là 16, chúng ta để 6 để tạo cảm giác chậm)
Constants.WALK_SPEED_PER_LEVEL = 2         -- Lượng WalkSpeed tăng thêm sau mỗi Level
Constants.SPEED_GAIN_INTERVAL = 0.35       -- Cứ mỗi 0.35 giây sẽ cộng Speed một lần (Loop Interval)
Constants.MIN_MOVEMENT_FOR_SPEED_GAIN = 1.5 -- Khoảng cách tối thiểu nhân vật phải di chuyển để được tính là đang chạy bộ
Constants.TREADMILL_GAIN_RADIUS = 13
Constants.STAGE_WINS = {
	[1] = 1,
	[2] = 3,
	[3] = 8,
	[4] = 15,
	[5] = 30,
	[6] = 60,
	[7] = 120,
	[8] = 250,
	[9] = 500,
	[10] = 1000,
}
Constants.FINISH_REWARD_WINS = Constants.STAGE_WINS[5]
Constants.FINISH_REWARD_COOLDOWN = 10
Constants.NETWORK_RATE_LIMIT_SECONDS = 0.4
Constants.MAX_CONFIGURED_STAGE = 8
Constants.REVIVE_PROMPT_SECONDS = 15
Constants.REVIVE_ROBUX_PRICE = 9
Constants.REVIVE_PRODUCT_ID = 0
Constants.REVIVE_AD_PLACEMENT_ID = 0

export type MultiplierPadConfig = {
	id: string,
	speedPerStep: number,
	requiredWins: number,
}

Constants.MULTIPLIER_PADS = {
	{ id = "pad_1", speedPerStep = 1, requiredWins = 0 },
	{ id = "pad_2", speedPerStep = 2, requiredWins = 5 },
	{ id = "pad_3", speedPerStep = 3, requiredWins = 20 },
	{ id = "pad_4", speedPerStep = 5, requiredWins = 80 },
	{ id = "pad_5", speedPerStep = 50, requiredWins = 500 },
	{ id = "pad_6", speedPerStep = 100, requiredWins = 2500 },
	{ id = "pad_7", speedPerStep = 250, requiredWins = 15000 },
	{ id = "pad_8", speedPerStep = 500, requiredWins = 50000 },
} :: { MultiplierPadConfig }

export type TeleportDestinationConfig = {
	id: string,
	name: string,
	description: string,
	targetPath: string,
	accentColor: Color3,
	sortOrder: number,
	priceWins: number,
	priceRobux: number,
	productId: number,
}

Constants.TELEPORT_DESTINATIONS = {
	{
		id = "lobby",
		name = "Lobby",
		description = "Spawn hub",
		targetPath = "Workspace.SpawnLocation",
		accentColor = Color3.fromRGB(59, 189, 255),
		sortOrder = 1,
		priceWins = 0,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_1",
		name = "Stage 1",
		description = "Keyboard Hop",
		targetPath = "Workspace.Zone1.Mechanics.Stage1Start",
		accentColor = Color3.fromRGB(79, 218, 102),
		sortOrder = 2,
		priceWins = 0,
		priceRobux = 0,
		productId = 0,
	},
	{
		id = "stage_2",
		name = "Stage 2",
		description = "Laser Grid",
		targetPath = "Workspace.Zone1.Ground.Transition1To2",
		accentColor = Color3.fromRGB(255, 201, 71),
		sortOrder = 3,
		priceWins = 2,
		priceRobux = 3,
		productId = 0,
	},
	{
		id = "stage_3",
		name = "Stage 3",
		description = "Clashing Crushers",
		targetPath = "Workspace.Zone2.Ground.Transition2To3",
		accentColor = Color3.fromRGB(255, 112, 81),
		sortOrder = 4,
		priceWins = 6,
		priceRobux = 5,
		productId = 0,
	},
	{
		id = "stage_4",
		name = "Stage 4",
		description = "Boss Chase",
		targetPath = "Workspace.Zone3.Ground.Transition3To4",
		accentColor = Color3.fromRGB(193, 111, 255),
		sortOrder = 5,
		priceWins = 20,
		priceRobux = 10,
		productId = 0,
	},
	{
		id = "stage_5",
		name = "Stage 5",
		description = "Conveyor Chaos",
		targetPath = "Workspace.Zone4.Ground.Transition4To5",
		accentColor = Color3.fromRGB(255, 93, 155),
		sortOrder = 6,
		priceWins = 40,
		priceRobux = 15,
		productId = 0,
	},
	{
		id = "stage_6",
		name = "Stage 6",
		description = "Shrinking Platform",
		targetPath = "Workspace.Zone5.Ground.Transition5To6",
		accentColor = Color3.fromRGB(79, 218, 202),
		sortOrder = 7,
		priceWins = 75,
		priceRobux = 20,
		productId = 0,
	},
	{
		id = "stage_7",
		name = "Stage 7",
		description = "Gravity Collapse",
		targetPath = "Workspace.Zone6.Ground.Transition6To7",
		accentColor = Color3.fromRGB(111, 153, 255),
		sortOrder = 8,
		priceWins = 120,
		priceRobux = 25,
		productId = 0,
	},
	{
		id = "stage_8",
		name = "Stage 8",
		description = "Spinning Sweeper",
		targetPath = "Workspace.Zone7.Ground.Transition7To8",
		accentColor = Color3.fromRGB(255, 82, 92),
		sortOrder = 9,
		priceWins = 250,
		priceRobux = 35,
		productId = 0,
	},
	{
		id = "training",
		name = "Training",
		description = "Treadmills",
		targetPath = "Workspace.Treadmill_x1",
		accentColor = Color3.fromRGB(255, 174, 60),
		sortOrder = 10,
		priceWins = 0,
		priceRobux = 0,
		productId = 0,
	},
} :: { TeleportDestinationConfig }

export type StreakBonusConfig = {
	streak: number,
	extraWins: number,
	label: string,
}

Constants.STREAK_BONUSES = {
	{ streak = 3, extraWins = 10, label = "3 STREAK" },
	{ streak = 5, extraWins = 50, label = "5 STREAK" },
	{ streak = 10, extraWins = 250, label = "10 STREAK" },
	{ streak = 20, extraWins = 1000, label = "20 STREAK" },
	{ streak = 50, extraWins = 10000, label = "50 STREAK" },
} :: { StreakBonusConfig }

-- ============================================================================
-- 3. CẤU HÌNH TRAILS (VỆT SÁNG)
-- ============================================================================
export type TrailConfig = {
	id: string,
	name: string,
	multiplier: number,      -- Hệ số nhân tốc độ (Trail Boost)
	priceWins: number,       -- Giá mua bằng Wins
	priceRobux: number,      -- Giá mua nhanh bằng Robux (0 là không bán bằng Robux)
}

Constants.TRAILS = {
	{ id = "trail_green",   name = "Green Trail",   multiplier = 1.5, priceWins = 500,    priceRobux = 19 },
	{ id = "trail_blue",    name = "Blue Trail",    multiplier = 2.0, priceWins = 1500,   priceRobux = 49 },
	{ id = "trail_purple",  name = "Purple Trail",  multiplier = 3.0, priceWins = 5000,   priceRobux = 99 },
	{ id = "trail_red",     name = "Red Trail",     multiplier = 4.0, priceWins = 25000,  priceRobux = 139 },
	{ id = "trail_rainbow", name = "Rainbow Trail", multiplier = 5.0, priceWins = 100000, priceRobux = 249 },
	{ id = "trail_galaxy",  name = "Galaxy Trail",  multiplier = 10.0, priceWins = 500000, priceRobux = 389 },
} :: { TrailConfig }

-- ============================================================================
-- 4. CẤU HÌNH AURAS (HÀO QUANG)
-- ============================================================================
export type AuraConfig = {
	id: string,
	name: string,
	multiplier: number,      -- Hệ số nhân tốc độ (Aura Boost)
	priceWins: number,       -- Giá mua bằng Wins
}

Constants.AURAS = {
	{ id = "aura_sparkle",   name = "Sparkle Aura",   multiplier = 1.2, priceWins = 200 },
	{ id = "aura_fire",      name = "Fire Aura",      multiplier = 1.8, priceWins = 2000 },
	{ id = "aura_lightning", name = "Lightning Aura", multiplier = 2.5, priceWins = 8000 },
	{ id = "aura_void",      name = "Void Aura",      multiplier = 4.5, priceWins = 40000 },
	{ id = "aura_cosmic",    name = "Cosmic Aura",    multiplier = 8.0, priceWins = 200000 },
} :: { AuraConfig }

-- ============================================================================
-- 5. CẤU HÌNH GAMEPASS (NHÂN HỆ SỐ BẰNG ROBUX - GIÁ SIÊU RẺ CHO VN)
-- ============================================================================
-- Thay thế các ID dưới đây bằng ID Gamepass thật của game trên Roblox Creator Dashboard
Constants.GAMEPASS_IDS = {
	DoubleSpeed = 0,         -- Gamepass x2 Speed (Giá: 3 Robux) - Nhân vĩnh viễn x2 Speed nhận được
	QuadSpeed = 0,           -- Gamepass x4 Speed (Giá: 9 Robux) - Nhân vĩnh viễn x4 Speed nhận được
	OctaSpeed = 0,           -- Gamepass x8 Speed (Giá: 19 Robux) - Nhân vĩnh viễn x8 Speed nhận được
}

-- ============================================================================
-- 6. CÁC HÀM CÔNG THỨC TOÁN HỌC CÂN BẰNG TIẾN TRÌNH (FORMULAS)
-- ============================================================================

-- Tỉ lệ quy đổi từ lượng Speed nhận được sang lượng XP tương ứng
Constants.XP_CONVERSION_RATE = 1 -- 1 Speed = 1 XP
Constants.XP_CURVE_ANCHOR_LEVEL = 67
Constants.XP_CURVE_ANCHOR_REQUIRED_SPEED = 1010000
Constants.XP_CURVE_NEXT_REQUIRED_SPEED = 1170000
Constants.XP_CURVE_GROWTH_RATE = Constants.XP_CURVE_NEXT_REQUIRED_SPEED / Constants.XP_CURVE_ANCHOR_REQUIRED_SPEED

-- Tính số XP cần thiết để thăng lên cấp độ tiếp theo (Required XP)
-- Neo theo game mẫu: Level 67 cần 1.01M và Level 68 cần 1.17M.
function Constants.GetRequiredXP(level: number): number
	if level <= 0 then return 0 end
	return math.floor(
		Constants.XP_CURVE_ANCHOR_REQUIRED_SPEED
			* math.pow(Constants.XP_CURVE_GROWTH_RATE, level - Constants.XP_CURVE_ANCHOR_LEVEL)
			+ 0.5
	)
end

-- Tính tốc độ di chuyển tối đa thực tế (Max WalkSpeed) dựa trên Level hiện tại
-- Công thức: Max WalkSpeed = 6 + ((Level - 1) * 2)
function Constants.GetMaxWalkSpeed(level: number): number
	return Constants.DEFAULT_WALK_SPEED + (math.max(level - 1, 0) * Constants.WALK_SPEED_PER_LEVEL)
end

-- Tính lượng XP thưởng khi người chơi thăng cấp
function Constants.GetLevelUpWinsReward(level: number): number
	return level * 10
end

-- Tính số Level tối thiểu cần thiết để thực hiện Rebirth lần tiếp theo
-- Neo theo UI mẫu: Rebirths = 5, multiplier x3.5 -> x4.0, cần Level 100.
-- Công thức: Yêu cầu Level = 50 + Rebirths * 10
function Constants.GetRequiredLevelForRebirth(currentRebirths: number): number
	return 50 + (currentRebirths * 10)
end

-- Tính hệ số nhân Rebirth vĩnh viễn (Rebirth Multiplier)
-- Công thức: Rebirth Multiplier = 1 + Rebirths * 0.5
function Constants.GetRebirthMultiplier(rebirths: number): number
	return 1 + (rebirths * 0.5)
end

function Constants.GetTreadmillById(treadmillId: string): TreadmillConfig?
	for _, config in Constants.TREADMILLS do
		if config.id == treadmillId then
			return config
		end
	end

	return nil
end

function Constants.GetTrailMultiplier(trailId: string): number
	if trailId == "none" then
		return 1
	end

	for _, config in Constants.TRAILS do
		if config.id == trailId then
			return config.multiplier
		end
	end

	return 1
end

function Constants.GetAuraMultiplier(auraId: string): number
	if auraId == "none" then
		return 1
	end

	for _, config in Constants.AURAS do
		if config.id == auraId then
			return config.multiplier
		end
	end

	return 1
end

function Constants.GetStreakBonus(streak: number): StreakBonusConfig?
	local bestBonus = nil
	for _, bonus in Constants.STREAK_BONUSES do
		if streak >= bonus.streak then
			bestBonus = bonus
		end
	end

	return bestBonus
end

-- ============================================================================
-- 7. HÀM ĐỊNH DẠNG SỐ LỚN ĐỂ RENDER UI (FORMAT NUMBER)
-- ============================================================================
-- Hàm chuyển đổi số nguyên thô (ví dụ: 1254300) thành chuỗi rút gọn gọn gàng (ví dụ: 1.25M)
function Constants.FormatNumber(value: number): string
	if value < 1000 then
		return tostring(math.floor(value))
	elseif value < 1000000 then
		return string.format("%.2fK", value / 1000)
	elseif value < 1000000000 then
		return string.format("%.2fM", value / 1000000)
	elseif value < 1000000000000 then
		return string.format("%.2fB", value / 1000000000)
	else
		return string.format("%.2fT", value / 1000000000000)
	end
end

return Constants
