--!strict
-- Runtime Brainrot definitions. Keep ModelName matching the Studio model exactly.

local BrainrotConfig = {}

local rarityConfigModule = script.Parent:FindFirstChild("RarityConfig")
local rarityConfig = nil

if rarityConfigModule and rarityConfigModule:IsA("ModuleScript") then
	local ok, result = pcall(require, rarityConfigModule)
	if ok and type(result) == "table" then
		rarityConfig = result
	end
end

BrainrotConfig.RarityOrder = rarityConfig and rarityConfig.Order or {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
}

BrainrotConfig.RarityColors = rarityConfig and rarityConfig.Colors or {
	Common = Color3.fromRGB(236, 242, 248),
	Uncommon = Color3.fromRGB(111, 236, 135),
	Rare = Color3.fromRGB(77, 174, 255),
	Epic = Color3.fromRGB(194, 91, 255),
	Legendary = Color3.fromRGB(255, 199, 61),
	Mythic = Color3.fromRGB(255, 83, 166),
	Secret = Color3.fromRGB(67, 255, 192),
}

BrainrotConfig.List = {
	{
		Id = "PipoNuggetini",
		DisplayName = "Pipo Nuggetini",
		Rarity = "Common",
		CashPerSecond = 6,
		CaptureReward = 45,
		HP = 45,
		Speed = 12,
		SpawnWeight = 100,
		ZoneUnlockRequirement = "Starter",
		ModelName = "PipoNuggetini",
		IconAssetId = nil,
		ShowcaseScale = 1,
		ShowcaseRotationOffset = Vector3.new(0, 0, 0),
		IdleAnimationId = 115565698981462,
		RunAnimationId = 98948126492086,
		StunAnimationId = 119409515712951,
		Mutation = {},
	},
}

BrainrotConfig.ById = {}
BrainrotConfig.ByModelName = {}

for _, entry in ipairs(BrainrotConfig.List) do
	BrainrotConfig.ById[entry.Id] = entry
	BrainrotConfig.ByModelName[entry.ModelName] = entry
end

function BrainrotConfig.GetById(id: string)
	return BrainrotConfig.ById[id]
end

function BrainrotConfig.GetByModelName(modelName: string)
	return BrainrotConfig.ByModelName[modelName]
end

return BrainrotConfig
