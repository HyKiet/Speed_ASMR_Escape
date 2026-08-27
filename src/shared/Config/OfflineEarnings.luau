--!strict
--[[
	OfflineEarnings.luau — Treadmill vẫn chạy khi người chơi thoát game.

	── VÌ SAO CÓ TÍNH NĂNG NÀY ────────────────────────────────────────────────────────────────
	`Day 1 retention` là một trong ba tín hiệu nặng nhất của thuật toán đề xuất Roblox 2026
	(cùng play-through rate và first-play bounce rate). Tiến trình offline là đòn bẩy trực tiếp
	nhất lên chỉ số đó: nó biến hành động "đóng game" từ *bỏ đi* thành *gieo hạt*. Đây chính là
	cơ chế đứng sau Grow a Garden — game bùng nổ nhanh nhất Roblox 2026.

	── LUẬT BẤT DI BẤT DỊCH: OFFLINE PHẢI KÉM HƠN ONLINE ─────────────────────────────────────
	Nếu offline bằng hoặc gần bằng online thì cách chơi tối ưu trở thành "thoát game", và mọi
	thứ game được xây quanh — obby, stage, vòng quay, mua bán — mất lý do tồn tại. `RATE` dưới
	đây là cái chốt giữ điều đó, và nó CHỈ ĐƯỢC ĐI XUỐNG, không bao giờ đi lên.

	Ba tầng bảo vệ chồng nhau:
	  1. `RATE` = 25% tốc độ online.
	  2. `MAX_SECONDS` = 2 giờ — thoát 10 tiếng cũng chỉ nhận đúng 2 giờ. Đây mới là cái chặn
	     thật: không có nó thì một tài khoản bỏ hoang một tuần vào lại là nhảy vọt mấy chục cấp.
	  3. Rổ liveOps (Playtime / Friends / Server Boost / Event) KHÔNG được tính — xem
	     `ProgressionService.GetOfflineMultiplier`. Đó là các buff của PHIÊN CHƠI; trả chúng cho
	     người đang offline vừa vô lý vừa nhân chồng lên nhau thành số khổng lồ.

	── GAMEPASS CÓ ĐƯỢC TÍNH KHÔNG? CÓ — VÀ ĐÓ LÀ CỐ Ý ───────────────────────────────────────
	Công thức đầy đủ nằm ở `ProgressionService.GetOfflineMultiplier`. Tóm tắt cái gì tính,
	cái gì không:

	    TÍNH   Treadmill đang trang bị   Wood x1 · Purple x3 · Blue x9 · Gold x25 · Red x100
	    TÍNH   Speed Pass                Double x2 · Quad x4 · Octa x8
	    TÍNH   VIP Membership            +0.5
	    TÍNH   Trail + Aura              (rổ cosmetic)
	    TÍNH   Rebirth                   1 + R×0.5
	    ─────────────────────────────────────────────────────────────────────────────────────
	    KHÔNG  Playtime Boost (tới x4)   buff của PHIÊN CHƠI
	    KHÔNG  Friends Boost             cần bạn bè CÙNG server
	    KHÔNG  Server Boost / Event      buff tạm thời toàn server

	Vì sao gamepass được tính: đó chính là chỗ tính năng này trả tiền cho chính nó. "Máy chạy
	bộ của bạn làm việc cả lúc bạn đi ngủ" là một lý do mua Treadmill/Speed Pass mạnh hơn hẳn
	bất kỳ dòng mô tả nào trong Shop. Còn rổ liveOps bị loại vì nhân chồng nhau (x4 × x2 × x2)
	sẽ biến trần 3 giờ thành một con số vô nghĩa.

	⚠️ HỆ QUẢ CẦN BIẾT: người sở hữu tối đa (Gold x25 + Octa x8 + VIP) có rổ premium = x32.5.
	Nếu về sau muốn chặn, chỗ đúng để chặn là kẹp TRẦN của `GetOfflineMultiplier`, không phải
	hạ `RATE` — hạ RATE phạt luôn cả người chơi miễn phí.

	── VÌ SAO KHÔNG PHÁT WINS ────────────────────────────────────────────────────────────────
	Chỉ phát Speed (tiền MỀM: đẩy Level, mất trắng khi rebirth). Wins là tiền CỨNG — mở pad,
	mua cosmetic, không hồi lại. Phát Wins offline là lạm phát thẳng vào thứ duy nhất neo giữ
	giá trị của cả vòng lặp lõi. Cùng lý do đã dùng khi cân lại vòng quay (`Config/Roulette`).
]]

local OfflineEarnings = {}

--[[
	Tỉ lệ so với online. 0.25 = kiếm 4 tiếng offline mới bằng 1 tiếng ngồi treadmill.

	Vì sao 25% chứ không phải 50%: ở 50% thì một đêm ngủ (trần 2h → 1h quy đổi online) ngang
	với cả một buổi chơi thật, và người chơi sẽ cảm thấy ngồi treadmill là phí thời gian. Ở 25%
	nó là phần thưởng cho việc QUAY LẠI, không phải một cách chơi thay thế.
]]
OfflineEarnings.RATE = 0.25

-- Trần tích luỹ. Thoát bao lâu cũng chỉ tính tối đa chừng này. (2h → 3h, 2026-08-27.)
OfflineEarnings.MAX_SECONDS = 3 * 60 * 60

--[[
	Dưới ngưỡng này thì không phát gì cả.

	Hai việc cùng lúc: chặn spam thoát-vào-lại để farm banner, và tránh làm phiền người vừa bị
	rớt mạng 30 giây bằng một cái banner "chào mừng trở lại" vô duyên.
]]
OfflineEarnings.MIN_SECONDS = 3 * 60

--[[
	Chỉ phát khi lượng Speed đủ để thành một con số đáng nhìn.

	Người chơi Level 1 dùng pad_1 (+1/step) thoát đúng 3 phút sẽ được ~128 Speed — hiện lên
	banner "+128" trông như một lỗi hơn là một món quà. Kẹp dưới ở đây để chuyện đó không xảy ra.
]]
OfflineEarnings.MIN_SPEED_TO_GRANT = 500

return OfflineEarnings
