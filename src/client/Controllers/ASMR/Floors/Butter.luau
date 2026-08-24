--!strict
-- Butter — 🧈 SÀN BƠ LÚN (Zone 14, thay sàn GummySquish).
--
-- Nguồn: pack "ASMR Butter" (LocalScript rời + model StandardButter). Bản này KHÔNG chép
-- nguyên pack: nó được viết lại thành adapter của ASMR Engine và sửa ba thứ.
--
-- ===== 1. GỠ TÍNH NĂNG LÀM CHẬM (yêu cầu user) =====
-- Pack gốc kẹp `humanoid.WalkSpeed = min(WalkSpeed, 10)` khi đứng trên bơ rồi trả lại khi rời
-- sàn. Trong +1 Speed Escape đó là lỗi chí mạng chứ không phải "chất liệu": cả game bán tốc
-- độ, cái kẹp đó ghi đè WalkSpeed do ProgressionService cấp — người chơi 250 WS bước lên sàn
-- là tụt về 10. Tệ hơn, pack khôi phục bằng biến `savedWalkSpeed` chụp MỘT LẦN lúc bước vào:
-- nếu server đổi tốc độ giữa chừng (level-up, rebirth, hết boost) thì lúc rời sàn nó trả lại
-- con số CŨ ĐÃ CHẾT. Ở đây adapter KHÔNG chạm vào Humanoid, một dòng cũng không.
--
-- ===== 2. `MeshPart.Size` KHÔNG PHÓNG TO SKINNED MESH — LƯỚI BONE MỚI LÀ CỠ THẬT =====
-- Bơ là MeshPart skinned: 48 Bone (lưới 12 × 4 trên mặt trên) kéo mặt bơ lún xuống.
-- Thí nghiệm đối chứng trong Studio 2026-08-13 (3 bản sao cạnh nhau, cùng khoảng cách
-- camera, mỗi bản đặt trên một tấm Neon đỏ đúng cỡ mong muốn):
--     A) Size ×1, bone ×1  → bơ cỡ gốc
--     B) Size ×5, bone ×1  → bơ VẪN CỠ GỐC. Gán Size không đổi được một pixel nào.
--     C) Size ×1, bone ×5  → bơ phủ kín tấm đỏ ×5, hình dạng và decal đều đẹp.
-- ⇒ Với MeshPart skinned, hình nhìn thấy do RIG BONE quyết định; `Size` chỉ còn là hộp bao
--   (bounding box, collision, streaming). Muốn khối bơ to gấp k lần thì phải NHÂN
--   `Bone.Position` lên k (đã làm sẵn lúc dựng map), rồi đặt `Size` khớp theo cho hộp bao đúng.
-- Hệ quả cho file này: **toạ độ bone là studs THẬT**, không có hệ quy chiếu "bind space" nào
-- phải quy đổi. Lún sâu D studs = dời bone đúng D. Cỡ khối cũng đọc thẳng từ span của lưới
-- bone (đáng tin hơn `Size`, vì `Size` có thể bị đặt sai mà không ai thấy).
--
-- ===== 3. KHÔNG CÓ VA CHẠM — ĐÚNG QUY ƯỚC SÀN ASMR CỦA ZONE =====
-- Pack gốc dựng một tấm `ButterCollision` CanCollide rồi hạ nó xuống theo vết lún. Ở đây
-- KHÔNG làm thế: `Collider` của sàn gum Zone 14 vốn đã `CanCollide = false` — mặt đi thật là
-- nền Obby ở Y=220, còn sàn ASMR chỉ là lớp trang trí cao hơn để chân LÚN VÀO trông thấy.
-- Dựng thêm tấm va chạm biết chìm sẽ tạo bậc thềm giữa các khối, mà ở 200+ WS bậc thềm là
-- nguồn vấp. `Collider` (nếu có) ở đây chỉ dùng làm mốc cao độ mặt đi + bounding box.
--
-- ===== HỢP ĐỒNG ENGINE =====
-- Model tag `ASMRFloor` + attribute FloorType="Butter", nên để ModelStreamingMode = Atomic.
--   • `Blocks` (Folder) — các MeshPart bơ, mỗi khối có `Root` (Bone).
--   • `Collider` (BasePart, tuỳ chọn) — mốc cao độ mặt đi, giống hệt sàn gum.
-- Attribute tinh chỉnh trên model: `DentRadius`, `DentDepth` (studs THẬT, không phải bind).
--
-- Hiệu năng: mỗi frame chỉ khối nằm trong `dentR + bán kính khối` mới được duyệt; khối đã về
-- nghỉ thì bỏ qua hẳn. Cả sàn ra ngoài 110 studs camera → reset đúng một lần rồi ngủ.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local Butter = {}

