--!strict
--[[
	TrailShowcaseController — quay 3 bệ trưng bày Trail ở Lobby, CHẠY TRÊN CLIENT.

	══ VÌ SAO CHUYỂN TỪ SERVER SANG CLIENT (2026-08-24) ═════════════════════════════════════

	Trước đây mỗi bệ có một `Script` SERVER riêng (`Lobby.TrailBase.<tên>.Base.Part.TrailShowcase`)
	tự nối `RunService.Heartbeat` và ghi `part.CFrame` mỗi khung hình. Ba bệ = **180 lần ghi
	CFrame mỗi giây trên server, mỗi lần replicate xuống MỌI client**, chạy vĩnh viễn kể cả khi
	lobby không có ai. Nó hiện nguyên hình ở tab Scripts của Developer Console: `TrailShowcase`
	đứng đầu bảng với Rate 180/s, gấp 3 lần mọi script khác trong game.

	Chuyển động này thuần trang trí: không ai chạm vào nó, không có phán xử gameplay nào phụ
	thuộc vị trí của part. Vậy nên nó thuộc về client. Sau khi chuyển:
	    server : 3 vòng Heartbeat → 0
	    mạng   : 180 gói CFrame/giây → 0
	    client : 3 phép ghi CFrame mỗi khung hình (không đáng kể)

	Quỹ đạo giữ NGUYÊN XI thông số của bản server cũ, nên hình ảnh không đổi một pixel.

	══ CỐ Ý KHÔNG CULL THEO KHOẢNG CÁCH ════════════════════════════════════════════════════

	Có thể ngừng quay khi người chơi ở xa, nhưng làm vậy phải tắt/bật lại `Trail` để ribbon
	không vẽ một vệt dài từ vị trí cũ sang vị trí mới lúc quay lại. Đây là BỆ BÁN HÀNG — một
	lỗi để `Trail.Enabled = false` là mất hẳn thứ đang chào khách. Ba phép ghi CFrame mỗi khung
	hình rẻ hơn nhiều so với rủi ro đó. Đừng "tối ưu" thêm chỗ này.

	══ STREAMING ═══════════════════════════════════════════════════════════════════════════

	`TrailBase` nằm trong Lobby nên `StreamingEnabled` có thể dỡ nó khi người chơi đi xa, rồi
	DỰNG PART MỚI khi quay lại — tham chiếu cũ thành mồ côi. Vì vậy phải resolve lại theo chu
	kỳ thay vì cache một lần lúc Start (cùng bẫy đã dính ở Zone14FanController).

	══ ⚠️ TÌM PART BẰNG ATTRIBUTE, ĐỪNG BAO GIỜ BẰNG TÊN ═══════════════════════════════════

	`Base` là một **Model** và bên trong có **BA part đều tên "Part"** (cộng một Billboard).
	`base:FindFirstChild("Part")` bốc trúng cái đầu tiên trong danh sách con — không phải cái
	đang đeo Trail. Bản server cũ không dính bẫy này vì nó dùng `script.Parent`.

	Nên đúng part đã được đánh dấu trong map bằng attribute `TrailShowcaseOrbit = true`. Cái
	này KHÔNG suy ra được từ hình học nên phải giữ.

	══ ⚠️ TÂM QUỸ ĐẠO: CHỤP LÚC NHÌN THẤY LẦN ĐẦU, KHÔNG ĐỌC TỪ ATTRIBUTE (2026-08-27) ══════

	Bản trước đọc tâm từ attribute `OrbitCenter` bake sẵn trong map. Nó hỏng, và hỏng im lặng:
	ai đó dời cả Lobby ~95 studs trên trục Z, ba attribute ở nguyên giá trị cũ. Đo lúc phát hiện
	— X và Y khớp hoàn hảo, chỉ Z lệch **đúng 95.14 stud ở cả ba bệ**:

	    Mystic Violet   part z = 94.7    OrbitCenter z = −0.40
	    Golden Ray      part z = 113.4   OrbitCenter z = 18.22
	    Crimson Fury    part z = 123.7   OrbitCenter z = 28.58

	Triệu chứng người dùng thấy: "trong Edit trail nằm đúng bệ, vào Play thì bay ra ngoài" —
	vì Edit không chạy controller, còn Play thì frame đầu tiên đã ném part về tâm cũ.
	(Cùng một lần dời đó cũng làm lệch cả sáu biển khu vực — xem `AreaSignService`.)

	Cách chữa: **chụp `part.Position` ngay lần đầu nhìn thấy MỘT INSTANCE part**, rồi nhớ theo
	instance đó. Không có dữ liệu nào phải bảo trì bằng tay nữa ⇒ dời Lobby bao nhiêu lần cũng
	đúng.

	Vì sao vẫn AN TOÀN dù `resolve()` chạy lại mỗi 2 giây (đây là lý do bản cũ dùng attribute):
	  • Part CŨ  — đã có trong `capturedCenter`, dùng lại giá trị đã chụp. KHÔNG đọc lại
	    `part.Position` (lúc này part đang bay, lấy vị trí hiện tại làm tâm là quỹ đạo trôi dần).
	  • Part MỚI — chỉ xuất hiện khi StreamingEnabled dựng lại từ dữ liệu map, tức nó đang đứng
	    ĐÚNG vị trí tác giả đặt. Chụp lúc này là chụp đúng.

	⚠️ Hệ quả: đừng cache `capturedCenter` theo TÊN part hay theo chỉ số — phải theo chính
	Instance, vì streaming tạo instance mới chứ không tái dùng cái cũ.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Thông số lấy nguyên từ bản server cũ — cả 3 bệ dùng chung một bộ.
local RADIUS = 3.8 -- vòng bay quanh bệ
local SPEED = 2.6 -- rad/s
local BOB = 1.2 -- biên độ nhấp nhô -> vệt vẽ thành hình xoắn ốc, khoe trọn hoạ tiết
local BOB_RATE = 2 -- số lần nhấp nhô mỗi vòng

local RESOLVE_INTERVAL = 2 -- giây; đủ nhanh để bệ hiện lại sau streaming mà không quét liên tục

type Showcase = {
	part: BasePart,
	center: Vector3,
	angle: number,
}

local TrailShowcaseController = {}

local showcases: { Showcase } = {}
local resolveAcc = 0
local announced = false

--[[
	Tâm quỹ đạo đã chụp, khoá theo INSTANCE (xem khối ⚠️ thứ hai ở đầu file).

	Bảng yếu: streaming huỷ part cũ và dựng part mới, không tái dùng instance. Bảng thường sẽ
	giữ tham chiếu tới mọi part đã chết suốt phiên chơi — rò rỉ chậm nhưng vĩnh viễn.
]]
local capturedCenter: { [BasePart]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any

-- Quét lại danh sách bệ. Giữ `angle` của bệ cũ để chuyển động không giật khi resolve lại.
local function resolve()
	local trailBase = Workspace:FindFirstChild("TrailBase", true)
	if not trailBase then
		table.clear(showcases)
		return
	end

	local previousAngle: { [BasePart]: number } = {}
	for _, s in showcases do
		previousAngle[s.part] = s.angle
	end

	table.clear(showcases)
	for _, o in trailBase:GetDescendants() do
		if o:IsA("BasePart") and o:GetAttribute("TrailShowcaseOrbit") == true then
			--[[
				Part đã biết ⇒ dùng lại tâm đã chụp (lúc này nó đang bay, đọc lại là trôi quỹ đạo).
				Part mới ⇒ nó vừa được streaming dựng từ dữ liệu map nên đang đứng đúng chỗ tác
				giả đặt: chụp ngay bây giờ.
			]]
			local center = capturedCenter[o]
			if not center then
				center = o.Position
				capturedCenter[o] = center
			end
			table.insert(showcases, {
				part = o,
				center = center,
				angle = previousAngle[o] or 0,
			})
		end
	end
end

local function step(dt: number)
	resolveAcc += dt
	if resolveAcc >= RESOLVE_INTERVAL then
		resolveAcc = 0
		resolve()
	end

	-- Báo MỘT lần, và chỉ khi đã thật sự tìm ra bệ. Lúc `Start()` chạy thì Lobby thường CHƯA
	-- stream về client, nên in ngay ở đó luôn ra "0 bệ" và làm người đọc log tưởng hỏng.
	if not announced and #showcases > 0 then
		announced = true
		Log.Boot(("[TrailShowcase] %d bệ trưng bày quay trên CLIENT (trước đây 180 CFrame/s từ server)"):format(#showcases))
	end

	for _, s in showcases do
		s.angle += SPEED * dt

		local center = s.center
		local x = center.X + math.cos(s.angle) * RADIUS
		local z = center.Z + math.sin(s.angle) * RADIUS
		local y = center.Y + math.sin(s.angle * BOB_RATE) * BOB
		local pos = Vector3.new(x, y, z)

		-- Hướng bay (tiếp tuyến quỹ đạo)
		local tangent = Vector3.new(-math.sin(s.angle), 0, math.cos(s.angle))
		-- Xoay 90 độ quanh trục Z: trục X cục bộ (nơi cặp Attachment của Trail nằm) dựng đứng
		-- -> ribbon thẳng đứng đúng như lúc đeo.
		s.part.CFrame = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, 0, math.rad(90))
	end
end

function TrailShowcaseController.Start()
	resolve()
	RunService.Heartbeat:Connect(step)
end

return TrailShowcaseController
