--!strict
-- GummySquish — 🍬 SÀN KẸO DẺO SÓNG LAN (thế hệ mới, Zone 14).
--
-- Khác hẳn SlimeSquish cũ (EditableMesh, mô phỏng từng vertex — nặng và chỉ lõm cục bộ):
-- sàn này là LƯỚI Ô PART, mỗi ô là một chất điểm trong mạng lò xo 2D. Dậm chân xuống là
-- SÓNG LAN RA khắp sàn: ô dưới chân lún sâu, vành quanh PHỒNG NGƯỢC LÊN (bảo toàn thể
-- tích), ô còn nhấp nhô dập dềnh vài nhịp rồi tắt dần.
--
-- Ba tầng "phê" chồng lên nhau, tất cả đều đi kèm phép ghi CFrame/Size vốn đã phải làm:
--   1. LÚN + PHỒNG  — Size.Y co/giãn, đáy ô neo cố định (mặt trên nhấp nhô như mặt thạch).
--   2. NGHIÊNG THEO SÓNG — ô nghiêng theo gradient của mặt sóng → bề mặt mềm như chất lỏng,
--      không còn cảm giác "lưới ô vuông" cứng đờ.
--   3. VỆT SÁNG CHẠY THEO CHÂN — ô lún ngả màu sâu, ô phồng bật màu rim sáng → mỗi bước
--      chân đẩy ra một vòng sáng lan tỏa.
--
-- Hiệu năng (mục tiêu: không nhích FPS dù sàn 128 ô × 3 platform):
--   • ACTIVE SET dạng MẢNG SỐ NGUYÊN — không string key, không concat, 0 rác GC mỗi frame
--     (bản SlimeSquish cũ tạo ~2000 string/giây chỉ để đánh chỉ mục).
--   • Ô ngủ = không đọc, không ghi. Sàn tĩnh + chân ở xa → vòng lặp rỗng.
--   • Camera-cull cả sàn ngoài 110 studs: snap về nghỉ đúng một lần rồi ngủ hẳn.
--   • Chỉ ghi part khi lệch > ngưỡng thị giác (~1cm) — tránh re-batch render vô ích.
--   • Trần MAX_ACTIVE chặn worst-case khi nhiều sóng chồng nhau.
--
-- Hợp đồng model (tag ASMRFloor + FloorType="GummySquish", nên Atomic):
--   • `Tiles` (Folder) — lưới Part chữ nhật đều, cùng cỡ, cùng cao độ đáy.
--   • `Collider` (BasePart, CanCollide) — mặt đi thật, top THẤP HƠN đỉnh ô để chân ngập gel.
-- Attribute tinh chỉnh trên model: `DentRadius`, `DentDepth`, `Wave`, `Bounce`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local GummySquish = {}

