--!strict
--[[
	ParkourUtil.luau — Hàm tiện ích vật lý dùng chung cho mọi cơ chế parkour.
]]

local Players = game:GetService("Players")

local ParkourTypes = require(script.Parent.ParkourTypes)

type Session = ParkourTypes.Session

local ParkourUtil = {}

-- Vận tốc NGANG (bỏ trục Y) của nhân vật.
function ParkourUtil.HorizontalVelocity(root: BasePart): Vector3
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z)
end

-- Độ lớn vận tốc ngang (stud/s).
function ParkourUtil.HorizontalSpeed(root: BasePart): number
	return ParkourUtil.HorizontalVelocity(root).Magnitude
end

-- Nhân vật có đang đứng trên mặt đất không?
function ParkourUtil.IsGrounded(humanoid: Humanoid): boolean
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return true
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
end

-- Hướng di chuyển NGANG mong muốn: ưu tiên phím WASD; nếu đứng yên thì lấy hướng mặt nhân vật.
function ParkourUtil.DesiredMoveDir(session: Session): Vector3
	local move = session.humanoid.MoveDirection
	if move.Magnitude > 0.05 then
		return Vector3.new(move.X, 0, move.Z).Unit
	end
	local look = session.root.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z).Unit
end

-- Tạo RaycastParams loại trừ MỌI nhân vật người chơi (mình + người khác).
-- Người chơi khác KHÔNG phải "tường": va chạm player-player đã tắt (CollisionGroupService),
-- nên blockcast chống văng của Slide mà tính thân người khác là vật cản thì sẽ ngắt trượt
-- + triệt tiêu vận tốc oan mỗi lần lướt qua đám đông.
function ParkourUtil.MakeRaycastParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { character }
	for _, otherPlayer in Players:GetPlayers() do
		local otherCharacter = otherPlayer.Character
		if otherCharacter and otherCharacter ~= character then
			table.insert(exclude, otherCharacter)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	-- CHỈ vật cản VẬT LÝ THẬT mới là tường. Mặc định raycast trúng cả part CanCollide=false
	-- (miễn CanQuery=true) — như cổng thủy tinh Zone 13 (đâm xuyên để vỡ) hay tường năng
	-- lượng Zone 5: WallGuard/blockcast mà tính chúng là tường thì cắt đà ngay trước cổng,
	-- phá cơ chế xuyên phá của game.
	params.RespectCanCollide = true
	return params
end

-- Pháp tuyến gần như nằm ngang → tường ĐỨNG (không phải dốc/trần).
function ParkourUtil.IsVerticalWall(normal: Vector3): boolean
	return math.abs(normal.Y) < 0.4
end

-- Dò TƯỜNG PHÍA TRƯỚC theo hướng `dir` (đã chuẩn hóa), trong khoảng `distance` studs.
-- Trả về RaycastResult nếu sắp đụng tường đứng; dùng để CHỐNG VĂNG NGƯỜI khi dash/slide.
function ParkourUtil.WallAhead(session: Session, dir: Vector3, distance: number): RaycastResult?
	if dir.Magnitude < 1e-3 then
		return nil
	end
	local Workspace = workspace
	local params = ParkourUtil.MakeRaycastParams(session.character)
	-- Bắn từ tâm root về phía trước.
	local result = Workspace:Raycast(session.root.Position, dir.Unit * distance, params)
	if result and ParkourUtil.IsVerticalWall(result.Normal) then
		return result
	end
	return nil
end

return ParkourUtil
