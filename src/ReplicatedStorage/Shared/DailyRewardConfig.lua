--!strict

local DailyRewardConfig = {
	CooldownSeconds = 24 * 60 * 60,
	StreakResetSeconds = 2 * 24 * 60 * 60,
	CheckEverySeconds = 30,
	BaseRewardMoney = 5000,
	RewardPerRebirth = 15000,
	StreakRewards = {
		{ Day = 1, Multiplier = 1.0, Label = "Day 1" },
		{ Day = 2, Multiplier = 1.25, Label = "Day 2" },
		{ Day = 3, Multiplier = 1.55, Label = "Day 3" },
		{ Day = 4, Multiplier = 1.9, Label = "Day 4" },
		{ Day = 5, Multiplier = 2.35, Label = "Day 5" },
		{ Day = 6, Multiplier = 2.8, Label = "Day 6" },
		{ Day = 7, Multiplier = 4.0, Label = "MEGA" },
	},
}

return DailyRewardConfig
