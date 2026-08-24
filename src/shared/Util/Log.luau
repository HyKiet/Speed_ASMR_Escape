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

	══ ⚠️ TRÊN LIVE, CLIENT KHÔNG IN GÌ CẢ (2026-08-24) ═══════════════════════════════════

	Bảng Developer Console (F9) mở được cho MỌI người chơi, và tab **Client** thì ai cũng đọc
	được — chỉ tab Server mới giới hạn cho người có quyền sửa place. Nghĩa là mọi dòng client
	in ra ở bản đã publish là công khai: số controller đã nạp, số sàn ASMR từng loại, thời
	gian nạp, ngưỡng tốc độ của từng zone. Đó là bản đồ kiến trúc game phát miễn phí cho bất
	kỳ ai bấm F9.

	Nên: `Log.Boot`, `Log.Info` và dòng tổng `Log.Floor` đều **câm trên client ở môi trường
	Live**. Server thì giữ nguyên — log server vốn đã chỉ mình bạn đọc được, mà nó lại là thứ
	chảy vào Error Report trên Creator Hub.

	⚠️ `Log.Warn` CỐ Ý VẪN IN Ở LIVE. Đó là nguồn cảnh báo lỗi phía client duy nhất chảy về
	Error Report; bịt nó lại là tự làm mù mình ở production để đổi lấy việc giấu vài dòng lỗi
	hiếm khi xảy ra. Đánh đổi sai. Muốn giấu cả warn thì đổi `WARN_SILENT_IN_LIVE = true` —
	nhưng đọc lại câu trên trước.

	══ BẬT LẠI ═══════════════════════════════════════════════════════════════════════════

	Chạy ở Command Bar của Studio (chế độ Edit) RỒI bấm Play:

	    workspace:SetAttribute("SEVerboseBoot", true)

	⚠️ **Phải đặt trên `workspace`, KHÔNG phải trên `game`.** Đã thử 2026-08-24:
	`game:SetAttribute(...)` trong Edit thì Play KHÔNG thấy — attribute trên chính DataModel
	không được sao sang phiên chạy. `workspace` là một Instance trong cây nên nó theo sang.
	(Hàm `verbose()` vẫn đọc cả hai, để một script server trong game đã publish đặt kiểu nào
	cũng được.)

	Cũng phải đặt TRƯỚC khi Play: các dòng này in đúng một lần lúc nạp, đặt sau là lỡ mất.

	Ba mức, cố ý ít:
	  • `Log.Boot`  — dòng "sẵn sàng" lúc nạp. IM LẶNG trừ khi bật verbose.
	  • `Log.Info`  — sự kiện đáng chú ý lúc CHẠY (mua pass, reset tutorial…). LUÔN in.
	  • `Log.Floor` — riêng cho sàn ASMR: gom lại, in đúng MỘT dòng tổng kết.
	Cần cảnh báo thì vẫn dùng `warn` thẳng — `warn` không bao giờ bị cổng này chặn.
]]

local RunService = game:GetService("RunService")

local Env = require(script.Parent.Env)

local Log = {}

local VERBOSE_ATTRIBUTE = "SEVerboseBoot"
-- Xem khối "TRÊN LIVE, CLIENT KHÔNG IN GÌ CẢ" trước khi bật cái này lên true.
local WARN_SILENT_IN_LIVE = false

local function verbose(): boolean
	-- Đọc CẢ HAI chỗ: `workspace` là chỗ đặt được từ Studio Edit (xem khối "BẬT LẠI"),
	-- `game` để một script server trong bản đã publish bật lên cũng ăn.
	return workspace:GetAttribute(VERBOSE_ATTRIBUTE) == true or game:GetAttribute(VERBOSE_ATTRIBUTE) == true
end

-- Đang ở phía client của một server Live ⇒ mọi thứ in ra là công khai với người chơi.
local function publiclyVisible(): boolean
	return RunService:IsClient() and Env.IsLive()
end

-- Dòng khởi động. Im lặng theo mặc định — xem khối "BẬT LẠI" ở trên.
function Log.Boot(...: any)
	if verbose() then
		print(...)
	end
end