--[[
	HAI VAI TRÒ ÂM THANH, KHÔNG PHẢI MỘT BỘ (2026-08-13).

	Đã ĐO thời lượng từng id trong Studio (không suy từ tên): tiếng bơ gốc của pack dài **1.75s**,
	còn cụm mẫu bổ sung nằm gọn trong **0.44–0.58s**. Chênh nhau 3–4 lần, và đây đúng là cái bẫy
	mà `GummySquish` đã ghi lại: bốc ngẫu nhiên giữa các mẫu dài ngắn khác hẳn nhau thì tai nghe
	ra ngay "bốc mẫu lung tung" chứ không phải một chất liệu. Tệ hơn, ở nhịp chạy 14 bước/giây
	một mẫu 1.75s chồng lên hơn 20 bước sau nó ⇒ nhoè thành tiếng ồn ướt liên tục.

	Nên KHÔNG trộn chung. Chia vai:

	  • `STEP_SOUNDS` (5 mẫu, 0.44–0.58s) — tiếng BƯỚC CHÂN khi chạy. Đều nhau nên nghe ra cùng
	    một chất liệu, ngắn nên mỗi bước là một tiếng dứt khoát, 5 biến thể + pitch ngẫu nhiên
	    nên không lặp máy móc.
	  • `ENTER_SOUND` — chính là tiếng bơ GỐC của pack, GIỮ NGUYÊN theo yêu cầu user. Nó dài và
	    có đặc trưng riêng nên hợp làm tiếng "lún ngập vào bơ" lúc ĐẶT CHÂN LÊN và lúc RỜI sàn:
	    mỗi lượt vào/ra chỉ kêu một lần (kèm `ENTER_MIN_GAP` chống spam ở mép sàn), nên cái đuôi
	    1.75s không bao giờ chồng lên chính nó.
]]
local ENTER_SOUND = 119687340156238 -- "Butter Sound" — mẫu gốc của pack, 1.75s
local STEP_SOUNDS = {
	87295773843957, -- SLIME SQUISHY 1 · 0.48s
	128710847750782, -- SLIME SQUISHY 2 · 0.46s
	108574512542351, -- mud_puddle_step_05 · 0.44s
	18640080812, -- walk_mud_sticky_13 · 0.55s
	6441160246, -- mud footstep · 0.58s
}
-- Engine preload + warm theo danh sách này, nên PHẢI có đủ cả mẫu vào/ra.
Butter.soundIds = { ENTER_SOUND, 87295773843957, 128710847750782, 108574512542351, 18640080812, 6441160246 }
-- 5 id luân phiên × 4 giọng mặc định = 20 giọng thật cho bước chân — thừa sức ở 14 bước/giây.
-- Chỉ mẫu vào/ra cần khai riêng: nó dài 1.75s nên đuôi tiếng sống lâu hơn nhịp vào/ra nhiều.
Butter.voices = { [ENTER_SOUND] = 6 }
local ENTER_MIN_GAP = 0.9

-- ── hình học vết lún (đơn vị: studs THẬT trên map) ──
-- Chỉnh sau khi ĐO trên khối đã phóng 5.34× (2026-08-13): lưới bone thưa 4.6 × 7.9 studs nên
-- bone gần chân nhất vẫn có thể cách 2–4 studs. Với falloff mũ 2 và depth 1.5, vết lún thật đo
-- được chỉ 0.99 stud — nhìn gần như phẳng. Nới sâu + làm mềm số mũ để vết chân đọc được.
-- ⚠️ TRẦN ĐỘ SÂU: đây là sàn lún bằng DỊCH CHUYỂN (bone đi xuống), không phải co tỉ lệ, nên
-- nó có thể chọc thủng mặt đất — đúng loại lỗi mà Engine/GroundLimit nói tới. Ở Zone 14 bơ nhô
-- 2.6 studs trên nền (đỉnh 222.6, nền 220), trừ CLEARANCE 0.15 ⇒ **tối đa 2.45**. Muốn sâu hơn
-- thì phải nâng đỉnh khối bơ trước, đừng nâng riêng con số này.
local DENT_RADIUS = 13.0
local DENT_DEPTH = 2.2
local DENT_FALLOFF = 1.6 -- số mũ tắt dần: lòng chảo mềm, không thành hố vách đứng
local PRESS_SPEED = 9.0 -- ép xuống nhanh
local RELEASE_SPEED = 1.2 -- nhả lên CHẬM — đây chính là cảm giác "bơ", đừng tăng

-- ── phát hiện chân (đồng bộ với GummySquish để bước chân cả zone giống nhau) ──
local FOOT_DROP = 3.0
local Y_TOL = 5.0
local CULL_DIST = 110
local STRIDE_MIN = 2.4
local STRIDE_DIV = 14
local MAX_STEP_RATE = 14

