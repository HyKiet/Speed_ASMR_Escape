--!strict
--[[
	══════════════════════════════════════════════════════════════════════════════════════════
	  Registry — DANH SÁCH MODAL, KHAI MỘT LẦN DUY NHẤT
	══════════════════════════════════════════════════════════════════════════════════════════

	Mỗi id ở đây tương ứng với một bộ state theo ĐÚNG quy ước đặt tên:

	    State.<id>ModalVisible          -- người chơi đang mở nó không (dùng cho Toggle + blur)
	    State.<id>ModalMounted          -- có nằm trên màn hình không (giữ thêm 0.22s cho hoạt ảnh)
	    State.<id>ModalAnimationGoal    -- 0 = đóng, 1 = mở
	    State.<id>ModalAnimation        -- Tween của Goal, nhịp `Tokens.MODAL_TWEEN`
	    State.<id>CloseHovered          -- đang rê chuột lên nút X

	Ba nơi cùng đọc bảng này nên không có cách nào lệch nhau:
	    • `State`        dựng 4 giá trị trên cho từng id
	    • `Manager`      sinh Open/Close/Toggle + `hideAll` + phát hiện "còn modal nào đang mở"
	    • `ModalShell`   tra state từ `Id` để nối hoạt ảnh và nút X

	── THÊM MODAL MỚI ────────────────────────────────────────────────────────────────────────
	    1. Thêm một dòng vào `Registry.IDS`
	    2. Thêm một dòng `declareModal()` trong `State.luau`
	    3. Gọi `defineModal(id)` trong `Manager.luau`
	    4. Viết file modal, dựng vỏ bằng `ModalShell.Build({ Id = <id>, … })`
	Trước đợt gom này thì bước 1–3 là sửa tay 4 chỗ rời nhau trong `Manager` (hideAll, bảng
	MODAL_VISIBLE_KEYS, Open, Close, Toggle) — sót một chỗ là modal mới không tự đóng khi mở
	modal khác, hoặc blur nền kẹt lại vĩnh viễn.
]]

local Registry = {}

--[[
	⚠️ "revive" CÓ trong bảng này dù `ReviveModal` không dùng `ModalShell` (nó là một nút nổi
	sát mép trên, không phải tấm panel có header). Nó vẫn cần nằm đây vì nó dùng chung cơ chế
	loại trừ: mở modal khác phải tắt nút Revive, và ngược lại.
]]
Registry.IDS = {
	"rebirth",
	"cosmetic",
	"teleport",
	"shop",
	"revive",
	"code",
	"daily",
	"roulette",
	"groupChest",
	"starterPack",
	"settings",
}

return Registry
