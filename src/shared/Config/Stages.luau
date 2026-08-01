--!strict
-- Cấu hình Stage: số Wins thưởng, gates (Level/WalkSpeed GỢI Ý), hồi sinh, skip rebirth.

export type StageGate = {
	minLv: number,
	minWS: number,
}

local Stages = {}

-- Đồng bộ theo GDD.md §3.B (2026-07-10)
Stages.STAGE_WINS = {
	[1] = 1,
	[2] = 3,
	[3] = 10,
	[4] = 20,
	[5] = 50,
	[6] = 100,
	[7] = 150,
	[8] = 300,
	[9] = 500,
	[10] = 1000,
	[11] = 2500,
	[12] = 10000,
	[13] = 25000,
	[14] = 50000,
	[15] = 150000,
} :: { [number]: number }

Stages.MAX_CONFIGURED_STAGE = 15
Stages.FINISH_REWARD_COOLDOWN = 10
Stages.STAGE_15_FIRST_CLEAR_BONUS = 50000

-- CHỈ LÀ GỢI Ý: dùng cho biển báo "Recommend: Lv X" và UI — KHÔNG chặn người chơi.
-- (Cơ chế gate chặn theo Level/WalkSpeed đã gỡ bỏ hoàn toàn khỏi gameplay.)
Stages.STAGE_GATES = {
	[1] = { minLv = 1,   minWS = 12 },
	[2] = { minLv = 8,   minWS = 26 },
	[3] = { minLv = 16,  minWS = 42 },
	[4] = { minLv = 24,  minWS = 58 },
	[5] = { minLv = 32,  minWS = 74 },
	[6] = { minLv = 40,  minWS = 90 },
	[7] = { minLv = 48,  minWS = 106 },
	[8] = { minLv = 56,  minWS = 122 },
	[9] = { minLv = 64,  minWS = 138 },
	[10] = { minLv = 72, minWS = 154 },
	[11] = { minLv = 80, minWS = 170 },
	[12] = { minLv = 88, minWS = 186 },
	[13] = { minLv = 96, minWS = 202 },
	[14] = { minLv = 104, minWS = 218 },
	[15] = { minLv = 112, minWS = 234 },
	[16] = { minLv = 119, minWS = 248 },
	[17] = { minLv = 126, minWS = 262 },
	[18] = { minLv = 133, minWS = 276 },
	[19] = { minLv = 140, minWS = 290 },
	[20] = { minLv = 147, minWS = 304 },
	[21] = { minLv = 154, minWS = 318 },
	[22] = { minLv = 161, minWS = 332 },
	[23] = { minLv = 168, minWS = 346 },
	[24] = { minLv = 175, minWS = 360 },
	[25] = { minLv = 182, minWS = 374 },
	[26] = { minLv = 189, minWS = 388 },
	[27] = { minLv = 196, minWS = 402 },
	[28] = { minLv = 203, minWS = 416 },
	[29] = { minLv = 210, minWS = 430 },
	[30] = { minLv = 217, minWS = 444 },
} :: { [number]: StageGate }

Stages.REVIVE_PROMPT_SECONDS = 5
Stages.REVIVE_ROBUX_PRICE = 19
Stages.REVIVE_PRODUCT_ID = 3608405576
Stages.REVIVE_AD_PLACEMENT_ID = 0
Stages.SKIP_REBIRTH_PRODUCT_ID = 3608406966
Stages.SKIP_REBIRTH_PASS_ID = 0

-- Developer Product IDs for Skip Stage and x2 Wins
Stages.SKIP_STAGE_PRODUCT_ID = 3608405926
Stages.DOUBLE_WINS_PRODUCT_ID = 3608406804

return Stages
