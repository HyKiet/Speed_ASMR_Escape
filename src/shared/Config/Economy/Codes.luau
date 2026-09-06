--!strict
--[[
	Bảng Mã Quà Tặng (Promo Codes) cho Speed Escape.

	── VÌ SAO CHỈ CÒN 2 MÃ, VÀ VÌ SAO PHẦN THƯỞNG CÓ HÌNH DẠNG NÀY (viết lại 2026-08-23) ──

	Bản cũ có 4 mã (RELEASE / SPEED / FREEWINS / LUCKY) và mắc đúng cái lỗi mà bảng điểm danh
	đã phải sửa ở GDD mục 8.A1: **phát Wins quá tay ở đầu game**. `FREEWINS` cho thẳng 2.500
	Wins — nhập một cái là nhảy qua pad_2 (3), pad_3 (15), pad_4 (100), pad_5 (500) và chạm
	pad_6 (2.500), tức bỏ qua trọn đoạn chơi mà phần đầu game được dựng ra để dạy.

	Luật mới, hai điều:

	1. **Mã KHÔNG phát Wins.** Wins là tiền cứng, là thứ mở pad và mở teleport — nó phải đến
	   từ việc chạy obby. Bảng daily đã bị siết xuống 1.177 Wins/tuần có chủ đích; mã quà mà
	   phát Wins là phá lại chính phép siết đó bằng cửa sau.

	2. **Phát Speed + vé quay.** Speed là xương sống (GDD 8.A1): nó cộng vào XP ⇒ Level ⇒
	   WalkSpeed — cảm nhận được ngay dưới chân mà không mua vượt cấp được thứ gì. Còn vé
	   quay là phần thưởng **không mất giá theo cấp**: với người mới lẫn người Level 98, một
	   vé vẫn là 1% cơ hội trúng Frozen Bloom (aura x10 mạnh nhất mà F2P sở hữu được). Đây là
	   cách duy nhất làm mã quà "đáng" với CẢ HAI đầu của đường cong.

	── ĐỐI CHIẾU ĐỘ MẠNH ──
	  Daily ngày 6 (ngày Speed to nhất)      = +150.000 Speed
	  Ô Epic của vòng quay (3%)              = +100.000 Speed
	  Daily ngày 7 (đỉnh của cả tuần)        = trail độc quyền + 1.000 Wins + 3 vé
	  ⇒ `RELEASE` 250.000 Speed + 3 vé: mạnh hơn ngày Speed to nhất, nhưng vẫn DƯỚI ngày 7
	    vì không có món độc quyền nào. Đúng thứ tự mong muốn — chuỗi 7 ngày phải hơn một mã
	    gõ trong 5 giây.

	⚠️ Mỗi mã chỉ nhận được MỘT LẦN cho mỗi tài khoản (`data.RedeemedCodes` trong
	`CodeService`). Đổi phần thưởng của một mã đã phát hành thì người nhập rồi KHÔNG nhận lại
	được — muốn phát đợt mới thì thêm mã mới, đừng sửa mã cũ.

	Danh sách hiển thị cho người chơi nằm ở file `CODES` ngoài repo — sửa ở đây thì sửa cả đó.
]]

export type CodeReward = {
	description: string,
	speed: number?,
	spin: number?,
}

local Codes: { [string]: CodeReward } = {
	-- Quà ra mắt, dành cho tất cả người chơi.
	["RELEASE"] = {
		description = "+500,000 Speed & 🎟️ 3 Spin Tickets",
		speed = 500000,
		spin = 3,
	},
	-- Mã thương hiệu, dùng cho bài đăng mạng xã hội / video.
	["ASMR"] = {
		description = "+200,000 Speed & 🎟️ 2 Spin Tickets",
		speed = 200000,
		spin = 2,
	},
}

return Codes
