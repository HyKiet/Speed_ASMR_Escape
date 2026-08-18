--!strict
--[[
	══════════════════════════════════════════════════════════════════════════════════════════
	  Tokens — NGUỒN SỰ THẬT DUY NHẤT CHO MỌI THUỘC TÍNH DÙNG CHUNG CỦA HUD
	══════════════════════════════════════════════════════════════════════════════════════════

	File này KHÔNG require gì ngoài chính nó (không Fusion, không State, không Theme). Nó chỉ
	chứa SỐ và MÀU. Nhờ vậy mọi module UI đều nạp được nó mà không sợ vòng require, và nó là
	nơi DUY NHẤT được phép khai báo các con số dùng chung.

	── QUY TẮC ────────────────────────────────────────────────────────────────────────────────
	  1. Sửa một dòng ở đây = toàn bộ UI đổi theo. Đó là mục đích tồn tại của file.
	  2. KHÔNG chép số từ đây sang file khác. Đọc `Tokens.X`, đừng viết lại giá trị.
	  3. Số chỉ thuộc về MỘT màn hình duy nhất thì KHÔNG để ở đây — để ngay trong file đó.
	     Token là thứ dùng chung; nhét số riêng vào đây làm file này phình ra và mất tác dụng.
	  4. `Theme` xuất lại (re-export) phần lớn token dưới tên cũ (`Theme.FONT`, `Theme.BORDER`…)
	     để ~40 file đang gọi không phải sửa. Code MỚI nên đọc thẳng `Tokens`.

	── VÌ SAO PHẢI TÁCH RA KHỎI `Theme` ───────────────────────────────────────────────────────
	`Theme.luau` vừa giữ hằng số vừa chứa hơn 20 factory dựng Instance, đã 1600 dòng. Hằng số bị
	chôn giữa các hàm nên mỗi lần muốn "chỉnh cho cả game" phải đi tìm — và đó chính là lý do
	11 modal trôi dạt mỗi cái một kiểu (icon lệch 20/18/24, viền header 42/45, nút X 4 vị trí
	khác nhau). Tách ra thì phần "chỉnh cả game" nằm gọn trong một file đọc hết được trong một
	màn hình.
]]

local Tokens = {}

--[[
	══ FONT & ĐỘ DÀY VIỀN ═══════════════════════════════════════════════════════════════════

	  • `FONT` — font chữ TOÀN BỘ HUD. Fredoka One: chữ tròn, thân dày, đúng ngôn ngữ hình ảnh
	    của dòng simulator. Đổi một dòng này là đổi cả game — KHÔNG khai `Enum.Font.*` thẳng ở
	    file khác nữa.
	  • `BORDER` — độ dày viền đen của MỌI khối trong HUD. MỘT con số, không có bậc thứ hai.
]]
Tokens.FONT = Enum.Font.FredokaOne

--[[
	══ VIỀN ĐEN: MỘT ĐỘ DÀY DUY NHẤT CHO CẢ HUD (user chốt 2026-08-16) ══════════════════════

	User: "lấy stroke của UI Cosmetic làm kích thước chuẩn rồi áp cho toàn bộ HUD". Cosmetic
	dựng ở tỉ lệ 1.0 với viền 4, nên chuẩn = 4.

	Đo trong Studio TRƯỚC khi chốt (quét mọi `UIStroke` + mọi viền `MakeSurface`, đã nhân
	`UIScale` trên đường đi để ra px THẬT):
	    4.00px ×216   ← áp đảo, và đúng bằng Cosmetic
	    3.44 ×34 / 3.40 ×7   ← Shop (UIScale 0.86) và Rebirth (0.85) làm viền mỏng đi
	    3.00 ×26      ← vài chỗ tự khai 3
	    5.00 ×12      ← `Tokens.BORDER` cũ = 5 (mặc định của `MakeSurface`) + Toast
	Nói cách khác cả HUD đang có SÁU độ dày viền khác nhau. Giờ chỉ còn một.

	⚠️ `BORDER` cũ là 5 và `BORDER_INNER` là 4 — hai bậc. Đã BỎ bậc: `MakeButton`/`MakeMenuButton`
	không truyền `Border` nên rơi vào mặc định 5, tức là nút menu trái dày hơn thẻ Cosmetic đúng
	1px, và đó chính là chỗ user nhìn ra không đồng bộ. `BORDER_INNER` giữ lại làm bí danh để
	code cũ không vỡ, nhưng nó bằng luôn `BORDER`.

	⚠️ NGOẠI LỆ DUY NHẤT được phép: vành vàng của bánh xe Roulette (`MakeStroke(vàng, 6)`) —
	đó là chi tiết trang trí của bánh xe, không phải viền khung UI.
]]
Tokens.BORDER = 4
Tokens.BORDER_INNER = 4

