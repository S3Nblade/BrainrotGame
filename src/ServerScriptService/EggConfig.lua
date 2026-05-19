--!nonstrict
-- ServerScriptService/EggConfig.lua
-- One tuning table for spawned eggs, rewards, HP, size, luck, and future zones.

local EggConfig = {}

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
		Eggs = {
			{
				Id = "CommonEgg",
				DisplayName = "Common Egg",
				Rarity = "Common",
				Tier = 1,
				HP = 100,
				Size = 1,
				LuckBonus = 5,
				Weight = 75,
				Glow = 0.45,
				Rewards = {
					Brainrots = {
						Common = 72,
						Rare = 28,
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
				HP = 250,
				Size = 1.22,
				LuckBonus = 15,
				Weight = 25,
				Glow = 0.8,
				Rewards = {
					Brainrots = {
						Common = 38,
						Rare = 52,
						Epic = 10,
					},
					Mutations = {
						Normal = 87,
						Golden = 11,
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
		Eggs = {
			{
				Id = "BigRareEgg",
				DisplayName = "Big Rare Egg",
				Rarity = "Rare",
				Tier = 3,
				HP = 450,
				Size = 1.36,
				LuckBonus = 25,
				Weight = 65,
				Glow = 1,
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
				HP = 500,
				Size = 1.48,
				LuckBonus = 20,
				Weight = 35,
				Glow = 1.15,
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
		Eggs = {
			{
				Id = "BigEpicEgg",
				DisplayName = "Big Epic Egg",
				Rarity = "Epic",
				Tier = 5,
				HP = 1200,
				Size = 1.7,
				LuckBonus = 45,
				Weight = 70,
				Glow = 1.35,
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
				HP = 1800,
				Size = 1.85,
				LuckBonus = 60,
				Weight = 30,
				Glow = 1.65,
				Rewards = {
					Brainrots = { Epic = 40, Mythic = 45, Legendary = 15 },
					Mutations = { Normal = 60, Golden = 22, Diamond = 12, Shadow = 4, Rainbow = 2 },
				},
			},
		},
	},
}

return EggConfig
