--!strict
--[[
	KillBlockVisualController.luau — Hiệu ứng sóng biển cuộn cho Texture trong KillBlockGlobal:
	  1. Tự động tìm tất cả Part & Texture bên trong Workspace.KillBlockGlobal.
	  2. Cuộn OffsetStudsU & OffsetStudsV mượt mà theo sóng sin (Ocean Wave animation).
	  3. Lắng nghe động DescendantAdded để hỗ trợ các Part được spawn sau.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local KillBlockVisualController = {}

local FOLDER_NAME = "KillBlockGlobal"
local WAVE_SPEED_U = 2.5 -- Tốc độ trôi dạt ngang
local WAVE_SPEED_V = 1.4 -- Tốc độ dạt dọc
local WAVE_AMPLITUDE = 0.55 -- Độ dao động nhấp nhô của sóng

local activeTextures: { [Texture]: boolean } = {}
local timeAccumulator = 0

local function trackTexture(inst: Instance)
	if inst:IsA("Texture") then
		activeTextures[inst] = true
	end
end

local function untrackTexture(inst: Instance)
	if inst:IsA("Texture") then
		activeTextures[inst] = nil
	end
end

local function scanFolder(folder: Folder)
	for _, desc in folder:GetDescendants() do
		trackTexture(desc)
	end

	folder.DescendantAdded:Connect(trackTexture)
	folder.DescendantRemoving:Connect(untrackTexture)
end

function KillBlockVisualController.Init() end

function KillBlockVisualController.Start()
	-- 1. Scan folder hiện tại nếu đã có sẵn trong Workspace
	local folder = Workspace:FindFirstChild(FOLDER_NAME)
	if folder and folder:IsA("Folder") then
		scanFolder(folder)
	end

	-- 2. Lắng nghe khi folder KillBlockGlobal được tạo muộn
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == FOLDER_NAME and child:IsA("Folder") then
			scanFolder(child)
		end
	end)

local MAX_CULL_DISTANCE_SQ = 90 * 90 -- Chỉ animate texture trong vòng 90 studs quanh Camera

	-- 3. RenderStepped animation vòng lặp sóng biển 60 FPS (Đã tối ưu Distance Culling)
	RunService.RenderStepped:Connect(function(dt: number)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local camPos = camera.CFrame.Position
		timeAccumulator += dt
		local elapsed = timeAccumulator

		for texture, _ in activeTextures do
			local parentPart = texture.Parent
			if parentPart and parentPart:IsA("BasePart") then
				local pPos = parentPart.Position
				local dx = pPos.X - camPos.X
				local dy = pPos.Y - camPos.Y
				local dz = pPos.Z - camPos.Z
				local distSq = dx * dx + dy * dy + dz * dz

				-- Tối ưu Distance Culling: Bỏ qua hoàn toàn các KillBlock ngoài 90 studs
				if distSq <= MAX_CULL_DISTANCE_SQ then
					local tileU = math.max(0.1, texture.StudsPerTileU)
					local tileV = math.max(0.1, texture.StudsPerTileV)

					-- Công thức sóng biển: dạt xuôi dòng + nhấp nhô sóng sin
					local offsetU = (elapsed * WAVE_SPEED_U) % tileU
					local waveV = math.sin(elapsed * 2.4) * WAVE_AMPLITUDE
					local offsetV = (elapsed * WAVE_SPEED_V + waveV) % tileV

					texture.OffsetStudsU = offsetU
					texture.OffsetStudsV = offsetV
				end
			else
				activeTextures[texture] = nil
			end
		end
	end)

	print("[KillBlockVisualController] Ocean Wave Texture Animation Initialized (Camera Distance Culled 90 studs).")
end

return KillBlockVisualController

