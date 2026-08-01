--!strict
--[[
	Zone6SharkController — phát hiện va chạm cá mập Zone 6 phía CLIENT.

	Cá mập được server animate (Workspace.Zone6.Mechanics.Zone6SharkScript) — chỉ
	1 root/con replicate. Việc "chạm chết" tính TẠI CLIENT dựa trên đúng vị trí cá mà
	người chơi ĐANG NHÌN THẤY (đã nội suy), nên hình ảnh khớp 100% — không còn cảnh
	"cá còn xa mà đã chết" do server chạy trước ~0.1s.

	Kill = set Humanoid.Health = 0 của CHÍNH mình (client sở hữu nhân vật → replicate).
	Tự sát môi trường không phải lỗ hổng (chỉ hại chính mình). 0 packet, 0 chi phí server.
	Mỗi client chỉ kiểm tra bản thân với ≤4 cá → 25 player vẫn nhẹ.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Zone6SharkController = {}

local KILL_R = 8 -- bán kính chạm thân cá (cá to → hitbox rộng cho công bằng)
local BREACH_Y = 1 -- chỉ chết khi cá đã nhô rõ khỏi nước

local player = Players.LocalPlayer

local function distToSeg(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom < 1e-4 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / denom, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

function Zone6SharkController.Init() end

function Zone6SharkController.Start()
	task.spawn(function()
		local zones = workspace:WaitForChild("Zones", 20)
		local zone6 = zones and zones:WaitForChild("Zone6", 20)
		local mech = zone6 and zone6:WaitForChild("Mechanics", 20)
		local sharks = mech and mech:WaitForChild("Sharks", 30)
		if not sharks then
			return
		end

		local dead = false

		RunService.Heartbeat:Connect(function()
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not (hum and root) or hum.Health <= 0 then
				dead = false
				return
			end
			if dead then
				return
			end
			local pos = root.Position
			for _, m in sharks:GetChildren() do
				local body = m.PrimaryPart or m:FindFirstChild("SharkRoot")
				if body and body:IsA("BasePart") and body.Position.Y > BREACH_Y then
					-- lọc thô theo khoảng cách tâm trước khi tính đoạn (rẻ)
					if (body.Position - pos).Magnitude <= body.Size.Z / 2 + KILL_R + 4 then
						local cf = body.CFrame
						local half = body.Size.Z / 2
						local nose = cf * Vector3.new(0, 0, half)
						local tail = cf * Vector3.new(0, 0, -half)
						if distToSeg(pos, nose, tail) <= KILL_R then
							dead = true
							hum.Health = 0
							break
						end
					end
				end
			end
		end)
		print("[Zone6SharkController] client kill khớp hình ảnh sẵn sàng")
	end)
end

return Zone6SharkController
