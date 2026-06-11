local EconomyService = {}
local context

function EconomyService.GetRebirthMultiplier(data)
	return context.Config.Economy.RebirthMultiplierPerLevel ^ data.Rebirths
end

function EconomyService.GetPlayerDamage(data)
	local zoneMultiplier = 1
	for _, zoneId in ipairs(context.Config.Zones.Order) do
		if data.UnlockedZones[zoneId] then
			zoneMultiplier = math.max(zoneMultiplier, context.Config.Zones[zoneId].DamageMultiplier or 1)
		end
	end
	return math.floor(
		context.Config.Economy.BaseDamage * zoneMultiplier * context.Config.Economy.DamageRebirthGrowth ^ data.Rebirths
	)
end

function EconomyService.GetItemIncome(item)
	local definition = context.Config.Brainrots[item.BrainrotId]
	local mutation = context.Config.Mutations[item.Mutation or "None"]
	if not definition or not mutation then
		return 0
	end
	local zone = context.Config.Zones[definition.Zone]
	return definition.MoneyPerSecond
		* mutation.Multiplier
		* (zone and zone.RewardMultiplier or 1)
		* (context.Config.Economy.LevelIncomeGrowth ^ ((item.Level or 1) - 1))
end

function EconomyService.GetUpgradeCost(item)
	local levelGrowth = context.Config.Economy.UpgradeCostGrowth ^ ((item.Level or 1) - 1)
	local baseCost = context.Config.Economy.UpgradeBaseCost * levelGrowth
	local incomeCost = EconomyService.GetItemIncome(item) * context.Config.Economy.UpgradeIncomeSeconds
	return math.floor(math.max(baseCost, incomeCost))
end

function EconomyService.Init(newContext)
	context = newContext
end

function EconomyService.Start() end

return EconomyService