-- Sự kiện lúc chạy. In trên server và trong Studio; câm trên client ở Live.
function Log.Info(...: any)
	if publiclyVisible() and not verbose() then
		return
	end
	print(...)
end

-- Cảnh báo. CỐ Ý vẫn in ở Live — xem khối cảnh báo ở đầu file.
function Log.Warn(...: any)
	if WARN_SILENT_IN_LIVE and publiclyVisible() and not verbose() then
		return
	end
	warn(...)
end

--[[
	══ GOM SÀN ASMR ═══════════════════════════════════════════════════════════════════════

	35 model sàn attach BẤT ĐỒNG BỘ trong khoảng 3–6 giây (mỗi cái chờ `Tiles`/`Blocks`
	replicate xong), nên không có một thời điểm nào biết chắc "đã xong hết". Vì vậy dùng
	hẹn giờ trượt: mỗi lần có sàn mới báo danh thì đẩy lịch in lùi thêm `SETTLE_SECONDS`.
	Sàn cuối cùng attach xong thì 1,5 giây sau in đúng một dòng tổng.

	Dòng tổng vẫn giữ đủ thông tin để chẩn đoán — số lượng theo TỪNG LOẠI và tổng số ô:
	    [ASMR] 36 sàn sẵn sàng — Clay×16 BubbleWrap×10 Keyboard×8 KineticSandLive×2 (11.640 ô)
	Thiếu một loại hay hụt số ô là nhìn ra ngay, y như đọc 40 dòng cũ nhưng trong một dòng.

	⚠️ Sàn init hụt là chết câm vĩnh viễn (không log, không lỗi). Dòng tổng này chính là chỗ
	phát hiện: số sàn ít hơn số model mang tag `ASMRFloor` nghĩa là có cái không attach nổi.

	══ ĐẾM THEO MODEL, KHÔNG ĐẾM THEO LƯỢT GỌI (sửa 2026-08-24) ═══════════════════════════

	Bản đầu cộng dồn mỗi lần `Log.Floor` được gọi. Chạy thử ra `[ASMR] 70 sàn — Clay×32
	BubbleWrap×20 Keyboard×16` trong khi chỉ có 36 model mang tag: watchdog của engine ASMR
	**gỡ ra gắn lại** những sàn chưa `ready`, và mỗi lần gắn lại là một lượt gọi nữa. Con số
	phồng lên thành vô nghĩa — tệ hơn cả 40 dòng cũ, vì nó trông như một sự thật.

	Nên giờ khoá theo chính `model`: gắn lại cùng một model KHÔNG cộng thêm sàn, chỉ cộng vào
	bộ đếm `reattach`. Và số đó được in ra khi khác 0 — churn attach là một lỗi thật đáng
	thấy, đừng giấu nó đi lần nữa.
]]
local SETTLE_SECONDS = 1.5

local floorCounts: { [string]: number } = {}
local floorTotal = 0
local cellTotal = 0
local reattachTotal = 0
local pendingToken = 0
-- Model nào đã tính rồi. Khoá yếu: sàn bị streaming dỡ hẳn thì bảng này không giữ nó sống.
local seenModels: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any

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
	local churn = if reattachTotal > 0 then (", %d re-attached"):format(reattachTotal) else ""
	Log.Info(
		("[ASMR] %d floors ready — %s (%s cells%s)"):format(
			floorTotal,
			table.concat(parts, " "),
			formatThousands(cellTotal),
			churn
		)
	)
end

-- `cells` là số ô/phím/bóng của riêng sàn đó (0 nếu không đếm được).
-- `model` là Model mang tag `ASMRFloor` — dùng làm KHOÁ, xem khối "ĐẾM THEO MODEL" ở trên.
function Log.Floor(name: string, cells: number, model: Instance?)
	if model and seenModels[model] then
		-- Cùng một sàn gắn lại: không phải sàn mới. Chỉ ghi nhận churn rồi vẫn hẹn giờ in
		-- lại, để dòng tổng phản ánh cả những lượt gắn lại tới muộn.
		reattachTotal += 1
	else
		if model then
			seenModels[model] = 1
		end
		floorCounts[name] = (floorCounts[name] or 0) + 1
		floorTotal += 1
		cellTotal += cells
	end

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
