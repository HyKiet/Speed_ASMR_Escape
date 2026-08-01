--!strict
--[[
	KeyboardLabelController v6 — DÁN CHỮ TRỌN TỪNG BÀN (per-board, all-or-nothing).

	VÌ SAO BỎ v5 (pool + lọc nón camera): nhãn được cấp phát theo hướng NHÌN, nên lia
	camera tới đâu chữ mới hiện tới đó — phím ngay cạnh mà lệch khỏi nón thì trống trơn.
	Người chơi thấy chữ "chạy theo" camera = lỗi thị giác.

	v6 đảo ngược nguyên tắc: đơn vị cấp phát là **BÀN PHÍM**, không phải từng phím.
	  • Mỗi 0.5s xếp các bàn theo khoảng cách tới NGƯỜI CHƠI (không dính camera), chọn
	    các bàn gần nhất trong ngân sách MAX_LABELS → bàn nào được chọn thì dán chữ
	    cho ĐỦ 100% phím của bàn đó. Không có phím nào trong bàn bị bỏ trống.
	  • Xoay camera 360° = KHÔNG có gì thay đổi (0 chi phí, 0 pop-in). Chữ chỉ xuất hiện
	    khi một bàn MỚI lọt vào tập gần nhất — mà lúc đó nó còn cách ~200 studs, ngoài
	    tầm nhìn thực tế → người chơi không bao giờ thấy nhãn bật lên.
	  • Tạo instance rải đều BUILD_PER_FRAME/frame → vào bàn mới không giật.
	  • SurfaceGui.MaxDistance để engine tự cull nhãn xa (nhãn vẫn tồn tại nhưng không vẽ).

	v6.2 (2026-07-28) — hướng chữ quy chiếu THẾ GIỚI, không còn cộng hằng số cho mọi bàn.
	  Xem khối bình luận trong `planBoard` — bug "chữ Zone 15 sai chiều khi chạy".

	v6.1 (2026-07-27) — Zone 15:
	  • Phím Zone 15 tên "K" (bản cũ chỉ nhận tên chứa "Key") ⇒ lọc theo LỚP `MeshPart`
	    đúng như engine `ASMR/Floors/Keyboard.luau`, không lọc theo tên nữa. Trong folder
	    theme chỉ có phím nên lọc lớp là đủ và không bao giờ hụt bàn mới.
	  • POOL instance: bàn bị bỏ khỏi tập gần nhất thì SurfaceGui được TRẢ VỀ KHO chứ không
	    Destroy — chạy dọc hành lang phím là chuỗi swap bàn liên tục, tạo/huỷ 168 GUI mỗi
	    lần swap chính là thứ gây khựng (churn + GC), trong khi số GUI sống luôn ≤ MAX_LABELS.

	Giữ từ các bản trước:
	  • SurfaceGui per-key + Adornee vào chính phím (canvas-per-board v2/v3 đã bị loại vì
	    nhìn phối cảnh sai). Hướng chữ do v6.2 quy chiếu về thế giới, xem `planBoard`.
	  • Kí tự suy từ CHỈ SỐ hàng/cột trong không gian bàn, pitch = KHOẢNG CÁCH THẬT giữa
	    phím (KHÔNG phải key.Size — phím bound 5.5 mà pitch 5 sẽ lệch dồn, trùng kí tự).
	  • Chỉ kí tự CHỮ, không có hàng số.
	  • Root = ScreenGui ResetOnSpawn=false (PlayerGui xoá mọi child khi respawn).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FLOOR_TAG = "ASMRFloor"
local KEY_CONTAINER = "Clicky Keyboard Asmr"

-- Ngân sách nhãn tồn tại cùng lúc. Đây là KNOB DUY NHẤT để đổi tầm phủ ↔ chi phí:
-- mỗi nhãn = 1 SurfaceGui. Bàn hiện tại 112–126 phím ⇒ 800 ≈ 6 bàn liền kề.
local MAX_LABELS = 800
local BOARD_RANGE = 300 -- bàn xa hơn mức này không xét
local BOARD_RANGE_SQ = BOARD_RANGE * BOARD_RANGE
local GUI_MAX_DIST = 260 -- engine tắt render ngoài tầm này
local BUILD_PER_FRAME = 45
local REFRESH_INTERVAL = 0.5
local PPS = 24

local ROWS = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }

local KeyboardLabelController = {}
local player = Players.LocalPlayer

--=====================================================================================
-- ROOT
--=====================================================================================

local guiRoot: ScreenGui? = nil

local function makeRoot(): ScreenGui
	local root = Instance.new("ScreenGui")
	root.Name = "KeyboardLabels"
	root.ResetOnSpawn = false
	root.Parent = player:WaitForChild("PlayerGui")
	guiRoot = root
	return root
end

--=====================================================================================
-- KẾ HOẠCH KÍ TỰ CHO MỘT BÀN (tính 1 lần, cache theo model)
--=====================================================================================

-- Màu chữ theo VIBE (2026-07-28). Phím vibe Zone 15 tối hơn hẳn pastel cũ nên chữ navy
-- `TEXT_DEFAULT` chìm mất. Dùng chữ sáng + viền tối cùng tông; viền lấy `TextStrokeColor3`
-- (thuộc tính có sẵn của TextLabel) chứ KHÔNG thêm UIStroke — 800 nhãn là 800 instance thừa.
local TEXT_DEFAULT = Color3.fromRGB(38, 42, 60)
local VIBE_TEXT: { [string]: { fill: Color3, stroke: Color3 } } = {
	Fire = { fill = Color3.fromRGB(255, 244, 225), stroke = Color3.fromRGB(96, 18, 6) },
	Water = { fill = Color3.fromRGB(235, 250, 255), stroke = Color3.fromRGB(8, 52, 96) },
	Lightning = { fill = Color3.fromRGB(226, 214, 255), stroke = Color3.fromRGB(24, 14, 58) },
}

type KeyPlan = { part: BasePart, char: string, rot: number, fill: Color3, stroke: Color3? }

local planCache: { [Instance]: { KeyPlan } } = setmetatable({}, { __mode = "k" }) :: any

local function planBoard(model: Instance, walk: BasePart): { KeyPlan }?
	local container = model:FindFirstChild(KEY_CONTAINER)
	if not container then
		return nil
	end
	local inv = walk.CFrame:Inverse()
	local raw = {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local setX, setZ = {}, {}
	local nx, nz = 0, 0

	for _, themes in container:GetChildren() do
		for _, theme in themes:GetChildren() do
			for _, key in theme:GetChildren() do
				-- lọc theo LỚP, KHÔNG theo tên: Zone 15 đặt tên phím là "K", các bàn cũ là
				-- "ThockyKey" — engine ASMR cũng chỉ nhận MeshPart nên hai bên luôn khớp nhau
				if key:IsA("MeshPart") then
					local o = inv * key.Position
					table.insert(raw, { part = key, ox = o.X, oz = o.Z })
					minX, maxX = math.min(minX, o.X), math.max(maxX, o.X)
					minZ, maxZ = math.min(minZ, o.Z), math.max(maxZ, o.Z)
					local kx, kz = math.round(o.X * 10), math.round(o.Z * 10)
					if not setX[kx] then
						setX[kx] = true
						nx += 1
					end
					if not setZ[kz] then
						setZ[kz] = true
						nz += 1
					end
				end
			end
		end
	end
	if #raw == 0 then
		return nil
	end

	local pitchX = if nx > 1 then (maxX - minX) / (nx - 1) else 1
	local pitchZ = if nz > 1 then (maxZ - minZ) / (nz - 1) else 1

	-- HƯỚNG CHỮ — v6.2 (2026-07-28), sửa bug "chữ Zone 15 không đúng chiều nhìn khi chạy":
	--
	-- SurfaceGui Face=Top neo vào chính phím ⇒ đỉnh chữ nằm về phía -Z CỦA PHÍM, tức là
	-- hướng chữ đi theo góc xoay RIÊNG của từng bàn. Bản cũ cộng thêm một hằng số
	-- `LabelYaw` (=90) cho mọi bàn, nên chỉ những bàn tình cờ có yaw 0 mới đọc xuôi; các
	-- bàn lát nghiêng/xoay của Zone 15 (yaw -90, 80, …) thì chữ nằm ngang hoặc ngược đầu —
	-- đúng như ảnh chụp: cùng một khung hình có chữ xuôi lẫn chữ quay 90°.
	--
	-- Sửa: quy chiếu về THẾ GIỚI — xoay bù đúng bằng yaw của phím rồi cộng một hằng số
	-- chung, nên mọi bàn dù lát nghiêng kiểu gì chữ cũng cùng trỏ về một hướng.
	--   rot = yaw(phím) + LabelWorldYaw
	-- Hằng số 180 chốt bằng thực nghiệm trong Play (chụp màn hình 3 mốc 90/0/180): 180 cho
	-- ra QWERTY đọc xuôi từ sau lưng nhân vật khi chạy dọc +X.
	--
	-- ĐỔI TÊN attribute: bản cũ dùng `LabelYaw` với ý nghĩa "xoay thêm bấy nhiêu độ" và các
	-- model Zone 15 đang mang giá trị 90 của hệ cũ. Đọc lại tên đó thì giá trị cũ ghi đè
	-- mặc định mới ⇒ dùng tên mới `LabelWorldYaw`, `LabelYaw` cũ coi như phế.
	local labelYaw = tonumber(model:GetAttribute("LabelWorldYaw")) or 180
	local vibe = VIBE_TEXT[tostring(model:GetAttribute("Vibe"))]
	local fill = vibe and vibe.fill or TEXT_DEFAULT
	local stroke = vibe and vibe.stroke

	local plan: { KeyPlan } = {}
	for _, r in raw do
		local row = math.round((r.oz - minZ) / pitchZ)
		local col = math.round((r.ox - minX) / pitchX)
		local rowStr = ROWS[(row % #ROWS) + 1]
		local ci = (col % #rowStr) + 1
		-- yaw đọc từ CHÍNH phím (không từ WalkSurface): phím lát lệch so với bàn vẫn đúng
		local _, keyYaw = r.part.CFrame:ToOrientation()
		local rot = (math.deg(keyYaw) + labelYaw) % 360
		table.insert(plan, { part = r.part, char = string.sub(rowStr, ci, ci), rot = rot, fill = fill, stroke = stroke })
	end
	return plan
end

--=====================================================================================
-- TẠO / HUỶ NHÃN
--=====================================================================================

-- KHO GUI RẢNH: bàn rời tập gần nhất thì nhãn về đây (Adornee=nil ⇒ engine không vẽ),
-- bàn mới lấy ra dùng lại. Số instance sống bám trần MAX_LABELS và ổn định sau vài giây
-- chạy, thay vì tạo/huỷ vài trăm cái mỗi lần đổi bàn.
local free: { SurfaceGui } = {}

local function applyStyle(text: TextLabel, char: string, rot: number, fill: Color3, stroke: Color3?)
	text.Text = char
	text.Rotation = rot
	text.TextColor3 = fill
	-- Nhãn lấy từ KHO có thể vừa phục vụ một bàn vibe khác ⇒ luôn set cả hai chiều,
	-- không được chỉ set khi có stroke (chữ vibe sẽ dính viền sang bàn thường).
	text.TextStrokeColor3 = stroke or Color3.new()
	text.TextStrokeTransparency = if stroke then 0 else 1
end

local function makeLabel(key: BasePart, kp: KeyPlan, root: ScreenGui): SurfaceGui
	local gui = table.remove(free)
	if gui then
		local text = gui:FindFirstChildWhichIsA("TextLabel")
		if text then
			applyStyle(text, kp.char, kp.rot, kp.fill, kp.stroke)
		end
		gui.Adornee = key
		return gui
	end

	gui = Instance.new("SurfaceGui")
	gui.Name = "KeyLabel"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.MaxDistance = GUI_MAX_DIST
	gui.Adornee = key
	gui.Parent = root

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.86, 0.86)
	text.Position = UDim2.fromScale(0.07, 0.07)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	applyStyle(text, kp.char, kp.rot, kp.fill, kp.stroke)
	text.Parent = gui

	return gui
end

local function recycle(gui: SurfaceGui)
	gui.Adornee = nil
	if #free < MAX_LABELS then
		table.insert(free, gui)
	else
		gui:Destroy()
	end
end

type Entry = { plan: { KeyPlan }, index: number, guis: { SurfaceGui } }

local labeled: { [Instance]: Entry } = {} -- bàn đã dán xong
local pending: { [Instance]: Entry } = {} -- bàn đang dán dở
local buildOrder: { Instance } = {}

local function dropBoard(model: Instance, entry: Entry)
	for _, g in entry.guis do
		recycle(g)
	end
	labeled[model] = nil
	pending[model] = nil
end

local function dropAll()
	for model, entry in labeled do
		dropBoard(model, entry)
	end
	for model, entry in pending do
		dropBoard(model, entry)
	end
	table.clear(buildOrder)
	-- dropAll chỉ xảy ra khi root chết (respawn/Stop) ⇒ mọi GUI trong kho đang treo dưới
	-- root cũ đã lìa cây, dùng lại là nhãn vô hình vĩnh viễn. Vứt kho, dựng lại từ đầu.
	for _, g in free do
		g:Destroy()
	end
	table.clear(free)
end

--=====================================================================================
-- CHỌN TẬP BÀN (theo khoảng cách tới NGƯỜI CHƠI — không dính camera)
--=====================================================================================

local function refresh()
	local root = guiRoot
	if not root or root.Parent == nil then
		dropAll()
		makeRoot()
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end
	local pos = hrp.Position

	local cands = {}
	for _, model in CollectionService:GetTagged(FLOOR_TAG) do
		if model:GetAttribute("FloorType") == "Keyboard" and model:IsDescendantOf(workspace) then
			local walk = model:FindFirstChild("WalkSurface")
			if walk and walk:IsA("BasePart") then
				local dx, dz = walk.Position.X - pos.X, walk.Position.Z - pos.Z
				local d2 = dx * dx + dz * dz
				if d2 <= BOARD_RANGE_SQ then
					table.insert(cands, { model = model, walk = walk, d2 = d2 })
				end
			end
		end
	end
	table.sort(cands, function(a, b)
		return a.d2 < b.d2
	end)

	-- gần nhất trước, dừng ngay khi hết ngân sách (bàn luôn được dán TRỌN VẸN)
	local keep: { [Instance]: { KeyPlan } } = {}
	local budget = MAX_LABELS
	for i, c in cands do
		local plan = planCache[c.model]
		if not plan then
			plan = planBoard(c.model, c.walk)
			if plan then
				planCache[c.model] = plan
			end
		end
		if plan then
			-- bàn gần nhất luôn được dán dù có vượt ngân sách
			if #plan <= budget or i == 1 then
				budget -= #plan
				keep[c.model] = plan
			else
				break
			end
		end
	end

	for model, entry in labeled do
		if not keep[model] or not model:IsDescendantOf(workspace) then
			dropBoard(model, entry)
		end
	end
	for model, entry in pending do
		if not keep[model] or not model:IsDescendantOf(workspace) then
			dropBoard(model, entry)
		end
	end

	for model, plan in keep do
		if not labeled[model] and not pending[model] then
			pending[model] = { plan = plan, index = 1, guis = {} }
			table.insert(buildOrder, model)
		end
	end
end

--=====================================================================================
-- BƠM HÀNG ĐỢI (rải việc tạo instance để không giật khi vào bàn mới)
--=====================================================================================

local function pump()
	if #buildOrder == 0 then
		return
	end
	local root = guiRoot
	if not root or root.Parent == nil then
		return
	end
	local budget = BUILD_PER_FRAME
	while budget > 0 and #buildOrder > 0 do
		local model = buildOrder[1]
		local entry = pending[model]
		if not entry then
			table.remove(buildOrder, 1)
			continue
		end
		local plan = entry.plan
		while budget > 0 and entry.index <= #plan do
			local kp = plan[entry.index]
			entry.index += 1
			budget -= 1
			if kp.part.Parent then
				table.insert(entry.guis, makeLabel(kp.part, kp, root))
			end
		end
		if entry.index > #plan then
			labeled[model] = entry
			pending[model] = nil
			table.remove(buildOrder, 1)
		end
	end
end

--=====================================================================================

local connection: RBXScriptConnection? = nil
local accum = REFRESH_INTERVAL

local function step(dt: number)
	accum += dt
	if accum >= REFRESH_INTERVAL then
		accum = 0
		refresh()
	end
	pump()
end

function KeyboardLabelController.Init() end

function KeyboardLabelController.Start()
	makeRoot()
	connection = RunService.Heartbeat:Connect(step)
end

function KeyboardLabelController.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	dropAll()
	if guiRoot then
		guiRoot:Destroy()
		guiRoot = nil
	end
end

return KeyboardLabelController
