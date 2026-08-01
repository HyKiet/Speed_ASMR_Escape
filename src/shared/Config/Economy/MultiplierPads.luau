--!strict

export type MultiplierPadConfig = {
	id: string,
	speedPerStep: number,
	requiredWins: number,
}

local MultiplierPads: { MultiplierPadConfig } = {
	{ id = "pad_1",  speedPerStep = 1,    requiredWins = 0 },
	{ id = "pad_2",  speedPerStep = 2,    requiredWins = 3 },
	{ id = "pad_3",  speedPerStep = 5,    requiredWins = 15 },
	{ id = "pad_4",  speedPerStep = 25,   requiredWins = 100 },
	{ id = "pad_5",  speedPerStep = 50,   requiredWins = 500 },
	{ id = "pad_6",  speedPerStep = 100,  requiredWins = 2500 },
	{ id = "pad_7",  speedPerStep = 250,  requiredWins = 15000 },
	{ id = "pad_8",  speedPerStep = 500,  requiredWins = 50000 },
	{ id = "pad_9",  speedPerStep = 1000, requiredWins = 200000 },
	{ id = "pad_10", speedPerStep = 2500, requiredWins = 1000000 },
	{ id = "pad_11", speedPerStep = 6000, requiredWins = 5000000 },
}

return MultiplierPads
