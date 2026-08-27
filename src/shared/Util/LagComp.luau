--!strict
--[[
	LagComp.luau — BÙ TRỄ MẠNG cho phán xử bẫy phía server.

	── VẤN ĐỀ (user đo 2026-08-27: ping 390ms trên PC, ~350ms trên iPhone 13) ──────────────
	Kiến trúc bẫy của game là "render ở client, phán xử ở server" (xem ghi chú kiến trúc
	bẫy zone). Client dựng hình bẫy tại thời điểm T bằng đồng hồ tất định,
	nên thứ người chơi NHÌN THẤY là bẫy-tại-T. Nhưng phía server:

	  • `root.Position` KHÔNG phải vị trí hiện tại của người chơi. Client là network owner
	    của nhân vật, nên vị trí đó là ảnh chụp cách đây ĐÚNG MỘT CHIỀU TRỄ MẠNG.
	  • `GetServerTimeNow()` thì lại là BÂY GIỜ.

	Server đang so vị-trí-quá-khứ với bẫy-hiện-tại. Ở 60ms ping sai lệch nhỏ nên không ai
	để ý; ở 390ms thì nó phá tan phép phán xử. Đo trên chính hình học laser Zone 2
	(beam bán kính 35, rpm 28 ⇒ ω = 2.93 rad/s):

	    trễ một chiều 0.195s × 2.93 rad/s = 0.57 rad
	    ⇒ tại bán kính 30, beam mà server dùng để phán xử NẰM CÁCH beam người chơi nhìn thấy
	      **17 studs**, trong khi cửa sổ trúng chỉ rộng 4.5 studs.

	Nói cách khác: ở ping cao, server và client phán xử trên HAI cái laser khác nhau. Người
	chơi thấy mình né sạch vẫn chết, hoặc chạy xuyên qua beam mà không sao — đúng hai lời
	phàn nàn "laser không chính xác".

	── CÁCH CHỮA ────────────────────────────────────────────────────────────────────────────
	Lùi ĐỒNG HỒ CỦA BẪY về đúng thời điểm mà vị trí người chơi được chụp. Server dựng lại
	bẫy tại `GetServerTimeNow() - Delay(player)` rồi mới so với `root.Position`. Cả hai vế
	giờ cùng thuộc về một mốc thời gian, và mốc đó chính là khung hình người chơi đã thấy.

	Đây là lag compensation tiêu chuẩn của thể loại bắn súng, áp cho bẫy. Nó KHÔNG mở ra lỗ
	hổng nào: người chơi không điều khiển được `GetNetworkPing()`, và thứ tệ nhất một kẻ giả
	ping cao có thể làm là bị phán xử theo một quá khứ xa hơn — vẫn là quá khứ của chính họ.

	── VÌ SAO KẸP TRẦN ──────────────────────────────────────────────────────────────────────
	Trễ vượt `MAX_DELAY` thì không còn bù được nữa: đoạn đường người chơi đi trong ngần ấy
	thời gian dài hơn cả cái bẫy, mọi phép nội suy đều là bịa. Kẹp lại và chấp nhận sai số
	còn hơn lùi đồng hồ về một chỗ vô nghĩa.
]]

local Players = game:GetService("Players")

local LagComp = {}

-- `Player:GetNetworkPing()` trả về trễ MỘT CHIỀU (server → client) tính bằng GIÂY.
-- Đây đã đúng đơn vị cần dùng, không chia đôi.
local MAX_DELAY = 0.40
-- Dưới mức này thì bù cũng như không — bỏ qua để đường chạy phổ biến (LAN/Studio) rẻ nhất.
local MIN_DELAY = 0.02

--[[
	Trễ một chiều của `player`, đã kẹp. Trả 0 nghĩa là "không cần bù".

	Làm mượt bằng trung bình trượt: `GetNetworkPing()` nhảy khá mạnh giữa các mẫu, mà con số
	này đi thẳng vào GÓC của bẫy — nhiễu ở đây biến thành beam giật qua giật lại trong phép
	phán xử. Hệ số 0.15 cho hằng số thời gian ~0.4s: đủ nhanh để theo kịp lúc mạng đổi trạng
	thái, đủ chậm để một mẫu lỗi không giết oan ai.
]]
local smoothed: { [Player]: number } = {}
local SMOOTH_ALPHA = 0.15

function LagComp.Delay(player: Player): number
	local raw = player:GetNetworkPing()
	if raw ~= raw then -- NaN phòng thân
		raw = 0
	end
	local prev = smoothed[player]
	local value = if prev then prev + (raw - prev) * SMOOTH_ALPHA else raw
	smoothed[player] = value
	if value < MIN_DELAY then
		return 0
	end
	return math.min(value, MAX_DELAY)
end

Players.PlayerRemoving:Connect(function(player)
	smoothed[player] = nil
end)

return LagComp
