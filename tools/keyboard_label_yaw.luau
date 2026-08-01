--[[
	keyboard_label_yaw.luau — gán `LabelWorldYaw` cho MỌI bàn phím ASMR trên map.
	Chạy bằng execute_luau (Edit mode). Đặt DRY_RUN = false để áp dụng.

	VÌ SAO CẦN: `KeyboardLabelController` v6.2 xoay chữ theo `rot = yaw(phím) + LabelWorldYaw`,
	quy chiếu về THẾ GIỚI. Hằng số đó phụ thuộc HƯỚNG CHẠY của hành lang, mà map có hai trục:
	  • Zone 1–9   chạy dọc **+Z**  ⇒ LabelWorldYaw = 270
	  • Zone 10–15 chạy dọc **+X**  ⇒ LabelWorldYaw = 180
	Mặc định 180 trong code chỉ đúng cho nửa sau ⇒ chữ Zone 1–9 quay ngang 90°.
	Cả hai số đều chốt bằng THỰC NGHIỆM trong Play (chụp màn hình đối chiếu ở Zone 1 và
	Zone 15), không suy ra từ công thức — xem [[keyboard-labels]].

	⚠️ VÌ SAO KHÔNG TỰ SUY TỪ HÌNH HỌC (đã thử, đều hỏng):
	  • Dây cung Stage{N}Start → Stage{N}Finish: sai với `KB_Transition8To9` — bàn nằm trong
	    hành lang +Z nối từ Zone 8 sang, nhưng dây cung của Zone 9 lại là +X vì zone rẽ ngay
	    sau đó.
	  • Trục NGẮN của WalkSurface: đúng cho Zone 1 (72×20.5) nhưng sai cho Zone 15
	    (KB15_021 84×72, KB15_025 84×12 — hai bàn cùng hành lang mà trục ngắn ngược nhau).
	Nên hướng chạy là DỮ LIỆU, không phải thứ đoán được; ghi thẳng vào attribute cho minh
	bạch, sửa được bằng tay trong Studio, và 0 chi phí runtime.
]]

local DRY_RUN = true

local CollectionService = game:GetService("CollectionService")

local YAW_BY_ZONE_AXIS = { PlusZ = 270, PlusX = 180 }

-- Zone nào chạy trục nào. Bảng tra tay: map đã hoàn thiện, không đổi nữa.
local function yawForZone(n: number): number
	return if n <= 9 then YAW_BY_ZONE_AXIS.PlusZ else YAW_BY_ZONE_AXIS.PlusX
end

local log, changed = {}, 0

for n = 1, 15 do
	local zone = workspace.Zones:FindFirstChild(`Zone{n}`)
	if zone then
		local yaw = yawForZone(n)
		local boards = 0
		for _, m in zone:GetDescendants() do
			if
				m:IsA("Model")
				and CollectionService:HasTag(m, "ASMRFloor")
				and m:GetAttribute("FloorType") == "Keyboard"
			then
				boards += 1
				if m:GetAttribute("LabelWorldYaw") ~= yaw then
					changed += 1
					if not DRY_RUN then
						m:SetAttribute("LabelWorldYaw", yaw)
					end
				end
			end
		end
		if boards > 0 then
			table.insert(log, ("Zone%-3d %2d bàn -> LabelWorldYaw=%d"):format(n, boards, yaw))
		end
	end
end

return ("%s — %d bàn đổi\n%s"):format(DRY_RUN and "DRY RUN" or "ĐÃ ÁP DỤNG", changed, table.concat(log, "\n"))
