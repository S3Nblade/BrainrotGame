local RebirthService = {}
local context

function RebirthService.GetCost(rebirths)
	return math.floor(context.Config.Economy.RebirthBaseCost * (context.Config.Economy.RebirthCostGrowth ^ rebirths))
end

function RebirthService.Init(newContext)
	context = newContext
end

function RebirthService.Start()
	context.Remotes.RebirthRequest.OnServerEvent:Connect(function(player)
		local data = context.DataService.Get(player)
		if not data then
			return
		end
		local cost = RebirthService.GetCost(data.Rebirths)
		if data.Money < cost then
			context.Remotes.Notify:FireClient(
				player,
				"You need $" .. context.Util.FormatNumber(cost) .. " to rebirth.",
				"Error"
			)
			return
		end
		data.Money = 0
		data.Rebirths += 1
		data.Placed = {}
		context.PlotService.ResetAccrued(player)
		context.DataService.PushState(player)
		context.PlotService.RefreshPlot(player)
		context.Remotes.Notify:FireClient(player, "Rebirth complete! Permanent income multiplied.", "Success")
	end)
end

return RebirthService
