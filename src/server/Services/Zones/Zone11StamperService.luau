--!strict
--[[
	Zone11StamperService.luau — máy ép ngang Cyber Metal Horizontal Stamper, Stage 11.

	THAY THẾ script inline `Workspace.Zones.Zone11.Mechanics.Zone11HorizontalStamperScript`
	(2026-08-27).

	Nhịp 3 pha (v4 — 2026-07-26, yêu cầu user "ép từ từ, mở từ từ nhưng nhanh hơn"):
	  1) Telegraph  0.35s — LED chớp + laser chỉ giới (client vẽ)
	  2) Stamp      1.70s — ÉP TỪ TỪ vào giữa, smoothstep p²(3−2p) (mượt đều, không giật)
	  3) Retract    1.15s — MỞ TỪ TỪ nhưng NHANH HƠN ép (1.15 < 1.70), cùng smoothstep
	  + Hold 0.35s giữ kín giữa (2) và (3)

	Kiến trúc: server KHÔNG set Position mỗi frame (trước đây replicate 4 part × 60Hz). Vị trí
	= f(`workspace:GetServerTimeNow()`); `Zone11StamperController` render local, server chỉ
	chạy box-overlap trong pha nguy hiểm. Zero-GC + early-out khi zone trống.

	ÉP SÁT (v6 — 2026-08-07, yêu cầu user): hai HAZARDFACE chạm nhau, không phải hai thân
	crusher. HazardFace lệch 15 khỏi tâm crusher và dày 2 ⇒ mặt trong của nó ở tâm ± 16, tức
	NHÔ 2 STUDS qua mặt trong của thân (tâm ± 14). Vậy điều kiện "chạm" tính theo hazard:
	  (rightZ - 16) - (leftZ + 16) = 0  ⇒  rightZ - leftZ = 32  ⇒  PRESS_HALF_WIDTH = 2.
	v5 để 0 là cho hai THÂN chạm nhau — khi đó hai hazard đã lồng xuyên qua nhau 4 studs.

	GATE TỐC ĐỘ (tính từ HÌNH HỌC, không phải ước lượng): khe chết khi gapHalf ≤ 8.
	  gapHalf(a) = OPEN_HALF_WIDTH - (OPEN_HALF_WIDTH - PRESS_HALF_WIDTH)·a
	  nay (press 2.0): 36 - 34.0a = 8 → a = 0.8235 → p_stamp 0.741 / p_retract 0.259
	  W = (1-p_retract)·RETRACT + (CYCLE - STAMP - HOLD - RETRACT) + p_stamp·STAMP
	  @CYCLE 4.10 → gate 188.1 WS · @CYCLE 4.20 → gate 182.0 WS  ← CHỌN, khớp độ khó bản gốc
	Chỉ CYCLE mới nâng được W mà không phá cảm giác "ép từ từ": kéo dài STAMP hay RETRACT đều
	LÀM GIẢM W (dW/dSTAMP = p_stamp − 1 < 0).

	⚠️ Đổi easing thì PHẢI sửa `closeAlphaAt` ở CẢ hai phía (service này + Zone11StamperController).
	Lệch là chết oan hoặc hụt.

	===== v7 (2026-08-27) — BÙ TRỄ MẠNG + VÀO GIT =====
	Ping thật của game 350–400ms. Ở pha ép, mép crusher đi ~34 studs / 1.7s ≈ 20 studs/s, nên
	195ms trễ = 4 studs lệch. Nghe nhỏ, nhưng khe chết chỉ rộng 8 studs mỗi bên — 4 studs là
	một nửa cửa sổ sống sót. Người chơi lách đúng lúc vẫn chết.
	⇒ Dựng máy ép tại `now - LagComp.Delay(player)`. Xem Shared/Util/LagComp.
	Hệ quả: truy vấn hộp chạy THEO TỪNG NGƯỜI (mỗi người một độ trễ ⇒ một độ mở khác nhau)
	thay vì một truy vấn chung. Đắt hơn, nhưng hành lang hiếm khi có quá vài người.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LagComp = require(ReplicatedStorage.Shared.Util.LagComp)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local Zone11StamperService = {}

local TRACK_CENTER_X = 879.0
local TRACK_CENTER_Z = 3029.0
local TRACK_FLOOR_Y = 212.0
local TRACK_LENGTH = 562.0

local OPEN_HALF_WIDTH = 36.0
-- 2.0 = hai HAZARDFACE chạm nhau khi ép kín (KHÔNG phải hai thân crusher). Đổi số này BẮT
-- BUỘC tính lại CYCLE theo khối công thức GATE ở đầu file, nếu không gate tốc độ sẽ trôi.
local PRESS_HALF_WIDTH = 2.0
local HALF_WALL_Z = 14.0
local CRUSHER_Y = TRACK_FLOOR_Y + 24

local OPEN_LEFT_Z = TRACK_CENTER_Z - OPEN_HALF_WIDTH - HALF_WALL_Z
local PRESS_LEFT_Z = TRACK_CENTER_Z - PRESS_HALF_WIDTH - HALF_WALL_Z
local OPEN_RIGHT_Z = TRACK_CENTER_Z + OPEN_HALF_WIDTH + HALF_WALL_Z
local PRESS_RIGHT_Z = TRACK_CENTER_Z + PRESS_HALF_WIDTH + HALF_WALL_Z

