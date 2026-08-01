--!strict
-- Giải mã chuỗi path dạng "Workspace.Zone3.Mechanics.Stage3Start" thành Instance.

local PathResolver = {}

function PathResolver.Resolve(path: string): Instance?
	local current: Instance = game
	for segment in string.gmatch(path, "[^%.]+") do
		local nextInstance = current:FindFirstChild(segment)
		if not nextInstance then
			return nil
		end
		current = nextInstance
	end

	return current
end

return PathResolver
