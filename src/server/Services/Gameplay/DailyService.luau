--!strict
-- Server dùng ngày UTC trong DataService để chốt mỗi lượt điểm danh, rồi gọi các service cấp quà.
-- ByteNet gửi trạng thái về DailyModal; bỏ lỡ một ngày thì bắt đầu lại chuỗi bảy ngày.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local NetRateLimit = require(ReplicatedStorage.Shared.Util.NetRateLimit)
local ServiceLocator = require(ReplicatedStorage.Shared.Util.ServiceLocator)

local DailyService = {}

--[[
	PHẦN THƯỞNG ĐIỂM DANH 7 NGÀY — cân bằng lại 2026-08-10
	======================================================

	Bản cũ phát 14.300 Wins trong 7 ngày, riêng NGÀY 1 đã là 300 Wins. Đối chiếu với thang
	giá thật của game thì đó là tự phá vòng lặp của chính mình:

	    Multiplier Pad:  pad_2 = 3 Wins · pad_3 = 15 · pad_4 = 100 · pad_5 = 500
	    Trail:           Green = 500 Wins · Blue = 1.500 · Purple = 5.000

	Nghĩa là người chơi mới bấm CLAIM một cái là nhảy thẳng qua pad_2/3/4 — bỏ qua trọn vẹn
	đoạn chơi mà toàn bộ phần đầu game được thiết kế để dạy, và mất luôn cảm giác "kiếm
	được" ở mỗi lần mở khoá. Ngày 3 thêm 1.000 Wins là mua đứt Blue Trail. Quà quá tay ở
	ngày đầu không giữ chân ai; nó chỉ làm phần còn lại của game trở nên vô nghĩa.

	Bảng mới đảo trục: **Wins ít lại, Speed thành xương sống, và Ngày 7 là một món KHÔNG
	MUA ĐƯỢC.**

	• Trục Speed (ngày 2/4/6) leo 5K → 25K → 150K. Speed cộng thẳng vào XP nên nó biến
	  thành Level, tức WalkSpeed — thứ người chơi CẢM NHẬN được ngay dưới chân, và cũng là
	  thứ không thể dùng để mua vượt cấp bất cứ gì.
	• Trục Wins (ngày 1/3/5/7) tổng 1.177 Wins cho cả tuần — vừa đủ để cảm thấy tiến lên,
	  không đủ để nhảy cóc. Ngày 1 đúng **2 Wins**: những Win ĐẦU TIÊN trong đời người chơi,
	  đi kèm 1.000 Speed để họ thấy nhân vật mình chạy nhanh hẳn lên ngay phút đầu.
	• Ngày 7: **Streak Aurora** — trail độc quyền, không bán bằng Wins lẫn Robux. Đây mới là
	  thứ kéo người ta quay lại đủ bảy hôm; số Wins/Spin đi kèm chỉ là phần thêm.

	Chuỗi vẫn HARDCORE: lỡ một ngày là về lại Ngày 1. Có món độc quyền ở cuối thì luật khắc
	nghiệt đó mới có sức nặng.

	⚠️ Sửa bảng này thì PHẢI sửa `REWARD_CONFIGS` trong `client/.../Modals/DailyModal.luau`
	— lệch nhau là người chơi thấy một đằng nhận một nẻo.
]]
type DailyReward = {
	wins: number?,
	speed: number?,
	spin: number?,
	boostSpeed: number?,
	boostWins: number?,
	megaServerBoost: boolean?,
	trail: string?,
}

local DAILY_REWARDS: { DailyReward } = {
	-- Ngày 1 cố tình NGHÈO Wins: người chơi mới không được nhảy cóc qua đoạn đầu game. Toàn bộ
	-- Wins đáng kể của chuỗi nằm ở Ngày 5 và Ngày 7, tức phải đi gần trọn chuỗi mới chạm tới.
	{ wins = 5, speed = 2_000 },
	{ speed = 10_000, boostSpeed = 900 },
	{ wins = 150, spin = 1 },
	{ speed = 60_000, boostWins = 900 },
	{ wins = 1_200, spin = 2 },
	{ speed = 400_000, megaServerBoost = true },
	{ wins = 12_000, spin = 3, trail = "trail_streak_aurora" },
}