local CYCLE = 4.20 -- xem khối tính GATE ở đầu file trước khi đổi
local T_TELEGRAPH = 0.35
local T_STAMP = 1.70 -- ép TỪ TỪ
local T_HOLD = 0.35
local T_RETRACT = 1.15 -- mở từ từ nhưng NHANH HƠN ép

-- Mốc thời gian tuyệt đối trong 1 chu kỳ.
local TELEGRAPH_AT = CYCLE - (T_TELEGRAPH + T_STAMP + T_HOLD + T_RETRACT)
local STAMP_AT = TELEGRAPH_AT + T_TELEGRAPH
local HOLD_AT = STAMP_AT + T_STAMP
local RETRACT_AT = HOLD_AT + T_HOLD

local KILL_COOLDOWN = 0.5
local RESOLVE_RETRY = 1

-- Hộp bao hành lang phán xử (giữ nguyên số của bản inline).
local GATE_MIN_X, GATE_MAX_X = 580, 1180
local GATE_MIN_Z, GATE_MAX_Z = 2980, 3080
local GATE_MIN_Y, GATE_MAX_Y = 200, 270

local lastKill: { [Player]: number } = {}
local resolved = false

-- ===== Zero-GC scratch =====
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = false
local oneCharacter: { Instance } = { nil :: any }

--[[ alpha 0 = mở hết, 1 = ép kín. ]]
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

local function resolve(): boolean
	local zones = Workspace:FindFirstChild("Zones")
	local zone11 = zones and zones:FindFirstChild("Zone11")
	local mechanics = zone11 and zone11:FindFirstChild("Mechanics")
	local stampersFolder = mechanics and mechanics:FindFirstChild("HorizontalStampers")
	local singleModel = stampersFolder and stampersFolder:FindFirstChild("ContinuousStamper")
	local leftCrusher = singleModel and singleModel:FindFirstChild("LeftCrusher")
	local rightCrusher = singleModel and singleModel:FindFirstChild("RightCrusher")
	if not zone11 or not leftCrusher or not leftCrusher:IsA("BasePart") then
		return false
	end
	if not rightCrusher or not rightCrusher:IsA("BasePart") then
		return false
	end

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

	-- Đưa 2 khối về vị trí mở MỘT lần; từ đây client tự render.
	leftCrusher.Anchored = true
	rightCrusher.Anchored = true
	leftCrusher.Position = Vector3.new(TRACK_CENTER_X, CRUSHER_Y, OPEN_LEFT_Z)
	rightCrusher.Position = Vector3.new(TRACK_CENTER_X, CRUSHER_Y, OPEN_RIGHT_Z)
	return true
end

local function tick()
	if not resolved then
		return
	end

	local now = Workspace:GetServerTimeNow()

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			local p = root.Position
			-- Cổng VỊ TRÍ: chỉ ai đang thực sự trong hành lang mới bị phán xử.
			if
				p.X >= GATE_MIN_X
				and p.X <= GATE_MAX_X
				and p.Z >= GATE_MIN_Z
				and p.Z <= GATE_MAX_Z
				and p.Y >= GATE_MIN_Y
				and p.Y <= GATE_MAX_Y
			then
				-- BÙ TRỄ (v7): độ mở phải lấy tại thời điểm ảnh chụp vị trí người chơi.
				local t = (now - LagComp.Delay(player)) % CYCLE
				-- Early-out: ngoài pha ép thì không có sát thương.
				if t >= STAMP_AT and t < RETRACT_AT + T_RETRACT then
					local alpha = closeAlphaAt(t)
					local leftZ = OPEN_LEFT_Z + (PRESS_LEFT_Z - OPEN_LEFT_Z) * alpha
					local rightZ = OPEN_RIGHT_Z + (PRESS_RIGHT_Z - OPEN_RIGHT_Z) * alpha
					local gapHalf = (rightZ - leftZ) * 0.5 - HALF_WALL_Z
					if gapHalf <= 8 then
						oneCharacter[1] = character :: Instance
						params.FilterDescendantsInstances = oneCharacter
						local boxSize = Vector3.new(TRACK_LENGTH, 30, math.max(2, gapHalf * 2))
						local boxCFrame = CFrame.new(TRACK_CENTER_X, CRUSHER_Y, TRACK_CENTER_Z)
						local parts = Workspace:GetPartBoundsInBox(boxCFrame, boxSize, params)
						if #parts > 0 then
							if now - (lastKill[player] or 0) >= KILL_COOLDOWN then
								lastKill[player] = now
								humanoid.Health = 0
							end
						end
					end
				end
			end
		end
	end
end

function Zone11StamperService.Init() end

function Zone11StamperService.Start()
	task.spawn(function()
		while not resolve() do
			task.wait(RESOLVE_RETRY)
		end
		resolved = true
		RunService.Heartbeat:Connect(tick)
		Log.Boot(`[Zone11StamperService] chu kỳ {CYCLE}s — client render, server phán xử + bù trễ`)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKill[player] = nil
	end)
end

return Zone11StamperService