--[[
	VIỀN CHỮ — MỘT CON SỐ DUY NHẤT CHO TOÀN BỘ HUD (user chốt 2026-08-15).

	⚠️ Đừng "cải tiến" thành viền tỉ lệ cỡ chữ. Đã thử đúng một vòng (2026-08-15 sáng): viền
	= 9% cỡ chữ, kẹp [2,5]. Về lý thuyết thì cân, nhưng thực tế trên màn hình nó thành ra
	CHỖ DÀY CHỖ MỎNG và user bác ngay — HUD này có hàng trăm nhãn nằm sát nhau, mắt so sánh
	nét viền giữa hai nhãn CẠNH nhau chứ không so với cỡ chữ của chính nhãn đó.

	An toàn trên màn nhỏ: `UIStroke` CÓ co theo `UIScale` (đã đo trong Studio), nên hằng này
	là design px giống mọi số đo khác — không cần nhân `viewportScale` bằng tay.
]]
Tokens.TEXT_STROKE = 4

--[[
	══ HỆ SỐ PHÓNG CỠ CHỮ TOÀN HUD (user 2026-08-16: "text khá nhỏ, khó nhìn") ═══════════════

	`MakeOutlineLabel` nhân `MaxTextSize` với hằng này. Sửa MỘT dòng là cả game chữ to lên.

	Vì sao chỉnh TRẦN chứ không chỉnh cỡ chữ: mọi nhãn trong HUD đều `TextScaled`, tức là chữ tự
	phình cho vừa Ô rồi bị `MaxTextSize` chặn lại. Nâng trần thì:
	  • nhãn nào đang bị TRẦN chặn (ô còn rộng, chữ vẫn nhỏ) sẽ to lên — đúng chỗ user kêu;
	  • nhãn nào đang bị Ô chặn thì không đổi một pixel nào, và KHÔNG BAO GIỜ tràn ô, vì
	    `TextScaled` luôn co lại cho vừa.
	Nói cách khác đây là phép nâng an toàn theo cấu tạo: không có cách nào làm vỡ bố cục.

	⚠️ Đừng đẩy quá tay. 1.15 là mức chữ chạm gần mép ô ở những nhãn chật nhất; cao hơn nữa thì
	chữ dính sát viền và đọc lại khó hơn lúc đầu.
]]
Tokens.TEXT_SCALE = 1.15

-- ── Canvas thiết kế ────────────────────────────────────────────────────────────────────────
Tokens.DESIGN_WIDTH = 1920
Tokens.DESIGN_HEIGHT = 1080
Tokens.MIN_SCALE = 0.12
Tokens.MAX_SCALE = 1

--[[
	══ HỆ RESPONSIVE — MỘT BẢN VẼ, MỘT TỈ LỆ (user chốt 2026-08-17) ══════════════════════════

	    scale = min(viewport.X / 1920, viewport.Y / 1080)

	Hết. Bản vẽ 1920×1080 là sự thật; mọi máy khác là bản vẽ đó THU NHỎ ĐỀU. Không có bố cục
	riêng cho mobile, không có cụm nào tự dịch ra mép máy, không có hằng nào theo cỡ màn hình.

	── HAI HỆ ĐÃ BỊ BÁC ───────────────────────────────────────────────────────────────────────
	  1. "boost" (2026-08-14): contain × 1.45 trên máy nhỏ — ba con số đoán bằng mắt.
	  2. "sàn ngón tay" (2026-08-17 sáng): tỉ lệ suy từ cỡ nút tối thiểu.

	  Cả hai đều phóng LỚN HƠN contain, tức bản vẽ TRÀN ra ngoài màn hình, nên buộc phải neo lại
	  từng cụm theo mép màn hình thật. Chính chỗ neo lại đó phá bố cục: trên iPhone XR (896×414,
	  tỉ lệ 2.16) bản vẽ bị cắt 164 design px chiều dọc, các cụm dồn vào phần còn thấy được, chữ
	  hệ số đè lên dải tutorial. User xem trên máy thật: "quá tệ".

	  Cái giá của thu nhỏ đều: máy khác 16:9 thừa ra hai dải ở rìa — nhưng đó là NỀN GAME nhìn
	  xuyên qua, không phải viền đen, và đổi lại bố cục y hệt bản thiết kế trên mọi máy.

	Đo thật: PC 1.000 · iPhone XR 896×414 → 0.383 · iPad 1024×768 → 0.533.

	⚠️ Nút nhỏ đi thì KHÔNG được chữa bằng cách phóng tỉ lệ (đã bác hai lần). Chữa bằng vùng chạm
	vô hình — xem `Responsive.AttachHitArea`.
]]

