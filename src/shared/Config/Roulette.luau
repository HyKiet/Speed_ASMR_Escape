--!strict
--[[
	Cấu hình Vòng quay May mắn (Speed Roulette) — 8 ô.
	Thứ tự SLOTS xếp theo GIÁ TRỊ TĂNG DẦN.
	(Sửa 2026-08-23: lý do gốc của quy ước này là "Extra Spin gamepass chọn slot index cao
	hơn" — pass đó đã gỡ 2026-07-31 và không còn logic quay đôi. Vẫn giữ thứ tự tăng dần vì
	nó là quy ước dễ đọc, nhưng giờ KHÔNG còn code nào phụ thuộc vào nó.)

	── CÂN BẰNG LẠI 2026-08-10 (user: "cân bằng hơn nhưng vẫn kích thích") ────────────────
	Bảng cũ hỏng ở HAI đầu cùng lúc, vì phần thưởng là số CỐ ĐỊNH còn thu nhập của người chơi
	thì tăng theo cấp số nhân:

	  • ĐẦU GAME BỊ PHÁ: ô thường nhất cho +500 Wins — đúng bằng mốc mở Pad 5. Người chơi mới
	    có 3 Wins, quay một cái là nhảy thẳng qua Pad 2/3/4, tức là bỏ qua toàn bộ 4 stage đầu
	    và cả cái vòng lặp mà game được xây quanh nó. Vé miễn phí 15 phút/vé nên chuyện này
	    xảy ra với MỌI người chơi mới, không phải trường hợp hiếm.
	  • CUỐI GAME VÔ NGHĨA: +500 Wins với tài khoản kiếm 500 Wins mỗi lượt Stage 9 là con số
	    không đáng bấm nút.

	Hướng sửa (giữ nguyên 8 ô + thang hiếm, chỉ đổi con số và trọng số):

	  1. KÉO WINS XUỐNG, ĐẨY SPEED LÊN. Wins là tiền CỨNG (mở pad, trả phí teleport, không hồi
	     lại); Speed là tiền MỀM (chỉ đẩy Level, mất trắng khi rebirth). Muốn số to gây phê mà
	     không lạm phát thì cho số to ở SPEED. EV Wins/lượt: 1.400 → 782 (−44%); EV Speed/lượt:
	     4.250 → 12.200 (gần gấp 3).
	  2. Ô THƯỜNG NHẤT = 250 Wins: đủ để người mới thấy "được thật" nhưng KHÔNG chạm mốc Pad 5
	     (500) — họ vẫn phải chạy obby để lên pad, vòng quay chỉ rút ngắn chứ không thay thế.
	  3. HAI Ô BOOST GIỮ NGUYÊN và là chỗ dựa cho end-game: x2 trong 10 phút tự động đáng giá
	     theo thu nhập HIỆN TẠI của người chơi, nên không bao giờ lỗi thời — khác hẳn số cố định.
	  4. Jackpot Wins hạ 15K→8K và hiếm hơn (6%→ vẫn 6%): 15K vượt mốc Pad 7, biếu không một
	     bậc sức mạnh giữa game.

	⚠️ KHÔNG nhân phần thưởng theo rebirth để "hợp end-game": nhãn trên vòng quay là LỜI HỨA
	người chơi đọc trước khi bấm: quay ra "+10K Speed" mà nhận số khác là mất niềm tin vào cả
	hệ thống. Muốn end-game vẫn thèm quay thì tăng giá trị hai ô boost, đừng đụng vào số hiển thị.

	⚠️ Tổng weight PHẢI = 100 để cột `rarity` (chuỗi hiển thị trên UI) đúng là phần trăm thật.

	── CÂN LẠI LẦN HAI 2026-08-27 (user: "phần thưởng wins của spin đang khá lớn") ───────────
	Bản 10/08 ở trên đi ĐÚNG HƯỚNG nhưng chưa đủ xa. Số liệu Economy thật (28 ngày) nói rõ:

	    roulette    61 giao dịch → 126.175 Wins  =  2.068 Wins/lượt
	    stage      592 giao dịch →  37.581 Wins  =      63 Wins/lượt   ← vòng lặp LÕI

	Một vòng quay bằng 33 lần vượt stage. Vòng quay không còn là gia vị nữa — nó LÀ nền kinh tế,
	còn obby thành thứ trang trí.

	Và luận điểm "250 không chạm mốc Pad 5 (500)" của bản trước chỉ đúng một nửa: nó bỏ sót ba
	pad NGAY TRƯỚC đó. Thang giá pad là 1 / 15 / 100 / 500 — một ô thường 250 Wins nhảy thẳng
	qua Pad 2, 3 VÀ 4. Vé miễn phí về sau 15 phút một cái, nên chuyện này xảy ra với gần như
	mọi người chơi mới, đúng trong phiên đầu tiên mà game đang mất 2/3 số người.

	Bản này giữ nguyên triết lý cũ (Wins = tiền cứng, Speed = tiền mềm, boost tự co giãn theo
	thu nhập) và đẩy nó tới nơi tới chốn:

	  1. Kéo mọi ô Wins xuống dưới mốc pad gần nhất.
	  2. Phần dopamine dồn về SPEED. EV Speed/lượt 12.200 → 13.300.
	  3. Hai ô boost nới 10 → 15 phút và tăng weight: đây là thứ DUY NHẤT tự co giãn theo thu
	     nhập hiện tại của người chơi, nên là chỗ dựa đúng cho end-game.

	── SỬA LẠI LẦN BA 2026-08-27 (user: "giảm quá đà, mất giá trị của spin, không bán được gói") ──
	Lần hai kéo EV Wins 782 → 242 (−69%). Quá tay, và cái hỏng thấy được ngay:

	  • Ô thường 50 Wins gần như là không có gì với bất kỳ ai đã chơi quá mười phút.
	  • Jackpot 2.000 Wins chỉ nhỉnh hơn ô 16% đúng ba lần — không đủ để gọi là jackpot.
	  • Ba gói vé Robux (19/79/149 R$) mất lý do tồn tại: bỏ tiền thật để đổi lấy một EV
	    nhỏ hơn một lượt chạy stage giữa game là một món không ai mua.

	Chỗ sai nằm ở LUẬT, không phải ở con số: "mọi ô Wins phải dưới một mốc pad" nghe hợp lý
	nhưng thang giá pad là 1 / 15 / 100 / 500 / 2.500 / 15.000 / 50.000 — khoảng cách quá thưa,
	nên luật đó ép mọi ô xuống đáy của khoảng chứa nó. Nó tối ưu TRỌN VẸN cho người chơi mới
	và bỏ rơi tất cả những người còn lại.

	Luật thay thế — chỉ ràng buộc đúng chỗ cần ràng buộc:

	  1. **Chỉ Ô THƯỜNG NHẤT phải dưới một mốc pad** (75 < 100 = Pad 4). Đó là ô mà người chơi
	     mới gần như chắc chắn trúng ở vé chào mừng trong tutorial, và là chỗ duy nhất việc
	     nhảy cóc pad thật sự phá vòng lặp lõi. Ba ô Wins còn lại được thả ra.
	  2. **Jackpot phải TO.** 5.000 Wins ở 6% — đây là thứ gánh phần lớn lý do mua gói vé.
	  3. EV Wins/lượt: 782 → **493** (−37%), tính cả ô đền bù aura. So với 63 Wins/stage thì
	     còn ~7,8 lần: đủ để một cú may mắn đáng hò reo và đủ để gói vé có nghĩa, nhưng không
	     còn là 33 lần như số liệu Economy đo được (2.068 Wins/lượt).
	  4. SPEED vẫn KHÔNG được thả nổi. Nó là tiền mềm (mất trắng khi rebirth) nhưng vẫn quy ra
	     Level ⇒ WalkSpeed ⇒ quyền vào stage. Xem hai khối ⚠️ ở `speed_15k` và `speed_200k`:
	     trần của chúng do `Formulas.GetRequiredXP` cộng dồn quyết định, không phải do bảng này
	     tự chọn.

	⚠️ Trước khi đụng vào bất kỳ con số nào ở dưới, đọc lại điểm 1: nó là ràng buộc DUY NHẤT
	còn lại nối bảng này với `Economy/MultiplierPads`. Đổi giá `pad_4` thì phải sửa ô thường theo.
]]

