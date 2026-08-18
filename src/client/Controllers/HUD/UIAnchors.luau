--!strict
--[[
	══════════════════════════════════════════════════════════════════════════════════════════
	  UIAnchors — SỔ ĐĂNG KÝ CÁC ĐIỂM NEO CỦA HUD
	══════════════════════════════════════════════════════════════════════════════════════════

	Một bảng tên → Instance, để những hệ thống KHÁC (tutorial spotlight, quest, sự kiện) trỏ được
	vào đúng một nút trong HUD mà không phải biết nó nằm ở đâu trong cây.

	── VÌ SAO KHÔNG DÒ BẰNG TÊN / CHỮ TRÊN NÚT ────────────────────────────────────────────────
	Cách hay gặp là `for _, d in gui:GetDescendants() do if d.Text == "Daily" then`. Nó hỏng theo
	ba đường, và cả ba đều hỏng ÂM THẦM:
	  • đổi nhãn nút (kể cả dịch sang ngôn ngữ khác) → không tìm thấy, spotlight không hiện;
	  • có hai chỗ cùng chữ đó (nút menu + tiêu đề modal) → chiếu nhầm cái;
	  • nút dựng bằng Fusion nên `Name` rỗng → không có gì để bám.
	Đăng ký một dòng ngay chỗ dựng nút thì mối liên kết nằm ngay cạnh thứ nó mô tả.

	── DÙNG ─────────────────────────────────────────────────────────────────────────────────
	    -- nơi dựng nút:
	    local tile = Theme.MakeMenuButton(...)
	    UIAnchors.Register("dailyButton", tile)

	    -- nơi cần:
	    local target = UIAnchors.Get("dailyButton")        -- có thể nil, LUÔN phải kiểm tra
	    UIAnchors.Await("dailyButton", 5)                  -- chờ tối đa 5 giây

	⚠️ Modal dựng LƯỜI (chỉ khi mở lần đầu), nên nút bên trong modal chưa tồn tại lúc HUD khởi
	động. Vì vậy có `Await` — hỏi `Get` ngay sau khi mở modal thường trả về nil.
]]

local RunService = game:GetService("RunService")

local UIAnchors = {}

local registry: { [string]: Instance } = {}

function UIAnchors.Register(name: string, instance: Instance)
	registry[name] = instance
	--[[
		Đóng dấu tên neo lên chính Instance.

		Sổ đăng ký là một bảng Luau, mà `execute_luau` của Studio chạy ở MỘT VM KHÁC — require từ
		đó ra một bản sao rỗng, nên không có cách nào soi được sổ lúc đang chơi (đã dính: kiểm tra
		báo "nil" trong khi neo vẫn đăng ký đúng). Attribute thì nằm trên Instance nên VM nào cũng
		đọc được:  `for _, d in PlayerGui:GetDescendants() do d:GetAttribute("UIAnchor") end`
	]]
	instance:SetAttribute("UIAnchor", name)
	--[[
		Tự xoá khi Instance chết. Không có dòng này thì sổ giữ tham chiếu tới một GuiObject đã bị
		`Destroy` — `Get` trả về một cái xác không có `Parent`, và spotlight sẽ chiếu vào toạ độ
		(0,0) ở góc màn hình thay vì báo "không tìm thấy".
	]]
	instance.Destroying:Once(function()
		if registry[name] == instance then
			registry[name] = nil
		end
	end)
end

--[[
	Bản dùng NGAY TRONG bảng `[Children]` của Fusion: đăng ký rồi trả lại chính Instance đó, nên
	chỉ cần bọc quanh lời gọi dựng nút mà không phải tách ra thành biến rồi chèn lại vào bảng.

	    UIAnchors.Keep("dailyButton", Theme.MakeMenuButton(...)),
]]
function UIAnchors.Keep(name: string, instance: Instance): Instance
	UIAnchors.Register(name, instance)
	return instance
end

-- Trả về nil nếu chưa đăng ký HOẶC đã bị gỡ khỏi màn hình.
function UIAnchors.Get(name: string): Instance?
	local instance = registry[name]
	if instance and instance.Parent == nil then
		return nil
	end
	return instance
end

--[[
	Chờ điểm neo xuất hiện. Dùng khi vừa ra lệnh mở một modal — nội dung của nó dựng ở frame sau.
	`timeout` tính bằng giây; trả về nil nếu hết giờ.
]]
function UIAnchors.Await(name: string, timeout: number): Instance?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local instance = UIAnchors.Get(name)
		-- `AbsoluteSize` > 0: Instance vừa dựng xong vẫn có cỡ (0,0) trong một frame đầu, mà
		-- spotlight lấy cỡ đó để cắt lỗ — chiếu vào một cái lỗ 0×0 thì màn hình tối đen thui.
		if instance and (not instance:IsA("GuiObject") or (instance :: GuiObject).AbsoluteSize.X > 0) then
			return instance
		end
		RunService.Heartbeat:Wait()
	end
	return nil
end

return UIAnchors
