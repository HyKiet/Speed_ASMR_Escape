--!nocheck
-- Bot đo kinh tế — mô phỏng hàng nghìn giờ chơi bằng SỐ, không cần mở Roblox.
--
-- Chạy: lune run tests/economy_sim.luau
--
-- Nó tái dựng đúng vòng tick của ProgressionService:
--   gain mỗi tick = padStep × premium × cosmetic × rebirth × liveOps
--   premium/cosmetic là rổ CỘNG (additive), các rổ nhân với nhau
-- rồi cho "người chơi ảo" cày cho tới mốc rebirth, đo mất bao nhiêu giờ.
--
-- Đây KHÔNG phải test đúng/sai — nó là báo cáo. Đọc số rồi tự quyết cân bằng.
-- Nếu đổi công thức mà số ở đây nhảy vọt, đó là tín hiệu.

local process = require("@lune/process")
local Shim = require("./roblox")

local Formulas = Shim.Require("src/shared/Config/Formulas.luau")
local Tuning = Shim.Require("src/shared/Config/Tuning.luau")
local Stages = Shim.Require("src/shared/Config/Stages.luau")
local Pads = Shim.Require("src/shared/Config/Economy/MultiplierPads.luau")
local Trails = Shim.Require("src/shared/Config/Economy/Trails.luau")
local Auras = Shim.Require("src/shared/Config/Economy/Auras.luau")
local Treadmills = Shim.Require("src/shared/Config/Economy/Treadmills.luau")
local Format = Shim.Require("src/shared/Util/Format.luau")

local TICK = Tuning.SPEED_GAIN_INTERVAL -- 0.35s
local TICKS_PER_SECOND = 1 / TICK

-- Thời gian một lượt chạy obby (giây). Đo thô từ chiều dài stage; đây là con số
-- giả định lớn nhất của mô hình — đổi nó thì mọi kết quả dịch theo.
local STAGE_RUN_SECONDS = 75

-- Trần mô phỏng để không chạy vô hạn khi công thức bị chỉnh hỏng.
local MAX_SIM_HOURS = 2000

type Profile = {
	name: string,
	treadmill: number,
	speedPass: number,
	vip: number,
	trail: number,
	aura: number,
	playtime: number,
}

local function additive(...: number): number
	local total = 1
	for _, m in { ... } do
		total += math.max(0, m - 1)
	end
	return total
end

local function multiplierFor(profile: Profile, rebirths: number): number
	local premium = additive(profile.treadmill, profile.speedPass, profile.vip)
	local cosmetic = additive(profile.trail, profile.aura)
	local rebirth = Formulas.GetRebirthMultiplier(rebirths)
	return premium * cosmetic * rebirth * profile.playtime
end

-- Pad cao nhất mở được với số Wins đang có. Luật mua TUẦN TỰ nên chỉ cần quét xuôi.
local function padStepFor(totalWins: number): number
	local step = Pads[1].speedPerStep
	for _, pad in Pads do
		if totalWins >= pad.requiredWins then
			step = pad.speedPerStep
		else
			break
		end
	end
	return step
end

-- Stage cao nhất người chơi sống sót được, suy từ WalkSpeed hiện tại.
-- STAGE_GATES là "gợi ý" trên biển, nhưng thực chất là ngưỡng sống sót của bẫy.
local function highestClearableStage(level: number): number
	local walkSpeed = Formulas.GetMaxWalkSpeed(level)
	local best = 0
	for stage = 1, Stages.MAX_CONFIGURED_STAGE do
		local gate = Stages.STAGE_GATES[stage]
		if gate and walkSpeed >= gate.minWS then
			best = stage
		end
	end
	return best
end

