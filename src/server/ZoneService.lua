local ZoneService = {}
local context

function ZoneService.Init(newContext)
	context = newContext
end

function ZoneService.Start()
	context.Remotes.UnlockZoneRequest.OnServerEvent:Connect(function(player, zoneId)
		local zone = type(zoneId) == "string" and context.Config.Zones[zoneId]
		local data = context.DataService.Get(player)
		if not zone or not data or data.UnlockedZones[zoneId] then
			return
		end
		local orderIndex = table.find(context.Config.Zones.Order, zoneId)
		local previous = orderIndex and context.Config.Zones.Order[orderIndex - 1]
		if not previous or not data.UnlockedZones[previous] or data.Money < zone.UnlockCost then
			return
		end
		data.Money -= zone.UnlockCost
		data.UnlockedZones[zoneId] = true
		context.DataService.PushState(player)
		context.Remotes.Notify:FireClient(player, zone.DisplayName .. " unlocked!", "Success")
	end)
end

return ZoneService
