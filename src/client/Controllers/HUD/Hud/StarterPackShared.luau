--!strict
--[[
	StarterPackShared.luau — phần dùng CHUNG giữa icon trên HUD (`StarterPackCard`) và modal
	chi tiết (`Modals/StarterPackModal`).

	Ba thứ ở đây phải tuyệt đối khớp nhau giữa hai màn: đồng hồ đếm lùi, số giây còn lại, và
	câu trả lời "gói còn bán không". Chép làm hai bản là sớm muộn cũng có cảnh icon đã biến
	mất mà modal vẫn mở, hoặc ngược lại.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.State)

local Computed = Fusion.Computed

local StarterPackShared = {}

-- "47:12:33" — còn trên 1 giờ thì hiện giờ:phút:giây, dưới 1 giờ thì phút:giây cho gấp gáp.
function StarterPackShared.FormatCountdown(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

--[[
	`starterPackDeadline` là mốc theo `os.clock()` cục bộ.

	⚠️ ĐỌC `boostClockNow` ĐỂ LẤY NHỊP, NHƯNG TRỪ BẰNG `os.clock()` TƯƠI (sửa 2026-08-24).

	`boostClockNow` chỉ nhích 4 lần/giây, nên nó LUÔN cũ tới 0,25 giây. Bản cũ trừ thẳng bằng
	nó, và đó là chỗ sinh lỗi "thẻ Starter Pack đã hết hạn vẫn chớp lên ~1 giây": mỗi lần server
	gửi lại trạng thái hết hạn, client đặt `deadline = os.clock() + 0` — một mốc MỚI HƠN giá trị
	`boostClockNow` đang giữ — nên hiệu số ra dương và `Available` lật thành true cho tới nhịp
	kế tiếp.

	Vẫn phải gọi `boostClockNow:get()` vì đó là thứ Fusion bám vào để tính lại Computed; bỏ nó
	đi thì đồng hồ đứng im. Nó chỉ còn làm NHỊP, không còn làm MỐC.
]]
function StarterPackShared.SecondsLeft(): number
	State.boostClockNow:get() -- nhịp cho Computed, xem chú thích trên
	return math.max(0, State.starterPackDeadline:get() - os.clock())
end

-- Ba trạng thái đều do server phán (xem StarterPackService), client chỉ vẽ.
StarterPackShared.Available = Computed(function()
	return State.starterPackConfigured:get()
		and not State.starterPackBought:get()
		and StarterPackShared.SecondsLeft() > 0
end)

return StarterPackShared
