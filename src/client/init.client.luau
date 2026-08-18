--!strict
-- Bootstrapper Client.
-- Duyệt đệ quy thư mục `Controllers/`, nạp mọi ModuleScript thành Controller,
-- đăng ký vào ServiceLocator, rồi gọi Init() và Start() theo thứ tự.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceLocator =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("ServiceLocator"))

local ControllersFolder = script:WaitForChild("Controllers")

print("--- [CLIENT LOADING] Bắt đầu nạp các bộ điều khiển (Controllers) trên Client... ---")

type Controller = { Init: (() -> ())?, Start: (() -> ())? }
local controllers: { [string]: Controller } = {}

local function collectModules(folder: Instance, into: { ModuleScript })
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(into, child)
		elseif child:IsA("Folder") then
			collectModules(child, into)
		end
	end
end

-- Cây Controllers replicate DẦN về client. WaitForChild("Controllers") chỉ đảm bảo có thư mục
-- gốc, không đảm bảo các thư mục con (Zones/, HUD/, ASMR/, CoreLoop/...) đã tới. Nếu quét ngay
-- thì có phiên chỉ bắt được vài module con trực tiếp — số còn lại IM LẶNG không nạp, không warn,
-- mà vẫn in "nạp thành công" (đã bắt được phiên chỉ nạp 1/90 module, Zone 9 sóng thần đứng im).
-- Chờ số lượng con cháu ổn định vài khung hình rồi mới quét.
local function awaitTreeStable(root: Instance)
	local last = -1
	local stableFrames = 0
	local deadline = os.clock() + 10
	while os.clock() < deadline do
		local count = #root:GetDescendants()
		if count == last and count > 0 then
			stableFrames += 1
			if stableFrames >= 3 then
				return
			end
		else
			stableFrames = 0
			last = count
		end
		task.wait(0.1)
	end
end

awaitTreeStable(ControllersFolder)

local modules: { ModuleScript } = {}
collectModules(ControllersFolder, modules)

-- Giai đoạn 1: require + register
for _, module in modules do
	local success, controller = pcall(require, module)
	if success then
		if controllers[module.Name] then
			warn(`[CLIENT WARN] Hai bộ điều khiển trùng tên: {module.Name}. Giữ bản đầu tiên.`)
		else
			controllers[module.Name] = controller
			ServiceLocator.Register(module.Name, controller)
		end
	else
		warn(`[CLIENT ERROR] Lỗi nạp bộ điều khiển: {module.Name} | Chi tiết: {tostring(controller)}`)
	end
end

-- Giai đoạn 2: Init đồng bộ
for name, controller in controllers do
	if type(controller.Init) == "function" then
		local success, err = pcall(controller.Init)
		if not success then
			warn(`[CLIENT ERROR] Lỗi Init bộ điều khiển: {name} | Chi tiết: {tostring(err)}`)
		end
	end
end

-- Giai đoạn 3: Start song song
for name, controller in controllers do
	if type(controller.Start) == "function" then
		task.spawn(function()
			local success, err = pcall(controller.Start)
			if not success then
				warn(`[CLIENT ERROR] Lỗi Start bộ điều khiển: {name} | Chi tiết: {tostring(err)}`)
			end
		end)
	end
end

print(`--- [CLIENT READY] Đã nạp {#modules} bộ điều khiển trên Client. ---`)
