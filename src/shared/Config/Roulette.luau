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
	{
		id = "wins_250",
		label = "+250 Wins",
		kind = "wins",
		-- 250 là trần cố ý: mốc Pad 5 = 500 Wins. Xem điểm 2 trong khối cân bằng ở đầu file.
		amount = 250,
		weight = 25,
		rarity = "25%",
		color = Color3.fromRGB(255, 205, 46),
	},
	{
		id = "speed_10k",
		label = "+10K Speed",
		kind = "speed",
		amount = 10_000,
		weight = 22,
		rarity = "22%",
		color = Color3.fromRGB(120, 200, 255),
	},
	{
		id = "wins_1500",
		label = "+1.5K Wins",
		kind = "wins",
		amount = 1_500,
		weight = 16,
		rarity = "16%",
		color = Color3.fromRGB(104, 234, 95),
	},
	{
		id = "boost_speed",
		label = "x2 Speed 10m",
		kind = "boostSpeed",
		amount = 600,
		weight = 14,
		rarity = "14%",
		color = Color3.fromRGB(72, 220, 200),
	},
	{
		id = "boost_wins",
		label = "x2 Wins 10m",
		kind = "boostWins",
		amount = 600,
		weight = 11,
		rarity = "11%",
		color = Color3.fromRGB(90, 130, 255),
	},
	{
		id = "wins_8k",
		label = "+8K Wins",
		kind = "wins",
		-- 8K nằm GIỮA Pad 6 (2.5K) và Pad 7 (15K): jackpot thật sự đáng hò reo mà không
		-- biếu không cả một bậc pad.
		amount = 8_000,
		weight = 6,
		rarity = "6%",
		color = Color3.fromRGB(186, 90, 255),
	},
	{
		id = "speed_200k",
		label = "+200K Speed",
		kind = "speed",
		-- Con số TO NHẤT của vòng quay nằm ở Speed chứ không phải Wins — đây là chỗ đổ dopamine
		-- mà không đụng tới tiền cứng.
		amount = 200_000,
		weight = 5,
		rarity = "5%",
		color = Color3.fromRGB(255, 110, 80),
	},
	{
		id = "aura_frozen_bloom",
		label = "FROZEN BLOOM",
		kind = "aura",
		auraId = "aura_frozen_bloom",
		-- Đền bù khi đã sở hữu: hạ 50K → 25K cho khớp mặt bằng Wins mới (vẫn là giải an ủi
		-- lớn nhất bảng).
		amount = 25_000,
		weight = 1,
		rarity = "1%",
		color = Color3.fromRGB(255, 60, 180),
	},
} :: { RouletteSlot }

return Roulette
