--!nocheck
-- Unit test cho phần LOGIC THUẦN của game: đường cong XP, trần WalkSpeed, hệ số
-- rebirth, bảng weight Roulette, tính nhất quán của catalog kinh tế.
--
-- Chạy: lune run tests/run.luau  (không cần mở Roblox Studio)
--
-- Phạm vi: chỉ những gì tính được bằng số. Mọi thứ chạm Instance/DataStore/Touched
-- nằm ngoài đây và thuộc về checklist trong Studio (docs/REGRESSION.md).

local process = require("@lune/process")

local Shim = require("./roblox")

local Formulas = Shim.Require("src/shared/Config/Formulas.luau")
local Tuning = Shim.Require("src/shared/Config/Tuning.luau")
local Stages = Shim.Require("src/shared/Config/Stages.luau")
local Roulette = Shim.Require("src/shared/Config/Roulette.luau")
local Trails = Shim.Require("src/shared/Config/Economy/Trails.luau")
local Auras = Shim.Require("src/shared/Config/Economy/Auras.luau")
local Treadmills = Shim.Require("src/shared/Config/Economy/Treadmills.luau")
local Format = Shim.Require("src/shared/Util/Format.luau")
local MovementConfig = Shim.Require("src/client/Controllers/Movement/MovementConfig.luau")
local MovementMath = Shim.Require("src/client/Controllers/Movement/MovementMath.luau")

local passed = 0
local failures: { string } = {}
local currentSuite = "?"

local function suite(name: string)
	currentSuite = name
end

local function check(label: string, ok: boolean, detail: string?)
	if ok then
		passed += 1
	else
		table.insert(failures, `[{currentSuite}] {label}{if detail then ` — {detail}` else ""}`)
	end
end

local function equals(label: string, actual: any, expected: any)
	check(label, actual == expected, `nhận {tostring(actual)}, cần {tostring(expected)}`)
end

local function isFinite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

--------------------------------------------------------------------------------
suite("Đường cong XP")

equals("GetRequiredXP(0) = 0", Formulas.GetRequiredXP(0), 0)
equals("GetRequiredXP(-5) = 0", Formulas.GetRequiredXP(-5), 0)

-- Hai mốc neo lấy từ game mẫu — nếu đổi công thức mà quên cập nhật thì gãy ở đây.
equals("neo Lv67 = 1.01M", Formulas.GetRequiredXP(Formulas.XP_CURVE_ANCHOR_LEVEL), 1_010_000)
equals("neo Lv68 = 1.17M", Formulas.GetRequiredXP(Formulas.XP_CURVE_ANCHOR_LEVEL + 1), 1_170_000)

do
	local strictlyIncreasing = true
	local allFinite = true
	local previous = Formulas.GetRequiredXP(1)
	for level = 2, 500 do
		local required = Formulas.GetRequiredXP(level)
		if not isFinite(required) then
			allFinite = false
			break
		end
		if required <= previous then
			strictlyIncreasing = false
			break
		end
		previous = required
	end
	check("tăng đơn điệu Lv1→500", strictlyIncreasing)
	check("không tràn số tới Lv500", allFinite)
end

do
	-- Rebirth mở khoá ở Lv50; cột mốc này phải còn nằm trong tầm với, không phải
	-- con số thiên văn do công thức bị chỉnh nhầm.
	local requiredAt50 = Formulas.GetRequiredXP(50)
	check("Lv50 dưới 100K Speed", requiredAt50 < 100_000, `nhận {requiredAt50}`)
	check("Lv50 trên 1K Speed", requiredAt50 > 1_000, `nhận {requiredAt50}`)
end

--------------------------------------------------------------------------------
suite("Trần WalkSpeed")

equals("Lv1 = BASE_MAX_WALK_SPEED", Formulas.GetMaxWalkSpeed(1), Tuning.BASE_MAX_WALK_SPEED)
equals("Lv0 không âm", Formulas.GetMaxWalkSpeed(0), Tuning.BASE_MAX_WALK_SPEED)

