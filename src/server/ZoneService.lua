local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ZoneService = {}
local context
local lastAllowedPositions = {}
local warningCooldowns = {}

function ZoneService.Init(newContext)
	context = newContext
end

function ZoneService.Start()
	context.Remotes.UnlockZoneRequest.OnServerEvent:Connect(function(player, zoneId)
		local zone = type(zoneId) == "string" and context.Config.Zones[zoneId]
		local data = context.DataService.Get(player)
		if not zone or not data then
			return
		end
		if data.UnlockedZones[zoneId] then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(zone.Center + Vector3.new(0, 4, 0))
			end
			return
		end
		local orderIndex = table.find(context.Config.Zones.Order, zoneId)
		local previous = orderIndex and context.Config.Zones.Order[orderIndex - 1]
		if not previous or not data.UnlockedZones[previous] then
			context.Remotes.Notify:FireClient(player, "Unlock the previous zone first.", "Error")
			return
		end
		if data.Money < zone.UnlockCost then
			context.Remotes.Notify:FireClient(
				player,
				"You need $" .. context.Util.FormatNumber(zone.UnlockCost) .. " to unlock this zone.",
				"Error"
			)
			return
		end
		data.Money -= zone.UnlockCost
		data.UnlockedZones[zoneId] = true
		context.DataService.PushState(player)
		context.QuestService.Progress(player, "UnlockZone", zoneId)
		context.Remotes.Notify:FireClient(player, zone.DisplayName .. " unlocked!", "Success")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(zone.Center + Vector3.new(0, 4, 0))
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed < 0.15 then
			return
		end
		elapsed = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local data = context.DataService.Get(player)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if data and root then
				local zoneId = context.MapService.GetZoneAt(root.Position)
				if zoneId and data.UnlockedZones[zoneId] then
					lastAllowedPositions[player] = root.Position
				elseif zoneId and not data.UnlockedZones[zoneId] then
					local fallback = lastAllowedPositions[player]
						or context.Config.Zones[context.Config.Zones.Order[1]].Center + Vector3.new(0, 4, 0)
					root.CFrame = CFrame.new(fallback + Vector3.new(0, 2, 0))
					local now = os.clock()
					if (warningCooldowns[player] or 0) <= now then
						warningCooldowns[player] = now + 2
						context.Remotes.Notify:FireClient(player, "That zone is locked. Unlock it from ZONES!", "Error")
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAllowedPositions[player] = nil
		warningCooldowns[player] = nil
	end)
end

return ZoneService
