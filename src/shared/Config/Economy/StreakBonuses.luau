--!strict

export type StreakBonusConfig = {
	streak: number,
	extraWins: number,
	label: string,
}

local StreakBonuses: { StreakBonusConfig } = {
	{ streak = 3,  extraWins = 10,    label = "3 STREAK" },
	{ streak = 5,  extraWins = 50,    label = "5 STREAK" },
	{ streak = 10, extraWins = 250,   label = "10 STREAK" },
	{ streak = 20, extraWins = 1000,  label = "20 STREAK" },
	{ streak = 50, extraWins = 10000, label = "50 STREAK" },
}

return StreakBonuses
