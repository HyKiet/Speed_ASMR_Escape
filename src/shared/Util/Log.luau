--!strict
--[[
	Log.luau — cổng chặn cho các dòng in lúc KHỞI ĐỘNG.

	══ VÌ SAO CÓ FILE NÀY (2026-08-24) ═════════════════════════════════════════════════════

	Mỗi service/controller in đúng một dòng "sẵn sàng" lúc nạp. Từng dòng thì vô hại, nhưng
	cộng lại là **~95 dòng đổ ra Output trong 6 giây đầu**, trong đó riêng sàn ASMR chiếm
	~40 dòng lặp gần như y hệt nhau ("[ASMR Clay] sẵn sàng — 16 ô" × 16 lần). Hệ quả thật:
	một `warn` thật sự bị đẩy trôi khỏi màn hình trước khi kịp đọc, và mỗi lần debug đều phải
	cuộn ngược qua một bức tường chữ.

	⚠️ NHƯNG KHÔNG ĐƯỢC XOÁ HẲN. Khối `[CLIENT LOADING] … [CLIENT READY] Đã nạp N` là công cụ
	chẩn đoán mà dự án ĐANG DỰA VÀO: bootstrapper client từng nạp thiếu controller trong im
	lặng, và cách duy nhất phát hiện là so con số N. Xoá là mù luôn lớp đó.

	Nên: các dòng khởi động vẫn còn nguyên trong code, chỉ bị TẮT TIẾNG theo mặc định.

	══ BẬT LẠI ═══════════════════════════════════════════════════════════════════════════

	Hai cách, không cần sửa file này:
	  • Trong Studio — chạy `game:SetAttribute("SEVerboseBoot", true)` ở Command Bar RỒI Play.
	    (Phải đặt TRƯỚC khi Play: các dòng này in đúng một lần lúc nạp, đặt sau là lỡ mất.)
	  • Trong game đã publish — đặt cùng attribute đó từ một script server.

	Ba mức, cố ý ít:
	  • `Log.Boot`  — dòng "sẵn sàng" lúc nạp. IM LẶNG trừ khi bật verbose.
	  • `Log.Info`  — sự kiện đáng chú ý lúc CHẠY (mua pass, reset tutorial…). LUÔN in.
	  • `Log.Floor` — riêng cho sàn ASMR: gom lại, in đúng MỘT dòng tổng kết.
	Cần cảnh báo thì vẫn dùng `warn` thẳng — `warn` không bao giờ bị cổng này chặn.
]]

local Log = {}

local VERBOSE_ATTRIBUTE = "SEVerboseBoot"

local function verbose(): boolean
	return game:GetAttribute(VERBOSE_ATTRIBUTE) == true
end

-- Dòng khởi động. Im lặng theo mặc định — xem khối "BẬT LẠI" ở trên.
function Log.Boot(...: any)
	if verbose() then
		print(...)
	end
end

-- Sự kiện lúc chạy, luôn in. Đây là thứ đáng để chiếm chỗ trong Output.
function Log.Info(...: any)
	print(...)
end

--[[
	══ GOM SÀN ASMR ═══════════════════════════════════════════════════════════════════════

	35 model sàn attach BẤT ĐỒNG BỘ trong khoảng 3–6 giây (mỗi cái chờ `Tiles`/`Blocks`
	replicate xong), nên không có một thời điểm nào biết chắc "đã xong hết". Vì vậy dùng
	hẹn giờ trượt: mỗi lần có sàn mới báo danh thì đẩy lịch in lùi thêm `SETTLE_SECONDS`.
	Sàn cuối cùng attach xong thì 1,5 giây sau in đúng một dòng tổng.

	Dòng tổng vẫn giữ đủ thông tin để chẩn đoán — số lượng theo TỪNG LOẠI và tổng số ô:
	    [ASMR] 35 sàn sẵn sàng — Clay×16 BubbleWrap×10 Keyboard×8 KineticSandLive×1 (5.468 ô)
	Thiếu một loại hay hụt số ô là nhìn ra ngay, y như đọc 40 dòng cũ nhưng trong một dòng.

	⚠️ Sàn init hụt là chết câm vĩnh viễn (không log, không lỗi). Dòng tổng này chính là chỗ
	phát hiện: số sàn ít hơn số model mang tag `ASMRFloor` nghĩa là có cái không attach nổi.
]]
local SETTLE_SECONDS = 1.5

local floorCounts: { [string]: number } = {}
local floorCells: { [string]: number } = {}
local floorTotal = 0
local cellTotal = 0
local pendingToken = 0

local function formatThousands(n: number): string
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (out:gsub("^%.", ""))
end

local function flushFloors()
	local parts: { string } = {}
	local names: { string } = {}
	for name in floorCounts do
		table.insert(names, name)
	end
	-- Sắp theo số lượng giảm dần để loại đông nhất đứng trước; trùng số thì theo tên cho
	-- dòng in ổn định giữa các phiên (dễ so hai lần chạy với nhau).
	table.sort(names, function(a, b)
		if floorCounts[a] ~= floorCounts[b] then
			return floorCounts[a] > floorCounts[b]
		end
		return a < b
	end)
	for _, name in names do
		table.insert(parts, ("%s×%d"):format(name, floorCounts[name]))
	end
	print(
		("[ASMR] %d sàn sẵn sàng — %s (%s ô)"):format(
			floorTotal,
			table.concat(parts, " "),
			formatThousands(cellTotal)
		)
	)
end

-- `cells` là số ô/phím/bóng của riêng sàn đó. Sàn không đếm được thì truyền 0.
function Log.Floor(name: string, cells: number)
	floorCounts[name] = (floorCounts[name] or 0) + 1
	floorCells[name] = (floorCells[name] or 0) + cells
	floorTotal += 1
	cellTotal += cells

	pendingToken += 1
	local token = pendingToken
	task.delay(SETTLE_SECONDS, function()
		-- Có sàn khác báo danh sau mình ⇒ nhường lượt in cho nó.
		if token == pendingToken then
			flushFloors()
		end
	end)
end

return Log
