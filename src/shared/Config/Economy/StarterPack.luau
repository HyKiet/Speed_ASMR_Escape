--!strict
--[[
	STARTER PACK "ROOKIE ROCKET" — gói một-lần-duy-nhất cho người chơi mới.

	── Ý TƯỞNG (chốt với user 2026-08-10) ────────────────────────────────────────────────
	Giá NIÊM YẾT cao, bán giảm cực sâu: 999 R$ → 99 R$ (−90%). Con số 999 không phải bịa cho
	đẹp — nó là tổng giá trị THẬT của những món bên trong nếu mua lẻ trong shop:

	    +50.000 Wins   ≈ 450 R$  (nằm giữa gói 40K/299 và gói 300K/699)
	    x2 Speed       =    3 R$  (pass rẻ nhưng là buff VĨNH VIỄN)
	    5 vé quay      ≈   79 R$  (gói 5 vé)
	    x2 Wins 30 phút ≈  50 R$  (gói boost 10 phút = 99 R$ nhưng là toàn server)
	    Rookie Trail   = KHÔNG BÁN — chỉ có ở gói này
	  → làm tròn xuống 999 để nhìn ra ngay là "giá gốc", rồi gạch đi.

	VÌ SAO KHÔNG NHÉT VIP VÀO GÓI: VIP đang bán 399 R$ và là món đắt nhất shop. Cho VIP vào
	gói 99 R$ thì không người mới nào mua VIP lẻ nữa — tự ăn thịt món chủ lực để đổi lấy một
	lần bán rẻ. Cả gói này KHÔNG chứa món nào đang bán ở giá cao hơn, nên nó chỉ thêm doanh
	thu chứ không rút của mục khác. Món "độc quyền" để tạo thèm muốn là cosmetic (Rookie
	Trail) — thứ duy nhất trong gói không thể mua bằng đường nào khác, và cũng là thứ không
	tốn gì của nền kinh tế.

	CỬA SỔ 48 GIỜ tính từ lần ĐẦU TIÊN vào game (thời gian thật, chạy cả khi offline). Hết
	hạn là thẻ biến mất vĩnh viễn — không có "gia hạn", vì một deadline có thể lùi được thì
	không còn là deadline.

	── BÁN BẰNG DEVELOPER PRODUCT (chốt 2026-08-11) ──────────────────────────────────────
	Gói này ĐÃ có một đời làm gamepass (1940593812) trong đúng một ngày, rồi đổi sang
	Developer Product. Lý do đổi, để đời sau khỏi đổi ngược:

	  Gamepass nằm VĨNH VIỄN trên tab Store của trang game. Nghĩa là (a) cái đồng hồ "ENDS
	  IN 47:12:33" trên thẻ thành lời nói dối với bất kỳ ai mở Store, và (b) người chơi CŨ
	  cũng mua được — trong khi gói định giá cho người MỚI (25.000 Wins bán lẻ ≈ 450 R$, gói
	  chỉ 99 R$), nên nó rút ruột luôn gói Wins 299/699 R$ trong shop và biến Rookie Trail
	  "độc quyền" thành món ai cũng có.

	  Developer Product KHÔNG hiện trên trang game — chỉ mua được qua prompt bật từ trong
	  game, tức là chỉ ai đang thấy thẻ mới mua được. Cửa sổ 48h tự nó là hàng rào, không
	  cần rào thêm.

	⚠️ `LEGACY_PASS_ID` PHẢI GIỮ. Gamepass cũ đã được tắt bán trên Dashboard nhưng ai lỡ mua
	trong ngày đó thì sở hữu là vĩnh viễn — server vẫn quét pass này lúc load profile và
	phát gói cho họ. Xoá dòng đó đi là ăn cắp tiền của người đã trả.

	⚠️ `PRODUCT_ID = 0` nghĩa là chưa thiết lập. Còn 0 thì `StarterPackService` tự tắt cả hệ
	thống (không hiện thẻ) thay vì hiện một nút bấm vào báo lỗi — xem `IsConfigured()`.
]]

local RunService = game:GetService("RunService")

local StarterPack = {
	-- Developer Product "Rookie Rocket" (99 R$) — Creator Dashboard, 2026-08-11.
	PRODUCT_ID = 3703422987,

	-- Gamepass đời đầu, ĐÃ tắt bán. Chỉ còn dùng để phát bù cho người đã mua (xem trên).
	LEGACY_PASS_ID = 1940593812,

	--[[
		XEM TRƯỚC THẺ KHI CHƯA CÓ PRODUCT ID (thêm 2026-08-11 để duyệt giao diện).

		Chỉ có tác dụng TRONG STUDIO (`RunService:IsStudio()`), và chỉ ảnh hưởng đúng một
		việc: thẻ có được VẼ hay không. Đường thanh toán vẫn khoá cứng ở `IsConfigured()`.
		Giờ đã có PRODUCT_ID thật nên cờ này nằm im — giữ lại cho lần sau đổi/gỡ sản phẩm.
	]]
	PREVIEW_WITHOUT_PRODUCT = false,

	PRICE_ROBUX = 99,
	-- Giá "gốc" gạch ngang. Chỉ để hiển thị — không dùng vào phép tính nào.
	ORIGINAL_PRICE_ROBUX = 999,
	DISCOUNT_PERCENT = 90,

	-- Cửa sổ bán, tính từ `FirstJoinTime` của tài khoản.
	WINDOW_SECONDS = 48 * 3600,

	-- ── Nội dung gói ──
	WINS = 50_000,
	--[[
		Buff Speed VĨNH VIỄN. CỘNG vào bậc pass cao nhất đang sở hữu (đổi 2026-08-14):
		  chưa pass → x2 · có x2 → x4 · có x4 → x6 · có x8 → x10.
		Không phải `math.max` (người có x8 mua gói xong không thấy gì thay đổi) và cũng không
		phải nhân chồng (x16). Xem khối lý do trong `computeGamepassMultiplier`.
	]]
	SPEED_MULTIPLIER = 2,
	SPINS = 5,
	BOOST_WINS_SECONDS = 30 * 60,
	TRAIL_ID = "trail_rookie",
}

-- Chưa có Product ID thật thì coi như gói chưa tồn tại (xem cảnh báo ở đầu file).
-- ĐÂY là cửa duy nhất cho mọi đường tiền: prompt mua và ProcessReceipt đều hỏi hàm này.
function StarterPack.IsConfigured(): boolean
	return StarterPack.PRODUCT_ID > 0
end

-- Có VẼ thẻ hay không — rộng hơn `IsConfigured` đúng một trường hợp: xem trước trong Studio.
function StarterPack.ShowsCard(): boolean
	if StarterPack.IsConfigured() then
		return true
	end
	return StarterPack.PREVIEW_WITHOUT_PRODUCT and RunService:IsStudio()
end

return StarterPack