do
	local monotonic = true
	local capped = true
	local previous = Formulas.GetMaxWalkSpeed(1)
	for level = 2, 1000 do
		local speed = Formulas.GetMaxWalkSpeed(level)
		if speed < previous then
			monotonic = false
		end
		if speed > 250 then
			capped = false
		end
		previous = speed
	end
	check("không giảm khi lên level", monotonic)
	check("luôn bị kẹp ở 250", capped)
	equals("Lv1000 chạm đúng trần 250", Formulas.GetMaxWalkSpeed(1000), 250)
end

do
	-- Biển stage ghi "Recommend: WS x". Nếu x vượt trần 250 thì gợi ý đó vĩnh viễn
	-- không đạt được — lỗi cân bằng thật, không phải lỗi hiển thị.
	local unreachable = {}
	for stage = 1, Stages.MAX_CONFIGURED_STAGE do
		local gate = Stages.STAGE_GATES[stage]
		if gate and gate.minWS > 250 then
			table.insert(unreachable, `stage {stage} cần WS {gate.minWS}`)
		end
	end
	check(
		"mọi gợi ý WS của stage 1-15 đều đạt được",
		#unreachable == 0,
		table.concat(unreachable, ", ")
	)
end

--------------------------------------------------------------------------------
suite("Rebirth")

equals("0 rebirth = hệ số 1", Formulas.GetRebirthMultiplier(0), 1)
equals("1 rebirth = 1.5", Formulas.GetRebirthMultiplier(1), 1.5)
equals("10 rebirth = 6", Formulas.GetRebirthMultiplier(10), 6)
equals("rebirth đầu cần Lv50", Formulas.GetRequiredLevelForRebirth(0), 50)
equals("rebirth thứ 2 cần Lv60", Formulas.GetRequiredLevelForRebirth(1), 60)

do
	local monotonic = true
	for rebirths = 1, 200 do
		if Formulas.GetRequiredLevelForRebirth(rebirths) <= Formulas.GetRequiredLevelForRebirth(rebirths - 1) then
			monotonic = false
			break
		end
		if Formulas.GetRebirthMultiplier(rebirths) <= Formulas.GetRebirthMultiplier(rebirths - 1) then
			monotonic = false
			break
		end
	end
	check("yêu cầu level và hệ số đều tăng dần tới rebirth 200", monotonic)

	-- Rebirth 50 là mốc người chơi hardcore chạm tới — không được tràn float.
	check("rebirth 50 vẫn hữu hạn", isFinite(Formulas.GetRebirthMultiplier(50)))
	check("Lv yêu cầu ở rebirth 50 hữu hạn", isFinite(Formulas.GetRequiredLevelForRebirth(50)))
end

--------------------------------------------------------------------------------
suite("Roulette")