--[[
	══ LUẬT NGÓN TAY ════════════════════════════════════════════════════════════════════════

	Chỉ còn chi phối VÙNG CHẠM, không còn chi phối tỉ lệ.

	  • `MIN_PX`     — cạnh ngắn tối thiểu của một vùng chạm (px THẬT). Dưới mức này là "bấm mười
	                   lần trúng bảy". Chuẩn Roblox/Apple HIG đều là 44.
	  • `MAX_GROWTH` — trần nới vùng chạm. Nới quá tay thì vùng chạm hai nút cạnh nhau CHỒNG lên
	                   nhau và cướp cú bấm của nhau — người chơi bấm trúng mà ra sai chức năng,
	                   khó chịu hơn hẳn nút nhỏ.
]]
Tokens.TOUCH = {
	MIN_PX = 44,
	MAX_GROWTH = 1.6,
}

--[[
	══ PHÂN LOẠI THIẾT BỊ ═══════════════════════════════════════════════════════════════════

	Phân theo CẠNH NGẮN của viewport (px thật) + có cảm ứng hay không. Cạnh ngắn chứ không phải
	đường chéo hay diện tích: chiều cao là thứ khan hiếm nhất trong game landscape, và nó cũng
	là thứ quyết định ngón tay che mất bao nhiêu phần màn hình.

	Vì sao KHÔNG chỉ dựa vào `TouchEnabled`: máy tính bảng lai (Surface) và laptop cảm ứng đều
	báo `TouchEnabled = true` nhưng màn hình rộng như PC — ép chúng theo luật điện thoại là
	phóng UI to vô lý.

	Đo thật: iPhone landscape 735×413 ⇒ 413 ⇒ phone. iPad 1024×768 ⇒ 768 ⇒ tablet.
]]
Tokens.DEVICE = {
	PHONE_MAX_SHORT_AXIS = 500,
	TABLET_MAX_SHORT_AXIS = 900,
}

--[[
	══ KHUNG NỘI DUNG LỚN NHẤT (design px) ══════════════════════════════════════════════════

	⚠️ KHÔNG còn dính dáng gì tới tỉ lệ nữa. Thu nhỏ đều thì bản vẽ luôn nằm trọn trong màn hình,
	nên modal không bao giờ tràn — không cần trần tỉ lệ như hai hệ trước.

	Hai hằng này giờ chỉ dùng để CĂN modal trong bản vẽ (`Theme.GetModalCenter` /
	`Theme.ModalPosition`): chúng nói "chỗ dành cho modal to nhất rộng chừng này", từ đó suy ra
	còn dư bao nhiêu để nhích modal lên cho cân mắt.
]]
Tokens.SAFE_CONTENT_WIDTH = 1120
-- 740 = modal cao nhất 700 (ShopModal) + 8 viền (`CanvasGroup` phình ra `MODAL.BORDER` mỗi mép)
-- + 32 lề thở. ⚠️ Thêm modal cao hơn 700 thì phải nới hằng này.
Tokens.SAFE_CONTENT_HEIGHT = 740

