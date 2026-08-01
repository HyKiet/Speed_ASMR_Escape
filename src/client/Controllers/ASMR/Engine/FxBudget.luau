--!strict
-- Ngân sách hiệu ứng toàn cục cho MỌI sàn ASMR (thay bản copy-paste `_G.__asmrSndBudget`
-- trong 9 script cũ): camera-cull + tối đa 20 sound/0.1s cho cả map.
-- Camera lấy tươi mỗi lần gọi — cache 1 lần bị stale sau respawn (bug đã gặp).

local FxBudget = {}

local WINDOW = 0.1
local MAX_PER_WINDOW = 20

local windowStart = 0
local count = 0

function FxBudget.fxOK(pos: Vector3, dist: number?): boolean
	local cam = workspace.CurrentCamera
	if not cam then
		return false
	end
	if (cam.CFrame.Position - pos).Magnitude > (dist or 90) then
		return false
	end
	local t = os.clock()
	if t - windowStart > WINDOW then
		windowStart = t
		count = 0
	end
	if count >= MAX_PER_WINDOW then
		return false
	end
	count += 1
	return true
end

-- Chỉ kiểm tra khoảng cách camera, không trừ ngân sách (dùng cho VFX thuần)
function FxBudget.nearCamera(pos: Vector3, dist: number): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude <= dist
end

return FxBudget
