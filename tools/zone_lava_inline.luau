-- BẢN THAM KHẢO của Workspace.Zones.ZoneLavaKillScript (inline script, không Rojo sync).
-- Giết nhân vật chạm bất kỳ part tên "LavaKillFloor" trong Workspace.Zones.
-- Mỗi zone có 1 LavaKillFloor (Neon cam, dày 14 studs chống tunnel) + LavaCrust decor
-- nằm trong ZoneN.Mechanics, do session 2026-07-12 tạo. Zone3 giữ KillFloor cũ (restyle lava),
-- Zone14 (Lava) + Zone15 (KillFloor) giữ nguyên cơ chế riêng. GlobalKillZone Y-280 là backstop.
local zonesFolder = script.Parent

local function kill(hit: BasePart)
	local model = hit:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

local function hook(inst: Instance)
	if inst:IsA("BasePart") and inst.Name == "LavaKillFloor" then
		inst.Touched:Connect(kill)
	end
end

for _, d in ipairs(zonesFolder:GetDescendants()) do
	hook(d)
end
zonesFolder.DescendantAdded:Connect(hook)
