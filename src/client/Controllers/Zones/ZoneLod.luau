--!strict
--[[
	ZoneLod.luau — TẦM ĐÁNH THỨC bẫy zone, tính theo TỐC ĐỘ chứ không phải hằng số studs.

	── VẤN ĐỀ (user báo 2026-08-09) ────────────────────────────────────────────────────────
	Mỗi controller bẫy tự giữ một `RENDER_RADIUS` viết cứng (240–420 studs) và NGỦ hẳn khi
	người chơi ở ngoài tầm đó — ngủ nghĩa là part bị ghim về tư thế gốc, đứng chết cứng.
	Con số đó chọn hồi WalkSpeed còn nhỏ. Ở 250 WS người chơi đi 250 studs MỖI GIÂY, nên
	bán kính 240 chỉ cho vỏn vẹn 0.96 giây: bẫy nằm chình ình trong tầm mắt (fog tới 1500
	studs) mà vẫn đứng im, rồi bật dậy ngay lúc người chơi lao tới. Đúng triệu chứng
	"chạy đến nơi rồi mà bẫy chưa kịp hoạt động".

	Sửa bằng cách đổi đơn vị: KHÔNG hỏi "cách bao nhiêu studs" mà hỏi **"còn bao nhiêu giây
	nữa thì tới"**. Bán kính = WalkSpeed × LEAD_SECONDS, và không bao giờ nhỏ hơn bán kính
	gốc của controller (giữ nguyên hành vi cho người chơi mới, WalkSpeed 12–30).

	── VÌ SAO VẪN MƯỢT ─────────────────────────────────────────────────────────────────────
	1. `LEAD_SECONDS` là hằng số ⇒ chi phí KHÔNG tăng theo tốc độ theo nghĩa "mỗi frame lại
	   xét nhiều vật hơn": người chơi càng nhanh thì càng ít thời gian ở trong vùng đó.
	   Trung bình số vật thức cùng lúc gần như không đổi.
	2. `MAX_RADIUS` chặn trên ở 900 studs — dưới mức `StreamingTargetRadius` mặc định (1024).
	   Đánh thức vật CHƯA stream về là vô nghĩa, và ngoài 900 studs thì một cỗ máy ép chiếm
	   chưa tới vài pixel.
	3. Vùng xa hạ nhịp còn `FAR_HZ` thay vì mỗi frame (xem `ShouldStepFar`). Toàn bộ bẫy đều
	   chạy theo ĐỒNG HỒ TẤT ĐỊNH (`workspace:GetServerTimeNow()`), nên mỗi lần cập nhật là
	   nhảy thẳng tới tư thế ĐÚNG của thời điểm đó — bỏ frame không hề trôi lệch, chỉ là
	   chuyển động của vật ở xa bớt mượt vài phần trăm mà mắt không thấy được.
	   Đây là điểm mấu chốt: hạ nhịp KHÁC HẲN ngủ. Vật vẫn CHUYỂN ĐỘNG.
	4. WalkSpeed đọc qua `GetPropertyChangedSignal` và cache, KHÔNG đọc mỗi frame; bán kính
	   bình phương cũng cache theo từng `baseRadius` nên `RadiusSq` chỉ là một tra bảng.

	Cách dùng trong controller:
	    local ZoneLod = require(script.Parent.ZoneLod)
	    ...
	    if dx * dx + dz * dz > ZoneLod.RadiusSq(RENDER_RADIUS) then
	        return -- SLEEP
	    end
]]

local Players = game:GetService("Players")

local ZoneLod = {}

