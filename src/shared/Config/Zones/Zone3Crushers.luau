--!strict
--[[
	Zone3Crushers.luau — nhịp và toán va chạm của cụm máy ép Stage 3.

	NHỊP (theo yêu cầu thiết kế): cặp 1 và cặp 2 ép CÙNG LÚC, xong mới tới lượt cặp 3.
	  nhóm 1 = CrusherDouble_1_* + CrusherDouble_2_*   (bắt đầu ở t = 0.0)
	  nhóm 2 = CrusherDouble_3_*                        (bắt đầu ở t = 1.6)
	Chu kỳ 3.2s → luôn có đúng MỘT nhóm đang ép, nhóm kia đã rút hẳn: người chơi đọc được
	"cửa sổ an toàn" và chạy xuyên qua theo nhịp thay vì phải đứng chờ.

	Vị trí piston suy ra từ `workspace:GetServerTimeNow()` nên server KHÔNG cần dời part
	(trước đây 6 script chạy TweenService riêng → 6 luồng replicate CFrame liên tục).

	Hình học đọc thẳng từ attribute trên từng model trong map (StartX / EndX / PistonY),
	nên chỉnh máy ép trong Studio là code chạy theo, không cần sửa file này.
]]

local Zone3Crushers = {}

Zone3Crushers.FolderName = "Crushers"

-- Nhóm ép theo tên model. Model nào không có trong bảng sẽ bị bỏ qua.
Zone3Crushers.GroupOf = {
	CrusherDouble_1_Left = 1,
	CrusherDouble_1_Right = 1,
	CrusherDouble_2_Left = 1,
	CrusherDouble_2_Right = 1,
	CrusherDouble_3_Left = 2,
	CrusherDouble_3_Right = 2,
} :: { [string]: number }

Zone3Crushers.Cycle = 3.2
Zone3Crushers.GroupStart = { 0.0, 1.6 }

Zone3Crushers.SlamTime = 0.22 -- lao ra: nhanh, dứt khoát
Zone3Crushers.HoldTime = 0.45 -- giữ ép
Zone3Crushers.RetractTime = 0.9 -- thu về: chậm, nặng nề

-- Nửa kích thước piston (32×32×45) + đệm thân người (rộng 1, cao 2.5).
-- HumanoidRootPart cách bàn chân 3 studs nên tâm thân = hrp.Y - 0.5.
Zone3Crushers.BodyCenterYOffset = -0.5
Zone3Crushers.HalfX = 17.0
Zone3Crushers.HalfY = 18.5
Zone3Crushers.HalfZ = 23.5

-- Hộp đánh thức: ngoài vùng này thì bỏ qua toàn bộ phần toán (lối thoát rẻ cho mọi player
-- không ở Stage 3). Tính từ hình học thật của cụm: X -60..52, Z 850..1040, sàn Y 8.
Zone3Crushers.WakeBox = {
	MinX = -75,
	MaxX = 70,
	MinZ = 840,
	MaxZ = 1050,
	MinY = 0,
	MaxY = 60,
}

-- Lao ra: bình phương (tăng tốc dần → cảm giác nện). Thu về: ngược lại, chậm dần khi về đích.
-- Trả về 0 = rút hẳn (an toàn), 1 = ép hết cỡ.
function Zone3Crushers.Alpha(now: number, group: number): number
	local start = Zone3Crushers.GroupStart[group]
	if not start then
		return 0
	end

	local p = (now - start) % Zone3Crushers.Cycle
	local slam = Zone3Crushers.SlamTime
	local holdEnd = slam + Zone3Crushers.HoldTime
	local retractEnd = holdEnd + Zone3Crushers.RetractTime

	if p < slam then
		local q = p / slam
		return q * q
	elseif p < holdEnd then
		return 1
	elseif p < retractEnd then
		local q = (p - holdEnd) / Zone3Crushers.RetractTime
		local inv = 1 - q
		return inv * inv
	end
	return 0
end

-- Vị trí X của piston tại thời điểm `now`.
function Zone3Crushers.PistonX(now: number, group: number, startX: number, endX: number): number
	return startX + (endX - startX) * Zone3Crushers.Alpha(now, group)
end

return Zone3Crushers
