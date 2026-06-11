local PlotService = {}
local PixelVisuals = require(script.Parent.PixelVisuals)
local context
local accrued = {}

local function findItem(data, uid)
	for index, item in ipairs(data.Inventory) do
		if item.Uid == uid then
			return item, index
		end
	end
end

local function collect(player, standIndex)
	standIndex = tonumber(standIndex)
	local amount = standIndex and accrued[player] and accrued[player][standIndex]
	if not amount or amount <= 0 then
		return 0
	end
	local payout = math.floor(amount)
	if payout <= 0 then
		return 0
	end
	accrued[player][standIndex] -= payout
	context.DataService.Update(player, function(data)
		data.Money += payout
	end)
	return payout
end

function PlotService.Init(newContext)
	context = newContext
end

function PlotService.ResetAccrued(player)
	accrued[player] = {}
end

function PlotService.RefreshPlot(player)
	local plot = context.MapService.GetPlot(player)
	local data = context.DataService.Get(player)
	if not plot or not data then
		return
	end
	for standIndex = 1, context.Config.Economy.PlotStandCount do
		local stand = plot:FindFirstChild("Stand" .. standIndex)
		if stand then
			local old = stand:FindFirstChild("Display")
			if old then
				old:Destroy()
			end
			local oldArt = stand:FindFirstChild("PixelArt")
			if oldArt then
				oldArt:Destroy()
			end
			local uid = data.Placed[tostring(standIndex)]
			local item = uid and findItem(data, uid)
			if item then
				local definition = context.Config.Brainrots[item.BrainrotId]
				local display = Instance.new("Part")
				display.Name = "Display"
				display.Anchored = true
				display.CanCollide = false
				display.Size = Vector3.new(6, 1, 6)
				display.Position = stand.Position + Vector3.new(0, 3.3, 0)
				display.Color = definition.Color
				display.Material = Enum.Material.Neon
				display.Parent = stand
				PixelVisuals.Build(
					stand,
					display,
					item.BrainrotId,
					definition.Color,
					context.Config.Rarities[definition.Rarity].Color,
					0.68,
					context.Config.Mutations[item.Mutation or "None"].Color
				)
				local spriteId = context.AssetIds.Brainrots[item.BrainrotId]
				if spriteId and spriteId ~= "rbxassetid://0" then
					local spriteGui = Instance.new("BillboardGui")
					spriteGui.Name = "Sprite"
					spriteGui.Size = UDim2.fromOffset(96, 96)
					spriteGui.Parent = display
					local image = Instance.new("ImageLabel")
					image.Size = UDim2.fromScale(1, 1)
					image.BackgroundTransparency = 1
					image.Image = spriteId
					image.ResampleMode = Enum.ResamplerMode.Pixelated
					image.Parent = spriteGui
					display.Transparency = 1
					local art = stand:FindFirstChild("PixelArt")
					if art then
						art:Destroy()
					end
				end
				local gui = Instance.new("BillboardGui")
				gui.Name = "Income"
				gui.AlwaysOnTop = true
				gui.Size = UDim2.fromOffset(150, 46)
				gui.StudsOffset = Vector3.new(0, 4, 0)
				gui.Parent = display
				local label = Instance.new("TextLabel")
				label.Name = "Label"
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
				label.TextColor3 = Color3.fromRGB(255, 231, 90)
				label.Font = Enum.Font.GothamBlack
				label.TextScaled = true
				label.Text = "$0"
				label.Parent = gui
			end
		end
	end
end