--[[
	── NỚI TẦM 2026-08-19 (user xin "client bẫy xa hơn một chút, vẫn phải tối ưu") ────────

	Trần cũ `MAX_RADIUS = 900` được chốt vì một lý do đã HẾT HIỆU LỰC: nó bám theo
	`StreamingTargetRadius` MẶC ĐỊNH của Roblox (1024) — đánh thức vật chưa stream về là vô
	nghĩa. Nay place đã đặt `StreamingTargetRadius = 3072` (cùng `StreamingMinRadius = 1024`
	và `StreamingIntegrityMode = PauseOutsideLoadedArea`), nên cái trần đó chỉ còn là di sản.

	Mới: nhìn trước 4.5s (ở 250 WS = 1.125 studs) và trần 1.800 — vẫn cách xa 3.072 để giữ
	đúng nguyên tắc "không đánh thức vật chưa stream".

	── VÌ SAO NỚI GẦN GẤP ĐÔI MÀ KHÔNG TỐN GẤP ĐÔI ────────────────────────────────────────
	Thêm BẬC NHỊP THỨ BA. Trước đây chỉ có hai bậc (mọi-frame trong 300, rồi 24Hz cho tất cả
	phần còn lại); nếu giữ nguyên hai bậc mà kéo trần lên 1.800 thì toàn bộ vùng 900→1.800
	mới cũng chạy 24Hz — đó mới là thứ làm phình chi phí.

	    ≤ 300 studs   : mọi frame      (vật đang ở ngay trước mặt, phải mượt tuyệt đối)
	    ≤ 900 studs   : 24 Hz          (đủ mượt ở khoảng cách đó — giữ nguyên hành vi cũ)
	    > 900 studs   : 6 Hz           (mới; ở đây một cỗ máy ép chiếm vài pixel)

	Nhịp thấp an toàn vì mọi bẫy chạy theo ĐỒNG HỒ TẤT ĐỊNH (`GetServerTimeNow`): mỗi lần cập
	nhật là nhảy thẳng tới tư thế ĐÚNG của thời điểm đó, bỏ frame không tích luỹ sai lệch.
	Người chơi chỉ thấy vật ở xa chuyển động hơi giật — mà ở 900+ studs thì không phân biệt
	nổi. Cái họ CẦN thấy là "bẫy kia đang động, không phải tượng", và 6 Hz thừa sức làm việc đó.

	Chi phí thực tế: vùng mới (900→1.800) rộng gấp ~3 lần vùng cũ về diện tích, nhưng chạy ở
	1/3 nhịp ⇒ tổng số lần cập nhật mỗi giây gần như không đổi.
]]
ZoneLod.LEAD_SECONDS = 4.5
ZoneLod.MAX_RADIUS = 1800
-- Trong tầm này: cập nhật MỌI frame.
ZoneLod.FULL_RATE_RADIUS = 300
-- Từ FULL_RATE_RADIUS tới FAR_RADIUS: nhịp FAR_HZ. Ngoài FAR_RADIUS: nhịp DISTANT_HZ.
ZoneLod.FAR_RADIUS = 900
ZoneLod.FAR_HZ = 24
ZoneLod.DISTANT_HZ = 6

