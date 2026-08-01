--!strict
-- Bảng Danh sách Mã Quà Tặng (Promo Codes) cho Speed Escape.

export type CodeReward = {
	description: string,
	wins: number?,
	speed: number?,
	spin: number?,
	boostSpeed: number?,
	boostWins: number?,
}

local Codes: { [string]: CodeReward } = {
	["RELEASE"] = {
		description = "+1,000 Wins & 🎟️ 1 Spin Ticket",
		wins = 1000,
		spin = 1,
	},
	["SPEED"] = {
		description = "+5,000 Speed Boost",
		speed = 5000,
	},
	["FREEWINS"] = {
		description = "+2,500 Wins",
		wins = 2500,
	},
	["LUCKY"] = {
		description = "+10,000 Speed & 🎟️ 2 Spin Tickets",
		speed = 10000,
		spin = 2,
	},
}

return Codes
