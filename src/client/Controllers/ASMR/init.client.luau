--!strict
-- Client: gắn/tháo adapter theo tag ASMRFloor và cập nhật tất cả sàn bằng một Heartbeat.
-- Chỉ phản hồi bước chân LocalPlayer; các adapter dùng chung pool âm thanh, hạt và FxBudget.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FLOOR_TAG = "ASMRFloor"

local FxBudget = require(script.Engine.FxBudget)
local SoundPool = require(script.Engine.SoundPool)
local ParticlePool = require(script.Engine.ParticlePool)
local SpatialGrid = require(script.Engine.SpatialGrid)
local Bounds = require(script.Engine.Bounds)
local Await = require(script.Engine.Await)
local GroundLimit = require(script.Engine.GroundLimit)

local Floors = {}
for _, mod in script.Floors:GetChildren() do
	if mod:IsA("ModuleScript") then
		Floors[mod.Name] = require(mod)
	end
end

local engine = {
	FxBudget = FxBudget,
	SoundPool = SoundPool,
	ParticlePool = ParticlePool,
	SpatialGrid = SpatialGrid,
	Bounds = Bounds,
	Await = Await,
	GroundLimit = GroundLimit,
}

-- container runtime (sound pool + particle anchors) — local, không replicate
local runtime = Instance.new("Folder")
runtime.Name = "ASMRRuntime"
runtime.Parent = workspace

-- preload + WARM toàn bộ sound của MỌI loại sàn đúng 1 lần lúc load
local allIds, seen = {}, {}
-- Sàn nào rút về ít mẫu (sàn phím: 1 mẫu/lớp) phải khai `Floor.voices = { [id] = n }`,
-- nếu không giọng bị cướp lại giữa chừng khi chạy nhanh và mẫu gần như không kịp kêu.
-- Nhiều sàn cùng khai một id thì lấy số LỚN NHẤT.
local voiceCounts = {}
-- `Floor.voiceFx = { [id] = { low=, mid=, high= } }` (dB): gắn EqualizerSoundEffect cố định
-- lên giọng của id đó. Dùng khi mẫu bị chói (nốt piano pitch-shift) — hạ `high` là đủ mềm.
local voiceFx = {}
for _, floor in Floors do
	for _, id in floor.soundIds or {} do
		if not seen[id] then
			seen[id] = true
			table.insert(allIds, id)
		end
	end
	for id, n in floor.voices or {} do
		if not voiceCounts[id] or n > voiceCounts[id] then
			voiceCounts[id] = n
		end
	end
	for id, fx in floor.voiceFx or {} do
		voiceFx[id] = fx
	end
end
SoundPool.init(runtime, allIds, voiceCounts, voiceFx)
ParticlePool.init(runtime)

-- ===== registry: tag -> adapter instance =====
local instances = {} -- [Model] = floorInstance
local instanceList = {} -- mảng để loop nhanh trong Heartbeat
local reattachCount: { [Instance]: number } = {}

local function rebuildList()
	table.clear(instanceList)
	for _, inst in instances do
		table.insert(instanceList, inst)
	end
end

local function attach(model)
	if instances[model] or not model:IsDescendantOf(workspace) or not CollectionService:HasTag(model, FLOOR_TAG) then
		return
	end
	local floorType = model:GetAttribute("FloorType")
	local floor = floorType and Floors[floorType]
	if not floor then
		warn("[ASMR Engine] FloorType không hợp lệ:", model:GetFullName(), tostring(floorType))
		return
	end
	instances[model] = floor.attach(model, engine)
	rebuildList()
end

local function detach(model)
	local inst = instances[model]
	if inst then
		instances[model] = nil
		rebuildList()
		if inst.destroy then
			inst.destroy()
		end
	end
end

CollectionService:GetInstanceAddedSignal(FLOOR_TAG):Connect(attach)
CollectionService:GetInstanceRemovedSignal(FLOOR_TAG):Connect(function(model)
	reattachCount[model] = nil
	detach(model)
end)
for _, m in CollectionService:GetTagged(FLOOR_TAG) do
	task.spawn(attach, m)
end

-- WATCHDOG: attach() ghi instances[model] NGAY, còn adapter mới init bất đồng bộ bên trong
-- (WaitForChild "Tiles"/"Blocks" rồi dựng hình). Dưới StreamingEnabled, Model có thể tới
-- client trước con của nó; nếu chờ quá hạn, adapter lặng lẽ return — model coi như đã attach
-- vĩnh viễn và KHÔNG BAO GIỜ dựng lại được. Sàn chết câm, không lỗi, không log
-- (Zone 14 slime đã dính: phải gỡ/gắn lại tag bằng tay mới hiện).
-- Ở đây thử lại các sàn chưa `ready`, có giới hạn để sàn rỗng hợp lệ không quay vô hạn.
local MAX_REATTACH = 3

task.spawn(function()
	while true do
		task.wait(3)
		for model, inst in instances do
			-- Không tháo adapter đang WaitForChild: instance con có thể chưa stream về sau 3 giây.
			local initializing = inst.initTask and coroutine.status(inst.initTask) ~= "dead"
			if not inst.ready and not initializing and model:IsDescendantOf(workspace) then
				local tries = reattachCount[model] or 0
				if tries < MAX_REATTACH then
					reattachCount[model] = tries + 1
					warn("[ASMR Engine] Nạp sàn chưa thành công, thử lại:", model:GetFullName(), tries + 1)
					detach(model)
					task.spawn(attach, model)
				end
			end
		end
	end
end)

-- ===== vòng chính: 1 Heartbeat duy nhất =====
local player = Players.LocalPlayer
local lastFootPos = nil

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()

	-- foot context tính đúng 1 lần/frame, chia sẻ cho mọi sàn
	local foot = nil
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and hum and hum.Health > 0 then
		local pos = root.Position
		local vel = root.AssemblyLinearVelocity
		foot = {
			root = root,
			pos = pos,
			lastPos = lastFootPos,
			vel = vel,
			ratio = math.clamp(Vector3.new(vel.X, 0, vel.Z).Magnitude / 250, 0, 1),
		}
		lastFootPos = pos
	else
		lastFootPos = nil
	end

	-- mỗi sàn tự early-out khi chân ngoài vùng + không có animation sống → gần như 0 chi phí
	for _, inst in instanceList do
		inst.update(dt, now, foot)
	end
end)

local floorCount = 0
for _ in Floors do
	floorCount += 1
end
Log.Boot(
	("[ASMR Engine] sẵn sàng — %d loại sàn, %d sound preload, tag '%s'"):format(floorCount, #allIds, FLOOR_TAG)
)
