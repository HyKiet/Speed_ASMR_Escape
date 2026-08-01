--[[
	zone15_vibes.luau — chia sàn phím Zone 15 thành 3 vibe Fire / Water / Lightning,
	đổi màu phím theo vibe và gắn attribute cho engine đọc lúc runtime.
	Chạy bằng execute_luau (Edit mode). Đặt DRY_RUN = false để áp dụng.

	CÁCH CHIA: theo trục chạy +X, cắt tại hai KHE THẬT giữa các cụm bàn (3843→4044 và
	5388→5480) chứ không cắt đều số bàn — cắt giữa một cụm liền mạch thì vibe đổi đột ngột
	giữa hành lang. Kết quả: 1152 / 1344 / 1175 stud, cân nhau.

	GIỮ NHỊP MÀU: theme `Zone15` dùng 7 màu pastel rải theo một hoa văn có sẵn. Tool KHÔNG
	tô đè một màu phẳng mà ánh xạ 7 màu gốc sang 7 sắc độ của vibe, nên hoa văn giữ nguyên,
	chỉ đổi tông. Slot (1..7) được ghi vào attribute `KeySlot` của từng phím ngay lần chạy
	đầu ⇒ chạy lại lần sau đọc `KeySlot` thay vì dò màu gốc (đã bị ghi đè), tool tái chạy
	được vô hạn để tinh chỉnh bảng màu.

	Bàn `Plain` (KB_Transition14To15) chỉ có một màu xám nên không dò được hoa văn — rải slot
	theo lưới hàng+cột để nó cũng có nhịp như các bàn khác.
]]

local DRY_RUN = true

local FIRE_MAX, WATER_MAX = 3900, 5450

-- 7 màu gốc của theme Zone15, theo thứ tự slot. Slot 3 và 6 là hai màu áp đảo (1070/1003
-- phím) nên chúng nhận tông NỀN của vibe; các slot hiếm nhận tông nhấn.
local ORIGIN = {
	Color3.new(1, 1, 1), -- 1 trắng (245)
	Color3.new(0.745098, 0.647059, 1), -- 2 lavender (433)
	Color3.new(0.588235, 0.921569, 0.784314), -- 3 mint (1070) NỀN
	Color3.new(1, 0.541176, 0.658824), -- 4 hồng (507)
	Color3.new(0.549020, 0.803922, 1), -- 5 xanh trời (709)
	Color3.new(1, 0.925490, 0.549020), -- 6 vàng bơ (1003) NỀN 2
	Color3.new(1, 0.745098, 0.470588), -- 7 cam đào (729)
}

local PALETTE = {
	Fire = {
		Color3.fromRGB(255, 235, 194),
		Color3.fromRGB(242, 92, 34),
		Color3.fromRGB(217, 58, 28),
		Color3.fromRGB(255, 200, 92),
		Color3.fromRGB(176, 35, 16),
		Color3.fromRGB(255, 122, 41),
		Color3.fromRGB(255, 168, 61),
	},
	-- ⚠️ Vòng 1 dùng tông xanh nhạt kiểu pastel → bàn phím CHÌM HẲN vào mặt biển (nền map
	-- Zone 15 là biển xanh nhạt phủ kín khung hình). Phải đẩy về xanh đại dương sâu, chỉ
	-- để vài phím teal sáng làm điểm nhấn.
	Water = {
		Color3.fromRGB(200, 240, 255),
		Color3.fromRGB(22, 110, 180),
		Color3.fromRGB(13, 74, 140),
		Color3.fromRGB(40, 190, 200),
		Color3.fromRGB(8, 48, 102),
		Color3.fromRGB(26, 140, 196),
		Color3.fromRGB(60, 205, 215),
	},
	-- Tông theo ảnh tham chiếu của user: bàn phím navy-tím tối, chữ tím nhạt nổi lên trên.
	Lightning = {
		Color3.fromRGB(217, 203, 255),
		Color3.fromRGB(74, 50, 147),
		Color3.fromRGB(59, 42, 122),
		Color3.fromRGB(169, 140, 245),
		Color3.fromRGB(36, 26, 82),
		Color3.fromRGB(91, 63, 176),
		Color3.fromRGB(123, 90, 214),
	},
}

local function nearestSlot(c: Color3): number
	local best, bestD = 1, math.huge
	for i, o in ORIGIN do
		local d = (c.R - o.R) ^ 2 + (c.G - o.G) ^ 2 + (c.B - o.B) ^ 2
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

local counts = { Fire = { boards = 0, keys = 0 }, Water = { boards = 0, keys = 0 }, Lightning = { boards = 0, keys = 0 } }

for _, model in workspace.Zones.Zone15.ASMR:GetChildren() do
	local walk = model:IsA("Model") and model:FindFirstChild("WalkSurface")
	if walk and walk:IsA("BasePart") then
		local x = walk.Position.X
		local vibe = if x < FIRE_MAX then "Fire" elseif x < WATER_MAX then "Water" else "Lightning"
		local palette = PALETTE[vibe]
		counts[vibe].boards += 1

		if not DRY_RUN then
			model:SetAttribute("Vibe", vibe)
		end

		local container = model:FindFirstChild("Clicky Keyboard Asmr")
		if container then
			for _, themes in container:GetChildren() do
				for _, theme in themes:GetChildren() do
					-- theme một-màu (Plain) không mang hoa văn ⇒ rải slot theo lưới
					local distinct = {}
					for _, k in theme:GetChildren() do
						if k:IsA("MeshPart") then
							distinct[tostring(k.Color)] = true
						end
					end
					local n = 0
					for _ in distinct do
						n += 1
					end
					local flat = n <= 1

					for _, key in theme:GetChildren() do
						if key:IsA("MeshPart") then
							local slot = tonumber(key:GetAttribute("KeySlot"))
							if not slot then
								if flat then
									slot = (math.floor(key.Position.X / 3) + math.floor(key.Position.Z / 3) * 3) % 7 + 1
								else
									slot = nearestSlot(key.Color)
								end
							end
							counts[vibe].keys += 1
							if not DRY_RUN then
								key:SetAttribute("KeySlot", slot)
								key.Color = palette[slot]
							end
						end
					end
				end
			end
		end
	end
end

local out = {}
for _, name in { "Fire", "Water", "Lightning" } do
	table.insert(out, ("%-10s %2d bàn, %4d phím"):format(name, counts[name].boards, counts[name].keys))
end
return ("%s\n%s"):format(DRY_RUN and "== DRY RUN ==" or "== ĐÃ ÁP DỤNG ==", table.concat(out, "\n"))
