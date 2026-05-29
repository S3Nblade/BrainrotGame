--!strict
-- Versioned default player data shape for future consolidated saving.

local DefaultData = {
	SchemaVersion = 4,
	Money = 0,
	Gems = 0,
	Strength = 0,
	Inventory = {},
	Discovered = {},
	Upgrades = {
		TrainingPower = 0,
		AutoTrainRate = 0,
		CapturePower = 0,
		Luck = 0,
		InventoryCapacity = 0,
		PlotSlotValue = 0,
		CashBoost = 0,
	},
	UnlockedZones = {
		Starter = true,
		Forest = false,
		Crystal = false,
		Lava = false,
		Galaxy = false,
	},
	Rebirths = 0,
	Multipliers = {
		TrainingMultiplier = 1,
		CapturePowerMultiplier = 1,
		LuckMultiplier = 1,
		MoneyMultiplier = 1,
		ShopCashMultiplier = 1,
		PlotSlotDiscount = 0,
		InventoryCapacityBonus = 0,
	},
	Plot = {
		UnlockedSlots = 3,
		Placements = {},
		UncollectedMoney = 0,
		FloorsUnlocked = 1,
	},
	Quests = {
		Level = 1,
		ClaimedMilestones = {},
		Daily = {
			DayKey = "",
			Progress = {},
			Claimed = {},
		},
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
