--!nonstrict
-- ReplicatedStorage/Configs/MutationConfig

local MutationConfig = {}

MutationConfig.RollTable = {
	{
		Name = "Normal",
		Weight = 720,
		MoneyMultiplier = 1,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(255, 255, 255),
	},

	{
		Name = "Golden",
		Weight = 180,
		MoneyMultiplier = 1.25,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(255, 220, 45),
	},

	{
		Name = "Diamond",
		Weight = 60,
		MoneyMultiplier = 1.6,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(90, 235, 255),
	},

	{
		Name = "Rainbow",
		Weight = 25,
		MoneyMultiplier = 2.25,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(255, 80, 220),
	},

	{
		Name = "Shadow",
		Weight = 18,
		MoneyMultiplier = 2.75,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(135, 55, 215),
	},

	{
		Name = "Lava",
		Weight = 12,
		MoneyMultiplier = 3.2,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(255, 65, 10),
	},

	{
		Name = "Frozen",
		Weight = 12,
		MoneyMultiplier = 3.2,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(120, 245, 255),
	},

	{
		Name = "Toxic",
		Weight = 8,
		MoneyMultiplier = 4,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(115, 255, 35),
	},

	{
		Name = "Electric",
		Weight = 6,
		MoneyMultiplier = 4.8,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(65, 170, 255),
	},

	{
		Name = "Galaxy",
		Weight = 4,
		MoneyMultiplier = 6,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(125, 75, 255),
	},

	{
		Name = "Hacked",
		Weight = 3,
		MoneyMultiplier = 7.5,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(55, 255, 90),
	},

	{
		Name = "Corrupted",
		Weight = 2,
		MoneyMultiplier = 10,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(175, 35, 255),
	},
}

MutationConfig.ByName = {}

for _, mutation in ipairs(MutationConfig.RollTable) do
	MutationConfig.ByName[mutation.Name] = mutation
end

function MutationConfig.Get(name)
	return MutationConfig.ByName[tostring(name or "Normal")] or MutationConfig.ByName.Normal
end

function MutationConfig.Roll()
	local totalWeight = 0

	for _, mutation in ipairs(MutationConfig.RollTable) do
		totalWeight += mutation.Weight
	end

	local roll = math.random() * totalWeight
	local current = 0

	for _, mutation in ipairs(MutationConfig.RollTable) do
		current += mutation.Weight

		if roll <= current then
			return mutation
		end
	end

	return MutationConfig.ByName.Normal
end

function MutationConfig.ApplyAttributes(instance, mutation)
	if not instance or not mutation then
		return
	end

	instance:SetAttribute("Mutation", mutation.Name)
	instance:SetAttribute("MutationName", mutation.Name)
	instance:SetAttribute("MutationMoneyMultiplier", mutation.MoneyMultiplier)
	instance:SetAttribute("MutationStrengthMultiplier", mutation.StrengthMultiplier)

	instance:SetAttribute("MutationColorR", math.floor(mutation.Color.R * 255))
	instance:SetAttribute("MutationColorG", math.floor(mutation.Color.G * 255))
	instance:SetAttribute("MutationColorB", math.floor(mutation.Color.B * 255))
end

return MutationConfig