function PlotService.Start()
	context.Remotes.PlaceRequest.OnServerEvent:Connect(function(player, uid, standIndex)
		if type(uid) ~= "string" or type(standIndex) ~= "number" then
			return
		end
		standIndex = math.floor(standIndex)
		if standIndex < 1 or standIndex > context.Config.Economy.PlotStandCount then
			return
		end
		local data = context.DataService.Get(player)
		if not data or not findItem(data, uid) then
			return
		end
		local currentUid = data.Placed[tostring(standIndex)]
		if currentUid and currentUid ~= uid then
			context.Remotes.Notify:FireClient(player, "That stand is already occupied.", "Error")
			return
		end
		for key, placedUid in pairs(data.Placed) do
			if placedUid == uid then
				data.Placed[key] = nil
			end
		end
		data.Placed[tostring(standIndex)] = uid
		accrued[player] = accrued[player] or {}
		accrued[player][standIndex] = 0
		context.DataService.PushState(player)
		PlotService.RefreshPlot(player)
	end)

	context.Remotes.UnplaceRequest.OnServerEvent:Connect(function(player, uid)
		if type(uid) ~= "string" then
			return
		end
		local data = context.DataService.Get(player)
		if not data or not findItem(data, uid) then
			return
		end
		local removedStand
		for key, placedUid in pairs(data.Placed) do
			if placedUid == uid then
				removedStand = tonumber(key)
				data.Placed[key] = nil
			end
		end
		if not removedStand then
			return
		end
		collect(player, removedStand)
		accrued[player] = accrued[player] or {}
		accrued[player][removedStand] = 0
		context.DataService.PushState(player)
		PlotService.RefreshPlot(player)
		context.Remotes.Notify:FireClient(player, "Creature returned to your bag.", "Success")
	end)

	context.Remotes.TravelPlotRequest.OnServerEvent:Connect(function(player)
		local plot = context.MapService.GetPlot(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not plot or not plot.PrimaryPart or not root then
			return
		end
		local total = 0
		for standIndex = 1, context.Config.Economy.PlotStandCount do
			total += collect(player, standIndex)
		end
		root.CFrame = CFrame.new(plot.PrimaryPart.Position + Vector3.new(0, 4, 15))
		if total > 0 then
			context.Remotes.Notify:FireClient(
				player,
				"Plot collected! +$" .. context.Util.FormatNumber(total),
				"Success"
			)
		end
	end)

	context.Remotes.CollectRequest.OnServerEvent:Connect(function(player, standIndex)
		collect(player, standIndex)
	end)

	context.Remotes.UpgradeRequest.OnServerEvent:Connect(function(player, uid)
		local data = context.DataService.Get(player)
		local item = data and findItem(data, uid)
		if not item or item.Level >= context.Config.Economy.MaxBrainrotLevel then
			return
		end
		local cost = context.EconomyService.GetUpgradeCost(item)
		if data.Money < cost then
			context.Remotes.Notify:FireClient(player, "Not enough money!", "Error")
			return
		end
		data.Money -= cost
		item.Level += 1
		context.DataService.PushState(player)
		PlotService.RefreshPlot(player)
	end)

	task.spawn(function()
		while task.wait(context.Config.Economy.CollectTickSeconds) do
			for player, perStand in pairs(accrued) do
				local data = context.DataService.Get(player)
				local plot = context.MapService.GetPlot(player)
				if data and plot then
					local multiplier = context.EconomyService.GetRebirthMultiplier(data)
					if data.Boosts.MoneyUntil > os.time() then
						multiplier *= 2
					end
					for standIndex = 1, context.Config.Economy.PlotStandCount do
						local uid = data.Placed[tostring(standIndex)]
						local item = uid and findItem(data, uid)
						if item then
							perStand[standIndex] = (perStand[standIndex] or 0)
								+ context.EconomyService.GetItemIncome(item) * multiplier
							local display = plot["Stand" .. standIndex]:FindFirstChild("Display")
							if display then
								display.Income.Label.Text = "$" .. context.Util.FormatNumber(perStand[standIndex])
							end
						end
					end
				end
			end
		end
	end)

	local function initializePlayer(player)
		accrued[player] = {}
		task.spawn(function()
			for _ = 1, 20 do
				if context.MapService.GetPlot(player) and context.DataService.Get(player) then
					PlotService.RefreshPlot(player)
					return
				end
				task.wait(0.25)
			end
		end)
	end
	game:GetService("Players").PlayerAdded:Connect(initializePlayer)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		accrued[player] = nil
	end)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		initializePlayer(player)
	end
	for _, stand in ipairs(game:GetService("CollectionService"):GetTagged("PlotStand")) do
		stand.CollectPrompt.Triggered:Connect(function(player)
			local plot = stand.Parent
			if plot and plot:GetAttribute("OwnerUserId") == player.UserId then
				collect(player, stand:GetAttribute("StandIndex"))
			end
		end)
	end
end

return PlotService
