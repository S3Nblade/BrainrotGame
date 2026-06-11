local OfflineEarningsService = {}
local context

local function findInventoryItem(data, uid)
	for _, item in ipairs(data.Inventory) do
		if item.Uid == uid then
			return item
		end
	end
	return nil
end

function OfflineEarningsService.FormatDuration(seconds)
	local hours = math.floor(seconds / 3600)
	local minutes = math.max(1, math.floor((seconds % 3600) / 60))
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	return string.format("%dm", minutes)
end

function OfflineEarningsService.Apply(data, timestamp)
	local now = timestamp or os.time()
	local lastSeen = tonumber(data.LastSeen) or 0
	data.LastSeen = now
	if lastSeen <= 0 then
		return 0, 0
	end

	local economy = context.Config.Economy
	local rawSeconds = math.max(0, now - lastSeen)
	if rawSeconds < economy.OfflineEarningsMinimumSeconds then
		return 0, rawSeconds
	end

	local incomePerSecond = 0
	local counted = {}
	for _, uid in pairs(data.Placed) do
		if type(uid) == "string" and not counted[uid] then
			counted[uid] = true
			local item = findInventoryItem(data, uid)
			if item then
				incomePerSecond += context.EconomyService.GetItemIncome(item)
			end
		end
	end

	local creditedSeconds = math.min(rawSeconds, economy.OfflineEarningsCapSeconds)
	local reward = math.floor(
		incomePerSecond
			* context.EconomyService.GetRebirthMultiplier(data)
			* creditedSeconds
			* economy.OfflineEarningsRate
	)
	if reward > 0 then
		data.Money += reward
	end
	return reward, creditedSeconds
end

function OfflineEarningsService.Init(newContext)
	context = newContext
end

function OfflineEarningsService.Start() end

return OfflineEarningsService
