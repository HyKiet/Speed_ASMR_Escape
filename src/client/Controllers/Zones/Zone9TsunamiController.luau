--!strict
--[[
	Zone9TsunamiController.luau — render local sóng Tsunami Stage 9.

	Server không PivotTo model (xem Zone9.Mechanics.Tsunami.TsunamiScript): vị trí sóng suy ra
	từ workspace:GetServerTimeNow() nên client dựng lại y hệt → 0 byte CFrame replication cho
	~15 part mỗi frame.

	v4 (2026-07-22): GỠ TOÀN BỘ rig hạt bọt/khói theo yêu cầu. Rig cũ chạy 3 ParticleEmitter
	(~230 hạt/giây, texture smoke_main) + 1 PointLight bám theo sóng — đây là khoản nặng nhất
	của zone này trên máy yếu, và bản thân khối sóng đã đủ rõ. Bỏ luôn nên không còn gì để cull.

	v5 (2026-07-26): FIX SÓNG MÉO HÌNH trên client. Bản cũ `model:PivotTo(...)` mỗi frame:
	dưới StreamingEnabled, part stream về LẺ TẺ tại vị trí HOME của server (server không bao
	giờ dời part) trong khi model client đã trôi giữa sweep → offset tương đối của part mới
	so với pivot bị SAI, PivotTo giữ nguyên cái sai đó vĩnh viễn → khối sóng rách/vặn
	(nhìn từ Server view thì lành lặn vì server không move gì). Fix: ghi nhớ offset của
	TỪNG part so với HOME CFrame (tính từ attribute — bất biến) ngay lúc part stream về,
	rồi mỗi frame set part.CFrame = waveCF × offset. Part về muộn bao nhiêu cũng đúng hình.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RENDER_RADIUS = 420
local RENDER_RADIUS_SQ = RENDER_RADIUS * RENDER_RADIUS

local Zone9TsunamiController = {}

local player = Players.LocalPlayer

local model: Model? = nil
local waveSpeed, homeX, finishX, baseY, channelZ = 0, 0, 0, 0, 0
local baseRot = CFrame.identity
local homeCF = CFrame.identity -- CFrame pivot lúc sóng ở home (nguồn sự thật cho offset part)
local cycle, sweepDuration = 1, 1

type PartRecord = { rel: CFrame, transparency: number }
local partRecords: { [BasePart]: PartRecord } = {}
local hidden = false

local ready = false
local connection: RBXScriptConnection? = nil
local descAddedConn: RBXScriptConnection? = nil

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone9")
	local mech = zone and zone:FindFirstChild("Mechanics")
	local found = mech and mech:FindFirstChild("Tsunami")
	if not (zone and found and found:IsA("Model")) then
		return false
	end

	local speedAttr = zone:GetAttribute("WaveSpeed")
	local cycleAttr = zone:GetAttribute("WaveCycle")
	local rotAttr = zone:GetAttribute("WaveRot")
	if typeof(speedAttr) ~= "number" or typeof(cycleAttr) ~= "number" or typeof(rotAttr) ~= "CFrame" then
		return false
	end

	model = found
	waveSpeed = speedAttr
	cycle = cycleAttr
	baseRot = rotAttr
	homeX = zone:GetAttribute("WaveHomeX") :: number
	finishX = zone:GetAttribute("WaveFinishX") :: number
	baseY = zone:GetAttribute("WaveY") :: number
	channelZ = zone:GetAttribute("WaveZ") :: number
	sweepDuration = zone:GetAttribute("WaveSweepDuration") :: number
	homeCF = CFrame.new(homeX, baseY, channelZ) * baseRot

	table.clear(partRecords)

	-- Đăng ký part NGAY khi stream về (poll 0.5s chỉ là lưới an toàn) — part mới phải được
	-- chốt offset trước khi step() kịp thấy nó nằm chỏng chơ ở home giữa lúc sóng đang chạy.
	if descAddedConn then
		descAddedConn:Disconnect()
	end
	descAddedConn = found.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and partRecords[d] == nil then
			partRecords[d] = {
				rel = homeCF:ToObjectSpace(d.CFrame),
				transparency = d.Transparency,
			}
			if hidden then
				d.Transparency = 1
			end
		end
	end)
	return true
end

-- StreamingEnabled: part của sóng stream về LẺ TẺ sau khi resolve() chạy. Mỗi part mới
-- phải được đăng ký NGAY tại vị trí server (= vị trí home) để chốt offset so với homeCF;
-- từ đó về sau client tự đặt CFrame cho nó — part về muộn không bao giờ lệch hình nữa.
local function refreshParts()
	local target = model
	if not target then
		return
	end
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") and partRecords[d] == nil then
			partRecords[d] = {
				-- d.CFrame lúc này là CFrame home do server replicate (server không move part).
				rel = homeCF:ToObjectSpace(d.CFrame),
				transparency = d.Transparency,
			}
			if hidden then
				d.Transparency = 1
			end
		end
	end
end

local function setHidden(state: boolean)
	if hidden == state then
		return
	end
	hidden = state
	for part, rec in partRecords do
		part.Transparency = state and 1 or rec.transparency
	end
end

local function step()
	local target = model
	-- StreamingEnabled=true: model có thể bị dỡ khi đi xa → resolve lại, đừng chết cứng.
	if not target or not target:IsDescendantOf(Workspace) then
		model = nil
		hidden = false
		ready = false
		table.clear(partRecords)
		if descAddedConn then
			descAddedConn:Disconnect()
			descAddedConn = nil
		end
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local dx = root.Position.X - (homeX + finishX) * 0.5
	local dz = root.Position.Z - channelZ
	if dx * dx + dz * dz > RENDER_RADIUS_SQ then
		-- SLEEP: quá xa, ngừng cập nhật vị trí — nhưng PHẢI ẩn sóng trước.
		setHidden(true)
		return
	end

	local t = Workspace:GetServerTimeNow() % cycle
	if t >= sweepDuration then
		setHidden(true)
		return
	end

	setHidden(false)
	local waveCF = CFrame.new(homeX + waveSpeed * t, baseY, channelZ) * baseRot
	for part, rec in partRecords do
		part.CFrame = waveCF * rec.rel
	end
end

function Zone9TsunamiController.Init() end

function Zone9TsunamiController.Start()
	connection = RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			if not ready then
				ready = resolve()
			end
			if ready then
				refreshParts()
			end
			task.wait(0.5)
		end
	end)
end

function Zone9TsunamiController.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Zone9TsunamiController
