--!strict
-- Các công thức cân bằng game.

local Tuning = require(script.Parent.Tuning)
local Stages = require(script.Parent.Stages)
local Treadmills = require(script.Parent.Economy.Treadmills)
local Trails = require(script.Parent.Economy.Trails)
local Auras = require(script.Parent.Economy.Auras)
local MultiplierPads = require(script.Parent.Economy.MultiplierPads)
local StreakBonuses = require(script.Parent.Economy.StreakBonuses)

type TreadmillConfig = Treadmills.TreadmillConfig
type MultiplierPadConfig = MultiplierPads.MultiplierPadConfig
type StreakBonusConfig = StreakBonuses.StreakBonusConfig
type StageGate = Stages.StageGate

local Formulas = {}

-- Đường cong XP neo theo game mẫu: Level 67 cần 1.01M Speed; Level 68 cần 1.17M.
local XP_ANCHOR_LEVEL = 67
local XP_ANCHOR_REQUIRED = 1_010_000
local XP_NEXT_REQUIRED = 1_170_000
local XP_GROWTH_RATE = XP_NEXT_REQUIRED / XP_ANCHOR_REQUIRED

Formulas.XP_CURVE_ANCHOR_LEVEL = XP_ANCHOR_LEVEL
Formulas.XP_CURVE_ANCHOR_REQUIRED_SPEED = XP_ANCHOR_REQUIRED
Formulas.XP_CURVE_NEXT_REQUIRED_SPEED = XP_NEXT_REQUIRED
Formulas.XP_CURVE_GROWTH_RATE = XP_GROWTH_RATE
Formulas.XP_SOFT_CAP = 100

function Formulas.GetRequiredXP(level: number): number
	if level <= 0 then
		return 0
	end
	return math.floor(XP_ANCHOR_REQUIRED * math.pow(XP_GROWTH_RATE, level - XP_ANCHOR_LEVEL) + 0.5)
end

function Formulas.GetMaxWalkSpeed(level: number): number
	local uncapped = Tuning.BASE_MAX_WALK_SPEED + (math.max(level - 1, 0) * Tuning.WALK_SPEED_PER_LEVEL)
	return math.min(250, uncapped)
end

function Formulas.GetLevelUpWinsReward(level: number): number
	return level * 10
end

function Formulas.GetRequiredLevelForRebirth(currentRebirths: number): number
	return 50 + (currentRebirths * 10)
end

function Formulas.GetRebirthMultiplier(rebirths: number): number
	return 1 + (rebirths * 0.5)
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

function Formulas.GetStreakBonus(streak: number): StreakBonusConfig?
	local bestBonus: StreakBonusConfig? = nil
	for _, bonus in StreakBonuses do
		if streak >= bonus.streak then
			bestBonus = bonus
		end
	end
	return bestBonus
end

return Formulas