--[[
	══ BÁN KÍNH BO GÓC ══════════════════════════════════════════════════════════════════════

	Bốn bậc, không hơn. `MakeSurface` tự suy bán kính NGOÀI = bán kính trong + viền, nên các
	con số dưới đây luôn là bán kính của PHẦN MÀU.

	Vì sao `HEADER` (10) nhỏ hơn `MODAL` (18): header nằm LỒNG trong vỏ modal, cộng viền 4 thành
	14 ở mép ngoài — nhỏ hơn vỏ đúng một nhịp, nên hai đường cong lồng vào nhau tự nhiên thay vì
	cắt nhau.
]]
Tokens.RADIUS = {
	MODAL = 18,
	--[[
		14, KHÔNG phải 10 (user chốt 2026-08-16: header phải "lấp đầy sát mép trong panel").

		`MakeSurface` tự suy bán kính NGOÀI = trong + viền, nên 14 + 4 = 18 = đúng bán kính vỏ
		modal. Nhờ vậy hai đường cong TRÙNG KHÍT thay vì lồng vào nhau — điều kiện để header ôm
		trọn phần trên của panel mà không lộ ra một khe hở nào ở hai góc.
	]]
	HEADER = 14,
	BUTTON = 10,
	-- Ô nhỏ nằm trong khối lớn: TextBox nhập liệu, badge, thẻ con.
	INNER = 14,
}

--[[
	══ TẦNG Z — BẢNG DUY NHẤT ═══════════════════════════════════════════════════════════════

	Trước đây mỗi modal tự chọn số (header chỗ 42 chỗ 45, icon/tiêu đề chỗ 44 chỗ 47 chỗ 48),
	nên khi thêm một lớp trang trí là phải dò lại bằng tay xem nó chui xuống dưới cái gì.

	Khoảng cách giữa các bậc để CHỪA CHỖ: `MakeSurface` chiếm zIndex, zIndex+1 (ruột màu) và
	zIndex+2 (lớp studs). Vì vậy hai bậc liền nhau phải cách nhau ít nhất 3.
]]
Tokens.Z = {
	-- Khung phủ toàn canvas, chỉ để bật/tắt hiển thị. Không vẽ gì.
	MODAL_ROOT = 38,
	-- Vỏ CanvasGroup của modal.
	MODAL_PANEL = 40,
	-- Nội dung thân modal (thẻ, danh sách, nhãn…).
	MODAL_CONTENT = 42,
	-- Thanh tiêu đề. Chiếm luôn 46 (ruột) và 47 (studs).
	MODAL_HEADER = 45,
	-- Icon + chữ tiêu đề: phải NẰM TRÊN lớp studs 47 của chính header.
	MODAL_HEADER_CONTENT = 48,
	-- Nút X. Chiếm luôn 51 (ruột) và 52 (chữ "X").
	MODAL_CLOSE = 50,
}

--[[
	══ NHỊP CHUYỂN ĐỘNG ═════════════════════════════════════════════════════════════════════

	`MODAL_TWEEN` là nhịp mở/đóng của CẢ 11 modal. Trước đây mỗi modal tự khai một
	`TweenInfo.new(0.18, Quad, Out)` trong State — muốn modal mở nhanh hơn phải sửa 11 dòng và
	chỉ cần sót một dòng là modal đó lệch nhịp với phần còn lại.

	⚠️ `MODAL_CLOSE_DELAY` PHẢI lớn hơn thời lượng `MODAL_TWEEN`. Nó là khoảng chờ trước khi gỡ
	modal khỏi màn hình (`Mounted = false`); gỡ sớm hơn hoạt ảnh là modal biến mất phụt một cái
	thay vì mờ dần.
]]
Tokens.MODAL_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Tokens.MODAL_CLOSE_DELAY = 0.22

-- Rê chuột / bấm nút. `Back` lúc thu nhỏ vọt nhẹ xuống dưới PRESS_SCALE rồi bật lại — đó chính
-- là cảm giác "nhấn lún" mong muốn.
Tokens.HOVER_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Tokens.HOVER_SCALE = 1.08
Tokens.PRESS_SCALE = 0.9

