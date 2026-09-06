--!strict
-- Các công thức cân bằng game.

local Tuning = require(script.Parent.Tuning)
local Stages = require(script.Parent.Stages)
local Treadmills = require(script.Parent.Economy.Treadmills)
local Trails = require(script.Parent.Economy.Trails)
local Auras = require(script.Parent.Economy.Auras)
local MultiplierPads = require(script.Parent.Economy.MultiplierPads)

type TreadmillConfig = Treadmills.TreadmillConfig
type MultiplierPadConfig = MultiplierPads.MultiplierPadConfig
type StageGate = Stages.StageGate

local Formulas = {}

--[[
	ĐƯỜNG CONG XP — HAI BĂNG (GDD 3.0 §3.1)

	Bản cũ dùng MỘT hàm mũ duy nhất neo ở Level 67 (1,01M Speed, nhịp 1,1584/level). Nó rẻ đều
	từ đầu tới cuối, nghĩa là 30 level đầu — đoạn quyết định người chơi mới ở lại hay bỏ đi —
	đắt ngang phần còn lại của game theo tỉ lệ.

	Hai băng:
	  • SPRINT  (1–30)  : xuất phát 5 XP, nhịp 1,25. Level đầu tiên xong trong ~2 giây.
	  • MARATHON (31+)  : neo tại 3.675, nhịp 1,157 — gần y hệt nhịp cũ (1,1584).

	Vì băng Sprint xuất phát ở 5 thay vì 62 và cả hai đường là hàm mũ (cắt nhau nhiều nhất một
	lần), đường mới nằm DƯỚI đường cũ ở MỌI level trong tầm chơi được. Không ai bị nerf; migration
	chỉ có thể làm người chơi lên level, không bao giờ tụt.

	⚠️ ĐÂY LÀ CẦN GẠT CHÍNH CỦA TOÀN BỘ NHỊP GAME. Băng Sprint quyết định 30 phút đầu; băng
	Marathon quyết định mọi thứ sau đó. Đổi một trong hai là phải chạy lại toàn bộ mô phỏng nhịp
	ở GDD §3.5 — mọi mốc thời gian trong đó đều suy ra từ hai con số này.
]]
local XP_SPRINT_MAX_LEVEL = 30
local XP_SPRINT_BASE = 5
local XP_SPRINT_GROWTH = 1.25
-- Neo băng Marathon = req(30) của băng Sprint, làm tròn lên cho dễ đọc.
local XP_MARATHON_ANCHOR = 3675
local XP_MARATHON_GROWTH = 1.157

Formulas.XP_SPRINT_MAX_LEVEL = XP_SPRINT_MAX_LEVEL
Formulas.XP_SPRINT_BASE = XP_SPRINT_BASE
Formulas.XP_SPRINT_GROWTH = XP_SPRINT_GROWTH
Formulas.XP_MARATHON_ANCHOR = XP_MARATHON_ANCHOR
Formulas.XP_MARATHON_GROWTH = XP_MARATHON_GROWTH
Formulas.XP_SOFT_CAP = 100

function Formulas.GetRequiredXP(level: number): number
	if level <= 0 then
		return 0
	end
	if level <= XP_SPRINT_MAX_LEVEL then
		return math.floor(XP_SPRINT_BASE * math.pow(XP_SPRINT_GROWTH, level - 1) + 0.5)
	end
	return math.floor(XP_MARATHON_ANCHOR * math.pow(XP_MARATHON_GROWTH, level - XP_SPRINT_MAX_LEVEL) + 0.5)
end

--[[
	Tổng XP tích luỹ để đi từ Level 1 tới `level`. Dùng cho:
	  • migration đường cong (DataService) — tính lại Level từ Speed đã có,
	  • phần thưởng co giãn của Daily Quest / điểm danh vòng 2+ (GDD §7.3, §7.4).
	Vòng lặp chứ không dùng công thức đóng: hai băng khác nhịp nên tổng đóng dễ sai lệch, mà
	level cao nhất thực tế chỉ vài trăm — chi phí không đáng kể.
]]
function Formulas.GetCumulativeXP(level: number): number
	local total = 0
	for l = 1, math.max(math.floor(level) - 1, 0) do
		total += Formulas.GetRequiredXP(l)
	end
	return total
end

function Formulas.GetMaxWalkSpeed(level: number): number
	local uncapped = Tuning.BASE_MAX_WALK_SPEED + (math.max(level - 1, 0) * Tuning.WALK_SPEED_PER_LEVEL)
	return math.min(250, uncapped)
end

function Formulas.GetLevelUpWinsReward(level: number): number
	return level * 10
end

