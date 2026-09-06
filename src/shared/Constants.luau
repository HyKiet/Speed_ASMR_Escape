--!strict
--[[
	Constants.luau — back-compat shim.

	Cấu hình chi tiết đã được tách vào `Shared/Config/*` và `Shared/Util/Format`.
	Module này gom lại thành 1 table duy nhất để mọi code cũ
	`require(ReplicatedStorage.Shared.Constants)` tiếp tục hoạt động không cần sửa.

	Khi thêm cấu hình mới, hãy đặt vào file Config phù hợp rồi expose ở đây nếu cần.
]]

local Config = script.Parent.Config

local DataTemplate = require(Config.DataTemplate)
local Tuning = require(Config.Tuning)
local Stages = require(Config.Stages)
local Teleport = require(Config.Teleport)
local Formulas = require(Config.Formulas)
local Treadmills = require(Config.Economy.Treadmills)
local Trails = require(Config.Economy.Trails)
local Auras = require(Config.Economy.Auras)
local MultiplierPads = require(Config.Economy.MultiplierPads)
local Gamepass = require(Config.Economy.Gamepass)
local Format = require(script.Parent.Util.Format)

export type TreadmillConfig = Treadmills.TreadmillConfig
export type TrailConfig = Trails.TrailConfig
export type AuraConfig = Auras.AuraConfig
export type MultiplierPadConfig = MultiplierPads.MultiplierPadConfig
export type TeleportDestinationConfig = Teleport.TeleportDestinationConfig
export type StageGate = Stages.StageGate

local Constants: { [string]: any } = {}

Constants.DATA_TEMPLATE = DataTemplate

-- Tuning (BASE_SPEED_GAIN, DEFAULT_WALK_SPEED, BASE_MAX_WALK_SPEED, WALK_SPEED_PER_LEVEL,
-- SPEED_GAIN_INTERVAL, MIN_MOVEMENT_FOR_SPEED_GAIN, TREADMILL_GAIN_RADIUS,
-- NETWORK_RATE_LIMIT_SECONDS, XP_CONVERSION_RATE, CORE_LOOP_VERSION)
for key, value in Tuning :: { [string]: any } do
	Constants[key] = value
end

-- Stages (STAGE_WINS, MAX_CONFIGURED_STAGE, FINISH_REWARD_COOLDOWN, STAGE_GATES, REVIVE_*,
-- SKIP_REBIRTH_*)
for key, value in Stages :: { [string]: any } do
	Constants[key] = value
end
Constants.FINISH_REWARD_WINS = Stages.STAGE_WINS[5]

-- Bảng catalog
Constants.TREADMILLS = Treadmills
Constants.TRAILS = Trails
Constants.AURAS = Auras
Constants.MULTIPLIER_PADS = MultiplierPads
Constants.TELEPORT_DESTINATIONS = Teleport
Constants.GAMEPASS_IDS = Gamepass

-- Công thức
Constants.XP_SPRINT_MAX_LEVEL = Formulas.XP_SPRINT_MAX_LEVEL
Constants.XP_SPRINT_BASE = Formulas.XP_SPRINT_BASE
Constants.XP_SPRINT_GROWTH = Formulas.XP_SPRINT_GROWTH
Constants.XP_MARATHON_ANCHOR = Formulas.XP_MARATHON_ANCHOR
Constants.XP_MARATHON_GROWTH = Formulas.XP_MARATHON_GROWTH

Constants.GetRequiredXP = Formulas.GetRequiredXP
Constants.GetCumulativeXP = Formulas.GetCumulativeXP
Constants.GetMaxWalkSpeed = Formulas.GetMaxWalkSpeed
Constants.GetLevelUpWinsReward = Formulas.GetLevelUpWinsReward
Constants.GetRequiredLevelForRebirth = Formulas.GetRequiredLevelForRebirth
Constants.GetRebirthMultiplier = Formulas.GetRebirthMultiplier
Constants.GetRebirthWinsCost = Formulas.GetRebirthWinsCost
Constants.GetStageGate = Formulas.GetStageGate
Constants.GetTreadmillById = Formulas.GetTreadmillById
Constants.GetMultiplierPadById = Formulas.GetMultiplierPadById
Constants.GetTrailMultiplier = Formulas.GetTrailMultiplier
Constants.GetAuraMultiplier = Formulas.GetAuraMultiplier

-- Format
Constants.FormatNumber = Format.Number

return Constants