export type RouletteSlot = {
	id: string,
	label: string,
	kind: "speed" | "wins" | "boostSpeed" | "boostWins" | "aura",
	-- speed/wins: lượng cộng thẳng; boost: số giây buff; aura: Wins đền bù nếu đã sở hữu
	amount: number,
	auraId: string?,
	weight: number,
	rarity: string,
	color: Color3,
}

local Roulette = {}

Roulette.FREE_TICKET_INTERVAL_SECONDS = 15 * 60 -- 15 phút online = 1 vé
Roulette.FREE_TICKET_STOCK_CAP = 3 -- vé miễn phí chỉ tích trữ tối đa 3
Roulette.MAX_TICKETS = 99 -- trần tuyệt đối (mua Robux/daily vẫn bị kẹp)

--[[
	QUYỀN LỢI VIP MEMBERSHIP (2026-08-12) — hồi vé nhanh gần gấp đôi + tích được nhiều hơn.

	Vì sao 8 phút chứ không phải 5: 5 phút là x3 tốc độ, đủ để một buổi chơi dài tự cày ra
	Frozen Bloom (1%, trung bình ~100 lượt) mà không cần đụng tới gói vé Robux — tức VIP tự
	ăn thịt cả ba Dev Product 19/79/149 R$. Ở 8 phút thì VIP rút ngắn thời gian CHỜ, còn ai
	muốn quay NGAY vẫn phải mua vé; đó là ranh giới cần giữ.

	Trần 5 (thay vì 3) để người AFK lâu không phí giờ tích — nhưng vẫn phải ONLINE mới hồi,
	và cơ cấu ô không đổi một chữ nào: VIP không mua được jackpot, chỉ được quay thường xuyên hơn.
]]
Roulette.VIP_TICKET_INTERVAL_SECONDS = 8 * 60
Roulette.VIP_TICKET_STOCK_CAP = 5