--[[
	══ KHUÔN MODAL — TOÀN BỘ SỐ ĐO CỦA VỎ + THANH TIÊU ĐỀ ═══════════════════════════════════

	    vỏ modal (rộng W)
	     └─ INSET 12 ─ header rộng W − 24, cao 84 ─ INSET 12 ─┘
	          └─ icon 68² tại (20, 8) ─ tiêu đề từ x=100 ─ … ─ nút X 66² sát mép phải ─┘

	── VÌ SAO NÚT X PHẢI TÍNH BẰNG CÔNG THỨC, KHÔNG ĐƯỢC GÕ TAY ────────────────────────────
	Đo lại 2026-08-16, 11 modal có 11 toạ độ X khác nhau và 5 cái SAI: Rebirth/Code/GroupChest/
	Daily đặt nút ở mép phải + 10px, Cosmetic + 4px — mà ruột `MakeSurface` có
	`ClipsDescendants = true`, nên nút X ở 5 modal đó đang bị CẮT CỤT bên phải. Không ai gõ tay
	11 lần mà đúng cả 11; vì vậy `ModalShell` suy toạ độ từ `CLOSE_MARGIN` và bề rộng vỏ.

	Căn dọc cũng vậy: (84 − 66) / 2 = 9 cho nút X, (84 − 68) / 2 = 8 cho icon. Trước đây rải
	rác 6/7/8/9 nên mỗi modal icon lệch tâm một kiểu.
]]
Tokens.MODAL = {
	--[[
		Lề của header tính từ mép vỏ modal — CHÍNH BẰNG ĐỘ DÀY VIỀN, không hơn.

		`MakeSurface` vẽ viền RA NGOÀI ô khai báo, nên khai ở (4,4) rộng W−8 thì mép ngoài của
		viền header rơi đúng (0,0)–(W, 92): ôm trọn phần trên của panel, không còn khe hở.

		⚠️ ĐỪNG để 0: viền khi đó nằm ở toạ độ ÂM, rơi ra ngoài `CanvasGroup` và bị cắt cụt —
		hai góc trên của modal thành vuông chằn. Cũng đừng để 12 như bản 2026-08-15: nó chừa
		4px nền panel lộ ra thành một đường viền thừa quanh header (user bác 2026-08-16).
	]]
	HEADER_INSET = 4,
	HEADER_HEIGHT = 84,
	-- Viền của vỏ modal và của header. Khác `Tokens.BORDER` (5) vì khối lớn để viền mảnh hơn
	-- trông mới cân — 5 trên tấm 1032px là quá nặng.
	BORDER = 4,
	--[[
		Độ trong của vỏ modal — cho nhìn xuyên thấy cảnh game phía sau.

		⚠️ Đây là NGOẠI LỆ DUY NHẤT không dùng `MakeSurface` được: viền kiểu mới là một khối ĐẶC
		nằm dưới, nên thân mờ sẽ hoà vào màu đen thay vì hoà vào cảnh — mất hẳn hiệu ứng kính mờ.
		Vỏ modal vì vậy giữ `UICorner + UIStroke`, và ở kích thước đó (viền 4 trên tấm 1032px)
		độ lệch pha pixel của UIStroke không nhìn ra được.
	]]
	PANEL_TRANSPARENCY = 0.3,

	--[[
		Lề trong của header, tính từ mép NGOÀI của nó (tức là từ mép panel).

		Icon và nút X phải cách mép panel BẰNG NHAU thì thanh tiêu đề mới cân. Vì header giờ khai
		ở (4,4), toạ độ nội dung lệch 4 so với panel — nên `ICON_X` = 16 cho ra lề thật 20, và
		`CLOSE_MARGIN` = 20 cũng cho ra lề thật 20 (nút X còn 4px viền vẽ ra ngoài nữa).
	]]
	EDGE_MARGIN = 20,

	ICON_SIZE = 68,
	ICON_X = 16, -- EDGE_MARGIN − HEADER_INSET
	ICON_Y = 8, -- (HEADER_HEIGHT − ICON_SIZE) / 2

	TITLE_X = 100,
	TITLE_Y = 5,
	TITLE_HEIGHT = 74,
	TITLE_MAX_TEXT_SIZE = 54,
	-- Khe giữa đuôi tiêu đề và nút X. Tiêu đề căn TRÁI nên khe này chỉ là chống đè, không ảnh
	-- hưởng cỡ chữ (`TextScaled` bị `TITLE_MAX_TEXT_SIZE` chặn trước).
	TITLE_GAP = 12,

	CLOSE_SIZE = 66,
	CLOSE_MARGIN = 20, -- khoảng cách từ mép phải header tới nút X (xem `EDGE_MARGIN`)
	CLOSE_Y = 9, -- (HEADER_HEIGHT − CLOSE_SIZE) / 2

	--[[
		Trượt lên khi mở. Modal đang mở nằm cao hơn modal đóng đúng chừng này — `Theme.ModalPosition`
		phải trừ nó ra khỏi trần nhích, không chừa là modal nhô lên khỏi mép trên màn hình
		(đã đo: Daily −1 px, Store −9 px).
	]]
	SLIDE = 18,
}

