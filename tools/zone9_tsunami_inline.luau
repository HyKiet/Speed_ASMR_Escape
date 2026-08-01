-- BẢN THAM CHIẾU (version-controlled) của Workspace.Zone9.Mechanics.Tsunami.TsunamiScript (v4)
-- Script thật sống inline trong Workspace (KHÔNG Rojo sync) — được ghi qua MCP execute_luau.
-- Nếu cần sửa: sửa file này rồi ghi lại Source vào Studio.
--
-- v4 (2026-07-22): sóng nhanh hơn (148 → 190 studs/s) và quay về vạch xuất phát nhanh hơn
-- (RESPAWN_DELAY 1.2 → 0.45s). Vị trí xuất phát đọc từ pivot model nên kéo Tsunami trong
-- Studio là code chạy theo, không cần sửa số ở đây.

--!strict
--[[
	Zone9 TsunamiScript — Tsunami Sprint (v4: deterministic clock, zero-replication)
	Server KHÔNG PivotTo model (trước đây replicate ~15 part CFrame mỗi frame).
	Vị trí sóng = f(workspace:GetServerTimeNow()) → client dựng lại y hệt và render local.
	Early-out: không có ai ở stage 9 → Heartbeat thoát ngay (Server CPU ~0ms).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local model = script.Parent
local mech = model.Parent
local zone = mech.Parent
local ground = zone:FindFirstChild("Ground")
local floor = ground and ground:FindFirstChild("WaterFloor")
local stageStart = mech:FindFirstChild("Stage9Start")
local stageFinish = mech:FindFirstChild("Stage9Finish")

local STAGE = 9
local WAVE_SPEED = 190 -- v4: đuổi gắt hơn (cũ 148)
local RESPAWN_DELAY = 0.45 -- v4: sóng quay về vạch xuất phát gần như tức thì (cũ 1.2)
local KILL_CD = 0.5

-- v6 (2026-07-25): kênh lấy theo Z của model — vị trí user đặt tay trong Edit là nguồn sự thật.
local channelZ = model:GetPivot().Position.Z
local channelWidth = floor and floor.Size.Z or 90
local finishX = stageFinish.Position.X

local homePivot = model:GetPivot()
local homeX = homePivot.Position.X
local baseY = homePivot.Position.Y
local baseRot = homePivot.Rotation

for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
	end
end
local _, boxSize = model:GetBoundingBox()
local killHalf = math.max(7, boxSize.X * 0.5)

local SWEEP_DURATION = math.max(0.1, (finishX - homeX) / WAVE_SPEED)
local CYCLE = SWEEP_DURATION + RESPAWN_DELAY

-- Hợp đồng chia sẻ với Zone9TsunamiController (client).
zone:SetAttribute("WaveSpeed", WAVE_SPEED)
zone:SetAttribute("WaveHomeX", homeX)
zone:SetAttribute("WaveFinishX", finishX)
zone:SetAttribute("WaveY", baseY)
zone:SetAttribute("WaveZ", channelZ)
zone:SetAttribute("WaveRot", baseRot)
zone:SetAttribute("WaveCycle", CYCLE)
zone:SetAttribute("WaveSweepDuration", SWEEP_DURATION)

local minX, maxX = math.min(homeX, finishX) - 14, math.max(homeX, finishX) + 14
local halfChannel = channelWidth * 0.5 + 8

local lastKill: { [Player]: number } = {}
local immune: { [Player]: boolean } = {}

if stageFinish then
	stageFinish.Touched:Connect(function(hit)
		local c = hit:FindFirstAncestorOfClass("Model")
		local plr = c and Players:GetPlayerFromCharacter(c)
		if plr then
			immune[plr] = true
		end
	end)
end
if stageStart then
	stageStart.Touched:Connect(function(hit)
		local c = hit:FindFirstAncestorOfClass("Model")
		local plr = c and Players:GetPlayerFromCharacter(c)
		if plr then
			immune[plr] = nil
		end
	end)
end

RunService.Heartbeat:Connect(function()
	local t = Workspace:GetServerTimeNow() % CYCLE
	if t >= SWEEP_DURATION then
		return -- pha "wait": sóng đã ẩn, không có sát thương
	end

	local waveX = homeX + WAVE_SPEED * t

	for _, plr in Players:GetPlayers() do
		-- Early-out guard theo từng player, không alloc bảng trung gian.
		if plr:GetAttribute("ActiveStage") == STAGE and not immune[plr] then
			local c = plr.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if h and h.Health > 0 and r and r:IsA("BasePart") then
				local p = r.Position
				if
					math.abs(p.Z - channelZ) <= halfChannel
					and p.X >= minX
					and p.X <= maxX
					and math.abs(p.X - waveX) <= killHalf
				then
					local now = os.clock()
					if now - (lastKill[plr] or 0) >= KILL_CD then
						lastKill[plr] = now
						h.Health = 0
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastKill[plr] = nil
	immune[plr] = nil
end)
