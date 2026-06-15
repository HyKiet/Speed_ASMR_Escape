--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ByteNet = require(ReplicatedStorage.Packages.ByteNet)

return ByteNet.defineNamespace("speedEscape", function()
	return {
		profileSnapshot = ByteNet.definePacket({
			value = ByteNet.struct({
				isLoaded = ByteNet.bool,
				speed = ByteNet.float64,
				totalWins = ByteNet.float64,
				currentRunWins = ByteNet.float64,
				streak = ByteNet.uint16,
				personalBestDistance = ByteNet.float64,
				personalBestRunWins = ByteNet.float64,
				totalRuns = ByteNet.uint32,
				highestCompletedStage = ByteNet.uint16,
				level = ByteNet.uint16,
				xp = ByteNet.float64,
				requiredXP = ByteNet.float64,
				rebirths = ByteNet.uint16,
				maxWalkSpeed = ByteNet.float32,
				customSpeedLimit = ByteNet.float32,
				gainMultiplier = ByteNet.float32,
				treadmillMultiplier = ByteNet.float32,
				isOnTreadmill = ByteNet.bool,
				canRebirth = ByteNet.bool,
				requiredRebirthLevel = ByteNet.uint16,
				activeTreadmillId = ByteNet.string,
				equippedTrail = ByteNet.string,
				equippedAura = ByteNet.string,
				unlockedTrails = ByteNet.map(ByteNet.string, ByteNet.bool),
				unlockedAuras = ByteNet.map(ByteNet.string, ByteNet.bool),
			}),
		}),
		requestSnapshot = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		requestRebirth = ByteNet.definePacket({
			value = ByteNet.struct({}),
		}),
		requestCustomSpeed = ByteNet.definePacket({
			value = ByteNet.struct({
				walkSpeed = ByteNet.float32,
			}),
		}),
		requestCosmeticAction = ByteNet.definePacket({
			value = ByteNet.struct({
				category = ByteNet.string,
				itemId = ByteNet.string,
			}),
		}),
		requestTeleport = ByteNet.definePacket({
			value = ByteNet.struct({
				destinationId = ByteNet.string,
				paymentKind = ByteNet.string,
			}),
		}),
		reviveOffer = ByteNet.definePacket({
			value = ByteNet.struct({
				stage = ByteNet.uint8,
				durationSeconds = ByteNet.uint8,
				robuxProductId = ByteNet.float64,
				robuxPrice = ByteNet.uint16,
				adRewardProductId = ByteNet.float64,
			}),
		}),
		requestRevive = ByteNet.definePacket({
			value = ByteNet.struct({
				method = ByteNet.string,
			}),
		}),
		reviveClosed = ByteNet.definePacket({
			value = ByteNet.struct({
				reason = ByteNet.string,
			}),
		}),
		toast = ByteNet.definePacket({
			value = ByteNet.struct({
				kind = ByteNet.string,
				message = ByteNet.string,
				amount = ByteNet.float64,
			}),
		}),
	}
end)