--[[
	BỘ ÂM "SquishHand" — 6 mẫu CÙNG MỘT BỘ THU (sillycutiebun), thay bộ cũ 2026-08-12.

	Vì sao đổi (user: "nghe không ASMR, không tương đồng"): bộ cũ
	{133222321566847, 76169806288463, 9114631918, 9114520014} có hai vấn đề cộng lại —

	  1. NÓ LÀ BỘ ĐI MƯỢN. Bốn ID đó chính là bộ của `SlimeSquish`, và ba trong số đó còn dùng
	     lại ở `Clay`/`SlimeJelly`. Sàn kẹo dẻo của Zone 14 không có tiếng riêng nào cả.
	  2. ĐỘ DÀI LỆCH NHAU TỚI 3 LẦN: 0.60s · 1.14s · 1.58s · 1.65s (đã đo). Bốc ngẫu nhiên
	     giữa chúng nghĩa là mỗi bước chân dài ngắn khác hẳn nhau — tai nghe ra ngay là "bốc
	     mẫu lung tung" chứ không phải một chất liệu. Tệ hơn: ở nhịp chạy 14 bước/giây, một
	     mẫu 1.65s chồng lên hơn 20 bước sau nó ⇒ nhoè thành tiếng ồn ướt liên tục.

	Bộ mới: 6 mẫu **0.17–0.22s**, chênh nhau đúng 0.05s, cùng chất "bóp kẹo dẻo bằng tay" —
	ngắn nên mỗi bước là một tiếng dứt khoát, đều nhau nên nghe ra CÙNG MỘT chất liệu, mà vẫn
	đủ 6 biến thể để không lặp máy móc (yêu cầu này đã chốt: KHÔNG dùng một mẫu duy nhất).

	Cố ý CHỪA `SquishHand5` (133081811995754): sàn Clay đang dùng làm mẫu chính, để lại thì
	hai zone vẫn phân biệt được.
]]
local STEP_SOUNDS = {
	105798502378436, -- SquishHand1 · 0.20s
	126425746730419, -- SquishHand2 · 0.22s
	131103233341950, -- SquishHand3 · 0.22s
	106681131400540, -- SquishHand4 · 0.19s
	132382300663275, -- SquishHand7 · 0.18s
	90277559933635, -- SquishHand9 · 0.17s
}
GummySquish.soundIds = STEP_SOUNDS

-- ── mạng lò xo ──
local DENT_R = 11.0 -- bán kính vùng chân đè (studs)
local DENT_DEPTH = 1.6 -- độ lún tại tâm (studs)
local SPRING_K = 150 -- lò xo về target/vị trí nghỉ
local SPRING_D = 5.2 -- giảm chấn (dưới tới hạn → dập dềnh 3-4 nhịp)
local COUPLE_C = 180 -- liên kết 4 ô kề = tốc độ lan sóng
local LAND_KICK = 14.0 -- xung bơm vào sàn khi tiếp đất (nhân theo vận tốc rơi)
local MAX_DT = 1 / 30 -- kẹp bước tích phân (frame hitch không làm nổ sóng)

-- ── biên độ hình học ──
local MAX_DOWN = 0.85 -- lún tối đa (tỉ lệ chiều cao ô)
local MAX_UP = 0.55 -- phồng tối đa
local BULGE = 0.16 -- phình ngang khi lún (mép ô ép ra)
local TILT = 0.07 -- hệ số nghiêng theo gradient sóng (radian/stud)

-- ── ngưỡng ngủ / ghi ──
local SLEEP_DISP = 0.012
local SLEEP_VEL = 0.05
local SPREAD_EPS = 0.035 -- |lệch| vượt mức này thì đánh thức 4 ô kề (sóng tiếp tục lan)
local WRITE_EPS = 0.01 -- lệch nhỏ hơn thì khỏi ghi part
local MAX_ACTIVE = 900

-- ── phát hiện chân ──
local FOOT_DROP = 3.0 -- root.Y − 3.0 ≈ cao độ bàn chân
local Y_TOL = 5.0
local CULL_DIST = 110
local STRIDE_MIN = 2.4
local STRIDE_DIV = 14
local MAX_STEP_RATE = 14

local COLOR_DEEP = Color3.fromRGB(186, 34, 116) -- ô lún sâu ngả đậm
local COLOR_RIM = Color3.fromRGB(255, 232, 246) -- ô phồng bật sáng