--[[
	══ MÀU DÙNG CHUNG ═══════════════════════════════════════════════════════════════════════

	CHỈ những màu xuất hiện ở NHIỀU màn hình. Màu nhận diện riêng của từng modal (header tím
	của Roulette, header hồng của Daily…) nằm trong chính file modal đó — đưa lên đây thì file
	này biến thành bảng màu 200 dòng và không ai tra được nữa.
]]
-- Bí danh cũ của `Tokens.TOUCH.MIN_PX` (SettingsModal đang gọi). Định nghĩa THẬT + toàn bộ lý do
-- nằm ở khối `LUẬT NGÓN TAY` đầu file — KHÔNG khai lại số 44 ở đây, hai nguồn sự thật là lệch.
Tokens.MIN_TOUCH_PX = Tokens.TOUCH.MIN_PX

--[[
	══ SÀN ĐỘ DÀY VIỀN (px THẬT) — HẠ TỪ 2.5 XUỐNG 1.2 NGÀY 2026-08-17 ══════════════════════

	Đây là van an toàn chống viền mỏng tới mức tàng hình trên cửa sổ tí hon. Nhưng để 2.5 thì nó
	KHÔNG CÒN là van an toàn nữa mà thành một cái "bố cục riêng cho mobile" trá hình — user nhìn
	ra ngay ("stroke trên di động bị lỗi so với PC"). Đo thật, viền khai 4 design px:

	    PC       scale 1.000 → dùng 4.00  (+0%)
	    Laptop   scale 0.711 → dùng 4.00  (+0%)
	    iPad     scale 0.533 → dùng 4.69  (+17%)
	    iPhone XR scale 0.383 → dùng 6.53 (+63%)   ← viền dày gấp rưỡi so với bản vẽ
	    Cửa sổ nhỏ 0.326     → dùng 7.67 (+92%)

	Sàn chỉ được phép là LƯỚI AN TOÀN CHO TRƯỜNG HỢP CỰC ĐOAN, không được đụng tới máy thật. Với
	1.2 thì nó chỉ kích hoạt khi `scale < 0.3` — tức nhỏ hơn cả iPhone SE ngang — nên MỌI thiết bị
	thật đều giữ ĐÚNG tỉ lệ viền của bản vẽ.

	Vì sao 1.2 là đủ: viền của `MakeSurface` KHÔNG phải `UIStroke` mà là một khối đặc lộ ra
	(xem `MakeSurface`), nên nó không bị khử răng cưa làm biến mất như `UIStroke` — 1.2px vẫn ra
	một hàng pixel đặc. Con số 2.5 cũ được chọn cho `UIStroke` kiểu cũ, đã không còn dùng.
]]
Tokens.MIN_BORDER_PX = 1.2

Tokens.COLOR = {
	-- Viền đen chuẩn của mọi khối.
	OUTLINE = Color3.fromRGB(0, 0, 0),
	-- Viền đen "ngả xanh" của header shop-style — mềm hơn đen tuyệt đối trên nền vàng.
	OUTLINE_SOFT = Color3.fromRGB(18, 18, 30),
	TEXT = Color3.fromRGB(255, 255, 255),
	--[[
		Xanh của nhãn giá Robux (user chốt màu 2026-08-16 theo ảnh tham chiếu).

		Cũ là (62,226,133) — xanh bạc hà, ngả lam. Ảnh user gửi cho thấy màu phải VIVID và ngả
		VÀNG hơn hẳn (xanh cỏ/lime) thì mới bật lên khỏi nền cát sáng và nền nút vàng.

		Một dòng này chi phối CẢ BA chỗ user nhắc — badge x2/x4/x8 Speed, thẻ Starter Pack, và
		nút Revive — vì cả ba đều đi qua `Theme.MakePriceLabel`.
	]]
	PRICE = Color3.fromRGB(104, 232, 40),
	-- Nút X: thường / khi rê chuột.
	CLOSE = Color3.fromRGB(211, 39, 49),
	CLOSE_HOVER = Color3.fromRGB(255, 92, 84),
}

return Tokens
