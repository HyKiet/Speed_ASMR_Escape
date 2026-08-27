--!strict
-- Bootstrapper Server.
-- Duyệt đệ quy thư mục `Services/`, nạp mọi ModuleScript thành Service,
-- đăng ký vào ServiceLocator, rồi gọi Init() và Start() theo thứ tự.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServiceLocator =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("ServiceLocator"))

--[[
	⚠️ PHẢI require TRƯỚC MỌI DỊCH VỤ — đây là chỗ ByteNet khởi động tiến trình server.

	Lỗi đã dính (Error Report QA 2026-08-21, 2 lần, ngay lúc server vừa lên):
	    bufferWriter:148 attempt to index nil with 'size'
	    ← ProgressionService.SendSnapshot ← FriendService.updateFriendsCount

	`nil` đó là `perPlayerReliable[player]` — kênh gửi riêng của một người chơi. ByteNet tạo
	kênh trong `playerAdded`, mà `playerAdded` chỉ được nối vào `Players.PlayerAdded` lúc tiến
	trình server của ByteNet khởi động (`process/server.luau`). Nếu tiến trình đó khởi động
	muộn — nó khởi động ở lần require namespace ĐẦU TIÊN, tức là giữa vòng nạp dịch vụ — thì
	người chơi vào đúng khe hở ấy KHÔNG có kênh, và mọi `sendTo` cho họ ném lỗi suốt phiên.

	Kéo require lên trước vòng nạp là đóng khe hở xuống mức nhỏ nhất có thể từ phía game (đoạn
	còn lại nằm trong chính ByteNet: giữa `Players:GetPlayers()` và `:Connect`). Đổi lại chỉ
	tốn đúng một lần require sớm hơn vài mili giây.

	KHÔNG được gỡ dòng này vì "không ai dùng biến đó" — tác dụng của nó là SIDE EFFECT.
]]
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"):WaitForChild("GamePackets"))

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

--[[
	In PHIÊN BẢN PLACE ra log ngay lúc server lên (2026-08-27).

	Roblox KHÔNG cập nhật server đang chạy: bản vừa publish chỉ áp cho server sinh ra SAU đó.
	Nên khi nghi ngờ "đã lên bản mới chưa", câu trả lời nằm ở con số này chứ không phải ở
	trang publish. `game.PlaceVersion` tăng mỗi lần publish; thấy số cũ = đang ở server cũ.

	`JobId` đi kèm để đối chiếu với danh sách server trên trang web (rỗng = đang trong Studio).
	Người chơi cũng xem được cặp số này trong bảng Cài đặt — xem SettingsModal.makeVersionLabel.
]]
print(
	("--- [SERVER READY] v%d · place %d · job %s ---"):format(
		game.PlaceVersion,
		game.PlaceId,
		if game.JobId ~= "" then string.sub(game.JobId, 1, 8) else "studio"
	)
)
