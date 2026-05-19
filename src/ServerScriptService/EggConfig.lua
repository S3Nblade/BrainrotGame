--!nonstrict
-- ServerScriptService/EggConfig.lua
-- One tuning table for egg spawning, rolled stats, chase behavior, luck, and rewards.

local EggConfig = {}

EggConfig.LuckScaling = {
	HPBonusMax = 10,
	SizeBonusMax = 12,
	RewardLuckScale = 0.012,
	MutationLuckScale = 0.016,
}

EggConfig.EvadeSuccessFullHeal = true
EggConfig.EvadeSuccessSpeedBoostDuration = 3
EggConfig.EvadeSuccessInvulnerableDuration = 2
EggConfig.EvadeSuccessSpeedMultiplier = 1.4
EggConfig.StunDuration = 20
EggConfig.HatchPromptText = "Press E to Hatch"

EggConfig.RarityOrder = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Mythic = 4,
	Legendary = 5,
	Divine = 6,
	Celestial = 7,
	Godly = 8,
	Secret = 9,
}

EggConfig.RarityColors = {
	Common = Color3.fromRGB(232, 238, 246),
	Rare = Color3.fromRGB(92, 178, 255),
	Epic = Color3.fromRGB(190, 105, 255),
	Mythic = Color3.fromRGB(255, 91, 177),
	Legendary = Color3.fromRGB(255, 207, 70),
	Divine = Color3.fromRGB(102, 239, 255),
	Celestial = Color3.fromRGB(170, 138, 255),
	Godly = Color3.fromRGB(255, 88, 88),
	Secret = Color3.fromRGB(92, 255, 166),
}

EggConfig.MutationInfo = {
	Normal = { Multiplier = 1, Color = Color3.fromRGB(255, 255, 255) },
	Golden = { Multiplier = 1.25, Color = Color3.fromRGB(255, 220, 45) },
	Diamond = { Multiplier = 1.6, Color = Color3.fromRGB(90, 235, 255) },
	Shadow = { Multiplier = 2.75, Color = Color3.fromRGB(135, 55, 215) },
	Rainbow = { Multiplier = 2.25, Color = Color3.fromRGB(255, 80, 220) },
}

EggConfig.Zones = {
	ForestMap1 = {
		DisplayName = "Forest",
		TemplateZone = "Forest",
		MaxEggs = 8,
		SpawnInterval = 8,
		RespawnDelay = 6,
		SpawnYOffset = 2.25,
		AllowedEggs = {
			{
				Id = "CommonEgg",
				DisplayName = "Common Egg",
				Rarity = "Common",
				Tier = 1,
				SpawnWeight = 75,
				HpRange = { Min = 80, Max = 160 },
				SizeRange = { Min = 0.9, Max = 1.15 },
				LuckRange = { Min = 3, Max = 8 },
				ChaseTime = 15,
				Speed = 14,
				ChaseRadius = 45,
				Rewards = {
					Brainrots = {
						Common = 85,
						Rare = 15,
					},
					Mutations = {
						Normal = 95,
						Golden = 5,
					},
				},
			},
			{
				Id = "RareEgg",
				DisplayName = "Rare Egg",
				Rarity = "Rare",
				Tier = 2,
				SpawnWeight = 25,
				HpRange = { Min = 180, Max = 420 },
				SizeRange = { Min = 1.15, Max = 1.45 },
				LuckRange = { Min = 10, Max = 22 },
				ChaseTime = 18,
				Speed = 13,
				ChaseRadius = 50,
				Rewards = {
					Brainrots = {
						Common = 50,
						Rare = 42,
						Epic = 8,
					},
					Mutations = {
						Normal = 88,
						Golden = 10,
						Diamond = 2,
					},
				},
			},
		},
	},

	Zone2 = {
		DisplayName = "Zone 2",
		TemplateZone = "Desert",
		MaxEggs = 9,
		SpawnInterval = 8,
		RespawnDelay = 6,
		AllowedEggs = {
			{
				Id = "BigRareEgg",
				DisplayName = "Big Rare Egg",
				Rarity = "Rare",
				Tier = 3,
				SpawnWeight = 65,
				HpRange = { Min = 320, Max = 620 },
				SizeRange = { Min = 1.32, Max = 1.65 },
				LuckRange = { Min = 18, Max = 30 },
				ChaseTime = 18,
				Speed = 12.5,
				ChaseRadius = 52,
				Rewards = {
					Brainrots = { Rare = 70, Epic = 30 },
					Mutations = { Normal = 82, Golden = 14, Diamond = 4 },
				},
			},
			{
				Id = "EpicEgg",
				DisplayName = "Epic Egg",
				Rarity = "Epic",
				Tier = 4,
				SpawnWeight = 35,
				HpRange = { Min = 450, Max = 1200 },
				SizeRange = { Min = 1.45, Max = 2 },
				LuckRange = { Min = 25, Max = 55 },
				ChaseTime = 22,
				Speed = 11,
				ChaseRadius = 55,
				Rewards = {
					Brainrots = { Rare = 40, Epic = 55, Mythic = 5 },
					Mutations = { Normal = 76, Golden = 17, Diamond = 6, Shadow = 1 },
				},
			},
		},
	},

	Zone3 = {
		DisplayName = "Zone 3",
		TemplateZone = "Crystal",
		MaxEggs = 9,
		SpawnInterval = 8,
		RespawnDelay = 6,
		AllowedEggs = {
			{
				Id = "BigEpicEgg",
				DisplayName = "Big Epic Egg",
				Rarity = "Epic",
				Tier = 5,
				SpawnWeight = 70,
				HpRange = { Min = 900, Max = 1600 },
				SizeRange = { Min = 1.7, Max = 2.15 },
				LuckRange = { Min = 38, Max = 62 },
				ChaseTime = 23,
				Speed = 10.5,
				ChaseRadius = 58,
				Rewards = {
					Brainrots = { Epic = 74, Mythic = 22, Legendary = 4 },
					Mutations = { Normal = 68, Golden = 20, Diamond = 9, Shadow = 2, Rainbow = 1 },
				},
			},
			{
				Id = "LegendaryEgg",
				DisplayName = "Legendary Egg",
				Rarity = "Legendary",
				Tier = 6,
				SpawnWeight = 30,
				HpRange = { Min = 1500, Max = 2400 },
				SizeRange = { Min = 1.9, Max = 2.35 },
				LuckRange = { Min = 55, Max = 78 },
				ChaseTime = 25,
				Speed = 9.5,
				ChaseRadius = 62,
				Rewards = {
					Brainrots = { Epic = 40, Mythic = 45, Legendary = 15 },
					Mutations = { Normal = 60, Golden = 22, Diamond = 12, Shadow = 4, Rainbow = 2 },
				},
			},
		},
	},
}

for _, zone in pairs(EggConfig.Zones) do
	zone.Eggs = zone.AllowedEggs
end

return EggConfig
