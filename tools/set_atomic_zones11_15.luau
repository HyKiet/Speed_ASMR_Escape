-- set_atomic_zones11_15.luau — Đặt ModelStreamingMode = Atomic cho toàn bộ Model ở Zone 11..15

local Zones = workspace:WaitForChild("Zones")

local count = 0
for i = 11, 15 do
	local zone = Zones:FindFirstChild("Zone" .. i)
	if zone then
		for _, desc in zone:GetDescendants() do
			if desc:IsA("Model") then
				desc.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				count += 1
			end
		end
	end
end

print(`[SET ATOMIC] Đã chuyển đổi {count} Model ở Zone 11 -> 15 sang ModelStreamingMode = Atomic!`)
