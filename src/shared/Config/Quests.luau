--!strict

export type ChainQuestConfig = {
	id: string,
	kind: string,
	title: string,
	target: number,
	rewardSpeed: number,
	rewardSpins: number,
	badgeId: number?,
}

export type DailyQuestConfig = {
	id: string,
	kind: string,
	title: string,
	target: number,
}

--[[
	QUEST CHAIN — GDD 3.0 §7.2. Chạy một lần, phút 2–10.

	══ TRÙNG SINH ĐẨY LÊN MẮT XÍCH 3 ═══════════════════════════════════════════════════════
	Bản cũ để nó ở mắt xích CUỐI (~phút 9), lúc người chơi đang ở Level ~38. Nghĩa là chuỗi
	quest hướng dẫn người chơi mới XOÁ SẠCH tiến trình mình vừa nhận để đổi lấy x1,5 — rồi mất
	hơn một giờ để leo lại. Đặt ở mắt xích 3 thì họ trùng sinh khi mới Level 10, gần như không
	mất gì, và toàn bộ phần thưởng lớn của chuỗi rơi xuống SAU khi đã có hệ số.

	Chuỗi dạy trọn vòng lặp trùng sinh HAI LẦN trong phiên đầu tiên. Đó là mục đích duy nhất.

	══ ⚠️ SỐ VÉ QUAY KHOÁ VỚI BẢNG CHỐT CHẶN ROULETTE (GDD §7.5) ═══════════════════════════
	Chuỗi phát 3 vé, không phải 6. Tổng vé của GIỜ ĐẦU phải giữ ở mức 12
	(4 online + 3 chuỗi + 5 mã quà). Ở mức 15 vé của bản cũ, Roulette chiếm 56% Wins và 53%
	Speed của giờ đầu — người chơi mới kiếm từ vòng quay nhiều hơn từ việc chơi game.
	Thêm vé vào đây là phải kiểm lại bảng chốt chặn đó.

	Thang độ mạnh: không mắt xích nào được vượt phần thưởng Speed lớn nhất của một ngày điểm
	danh (Ngày 6 = 400.000). Một chuỗi xong trong 10 phút không được mạnh hơn chuỗi 7 ngày.
]]
local Chain: { ChainQuestConfig } = {
	{ id = "stage_2", kind = "stage", title = "Clear Stage 2", target = 2, rewardSpeed = 1_500, rewardSpins = 0 },
	{ id = "level_10", kind = "level", title = "Reach Level 10", target = 10, rewardSpeed = 3_000, rewardSpins = 0 },
	{
		id = "first_rebirth",
		kind = "rebirth",
		title = "Rebirth for the first time",
		target = 1,
		rewardSpeed = 20_000,
		rewardSpins = 1,
	},
	{
		id = "pad_4",
		kind = "pad",
		title = "Unlock Multiplier Pad 4",
		target = 4,
		rewardSpeed = 60_000,
		rewardSpins = 0,
	},
	{ id = "stage_5", kind = "stage", title = "Clear Stage 5", target = 5, rewardSpeed = 150_000, rewardSpins = 0 },
	{
		id = "second_rebirth",
		kind = "rebirth",
		title = "Rebirth a second time",
		target = 2,
		rewardSpeed = 250_000,
		rewardSpins = 2,
		badgeId = 0,
	},
}

-- Only targets explicitly locked in GDD 8.A0c are included. The unspecified
-- "gain X Speed" and "play with a friend" examples remain design backlog.
local ObbyPool: { DailyQuestConfig } = {
	{ id = "clear_3_stages", kind = "stage_clear", title = "Clear 3 stages", target = 3 },
}
local FarmEconomyPool: { DailyQuestConfig } = {
	{ id = "gain_2_levels", kind = "level_gain", title = "Gain 2 Levels", target = 2 },
	{ id = "buy_1_cosmetic", kind = "cosmetic_purchase", title = "Buy 1 cosmetic", target = 1 },
}
local FreePool: { DailyQuestConfig } = {
	{ id = "rebirth_once", kind = "rebirth_event", title = "Rebirth once", target = 1 },
	{ id = "spin_3_times", kind = "roulette_spin", title = "Spin Roulette 3 times", target = 3 },
	{ id = "use_5_emotes", kind = "emote_use", title = "Use emotes 5 times", target = 5 },
}

local function choose(pool: { DailyQuestConfig }, random: Random): DailyQuestConfig
	return pool[random:NextInteger(1, #pool)]
end

local function buildDailySet(daySeed: number): { DailyQuestConfig }
	local random = Random.new(daySeed)
	return {
		choose(ObbyPool, random),
		choose(FarmEconomyPool, random),
		choose(FreePool, random),
	}
end

-- Keep numeric Chain entries for existing simulations/tools that consume this
-- module as an array; runtime code uses the named fields below.
local Config: any = table.clone(Chain)
Config.CHAIN = Chain
Config.BuildDailySet = buildDailySet
return Config
