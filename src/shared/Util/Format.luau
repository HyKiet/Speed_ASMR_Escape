--!strict
-- Format số lớn cho UI.

local Format = {}

function Format.Number(value: number): string
	if value < 1000 then
		return tostring(math.floor(value))
	elseif value < 1_000_000 then
		return string.format("%.2fK", value / 1_000)
	elseif value < 1_000_000_000 then
		return string.format("%.2fM", value / 1_000_000)
	elseif value < 1_000_000_000_000 then
		return string.format("%.2fB", value / 1_000_000_000)
	else
		return string.format("%.2fT", value / 1_000_000_000_000)
	end
end

return Format
