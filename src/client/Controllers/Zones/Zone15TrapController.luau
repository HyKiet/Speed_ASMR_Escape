--!strict
--[[
	Zone15TrapController.luau — Render local CẢ BA bẫy của Stage 15.

	BẪY 1 "Laser Sweep"  (marker Trap1) — 2 tia mảnh sát sàn trượt tới-lui dọc đường chạy.
	                                      Chạy theo NHỊP VÒNG LẶP (đồng hồ tất định).
	BẪY 2 "Shift Bridge" (marker Trap2) — 2 tấm sàn lấp khe, trượt ngang ra khỏi lối đi.
	BẪY 3 "Split Floor"  (Ground.Obby_Open1/2) — cầu cuối tách đôi sang 2 bên.
	                                      Từ 2026-08-22 bẫy 2 & 3 KÍCH THEO NGƯỜI CHƠI.

	NGUYÊN TẮC (giống Zone 8/9/11/14): server KHÔNG replicate CFrame. Vị trí suy ra từ
	`workspace:GetServerTimeNow()` + hàm toán trong Shared.Config.Zones.Zone15Traps, nên mọi
	client thấy y hệt nhau còn băng thông là 0. Va chạm hoạt động vì nhân vật do CHÍNH client
	đó mô phỏng — part đã Anchored nên client dời tự do, không tranh chấp quyền sở hữu.

	NGOẠI LỆ CỦA "MỌI CLIENT THẤY Y HỆT" (bẫy 2 & 3): chúng không còn chạy theo pha chung mà
	nằm ngủ tới khi NGƯỜI CHƠI CỦA CLIENT NÀY tới gần thì nháy đỏ rồi mở ra (xem khối KÍCH
	HOẠT THEO NGƯỜI CHƠI trong Zone15Traps). Nghĩa là hai người chạy cách nhau vài giây sẽ
	thấy tấm sàn ở hai tư thế khác nhau. Chấp nhận được vì cả hai bẫy KHÔNG có logic server
	(chúng giết gián tiếp — người chơi rơi xuống KillBlockGlobal), nên không có "sự thật của
	server" nào để mà lệch. Bẫy 1 thì server phân xử sát thương ⇒ BẮT BUỘC giữ nhịp chung.

	Vị trí gốc luôn đọc từ attribute `HomeCF` chứ KHÔNG lấy vị trí hiện thời của part:
	part đã bị chính controller này dời đi rồi.

	NGÂN SÁCH KHUNG HÌNH:
	  • Một RenderStepped duy nhất cho cả zone.
	  • MỖI CỤM tự resolve và tự cull. Zone 15 trải ~3.800 studs nên 3 cụm KHÔNG BAO GIỜ cùng
	    stream một lúc — gộp chung một resolve() sẽ khiến cả ba tê liệt (đã dính thật khi QA).
	  • Zero-GC: cache part + HomeCF một lần, trong vòng lặp chỉ ghi CFrame/Color.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Zone15Traps = require(ReplicatedStorage.Shared.Config.Zones.Zone15Traps)
local ZoneLod = require(script.Parent.ZoneLod)

local SW = Zone15Traps.Sweep
local SH = Zone15Traps.Shuttle
local F = Zone15Traps.SplitFloor
local TR = Zone15Traps.Trigger

-- Bán kính SÀN. Tầm thức thật do `ZoneLod.RadiusSq` quyết định theo WalkSpeed — xem ZoneLod.
local RENDER_RADIUS = 380
local RESOLVE_INTERVAL = 0.5

local Zone15TrapController = {}

-- `inst` là PVInstance: tấm sàn bẫy 2 do người dựng map làm là Model nhiều part, còn tia
-- laser là Part đơn. PivotTo() dùng được cho cả hai nên không cần tách hai nhánh render.
-- `paint` chỉ có ở bẫy 2 (tấm sàn phải nháy đỏ): danh sách part + màu GỐC của chúng, gom
-- một lần lúc resolve để vòng render không phải duyệt cây Instance.
type PaintPart = { part: BasePart, base: Color3 }
type MovingView = { inst: PVInstance, index: number, home: CFrame, paint: { PaintPart }? }
type DoorView = { part: BasePart, home: CFrame, dir: number, baseColor: Color3, isDoor: boolean }

local beamViews: { MovingView } = {}
local padViews: { MovingView } = {}
local doorViews: { DoorView } = {}

-- Tâm cụm dùng để cull, tính lại mỗi lần resolve (bẫy dời theo marker nên không hằng số hoá).
local beamCenter = Vector3.zero
local padCenter = Vector3.zero
local doorCenter = Vector3.zero

local connection: RBXScriptConnection? = nil
local resolverThread: thread? = nil

--=====================================================================================
-- RESOLVE — chạy ở vòng poll chậm, KHÔNG chạy trong RenderStepped.
-- Mỗi cụm độc lập: cụm nào đã stream thì cụm đó chạy.
--=====================================================================================

local function readyZone(): Instance?
	local zones = Workspace:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild("Zone15")
	if zone and zone:GetAttribute("TrapsReady") == true then
		return zone
	end
	return nil
end

local function cluster(zone: Instance, name: string): Instance?
	local mechanics = zone:FindFirstChild("Mechanics")
	local traps = mechanics and mechanics:FindFirstChild("Traps")
	return traps and traps:FindFirstChild(name)
end

-- Gom part để tô màu cảnh báo. Tấm sàn bẫy 2 có thể là Part đơn HOẶC Model nhiều part do
-- người dựng map làm — cả hai đều phải nháy được, nên duyệt đệ quy một lần tại đây.
local function collectPaint(inst: PVInstance): { PaintPart }
	local out: { PaintPart } = {}
	if inst:IsA("BasePart") then
		table.insert(out, { part = inst, base = inst.Color })
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, { part = d, base = d.Color })
		end
	end
	return out
end

-- Streaming nạp lẻ từng part: cache nửa vời sẽ không bao giờ được sửa vì vòng poll tưởng
-- đã xong. Chỉ nhận khi ĐỦ số part mong đợi, thiếu thì bỏ hết để lượt sau thử lại.
local function resolveMoving(
	zone: Instance,
	clusterName: string,
	expected: number,
	into: { MovingView },
	withPaint: boolean
): Vector3
	table.clear(into)

	local model = cluster(zone, clusterName)
	if not model then
		return Vector3.zero
	end

	local sum = Vector3.zero
	for _, child in model:GetChildren() do
		local home = child:GetAttribute("HomeCF")
		local index = child:GetAttribute("TrapIndex")
		if child:IsA("PVInstance") and typeof(home) == "CFrame" and typeof(index) == "number" then
			table.insert(into, {
				inst = child,
				index = index,
				home = home,
				paint = if withPaint then collectPaint(child) else nil,
			})
			sum += home.Position
		end
	end

	if #into ~= expected then
		table.clear(into)
		return Vector3.zero
	end
	return sum / expected
end

local function resolveDoors(zone: Instance): Vector3
	table.clear(doorViews)

	local ground = zone:FindFirstChild("Ground")
	if not ground then
		return Vector3.zero
	end

	local sum = Vector3.zero
	for _, lane in F.Lanes do
		local model = ground:FindFirstChild(lane.Name)
		if not model then
			table.clear(doorViews)
			return Vector3.zero
		end
		for _, child in model:GetChildren() do
			local home = child:GetAttribute("HomeCF")
			local dir = child:GetAttribute("SlideDir")
			if child:IsA("BasePart") and typeof(home) == "CFrame" and typeof(dir) == "number" then
				table.insert(doorViews, {
					part = child,
					home = home,
					dir = dir,
					baseColor = child.Color,
					isDoor = string.find(child.Name, "Door") ~= nil,
				})
				sum += home.Position
			end
		end
	end

	if #doorViews == 0 then
		return Vector3.zero
	end
	return sum / #doorViews
end

local function alive(views: { any }): boolean
	local first = views[1]
	if not first then
		return false
	end
	return (first.inst or first.part):IsDescendantOf(Workspace)
end

local function poll()
	local zone = readyZone()
	if not zone then
		table.clear(beamViews)
		table.clear(padViews)
		table.clear(doorViews)
		return
	end

	if not alive(beamViews) then
		beamCenter = resolveMoving(zone, SW.ClusterName, #SW.Beams, beamViews, false)
	end
	if not alive(padViews) then
		padCenter = resolveMoving(zone, SH.ClusterName, #SH.Pads, padViews, true)
	end
	if not alive(doorViews) then
		doorCenter = resolveDoors(zone)
	end
end

--=====================================================================================
-- RENDER
--=====================================================================================

local function renderBeams(now: number)
	for i = 1, #beamViews do
		local view = beamViews[i]
		local offset = Zone15Traps.SweepOffset(now, view.index)
		local beam = view.inst :: BasePart
		beam.CFrame = view.home * CFrame.new(offset, 0, 0)
		-- Sáng rực ở hai đầu quét (lúc tia gần như đứng yên) → đọc được nhịp để canh nhảy.
		local edge = math.abs(offset) / SW.Amplitude
		beam.Color = SW.Color:Lerp(SW.ColorHot, edge * edge)
	end
end

--[[
	Tấm sàn trước đây giữ NGUYÊN màu map ("chúng cố tình trông y hệt sàn thật"). Từ 2026-08-22
	chúng NHÁY ĐỎ trước khi mở: khi bẫy chỉ chạy theo nhịp vòng lặp thì im lặng là công bằng
	(nhịp đều, học được), nhưng bẫy KÍCH THEO NGƯỜI CHƠI mà không báo trước thì thành phục kích
	— cảnh báo đỏ chính là thứ biến nó thành kỹ năng thay vì xui xẻo.

	`warnPainted` chặn việc ghi Color mỗi frame lúc bẫy đang ngủ (phần lớn thời gian).
]]
local padWarnPainted = false

local function paintPads(mix: number)
	for i = 1, #padViews do
		local paint = padViews[i].paint
		if paint then
			for j = 1, #paint do
				local p = paint[j]
				p.part.Color = if mix > 0 then p.base:Lerp(TR.ColorAlarm, mix) else p.base
			end
		end
	end
	padWarnPainted = mix > 0
end

local function renderPads(now: number, elapsed: number)
	for i = 1, #padViews do
		local view = padViews[i]
		view.inst:PivotTo(view.home * CFrame.new(0, 0, Zone15Traps.ShuttleOffset(elapsed, view.index)))
	end

	local mix = Zone15Traps.ArmedWarn(elapsed, now)
	if mix > 0 or padWarnPainted then
		paintPads(mix)
	end
end

local function renderDoors(now: number, elapsed: number)
	local offset = F.Slide * Zone15Traps.ArmedAlpha(elapsed)
	-- Nhấp nháy mượt (sine) thay vì bật/tắt nhị phân — cùng ngôn ngữ cảnh báo với Zone 14.
	local warnMix = Zone15Traps.ArmedWarn(elapsed, now)

	for i = 1, #doorViews do
		local view = doorViews[i]
		-- Trượt NGANG (trục Z cục bộ): cả làn rời khỏi đường chạy về một phía.
		view.part.CFrame = view.home * CFrame.new(0, 0, view.dir * offset)
		if view.isDoor then
			view.part.Color = if warnMix > 0 then view.baseColor:Lerp(F.ColorWarn, warnMix) else view.baseColor
		end
	end
end

-- Khi cụm chuyển sang NGỦ, đưa part về đúng tư thế nghỉ MỘT LẦN. Nếu không, part sẽ đứng
-- chết cứng ở tư thế dở dang (tia đang giữa đường quét, tấm sàn đang hở nửa chừng) và người
-- chơi từ xa nhìn vào tưởng bẫy hỏng.
local function sleepMoving(views: { MovingView })
	for i = 1, #views do
		views[i].inst:PivotTo(views[i].home)
	end
	if views == padViews and padWarnPainted then
		paintPads(0)
	end
end

local function sleepDoors()
	for i = 1, #doorViews do
		local view = doorViews[i]
		view.part.CFrame = view.home
		if view.isDoor then
			view.part.Color = view.baseColor
		end
	end
end

-- Trạng thái thức/ngủ của từng cụm (đổi trạng thái mới ghi part, mỗi khung hình không đụng gì).
local beamAwake, padAwake, doorAwake = false, false, false
-- Mốc nhịp hạ tần riêng từng cụm (xem ZoneLod.ShouldStepFar).
local beamFar, padFar, doorFar = 0, 0, 0

--[[
	Thời điểm bẫy 2 / bẫy 3 được KÍCH (giờ server, cùng đồng hồ mọi thứ khác trong file).
	`-math.huge` = chưa từng kích ⇒ `elapsed` là vô cực ⇒ `ArmedAlpha` trả 0 ⇒ sàn kín.

	⚠️ KHÔNG reset về `-math.huge` khi cụm ngủ. Cụm ngủ nghĩa là người chơi đã đi xa; giữ
	nguyên mốc cũ thì lượt quay lại `now - armedAt` vẫn lớn hơn `ARMED_SPAN + RearmSeconds`
	nên bẫy sẵn sàng ngay — mà không phải tốn thêm một biến trạng thái nào.
]]
local padArmedAt = -math.huge
local doorArmedAt = -math.huge

local REARM_TOTAL = Zone15Traps.ARMED_SPAN + TR.RearmSeconds

--[[
	Kích khi người chơi vào trong bán kính-tính-bằng-giây VÀ lượt trước đã xong hẳn (kể cả
	thời gian nghỉ). Trả về mốc kích mới.

	Bán kính đo tới TÂM CỤM: bẫy 2 dài ~48 studs, bẫy 3 dài ~170 — sai số đó nhỏ hơn nhiều so
	với quãng `LeadSeconds` (222 studs ở tốc độ Stage 15) nên không cần đo theo từng tấm.
]]
local function arm(distSq: number, trigSq: number, now: number, armedAt: number): number
	if distSq <= trigSq and now - armedAt >= REARM_TOTAL then
		return now
	end
	return armedAt
end

local function step()
	-- Gốc nhân vật tra MỘT lần mỗi frame cho cả bảy controller bẫy, không phải mỗi
	-- controller một lần `FindFirstChild` — xem `ZoneLod.Root`.
	if not ZoneLod.Root() then
		return
	end
	local pos = ZoneLod.RootPosition()
	local now = ZoneLod.Now()
	local radiusSq = ZoneLod.RadiusSq(RENDER_RADIUS)
	local shouldStep: boolean

	-- Bán kính KÍCH (khác bán kính RENDER ở trên: render lo "có nhìn thấy không", kích lo
	-- "còn mấy giây nữa thì tới"). Tính một lần mỗi frame cho cả hai bẫy.
	local trigger = Zone15Traps.TriggerRadius(ZoneLod.WalkSpeed())
	local trigSq = trigger * trigger

	local dx, dz = pos.X - beamCenter.X, pos.Z - beamCenter.Z
	local distSq = dx * dx + dz * dz
	local near = distSq <= radiusSq and alive(beamViews)
	if near then
		shouldStep, beamFar = ZoneLod.ShouldStepFar(distSq, now, beamFar)
		if shouldStep then
			renderBeams(now)
		end
	elseif beamAwake and alive(beamViews) then
		sleepMoving(beamViews)
	end
	beamAwake = near

	dx, dz = pos.X - padCenter.X, pos.Z - padCenter.Z
	distSq = dx * dx + dz * dz
	near = distSq <= radiusSq and alive(padViews)
	if near then
		padArmedAt = arm(distSq, trigSq, now, padArmedAt)
		shouldStep, padFar = ZoneLod.ShouldStepFar(distSq, now, padFar)
		if shouldStep then
			renderPads(now, now - padArmedAt)
		end
	elseif padAwake and alive(padViews) then
		sleepMoving(padViews)
	end
	padAwake = near

	dx, dz = pos.X - doorCenter.X, pos.Z - doorCenter.Z
	distSq = dx * dx + dz * dz
	near = distSq <= radiusSq and alive(doorViews)
	if near then
		doorArmedAt = arm(distSq, trigSq, now, doorArmedAt)
		shouldStep, doorFar = ZoneLod.ShouldStepFar(distSq, now, doorFar)
		if shouldStep then
			renderDoors(now, now - doorArmedAt)
		end
	elseif doorAwake and alive(doorViews) then
		sleepDoors()
	end
	doorAwake = near
end

--=====================================================================================

function Zone15TrapController.Init() end

function Zone15TrapController.Start()
	if connection then
		return
	end
	connection = RunService.RenderStepped:Connect(step)

	resolverThread = task.spawn(function()
		while true do
			poll()
			task.wait(RESOLVE_INTERVAL)
		end
	end)
end

function Zone15TrapController.Stop()
	-- Dừng cả vòng dò streaming; ngắt render thôi vẫn giữ controller sống ngầm.
	if resolverThread then
		if coroutine.status(resolverThread) == "suspended" then
			task.cancel(resolverThread)
		end
		resolverThread = nil
	end
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Zone15TrapController
