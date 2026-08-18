--!strict
--[[
	Cấu hình Group Chest. Đổi GROUP_ID sang group thật của game khi publish.

	── CÂN BẰNG PHẦN THƯỞNG WINS (chốt 2026-08-10, user) ─────────────────────────────────
	Rương này chỉ có MỘT nhiệm vụ: đổi hai cú bấm (join group + like game) lấy phần thưởng.
	Nó được mở đúng lúc người chơi mới vào game, nên phần thưởng phải nhìn thấy được NGAY —
	một hệ số nhân âm thầm không đủ để ai đó rời game đi bấm Join trên trang group.

	Bản cũ chỉ có: +5.000 Speed một lần + x1.1 Wins vĩnh viễn.
	Speed thì người chơi mới nào cũng có sẵn cả nghìn từ Daily, còn "+10% Wins" là con số họ
	không cảm được cho tới hàng giờ sau. Kết quả: phần thưởng to nhất của rương lại là thứ vô
	hình đúng vào giây phút cần thuyết phục.

	Giờ thêm `INSTANT_WINS_REWARD` — Wins TRAO NGAY, vì Wins mới là thứ mở Multiplier Pad và
	trả tiền teleport, tức là thứ người chơi mới đang thiếu và biết mình thiếu.

	Vì sao đúng 10 Wins, không phải 25 hay 100:
	    Mốc pad:      Pad 2 = 3 Wins · Pad 3 = 15 Wins · Pad 4 = 100 Wins
	    Giờ đầu tiên: Daily ngày 1 = 2 · Stage 1 = 1 · Stage 2 = 3 · Stage 3 = 10
	  → 10 Wins ≈ đúng một lượt Stage 3, tức "tiết kiệm được một chặng" — cảm nhận được ngay.
	  → Cộng vào mạch mở đầu (2+1 = 3) thành 13: VẪN CHƯA đủ 15 cho Pad 3, nên rương không
	    phát không một pad nào, người chơi vẫn phải chạy thêm một stage. Đây là ranh giới cố ý.
	  → 25 Wins sẽ vượt thẳng mốc Pad 3 (biếu không một cấp sức mạnh); 100 thì phá luôn cả
	    Pad 4 và làm 4 stage đầu thành vô nghĩa.
	  → Với tài khoản đã có 100K+ Wins thì 10 Wins là số không — đúng như mong muốn: đây là
	    phần thưởng NGƯỜI MỚI, không phải nguồn lạm phát cho người chơi lâu năm.

	`WINS_MULTIPLIER` giữ nguyên 1.1: đây là cần gạt duy nhất tác động VĨNH VIỄN lên toàn bộ
	kinh tế (mọi Win kiếm được suốt đời tài khoản), nâng nó lên là lạm phát cộng dồn không
	rút lại được. Muốn rương hấp dẫn hơn thì tăng phần TRAO NGAY, đừng đụng vào hệ số.

	⚠️ Sửa `INSTANT_WINS_REWARD` thì phải kiểm lại phép cộng "2 + 1 + N < 15" ở trên, và sửa
	luôn thẻ giữa trong `GroupChestModal` (chữ trên thẻ là lời hứa với người chơi).
]]

local GroupChest = {
	GROUP_ID = 675923086,
	STARTER_SPEED_REWARD = 5_000,
	INSTANT_WINS_REWARD = 10,
	WINS_MULTIPLIER = 1.1,
}

return GroupChest
