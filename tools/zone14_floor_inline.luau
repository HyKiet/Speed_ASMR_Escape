-- BẢN THAM KHẢO (version-controlled) của Workspace.Zone14.Mechanics.Zone14FloorScript (v2)
-- Script thật sống inline trong Workspace (KHÔNG Rojo sync) — được ghi qua MCP execute_luau.
-- Nếu cần sửa: sửa file này rồi ghi lại Source vào Studio.

--!strict
--[[
	Zone14FloorScript.luau — Stage 14: Floor Opens Canyon (v2 — smooth)
	Sàn 20 đoạn trapdoor 2 cánh. "Sóng mở" chạy dọc +X đúng 218 studs/s
	(= minWS gate Stage 14): sàn mở NGAY SAU LƯNG người đủ tốc độ; chậm hơn → rơi lava.
	v2: cảnh báo = pulse màu MƯỢT (sine lerp, không nhấp nháy nhị phân),
	hinge Y đọc từ vị trí part thực tế (tránh lệch sau chỉnh tay).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local zone = script.Parent.Parent
local trap = zone:WaitForChild("Ground"):WaitForChild("TrapFloor")
local mech = script.Parent
local lava = mech:WaitForChild("Lava") :: BasePart
local startLight = mech:WaitForChild("StartLight")

local WAVE_SPEED = 218   -- studs/s = minWS gate Stage 14
local X0 = 2520
local X1 = 3060
local LAG = 0.12         -- sóng mở TRỄ sau khi người 218 rời đoạn
local WARN_TIME = 0.4    -- pulse cảnh báo trước khi mở
local OPEN_HOLD = 0.45
local SWING_TIME = 0.28
local REST = 1.8
local OPEN_ANGLE = 100

local SWEEP = (X1 - X0) / WAVE_SPEED
local CYCLE = SWEEP + LAG + WARN_TIME + OPEN_HOLD + SWING_TIME * 2 + REST

local COLOR_WARN = Color3.fromRGB(255, 92, 48)

type Flap = {
	part: BasePart,
	closedCF: CFrame,
	openCF: CFrame,
	baseColor: Color3,
	openAt: number,
	state: string,
	tween: Tween?,
}
local flaps: { Flap } = {}
for _, p in ipairs(trap:GetChildren()) do
	if p:IsA("BasePart") then
		local hingeZ = p:GetAttribute("HingeZ") :: number
		local off = p:GetAttribute("Offset") :: number
		local seg = p:GetAttribute("SegIndex") :: number
		local x = p.Position.X
		local y = p.Position.Y -- đọc Y thực (đã hạ 218.95)
		local ang = math.rad(OPEN_ANGLE) * (off > 0 and 1 or -1)
		local hinge = CFrame.new(x, y, hingeZ)
		local segEndX = X0 + seg * 27
		table.insert(flaps, {
			part = p,
			closedCF = hinge * CFrame.new(0, 0, off),
			openCF = hinge * CFrame.Angles(ang, 0, 0) * CFrame.new(0, 0, off),
			baseColor = p.Color,
			openAt = (segEndX - X0) / WAVE_SPEED + LAG,
			state = "closed",
			tween = nil,
		})
	end
end

local function killTouch(hit: BasePart)
	local character = hit.Parent
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 and Players:GetPlayerFromCharacter(character) then
		humanoid.Health = 0
	end
end
lava.Touched:Connect(killTouch)

local function swing(f: Flap, open: boolean)
	if f.tween then f.tween:Cancel() end
	local tween = TweenService:Create(f.part,
		TweenInfo.new(SWING_TIME, Enum.EasingStyle.Quad, open and Enum.EasingDirection.In or Enum.EasingDirection.Out),
		{ CFrame = open and f.openCF or f.closedCF })
	f.tween = tween
	tween:Play()
end

-- Đèn GO/WAIT
local pillars = {}
local goLabel: TextLabel? = nil
for _, c in ipairs(startLight:GetChildren()) do
	if c.Name:match("^Pillar") then table.insert(pillars, c) end
	if c.Name == "GoBoard" then
		local gui = c:FindFirstChildOfClass("SurfaceGui")
		goLabel = gui and gui:FindFirstChild("GoLabel") :: TextLabel?
	end
end
local GREEN = Color3.fromRGB(80, 255, 120)
local RED = Color3.fromRGB(255, 60, 60)
local function setLight(safe: boolean)
	for _, p in ipairs(pillars) do p.Color = safe and GREEN or RED end
	if goLabel then
		goLabel.Text = safe and "GO!" or "WAIT"
		goLabel.TextColor3 = safe and GREEN or RED
	end
end

local DANGER_AFTER_LAUNCH = WARN_TIME + OPEN_HOLD + SWING_TIME * 2 + 0.25

local startClock = os.clock()
local lightSafe = true
setLight(true)

RunService.Heartbeat:Connect(function()
	local t = (os.clock() - startClock) % CYCLE
	for _, f in ipairs(flaps) do
		local state
		if t >= f.openAt - WARN_TIME and t < f.openAt then
			state = "warn"
		elseif t >= f.openAt and t < f.openAt + SWING_TIME + OPEN_HOLD then
			state = "open"
		else
			state = "closed"
		end
		if state ~= f.state then
			f.state = state
			if state == "open" then
				f.part.Color = f.baseColor
				swing(f, true)
			elseif state == "closed" then
				f.part.Color = f.baseColor
				swing(f, false)
			end
		end
		if state == "warn" then
			-- pulse mượt: lerp base -> cam đỏ theo sine, mạnh dần khi sắp mở
			local k = 1 - (f.openAt - t) / WARN_TIME -- 0 -> 1
			local pulse = 0.5 + 0.5 * math.sin(t * 14)
			f.part.Color = f.baseColor:Lerp(COLOR_WARN, 0.35 + 0.65 * k * pulse)
		end
	end
	local safe = t >= DANGER_AFTER_LAUNCH
	if safe ~= lightSafe then
		lightSafe = safe
		setLight(safe)
	end
end)

print(("[Zone14FloorScript] Floor Opens Canyon v2: %d flaps, wave %d studs/s, cycle %.1fs"):format(#flaps, WAVE_SPEED, CYCLE))
