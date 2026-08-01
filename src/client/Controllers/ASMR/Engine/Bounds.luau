--!strict
-- Bounding box XZ của một sàn — gate rẻ nhất trước mọi tính toán.
-- ofBase giữ đúng số đo script cũ (Base/Tray/Collider); ofParts thay thế khi
-- part nền đã bị xóa (bài học zone v3: inject __asmrBox từ tile folder).

local Bounds = {}

export type Box = { cx: number, cz: number, halfX: number, halfZ: number, topY: number }

function Bounds.ofBase(base: BasePart, pad: number): Box
	return {
		cx = base.Position.X,
		cz = base.Position.Z,
		halfX = base.Size.X / 2 + pad,
		halfZ = base.Size.Z / 2 + pad,
		topY = base.Position.Y + base.Size.Y / 2,
	}
end

function Bounds.ofParts(parts: { Instance }, pad: number): Box?
	local x0, x1 = math.huge, -math.huge
	local z0, z1 = math.huge, -math.huge
	local top = -math.huge
	local n = 0
	for _, p in parts do
		if p:IsA("BasePart") then
			n += 1
			x0 = math.min(x0, p.Position.X - p.Size.X / 2)
			x1 = math.max(x1, p.Position.X + p.Size.X / 2)
			z0 = math.min(z0, p.Position.Z - p.Size.Z / 2)
			z1 = math.max(z1, p.Position.Z + p.Size.Z / 2)
			top = math.max(top, p.Position.Y + p.Size.Y / 2)
		end
	end
	if n == 0 then
		return nil
	end
	return {
		cx = (x0 + x1) / 2,
		cz = (z0 + z1) / 2,
		halfX = (x1 - x0) / 2 + pad,
		halfZ = (z1 - z0) / 2 + pad,
		topY = top,
	}
end

function Bounds.contains(box: Box, pos: Vector3): boolean
	return math.abs(pos.X - box.cx) <= box.halfX and math.abs(pos.Z - box.cz) <= box.halfZ
end

return Bounds
