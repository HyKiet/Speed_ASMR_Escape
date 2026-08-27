--!strict
-- ID Developer Product (Creator Dashboard — cập nhật 2026-07-06).

export type SpinPack = {
	productId: number,
	spins: number,
	priceRobux: number,
}

local Products = {}

-- Wins Packs: productId → số Wins cộng thẳng
Products.WINS_PACKS = {
	[3608400621] = 1_000, -- Small Wins Pack (99 R$)
	[3608400807] = 10_000, -- Medium Wins Pack (299 R$)
	[3608401003] = 100_000, -- Large Wins Pack (699 R$)
	[3608401110] = 1_000_000, -- Ultra Wins Pack (1299 R$)
} :: { [number]: number }

-- Server Boosts (toàn máy chủ, 10 phút, cộng dồn khi mua chồng)
Products.SERVER_BOOST_SPEED_PRODUCT_ID = 3608407713 -- Server x2 Speed (99 R$)
Products.SERVER_BOOST_WINS_PRODUCT_ID = 3608407843 -- Server x2 Wins (99 R$)
Products.SERVER_BOOST_MEGA_PRODUCT_ID = 3608407916 -- MEGA Server Boost x2 Both (149 R$)
Products.SERVER_BOOST_DURATION_SECONDS = 600

-- Skip Rebirth (149 R$): trùng sinh ngay không cần đủ Level
Products.SKIP_REBIRTH_PRODUCT_ID = 3608406966

-- Gói lượt quay Roulette (Đã khởi tạo trên Creator Dashboard)
Products.SPIN_PACKS = {
	{ productId = 3610356888, spins = 1, priceRobux = 19 },
	{ productId = 3610357071, spins = 5, priceRobux = 79 },
	{ productId = 3610357149, spins = 10, priceRobux = 149 },
} :: { SpinPack }

--[[
	══ NHÂN ĐÔI PHẦN THƯỞNG OFFLINE ════════════════════════════════════════════════════════

	Nút "Double It" trên `OfflineModal` — mua ngay tại khoảnh khắc người chơi vừa quay lại và
	đang nhìn con số mình kiếm được lúc offline.

	── VÌ SAO 19 R$ CHỨ KHÔNG PHẢI 9 ────────────────────────────────────────────────────────
	Mẫu tham khảo user gửi để 9 R$, nhưng **19 là sàn giá của game này**: Revive 19, và 1 vé
	quay Roulette cũng 19 (xem `SPIN_PACKS` + bảng Developer Products trong GDD §7.B). Đặt một
	món 9 R$ là kéo tụt cả thang giá — một vé quay (EV ~493 Wins + 13.300 Speed) bỗng trông
	đắt gấp đôi so với việc nhân đôi cả gói offline, và không ai mua vé nữa.

	19 R$ cũng là mức đúng về mặt tâm lý: cùng giá với Revive, món xung động rẻ nhất mà người
	chơi đã quen bấm.

	── VÌ SAO CÓ NGƯỠNG TỐI THIỂU ───────────────────────────────────────────────────────────
	`OFFLINE_DOUBLE_MIN_SPEED` — dưới ngưỡng này thì modal CHỈ hiện nút Claim.

	`OfflineEarnings.MIN_SPEED_TO_GRANT` chỉ là 500, tức người vắng 5 phút vẫn thấy modal. Chào
	bán 19 R$ để nhân đôi 500 Speed là một lời chào xúc phạm, và tệ hơn: nó dạy người chơi rằng
	nút Double không đáng bấm. Một khi họ học được điều đó thì lần thật sự đáng bấm cũng bị bỏ qua.

	⚠️ `productId = 0` ⇒ CHƯA TẠO trên Creator Dashboard. Client sẽ báo toast thay vì mở hộp
	thoại mua (cùng cách xử lý với `SPIN_PACKS` hồi chưa có ID). Tạo xong thì điền số vào đây.
]]
Products.OFFLINE_DOUBLE_PRODUCT_ID = 0
Products.OFFLINE_DOUBLE_PRICE_ROBUX = 19
Products.OFFLINE_DOUBLE_MIN_SPEED = 5_000

return Products
