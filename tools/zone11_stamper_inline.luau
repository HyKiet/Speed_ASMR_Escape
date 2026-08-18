--!strict
--[[
	Zone11HorizontalStamperScript — Cyber Metal Horizontal Stamper (v6)
	Đặt làm con của Workspace.Zones.Zone11.Mechanics (Script chạy trên Server).
	(Bản gốc để version-control; bản chạy nằm trong .rbxlx do map không được Rojo sync.)

	Nhịp 3 pha (v4 — 2026-07-26, yêu cầu user "ép từ từ, mở từ từ nhưng nhanh hơn"):
	  1) Telegraph  0.35s — LED chớp + laser chỉ giới (client vẽ)
	  2) Stamp      1.70s — ÉP TỪ TỪ vào giữa, smoothstep p²(3−2p) (mượt đều, không giật)
	  3) Retract    1.15s — MỞ TỪ TỪ nhưng NHANH HƠN ép (1.15 < 1.70), cùng smoothstep
	  + Hold 0.35s giữ kín giữa (2) và (3)

	Tối ưu: server KHÔNG set Position mỗi frame. Vị trí = f(workspace:GetServerTimeNow());
	client render local, server chỉ chạy box-overlap trong pha nguy hiểm.

	===== v6 (2026-08-07) — ÉP SÁT: HAI HAZARDFACE CHẠM NHAU (yêu cầu user) =====
	"Ép sát" ở đây tính theo HAZARDFACE (tấm đỏ người chơi nhìn thấy), KHÔNG phải thân crusher.
	HazardFace lệch 15 khỏi tâm crusher và dày 2 ⇒ mặt trong của nó ở tâm ± 16, tức NHÔ 2 STUDS
	qua mặt trong của thân (tâm ± 14). Điều kiện chạm:
	  (rightZ − 16) − (leftZ + 16) = 0  ⇒  rightZ − leftZ = 32  ⇒  PRESS_HALF_WIDTH = 2
	  v5 để 0 là cho hai THÂN chạm nhau — khi đó hai hazard đã lồng XUYÊN QUA nhau 4 studs.
	Ở PRESS_HALF_WIDTH = 2: hai thân còn cách 4 studs, và 4 studs đó được hai tấm hazard
	(2 studs mỗi tấm) lấp kín ⇒ nhìn ra là hai mặt đỏ dán sát nhau, không kẽ hở.
	Đo lại trong Studio: khe HAZARD = 0.00 tại Z = 3029, khe THÂN = 4.00.

	BÙ LẠI GATE TỐC ĐỘ — CYCLE 4.10 → 4.20 (user chốt: giữ nguyên độ khó).
	Khe hẹp hơn ⇒ ngưỡng chết (gapHalf <= 8) đạt SỚM hơn trong pha ép, cửa sổ an toàn ngắn đi:
	  gapHalf(α) = OPEN_HALF_WIDTH − (OPEN_HALF_WIDTH − PRESS_HALF_WIDTH)·α
	  gốc (press 3.5): 36 − 32.5α = 8 → α = 0.8615 → p_stamp 0.766 / p_retract 0.234
	  nay (press 2.0): 36 − 34.0α = 8 → α = 0.8235 → p_stamp 0.741 / p_retract 0.259
	  W = (1−p_retract)·RETRACT + (CYCLE − STAMP − HOLD − RETRACT) + p_stamp·STAMP
	  gốc @CYCLE 4.10: gate = 562/W = 182.3 WS
	  nay @CYCLE 4.10: gate = 188.1 WS   ⟵ khe hẹp hơn nên zone tự nhiên KHÓ hơn
	  nay @CYCLE 4.20: gate = 182.0 WS   ⟵ CHỌN cái này, khớp lại độ khó bản gốc
	Chỉ CYCLE mới nâng được W mà không phá cảm giác "ép từ từ": kéo dài STAMP hay RETRACT
	đều LÀM GIẢM W (dW/dSTAMP = p_stamp − 1 < 0). Phần cộng thêm rơi trọn vào pha mở hẳn.

	`gapHalf <= 8` vẫn đo trên MẶT THÂN như mọi bản trước — không đổi ý nghĩa luật chết,
	chỉ đổi hình học. Hazard nhô 2 studs nên hành lang trống thật luôn hẹp hơn gapHalf 2 studs,
	y như từ trước tới nay.

	⚠️ `closeAlphaAt` PHẢI khớp tuyệt đối với bản trong Zone11StamperController (client) —
	server phán xử sát thương bằng chính công thức này, lệch là "chết oan/hụt".
	Client đọc toàn bộ mốc qua attribute nên KHÔNG cần sửa gì theo thay đổi này.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local mechanics = script.Parent
local zone11 = mechanics.Parent
local stampersFolder = mechanics:WaitForChild("HorizontalStampers")

local singleModel = stampersFolder:WaitForChild("ContinuousStamper")
local leftCrusher = singleModel:WaitForChild("LeftCrusher") :: BasePart
local rightCrusher = singleModel:WaitForChild("RightCrusher") :: BasePart

local TRACK_CENTER_X = 879.0
local TRACK_CENTER_Z = 3029.0
local TRACK_FLOOR_Y = 212.0
local TRACK_LENGTH = 562.0

local OPEN_HALF_WIDTH = 36.0
-- 2.0 = hai HAZARDFACE chạm nhau khi ép kín (KHÔNG phải hai thân crusher). Đổi số này phải
-- tính lại CYCLE theo khối công thức ở đầu file, nếu không gate tốc độ của zone sẽ trôi.
local PRESS_HALF_WIDTH = 2.0
local HALF_WALL_Z = 14.0

local CRUSHER_Y = TRACK_FLOOR_Y + 24

