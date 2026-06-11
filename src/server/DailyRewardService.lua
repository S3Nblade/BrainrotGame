local DailyRewardService = {}
local context

local function currentDay()
	return math.floor(os.time() / 86400)
end

local function rewardText(money, gems)
	local parts = { "$" .. context.Util.FormatNumber(money) }
	if gems > 0 then
		table.insert(parts, gems .. " Gems")
	end
	return table.concat(parts, " + ")
end

function DailyRewardService.Init(newContext)
	context = newContext
end

function DailyRewardService.Start()
	context.Remotes.ClaimDailyRequest.OnServerEvent:Connect(function(player)
		local data = context.DataService.Get(player)
		if not data then
			return
		end

		local day = currentDay()
		if data.Daily.LastClaimDay >= day then
			context.Remotes.Notify:FireClient(player, "Today's reward is already claimed.", "Error")
			return
		end

		local rewardIndex = 1
		if data.Daily.LastClaimDay == day - 1 then
			rewardIndex = data.Daily.Streak % #context.Config.DailyRewards + 1
		end
		local reward = context.Config.DailyRewards[rewardIndex]
		local money = math.floor((reward.Money or 0) * context.EconomyService.GetRebirthMultiplier(data))
		local gems = reward.Gems or 0
		data.Money += money
		data.Gems += gems
		data.Daily.LastClaimDay = day
		data.Daily.Streak = rewardIndex
		context.DataService.PushState(player)
		context.Remotes.Notify:FireClient(
			player,
			"Day " .. rewardIndex .. " reward! +" .. rewardText(money, gems),
			"Success"
		)
	end)
end

return DailyRewardService
