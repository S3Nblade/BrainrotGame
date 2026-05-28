--!strict
-- One place for simulator pacing numbers. Server scripts should read from here when possible.

local BalanceConfig = {
	Capture = {
		MaxCaptureDistance = 18,
		CaptureCooldown = 0.75,
		StunDuration = 12,
		BaseAttackDamage = 10,
	},

	NPC = {
		MaxActivePerZone = 8,
		FleeRadius = 45,
		FleeUpdateInterval = 0.35,
		RespawnDelay = 4,
		WanderMinWait = 2.0,
		WanderMaxWait = 4.5,
		WanderMoveTimeout = 5,
	},

	Plot = {
		CollectCooldown = 0.35,
		IncomeTickSeconds = 1,
		BaseSlots = 3,
		MaxSlots = 18,
	},

	Reveal = {
		FakePreviewMinTime = 0.12,
		FakePreviewMaxTime = 0.22,
		FakePreviewCount = 9,
		FinalRevealSeconds = 1.25,
		AllowSkipAfterSeconds = 1.75,
	},

	Economy = {
		StarterMoney = 0,
		StarterGems = 0,
		CashMultiplierPerRebirth = 2,
	},

	Quests = {
		UpdateInterval = 2.5,
	},
}

return BalanceConfig