do
	local total = 0
	local ids = {}
	local duplicateId = nil
	local nonPositiveWeight = false
	local rarityMismatch = nil
	local weightsDescending = true
	local previousWeight = math.huge

	for _, slot in Roulette.SLOTS do
		total += slot.weight
		if ids[slot.id] then
			duplicateId = slot.id
		end
		ids[slot.id] = true
		if slot.weight <= 0 then
			nonPositiveWeight = true
		end
		if slot.rarity ~= `{slot.weight}%` then
			rarityMismatch = `{slot.id}: rarity "{slot.rarity}" ≠ weight {slot.weight}`
		end
		if slot.weight > previousWeight then
			weightsDescending = false
		end
		previousWeight = slot.weight
	end

	-- Tổng weight phải đúng 100 thì chuỗi rarity hiển thị mới là phần trăm thật.
	equals("tổng weight = 100", total, 100)
	check("không có id trùng", duplicateId == nil, duplicateId)
	check("mọi weight đều dương", not nonPositiveWeight)
	check("chuỗi rarity khớp weight", rarityMismatch == nil, rarityMismatch)
	-- Extra Spin gamepass chọn slot index cao hơn ⇒ index tăng thì phải hiếm dần.
	check("weight giảm dần theo index", weightsDescending)
	check("có đúng 8 ô", #Roulette.SLOTS == 8, `nhận {#Roulette.SLOTS}`)
end

equals("vé miễn phí trần 3", Roulette.FREE_TICKET_STOCK_CAP, 3)
check("trần vé tuyệt đối ≥ trần tích trữ", Roulette.MAX_TICKETS >= Roulette.FREE_TICKET_STOCK_CAP)

--------------------------------------------------------------------------------
suite("Catalog kinh tế")

local function auditCatalog(name: string, catalog: { any }, opts: { requiresPrice: boolean })
	local ids = {}
	local duplicate = nil
	local badMultiplier = nil
	local badPrice = nil
	-- Catalog chia 2 nhóm hiển thị: mua bằng Wins và premium chỉ-Robux. Mỗi nhóm
	-- phải xếp theo MỘT chiều nhất quán (tăng hoặc giảm) — zigzag mới là lỗi thật,
	-- vì người chơi đọc danh sách để đoán món nào mạnh hơn.
	local groups: { [string]: { number } } = { wins = {}, robux = {} }

	for _, item in catalog do
		if ids[item.id] then
			duplicate = item.id
		end
		ids[item.id] = true

		if type(item.multiplier) ~= "number" or item.multiplier < 1 then
			badMultiplier = `{item.id}: {tostring(item.multiplier)}`
		end
		if opts.requiresPrice and item.priceRobux and item.priceRobux < 0 then
			badPrice = `{item.id}: {item.priceRobux}`
		end

		--[[
			CHỈ xếp vào thang giá những món THỰC SỰ MUA ĐƯỢC bằng loại tiền đó.

			Phép kiểm này khẳng định một điều về TRẢI NGHIỆM MUA HÀNG: đọc danh sách từ trên
			xuống thì món đắt hơn phải mạnh hơn. Nó chỉ có nghĩa với món nằm trên quầy.

			Bản cũ chỉ loại `spinOnly` nên vẫn nhét cả quà tặng và món gamepass vào dãy Wins,
			rồi báo đỏ oan trên dữ liệu ĐÚNG:
			  • `trail_streak_aurora` (5.0) — quà điểm danh Ngày 7, `dailyOnly`
			  • `trail_rookie` (2.5)        — quà khởi đầu, cố ý đặt NGANG hạng trung
			                                  (xem khối lý do dài trong `Trails.luau`)
			  • `trail_vip` (6.0)           — đi kèm VIP Membership
			Cả ba đều có `priceWins = 0` — con số đó là "không bán", không phải "giá 0".
			Xếp chúng cạnh Galaxy 500.000 Wins rồi đòi đơn điệu là so hai thứ khác loại.

			Sau khi lọc, dãy Wins còn đúng thang mua bán: 1.5 → 2 → 3 → 4 → 5 → 10.

			⚠️ PHẢI LỌC THEO CỜ, KHÔNG THEO GIÁ — catalog mã hoá "không bán" bằng HAI kiểu:
			  • Trails dùng `priceWins = 0`
			  • Auras  dùng `priceWins = 999999999` (số canh gác "không bao giờ đủ tiền")
			Vì vậy chỉ kiểm `priceWins > 0` là chưa đủ: `aura_vip` (dailyOnly, multiplier 6.0)
			vẫn lọt vào dãy và làm nó tụt sau `aura_cosmic` 8.0. Cờ `spinOnly`/`dailyOnly`/
			`robuxOnly` mới là thứ nói đúng món đó bán ở quầy nào.

			(Bản thân việc có hai cách mã hoá "không bán" là một code smell của catalog —
			nên thống nhất về một quy ước, nhưng đó là việc đổi dữ liệu kinh tế nên tách riêng.)
		]]
		local buyableWithWins = type(item.priceWins) == "number" and item.priceWins > 0
		local giveaway = item.spinOnly or item.dailyOnly
		if not giveaway and (item.robuxOnly or buyableWithWins) then
			local group = if item.robuxOnly then "robux" else "wins"
			table.insert(groups[group], item.multiplier)
		end
	end

	local zigzag = nil
	for groupName, multipliers in groups do
		local ascending = true
		local descending = true
		for index = 2, #multipliers do
			if multipliers[index] < multipliers[index - 1] then
				ascending = false
			end
			if multipliers[index] > multipliers[index - 1] then
				descending = false
			end
		end
		if not ascending and not descending then
			zigzag = `nhóm {groupName}: {table.concat(multipliers, ", ")}`
		end
	end

	check(`{name}: không trùng id`, duplicate == nil, duplicate)
	check(`{name}: multiplier ≥ 1`, badMultiplier == nil, badMultiplier)
	check(`{name}: giá không âm`, badPrice == nil, badPrice)
	check(`{name}: thứ tự multiplier nhất quán trong từng nhóm`, zigzag == nil, zigzag)
end

auditCatalog("Trails", Trails, { requiresPrice = true })
auditCatalog("Auras", Auras, { requiresPrice = true })
auditCatalog("Treadmills", Treadmills, { requiresPrice = true })

do
	-- Treadmill free phải tồn tại, nếu không người chơi mới không farm được.
	local hasFree = false
	for _, treadmill in Treadmills do
		if treadmill.gamepassId == 0 and treadmill.priceRobux == 0 then
			hasFree = true
		end
	end
	check("có ít nhất 1 treadmill miễn phí", hasFree)
end

do
	-- Gamepass id 0 nghĩa là "không bán bằng Robux". Món nào đặt robuxOnly = true
	-- mà lại không có gamepass thì người chơi không thể mua bằng đường nào cả.
	local unbuyable = {}
	for _, list in { Trails, Auras } do
		for _, item in list do
			if item.robuxOnly and (not item.gamepassId or item.gamepassId == 0) then
				table.insert(unbuyable, item.id)
			end
		end
	end
	check("không có món robuxOnly mà thiếu gamepassId", #unbuyable == 0, table.concat(unbuyable, ", "))
end

--------------------------------------------------------------------------------
suite("Stage wins")

do
	local increasing = true
	local previous = 0
	for stage = 1, Stages.MAX_CONFIGURED_STAGE do
		local wins = Stages.STAGE_WINS[stage]
		if not wins then
			check(`stage {stage} có phần thưởng`, false)
			increasing = false
			break
		end
		if wins <= previous then
			increasing = false
		end
		previous = wins
	end
	check("thưởng Wins tăng dần qua 15 stage", increasing)
end

--------------------------------------------------------------------------------
suite("Format số")

equals("999 giữ nguyên", Format.Number(999), "999")
equals("1000 → 1.00K", Format.Number(1000), "1.00K")
equals("1500 → 1.50K", Format.Number(1500), "1.50K")
equals("1 triệu → 1.00M", Format.Number(1_000_000), "1.00M")
equals("1 tỷ → 1.00B", Format.Number(1_000_000_000), "1.00B")
equals("0 → 0", Format.Number(0), "0")
check("số âm không vỡ", type(Format.Number(-1500)) == "string", tostring(Format.Number(-1500)))

--------------------------------------------------------------------------------
suite("Slide — dừng khi ấn lùi")

do
	local V = Shim.Vector3
	local grace = MovementConfig.Slide.BackwardStopGrace
	local after = grace + 0.01 -- đã qua cửa sổ ân huệ
	local forward = V.new(0, 0, 1)

	check("ấn ngược hẳn 180° → dừng", MovementMath.ShouldStopForBackward(forward, V.new(0, 0, -1), after))
	check(
		"ấn chéo sau (135°) → dừng",
		MovementMath.ShouldStopForBackward(forward, V.new(0.7071, 0, -0.7071), after)
	)
	check(
		"ấn ngang 90° → KHÔNG dừng (đang bẻ lái, không phải phanh)",
		not MovementMath.ShouldStopForBackward(forward, V.new(1, 0, 0), after)
	)
	check("vẫn ấn tới → KHÔNG dừng", not MovementMath.ShouldStopForBackward(forward, forward, after))
	check(
		"thả hết phím → KHÔNG dừng (để slide trôi hết đà tự nhiên)",
		not MovementMath.ShouldStopForBackward(forward, V.new(0, 0, 0), after)
	)
	check(
		"ấn lùi TRONG cửa sổ ân huệ → KHÔNG dừng (chống cắt slide vừa mở)",
		not MovementMath.ShouldStopForBackward(forward, V.new(0, 0, -1), grace * 0.5)
	)
	check("trục Y của phím bị bỏ qua", MovementMath.ShouldStopForBackward(forward, V.new(0, 5, -1), after))
	check(
		"slideDir rỗng → KHÔNG dừng (không có hướng để so)",
		not MovementMath.ShouldStopForBackward(V.new(0, 0, 0), V.new(0, 0, -1), after)
	)
end

--------------------------------------------------------------------------------
suite("Phanh & trần tốc độ")

do
	local brake = MovementConfig.Brake
	local grip = MovementConfig.Grip

	equals("tốc độ thấp dùng gia tốc nền", MovementMath.BrakeAccelAt(10), brake.Accel)
	check("hãm càng gắt khi càng nhanh", MovementMath.BrakeAccelAt(250) > MovementMath.BrakeAccelAt(120))

	-- Đây là tính chất QUAN TRỌNG NHẤT của phanh: quãng dừng không được phình theo v².
	-- Bản cũ (accel tỉ lệ bậc nhất với v) cho 13 studs @120 nhưng 42 studs @250.
	check(
		"quãng dừng @250 không vượt mục tiêu",
		MovementMath.StopDistanceAt(250) <= brake.TargetStopDistance + 0.01,
		`{MovementMath.StopDistanceAt(250)} studs, mục tiêu {brake.TargetStopDistance}`
	)
	check(
		"quãng dừng @400 (rebirth cao) vẫn không vượt mục tiêu",
		MovementMath.StopDistanceAt(400) <= brake.TargetStopDistance + 0.01,
		`{MovementMath.StopDistanceAt(400)} studs`
	)
	check(
		"quãng dừng @250 không quá 1.6× @120",
		MovementMath.StopDistanceAt(250) <= MovementMath.StopDistanceAt(120) * 1.6,
		`{MovementMath.StopDistanceAt(250)} vs {MovementMath.StopDistanceAt(120)}`
	)
	check(
		"tốc độ thấp vẫn dừng dứt khoát (< 15 studs @120)",
		MovementMath.StopDistanceAt(120) < 15,
		`{MovementMath.StopDistanceAt(120)} studs`
	)

	equals("trần tốc độ theo WalkSpeed", MovementMath.SpeedCeiling(250), 250 * grip.MaxSpeedFactor)
	equals("trần tốc độ có sàn tuyệt đối", MovementMath.SpeedCeiling(1), grip.MinCeiling)
	check("trần luôn ≥ WalkSpeed", MovementMath.SpeedCeiling(250) >= 250)
end

--------------------------------------------------------------------------------

print(`\n{passed} test đạt, {#failures} test hỏng`)

if #failures > 0 then
	print("\nHỏng:")
	for _, failure in failures do
		print(`  ✗ {failure}`)
	end
	process.exit(1)
end

print("Toàn bộ test logic thuần đã qua.")
