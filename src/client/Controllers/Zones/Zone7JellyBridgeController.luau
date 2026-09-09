--!strict
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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local RunService = game:GetService("RunService")

local Zone7JellyBridgeController = {}

local WARN_COLOR = Color3.fromRGB(255, 82, 148)
local CULL_DIST = 130
local FALL_TIME = 0.55
local RISE_TIME = 0.5

type Block = { part: BasePart, cf0: CFrame, size0: Vector3, transp0: number, color0: Color3 }
type Segment = { part: BasePart, z: number, state: string, t: number, blocks: { Block }? }
local segs: { Segment } = {}

local function collectBlocks(segZ: number): { Block }
	-- lấy khối jelly hiện có trong dải Z của segment (lazy — an toàn với streaming)
	local zones = workspace:FindFirstChild("Zones")
	local zone7 = zones and zones:FindFirstChild("Zone7")
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

local function applyRest(e: Block)
	local b = e.part
	b.CFrame = e.cf0
	b.Size = e.size0
	b.Transparency = e.transp0
	b.Color = e.color0
end

local function applyHidden(e: Block)
	e.part.Transparency = 1
end

function Zone7JellyBridgeController.Init() end

local started = false
local folderJanitor = Janitor.new()
local activeFolder: Instance? = nil

function Zone7JellyBridgeController.Start()
	if started then
		return
	end
	started = true
	local elapsed = 0.5
	local warned = false
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.5 then
			elapsed = 0
			local zones = workspace:FindFirstChild("Zones")
			local zone = zones and zones:FindFirstChild("Zone7")
			local mechanics = zone and zone:FindFirstChild("Mechanics")
			local folder = mechanics and mechanics:FindFirstChild("JellyBridge")
			if folder ~= activeFolder then
				folderJanitor:Sweep()
				activeFolder = folder
				if folder then
					local function register(part: Instance)
						if not part:IsA("BasePart") or folderJanitor[part] then
							return
						end
						local e: Segment = { part = part, z = part.Position.Z, state = "up", t = 0, blocks = nil }
						table.insert(segs, e)
						local connection = part:GetAttributeChangedSignal("State"):Connect(function()
							local state = part:GetAttribute("State")
							e.state = if typeof(state) == "string" then state else "up"
							e.t = 0
							-- Chụp lúc warn để không lưu nhầm màu hoặc hình đang rơi làm gốc.
							if e.state == "warn" and not e.blocks then
								e.blocks = collectBlocks(e.z)
							end
						end)
						folderJanitor[part] = function()
							connection:Disconnect()
							if e.blocks then
								for _, block in e.blocks do
									applyRest(block)
								end
							end
							local index = table.find(segs, e)
							if index then
								table.remove(segs, index)
							end
						end
					end
					folderJanitor:Add(folder.ChildAdded:Connect(register))
					folderJanitor:Add(folder.ChildRemoved:Connect(function(part)
						folderJanitor[part] = nil
					end))
					for _, part in folder:GetChildren() do
						register(part)
					end
					Log.Boot(("[Zone7JellyBridge] visual sẵn sàng — %d segment"):format(#segs))
				end
			end
			if not folder and not warned then
				warned = true
				warn("[Zone7JellyBridge] Waiting for streamed JellyBridge; retrying")
			end
		end
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
end

return Zone7JellyBridgeController