--[[
	NGÀY 7 TỪ VÒNG 2 TRỞ ĐI (GDD 3.0 §7.4).

	Chuỗi lặp vô hạn: hết Ngày 7 thì hôm sau quay lại Ngày 1. Nhưng Streak Aurora Trail chỉ có
	MỘT cái — từ vòng 2 người chơi đã sở hữu nó, nên nếu vẫn phát trail thì phần thưởng đỉnh của
	cả tuần biến thành một lệnh không làm gì, và người đi trọn 14 ngày nhận ít giá trị hơn người
	đi trọn 7 ngày.

	Gói bù dùng lại đúng nguyên tắc "% mục tiêu hiện tại" của Daily Quest (§7.3) nên nó không bao
	giờ lỗi thời, dù người chơi đang ở R2 hay R20.
]]
local REPEAT_DAY7_FEE_SHARE = 0.20 -- % phí Wins trùng sinh kế tiếp
local REPEAT_DAY7_CLIMB_SHARE = 0.15 -- % quãng đường trùng sinh kế tiếp
local REPEAT_DAY7_MIN_WINS = 12_000 -- không bao giờ tệ hơn Ngày 7 vòng 1

local SECONDS_PER_DAY = 86400

local DataService: any
local ProgressionService: any

local function todayNumber(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

-- Trả về: streakDayHiệnTại, canClaim, nextDay(1..7)
local function computeState(data: any): (number, boolean, number)
	local last = tonumber(data.DailyLastClaimDay) or 0
	local streak = tonumber(data.DailyStreakDay) or 0

	if last == 0 then
		return 0, true, 1
	end

	local diff = todayNumber() - last
	if diff <= 0 then
		-- Đã nhận hôm nay rồi
		return streak, false, math.clamp(streak + 1, 1, 7)
	elseif diff == 1 then
		-- Ngày kế tiếp liên tục
		local nextDay = if streak >= 7 then 1 else streak + 1
		return streak, true, nextDay
	else
		-- Bỏ lỡ → reset
		return 0, true, 1
	end
end

local function sendState(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	local streak, canClaim, nextDay = computeState(data)
	-- Khi chuẩn bị mở chuỗi mới (nextDay == 1) thì hiển thị 0 ngày đã nhận.
	local displayStreak = streak
	if canClaim and nextDay == 1 then
		displayStreak = 0
	end

	GamePackets.dailyState.sendTo({
		streakDay = math.clamp(displayStreak, 0, 7),
		canClaim = canClaim,
		nextDay = math.clamp(nextDay, 1, 7),
	}, player)
end

local function grantReward(player: Player, day: number)
	local reward = DAILY_REWARDS[day]
	if not reward then
		return
	end

	if reward.wins and reward.wins > 0 then
		ProgressionService.AwardWins(player, reward.wins, "daily")
	end

	if reward.speed and reward.speed > 0 then
		ProgressionService.GrantSpeed(player, reward.speed)
	end

	if reward.spin and reward.spin > 0 then
		local rouletteService = ServiceLocator.Find("RouletteService")
		if rouletteService then
			rouletteService.GrantTickets(player, reward.spin, true)
		end
	end

	local serverBoostService = ServiceLocator.Find("ServerBoostService")
	if reward.boostSpeed and serverBoostService then
		serverBoostService.ActivatePersonalBoost(player, "speed", reward.boostSpeed)
	end

	if reward.boostWins and serverBoostService then
		serverBoostService.ActivatePersonalBoost(player, "wins", reward.boostWins)
	end

	if reward.megaServerBoost and serverBoostService then
		serverBoostService.ActivateServerBoost(player, "both", 900)
	end

	--[[
		Trail độc quyền Ngày 7. `equip = true`: mặc luôn cho người chơi — phần thưởng của bảy
		ngày kiên trì phải HIỆN RA sau lưng họ ngay, không bắt đi tìm trong menu Cosmetics.

		`UnlockCosmetic` trả về false nếu người chơi ĐÃ sở hữu ⇒ đây là vòng 2 trở đi ⇒ trả gói
		bù co giãn thay thế. Không cần thêm trường dữ liệu nào để biết đang ở vòng mấy.
	]]
	if reward.trail then
		local isFirstTime = ProgressionService.UnlockCosmetic(player, "trail", reward.trail, true)
		if not isFirstTime then
			local data = DataService.GetData(player)
			if data then
				local rebirths = math.max(0, math.floor(tonumber(data.Rebirths) or 0))
				local nextLevel = Constants.GetRequiredLevelForRebirth(rebirths)
				local climb = math.max(0, Constants.GetCumulativeXP(nextLevel) - (tonumber(data.Speed) or 0))
				local feeShare = Constants.GetRebirthWinsCost(rebirths + 1) * REPEAT_DAY7_FEE_SHARE

				local bonusWins = math.floor(math.max(REPEAT_DAY7_MIN_WINS, feeShare))
				local bonusSpeed = math.floor(climb * REPEAT_DAY7_CLIMB_SHARE)
				ProgressionService.AwardWins(player, bonusWins, "daily")
				if bonusSpeed > 0 then
					ProgressionService.GrantSpeed(player, bonusSpeed)
				end
			end
		end
	end
end

local function onClaim(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end

	local currentStreak, canClaim, nextDay = computeState(data)
	if not canClaim then
		sendState(player)
		return
	end
	-- `computeState` đọc `DailyStreakDay`, mà dòng dưới ghi đè nó ngay — giữ lại bản cũ trong
	-- biến cục bộ (KHÔNG ghi field rác vào profile) để phân biệt "vòng mới liền mạch" với
	-- "chuỗi vừa đứt" khi cập nhật LifetimeStreak.

	-- Ghi cờ chống-trùng TRƯỚC khi cấp thưởng. grantReward → AwardWins có thể yield
	-- (GroupChestService.IsGroupMember gọi web API); nếu ghi cờ sau, hai gói claim cùng
	-- frame đều lọt qua cửa canClaim ở trên rồi cùng nhận thưởng. Set cờ trước =
	-- check-and-set nguyên tử: gói thứ hai thấy canClaim=false và bị chặn.
	-- nextDay đã được chốt ở computeState nên đặt cờ sớm không đổi phần thưởng.
	data.DailyStreakDay = nextDay
	data.DailyLastClaimDay = todayNumber()
	--[[
		Tổng ngày liên tục qua MỌI vòng — chỉ để khoe và để đo nhóm gắn bó nhất, không trao
		thưởng. `nextDay == 1` sau khi bỏ lỡ nghĩa là chuỗi vừa đứt: `computeState` trả
		(0, true, 1) ở nhánh đó, phân biệt được với vòng mới liền mạch nhờ `streak >= 7`.
	]]
	if nextDay == 1 and currentStreak < 7 then
		data.LifetimeStreak = 1
	else
		data.LifetimeStreak = (tonumber(data.LifetimeStreak) or 0) + 1
	end

	grantReward(player, nextDay)

	sendState(player)
end

function DailyService.SendState(player: Player)
	sendState(player)
end

function DailyService.Init()
	DataService = ServiceLocator.Get("DataService")
	ProgressionService = ServiceLocator.Get("ProgressionService")
end

function DailyService.Start()
	GamePackets.requestDailyClaim.listen(function(_data, player)
		if not player or NetRateLimit.ShouldDrop(player, "dailyClaim") then
			return
		end
		onClaim(player)
	end)

	local function pushWhenReady(player: Player)
		task.spawn(function()
			local tries = 0
			while not DataService.IsLoaded(player) and tries < 200 and player.Parent == Players do
				task.wait(0.1)
				tries += 1
			end
			if DataService.IsLoaded(player) then
				sendState(player)
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		pushWhenReady(player)
	end
	Players.PlayerAdded:Connect(pushWhenReady)
end

return DailyService