Roulette.SLOTS = {
	--[[
		⚠️ Ô THƯỜNG NHẤT: 50 < 53 = tổng giá pad_2 + pad_3 + pad_4.

		Đây là ô người chơi mới gần như chắc chắn trúng ở vé chào mừng trong tutorial. Giữ nó
		dưới tổng ba pad đầu là chốt chặn duy nhất còn lại nối bảng này với `Economy/MultiplierPads`
		— trúng ô thường vẫn không tự mua nổi ba pad, vẫn phải chạy obby.
	]]
	{
		id = "wins_50",
		label = "+50 Wins",
		kind = "wins",
		amount = 50,
		weight = 25,
		rarity = "25%",
		color = Color3.fromRGB(255, 205, 46),
	},
	{
		id = "speed_15k",
		label = "+15K Speed",
		kind = "speed",
		-- Soi vào đường cong XP mới: +15.000 đưa người chơi vừa reset lên Level 30 (WS 72),
		-- vừa đủ mở Stage 4. Mọi ô Speed phải soi vào `Formulas.GetCumulativeXP`, không phải
		-- soi vào các ô khác trên cùng bánh xe.
		amount = 15_000,
		weight = 22,
		rarity = "22%",
		color = Color3.fromRGB(120, 200, 255),
	},
	{
		id = "wins_400",
		label = "+400 Wins",
		kind = "wins",
		amount = 400,
		weight = 16,
		rarity = "16%",
		color = Color3.fromRGB(104, 234, 95),
	},
	{
		id = "boost_speed",
		label = "x2 Speed 15m",
		kind = "boostSpeed",
		-- Hai ô boost là thứ DUY NHẤT trên bánh xe tự co giãn theo thu nhập hiện tại của người
		-- chơi, nên chúng là toàn bộ giá trị end-game của hệ thống này.
		amount = 900,
		weight = 15,
		rarity = "15%",
		color = Color3.fromRGB(72, 220, 200),
	},
	{
		id = "boost_wins",
		label = "x2 Wins 15m",
		kind = "boostWins",
		amount = 900,
		weight = 12,
		rarity = "12%",
		color = Color3.fromRGB(90, 130, 255),
	},
	{
		id = "wins_4k",
		label = "+4K Wins",
		kind = "wins",
		-- 4.000 < 4.273 = tổng giá pad_2..pad_7. Một cú may mắn vẫn không mua đứt cả thang pad.
		amount = 4_000,
		weight = 6,
		rarity = "6%",
		color = Color3.fromRGB(186, 90, 255),
	},
	{
		id = "speed_400k",
		label = "+400K Speed",
		kind = "speed",
		-- Con số to nhất bánh xe nằm ở Speed chứ không phải Wins: Speed là tiền MỀM (mất trắng
		-- khi trùng sinh), Wins là tiền CỨNG. Đổ dopamine ở tiền mềm thì không gây lạm phát.
		-- +400.000 → Level 49 (WS 110) cho người vừa reset.
		amount = 400_000,
		weight = 3,
		rarity = "3%",
		color = Color3.fromRGB(255, 110, 80),
	},
	{
		id = "aura_frozen_bloom",
		label = "FROZEN BLOOM",
		kind = "aura",
		auraId = "aura_frozen_bloom",
		-- Đền bù khi ĐÃ sở hữu aura. Đây là lý do bánh xe không bao giờ hết giá trị: một aura
		-- x10 nằm trong xô Cosmetic vĩnh viễn, đáng giá y hệt với người Level 20 và người R15.
		-- Ba gói vé Robux bán chính món này, không phải bán mấy ô Wins.
		amount = 10_000,
		weight = 1,
		rarity = "1%",
		color = Color3.fromRGB(255, 60, 180),
	},
} :: { RouletteSlot }
return Roulette
