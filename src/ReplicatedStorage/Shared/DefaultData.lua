--!strict
-- Versioned default player data shape for future consolidated saving.

local DefaultData = {
	SchemaVersion = 1,
	Money = 0,
	Gems = 0,
	Inventory = {},
	Discovered = {},
	Upgrades = {
		TrainingPower = 0,
		AutoTrainRate = 0,
		CapturePower = 0,
		Luck = 0,
	},
	UnlockedZones = {
		Starter = true,
	},
	Rebirths = 0,
	Plot = {
		UnlockedSlots = 3,
		Placements = {},
		UncollectedMoney = 0,
	},
	Quests = {
		Level = 1,
		ClaimedMilestones = {},
		Daily = {},
	},
	Daily = {
		LastClaimDay = 0,
		Streak = 0,
		BestStreak = 0,
	},
	Settings = {
		SfxVolume = 1,
		MusicVolume = 0.6,
		RevealSkip = false,
	},
}

return DefaultData
