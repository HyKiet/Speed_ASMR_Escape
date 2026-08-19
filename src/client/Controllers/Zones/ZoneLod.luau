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
	    > 900 studs   : 8 Hz           (mới; ở đây một cỗ máy ép chiếm vài pixel)

	8 Hz an toàn vì mọi bẫy chạy theo ĐỒNG HỒ TẤT ĐỊNH (`GetServerTimeNow`): mỗi lần cập
	nhật là nhảy thẳng tới tư thế ĐÚNG của thời điểm đó, bỏ frame không tích luỹ sai lệch.
	Người chơi chỉ thấy vật ở xa chuyển động hơi giật — mà ở 900+ studs thì không phân biệt
	nổi. Cái họ CẦN thấy là "bẫy kia đang động, không phải tượng", và 8 Hz thừa sức làm việc đó.

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
ZoneLod.DISTANT_HZ = 8

local FULL_RATE_SQ = ZoneLod.FULL_RATE_RADIUS * ZoneLod.FULL_RATE_RADIUS
local FAR_SQ = ZoneLod.FAR_RADIUS * ZoneLod.FAR_RADIUS
local FAR_STEP = 1 / ZoneLod.FAR_HZ
local DISTANT_STEP = 1 / ZoneLod.DISTANT_HZ

local player = Players.LocalPlayer

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
	-- Bậc ba: ngoài FAR_RADIUS thì giãn nhịp tiếp (xem khối lý do ở đầu file).
	-- Chỗ gọi không phải sửa gì — vẫn đúng một biến `nextFar` như trước.
	return true, now + (if distSq > FAR_SQ then DISTANT_STEP else FAR_STEP)
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
