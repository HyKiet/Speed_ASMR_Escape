--!strict
--[[
	SoundIds.luau — MỘT nguồn duy nhất cho các asset âm thanh dùng ở NHIỀU nơi.

	── PHẠM VI: CHỈ ID DÙNG CHUNG ────────────────────────────────────────────────────────
	Đây KHÔNG phải kho chứa mọi ID âm thanh của game. Sàn ASMR mỗi loại có bộ âm riêng và
	chúng nên tiếp tục sống cạnh chính sàn đó — đọc `Butter.luau` mà thấy luôn ID của nó thì
	dễ chỉnh hơn nhiều so với phải nhảy sang một file bảng tra.

	Chỉ những ID mà HAI NƠI TRỞ LÊN cùng dùng mới chuyển về đây. Lý do rất cụ thể: khi cùng
	một con số nằm ở hai file, sửa một chỗ mà quên chỗ kia sẽ tạo ra lỗi âm thanh IM LẶNG —
	không có cảnh báo, không có lỗi, chỉ là hai chỗ trong game phát ra hai tiếng khác nhau
	trong khi lẽ ra phải giống hệt. Loại lỗi đó rất khó truy vì không có gì để bám.

	Đã đo 2026-08-18: đúng 3 ID rơi vào diện này.

	⚠️ Thêm ID mới vào đây thì phải KIỂM ĐỘ DÀI THẬT trước (xem `audio-system`): asset sai
	loại chỉ log đúng một dòng rồi im, nên phải nghe/đo chứ đừng suy từ tên hay chủ sở hữu.
]]

local SoundIds = {
	-- Bàn phím cơ — dùng bởi `ASMR/Floors/Keyboard` (sàn phím Zone 15, 4.650 phím).
	-- (2026-09-06: `Effects/KeyCapperSFXController` đã gỡ cùng plugin KeyCapper, xem README.)
	KEYBOARD_TICK = 9113140795, -- ProSoundEffects Apple Keyboard 5, 0.20s
	KEYBOARD_RELEASE = 9116157307, -- ProSoundEffects Keyboard Typing 34, 0.30s

	-- Cát: `KineticSand` (bản 144 ô) và `KineticSandLive` (bản 5.180 ô, crater+rim) là hai
	-- cách DỰNG khác nhau của CÙNG MỘT loại sàn — tách module có chủ đích (xem ghi chú đầu
	-- `KineticSandLive`), nhưng ÂM THANH thì phải trùng khít, nếu không người chơi đi từ ô
	-- này sang ô kia sẽ nghe hai chất cát khác nhau.
	SAND_DIRT = 9114087861,
	SAND_CRUNCH = { 72043022297629, 139933585379767, 123627945803927, 81253534133158 },
}

return SoundIds
