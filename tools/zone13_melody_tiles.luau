-- Dựng lại sàn MelodyRun của Zone 13 — chạy trong Studio (Edit mode). Idempotent.
--
-- THIẾT KẾ (2026-08-06, theo yêu cầu user): CẢ ZONE 13 LÀ MỘT THANG ĐI LÊN DUY NHẤT.
-- Bản trước cho `Col` lặp vòng 1..8 nên người chơi nghe đúng một đoạn thang lặp 3.4 lần —
-- không ra cảm giác "thấp dần lên cao". Giờ Col = 1..COLS chạy thẳng, không lặp.
--
-- VÌ SAO CHỈ 10 NỐT: mẫu là piano C5 pitch-shift bằng PlaybackSpeed. Thang ngũ cung 10 bậc
-- = 21 nửa cung, với OCTAVE_DOWN=-12 trong MelodyRun.luau cho C4→A5 (speed 0.50–1.68) —
-- đây là biên còn nghe ra tiếng đàn. Thêm bậc nữa là đỉnh thang chói lại đúng thứ vừa sửa.
-- Muốn nhiều nốt hơn thì phải đổi mẫu audio, KHÔNG phải nới thang.
--
-- HỆ QUẢ CỠ Ô: 10 nốt chia đều 500 studs ⇒ mỗi nốt một dải rộng ĐÚNG 50 studs, phủ trọn
-- Platform_13 không thừa mép. 50 cũng là khoảng cách giữa 10 cổng kính của Zone 13
-- (GlassWall1..10 tại x=1508.5 + 50k) ⇒ MỖI CỔNG NẰM TRONG ĐÚNG MỘT NỐT: qua một cổng =
-- lên một bậc. Đổi COLS là hỏng sự trùng khớp này, cân nhắc kỹ.
--
-- NHỊP: 180–250 WS → 3.6–5.0 nốt/giây (bản ô 10.8 cũ: 17–23 — chính là tiếng "dồn dập"
-- user phàn nàn). Người chơi băng hết zone trong ~2.5s ⇒ nghe trọn một câu 10 nốt.
--
-- Ô rộng 50 (dọc đường chạy) × sâu 24 (ngang) — 72/24 = 3 hàng CHẴN nên lưới nằm gọn
-- trong Platform_13, không lòi mép như lưới 7×10.8 cũ.
--
-- ⚠️ CẢ SÀN LÀ MỘT MODEL DUY NHẤT, đừng chia nhỏ ra nhiều patch "cho nhẹ streaming".
-- Mỗi model = một adapter với `currentTile` RIÊNG, mà hộp bao mỗi patch còn đệm thêm 2
-- studs nên ở ranh giới hai adapter cạnh nhau CÙNG nhận bàn chân và thứ tự bắn phụ thuộc
-- thứ tự duyệt instanceList ⇒ nghe ra nốt SAI THỨ TỰ ("đô rê fa mi fa", đo được 2026-08-06).
-- Cả sàn chỉ có 31 part nên gộp một model chẳng tốn gì.

local CS = game:GetService("CollectionService")
local CH = game:GetService("ChangeHistoryService")

local asmr = workspace.Zones.Zone13.ASMR
local plat = workspace.Zones.Zone13.Ground.Platform_13

local COLS = 10 -- số NỐT của cả zone (= số bậc thang, xem giải thích trên)
local ROWS = 3 -- 3 × 24 = 72 = đúng chiều sâu Platform_13
local SIZE_X = 50 -- bề rộng một nốt dọc đường chạy = 500/10, khớp nhịp 10 cổng kính
local SIZE_Z = 24
local TILE_Y = 220.2 -- giữ nguyên cao độ cũ: mặt ô 220.4, khớp GroundLimit
local WS_Y = 220.35

local DIM_S, DIM_V = 0.5514, 0.419608 -- màu ô lúc tắt (giữ y hệt bảng màu cũ)

local x0 = plat.Position.X - plat.Size.X / 2
local z0 = plat.Position.Z - plat.Size.Z / 2
local firstCX = x0 + (plat.Size.X - COLS * SIZE_X) / 2 + SIZE_X / 2
local firstCZ = z0 + SIZE_Z / 2

local rec = CH:TryBeginRecording("Zone13 MelodyRun thang " .. COLS .. " not")

for _, m in asmr:GetChildren() do
	if m:GetAttribute("FloorType") == "MelodyRun" then
		m:Destroy()
	end
end

local model = Instance.new("Model")
model.Name = "Melody_Platform13"
model:SetAttribute("FloorType", "MelodyRun")
-- Atomic bắt buộc: sàn ASMR xa spawn, streaming nhả lẻ từng ô là adapter attach hụt
-- rồi câm vĩnh viễn (xem memory asmr-attach-watchdog).
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

local tiles = Instance.new("Folder")
tiles.Name = "Tiles"
tiles.Parent = model

local made = 0
for gx = 0, COLS - 1 do
	-- Col TĂNG DẦN suốt zone, không mod: MelodyRun.luau đọc ra bậc ngũ cung leo liên tục.
	local col = gx + 1
	-- Hue quét trọn vòng màu theo chiều đi lên ⇒ nhìn cũng thấy được "thấp → cao".
	local hue = gx / COLS
	local cx = firstCX + gx * SIZE_X
	for r = 0, ROWS - 1 do
		local t = Instance.new("Part")
		t.Name = "Note"
		t.Anchored = true
		t.CanCollide = false
		t.CanTouch = false
		t.CanQuery = false
		t.CastShadow = false
		t.Material = Enum.Material.SmoothPlastic
		t.TopSurface = Enum.SurfaceType.Studs
		t.BottomSurface = Enum.SurfaceType.Smooth
		t.Size = Vector3.new(SIZE_X, 0.4, SIZE_Z)
		t.Position = Vector3.new(cx, TILE_Y, firstCZ + r * SIZE_Z)
		t.Color = Color3.fromHSV(hue, DIM_S, DIM_V)
		t:SetAttribute("Col", col)
		t:SetAttribute("Hue", hue)
		t.Parent = tiles
		made += 1
	end
end

local ws = Instance.new("Part")
ws.Name = "WalkSurface"
ws.Anchored = true
ws.CanCollide = false
ws.CanTouch = false
ws.CanQuery = false
ws.CastShadow = false
ws.Transparency = 1
ws.Size = Vector3.new(COLS * SIZE_X, 0.4, plat.Size.Z + 1)
ws.Position = Vector3.new(plat.Position.X, WS_Y, plat.Position.Z)
ws.Parent = model

model.Parent = asmr
CS:AddTag(model, "ASMRFloor")

if rec then
	CH:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end

return ("Zone13 MelodyRun: 1 model, thang %d nốt liên tục, %d ô %dx%d — %.1f–%.1f nốt/giây ở 180–250 WS"):format(
	COLS,
	made,
	SIZE_X,
	SIZE_Z,
	180 / SIZE_X,
	250 / SIZE_X
)
