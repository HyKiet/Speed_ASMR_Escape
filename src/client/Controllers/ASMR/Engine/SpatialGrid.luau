--!strict
-- Băm không gian 2D (cell vuông) — tra cứu O(1) quanh một điểm.
-- Hot path (Keyboard 720+ phím) truy cập thẳng `grid.map`/`grid.cell` và tự loop 3x3
-- như v5 để không tốn closure; các sàn khác dùng query() cho gọn.

local SpatialGrid = {}
SpatialGrid.__index = SpatialGrid

function SpatialGrid.new(cellSize: number)
	return setmetatable({ cell = cellSize, map = {} }, SpatialGrid)
end

function SpatialGrid:insert(x: number, z: number, item)
	local key = math.floor(x / self.cell) .. "," .. math.floor(z / self.cell)
	local bucket = self.map[key]
	if not bucket then
		bucket = {}
		self.map[key] = bucket
	end
	table.insert(bucket, item)
end

function SpatialGrid:remove(x: number, z: number, item)
	local key = math.floor(x / self.cell) .. "," .. math.floor(z / self.cell)
	local bucket = self.map[key]
	if bucket then
		local i = table.find(bucket, item)
		if i then
			table.remove(bucket, i)
		end
		if #bucket == 0 then
			self.map[key] = nil
		end
	end
end

-- Bucket chứa đúng cell của (x,z) — cho sàn tra 1 ô (MelodyRun)
function SpatialGrid:bucketAt(x: number, z: number)
	return self.map[math.floor(x / self.cell) .. "," .. math.floor(z / self.cell)]
end

-- Gọi fn(item) cho mọi item trong (2r+1)^2 cell quanh (x,z)
function SpatialGrid:query(x: number, z: number, r: number, fn)
	local cx, cz = math.floor(x / self.cell), math.floor(z / self.cell)
	for dx = -r, r do
		for dz = -r, r do
			local bucket = self.map[(cx + dx) .. "," .. (cz + dz)]
			if bucket then
				for _, item in bucket do
					fn(item)
				end
			end
		end
	end
end

return SpatialGrid
