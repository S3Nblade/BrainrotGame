local EconomyService = {}
local context

function EconomyService.GetRebirthMultiplier(data)
	return context.Config.Economy.RebirthMultiplierPerLevel ^ data.Rebirths
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
	return math.floor(
		context.Config.Economy.UpgradeBaseCost * (context.Config.Economy.UpgradeCostGrowth ^ ((item.Level or 1) - 1))
	)
end

function EconomyService.Init(newContext)
	context = newContext
end

function EconomyService.Start() end

return EconomyService
