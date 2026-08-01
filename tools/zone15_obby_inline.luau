-- BẢN THAM KHẢO (version-controlled) của Workspace.Zone15.Mechanics.Zone15ObbyScript (v2 geyser)
-- Script thật sống inline trong Workspace (KHÔNG Rojo sync) — được ghi qua MCP execute_luau.
-- LƯU Ý: script live có ERUPT_HEIGHT = 122 (đảo dâng tới Y 250).
--
-- Geometry v5 (Ground.Platforms): P0_RunUp X 3187-3220 -> 6 ĐẢO TRỤ 34x34 SO LE dâng từ
-- lava (X 3294/3368/3442/3516/3590/3664, Z xen kẽ 3004/3054, top 226->256 +6/bậc;
-- dx 74 + dz 50 = D chéo 89.4 = quãng bay WS 234 nhảy lên +6 — đảo 34 nên nhảy chỗ nào
-- cũng đáp). KHÔNG có ramp: finale = lao khỏi I6 (top 256) BAY XUYÊN vạch đích trên không
-- rồi đáp/bật tường World2Gate xuống cầu. Mechanics.Rings: 4 vòng tại đỉnh cung.
-- Lava KillFloor Y=140. Stage15Finish X 3700 = MÀN neon Y 220-270 (size 14x50x72);
-- World2Gate nâng cao Y 218-290 làm tường hậu chặn bay lố.
-- Geyser (trong script live): interval 0.5-0.9s, cột 10x130, 30% nhắm player.

--!strict
--[[
	Zone15ObbyScript.luau — Stage 15: Momentum Jump Obby
	Obby nhảy đà: 3 gap leo thang 85/95/102 studs — nhảy từ mép vàng ở WalkSpeed cao
	(234 bay ~119 studs) mới qua; chậm/nhảy sớm -> rơi biển lava (KillFloor Y=140).
	Script này: (1) lava kill, (2) vòng neon giữa gap xoay + lơ lửng + pulse,
	(3) bay XUYÊN vòng -> flash trắng + nổ particle + tăng nhịp (juice),
	(4) viền platform "thở" màu theo sóng dọc X.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local zone = script.Parent.Parent
local mech = script.Parent
local ground = zone:WaitForChild("Ground")
local killFloor = mech:WaitForChild("KillFloor") :: BasePart
local ringsFolder = mech:WaitForChild("Rings")
local plats = ground:WaitForChild("Platforms")

local function kill(hit: BasePart)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and Players:GetPlayerFromCharacter(character) then
		humanoid.Health = 0
	end
end
killFloor.Touched:Connect(kill)

-- ============ VÒNG NEON: xoay + bob + pulse + phát hiện bay xuyên ============
type RingInfo = {
	model: Model,
	bars: { BasePart },
	baseColor: Color3,
	centerX: number,
	baseY: number,
	flashUntil: number,
	lastPass: { [Player]: number },
}
local rings: { RingInfo } = {}
for _, m in ipairs(ringsFolder:GetChildren()) do
	if m:IsA("Model") then
		local bars = {}
		for _, b in ipairs(m:GetChildren()) do
			if b:IsA("BasePart") then table.insert(bars, b) end
		end
		table.insert(rings, {
			model = m,
			bars = bars,
			baseColor = bars[1].Color,
			centerX = m:GetAttribute("CenterX") :: number,
			baseY = m:GetAttribute("BaseY") :: number,
			flashUntil = 0,
			lastPass = {},
		})
	end
end

local WHITE = Color3.fromRGB(255, 255, 255)
local Z_CENTER = 3029

local function ringBurst(ring: RingInfo)
	local top = ring.model:FindFirstChild("Top") :: BasePart?
	if not top then return end
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(ring.baseColor, WHITE)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(15, 35)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Rate = 0
	e.Parent = top
	e:Emit(36)
	game:GetService("Debris"):AddItem(e, 1.2)
end

-- ============ VIỀN PLATFORM "THỞ" ============
local trims: { BasePart } = {}
for _, p in ipairs(plats:GetChildren()) do
	if p:IsA("BasePart") and p.Name:match("_Trim") then
		table.insert(trims, p)
	end
end

local clock0 = os.clock()
RunService.Heartbeat:Connect(function()
	local t = os.clock() - clock0
	-- vòng neon
	for i, ring in ipairs(rings) do
		local bob = math.sin(t * 2 + i * 2.1) * 1.4
		local cy = ring.baseY + bob
		local spin = t * 1.2 + i
		local flashing = os.clock() < ring.flashUntil
		-- xoay khung quanh trục X (trục bay) — pivot cả model
		local pivotCF = CFrame.new(ring.centerX, cy, Z_CENTER) * CFrame.Angles(spin, 0, 0)
		ring.model:PivotTo(pivotCF)
		local pulse = flashing and 0 or (0.1 + 0.15 * (0.5 + 0.5 * math.sin(t * 4 + i)))
		for _, b in ipairs(ring.bars) do
			b.Transparency = pulse
			b.Color = flashing and WHITE or ring.baseColor
		end
		-- phát hiện player bay xuyên (đang ở trên không, gần tâm vòng)
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local p = root.Position
				if math.abs(p.X - ring.centerX) < 6 and math.abs(p.Y - cy) < 11 and math.abs(p.Z - Z_CENTER) < 11 then
					local now = os.clock()
					if now - (ring.lastPass[player] or 0) > 2 then
						ring.lastPass[player] = now
						ring.flashUntil = now + 0.35
						ringBurst(ring)
					end
				end
			end
		end
	end
	-- viền platform thở màu theo sóng chạy dọc X
	for _, trim in ipairs(trims) do
		local wavePhase = (trim.Position.X / 60) - t * 2
		trim.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(wavePhase))
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for _, ring in ipairs(rings) do
		ring.lastPass[player] = nil
	end
end)

print("[Zone15ObbyScript] Momentum Jump Obby ready —", #rings, "rings,", #trims, "trims")
