--!strict
--[[
	MULTIPLIER PAD — mua một lần bằng Wins, sở hữu VĨNH VIỄN (GDD 3.0 §5.1).

	══ ĐỔI CẤU TRÚC 2026-09-06 — `requiredWins` giờ là GIÁ, không phải NGƯỠNG ═══════════════

	Bản cũ: pad là ngưỡng số dư ví. `MultiplierPadService.eligibleIndex` đọc `data.TotalWins`
	rồi cấp pad cao nhất mà số dư với tới — nghĩa là TIÊU Wins làm người chơi YẾU ĐI. Mua một
	trail 100.000 Wins là tự đánh tụt tốc độ cày của chính mình xuống mấy bậc pad.

	Đó là nguyên nhân gốc của Sinks/Sources = 2,3% đo được trên Live: người chơi không keo, họ
	học được rằng tiêu tiền thì bị phạt.

	Giờ: trừ Wins một lần, ghi vào `data.OwnedPadIndex`, giữ mãi mãi.

	⚠️ MIGRATION BẮT BUỘC (DataService, CORE_LOOP_VERSION 5): mọi tài khoản được cấp MIỄN PHÍ
	tất cả pad mà `TotalWins` hiện tại của họ đủ theo bảng NGƯỠNG CŨ (0 / 1 / 15 / 100 / 500 /
	2.500 / 15.000 / 50.000). Bảng đó khai TRONG `DataService` chứ không ở đây — nó là dữ liệu
	migration dùng đúng một lần, và file này PHẢI là mảng thuần: mọi nơi khác đều duyệt bằng
	`for _, config in MultiplierPads`, thêm một khoá phụ là vòng lặp đó nhận phải thứ không có
	trường `.id`.

	══ VÌ SAO KHÔNG NÂNG TRẦN PAD ═════════════════════════════════════════════════════════

	Đo bằng mô phỏng (GDD §5.1): nâng `pad_8` từ +500 lên +1.200 gần như KHÔNG đổi gì cho người
	nạp (Stage 15: 20 → 18 phút) vì xô Premium của họ đã áp đảo. Nó chỉ rút ngắn nội dung của
	người chơi miễn phí (6,1 → 2,9 giờ) và kéo khoảng cách trả tiền/không trả từ 14× xuống 6×.

	Nên `pad_4`…`pad_8` giữ NGUYÊN giá trị đang chạy. Chỉ nới hai bậc đầu để đoạn mở màn bùng nổ.
	Sức mạnh dài hạn nằm ở hệ số trùng sinh (`Formulas.GetRebirthMultiplier`), không nằm ở đây.
]]

export type MultiplierPadConfig = {
	id: string,
	speedPerStep: number,
	-- GIÁ MUA bằng Wins (trừ một lần). Tên trường giữ nguyên để không phải sửa 3 file gọi tới.
	requiredWins: number,
}

local MultiplierPads: { MultiplierPadConfig } = {
	{ id = "pad_1", speedPerStep = 1, requiredWins = 0 },
	--[[
		⚠️ GIÁ 1 WINS KHOÁ CHẶT VỚI `Stages.STAGE_WINS[1]` = 2.

		Đây là giá của BƯỚC 2 TUTORIAL. Người chơi tới bước này chỉ có đúng phần thưởng của
		bước 1 trong túi (Daily nằm SAU tutorial, không mượn được). Luật bất di bất dịch:
		giá pad_2 ≤ Wins kiếm được ở Stage 1. Đổi một trong hai là phải kiểm lại phép so này,
		nếu không bước 2 thành ngõ cụt "Need N Wins" và người mới kẹt không có đường ra.
	]]
	{ id = "pad_2", speedPerStep = 3, requiredWins = 1 },
	{ id = "pad_3", speedPerStep = 8, requiredWins = 12 },
	{ id = "pad_4", speedPerStep = 25, requiredWins = 40 },
	{ id = "pad_5", speedPerStep = 50, requiredWins = 120 },
	{ id = "pad_6", speedPerStep = 100, requiredWins = 600 },
	{ id = "pad_7", speedPerStep = 250, requiredWins = 3500 },
	--[[
		⚠️ BẢNG NÀY DỪNG Ở 8 — VÌ MAP CHỈ DỰNG 8 PAD.

		`Workspace.Lobby.MultiplierPads` có đúng Pad_1..Pad_8 (kiểm 2026-09-06). Thêm dòng vào
		đây mà không dựng pad trong map là tặng sức mạnh cho một thứ không tồn tại, và client
		không tô được pad nào vì `ActivePadId` không khớp PadPart nào cả.

		THÊM PAD MỚI = DỰNG PAD TRONG MAP TRƯỚC, thêm dòng vào đây sau.
	]]
	{ id = "pad_8", speedPerStep = 500, requiredWins = 18000 },
}

return MultiplierPads
