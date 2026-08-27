--!strict
--[[
	Zone13GlassGateService.luau — Cổng Thủy Tinh Cyber, Stage 13.

	THAY THẾ script inline `Workspace.Zones.Zone13.Mechanics.Zone13SpringFlingScript`
	(2026-08-27). Cơ chế giữ NGUYÊN 100% — chỉ đưa vào git.

	Cơ chế (v3): bỏ hoàn toàn thanh máu.
	  đủ WalkSpeed  → ĐÂM VỠ TAN cổng, chạy thẳng qua
	  chưa đủ       → cổng đứng nguyên, người chơi bị chặn lại

	Anti-cheat: client chỉ báo "tôi vừa chạm tấm nào". Server tự đọc `humanoid.WalkSpeed`
	(giá trị do server cấp) + tự kiểm tra khoảng cách, nên client không thể khai khống tốc độ
	để phá cổng.

	Mảnh vỡ 3D + SFX do client dựng (packet `glassShattered`), server không sinh part nào
	⇒ 0 replication.

	── VÌ SAO KHÔNG CẦN BÙ TRỄ MẠNG (LagComp) ──────────────────────────────────────────────
	Bẫy này không có phần nào CHUYỂN ĐỘNG theo thời gian: cổng đứng yên cho tới khi bị đập.
	Không có "bẫy-tại-thời-điểm-nào" để lệch, nên không có gì để bù. `MAX_SMASH_DISTANCE` 60
	studs đã đủ rộng để nuốt trọn sai số vị trí do trễ mạng (250 WS × 0.2s = 50 studs).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GamePackets = require(ReplicatedStorage.Shared.Network.GamePackets)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone13GlassGateService = {}

local RESPAWN_DELAY = 1.5
local MAX_SMASH_DISTANCE = 60 -- server tự kiểm: phải thực sự đứng cạnh tấm kính
local SMASH_COOLDOWN = 0.35
local RESOLVE_RETRY = 1

local ground: Instance? = nil
local lastSmash: { [Player]: number } = {}

local function collectWalls(): { BasePart }
	local walls: { BasePart } = {}
	for _, inst in CollectionService:GetTagged("Zone13GlassWall") do
		if inst:IsA("BasePart") then
			table.insert(walls, inst)
		end
	end
	table.sort(walls, function(a, b)
		return a.Position.X < b.Position.X
	end)
	return walls
end

-- Tốc độ yêu cầu tăng dần theo thứ tự cổng (giữ nguyên thang cũ 22..202).
local function initializeWalls(): number
	local walls = collectWalls()
	local count = #walls
	for idx, wall in walls do
		local req = 22 + (idx - 1) * 20
		if idx == count then
			req = 202
		end

		wall:SetAttribute("ReqSpeed", req)
		wall:SetAttribute("Shattered", false)
		-- Bỏ mọi tàn dư thanh máu của bản cũ.
		wall:SetAttribute("HP", nil)
		wall:SetAttribute("MaxHP", nil)
		local gui = wall:FindFirstChild("HealthGui")
		if gui then
			gui:Destroy()
		end

		wall.CanCollide = true
		wall.Transparency = 0.5
		wall.Material = Enum.Material.Glass
	end
	return count
end

local function restore(wall: BasePart)
	wall:SetAttribute("Shattered", false)
	wall.CanCollide = true
	wall.Transparency = 0.5
end

local function resolve(): number?
	local zones = Workspace:FindFirstChild("Zones")
	local zone13 = zones and zones:FindFirstChild("Zone13")
	local groundFolder = zone13 and zone13:FindFirstChild("Ground")
	if not groundFolder then
		return nil
	end
	local count = initializeWalls()
	if count == 0 then
		return nil
	end
	ground = groundFolder
	return count
end

function Zone13GlassGateService.Init() end

function Zone13GlassGateService.Start()
	-- Dọn tàn dư hệ cũ (RemoteEvent thô của bản HP bar).
	local legacyRemote = ReplicatedStorage:FindFirstChild("Zone13GlassDamageEvent")
	if legacyRemote then
		legacyRemote:Destroy()
	end

	GamePackets.requestGlassSmash.listen(function(data, player)
		local groundFolder = ground
		if not groundFolder then
			return
		end
		local wall = groundFolder:FindFirstChild(data.wallName)
		if not wall or not wall:IsA("BasePart") then
			return
		end
		if not CollectionService:HasTag(wall, "Zone13GlassWall") then
			return
		end
		if wall:GetAttribute("Shattered") == true then
			return
		end

		local now = os.clock()
		if now - (lastSmash[player] or 0) < SMASH_COOLDOWN then
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
			return
		end

		-- Kiểm tra server-side: đứng đủ gần + đủ tốc độ THẬT.
		if (root.Position - wall.Position).Magnitude > MAX_SMASH_DISTANCE then
			return
		end
		local req = wall:GetAttribute("ReqSpeed")
		if type(req) ~= "number" or humanoid.WalkSpeed < req then
			return
		end

		lastSmash[player] = now
		wall:SetAttribute("Shattered", true)
		wall.CanCollide = false
		wall.Transparency = 1

		local vel = root.AssemblyLinearVelocity
		local dir = Vector3.new(vel.X, 0, vel.Z)
		dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.xAxis

		GamePackets.glassShattered.sendToAll({
			wallName = wall.Name,
			hitX = root.Position.X,
			hitY = root.Position.Y,
			hitZ = root.Position.Z,
			dirX = dir.X,
			dirZ = dir.Z,
			speed = humanoid.WalkSpeed,
		})

		task.delay(RESPAWN_DELAY, function()
			if wall.Parent then
				restore(wall)
			end
		end)
	end)

	task.spawn(function()
		local count = resolve()
		while not count do
			task.wait(RESOLVE_RETRY)
			count = resolve()
		end
		Log.Boot(`[Zone13GlassGateService] {count} cổng — shatter server-authoritative, không thanh máu`)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSmash[player] = nil
	end)
end

return Zone13GlassGateService
