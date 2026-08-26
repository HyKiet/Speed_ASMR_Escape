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
	--[[
		⚠️ BẢNG NÀY DỪNG Ở 8 — VÌ MAP CHỈ DỰNG 8 PAD (cắt 2026-08-26, user).

		`Workspace.Lobby.MultiplierPads` có đúng Pad_1..Pad_8. Bản trước bảng này khai thêm
		pad_9/10/11 (200k / 1M / 5M Wins) không có thân xác ngoài đời, và `MultiplierPadService`
		tin bảng chứ không tin map:
		  • `eligibleIndex` trả 9 cho người ≥200k Wins ⇒ `enforcePad` cấp thẳng +1000/step từ
		    một cái pad họ chưa từng đi tới. Pad 8 (+500) tốn 50k Wins để leo lên; pad 9 tự rơi
		    vào tay miễn phí — nấc cuối của cả hệ thống bị vô hiệu hoá.
		  • `ActivePadId = "pad_9"` không khớp PadPart nào ⇒ client không tô vàng pad nào cả,
		    người chơi mất luôn chỉ dấu "mình đang ở pad nào".

		⚠️ THÊM PAD MỚI = DỰNG PAD TRONG MAP TRƯỚC, thêm dòng vào đây sau. Ngược lại là tặng
		sức mạnh cho một thứ không tồn tại.
	]]
	{ id = "pad_8", speedPerStep = 500, requiredWins = 50000 },
}

return MultiplierPads