local function simulate(profile: Profile, targetRebirths: number)
	local speed, xp, level, rebirths = 0, 0, 1, 0
	local totalWins = 0
	local elapsed = 0
	local clearedUpTo = 0
	local milestones: { { rebirth: number, hours: number } } = {}
	local secondsFarming, secondsRunning = 0, 0

	while rebirths < targetRebirths and elapsed < MAX_SIM_HOURS * 3600 do
		-- Nếu đã đủ nhanh để ăn một stage mới thì đi chạy — Wins mở pad, pad mới
		-- là thứ tăng tốc thật sự, nên người chơi tối ưu luôn ưu tiên việc này.
		local reachable = highestClearableStage(level)
		if reachable > clearedUpTo then
			clearedUpTo += 1
			totalWins += Stages.STAGE_WINS[clearedUpTo] or 0
			elapsed += STAGE_RUN_SECONDS
			secondsRunning += STAGE_RUN_SECONDS
			continue
		end

		-- Còn lại thì đứng treadmill cày, mô phỏng theo từng phút cho nhanh.
		local step = padStepFor(totalWins)
		local gainPerTick = step * multiplierFor(profile, rebirths)
		local gainPerMinute = gainPerTick * TICKS_PER_SECOND * 60

		speed += gainPerMinute
		xp += gainPerMinute * Tuning.XP_CONVERSION_RATE
		elapsed += 60
		secondsFarming += 60

		while xp >= Formulas.GetRequiredXP(level) do
			xp -= Formulas.GetRequiredXP(level)
			level += 1
		end

		local required = Formulas.GetRequiredLevelForRebirth(rebirths)
		if level >= required then
			rebirths += 1
			table.insert(milestones, { rebirth = rebirths, hours = elapsed / 3600 })
			speed, xp, level = 0, 0, 1
			clearedUpTo = 0 -- WalkSpeed reset ⇒ phải cày lại mới qua được stage cao
		end
	end

	return {
		milestones = milestones,
		hours = elapsed / 3600,
		totalWins = totalWins,
		farmShare = if elapsed > 0 then secondsFarming / elapsed else 0,
		reachedTarget = rebirths >= targetRebirths,
	}
end

--------------------------------------------------------------------------------

local function findTrail(id: string): number
	for _, t in Trails do
		if t.id == id then
			return t.multiplier
		end
	end
	return 1
end

local function findAura(id: string): number
	for _, a in Auras do
		if a.id == id then
			return a.multiplier
		end
	end
	return 1
end

local function findTreadmill(id: string): number
	for _, t in Treadmills do
		if t.id == id then
			return t.multiplier
		end
	end
	return 1
end

local PROFILES: { Profile } = {
	{
		name = "Free (không mua gì)",
		treadmill = findTreadmill("treadmill_1"),
		speedPass = 1,
		vip = 1,
		trail = 1,
		aura = 1,
		playtime = 1,
	},
	{
		name = "Nhẹ (~100 R$: x2 speed + trail xanh)",
		treadmill = findTreadmill("treadmill_1"),
		speedPass = 2,
		vip = 1,
		trail = findTrail("trail_blue"),
		aura = 1,
		playtime = 1,
	},
	{
		name = "Trung (~1000 R$: x4 + Purple treadmill + trail đỏ + aura tím)",
		treadmill = findTreadmill("treadmill_2"),
		speedPass = 4,
		vip = 1,
		trail = findTrail("trail_red"),
		aura = findAura("aura_void"),
		playtime = 1,
	},
	{
		name = "Whale (mua sạch: x8 + Red Admin + Galaxy + RedHeart + VIP)",
		treadmill = findTreadmill("treadmill_5"),
		speedPass = 8,
		vip = 2,
		trail = findTrail("trail_galaxy"),
		aura = findAura("RedHeart"),
		playtime = 1,
	},
}

local TARGET_REBIRTHS = 5

print("═══ BÁO CÁO KINH TẾ — SpeedEscape ═══\n")
print(`Giả định: 1 lượt chạy obby = {STAGE_RUN_SECONDS}s, cày liên tục không nghỉ,`)
print("người chơi luôn rebirth ngay khi đủ level, luôn dùng pad cao nhất mở được.\n")

print("Hệ số tổng (lúc 0 rebirth) và thời gian tới các mốc rebirth:\n")
print(string.format("%-52s %8s %10s %10s %10s", "Hồ sơ", "Hệ số", "R1", "R3", "R5"))
print(string.rep("─", 94))