--[[
	══ NGÂN SÁCH MỖI FRAME — thứ THẬT SỰ giữ được 60 FPS (2026-08-19) ══════════════════════

	User đo sau khi nới tầm: chạy tốc độ cao FPS tụt còn 54–55. Đó KHÔNG phải chi phí trung
	bình tăng — tính trung bình thì ba bậc nhịp ở trên đã cân rồi. Đó là chi phí bị DỒN CỤC.

	Vì sao dồn cục: `nextFar` của mỗi controller cộng đúng một hằng số (1/24 hay 1/6 giây).
	Hai controller cùng thức dậy trong một frame — chuyện xảy ra liên tục khi người chơi lao
	với 250 WS qua ranh giới vùng LOD — thì mãi mãi đáo hạn CÙNG MỘT FRAME về sau. Ở tầm
	1.800 studs có 4–5 zone thức cùng lúc, nên cứ vài chục frame lại có một frame phải ghi
	CFrame cho toàn bộ chúng. Một frame nặng gấp 4 lần trong 60 frame = trung bình 60 FPS
	nhưng đồng hồ hiển thị 54–55, đúng con số user thấy.

	Hai van, cả hai đều KHÔNG đổi hành vi nhìn thấy được:

	  1. `MAX_FAR_STEPS_PER_FRAME` — mỗi frame chỉ cho phép ngần này lượt cập nhật ở vùng xa.
	     Ai vượt ngân sách thì KHÔNG dời `nextFar`, nên frame sau hỏi lại và được phục vụ
	     ngay lập tức. Trễ tối đa một hai frame (~30 ms).
	  2. `JITTER` — mỗi lần đặt hẹn kế tiếp thì nhân nhịp với 0.88–1.12. Đây là thứ PHÁ hẳn
	     sự đồng pha, để van (1) gần như không bao giờ phải kích hoạt.

	Cả hai an toàn vì cùng một lý do đã ghi ở trên: bẫy chạy theo ĐỒNG HỒ TẤT ĐỊNH. Trễ một
	frame không làm bẫy sai pha — lần cập nhật sau vẫn nhảy thẳng tới tư thế ĐÚNG của thời
	điểm đó. Đây là điều một hệ nội suy theo dt sẽ KHÔNG làm được, và là lý do kiến trúc
	đồng hồ tất định đáng giá.

	6 = 360 lượt/giây ở 60 FPS. Vùng 24 Hz cần 24 lượt/giây mỗi controller, tức đủ cho 15
	controller cùng ở vùng đó — nhiều hơn tổng số bẫy có LOD trong game (7). Nói cách khác
	van này KHÔNG bóp nhịp trung bình, nó chỉ san phẳng các đỉnh.

	Nhân tiện hạ `DISTANT_HZ` 8 → 6: ngoài 900 studs một cỗ máy ép chiếm vài pixel, và đây là
	vùng rộng nhất (900→1.800) nên mỗi nấc nhịp cắt được nhiều lượt nhất.
]]
ZoneLod.MAX_FAR_STEPS_PER_FRAME = 6

local FULL_RATE_SQ = ZoneLod.FULL_RATE_RADIUS * ZoneLod.FULL_RATE_RADIUS
local FAR_SQ = ZoneLod.FAR_RADIUS * ZoneLod.FAR_RADIUS
local FAR_STEP = 1 / ZoneLod.FAR_HZ
local DISTANT_STEP = 1 / ZoneLod.DISTANT_HZ

local player = Players.LocalPlayer
local jitter = Random.new()

--[[
	══ NGỮ CẢNH DÙNG CHUNG MỖI FRAME ═══════════════════════════════════════════════════════

	Bảy controller bẫy đều mở đầu `step` của mình bằng đúng ba việc giống hệt nhau:

	    local character = player.Character
	    local root = character and character:FindFirstChild("HumanoidRootPart")
	    local now = Workspace:GetServerTimeNow()

	Bảy lần `FindFirstChild` (quét danh sách con của model nhân vật — ~20 phần tử), bảy lần
	đọc `.Position`, bảy lần gọi sang engine lấy giờ, MỖI FRAME, kể cả khi cả bảy đang ngủ.
	Đó là chi phí trả cho một câu trả lời không bao giờ khác nhau giữa chúng.

	Giờ tính MỘT lần mỗi frame rồi phát lại. Quan trọng ở chỗ nó rẻ đi đúng chỗ user đau:
	đường ngủ (controller ở xa, chỉ hỏi khoảng cách rồi thoát) là đường chạy nhiều nhất.

	`RunService.RenderStepped` nối NGAY LÚC NẠP MODULE. Thứ tự các connection RenderStepped
	là thứ tự nối, mà controller chỉ nối trong `Start` của chúng — còn `require(ZoneLod)` thì
	nằm ở đầu file, chạy trước. Nên cái nạp ngân sách này luôn chạy TRƯỚC mọi `step`.
]]
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local frameId = 0
local farBudget = ZoneLod.MAX_FAR_STEPS_PER_FRAME
local rootFrame = -1
local rootPart: BasePart? = nil
local rootPos = Vector3.zero
local nowFrame = -1
local nowValue = 0

