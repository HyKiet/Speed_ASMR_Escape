--[[
	ground_walk_surface.luau — chạy trong Studio (Edit mode), KHÔNG phải script của game.

	VIỆC: tắt collision của các tấm slab vô hình (`WalkSurface` / `Collider`) trong 15 zone,
	để người chơi đi thẳng trên mặt Ground thật.

	VÌ SAO (user 2026-08-04): slab nằm LƯNG CHỪNG thân deco — phím bàn phím cao 2.0 stud
	thì mặt slab ở 1.0 — nên vào/ra mỗi sàn ASMR là một bậc 0.4–1.6 stud, đường chạy vấp
	khúc. Bỏ slab đi thì mạch chạy liền một mặt, deco nhô lên quanh chân và lún xuống khi
	giẫm (độ lún do `ASMR/Engine/GroundLimit.luau` quy chiếu lại theo mặt đất).

	KHÔNG ĐỤNG TỚI: Lobby (yêu cầu user), và Zone5 PopIt / Zone7 Jelly — hai đoạn đó bắc
	qua vực, chính sàn ASMR là mặt đường; chúng vốn không có slab nên tự động nằm ngoài.

	MAP KHÔNG NẰM TRONG GIT ⇒ mỗi part bị sửa được đánh dấu attribute `PreGroundCollide`.
	Đặt MODE = "revert" rồi chạy lại là trả nguyên trạng, không cần nhớ gì.
]]

local MODE = "apply" -- "apply" | "revert" | "check"

local CollectionService = game:GetService("CollectionService")

local SLAB_NAMES = { WalkSurface = true, Collider = true }
local ATTR = "PreGroundCollide"

local zones = workspace:FindFirstChild("Zones")
assert(zones, "Không thấy workspace.Zones")

local function zoneOf(inst: Instance): string?
	local node: Instance? = inst
	while node do
		if node.Parent == zones then
			return node.Name
		end
		node = node.Parent
	end
	return nil
end

local perZone: { [string]: number } = {}
local total = 0

if MODE == "revert" then
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(ATTR) ~= nil then
			d.CanCollide = true
			d:SetAttribute(ATTR, nil)
			total += 1
		end
	end
	print(("[GroundWalk] REVERT — bật lại collision cho %d tấm"):format(total))
	return
end

for _, model in CollectionService:GetTagged("ASMRFloor") do
	local zone = zoneOf(model)
	if zone then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and SLAB_NAMES[d.Name] and d.CanCollide then
				if MODE == "apply" then
					d:SetAttribute(ATTR, true)
					d.CanCollide = false
				end
				perZone[zone] = (perZone[zone] or 0) + 1
				total += 1
			end
		end
	end
end

local lines = {}
for zone, n in perZone do
	table.insert(lines, ("%s=%d"):format(zone, n))
end
table.sort(lines)
print(("[GroundWalk] %s — %d tấm | %s"):format(MODE:upper(), total, table.concat(lines, " ")))
