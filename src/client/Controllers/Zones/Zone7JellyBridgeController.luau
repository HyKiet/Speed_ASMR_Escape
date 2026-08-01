--[[
	Zone7JellyBridgeController — VISUAL cầu sập jelly Zone 7 (100% client, 0 network/frame).

	Server (Workspace.Zone7.Zone7JellyBridgeScript) chỉ toggle attribute "State"
	("up" | "warn" | "fall") + CanCollide trên 30 segment collider vô hình.
	Client này nghe attribute và tự animate khối jelly ASMR trong dải Z của segment:
	  • warn: chớp màu hồng nóng + co giật squash nhanh (0.35s)
	  • fall: khối rơi xoáy nhẹ + tan mờ (0.55s) rồi ẩn
	  • up:   mọc lại từ dưới với overshoot đàn hồi + hiện dần
	Cull: camera ngoài 130 studs → set trạng thái cuối tức thì, không ghi property.
]]

local RunService = game:GetService("RunService")

local Zone7JellyBridgeController = {}

local WARN_COLOR = Color3.fromRGB(255, 82, 148)
local CULL_DIST = 130
local FALL_TIME = 0.55
local RISE_TIME = 0.5

local segs = {} -- { part, z, state, t, blocks = { {part, cf0, transp0, color0} } | nil }

local function collectBlocks(segZ)
	-- lấy khối jelly hiện có trong dải Z của segment (lazy — an toàn với streaming)
	local zone7 = workspace.Zones and workspace.Zones:FindFirstChild("Zone7")
	local asmr = zone7 and zone7:FindFirstChild("ASMR")
	if not asmr then
		return {}
	end
	local list = {}
	for _, m in asmr:GetChildren() do
		if m.Name:find("Jelly_Floor7") then
			local folder = m:FindFirstChild("Blocks")
			if folder then
				for _, b in folder:GetChildren() do
					if b:IsA("BasePart") and math.abs(b.Position.Z - segZ) <= 5.5 then
						table.insert(list, {
							part = b,
							cf0 = b.CFrame,
							size0 = b.Size,
							transp0 = b.Transparency,
							color0 = b.Color,
						})
					end
				end
			end
		end
	end
	return list
end

local function applyRest(e)
	local b = e.part
	b.CFrame = e.cf0
	b.Size = e.size0
	b.Transparency = e.transp0
	b.Color = e.color0
end

local function applyHidden(e)
	e.part.Transparency = 1
end

function Zone7JellyBridgeController.Init() end

function Zone7JellyBridgeController.Start()
	task.spawn(function()
		local zone7 = workspace:WaitForChild("Zones", 10) and workspace.Zones:WaitForChild("Zone7", 10)
		local mech = zone7 and zone7:WaitForChild("Mechanics", 10)
		local folder = mech and mech:WaitForChild("JellyBridge", 15)
		if not folder then
			return
		end

		local function register(p)
			if not p:IsA("BasePart") then
				return
			end
			local e = { part = p, z = p.Position.Z, state = "up", t = 0, blocks = nil }
			table.insert(segs, e)
			p:GetAttributeChangedSignal("State"):Connect(function()
				local s = p:GetAttribute("State") or "up"
				e.state = s
				e.t = 0
				-- CHỈ chụp trạng thái gốc lúc bắt đầu warn (chụp giữa chu kỳ sẽ
				-- lưu nhầm màu hồng/độ mờ đang animate làm "gốc" — bug kẹt màu)
				if s == "warn" and not e.blocks then
					e.blocks = collectBlocks(e.z)
				end
			end)
		end
		for _, p in folder:GetChildren() do
			register(p)
		end
		folder.ChildAdded:Connect(register)
		print(("[Zone7JellyBridge] visual sẵn sàng — %d segment"):format(#segs))

		RunService.Heartbeat:Connect(function(dt)
			local cam = workspace.CurrentCamera
			local camPos = cam and cam.CFrame.Position
			for _, e in segs do
				if not e.blocks then
					continue
				end
				local near = camPos and math.abs(camPos.Z - e.z) < CULL_DIST and math.abs(camPos.X + 4) < CULL_DIST
				e.t += dt
				if e.state == "warn" then
					if near then
						-- nhấp sáng trắng nóng (Lerp giữ tông màu gốc) + rùng nhẹ
						local k = 0.5 + 0.5 * math.sin(e.t * 40)
						local sq = 1 - 0.08 * k
						for _, blk in e.blocks do
							blk.part.Color = blk.color0:Lerp(WARN_COLOR, 0.35 + 0.4 * k)
							blk.part.Size = Vector3.new(blk.size0.X, blk.size0.Y * sq, blk.size0.Z)
						end
					end
				elseif e.state == "fall" then
					local a = math.min(e.t / FALL_TIME, 1)
					if near and a < 1 then
						-- rơi giữ nguyên màu thạch, xoáy nhẹ so le, tan mờ dần
						local drop = 26 * a * a
						local spin = 0.45 * a
						for i, blk in e.blocks do
							local dir = (i % 2 == 0) and 1 or -1
							blk.part.Color = blk.color0
							blk.part.Size = blk.size0
							blk.part.CFrame = blk.cf0
								* CFrame.new(0, -drop, 0)
								* CFrame.Angles(spin * 0.35 * dir, spin * 0.2, spin * dir)
							blk.part.Transparency = blk.transp0 + (0.95 - blk.transp0) * (a * a)
						end
					elseif a >= 1 then
						for _, blk in e.blocks do
							applyHidden(blk)
						end
					end
				elseif e.state == "up" then
					local a = math.min(e.t / RISE_TIME, 1)
					if a >= 1 then
						for _, blk in e.blocks do
							applyRest(blk)
						end
						e.blocks = nil -- xong chu kỳ — ngừng animate segment này
					elseif near then
						-- mọc từ dưới -6 với overshoot đàn hồi
						local rise = 1 - math.exp(-8 * a)
						local yOff = -6 * (1 - rise)
						local wob = 1 + 0.3 * math.exp(-5 * a) * math.sin(14 * a)
						for _, blk in e.blocks do
							blk.part.CFrame = blk.cf0 * CFrame.new(0, yOff, 0)
							blk.part.Size = Vector3.new(blk.size0.X, blk.size0.Y * wob, blk.size0.Z)
							blk.part.Transparency = blk.transp0 + (1 - blk.transp0) * (1 - a)
						end
					end
				end
			end
		end)
	end)
end

return Zone7JellyBridgeController