RunService.RenderStepped:Connect(function()
	frameId += 1
	farBudget = ZoneLod.MAX_FAR_STEPS_PER_FRAME
end)

--[[
	HumanoidRootPart của người chơi, tra tối đa MỘT lần mỗi frame.
	Trả về `nil` khi chưa có nhân vật — chỗ gọi thoát sớm y như trước.
]]
function ZoneLod.Root(): BasePart?
	if rootFrame == frameId then
		return rootPart
	end
	rootFrame = frameId
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		rootPart = root
		rootPos = root.Position
	else
		rootPart = nil
	end
	return rootPart
end

-- Vị trí gốc nhân vật, đã cache cùng `Root()`. Gọi `Root()` trước để kiểm tra nil.
function ZoneLod.RootPosition(): Vector3
	ZoneLod.Root()
	return rootPos
end

-- `workspace:GetServerTimeNow()` một lần mỗi frame thay vì một lần mỗi controller.
-- Đồng hồ tất định của mọi bẫy — xem khối lý do đầu file.
function ZoneLod.Now(): number
	if nowFrame ~= frameId then
		nowFrame = frameId
		nowValue = Workspace:GetServerTimeNow()
	end
	return nowValue
end

-- WalkSpeed hiện tại + bảng cache baseRadius → radiusSq. Cả hai bị xoá khi WalkSpeed đổi.
local walkSpeed = 16
local radiusCache: { [number]: number } = {}

--[[
	Tầm nhìn thật, quy về bán kính đánh thức. Đọc từ `Lighting.FogEnd` chứ không chép số:
	game có Night mode / Performance mode đổi lighting (xem `ClientSettingsController`), và
	một hằng số chép tay ở đây sẽ lệch ngay lần đầu ai đó chỉnh sương mù.

	Kẹp trong `MAX_RADIUS` vì ngoài mức đó vật chưa chắc đã được stream về — đánh thức thứ
	chưa tồn tại là vô nghĩa (xem khối lý do đầu file).
]]
local Lighting = game:GetService("Lighting")
local viewFloor = math.min(Lighting.FogEnd, ZoneLod.MAX_RADIUS)

Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
	local next = math.min(Lighting.FogEnd, ZoneLod.MAX_RADIUS)
	if next ~= viewFloor then
		viewFloor = next
		table.clear(radiusCache)
	end
end)

--[[
	Bán kính đánh thức (bình phương) cho một controller có bán kính gốc `baseRadius`.
	Trả về bình phương để chỗ gọi so thẳng với `dx*dx + dz*dz`, khỏi phải căn bậc hai.
]]
--[[
	⚠️ SÀN THEO TẦM NHÌN (sửa 2026-08-19 — user: "trong tầm nhìn phải thấy bẫy đang hoạt động").

	Bản trước lấy `max(baseRadius, WalkSpeed × LEAD_SECONDS)`. Vế tốc độ chỉ có ý nghĩa khi
	người chơi ĐÃ nhanh; ở WalkSpeed 46 nó ra 207, thua cả `baseRadius` nên bán kính rơi về
	240–420 studs của controller. Trong khi `Lighting.FogEnd = 1500` — người chơi NHÌN THẤY xa
	gấp 4 lần chỗ bẫy còn cử động. Đó đúng là thứ user thấy: dàn bẫy hiện rõ cuối hành lang
	nhưng đứng như tượng, tới gần mới giật mình sống dậy.

	Luật mới, một câu: **THẤY ĐƯỢC THÌ PHẢI ĐỘNG.** Sàn bán kính = tầm nhìn thật, đọc thẳng
	từ `FogEnd` chứ không chép số — đổi lighting (Night mode, Performance mode) là LOD tự
	theo, không có con số nào phải nhớ đồng bộ.

	Vế tốc độ GIỮ NGUYÊN và vẫn có tác dụng: ở 250 WS nó cho 1.125 studs, nhưng khi người
	chơi vượt quá tầm nhìn thì nó mới là vế thắng (tới trần `MAX_RADIUS`). Hai vế bù nhau —
	một cái lo "nhìn thấy", một cái lo "sắp tới nơi".
]]
function ZoneLod.RadiusSq(baseRadius: number): number
	local cached = radiusCache[baseRadius]
	if cached then
		return cached
	end
	local reach = math.max(walkSpeed * ZoneLod.LEAD_SECONDS, viewFloor)
	local radius = math.clamp(reach, baseRadius, ZoneLod.MAX_RADIUS)
	local value = radius * radius
	radiusCache[baseRadius] = value
	return value
