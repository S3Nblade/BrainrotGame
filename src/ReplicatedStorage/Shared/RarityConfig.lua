--!strict
-- Shared rarity metadata for Brainrot rewards, UI, spawning, and reveal effects.

local RarityConfig = {}

RarityConfig.Order = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
}

RarityConfig.Colors = {
	Common = Color3.fromRGB(236, 242, 248),
	Uncommon = Color3.fromRGB(111, 236, 135),
	Rare = Color3.fromRGB(77, 174, 255),
	Epic = Color3.fromRGB(194, 91, 255),
	Legendary = Color3.fromRGB(255, 199, 61),
	Mythic = Color3.fromRGB(255, 83, 166),
	Secret = Color3.fromRGB(67, 255, 192),
}

RarityConfig.SpawnLuckWeights = {
	Common = 1,
	Uncommon = 1.08,
	Rare = 1.18,
	Epic = 1.35,
	Legendary = 1.7,
	Mythic = 2.25,
	Secret = 3,
}

RarityConfig.RevealSfx = {
	Common = "reveal_final_pop",
	Uncommon = "reveal_final_pop",
	Rare = "reveal_rare",
	Epic = "reveal_rare",
	Legendary = "reveal_legendary",
	Mythic = "reveal_legendary",
	Secret = "reveal_legendary",
}

function RarityConfig.GetOrder(rarity: string?): number
	return RarityConfig.Order[tostring(rarity or "Common")] or RarityConfig.Order.Common
end

function RarityConfig.GetColor(rarity: string?): Color3
	return RarityConfig.Colors[tostring(rarity or "Common")] or RarityConfig.Colors.Common
end

return RarityConfig
