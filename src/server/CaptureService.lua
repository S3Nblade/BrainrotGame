local CaptureService = {}
local context
local cooldowns = {}
local random = Random.new()

local function distanceTo(player, position)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - position).Magnitude or math.huge
end

local function rollMutation(player)
	local entries = {}
	local data = context.DataService.Get(player)
	local luckMultiplier = data and data.Boosts.LuckUntil > os.time() and 2 or 1
	for name, mutation in pairs(context.Config.Mutations) do
		local weight = mutation.Weight
		if name ~= "None" then
			weight *= luckMultiplier
		end
		table.insert(entries, { Value = name, Weight = weight })
	end
	return context.Util.WeightedChoice(entries, random)
end

function CaptureService.Init(newContext)
	context = newContext
end

function CaptureService.Start()
	context.Remotes.AttackRequest.OnServerEvent:Connect(function(player, model)
		local record = typeof(model) == "Instance" and context.BrainrotSpawnService.Get(model)
		local now = os.clock()
		if not record or record.Stunned or (cooldowns[player] or 0) > now then
			return
		end
		local data = context.DataService.Get(player)
		local zoneId = model:GetAttribute("ZoneId")
		if
			not data
			or not data.UnlockedZones[zoneId]
			or distanceTo(player, record.Root.Position) > context.Config.Economy.AttackRange
		then
			return
		end
		if record.Attacker and record.Attacker ~= player then
			return
		end
		cooldowns[player] = now + context.Config.Economy.AttackCooldown
		record.Attacker = player
		record.ChaseEnds = now + context.Config.Economy.ChaseDuration
		local damage = context.Config.Economy.BaseDamage
		record.HP = math.max(0, record.HP - damage)
		record.Root.Status.HPBack.Fill.Size = UDim2.fromScale(record.HP / record.MaxHP, 1)
		context.Remotes.DamagePopup:FireAllClients(record.Root.Position, damage)
		if record.HP <= 0 then
			record.Stunned = true
			record.Root.Color = Color3.fromRGB(155, 155, 165)
			record.Root.Status.NameLabel.Text = record.Definition.Name .. " - PRESS E"
		end
	end)

	context.Remotes.CaptureRequest.OnServerEvent:Connect(function(player, model)
		local record = typeof(model) == "Instance" and context.BrainrotSpawnService.Get(model)
		if not record or not record.Stunned or record.Attacker ~= player then
			return
		end
		if distanceTo(player, record.Root.Position) > context.Config.Economy.CaptureRange then
			return
		end
		local data = context.DataService.Get(player)
		if not data then
			return
		end
		local capacity = context.Config.Economy.InventoryBaseCapacity
			+ data.StorageLevel * context.Config.Economy.StorageUpgradeAmount
		if #data.Inventory >= capacity then
			context.Remotes.Notify:FireClient(player, "Inventory full!", "Error")
			return
		end
		local mutation = rollMutation(player)
		local item = {
			Uid = context.Util.NewId(),
			BrainrotId = record.Id,
			Mutation = mutation,
			Level = 1,
		}
		table.insert(data.Inventory, item)
		data.Discovered[record.Id] = true
		local position = record.Root.Position
		context.BrainrotSpawnService.Remove(model)
		context.DataService.PushState(player)
		context.Remotes.CaptureEffect:FireAllClients(position, context.Config.Mutations[mutation].Color)
		context.Remotes.RevealBrainrot:FireClient(player, item)
	end)
end

return CaptureService
