--!strict
-- Soap — port nguyên vẹn SoapCutClient: mỗi nhịp chạy trên bánh xà phòng tạo LÁT CẮT
-- (rãnh sẫm màu fade 3.2s + 4 dăm xà phòng văng xoay rồi tan). Giữ nguyên POOL 30 dăm
-- + 24 rãnh của bản gốc; template dăm = ReplicatedStorage.RoundCubeMesh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Soap = {}

local CUT_SOUNDS = { 9120972205, 9120626543, 9125610697, 9117020137 } -- whittle, wax press, scoop + mouth pop mềm
Soap.soundIds = CUT_SOUNDS

local CURL_POOL_N, GROOVE_POOL_N = 30, 24
local FOOT_DROP = 3.2
local Y_TOL = 3

function Soap.attach(model, engine)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }

	local bars = {}
	local box, surfY
	local curls, grooves = {}, {}
	local curlIdx, grooveIdx = 0, 0
	local anyFxActive = false

	self.initTask = task.spawn(function()
		local folder = model:WaitForChild("Bars", 10)
		local curlTemplate = ReplicatedStorage:WaitForChild("RoundCubeMesh", 10)
		if not (folder and curlTemplate) then
			warn("[ASMR Soap] thiếu Bars hoặc ReplicatedStorage.RoundCubeMesh")
			return
		end
		engine.Await.childrenStable(folder)
		for _, b in folder:GetChildren() do
			if b:IsA("BasePart") then
				table.insert(bars, { part = b, x = b.Position.X, color = b.Color, halfX = b.Size.X / 2 })
			end
		end
		local tray = model:FindFirstChild("Tray")
		box = if tray and tray:IsA("BasePart") then Bounds.ofBase(tray, 2) else Bounds.ofParts(folder:GetChildren(), 2)
		surfY = bars[1] and (bars[1].part.Position.Y + bars[1].part.Size.Y / 2) or (box and box.topY) or 10.6

		for i = 1, CURL_POOL_N do
			local c = curlTemplate:Clone()
			c:ClearAllChildren()
			c.Name = "SoapCurl"
			c.Anchored = true
			c.CanCollide = false
			c.CanTouch = false
			c.CanQuery = false
			c.CastShadow = false
			c.Transparency = 1
			c.CFrame = CFrame.new(0, -80, 0)
			c.Parent = model
			curls[i] = { part = c, ttl = 0, vel = Vector3.zero, rot = Vector3.zero }
		end
		for i = 1, GROOVE_POOL_N do
			local g = Instance.new("Part")
			g.Name = "Groove"
			g.Anchored = true
			g.CanCollide = false
			g.CanTouch = false
			g.CanQuery = false
			g.CastShadow = false
			g.Material = Enum.Material.SmoothPlastic
			g.Transparency = 1
			g.CFrame = CFrame.new(0, -80, 0)
			g.Parent = model
			grooves[i] = { part = g, ttl = 0, life = 0 }
		end
		self.ready = box ~= nil and #bars > 0
		Log.Floor("Soap", #bars, model)
	end)

	local function cutSound(parent, ratio)
		if not FxBudget.fxOK(parent.Position) then
			return
		end
		SoundPool.playStep(
			CUT_SOUNDS[math.random(#CUT_SOUNDS)],
			parent.Position,
			0.45 + ratio * 0.3,
			0.85 + ratio * 0.35 + (math.random() * 0.2 - 0.1),
			75
		)
	end

	local function spawnCut(bar, z)
		local topY = bar.part.Position.Y + bar.part.Size.Y / 2
		-- rãnh cắt
		grooveIdx = grooveIdx % GROOVE_POOL_N + 1
		local g = grooves[grooveIdx]
		g.part.Size = Vector3.new(bar.part.Size.X + 0.15, bar.part.Size.Y + 0.06, 0.4)
		g.part.CFrame = CFrame.new(bar.x, bar.part.Position.Y + 0.04, z)
		g.part.Color = Color3.new(bar.color.R * 0.62, bar.color.G * 0.62, bar.color.B * 0.62)
		g.part.Transparency = 0.15
		g.life = 3.2
		g.ttl = 3.2
		anyFxActive = true
		-- dăm xà phòng (chỉ khi gần camera)
		if FxBudget.nearCamera(Vector3.new(bar.x, topY, z), 110) then
			for _ = 1, 4 do
				curlIdx = curlIdx % CURL_POOL_N + 1
				local c = curls[curlIdx]
				local sz = 0.45 + math.random() * 0.5
				c.part.Size = Vector3.new(sz, sz * 0.4, sz * 0.8)
				c.part.Color = bar.color
				c.part.Transparency = 0.05
				c.part.CFrame = CFrame.new(
					bar.x + (math.random() - 0.5) * 3,
					topY + 0.4,
					z + (math.random() - 0.5) * 1.5
				) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3)
				c.vel = Vector3.new((math.random() - 0.5) * 14, 10 + math.random() * 10, (math.random() - 0.5) * 14)
				c.rot = Vector3.new((math.random() - 0.5) * 12, (math.random() - 0.5) * 12, (math.random() - 0.5) * 12)
				c.ttl = 0.85
			end
		end
	end

	local onFloorState = nil

	function self.update(dt, _now, foot)
		if not self.ready then
			return
		end

		if foot then
			local pos = foot.pos
			if not engine.Bounds.contains(box, pos) or math.abs((pos.Y - FOOT_DROP) - surfY) > Y_TOL then
				onFloorState = nil
			else
				local ratio = foot.ratio
				local st = onFloorState
				if not st then
					st = { dist = 0, last = pos, cd = 0 }
					onFloorState = st
				end
				st.cd = math.max(0, st.cd - dt)
				local d = pos - st.last
				st.last = pos
				st.dist += Vector3.new(d.X, 0, d.Z).Magnitude
				if st.dist >= 2.0 and st.cd <= 0 then
					st.dist = 0
					st.cd = 0.09
					-- tìm bánh xà phòng dưới chân
					for _, bar in bars do
						if
							math.abs(pos.X - bar.x) <= bar.halfX
							and math.abs(pos.Z - bar.part.Position.Z) <= bar.part.Size.Z / 2
						then
							spawnCut(bar, pos.Z)
							cutSound(foot.root, ratio)
							break
						end
					end
				end
			end
		else
			onFloorState = nil
		end

		-- animate pools (thủ công, rẻ) — bỏ qua hoàn toàn khi không có FX sống
		if anyFxActive then
			local still = false
			for _, c in curls do
				if c.ttl > 0 then
					c.ttl -= dt
					if c.ttl <= 0 then
						c.part.Transparency = 1
						c.part.CFrame = CFrame.new(0, -80, 0)
					else
						still = true
						c.vel += Vector3.new(0, -60 * dt, 0)
						c.part.CFrame = (c.part.CFrame + c.vel * dt)
							* CFrame.Angles(c.rot.X * dt, c.rot.Y * dt, c.rot.Z * dt)
						c.part.Transparency = 0.05 + 0.95 * (1 - c.ttl / 0.85)
					end
				end
			end
			for _, g in grooves do
				if g.ttl > 0 then
					g.ttl -= dt
					if g.ttl <= 0 then
						g.part.Transparency = 1
						g.part.CFrame = CFrame.new(0, -80, 0)
					else
						still = true
						if g.ttl < 1 then
							g.part.Transparency = 0.15 + 0.85 * (1 - g.ttl)
						end
					end
				end
			end
			anyFxActive = still
		end
	end

	function self.destroy()
		self.ready = false
		engine.Await.cancel(self.initTask)
		for _, curl in curls do
			curl.part:Destroy()
		end
		for _, groove in grooves do
			groove.part:Destroy()
		end
		table.clear(curls)
		table.clear(grooves)
		table.clear(bars)
	end

	return self
end

return Soap