function GummySquish.attach(model, engine)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }

	local dentR = tonumber(model:GetAttribute("DentRadius")) or DENT_R
	local dentDepth = tonumber(model:GetAttribute("DentDepth")) or DENT_DEPTH
	local coupleC = tonumber(model:GetAttribute("Wave")) or COUPLE_C
	local landKick = tonumber(model:GetAttribute("Bounce")) or LAND_KICK

	-- lưới: mảng phẳng idx = i * nz + j (i theo X, j theo Z), 0-based
	local nx, nz = 0, 0
	local px, pz = 1, 1
	local x0, z0 = 0, 0
	local tiles: { BasePart } = {}
	local restCF: { CFrame } = {}
	local restSize: { Vector3 } = {}
	local restColor: { Color3 } = {}
	local bottomY: { number } = {}
	local height = 1
	local disp: { number } = {}
	local vel: { number } = {}
	local written: { number } = {}

	-- active set: mảng số nguyên + bảng đánh dấu (không string key → 0 alloc/frame)
	local activeIdx: { number } = {}
	local isActive: { [number]: boolean } = {}
	local pending: { number } = {}
	local pendingN = 0

	local box, walkTop
	local cullCenter, cullReach
	local anyActive = false

	local function wake(idx: number)
		if not isActive[idx] and #activeIdx + pendingN < MAX_ACTIVE then
			isActive[idx] = true
			pendingN += 1
			pending[pendingN] = idx
		end
	end

	task.spawn(function()
		local folder = model:WaitForChild("Tiles", 10)
		local collider = model:WaitForChild("Collider", 10)
		if not (folder and collider and collider:IsA("BasePart")) then
			return
		end
		engine.Await.childrenStable(folder)

		local list: { BasePart } = {}
		local minX, maxX = math.huge, -math.huge
		local minZ, maxZ = math.huge, -math.huge
		for _, t in folder:GetChildren() do
			if t:IsA("BasePart") then
				table.insert(list, t)
				minX = math.min(minX, t.Position.X)
				maxX = math.max(maxX, t.Position.X)
				minZ = math.min(minZ, t.Position.Z)
				maxZ = math.max(maxZ, t.Position.Z)
			end
		end
		if #list == 0 then
			return
		end

		local first = list[1]
		px, pz = first.Size.X, first.Size.Z
		height = first.Size.Y
		x0, z0 = minX, minZ
		nx = math.max(math.floor((maxX - minX) / px + 0.5), 0)
		nz = math.max(math.floor((maxZ - minZ) / pz + 0.5), 0)

		for _, t in list do
			local i = math.floor((t.Position.X - x0) / px + 0.5)
			local j = math.floor((t.Position.Z - z0) / pz + 0.5)
			local idx = i * (nz + 1) + j
			tiles[idx] = t
			restCF[idx] = t.CFrame
			restSize[idx] = t.Size
			restColor[idx] = t.Color
			bottomY[idx] = t.Position.Y - t.Size.Y / 2
			disp[idx] = 0
			vel[idx] = 0
			written[idx] = 0
		end

		walkTop = collider.Position.Y + collider.Size.Y / 2
		box = Bounds.ofBase(collider, 4)
		if box then
			cullCenter = Vector3.new(box.cx, box.topY, box.cz)
			cullReach = CULL_DIST + math.max(box.halfX, box.halfZ)
		end

		self.ready = box ~= nil
		if self.ready then
			Log.Floor("GummySquish", #list)
		end
	end)

	local function render(idx: number, d: number)
		local part = tiles[idx]
		if not part then
			return
		end
		local rs = restSize[idx]
		-- d > 0 = lún xuống; d < 0 = phồng lên. Đáy ô neo cố định.
		local sy = math.clamp(1 - d / height, 1 - MAX_DOWN, 1 + MAX_UP)
		-- CHỈ phình ra khi lún, không bao giờ co lại: ô co ngang sẽ hở khe lộ sàn bên dưới
		local lateral = 1 + BULGE * math.clamp(d / height, 0, 1)
		local newH = rs.Y * sy
		part.Size = Vector3.new(rs.X * lateral, newH, rs.Z * lateral)

		-- nghiêng theo gradient mặt sóng: bề mặt mềm, không lộ dạng ô vuông
		local i = idx // (nz + 1)
		local j = idx % (nz + 1)
		local gx, gz = 0, 0
		if i > 0 and i < nx then
			gx = ((disp[idx + (nz + 1)] or 0) - (disp[idx - (nz + 1)] or 0)) * 0.5
		end
		if j > 0 and j < nz then
			gz = ((disp[idx + 1] or 0) - (disp[idx - 1] or 0)) * 0.5
		end
		local rot = restCF[idx].Rotation * CFrame.Angles(-gz * TILT, 0, gx * TILT)
		part.CFrame = CFrame.new(restCF[idx].X, bottomY[idx] + newH / 2, restCF[idx].Z) * rot

		-- vệt sáng: lún → đậm, phồng → rim sáng
		local base = restColor[idx]
		if d > 0 then
			part.Color = base:Lerp(COLOR_DEEP, math.clamp(d / dentDepth, 0, 1) * 0.7)
		elseif d < 0 then
			part.Color = base:Lerp(COLOR_RIM, math.clamp(-d / (dentDepth * 0.6), 0, 1) * 0.85)
		else
			part.Color = base
		end
	end

	local function resetAll()
		for idx, part in tiles do
			if written[idx] ~= 0 then
				written[idx] = 0
				disp[idx] = 0
				vel[idx] = 0
				part.Size = restSize[idx]
				part.CFrame = restCF[idx]
				part.Color = restColor[idx]
			end
		end
		table.clear(activeIdx)
		table.clear(isActive)
		pendingN = 0
	end

	local lastStepT = 0
	local function playStep(pos: Vector3, now: number, volume: number, pitchBias: number)
		if now - lastStepT < 1 / MAX_STEP_RATE then
			return
		end
		lastStepT = now
		if not FxBudget.fxOK(pos) then
			return
		end
		SoundPool.playStep(
			STEP_SOUNDS[math.random(#STEP_SOUNDS)],
			pos,
			volume,
			(0.88 + math.random() * 0.2) * pitchBias,
			80
		)
	end

	local onFloor = false
	local stepLast: Vector3? = nil
	local stepDist = 0
	local lastProbeT = 0

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		-- cull cả sàn: ngoài tầm nhìn → về nghỉ một lần rồi ngủ hẳn
		if not FxBudget.nearCamera(cullCenter, cullReach) then
			if anyActive then
				resetAll()
				anyActive = false
			end
			onFloor = false
			return
		end

		local footPos: Vector3? = nil
		local landVy = 0
		if foot then
			local pos = foot.pos
			if Bounds.contains(box, pos) and math.abs((pos.Y - FOOT_DROP) - walkTop) < Y_TOL then
				footPos = pos
				if not onFloor then
					onFloor = true
					stepLast, stepDist = pos, 0
					landVy = math.clamp(math.abs(foot.vel.Y), 0, 70)
					playStep(pos, now, 0.55 + 0.35 * (landVy / 70), 0.92)
				end
				if stepLast then
					local d = pos - stepLast
					stepDist += Vector3.new(d.X, 0, d.Z).Magnitude
				end
				stepLast = pos
				local speed = Vector3.new(foot.vel.X, 0, foot.vel.Z).Magnitude
				if stepDist >= math.max(STRIDE_MIN, speed / STRIDE_DIV) then
					stepDist = 0
					playStep(pos, now, 0.5, 1)
				end
			else
				onFloor = false
			end
		else
			onFloor = false
		end

		if footPos == nil and #activeIdx == 0 then
			anyActive = false
			return
		end
		anyActive = true

		local h = math.min(dt, MAX_DT)
		local r2 = dentR * dentR

		-- 1) đánh thức vùng quanh chân (+ xung tiếp đất)
		if footPos then
			local iMin = math.max(math.floor((footPos.X - dentR - x0) / px), 0)
			local iMax = math.min(math.ceil((footPos.X + dentR - x0) / px), nx)
			local jMin = math.max(math.floor((footPos.Z - dentR - z0) / pz), 0)
			local jMax = math.min(math.ceil((footPos.Z + dentR - z0) / pz), nz)
			for i = iMin, iMax do
				for j = jMin, jMax do
					local idx = i * (nz + 1) + j
					if tiles[idx] then
						local dx = x0 + i * px - footPos.X
						local dz = z0 + j * pz - footPos.Z
						local d2 = dx * dx + dz * dz
						if d2 < r2 then
							wake(idx)
							if landVy > 0 then
								local w = 1 - d2 / r2
								vel[idx] += landKick * (landVy / 70) * w * w
							end
						end
					end
				end
			end
		end

		-- gộp danh sách chờ vào active set (không sửa mảng khi đang duyệt)
		for k = 1, pendingN do
			table.insert(activeIdx, pending[k])
		end
		pendingN = 0

		-- 2) tích phân mạng lò xo + ghi hình. Duyệt ngược để swap-remove ô ngủ tại chỗ.
		local n = #activeIdx
		for k = n, 1, -1 do
			local idx = activeIdx[k]
			local i = idx // (nz + 1)
			local j = idx % (nz + 1)

			local target = 0
			if footPos then
				local dx = x0 + i * px - footPos.X
				local dz = z0 + j * pz - footPos.Z
				local d2 = dx * dx + dz * dz
				if d2 < r2 then
					local w = 1 - d2 / r2
					target = dentDepth * w * w
				end
			end

			-- laplacian 4 ô kề → sóng lan ngang
			local dc = disp[idx]
			local sum, cnt = 0, 0
			if i > 0 then
				local a = disp[idx - (nz + 1)]
				if a then
					sum += a
					cnt += 1
				end
			end
			if i < nx then
				local a = disp[idx + (nz + 1)]
				if a then
					sum += a
					cnt += 1
				end
			end
			if j > 0 then
				local a = disp[idx - 1]
				if a then
					sum += a
					cnt += 1
				end
			end
			if j < nz then
				local a = disp[idx + 1]
				if a then
					sum += a
					cnt += 1
				end
			end
			local lap = if cnt > 0 then sum / cnt - dc else 0

			local v = vel[idx] + (SPRING_K * (target - dc) + coupleC * lap - SPRING_D * vel[idx]) * h
			local d = math.clamp(dc + v * h, -height * MAX_UP, height * MAX_DOWN)
			vel[idx] = v
			disp[idx] = d

			if math.abs(d - written[idx]) > WRITE_EPS then
				written[idx] = d
				render(idx, d)
			end

			if target == 0 and math.abs(d) < SLEEP_DISP and math.abs(v) < SLEEP_VEL then
				disp[idx] = 0
				vel[idx] = 0
				if written[idx] ~= 0 then
					written[idx] = 0
					render(idx, 0)
				end
				isActive[idx] = nil
				activeIdx[k] = activeIdx[#activeIdx]
				activeIdx[#activeIdx] = nil
			elseif math.abs(d) > SPREAD_EPS then
				-- sóng đủ mạnh → kéo 4 ô kề vào cuộc
				if i > 0 and tiles[idx - (nz + 1)] then
					wake(idx - (nz + 1))
				end
				if i < nx and tiles[idx + (nz + 1)] then
					wake(idx + (nz + 1))
				end
				if j > 0 and tiles[idx - 1] then
					wake(idx - 1)
				end
				if j < nz and tiles[idx + 1] then
					wake(idx + 1)
				end
			end
		end

		-- ô mới đánh thức trong vòng này bắt đầu chạy từ frame sau
		for k = 1, pendingN do
			table.insert(activeIdx, pending[k])
		end
		pendingN = 0

		-- QA hook: số ô đang mô phỏng (throttle 0.5s — đây là cách duy nhất quan sát
		-- trạng thái mạng lò xo từ ngoài adapter)
		if now - lastProbeT > 0.5 then
			lastProbeT = now
			if model:GetAttribute("GSActive") ~= #activeIdx then
				model:SetAttribute("GSActive", #activeIdx)
			end
		end
	end

	function self.destroy()
		resetAll()
	end

	return self
end

return GummySquish
