--!strict
-- Bootstrapper Server.
-- Duyệt đệ quy thư mục `Services/`, nạp mọi ModuleScript thành Service,
-- đăng ký vào ServiceLocator, rồi gọi Init() và Start() theo thứ tự.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceLocator =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("ServiceLocator"))

local ServicesFolder = script:WaitForChild("Services")

print("--- [SERVER LOADING] Bắt đầu nạp các dịch vụ trên Server... ---")

type Service = { Init: (() -> ())?, Start: (() -> ())? }
local services: { [string]: Service } = {}

local function collectModules(folder: Instance, into: { ModuleScript })
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(into, child)
		elseif child:IsA("Folder") then
			collectModules(child, into)
		end
	end
end

local modules: { ModuleScript } = {}
collectModules(ServicesFolder, modules)

-- Giai đoạn 1: require + register
for _, module in modules do
	local success, service = pcall(require, module)
	if success then
		if services[module.Name] then
			warn(`[SERVER WARN] Hai dịch vụ trùng tên: {module.Name}. Giữ bản đầu tiên.`)
		else
			services[module.Name] = service
			ServiceLocator.Register(module.Name, service)
		end
	else
		warn(`[SERVER ERROR] Lỗi nạp dịch vụ: {module.Name} | Chi tiết: {tostring(service)}`)
	end
end

-- Giai đoạn 2: Init đồng bộ
for name, service in services do
	if type(service.Init) == "function" then
		local success, err = pcall(service.Init)
		if not success then
			warn(`[SERVER ERROR] Lỗi Init dịch vụ: {name} | Chi tiết: {tostring(err)}`)
		end
	end
end

-- Giai đoạn 3: Start song song
for name, service in services do
	if type(service.Start) == "function" then
		task.spawn(function()
			local success, err = pcall(service.Start)
			if not success then
				warn(`[SERVER ERROR] Lỗi Start dịch vụ: {name} | Chi tiết: {tostring(err)}`)
			end
		end)
	end
end

print("--- [SERVER READY] Tất cả các dịch vụ trên Server đã được nạp thành công! ---")
