--!strict
-- Đợi children của một folder replicate ổn định — model KHÔNG Atomic có thể stream con
-- về sau khi script client đã chạy (bài học Keyboard v5). Model Atomic về đủ ngay,
-- vòng lặp thoát sau đúng 2 lần đếm.

local Await = {}

function Await.childrenStable(folder: Instance, timeout: number?)
	local last = -1
	local deadline = os.clock() + (timeout or 20)
	while os.clock() < deadline do
		local n = #folder:GetChildren()
		if n > 0 and n == last then
			return
		end
		last = n
		task.wait(0.35)
	end
end

return Await
