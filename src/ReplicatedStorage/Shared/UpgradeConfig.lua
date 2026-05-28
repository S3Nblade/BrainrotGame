--!strict

local UpgradeConfig = {}

UpgradeConfig.Definitions = {
	TrainingPower = {
		title = "Training Power",
		desc = "More strength every training hit.",
		icon = "STR",
		maxLevel = 5,
		requirements = { 250, 750, 1500, 3000, 5000 },
		effect = {
			attribute = "TrainingMultiplier",
			base = 1,
			perLevel = 0.2,
		},
	},

	AutoTrainRate = {
		title = "Auto Train Rate",
		desc = "Auto training ticks faster.",
		icon = "SPD",
		maxLevel = 5,
		requirements = { 500, 1500, 3000, 6000, 10000 },
		effect = {
			attribute = "AutoTrainDelay",
			base = 0.4,
			perLevel = -0.025,
			min = 0.29,
		},
	},

	CapturePower = {
		title = "Capture Power",
		desc = "Stun wild Brainrots faster.",
		icon = "POW",
		maxLevel = 5,
		requirements = { 800, 2200, 5200, 11000, 22000 },
		effect = {
			attribute = "CapturePowerMultiplier",
			base = 1,
			perLevel = 0.15,
		},
	},

	Luck = {
		title = "Luck",
		desc = "Better odds for rare Brainrots.",
		icon = "LUK",
		maxLevel = 5,
		requirements = { 1200, 3600, 8200, 18000, 40000 },
		effect = {
			attribute = "LuckMultiplier",
			base = 1,
			perLevel = 0.1,
		},
	},
}

return UpgradeConfig
