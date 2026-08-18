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

-- `starterPackDeadline` là mốc theo `os.clock()` cục bộ; `boostClockNow` đã có sẵn nhịp
-- 4 lần/giây trong HUDController nên không cần vòng lặp thứ hai chỉ để nhích một con số.
function StarterPackShared.SecondsLeft(): number
	return math.max(0, State.starterPackDeadline:get() - State.boostClockNow:get())
end

-- Ba trạng thái đều do server phán (xem StarterPackService), client chỉ vẽ.
StarterPackShared.Available = Computed(function()
	return State.starterPackConfigured:get()
		and not State.starterPackBought:get()
		and StarterPackShared.SecondsLeft() > 0
end)

return StarterPackShared
