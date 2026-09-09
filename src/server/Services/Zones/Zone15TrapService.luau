--!strict
--[[
	Zone15TrapService.luau — Server cho 3 bẫy Stage 15.

	TRÁCH NHIỆM (chỉ 2 việc, cố ý giữ hẹp):
	  1. DỰNG BÙ hình học nếu map chưa có (gọi Zone15Traps.Build — cùng một hàm mà Studio
	     dùng để bake vào .rbxlx). Cụm đã có sẵn thì KHÔNG đụng vào, chỉnh tay không bị mất.
	  2. PHÂN XỬ sát thương của BẪY 1 (tia laser quét) — bẫy duy nhất giết trực tiếp.
	     Bẫy 2 & 3 giết gián tiếp bằng cách làm người chơi rơi xuống KillBlockGlobal (Y 149),
	     nên không tốn một dòng logic server nào.

	TỐI ƯU CHO SERVER HÀNG NGÀN NGƯỜI:
	  • Server KHÔNG di chuyển part bẫy. Vị trí suy ra từ `workspace:GetServerTimeNow()`,
	    client tự dựng lại → 0 byte replication/khung hình.
	  • Vòng kiểm tra 15Hz, mỗi player thoát sớm bằng 1 phép so hộp cục bộ. Chi phí thực tế
	    = O(số người ĐANG ở trong ô bẫy), phần còn lại của server không trả giá.
	  • Kiểm tra kiểu QUÉT (swept): ở WalkSpeed 234 người chơi đi 15,6 studs/tick còn tia chỉ
	    dày 3 studs — so vị trí tức thời sẽ để lọt. Ta xét ĐỔI DẤU của (vị trí người − vị trí tia)
	    giữa 2 tick, đúng cả khi tia cũng đang chạy ngược chiều người.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local Zone15Traps = require(ReplicatedStorage.Shared.Config.Zones.Zone15Traps)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone15TrapService = {}

local TICK_RATE = 1 / 15
local KILL_COOLDOWN = 1.0
local SW = Zone15Traps.Sweep

-- Ngoài tầm này (studs, tính từ tâm cụm) thì bỏ qua ngay, không tính gì thêm.
local WAKE_RADIUS = 260
local WAKE_RADIUS_SQ = WAKE_RADIUS * WAKE_RADIUS

type Beam = { part: BasePart, index: number, home: CFrame }
type Sample = { pos: Vector3, t: number, near: boolean }

local beams: { Beam } = {}
local center: Vector3? = nil
local samples: { [Player]: Sample } = {}
local lastKill: { [Player]: number } = {}

--=====================================================================================
-- DỰNG / NẠP HÌNH HỌC
--=====================================================================================

local function cacheBeams(zone: Instance): boolean
	local mechanics = zone:FindFirstChild("Mechanics")
	local traps = mechanics and mechanics:FindFirstChild("Traps")
	local cluster = traps and traps:FindFirstChild(SW.ClusterName)
	if not cluster then
		return false
	end

	table.clear(beams)
	local sum = Vector3.zero
	for _, child in cluster:GetChildren() do
		local home = child:GetAttribute("HomeCF")
		local index = child:GetAttribute("TrapIndex")
		if child:IsA("BasePart") and typeof(home) == "CFrame" and typeof(index) == "number" then
			table.insert(beams, { part = child, index = index, home = home })
			sum += home.Position
		end
	end

	if #beams ~= #SW.Beams then
		table.clear(beams)
		return false
	end

	center = sum / #beams
	return true
end

local function setup(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone15")
	if not zone or not zone:FindFirstChild("Mechanics") then
		return false
	end

	Log.Boot("[Zone15TrapService] " .. Zone15Traps.Build(zone))
	zone:SetAttribute("TrapsReady", true)
	return cacheBeams(zone)
end

--=====================================================================================
-- PHÂN XỬ SÁT THƯƠNG BẪY 1
--=====================================================================================

-- Khoảng cách CÓ DẤU giữa người chơi và tia, theo trục chạy (toạ độ cục bộ của tia).
-- Trả về nil nếu người chơi nằm ngoài bề ngang / độ cao sát thương → coi như an toàn.
--
-- `worldPos` là HumanoidRootPart, nằm cách bàn chân 3 studs nên KHÔNG phải tâm thân người;
-- bù BodyCenterYOffset rồi mới so, nếu không vùng chết sẽ lệch lên trên nửa mét so với hình.
local function signedGap(beam: Beam, worldPos: Vector3, at: number): number?
	local lp = beam.home:PointToObjectSpace(worldPos)
	if math.abs(lp.Z) > SW.HalfWidth or math.abs(lp.Y + SW.BodyCenterYOffset) > SW.HalfHeight then
		return nil
	end
	return lp.X - Zone15Traps.SweepOffset(at, beam.index)
end

local function evaluate(prev: Sample, pos: Vector3, now: number): boolean
	for i = 1, #beams do
		local beam = beams[i]
		local gapNow = signedGap(beam, pos, now)
		if gapNow then
			-- (a) đang đứng/đi chậm ngay trong tia
			if math.abs(gapNow) <= SW.HalfThickness then
				return true
			end
			-- (b) quét: tick trước ở một bên tia, tick này ở bên kia → đã xuyên qua
			local gapPrev = signedGap(beam, prev.pos, prev.t)
			if gapPrev and gapPrev * gapNow < 0 then
				return true
			end
		end
	end
	return false
end

local function tick()
	local origin = center
	if not origin or #beams == 0 then
		return
	end
	-- StreamingEnabled: cụm bị dỡ thì tham chiếu vẫn còn nhưng đã rời Workspace.
	if not beams[1].part:IsDescendantOf(Workspace) then
		return
	end

	local now = Workspace:GetServerTimeNow()

	for _, player in Players:GetPlayers() do
		local root = CharacterUtil.GetAliveRoot(player)
		if not root then
			samples[player] = nil
			continue
		end

		local pos = root.Position
		local dx, dz = pos.X - origin.X, pos.Z - origin.Z
		local near = dx * dx + dz * dz <= WAKE_RADIUS_SQ
		local prev = samples[player]

		if not prev then
			samples[player] = { pos = pos, t = now, near = near }
			continue
		end

		-- Ở xa: đây là lối thoát rẻ cho 99% player, không chạm tới phần toán nào.
		if near or prev.near then
			if evaluate(prev, pos, now) then
				local last = lastKill[player] or 0
				if now - last >= KILL_COOLDOWN then
					lastKill[player] = now
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = 0
					end
				end
			end
		end

		prev.pos, prev.t, prev.near = pos, now, near
	end
end

--=====================================================================================

function Zone15TrapService.Init() end

function Zone15TrapService.Start()
	task.spawn(function()
		-- Zone có thể chưa nạp xong lúc server vừa lên.
		while not setup() do
			task.wait(1)
		end

		while true do
			task.wait(TICK_RATE)
			tick()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		samples[player] = nil
		lastKill[player] = nil
	end)
end

return Zone15TrapService
