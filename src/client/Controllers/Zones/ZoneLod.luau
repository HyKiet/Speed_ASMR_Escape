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

-- Bao nhiêu GIÂY chạy nữa thì tới nơi. 3.2s ở 250 WS = 800 studs — bẫy đã chuyển động từ
-- lúc còn là chấm nhỏ cuối hành lang, người chơi đọc được nhịp trước khi phải né.
ZoneLod.LEAD_SECONDS = 3.2
-- Chặn trên: dưới StreamingTargetRadius mặc định (1024) để không đánh thức vật chưa stream.
ZoneLod.MAX_RADIUS = 900
-- Trong tầm này: cập nhật MỌI frame. Ngoài ra: hạ xuống FAR_HZ.
ZoneLod.FULL_RATE_RADIUS = 300
ZoneLod.FAR_HZ = 24

local FULL_RATE_SQ = ZoneLod.FULL_RATE_RADIUS * ZoneLod.FULL_RATE_RADIUS
local FAR_STEP = 1 / ZoneLod.FAR_HZ

local player = Players.LocalPlayer

-- WalkSpeed hiện tại + bảng cache baseRadius → radiusSq. Cả hai bị xoá khi WalkSpeed đổi.
local walkSpeed = 16
local radiusCache: { [number]: number } = {}

--[[
	Bán kính đánh thức (bình phương) cho một controller có bán kính gốc `baseRadius`.
	Trả về bình phương để chỗ gọi so thẳng với `dx*dx + dz*dz`, khỏi phải căn bậc hai.
]]
function ZoneLod.RadiusSq(baseRadius: number): number
	local cached = radiusCache[baseRadius]
	if cached then
		return cached
	end
	local radius = math.clamp(walkSpeed * ZoneLod.LEAD_SECONDS, baseRadius, ZoneLod.MAX_RADIUS)
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
	return true, now + FAR_STEP
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
