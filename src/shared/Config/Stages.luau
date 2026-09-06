--!strict
-- Cấu hình Stage: số Wins thưởng, gates (Level/WalkSpeed GỢI Ý), hồi sinh, skip rebirth.

export type StageGate = {
	minLv: number,
	minWS: number,
}

local Stages = {}

--[[
	Thưởng Wins mỗi stage — GDD 3.0 §4.2.

	Tỉ lệ đều ~2,4× mỗi bậc. Bản cũ nhảy thất thường (×2 → ×3,3 → ×1,5 → ×4) nên không stage nào
	đọc ra là "bước tiếp theo đáng giá".

	⚠️ Đổi bảng này là PHẢI tính lại `Config/Teleport.priceWins`: giá teleport tới stage N bị kẹp
	cứng trong khoảng STAGE_WINS[N-1] < giá < STAGE_WINS[N]. Phá cận dưới là sinh Wins vô hạn.
]]
Stages.STAGE_WINS = {
	[1] = 2,
	[2] = 5,
	[3] = 12,
	[4] = 30,
	[5] = 75,
	[6] = 180,
	[7] = 420,
	[8] = 1000,
	[9] = 2400,
	[10] = 5500,
	[11] = 13000,
	[12] = 30000,
	[13] = 70000,
	[14] = 160000,
	[15] = 400000,
} :: { [number]: number }

Stages.MAX_CONFIGURED_STAGE = 15
Stages.FINISH_REWARD_COOLDOWN = 10
-- GỠ 2026-09-06 (GDD 3.0 §4.2): bonus lần đầu clear Stage 15 và thưởng chuỗi liên tiếp đều bỏ.
-- Bảng Wins mới đã hào phóng hơn nhiều lần so với những gì chúng từng cộng thêm — clear Stage 15
-- lần đầu nhận 400.000 thay vì 150.000 + 50.000 bonus. Giữ lại chỉ là hai đường trao thưởng nữa
-- phải bảo trì.

-- CHỈ LÀ GỢI Ý: dùng cho biển báo "Recommend: Lv X" và UI — KHÔNG chặn người chơi.
-- (Cơ chế gate chặn theo Level/WalkSpeed đã gỡ bỏ hoàn toàn khỏi gameplay.)
--
-- ⚠️ XOÁ 2026-08-23 — bảng này từng khai tiếp tới [30] với minWS 248→444. Đó là dữ liệu CHẾT
-- và SAI: trần WalkSpeed là 250 (`Formulas.GetMaxWalkSpeed`) và World 2 GIỮ NGUYÊN trần 250
-- (GDD mục 9), nên mọi gate từ [17] trở đi yêu cầu tốc độ không thể đạt được. Chưa lộ vì
-- `MAX_CONFIGURED_STAGE = 15`. Khi dựng World 2 thì viết lại bảng cho Stage 16–30 trong
-- khoảng ≤ 250 — phải đi kèm thiết kế 15 màn mới, không suy ra bằng công thức được.
Stages.STAGE_GATES = {
	[1] = { minLv = 1, minWS = 12 },
	[2] = { minLv = 8, minWS = 26 },
	[3] = { minLv = 16, minWS = 42 },
	[4] = { minLv = 24, minWS = 58 },
	[5] = { minLv = 32, minWS = 74 },
	[6] = { minLv = 40, minWS = 90 },
	[7] = { minLv = 48, minWS = 106 },
	[8] = { minLv = 56, minWS = 122 },
	[9] = { minLv = 64, minWS = 138 },
	[10] = { minLv = 72, minWS = 154 },
	[11] = { minLv = 80, minWS = 170 },
	[12] = { minLv = 88, minWS = 186 },
	[13] = { minLv = 96, minWS = 202 },
	[14] = { minLv = 104, minWS = 218 },
	[15] = { minLv = 112, minWS = 234 },
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