--[[
	TRÙNG SINH (GDD 3.0 §3.4) — đây là trục tiến trình dài hạn của cả game.

	Bảng 8 mốc đầu giữ NGUYÊN bản cũ; R8 = Level 120 là điều kiện mở World 2. Từ R9 bước
	+4 level thay vì +10: chi phí mỗi bậc thành ×1,82 thay vì ×4,35, đủ dốc mà không dựng tường.
]]
local EARLY_REBIRTH_LEVELS = { 10, 20, 32, 46, 62, 80, 100, 120 }
local REBIRTH_LEVEL_STEP = 4

function Formulas.GetRequiredLevelForRebirth(currentRebirths: number): number
	local index = currentRebirths + 1
	local early = EARLY_REBIRTH_LEVELS[index]
	if early then
		return early
	end
	return EARLY_REBIRTH_LEVELS[#EARLY_REBIRTH_LEVELS] + (index - #EARLY_REBIRTH_LEVELS) * REBIRTH_LEVEL_STEP
end

--[[
	Hệ số cày. R1–R3 y hệt bản cũ (1,5 / 2,0 / 2,5) nên không ai bị nerf; từ R4 chuyển sang nhân
	liên hoàn ×1,45.

	Vì sao 1,45 chứ không phải 1,3: đo bằng mô phỏng (GDD §5.1). Ở 1,3 người chơi F2P chỉ dành
	5% thời gian trong obby và tiêu 39% số Wins kiếm được — tức biến thành người chơi idle và
	nền kinh tế chết. Ở 1,45 hai con số đó là 36% và 86%.

	⚠️ Đây là xô DUY NHẤT nhân liên hoàn (xem GDD §3.3). Không được nhét quyền lợi gamepass nào
	vào đây — mọi thứ khác đều nằm trong các xô cộng dồn nên bị chặn trên, riêng xô này thì không.
]]
local REBIRTH_LINEAR_MAX = 3
local REBIRTH_GROWTH = 1.45

function Formulas.GetRebirthMultiplier(rebirths: number): number
	if rebirths <= REBIRTH_LINEAR_MAX then
		return 1 + (rebirths * 0.5)
	end
	return (1 + REBIRTH_LINEAR_MAX * 0.5) * math.pow(REBIRTH_GROWTH, rebirths - REBIRTH_LINEAR_MAX)
end

--[[
	PHÍ WINS KHI TRÙNG SINH — sink Wins DUY NHẤT tăng vô hạn trong game.

	Mọi sink khác đều có trần: pad 22.273 · cosmetic 882.200 · emote 39.260. Cộng lại chưa bằng
	ba lượt clear Stage 15. Không có khoản phí này thì Wins bão hoà sau ~3 giờ chơi và mọi món
	bán bằng Wins mất giá trị — đúng cái đã đo được ở bản cũ: Sinks/Sources = 2,3%.

	5 lần trùng sinh đầu MIỄN PHÍ để vòng lặp được dạy xong trước khi bị tính tiền.
]]
local REBIRTH_FEE_FREE_UNTIL = 5
local REBIRTH_FEE_BASE = 50_000
local REBIRTH_FEE_GROWTH = 2.6

-- `targetRebirth` = lần trùng sinh SẮP thực hiện (người có 5 lần rồi thì truyền 6).
function Formulas.GetRebirthWinsCost(targetRebirth: number): number
	local target = math.floor(targetRebirth)
	if target <= REBIRTH_FEE_FREE_UNTIL then
		return 0
	end
	return math.floor(REBIRTH_FEE_BASE * math.pow(REBIRTH_FEE_GROWTH, target - REBIRTH_FEE_FREE_UNTIL - 1))
end

function Formulas.GetStageGate(stage: number): StageGate?
	return Stages.STAGE_GATES[stage]
end

function Formulas.GetTreadmillById(treadmillId: string): TreadmillConfig?
	for _, config in Treadmills do
		if config.id == treadmillId then
			return config
		end
	end
	return nil
end

function Formulas.GetMultiplierPadById(padId: string): MultiplierPadConfig?
	for _, config in MultiplierPads do
		if config.id == padId then
			return config
		end
	end
	return nil
end

function Formulas.GetTrailMultiplier(trailId: string): number
	if trailId == "none" then
		return 1
	end
	for _, config in Trails do
		if config.id == trailId then
			return config.multiplier
		end
	end
	return 1
end

function Formulas.GetAuraMultiplier(auraId: string): number
	if auraId == "none" then
		return 1
	end
	for _, config in Auras do
		if config.id == auraId then
			return config.multiplier
		end
	end
	return 1
end

return Formulas