local WRITE_EPS = 0.004 -- lệch nhỏ hơn thì khỏi ghi bone (tránh re-skin vô ích)
local SLEEP_EPS = 0.002 -- dưới ngưỡng này coi như đã về nghỉ

type Block = {
	surface: MeshPart,
	bones: { Bone },
	rest: { Vector3 }, -- toạ độ nghỉ (studs, local theo part), cùng chỉ số với `bones`
	worldXZ: { Vector2 }, -- toạ độ XZ thật của từng bone (bất biến vì khối đứng yên)
	offset: { number }, -- độ lún hiện tại của từng bone, studs (âm = lún)
	written: { number },
	cx: number,
	cz: number,
	reachSq: number, -- (bán kính khối + dentR)²: ngoài tầm này khối không thể bị chạm
	asleep: boolean,
}

function Butter.attach(model, engine)
	local FxBudget, SoundPool, Bounds = engine.FxBudget, engine.SoundPool, engine.Bounds
	local self = { ready = false }

	local dentR = tonumber(model:GetAttribute("DentRadius")) or DENT_RADIUS
	local dentDepth = tonumber(model:GetAttribute("DentDepth")) or DENT_DEPTH

	local blocks: { Block } = {}
	local box, walkTop
	local cullCenter, cullReach
	local anyActive = false

	task.spawn(function()
		local folder = model:WaitForChild("Blocks", 10)
		if not folder then
			return
		end
		engine.Await.childrenStable(folder)

		local surfaces: { Instance } = {}
		for _, surface in folder:GetChildren() do
			if not surface:IsA("MeshPart") then
				continue
			end
			local root = surface:FindFirstChild("Root")
			if not root then
				continue
			end

			local bones: { Bone } = {}
			for _, b in root:GetDescendants() do
				if b:IsA("Bone") then
					table.insert(bones, b)
				end
			end
			if #bones == 0 then
				continue
			end

			-- Cỡ khối đọc từ span lưới bone (bone phủ đúng mép mặt trên), KHÔNG đọc từ `Size`:
			-- xem khối (2) ở đầu file — `Size` không quyết định hình nhìn thấy.
			local minX, maxX = math.huge, -math.huge
			local minZ, maxZ = math.huge, -math.huge
			local cf = surface.CFrame

			local rest, worldXZ, offset, written = {}, {}, {}, {}
			for i, b in bones do
				local p = b.Position
				rest[i] = p
				minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
				minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
				local w = cf:PointToWorldSpace(p)
				worldXZ[i] = Vector2.new(w.X, w.Z)
				offset[i] = 0
				written[i] = 0
			end
			local spanX, spanZ = maxX - minX, maxZ - minZ
			if spanX <= 0 or spanZ <= 0 then
				warn("[ASMR Butter] rig bone suy biến:", surface:GetFullName())
				continue
			end

			-- Mesh không va chạm: collision hull của MeshPart đứng yên khi bone lún, để nó
			-- CanCollide thì người chơi đứng trên một mặt phẳng vô hình cao hơn vết lún.
			surface.CanCollide = false

			local blockReach = dentR + Vector3.new(spanX, 0, spanZ).Magnitude * 0.5
			table.insert(blocks, {
				surface = surface,
				bones = bones,
				rest = rest,
				worldXZ = worldXZ,
				offset = offset,
				written = written,
				cx = cf.Position.X,
				cz = cf.Position.Z,
				reachSq = blockReach * blockReach,
				asleep = true,
			})
			table.insert(surfaces, surface)
		end

		if #blocks == 0 then
			return
		end

		box = Bounds.ofParts(surfaces, 4)
		if box then
			-- Mặt đi THẬT thấp hơn đỉnh bơ (chân ngập vào bơ). Mốc lấy từ `Collider` giống sàn
			-- gum; không có thì tạm lấy đỉnh bơ — Y_TOL đủ rộng để vẫn bắt được chân.
			local collider = model:FindFirstChild("Collider")
			walkTop = if collider and collider:IsA("BasePart")
				then collider.Position.Y + collider.Size.Y / 2
				else box.topY
			cullCenter = Vector3.new(box.cx, box.topY, box.cz)
			cullReach = CULL_DIST + math.max(box.halfX, box.halfZ)
		end

		self.ready = box ~= nil
		if self.ready then
			Log.Floor("Butter", #blocks, model)
		end
	end)

	local function renderBlock(blk: Block)
		local bones, rest, written, offset = blk.bones, blk.rest, blk.written, blk.offset
		for i = 1, #bones do
			local cur = offset[i]
			if math.abs(cur - written[i]) > WRITE_EPS then
				written[i] = cur
				local r = rest[i]
				bones[i].Position = Vector3.new(r.X, r.Y + cur, r.Z)
			end
		end
	end

	local function restBlock(blk: Block)
		if blk.asleep then
			return
		end
		for i = 1, #blk.bones do
			blk.offset[i] = 0
		end
		renderBlock(blk)
		blk.asleep = true
	end

	local function resetAll()
		for _, blk in blocks do
			restBlock(blk)
		end
	end

	local lastStepT = 0
	local function playStep(pos: Vector3, now: number, volume: number, pitch: number)
		if now - lastStepT < 1 / MAX_STEP_RATE then
			return
		end
		lastStepT = now
		if not FxBudget.fxOK(pos) then
			return
		end
		SoundPool.playStep(STEP_SOUNDS[math.random(#STEP_SOUNDS)], pos, volume, pitch, 80)
	end

	-- Tiếng bơ gốc lúc vào/ra sàn. CỐ Ý không dùng chung đồng hồ `lastStepT` với bước chân:
	-- đây là sự kiện chuyển trạng thái, bị một tiếng bước chân vừa kêu nuốt mất là hỏng.
	local lastEnterT = -math.huge
	local function playEnter(pos: Vector3, now: number, volume: number, pitch: number)
		if now - lastEnterT < ENTER_MIN_GAP then
			return
		end
		lastEnterT = now
		if not FxBudget.fxOK(pos) then
			return
		end
		SoundPool.playStep(ENTER_SOUND, pos, volume, pitch, 90)
	end

	local onFloor = false
	local stepLast: Vector3? = nil
	local stepDist = 0

	function self.update(dt, now, foot)
		if not self.ready then
			return
		end

		if not FxBudget.nearCamera(cullCenter, cullReach) then
			if anyActive then
				resetAll()
				anyActive = false
			end
			onFloor = false
			return
		end

		local footPos: Vector3? = nil
		if foot then
			local pos = foot.pos
			if Bounds.contains(box, pos) and math.abs((pos.Y - FOOT_DROP) - walkTop) < Y_TOL then
				footPos = pos
				if not onFloor then
					onFloor = true
					stepLast, stepDist = pos, 0
					-- ĐẶT CHÂN LÊN BƠ: tiếng gốc, rơi càng mạnh càng to và càng trầm.
					local landVy = math.clamp(math.abs(foot.vel.Y), 0, 70)
					playEnter(pos, now, 0.55 + 0.35 * (landVy / 70), 0.9 - 0.06 * (landVy / 70))
				end
				if stepLast then
					local d = pos - stepLast
					stepDist += Vector3.new(d.X, 0, d.Z).Magnitude
				end
				stepLast = pos
				local speed = Vector3.new(foot.vel.X, 0, foot.vel.Z).Magnitude
				if stepDist >= math.max(STRIDE_MIN, speed / STRIDE_DIV) then
					stepDist = 0
					playStep(pos, now, 0.5, 0.96 + math.random() * 0.12)
				end
			elseif onFloor then
				-- RỜI BƠ: cùng mẫu gốc nhưng cao hơn — nghe như chân rút ra khỏi khối bơ.
				onFloor = false
				playEnter(stepLast or pos, now, 0.45, 1.06)
			end
		elseif onFloor then
			onFloor = false
		end

		local footX, footZ = 0, 0
		if footPos then
			footX, footZ = footPos.X, footPos.Z
		end
		local anyAwake = false

		for _, blk in blocks do
			-- Khối ở xa chân VÀ đã về nghỉ ⇒ bỏ qua hoàn toàn (không đọc, không ghi).
			local touched = false
			if footPos then
				local dx, dz = footX - blk.cx, footZ - blk.cz
				touched = dx * dx + dz * dz <= blk.reachSq
			end
			if not touched and blk.asleep then
				continue
			end

			local maxAbs = 0
			for i = 1, #blk.bones do
				local target = 0
				if touched then
					local w = blk.worldXZ[i]
					local dx, dz = w.X - footX, w.Y - footZ
					local d = math.sqrt(dx * dx + dz * dz)
					if d < dentR then
						target = -dentDepth * (1 - d / dentR) ^ DENT_FALLOFF
					end
				end
				local cur = blk.offset[i]
				local rate = target < cur and PRESS_SPEED or RELEASE_SPEED
				cur += (target - cur) * math.min(1, rate * dt)
				if target == 0 and math.abs(cur) < SLEEP_EPS then
					cur = 0
				end
				blk.offset[i] = cur
				maxAbs = math.max(maxAbs, math.abs(cur))
			end

			renderBlock(blk)
			blk.asleep = not touched and maxAbs < SLEEP_EPS
			anyAwake = anyAwake or not blk.asleep
		end

		anyActive = anyAwake
	end

	function self.destroy()
		resetAll()
	end

	return self
end

return Butter
