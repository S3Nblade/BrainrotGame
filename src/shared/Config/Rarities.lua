local Rarities = {
	Common = { Weight = 5200, Color = Color3.fromRGB(196, 206, 214), HP = 1, Speed = 1, Income = 1 },
	Rare = { Weight = 2600, Color = Color3.fromRGB(64, 157, 255), HP = 1.35, Speed = 1.08, Income = 2.2 },
	Epic = { Weight = 1300, Color = Color3.fromRGB(179, 86, 255), HP = 1.8, Speed = 1.16, Income = 5 },
	Legendary = { Weight = 600, Color = Color3.fromRGB(255, 183, 47), HP = 2.5, Speed = 1.25, Income = 12 },
	Mythic = { Weight = 220, Color = Color3.fromRGB(255, 72, 121), HP = 3.5, Speed = 1.35, Income = 30 },
	Divine = { Weight = 70, Color = Color3.fromRGB(76, 255, 217), HP = 5, Speed = 1.48, Income = 85 },
	Secret = { Weight = 10, Color = Color3.fromRGB(255, 255, 255), HP = 8, Speed = 1.65, Income = 300 },
}

Rarities.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Secret" }

return Rarities
