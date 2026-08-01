--!strict
--[[
	Zone2LaserService.luau — Server cho dàn laser quét Stage 2.

	THAY THẾ script inline Zone2LaserScript (xoay Pivot mỗi Heartbeat → replicate CFrame liên
	tục) + các Touched-kill trên từng beam.

	Mô hình mới "render ở client, phán xử ở server":
	  • Server KHÔNG xoay Pivot. Chỉ chuẩn hoá part (anchor pivot, tắt Touch beam), ghi rpm/dir
	    lên model rồi bật cờ LasersReady cho client dựng.
	  • Sát thương phân xử ở 20Hz: tính góc ảo từ đồng hồ, dựng lại đoạn thẳng của từng beam
	    và kiểm tra người chơi nằm trong hộp beam. Không dùng Touched → 0 chi phí va chạm engine.
	  • Mỗi player thoát sớm bằng 1 phép so hộp bao dàn laser (đa số người không ở Stage 2).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterUtil = require(ReplicatedStorage.Shared.Util.CharacterUtil)
local Zone2Lasers = require(ReplicatedStorage.Shared.Config.Zones.Zone2Lasers)

local Zone2LaserService = {}

local TICK_RATE = 1 / 20
local KILL_COOLDOWN = 0.85
local BODY_HALF_HEIGHT = 2.5 -- nửa thân người
local BODY_HALF_WIDTH = 1.5
local WAKE_PAD = 40

type Beam = { relCF: CFrame, halfLen: number, halfThick: number, halfHeight: number }
type Laser = { pivot: BasePart, base: CFrame, rpm: number, dir: number, beams: { Beam } }

local lasers: { Laser } = {}
local lastKill: { [Player]: number } = {}
local wakeMinX, wakeMaxX, wakeMinZ, wakeMaxZ = 0, 0, 0, 0
local ready = false

local function getNumberAttr(inst: Instance?, name: string, fallback: number): number
	if inst then
		local v = inst:GetAttribute(name)
		if type(v) == "number" then
			return v
		end
	end
	return fallback
end

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(Zone2Lasers.ZoneName)
	local mechanics = zone and zone:FindFirstChild("Mechanics")
	if not zone or not mechanics then
		return false
	end

	table.clear(lasers)
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge

	for _, model in mechanics:GetChildren() do
		local default = model:IsA("Model") and Zone2Lasers.Defaults[model.Name]
		local pivot = default and model:FindFirstChild("Pivot")
		if default and pivot and pivot:IsA("BasePart") then
			-- Ghi rpm/dir lên model để client đọc (ưu tiên attribute có sẵn trong map).
			local rpm = getNumberAttr(model, "RPM", default.rpm)
			local dir = getNumberAttr(model, "Dir", default.dir)
			model:SetAttribute("RPM", rpm)
			model:SetAttribute("Dir", dir)

			-- Tắt script legacy per-model (nếu còn).
			local legacy = model:FindFirstChildWhichIsA("Script")
			if legacy then
				legacy.Disabled = true
			end

			local base = pivot.CFrame
			pivot.Anchored = true
			-- Client dời pivot cục bộ nên KHÔNG đọc được góc gốc từ pivot.CFrame sau này.
			-- Ghi BaseCF cố định để client re-resolve bao nhiêu lần cũng ra đúng gốc.
			pivot:SetAttribute("BaseCF", base)

			local beams: { Beam } = {}
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and Zone2Lasers.IsBeam(part, pivot) then
					part.CanTouch = false
					part.CanQuery = false
					part.CanCollide = false
					table.insert(beams, {
						relCF = base:ToObjectSpace(part.CFrame),
						halfLen = part.Size.X * 0.5,
						halfThick = part.Size.Z * 0.5,
						halfHeight = part.Size.Y * 0.5,
					})
				end
			end

			if #beams > 0 then
				table.insert(lasers, { pivot = pivot, base = base, rpm = rpm, dir = dir, beams = beams })
				local p = pivot.Position
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
			end
		end
	end

	if #lasers == 0 then
		return false
	end

	wakeMinX, wakeMaxX = minX - WAKE_PAD, maxX + WAKE_PAD
	wakeMinZ, wakeMaxZ = minZ - WAKE_PAD, maxZ + WAKE_PAD
	zone:SetAttribute(Zone2Lasers.ReadyAttribute, true)
	return true
end

local function inWakeBox(pos: Vector3): boolean
	return pos.X >= wakeMinX and pos.X <= wakeMaxX and pos.Z >= wakeMinZ and pos.Z <= wakeMaxZ
end

-- Người chơi có chạm beam nào của laser này tại thời điểm `now` không?
local function hitByLaser(laser: Laser, pos: Vector3, now: number): boolean
	local angle = math.rad(Zone2Lasers.AngleDeg(now, laser.rpm, laser.dir))
	local pivotNow = laser.base * CFrame.Angles(0, angle, 0)
	for i = 1, #laser.beams do
		local beam = laser.beams[i]
		local lp = (pivotNow * beam.relCF):PointToObjectSpace(pos)
		if
			math.abs(lp.X) <= beam.halfLen
			and math.abs(lp.Z) <= beam.halfThick + BODY_HALF_WIDTH
			and math.abs(lp.Y) <= beam.halfHeight + BODY_HALF_HEIGHT
		then
			return true
		end
	end
	return false
end

local function tick()
	if not ready or #lasers == 0 then
		return
	end
	if not lasers[1].pivot:IsDescendantOf(Workspace) then
		ready = false
		return
	end

	local now = Workspace:GetServerTimeNow()
	for _, player in Players:GetPlayers() do
		local root = CharacterUtil.GetAliveRoot(player)
		if root and inWakeBox(root.Position) then
			for i = 1, #lasers do
				if hitByLaser(lasers[i], root.Position, now) then
					local last = lastKill[player] or 0
					if now - last >= KILL_COOLDOWN then
						lastKill[player] = now
						local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid.Health = 0
						end
					end
					break
				end
			end
		end
	end
end

function Zone2LaserService.Init() end

function Zone2LaserService.Start()
	task.spawn(function()
		while not resolve() do
			task.wait(1)
		end
		ready = true
		print(`[Zone2LaserService] {#lasers} laser — render client, phán xử server 20Hz`)

		while true do
			task.wait(TICK_RATE)
			tick()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKill[player] = nil
	end)
end

return Zone2LaserService
