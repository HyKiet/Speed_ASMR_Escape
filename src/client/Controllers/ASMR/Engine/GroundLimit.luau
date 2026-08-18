--!strict
--[[
	GroundLimit — trả lời đúng MỘT câu hỏi: "sàn này được phép lún sâu bao nhiêu
	trước khi chọc thủng mặt đất bên dưới?"

	VÌ SAO CÓ MODULE NÀY (2026-08-04): trước đây người chơi đứng trên `WalkSurface` —
	tấm slab vô hình cắt ngang LƯNG CHỪNG deco (phím cao 2.0 stud thì slab nằm ở 1.0).
	Đường chạy vì thế lên xuống bậc 0.4–1.6 stud mỗi lần vào/ra một sàn ASMR. Nay slab
	đã tắt collision: chân người chơi đặt thẳng lên Ground thật, deco nhô lên quanh chân.

	Hệ quả: độ lún phải quy chiếu về MẶT ĐẤT, không còn là một hằng số chung.
	  • Sàn lún bằng DỊCH CHUYỂN (Keyboard, PopIt) lún quá tay là deco chui tụt xuống
	    dưới mặt đất rồi biến mất.
	  • Sàn lún bằng CO TỈ LỆ (SquishFloor, Clay, GummySquish) neo đáy ô nên không bao
	    giờ chọc thủng — chúng không cần module này.

	MỐC CHỐT (user 2026-08-04): đỉnh deco khi lún hết cỡ dừng cách mặt đất `CLEARANCE`.
	Không cho bằng 0: hai mặt phẳng trùng cao độ là z-fighting nhấp nháy.

	Sàn nào KHÔNG có đất bên dưới (lobby, sàn bắc qua vực như Zone5 PopIt / Zone7 Jelly)
	thì `maxSink` trả về nil và floor giữ nguyên hằng số cũ — đó là cách lobby và hai
	đoạn cầu đó không bị đụng tới mà không cần liệt kê tên chúng ở bất cứ đâu.
]]

local CollectionService = game:GetService("CollectionService")

local GroundLimit = {}

local CLEARANCE = 0.15 -- đỉnh deco lún sâu nhất vẫn còn nhô ngần này trên mặt đất
local PROBE = 14 -- dò xuống bấy nhiêu stud tính từ đáy deco

-- Bề mặt tìm được chỉ được coi là "mặt đất deco đang đứng lên" khi nó nằm NGANG hoặc
-- THẤP HƠN đáy deco, sai số ngần này. Ngưỡng chính là thứ phân biệt hai trường hợp
-- nhìn giống nhau trong raycast:
--   • bóng BubbleWrap là chỏm cầu chôn nửa dưới ⇒ mặt đất cao hơn đáy bóng 0.70 → NHẬN
--   • ô PopIt/Jelly nằm LỌT trong tấm cơ chế của zone (SlideFloor / JellyBridge), mặt
--     tấm cao hơn đáy ô 1.25–2.40 ⇒ đó không phải nền, mà là ruột của một cơ chế khác;
--     kẹp lún theo nó là tự dưng đổi cảm giác hai đoạn không ai yêu cầu → BỎ QUA
local EMBED_SLACK = 0.8

-- Danh sách loại trừ: mọi sàn ASMR (kể cả chính nó) — ta đi tìm NỀN, không phải hàng xóm.
-- Dựng lại mỗi lần gọi vì hàm này chỉ chạy một lần cho mỗi sàn lúc attach.
local function makeParams(): RaycastParams
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = CollectionService:GetTagged("ASMRFloor")
	rp.IgnoreWater = true
	return rp
end

--[[
	Cao độ mặt đất ngay dưới `pos`, hoặc nil nếu không có nền hợp lệ.
	`bottomY` = đáy deco lúc nghỉ (dùng cho phép thử EMBED_SLACK ở trên).
]]
function GroundLimit.topUnder(model: Instance, pos: Vector3, bottomY: number): number?
	-- Lobby không đụng tới (yêu cầu user): chỉ 15 zone mới quy chiếu về mặt đất.
	local zones = workspace:FindFirstChild("Zones")
	if not (zones and model:IsDescendantOf(zones)) then
		return nil
	end

	local from = Vector3.new(pos.X, bottomY + 1, pos.Z)
	local hit = workspace:Raycast(from, Vector3.new(0, -(PROBE + 1), 0), makeParams())
	if not hit then
		return nil
	end
	if hit.Position.Y > bottomY + EMBED_SLACK then
		return nil
	end
	return hit.Position.Y
end

--[[
	Độ lún tối đa cho một deco có đỉnh nghỉ ở `restTopY`, hoặc nil nếu không rõ mặt đất.
	Trả về 0 (không phải số âm) khi deco vốn đã nằm dưới mốc — lún thêm chỉ tổ chôn nó.
]]
function GroundLimit.maxSink(restTopY: number, groundTop: number?): number?
	if not groundTop then
		return nil
	end
	return math.max(restTopY - CLEARANCE - groundTop, 0)
end

return GroundLimit