end

--[[
	WalkSpeed hiện tại của người chơi, lấy từ cùng cái cache mà `RadiusSq` dùng (cập nhật qua
	`GetPropertyChangedSignal`, KHÔNG đọc Humanoid mỗi frame).

	Dùng cho bẫy kích theo người chơi (Zone 15 bẫy 2 & 3): bán kính kích của chúng cũng phải
	tính bằng GIÂY-tới-nơi chứ không phải studs, y hệt lý do của `RadiusSq`.
]]
function ZoneLod.WalkSpeed(): number
	return walkSpeed
end

--[[
	Vật ở XA thì có được phép cập nhật ở frame này không?

	`nextFar` là mốc thời gian riêng của từng controller (giữ trong biến local của nó).
	Trả về `(shouldStep, nextFar)` — chỗ gọi ghi đè lại biến của mình:

	    local ok, nextFar = ZoneLod.ShouldStepFar(distSq, now, nextFar)
	    if not ok then return end

	Trong `FULL_RATE_RADIUS` thì luôn trả true và không đụng tới `nextFar`.
]]
function ZoneLod.ShouldStepFar(distSq: number, now: number, nextFar: number): (boolean, number)
	if distSq <= FULL_RATE_SQ then
		return true, nextFar
	end
	if now < nextFar then
		return false, nextFar
	end
	if farBudget <= 0 then
		--[[
			Ngân sách frame này đã cạn. Trả false mà KHÔNG dời `nextFar`: frame sau controller
			hỏi lại, vẫn quá hạn, và lúc đó ngân sách đã nạp lại nên nó được phục vụ ngay.
			Không dời mốc chính là điều giữ cho nhịp trung bình không bị trôi.
		]]
		return false, nextFar
	end
	farBudget -= 1
	-- Bậc ba: ngoài FAR_RADIUS thì giãn nhịp tiếp (xem khối lý do ở đầu file).
	-- Chỗ gọi không phải sửa gì — vẫn đúng một biến `nextFar` như trước.
	local step = if distSq > FAR_SQ then DISTANT_STEP else FAR_STEP
	-- Nhiễu pha: xem `MAX_FAR_STEPS_PER_FRAME`. Đây là thứ giữ cho các controller không bao
	-- giờ khoá pha với nhau, nên ngân sách ở trên gần như không phải can thiệp.
	return true, now + step * (0.88 + jitter:NextNumber() * 0.24)
end

local function watchHumanoid(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local function sync()
		if humanoid.WalkSpeed ~= walkSpeed then
			walkSpeed = humanoid.WalkSpeed
			-- Bán kính phụ thuộc WalkSpeed nên cache cũ hết hạn. Bảng chỉ vài phần tử
			-- (một baseRadius/controller) nên dựng lại là miễn phí.
			table.clear(radiusCache)
		end
	end
	sync()
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(sync)
end

-- Hook ngay lúc module được nạp: các controller bẫy gọi `RadiusSq` từ chính `Start` của
-- chúng, mà thứ tự Start là song song nên không thể dựa vào `ZoneLod.Start` chạy trước.
if player then
	if player.Character then
		task.spawn(watchHumanoid, player.Character)
	end
	player.CharacterAdded:Connect(watchHumanoid)
end

return ZoneLod