local OPEN_LEFT_Z = TRACK_CENTER_Z - OPEN_HALF_WIDTH - HALF_WALL_Z
local PRESS_LEFT_Z = TRACK_CENTER_Z - PRESS_HALF_WIDTH - HALF_WALL_Z
local OPEN_RIGHT_Z = TRACK_CENTER_Z + OPEN_HALF_WIDTH + HALF_WALL_Z
local PRESS_RIGHT_Z = TRACK_CENTER_Z + PRESS_HALF_WIDTH + HALF_WALL_Z

local CYCLE = 4.20 -- xem khối tính gate ở đầu file trước khi đổi
local T_TELEGRAPH = 0.35
local T_STAMP = 1.70 -- ép TỪ TỪ
local T_HOLD = 0.35
local T_RETRACT = 1.15 -- mở từ từ nhưng NHANH HƠN ép

-- Mốc thời gian tuyệt đối trong 1 chu kỳ.
local TELEGRAPH_AT = CYCLE - (T_TELEGRAPH + T_STAMP + T_HOLD + T_RETRACT)
local STAMP_AT = TELEGRAPH_AT + T_TELEGRAPH
local HOLD_AT = STAMP_AT + T_STAMP
local RETRACT_AT = HOLD_AT + T_HOLD

-- Hợp đồng chia sẻ với Zone11StamperController (client).
zone11:SetAttribute("StampCycle", CYCLE)
zone11:SetAttribute("StampTelegraphAt", TELEGRAPH_AT)
zone11:SetAttribute("StampStampAt", STAMP_AT)
zone11:SetAttribute("StampHoldAt", HOLD_AT)
zone11:SetAttribute("StampRetractAt", RETRACT_AT)
zone11:SetAttribute("StampOpenLeftZ", OPEN_LEFT_Z)
zone11:SetAttribute("StampPressLeftZ", PRESS_LEFT_Z)
zone11:SetAttribute("StampOpenRightZ", OPEN_RIGHT_Z)
zone11:SetAttribute("StampPressRightZ", PRESS_RIGHT_Z)
zone11:SetAttribute("StampCenterX", TRACK_CENTER_X)
zone11:SetAttribute("StampCenterZ", TRACK_CENTER_Z)
zone11:SetAttribute("StampY", CRUSHER_Y)
zone11:SetAttribute("StampTrackLength", TRACK_LENGTH)

-- Đưa 2 khối về vị trí mở 1 lần; từ đây client tự render.
leftCrusher.Anchored = true
rightCrusher.Anchored = true
leftCrusher.Position = Vector3.new(TRACK_CENTER_X, CRUSHER_Y, OPEN_LEFT_Z)
rightCrusher.Position = Vector3.new(TRACK_CENTER_X, CRUSHER_Y, OPEN_RIGHT_Z)

--[[ alpha 0 = mở hết, 1 = ép kín (hai khối chạm nhau). ]]
local function closeAlphaAt(t: number): number
	if t < TELEGRAPH_AT then
		return 0
	elseif t < STAMP_AT then
		return 0 -- telegraph: chưa di chuyển, chỉ cảnh báo
	elseif t < HOLD_AT then
		local p = (t - STAMP_AT) / T_STAMP
		return p * p * (3 - 2 * p) -- smoothstep: khởi/dừng êm, giữa đều → "ép từ từ"
	elseif t < RETRACT_AT then
		return 1
	else
		local p = (t - RETRACT_AT) / T_RETRACT
		local s = p * p * (3 - 2 * p)
		return 1 - s -- mở cùng dạng smoothstep, chỉ ngắn hơn nên NHANH hơn
	end
end

local lastKill: { [Player]: number } = {}
local KILL_COOLDOWN = 0.5

-- ===== Zero-GC scratch =====
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = false
local charBuffer: { Instance } = {}

RunService.Heartbeat:Connect(function()
	local t = Workspace:GetServerTimeNow() % CYCLE
	-- Early-out: ngoài pha ép thì không có sát thương, thoát ngay.
	if t < STAMP_AT or t >= RETRACT_AT + T_RETRACT then return end

	local alpha = closeAlphaAt(t)
	local leftZ = OPEN_LEFT_Z + (PRESS_LEFT_Z - OPEN_LEFT_Z) * alpha
	local rightZ = OPEN_RIGHT_Z + (PRESS_RIGHT_Z - OPEN_RIGHT_Z) * alpha
	local gapHalf = (rightZ - leftZ) * 0.5 - HALF_WALL_Z
	if gapHalf > 8 then return end

	table.clear(charBuffer)
	local n = 0
	for _, plr in Players:GetPlayers() do
		local c = plr.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if h and h.Health > 0 and r and r:IsA("BasePart") then
			local p = r.Position
			if p.X >= 580 and p.X <= 1180 and p.Z >= 2980 and p.Z <= 3080 and p.Y >= 200 and p.Y <= 270 then
				n += 1
				charBuffer[n] = c
			end
		end
	end
	if n == 0 then return end -- SLEEP: zone trống

	params.FilterDescendantsInstances = charBuffer
	local boxSize = Vector3.new(TRACK_LENGTH, 30, math.max(2, gapHalf * 2))
	local boxCFrame = CFrame.new(TRACK_CENTER_X, CRUSHER_Y, TRACK_CENTER_Z)

	for _, part in Workspace:GetPartBoundsInBox(boxCFrame, boxSize, params) do
		local char = part:FindFirstAncestorOfClass("Model")
		local plr = char and Players:GetPlayerFromCharacter(char)
		local h = char and char:FindFirstChildOfClass("Humanoid")
		if plr and h and h.Health > 0 then
			local now = os.clock()
			if now - (lastKill[plr] or 0) >= KILL_COOLDOWN then
				lastKill[plr] = now
				h.Health = 0
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	lastKill[plr] = nil
end)
