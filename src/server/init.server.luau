--!strict -- Bật chế độ Type Checking nghiêm ngặt của Luau (ngôn ngữ lập trình của Roblox). Giúp phát hiện lỗi sớm trước khi chạy game!

-- Bộ khởi chạy Server Modular (Custom Bootstrapper)
-- Đây là "trái tim" của Server. Thay vì chạy nhiều script riêng lẻ, file này tự động tìm và chạy tất cả Services (dịch vụ).

-- script:WaitForChild("Services") dùng để tìm thư mục có tên "Services" nằm bên trong script này.
-- WaitForChild là một cách an toàn để lấy Instance vì nó sẽ đợi cho đến khi Instance đó được tải xong hoàn toàn.
local ServicesFolder = script:WaitForChild("Services")

print("--- [SERVER LOADING] Bắt đầu nạp các dịch vụ trên Server... ---")

-- Khởi tạo bảng (table) trống để lưu trữ các dịch vụ đã tải thành công.
local Services = {}

-- ============================================================================
-- GIAI ĐOẠN 1: QUÉT VÀ NẠP TẤT CẢ MODULESCRIPT TRONG THƯ MỤC SERVICES
-- ============================================================================
-- GetChildren() lấy ra danh sách tất cả các đối tượng con nằm trực tiếp trong thư mục ServicesFolder.
for _, module in ServicesFolder:GetChildren() do
	-- Kiểm tra xem đối tượng con đó có đúng là kiểu "ModuleScript" hay không.
	if module:IsA("ModuleScript") then
		-- pcall (Protected Call) chạy hàm require(module) trong một chế độ an toàn.
		-- Nếu ModuleScript có lỗi cú pháp hoặc bị crash, pcall sẽ bắt lỗi đó và trả về success = false mà không làm crash toàn bộ Server.
		-- require() là hàm dùng để nạp nội dung của một ModuleScript và trả về giá trị (thường là một table).
		local success, service = pcall(require, module)
		if success then
			-- Lưu dịch vụ vào bảng Services với tên của file làm khóa (Key).
			Services[module.Name] = service
		else
			-- Nếu có lỗi, cảnh báo (warn) sẽ in ra màn hình Output màu cam nhưng không làm gián đoạn game.
			warn("[SERVER ERROR] Lỗi nạp dịch vụ: " .. module.Name .. " | Chi tiết lỗi: " .. tostring(service))
		end
	end
end

-- ============================================================================
-- GIAI ĐOẠN 2: KHỞI TẠO (INIT)
-- ============================================================================
-- Vòng lặp này chạy qua tất cả các dịch vụ đã nạp thành công ở Giai đoạn 1.
for name, service in Services do
	-- Kiểm tra xem trong dịch vụ đó có định nghĩa hàm tên là "Init" hay không.
	if type(service.Init) == "function" then
		-- Chạy hàm Init() trong chế độ an toàn pcall.
		-- Init là nơi chúng ta thiết lập biến ban đầu, tạo RemoteEvent, nạp cấu hình,... (không chứa logic chạy lâu dài).
		local success, err = pcall(service.Init)
		if not success then
			warn("[SERVER ERROR] Lỗi Khởi tạo (Init) dịch vụ: " .. name .. " | Chi tiết lỗi: " .. tostring(err))
		end
	end
end

-- ============================================================================
-- GIAI ĐOẠN 3: BẮT ĐẦU CHẠY LOGIC GAME (START)
-- ============================================================================
for name, service in Services do
	-- Kiểm tra xem trong dịch vụ đó có hàm "Start" hay không.
	if type(service.Start) == "function" then
		-- Sử dụng task.spawn để chạy hàm Start() trong một luồng (thread) chạy song song riêng biệt.
		-- task.spawn() là thư viện quản lý tác vụ hiện đại nhất của Roblox (thay thế cho spawn() cũ lỗi thời).
		-- Nó đảm bảo nếu một dịch vụ bị dừng hoặc chạy vòng lặp vô hạn, nó cũng KHÔNG làm đóng băng các dịch vụ khác.
		task.spawn(function()
			local success, err = pcall(service.Start)
			if not success then
				warn("[SERVER ERROR] Lỗi Bắt đầu (Start) dịch vụ: " .. name .. " | Chi tiết lỗi: " .. tostring(err))
			end
		end)
	end
end

print("--- [SERVER READY] Tất cả các dịch vụ trên Server đã được nạp thành công! ---")

