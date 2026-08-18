--!strict
--[[
	MovementUtil.luau — tiện ích vật lý dùng chung.

	Điểm khác bản Parkour cũ: RaycastParams được DỰNG LẠI CÓ ĐIỀU KIỆN và lưu trong
	session, thay vì `RaycastParams.new()` + duyệt Players:GetPlayers() ở MỖI lần quét.
	Bản cũ gọi hàm đó 2 lần/frame ở 60Hz ⇒ 120 RaycastParams + 120 bảng tạm mỗi giây,
	toàn bộ thành rác GC.
]]

local Players = game:GetService("Players")

local MovementConfig = require(script.Parent.MovementConfig)
local MovementTypes = require(script.Parent.MovementTypes)

type Session = MovementTypes.Session

local MovementUtil = {}

function MovementUtil.HorizontalVelocity(root: BasePart): Vector3
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z)
end

function MovementUtil.HorizontalSpeed(root: BasePart): number
	local v = root.AssemblyLinearVelocity
	return math.sqrt(v.X * v.X + v.Z * v.Z)
end

function MovementUtil.IsGrounded(humanoid: Humanoid): boolean
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return true
	end
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.RunningNoPhysics
end

-- Hướng di chuyển mong muốn: ưu tiên phím, đứng yên thì lấy hướng mặt.
function MovementUtil.DesiredMoveDir(session: Session): Vector3
	local move = session.humanoid.MoveDirection
	if move.Magnitude > 0.05 then
		return Vector3.new(move.X, 0, move.Z).Unit
	end
	local look = session.root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-4 then flat.Unit else Vector3.zero
end

-- Pháp tuyến gần như nằm ngang → tường ĐỨNG (không phải dốc/trần).
function MovementUtil.IsVerticalWall(normal: Vector3): boolean
	return math.abs(normal.Y) < MovementConfig.AntiFling.VerticalWallDot
end

--[[
	Dựng lại bộ lọc raycast: loại trừ nhân vật của mình VÀ mọi nhân vật khác.

	Người chơi khác KHÔNG phải "tường" — va chạm player-player đã tắt qua CollisionGroup,
	nên nếu tính thân họ là vật cản thì mỗi lần lướt qua đám đông là bị cắt đà oan.

	RespectCanCollide = true: part CanCollide=false (cổng thuỷ tinh Zone 13, tường năng
	lượng Zone 5 — thứ để đâm xuyên) không được tính là tường, nếu không sẽ cắt đà ngay
	trước cổng và phá cơ chế xuyên phá.
]]
function MovementUtil.RebuildRayParams(session: Session)
	local params = session.rayParams
	local exclude: { Instance } = { session.character }
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		if otherCharacter and otherCharacter ~= session.character then
			table.insert(exclude, otherCharacter)
		end
	end
	params.FilterDescendantsInstances = exclude
	session.rayParamsDirty = false
end

-- Lấy params đã sẵn sàng; chỉ dựng lại khi có người vào/ra hoặc respawn.
function MovementUtil.GetRayParams(session: Session): RaycastParams
	if session.rayParamsDirty then
		MovementUtil.RebuildRayParams(session)
	end
	return session.rayParams
end

return MovementUtil
