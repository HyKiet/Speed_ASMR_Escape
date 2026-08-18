--!strict

export type MultiplierPadConfig = {
	id: string,
	speedPerStep: number,
	requiredWins: number,
}

local MultiplierPads: { MultiplierPadConfig } = {
	{ id = "pad_1", speedPerStep = 1, requiredWins = 0 },
	--[[
		⚠️ 3 → 1 (2026-08-17). Đây là GIÁ CỦA BƯỚC 2 TUTORIAL, không phải một con số kinh tế tự do.

		Stage 1 chốt được đúng 1 Win (`Stages.STAGE_WINS[1]`). Bản trước Pad 2 giá 3 và nó vẫn đủ
		tiền, nhưng CHỈ VÌ quà Daily (+2 Wins) được nhận ở ĐẦU phiên. Từ 2026-08-17 Daily chuyển
		xuống bước cuối, nên người chơi tới bước 2 chỉ có 1 Win — bước 2 thành ngõ cụt "Need 3
		Wins" đúng như `TutorialService` đã cảnh báo, và người mới kẹt ở đó không có đường ra.

		⚠️ ĐỔI `Stages.STAGE_WINS[1]` hoặc đổi thứ tự bước tutorial thì PHẢI kiểm lại con số này:
		luật bất di bất dịch là **giá Pad 2 ≤ số Wins kiếm được ở bước 1**.
	]]
	{ id = "pad_2", speedPerStep = 2, requiredWins = 1 },
	{ id = "pad_3", speedPerStep = 5, requiredWins = 15 },
	{ id = "pad_4", speedPerStep = 25, requiredWins = 100 },
	{ id = "pad_5", speedPerStep = 50, requiredWins = 500 },
	{ id = "pad_6", speedPerStep = 100, requiredWins = 2500 },
	{ id = "pad_7", speedPerStep = 250, requiredWins = 15000 },
	{ id = "pad_8", speedPerStep = 500, requiredWins = 50000 },
	{ id = "pad_9", speedPerStep = 1000, requiredWins = 200000 },
	{ id = "pad_10", speedPerStep = 2500, requiredWins = 1000000 },
	{ id = "pad_11", speedPerStep = 6000, requiredWins = 5000000 },
}

return MultiplierPads
