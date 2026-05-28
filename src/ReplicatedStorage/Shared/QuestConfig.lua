--!strict

local QuestConfig = {}

QuestConfig.CollectionMilestones = {
	{ Id = "first_brainrot", Goal = 1, Title = "First Brainrot!", RewardType = "Coins", RewardAmount = 250 },
	{ Id = "small_squad", Goal = 3, Title = "Small Squad", RewardType = "Coins", RewardAmount = 750 },
	{ Id = "base_builder", Goal = 5, Title = "Base Builder", RewardType = "Coins", RewardAmount = 2000 },
	{ Id = "collector", Goal = 10, Title = "Collector", RewardType = "Gems", RewardAmount = 150 },
	{ Id = "brainrot_tycoon", Goal = 20, Title = "Brainrot Tycoon", RewardType = "Gems", RewardAmount = 500 },
	{ Id = "collection_legend", Goal = 50, Title = "Collection Legend", RewardType = "Gems", RewardAmount = 1500 },
}

QuestConfig.Quests = {
	{ Title = "First Catch", Action = "Capture or place 1 Brainrot", Goal = 1, RewardType = "Coins", RewardAmount = 250 },
	{ Title = "Build Your Squad", Action = "Collect 3 Brainrots", Goal = 3, RewardType = "Coins", RewardAmount = 500 },
	{ Title = "Grow The Base", Action = "Collect 5 Brainrots", Goal = 5, RewardType = "Coins", RewardAmount = 1500 },
	{ Title = "Rare Hunter", Action = "Collect 10 Brainrots", Goal = 10, RewardType = "Gems", RewardAmount = 250 },
	{ Title = "Brainrot Boss", Action = "Collect 15 Brainrots", Goal = 15, RewardType = "Gems", RewardAmount = 1000 },
	{ Title = "Money Machine", Action = "Collect 25 Brainrots", Goal = 25, RewardType = "Coins", RewardAmount = 10000 },
	{ Title = "Simulator Legend", Action = "Collect 40 Brainrots", Goal = 40, RewardType = "Gems", RewardAmount = 2500 },
}

QuestConfig.DailyQuests = {
	{
		Id = "daily_chest",
		Title = "Daily Streak",
		Action = "Claim the daily chest",
		Event = "DailyRewardClaimed",
		Goal = 1,
		RewardType = "Coins",
		RewardAmount = 1500,
	},
	{
		Id = "capture_10",
		Title = "Daily Hunt",
		Action = "Capture 10 Brainrots",
		Event = "CaptureCompleted",
		Goal = 10,
		RewardType = "Coins",
		RewardAmount = 2500,
	},
	{
		Id = "collect_money_5",
		Title = "Cash Grab",
		Action = "Collect plot money 5 times",
		Event = "MoneyCollected",
		Goal = 5,
		RewardType = "Coins",
		RewardAmount = 3500,
	},
	{
		Id = "place_3",
		Title = "Base Builder",
		Action = "Place 3 Brainrots",
		Event = "BrainrotPlaced",
		Goal = 3,
		RewardType = "Gems",
		RewardAmount = 100,
	},
	{
		Id = "rare_capture",
		Title = "Rare Moment",
		Action = "Capture 1 Rare+ Brainrot",
		Event = "CaptureCompleted",
		Goal = 1,
		MinRarity = "Rare",
		RewardType = "Gems",
		RewardAmount = 150,
	},
}

return QuestConfig
