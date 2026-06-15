--!strict -- Bật chế độ kiểm tra kiểu dữ liệu nghiêm ngặt trên Client.

-- Bộ khởi chạy Client Modular (Custom Bootstrapper)
-- Đây là điểm xuất phát của game trên Client (thiết bị người chơi). Nó tự động chạy các Controllers (bộ điều khiển giao diện, âm thanh, điều khiển nhân vật).

-- Tìm thư mục Controllers nằm bên trong LocalScript này.
local ControllersFolder = script:WaitForChild("Controllers")

print("--- [CLIENT LOADING] Bắt đầu nạp các bộ điều khiển (Controllers) trên Client... ---")

local Controllers = {}

-- ============================================================================
-- GIAI ĐOẠN 1: QUÉT VÀ NẠP TẤT CẢ MODULESCRIPT TRONG THƯ MỤC CONTROLLERS
-- ============================================================================
for _, module in ControllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		-- Nạp module trong chế độ an toàn pcall. 
		-- Ở Client, pcall rất quan trọng vì máy người chơi có thể tải tài nguyên chậm hoặc gặp lỗi cục bộ.
		local success, controller = pcall(require, module)
		if success then
			Controllers[module.Name] = controller
		else
			warn("[CLIENT ERROR] Lỗi nạp bộ điều khiển: " .. module.Name .. " | Chi tiết lỗi: " .. tostring(controller))
		end
	end
end

-- ============================================================================
-- GIAI ĐOẠN 2: KHỞI TẠO (INIT)
-- ============================================================================
for name, controller in Controllers do
	if type(controller.Init) == "function" then
		-- Chạy hàm Init(). Đây là nơi các Controller liên kết sự kiện giao diện (UI) hoặc kết nối RemoteEvent từ Server.
		local success, err = pcall(controller.Init)
		if not success then
			warn("[CLIENT ERROR] Lỗi Khởi tạo (Init) bộ điều khiển: " .. name .. " | Chi tiết lỗi: " .. tostring(err))
		end
	end
end

-- ============================================================================
-- GIAI ĐOẠN 3: BẮT ĐẦU CHẠY LOGIC GAME (START)
-- ============================================================================
for name, controller in Controllers do
	if type(controller.Start) == "function" then
		-- Chạy song song hàm Start(). Đây là nơi các Controller thực thi vòng lặp cập nhật UI, kiểm tra hành vi bấm phím của người chơi.
		task.spawn(function()
			local success, err = pcall(controller.Start)
			if not success then
				warn("[CLIENT ERROR] Lỗi Bắt đầu (Start) bộ điều khiển: " .. name .. " | Chi tiết lỗi: " .. tostring(err))
			end
		end)
	end
end

print("--- [CLIENT READY] Tất cả các bộ điều khiển trên Client đã được nạp thành công! ---")

