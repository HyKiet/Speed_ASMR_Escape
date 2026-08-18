--!strict
--[[
	KillBlockVisualController.luau — dòng dung nham chảy nhẹ trên Texture của KillBlockGlobal.

	BẢN CŨ SAI CHỖ NÀO: cull bằng khoảng cách camera → `part.Position`, tức TÂM part. Các
	slab lava rộng tới 2047 studs nên tâm luôn cách camera hàng trăm studs ⇒ điều kiện
	`distSq <= 90²` gần như không bao giờ đúng ⇒ lava đứng im trong lúc vẫn tốn một vòng
	lặp RenderStepped 60Hz quét toàn bộ texture mỗi khung hình. Vừa mất hiệu ứng vừa tốn CPU.

	BẢN NÀY:
	  • Cull theo BỀ MẶT (khoảng cách tới hộp bao OBB) nên slab to vẫn được tính là "gần".
	  • 24Hz thay vì RenderStepped 60Hz — offset texture không cần mượt hơn thế.
	  • Offset tính MỘT LẦN mỗi tick rồi gán cho mọi texture cùng cỡ tile, không tính lại
	    theo từng texture.
	  • Bỏ hẳn mặt Bottom (không bao giờ nhìn thấy dưới đáy biển dung nham).
	  • Không có part nào trong tầm → thoát ngay, 0 công việc.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KillBlockVisualController = {}

local FOLDER_NAME = "KillBlockGlobal"

-- Dung nham chảy chậm: đây là biển nền, không phải dòng thác. Tile texture rộng 30 studs
-- nên 0.9 stud/s ≈ 33s một vòng lặp — thấy rõ đang chảy mà không lượn nhanh gây rối mắt.
local FLOW_U = 0.9
local FLOW_V = 0.58
local SWAY_AMPLITUDE = 0.3
local SWAY_RATE = 0.7

local UPDATE_HZ = 24
local UPDATE_INTERVAL = 1 / UPDATE_HZ
-- Đo tới bề mặt slab, không tới tâm. 260 studs ≈ vừa quá tầm nhìn thấy rõ chuyển động.
local CULL_DISTANCE = 260
local CULL_DISTANCE_SQ = CULL_DISTANCE * CULL_DISTANCE

type Entry = {
	part: BasePart,
	textures: { Texture },
}

local entries: { Entry } = {}
local entryByPart: { [BasePart]: Entry } = {}
local accumulator = 0

local function isAnimatedFace(texture: Texture): boolean
	-- Đáy slab dung nham không bao giờ lọt vào khung hình.
	return texture.Face ~= Enum.NormalId.Bottom
end

local function trackTexture(inst: Instance)
	if not inst:IsA("Texture") then
		return
	end
	local part = inst.Parent
	if not (part and part:IsA("BasePart")) then
		return
	end
	if not isAnimatedFace(inst) then
		return
	end

	local entry = entryByPart[part]
	if not entry then
		entry = { part = part, textures = {} }
		entryByPart[part] = entry
		table.insert(entries, entry)
	end
	table.insert(entry.textures, inst)
end

local function untrackTexture(inst: Instance)
	if not inst:IsA("Texture") then
		return
	end
	local part = inst.Parent
	if not (part and part:IsA("BasePart")) then
		return
	end
	local entry = entryByPart[part]
	if not entry then
		return
	end
	local index = table.find(entry.textures, inst)
	if index then
		table.remove(entry.textures, index)
	end
end

local function scanFolder(folder: Folder)
	for _, desc in folder:GetDescendants() do
		trackTexture(desc)
	end
	folder.DescendantAdded:Connect(trackTexture)
	folder.DescendantRemoving:Connect(untrackTexture)
end

-- Khoảng cách bình phương từ điểm tới HỘP BAO của part (0 nếu điểm nằm trong).
-- Dùng object-space nên đúng cả khi slab bị xoay.
local function distanceSqToPart(part: BasePart, point: Vector3): number
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	local dx = math.max(math.abs(localPoint.X) - half.X, 0)
	local dy = math.max(math.abs(localPoint.Y) - half.Y, 0)
	local dz = math.max(math.abs(localPoint.Z) - half.Z, 0)
	return dx * dx + dy * dy + dz * dz
end

function KillBlockVisualController.Init() end

function KillBlockVisualController.Start()
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		scanFolder(folder)
	end

	Workspace.ChildAdded:Connect(function(child)
		if child.Name == FOLDER_NAME and child:IsA("Folder") then
			scanFolder(child)
		end
	end)

	local elapsed = 0

	RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < UPDATE_INTERVAL then
			return
		end
		elapsed += accumulator
		accumulator = 0

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local camPos = camera.CFrame.Position

		-- Pha dòng chảy: tính một lần cho cả frame.
		local flowU = elapsed * FLOW_U
		local flowV = elapsed * FLOW_V + math.sin(elapsed * SWAY_RATE) * SWAY_AMPLITUDE

		for index = #entries, 1, -1 do
			local entry = entries[index]
			local part = entry.part

			if not part.Parent then
				-- Slab bị stream ra: gỡ khỏi danh sách, DescendantAdded sẽ thêm lại.
				entryByPart[part] = nil
				table.remove(entries, index)
				continue
			end

			if distanceSqToPart(part, camPos) <= CULL_DISTANCE_SQ then
				for _, texture in entry.textures do
					-- % theo cỡ tile để offset không phình vô hạn (mất chính xác float).
					texture.OffsetStudsU = flowU % math.max(0.1, texture.StudsPerTileU)
					texture.OffsetStudsV = flowV % math.max(0.1, texture.StudsPerTileV)
				end
			end
		end
	end)

	print(
		("[KillBlockVisualController] Dung nham chảy nhẹ — %d slab, %dHz, cull %d studs tính theo bề mặt"):format(
			#entries,
			UPDATE_HZ,
			CULL_DISTANCE
		)
	)
end

return KillBlockVisualController