local results = {}
for _, profile in PROFILES do
	local result = simulate(profile, TARGET_REBIRTHS)
	results[profile.name] = result

	local function at(n: number): string
		for _, m in result.milestones do
			if m.rebirth == n then
				return string.format("%.1fh", m.hours)
			end
		end
		return "—"
	end

	print(string.format("%-52s %8.1f %10s %10s %10s", profile.name, multiplierFor(profile, 0), at(1), at(3), at(5)))
end

print(string.rep("─", 94))

local free = results["Free (không mua gì)"]
local whale = results["Whale (mua sạch: x8 + Red Admin + Galaxy + RedHeart + VIP)"]

local function hoursTo(result, n: number): number?
	for _, m in result.milestones do
		if m.rebirth == n then
			return m.hours
		end
	end
	return nil
end

print("\n── Nhận xét tự động ──\n")

local freeR1 = hoursTo(free, 1)
local whaleR1 = hoursTo(whale, 1)

if freeR1 then
	print(string.format("• Người chơi free tới rebirth đầu sau %.1f giờ.", freeR1))
	if freeR1 > 12 then
		print("  ⚠️ QUÁ CHẬM. Rebirth đầu là cú hookmạnh nhất của thể loại simulator;")
		print("     quá 12 giờ thì phần lớn người chơi bỏ trước khi chạm tới.")
	elseif freeR1 < 0.5 then
		print("  ⚠️ QUÁ NHANH. Rebirth mất cảm giác thành tựu, và người chơi đốt hết")
		print("     nội dung trong buổi đầu.")
	else
		print("  ✓ Nằm trong khoảng lành mạnh (0.5–12 giờ).")
	end
else
	print(`• ⚠️ Người chơi free KHÔNG tới nổi rebirth đầu trong {MAX_SIM_HOURS} giờ mô phỏng.`)
end

if freeR1 and whaleR1 then
	print(string.format("\n• Whale nhanh gấp %.1f lần người chơi free (tới rebirth 1).", freeR1 / whaleR1))
	local ratio = freeR1 / whaleR1
	if ratio > 50 then
		print(
			"  ⚠️ Khoảng cách quá lớn — người chơi free sẽ thấy vô vọng khi nhìn bảng xếp hạng."
		)
	elseif ratio < 3 then
		print("  ⚠️ Khoảng cách quá nhỏ — mua Robux gần như vô nghĩa, doanh thu sẽ thấp.")
	else
		print("  ✓ Khoảng cách hợp lý (3–50 lần).")
	end
end

print(
	string.format(
		"\n• Người chơi free dành %.0f%% thời gian đứng treadmill, còn lại chạy obby.",
		free.farmShare * 100
	)
)
if free.farmShare > 0.9 then
	print("  ⚠️ Gần như chỉ đứng yên. Phần obby — thứ tốn công làm nhất — bị bỏ phí.")
end

print("\n── Kiểm tra lạm phát Wins ──\n")
local totalStageWins = 0
for stage = 1, Stages.MAX_CONFIGURED_STAGE do
	totalStageWins += Stages.STAGE_WINS[stage] or 0
end
print(string.format("Chạy trọn 15 stage một lượt = %s Wins.", Format.Number(totalStageWins)))
print(
	string.format(
		"Pad cuối (pad_%d) cần %s Wins ⇒ ~%.1f lượt chạy trọn map.",
		#Pads,
		Format.Number(Pads[#Pads].requiredWins),
		Pads[#Pads].requiredWins / totalStageWins
	)
)

local mostExpensiveTrail = 0
for _, t in Trails do
	if not t.robuxOnly and t.priceWins > mostExpensiveTrail and t.priceWins < 1e9 then
		mostExpensiveTrail = t.priceWins
	end
end
print(
	string.format(
		"Trail đắt nhất mua bằng Wins = %s ⇒ ~%.1f lượt chạy trọn map.",
		Format.Number(mostExpensiveTrail),
		mostExpensiveTrail / totalStageWins
	)
)

print("\n═══ HẾT ═══")

process.exit(0)
