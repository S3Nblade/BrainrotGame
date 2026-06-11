local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UIController = {}
local context
local Components = require(ReplicatedStorage.UI.Components)
local Theme = require(ReplicatedStorage.UI.Theme)
local state
local gui
local counters = {}
local windows = {}
local navButtons = {}
local objectiveTitleLabel
local objectiveBodyLabel
local comboPanel
local comboLabel
local comboExpiresAt = 0
local toastQueue = {}
local toastBusy = false
local activeGuideButton
local guideTween
local rebirthConfirmUntil = 0

local function rarityRank(rarityName)
	return table.find(context.Config.Rarities.Order, rarityName) or 0
end

local function itemIncome(item)
	local definition = context.Config.Brainrots[item.BrainrotId]
	local mutation = context.Config.Mutations[item.Mutation or "None"]
	local zone = definition and context.Config.Zones[definition.Zone]
	if not definition or not mutation then
		return 0
	end
	return definition.MoneyPerSecond
		* mutation.Multiplier
		* (zone and zone.RewardMultiplier or 1)
		* context.Config.Economy.LevelIncomeGrowth ^ ((item.Level or 1) - 1)
end

local function getUpgradeCost(item)
	local levelGrowth = context.Config.Economy.UpgradeCostGrowth ^ ((item.Level or 1) - 1)
	return math.floor(
		math.max(
			context.Config.Economy.UpgradeBaseCost * levelGrowth,
			itemIncome(item) * context.Config.Economy.UpgradeIncomeSeconds
		)
	)
end

local function addFace(parent, color, locked)
	local sprite = Instance.new("Frame")
	sprite.Size = UDim2.new(1, -28, 0, 76)
	sprite.Position = UDim2.fromOffset(14, 12)
	sprite.BackgroundColor3 = locked and Color3.fromRGB(23, 25, 35) or color
	sprite.BorderSizePixel = 0
	sprite.Parent = parent
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(18, 20, 31)
	outline.Thickness = 3
	outline.Parent = sprite
	for _, x in ipairs({ 0.29, 0.67 }) do
		local eye = Instance.new("Frame")
		eye.Size = UDim2.fromOffset(12, 12)
		eye.Position = UDim2.new(x, -6, 0.35, 0)
		eye.BackgroundColor3 = locked and Color3.fromRGB(62, 66, 82) or Color3.fromRGB(245, 248, 255)
		eye.BorderSizePixel = 0
		eye.Parent = sprite
		local pupil = Instance.new("Frame")
		pupil.Size = UDim2.fromOffset(5, 5)
		pupil.Position = UDim2.fromOffset(4, 4)
		pupil.BackgroundColor3 = Color3.fromRGB(24, 26, 38)
		pupil.BorderSizePixel = 0
		pupil.Parent = eye
	end
	local mouth = Instance.new("Frame")
	mouth.Size = UDim2.fromOffset(24, 6)
	mouth.Position = UDim2.new(0.5, -12, 0.7, 0)
	mouth.BackgroundColor3 = Color3.fromRGB(38, 40, 54)
	mouth.BorderSizePixel = 0
	mouth.Parent = sprite
	return sprite
end

local function clear(container)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end
end

local function openOnly(window)
	for _, other in pairs(windows) do
		other.Visible = other == window and not window.Visible
	end
end

local function guideButton(name)
	if activeGuideButton == navButtons[name] then
		return
	end
	if guideTween then
		guideTween:Cancel()
		guideTween = nil
	end
	if activeGuideButton then
		activeGuideButton.GuideScale.Scale = 1
	end
	activeGuideButton = navButtons[name]
	if not activeGuideButton then
		return
	end
	guideTween = TweenService:Create(
		activeGuideButton.GuideScale,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.08 }
	)
	guideTween:Play()
end

local function makeCounter(parent, name, color, layoutOrder)
	local panel = Components.Panel(parent, name, UDim2.new(0.25, -8, 0, 38), UDim2.new())
	panel.BackgroundColor3 = color
	panel.LayoutOrder = layoutOrder
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(72, 38)
	sizeConstraint.MaxSize = Vector2.new(138, 38)
	sizeConstraint.Parent = panel
	local label = Components.Label(panel, name .. ": 0", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	label.TextXAlignment = Enum.TextXAlignment.Left
	counters[name] = label
	return panel
end

local function renderInventory(body)
	clear(body)
	Components.Grid(body, UDim2.fromOffset(175, 205))
	local inventory = table.clone(state.Inventory)
	table.sort(inventory, function(left, right)
		local leftDefinition = context.Config.Brainrots[left.BrainrotId]
		local rightDefinition = context.Config.Brainrots[right.BrainrotId]
		local leftRank = rarityRank(leftDefinition.Rarity)
		local rightRank = rarityRank(rightDefinition.Rarity)
		if leftRank == rightRank then
			return leftDefinition.Name < rightDefinition.Name
		end
		return leftRank > rightRank
	end)
	local placedCount = 0
	for _ in pairs(state.Placed) do
		placedCount += 1
	end
	local standsFull = placedCount >= context.Config.Economy.PlotStandCount
	for _, item in ipairs(inventory) do
		local definition = context.Config.Brainrots[item.BrainrotId]
		local rarity = context.Config.Rarities[definition.Rarity]
		local income = itemIncome(item)
		local placedStand
		for stand, uid in pairs(state.Placed) do
			if uid == item.Uid then
				placedStand = tonumber(stand)
				break
			end
		end
		local card = Components.Card(body, rarity.Color)
		addFace(card, definition.Color, false)
		local info = Components.Label(
			card,
			string.format(
				"%s\n%s %s\nLv. %d | $%s/s",
				definition.Name,
				item.Mutation ~= "None" and item.Mutation or "",
				definition.Rarity,
				item.Level,
				context.Util.FormatNumber(income)
			),
			UDim2.new(1, -12, 0, 70),
			UDim2.fromOffset(6, 92)
		)
		info.TextColor3 = rarity.Color
		local placeText = placedStand and ("REMOVE " .. placedStand) or (standsFull and "FULL" or "PLACE")
		local place = Components.Button(card, placeText, placedStand and Theme.Colors.Red or Theme.Colors.Green)
		place.Size = UDim2.new(0.48, -8, 0, 34)
		place.Position = UDim2.new(0.02, 0, 1, -40)
		place.Activated:Connect(function()
			if placedStand then
				context.Remotes.UnplaceRequest:FireServer(item.Uid)
				return
			end
			if standsFull then
				return
			end
			local occupied = {}
			for stand, uid in pairs(state.Placed) do
				occupied[tonumber(stand)] = uid
			end
			local target = 1
			while occupied[target] and target <= context.Config.Economy.PlotStandCount do
				target += 1
			end
			if target > context.Config.Economy.PlotStandCount then
				return
			end
			context.Remotes.PlaceRequest:FireServer(item.Uid, target)
		end)
		local upgradeCost = getUpgradeCost(item)
		local upgradeText = item.Level >= context.Config.Economy.MaxBrainrotLevel and "MAX"
			or ("UP $" .. context.Util.FormatNumber(upgradeCost))
		local upgrade = Components.Button(card, upgradeText, Theme.Colors.Yellow)
		upgrade.Size = UDim2.new(0.48, -8, 0, 34)
		upgrade.Position = UDim2.new(0.52, 0, 1, -40)
		upgrade.Activated:Connect(function()
			context.Remotes.UpgradeRequest:FireServer(item.Uid)
		end)
	end
end

local function renderShop(body)
	clear(body)
	Components.Grid(body, UDim2.fromOffset(220, 170))
	for _, productId in ipairs({ "Luck", "Speed", "Storage", "Money" }) do
		local product = context.Config.Shop[productId]
		local card = Components.Card(body, Theme.Colors.Purple)
		local info = Components.Label(
			card,
			product.DisplayName .. "\n" .. product.Description .. "\n$" .. context.Util.FormatNumber(product.Cost),
			UDim2.new(1, -16, 1, -58),
			UDim2.fromOffset(8, 8)
		)
		info.TextWrapped = true
		local buy = Components.Button(card, "BUY", Theme.Colors.Green)
		buy.Size = UDim2.new(1, -20, 0, 38)
		buy.Position = UDim2.new(0, 10, 1, -48)
		buy.Activated:Connect(function()
			context.Remotes.ShopPurchaseRequest:FireServer(productId)
		end)
	end
end

local function renderIndex(body)
	clear(body)
	Components.Grid(body, UDim2.fromOffset(175, 175))
	local found = 0
	local total = 0
	local ids = {}
	for id in pairs(context.Config.Brainrots) do
		table.insert(ids, id)
	end
	table.sort(ids, function(left, right)
		local leftDefinition = context.Config.Brainrots[left]
		local rightDefinition = context.Config.Brainrots[right]
		local leftRank = rarityRank(leftDefinition.Rarity)
		local rightRank = rarityRank(rightDefinition.Rarity)
		if leftRank == rightRank then
			return leftDefinition.Name < rightDefinition.Name
		end
		return leftRank < rightRank
	end)
	for _, id in ipairs(ids) do
		local definition = context.Config.Brainrots[id]
		total += 1
		local discovered = state.Discovered[id]
		if discovered then
			found += 1
		end
		local rarity = context.Config.Rarities[definition.Rarity]
		local card = Components.Card(body, rarity.Color)
		addFace(card, definition.Color, not discovered)
		local label = Components.Label(
			card,
			discovered
					and (definition.Name .. "\n" .. definition.Rarity .. "\n$" .. context.Util.FormatNumber(
						definition.MoneyPerSecond
					) .. "/s")
				or "???\nLOCKED",
			UDim2.new(1, -10, 0, 62),
			UDim2.new(0, 5, 1, -70)
		)
		label.TextColor3 = discovered and rarity.Color or Theme.Colors.Muted
	end
	windows.Index.Header.TextLabel.Text =
		string.format("INDEX - %d%%", total > 0 and math.floor(found / total * 100) or 0)
end

local function renderRebirth(body)
	clear(body)
	local cost =
		math.floor(context.Config.Economy.RebirthBaseCost * context.Config.Economy.RebirthCostGrowth ^ state.Rebirths)
	local info = Components.Label(
		body,
		string.format(
			"REBIRTH %d -> %d\n\nCost: $%s\n\nPermanent multiplier: x%s -> x%s\n\nRebirth resets money and clears your stands. Your collection stays.",
			state.Rebirths,
			state.Rebirths + 1,
			context.Util.FormatNumber(cost),
			context.Util.FormatNumber(context.Config.Economy.RebirthMultiplierPerLevel ^ state.Rebirths),
			context.Util.FormatNumber(context.Config.Economy.RebirthMultiplierPerLevel ^ (state.Rebirths + 1))
		),
		UDim2.new(1, -30, 0, 270),
		UDim2.fromOffset(15, 10)
	)
	info.TextWrapped = true
	local button = Components.Button(body, "REBIRTH NOW", Theme.Colors.Purple)
	button.Size = UDim2.new(0.7, 0, 0, 58)
	button.Position = UDim2.new(0.15, 0, 0, 290)
	button.Activated:Connect(function()
		if os.clock() > rebirthConfirmUntil then
			rebirthConfirmUntil = os.clock() + 3
			button.Text = "TAP AGAIN TO CONFIRM"
			button.BackgroundColor3 = Theme.Colors.Red
			task.delay(3, function()
				if button.Parent and os.clock() >= rebirthConfirmUntil then
					button.Text = "REBIRTH NOW"
					button.BackgroundColor3 = Theme.Colors.Purple
				end
			end)
			return
		end
		rebirthConfirmUntil = 0
		context.Remotes.RebirthRequest:FireServer()
	end)
end

local function renderZones(body)
	clear(body)
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.Parent = body
	for _, zoneId in ipairs(context.Config.Zones.Order) do
		local zone = context.Config.Zones[zoneId]
		local owned = state.UnlockedZones[zoneId]
		local button = Components.Button(
			body,
			owned and (zone.DisplayName .. " - TRAVEL")
				or string.format(
					"%s - $%s | x%s POWER",
					zone.DisplayName,
					context.Util.FormatNumber(zone.UnlockCost),
					context.Util.FormatNumber(zone.DamageMultiplier)
				),
			owned and Theme.Colors.Green or zone.AccentColor
		)
		button.Size = UDim2.new(1, -12, 0, 58)
		button.Activated:Connect(function()
			context.Remotes.UnlockZoneRequest:FireServer(zoneId)
		end)
	end
end

local function renderDaily(body)
	clear(body)
	local day = math.floor(os.time() / 86400)
	local daily = state.Daily
	local rewardIndex = 1
	if daily.LastClaimDay == day then
		rewardIndex = daily.Streak
	elseif daily.LastClaimDay == day - 1 then
		rewardIndex = daily.Streak % #context.Config.DailyRewards + 1
	end
	local reward = context.Config.DailyRewards[rewardIndex]
	local multiplier = context.Config.Economy.RebirthMultiplierPerLevel ^ state.Rebirths
	local money = math.floor((reward.Money or 0) * multiplier)
	local rewardDescription = "$" .. context.Util.FormatNumber(money)
	if (reward.Gems or 0) > 0 then
		rewardDescription ..= " + " .. reward.Gems .. " Gems"
	end

	local banner = Components.Panel(body, "DailyBanner", UDim2.new(1, -16, 0, 168), UDim2.fromOffset(8, 4))
	banner.BackgroundColor3 = Color3.fromRGB(74, 48, 96)
	local title = Components.Label(
		banner,
		daily.CanClaim and ("DAY " .. rewardIndex .. " IS READY!") or ("DAY " .. daily.Streak .. " CLAIMED"),
		UDim2.new(1, -24, 0, 42),
		UDim2.fromOffset(12, 14)
	)
	title.TextColor3 = Theme.Colors.Yellow
	local details = Components.Label(
		banner,
		daily.CanClaim and ("Today's reward\n" .. rewardDescription) or "Come back tomorrow\nto continue your streak!",
		UDim2.new(1, -24, 0, 64),
		UDim2.fromOffset(12, 56)
	)
	details.TextWrapped = true
	local claim = Components.Button(
		banner,
		daily.CanClaim and "CLAIM REWARD" or "CLAIMED TODAY",
		daily.CanClaim and Theme.Colors.Green or Theme.Colors.Muted
	)
	claim.Size = UDim2.new(0.66, 0, 0, 42)
	claim.Position = UDim2.new(0.17, 0, 1, -52)
	claim.Active = daily.CanClaim
	claim.Activated:Connect(function()
		if daily.CanClaim then
			context.Remotes.ClaimDailyRequest:FireServer()
		end
	end)

	local streakTitle = Components.Label(body, "7-DAY STREAK", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 190))
	streakTitle.TextColor3 = Theme.Colors.Yellow
	for index, entry in ipairs(context.Config.DailyRewards) do
		local card = Components.Panel(
			body,
			"Day" .. index,
			UDim2.fromOffset(94, 92),
			UDim2.fromOffset(8 + ((index - 1) % 4) * 106, 232 + math.floor((index - 1) / 4) * 104)
		)
		local completed = daily.LastClaimDay == day and index <= daily.Streak
		card.BackgroundColor3 = completed and Color3.fromRGB(48, 112, 83) or Color3.fromRGB(45, 51, 70)
		local amount = "$" .. context.Util.FormatNumber(math.floor((entry.Money or 0) * multiplier))
		if (entry.Gems or 0) > 0 then
			amount ..= "\n+" .. entry.Gems .. " Gems"
		end
		local label =
			Components.Label(card, "DAY " .. index .. "\n" .. amount, UDim2.new(1, -10, 1, -10), UDim2.fromOffset(5, 5))
		label.TextColor3 = index == rewardIndex and Theme.Colors.Yellow or Theme.Colors.Ink
	end
end

local function refresh(newState)
	state = newState
	if not state then
		return
	end
	counters.Money.Text = "$ " .. context.Util.FormatNumber(state.Money)
	counters.Gems.Text = "Gems: " .. context.Util.FormatNumber(state.Gems)
	counters.Rebirths.Text = "Rebirths: " .. state.Rebirths
	counters.Power.Text = "Power: " .. context.Util.FormatNumber(state.Power)
	local placedCount = 0
	for _ in pairs(state.Placed) do
		placedCount += 1
	end
	local quest = context.Config.Quests[state.QuestStage]
	if quest then
		local reward = quest.RewardMoney and ("$" .. context.Util.FormatNumber(quest.RewardMoney))
			or ((quest.RewardGems or 0) .. " Gems")
		objectiveTitleLabel.Text = string.format("QUEST %d/%d", state.QuestStage, #context.Config.Quests)
		objectiveBodyLabel.Text = string.format(
			"%s\n%s  %d/%d\nReward: %s",
			quest.Title,
			quest.Description,
			state.QuestProgress,
			quest.Target,
			reward
		)
	elseif placedCount == 0 then
		objectiveTitleLabel.Text = "QUESTS COMPLETE!"
		objectiveBodyLabel.Text = "Fill your stands\nComplete the index\nReach the Glitch Zone"
	else
		objectiveTitleLabel.Text = "QUESTS COMPLETE!"
		objectiveBodyLabel.Text = "Build your best squad\nChase rare mutations\nClimb the rebirths"
	end
	if state.QuestStage == 2 or state.QuestStage == 3 then
		guideButton("Inventory")
	elseif state.QuestStage == 5 then
		guideButton("Zones")
	elseif state.Daily.CanClaim then
		guideButton("Daily")
	else
		guideButton(nil)
	end
	renderInventory(windows.Inventory.Body)
	renderShop(windows.Shop.Body)
	renderIndex(windows.Index.Body)
	renderRebirth(windows.Rebirth.Body)
	renderZones(windows.Zones.Body)
	renderDaily(windows.Daily.Body)
end

local function notify(message, kind)
	table.insert(toastQueue, { Message = message, Kind = kind })
	if toastBusy then
		return
	end
	toastBusy = true
	task.spawn(function()
		while #toastQueue > 0 do
			local entry = table.remove(toastQueue, 1)
			local toast = Components.Panel(gui, "Toast", UDim2.fromOffset(360, 56), UDim2.new(0.5, -180, 0, -70))
			toast.BackgroundColor3 = entry.Kind == "Error" and Theme.Colors.Red or Theme.Colors.Green
			toast.ZIndex = 30
			local label = Components.Label(toast, entry.Message, UDim2.new(1, -20, 1, -10), UDim2.fromOffset(10, 5))
			label.ZIndex = 31
			TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
				Position = UDim2.new(0.5, -180, 0, 24),
			}):Play()
			task.wait(2.1)
			local tween = TweenService:Create(toast, TweenInfo.new(0.2), { Position = UDim2.new(0.5, -180, 0, -70) })
			tween:Play()
			tween.Completed:Wait()
			toast:Destroy()
		end
		toastBusy = false
	end)
end

function UIController.Init(newContext)
	context = newContext
	gui = Instance.new("ScreenGui")
	gui.Name = "PixelHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = context.PlayerGui
	local title = Components.Panel(gui, "GameTitle", UDim2.fromOffset(230, 40), UDim2.new(0.5, -115, 0, 10))
	title.BackgroundColor3 = Color3.fromRGB(36, 31, 61)
	local titleLabel = Components.Label(title, "PIXEL BRAINROT", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	titleLabel.TextColor3 = Theme.Colors.Yellow
	local top = Instance.new("Frame")
	top.Name = "Counters"
	top.Size = UDim2.new(1, -24, 0, 42)
	top.Position = UDim2.fromOffset(12, 58)
	top.BackgroundTransparency = 1
	top.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = top
	makeCounter(top, "Money", Theme.Colors.Green, 1)
	makeCounter(top, "Gems", Theme.Colors.Blue, 2)
	makeCounter(top, "Rebirths", Theme.Colors.Purple, 3)
	makeCounter(top, "Power", Color3.fromRGB(246, 154, 70), 4)

	local objective = Components.Panel(gui, "Objective", UDim2.fromOffset(270, 104), UDim2.fromOffset(14, 112))
	objective.BackgroundColor3 = Color3.fromRGB(35, 41, 58)
	objectiveTitleLabel = Components.Label(objective, "FIRST QUEST", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 8))
	objectiveTitleLabel.TextColor3 = Theme.Colors.Yellow
	objectiveTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectiveBodyLabel = Components.Label(
		objective,
		"Find a pixel creature\nATTACK: click / Space\nCAPTURE: E when stunned",
		UDim2.new(1, -20, 0, 65),
		UDim2.fromOffset(10, 32)
	)
	objectiveBodyLabel.TextXAlignment = Enum.TextXAlignment.Left
	objectiveBodyLabel.TextYAlignment = Enum.TextYAlignment.Top

	comboPanel = Components.Panel(gui, "CaptureCombo", UDim2.fromOffset(230, 58), UDim2.new(1, -248, 0, 165))
	comboPanel.BackgroundColor3 = Color3.fromRGB(108, 58, 137)
	comboPanel.Visible = false
	comboLabel = Components.Label(comboPanel, "COMBO x1", UDim2.new(1, -16, 1, -10), UDim2.fromOffset(8, 5))
	comboLabel.TextColor3 = Theme.Colors.Yellow

	local nav = Instance.new("Frame")
	nav.Name = "Navigation"
	nav.Position = UDim2.fromOffset(18, 227)
	nav.Size = UDim2.new(1, -36, 0, 58)
	nav.BackgroundTransparency = 1
	nav.Parent = gui
	local navConstraint = Instance.new("UISizeConstraint")
	navConstraint.MaxSize = Vector2.new(690, 58)
	navConstraint.Parent = nav
	local navLayout = Instance.new("UIListLayout")
	navLayout.Padding = UDim.new(0, 8)
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Parent = nav

	for index, spec in ipairs({
		{ "Inventory", "BAG", Theme.Colors.Blue },
		{ "Shop", "SHOP", Theme.Colors.Green },
		{ "Index", "INDEX", Theme.Colors.Yellow },
		{ "Zones", "ZONES", Theme.Colors.Red },
		{ "Daily", "DAILY", Color3.fromRGB(246, 154, 70) },
		{ "Rebirth", "REBIRTH", Theme.Colors.Purple },
	}) do
		local window, body = Components.Window(gui, spec[1], string.upper(spec[1]))
		windows[spec[1]] = window
		local button = Components.Button(nav, spec[2], spec[3])
		navButtons[spec[1]] = button
		button.Size = UDim2.new(1 / 7, -7, 0, 50)
		local guideScale = Instance.new("UIScale")
		guideScale.Name = "GuideScale"
		guideScale.Parent = button
		button.LayoutOrder = index
		button.Activated:Connect(function()
			openOnly(window)
		end)
	end
	local plotButton = Components.Button(nav, "PLOT", Color3.fromRGB(91, 224, 209))
	plotButton.Size = UDim2.new(1 / 7, -7, 0, 50)
	plotButton.LayoutOrder = 7
	plotButton.Activated:Connect(function()
		for _, window in pairs(windows) do
			window.Visible = false
		end
		context.Remotes.TravelPlotRequest:FireServer()
	end)
end

function UIController.Start()
	context.Remotes.StateChanged.OnClientEvent:Connect(refresh)
	context.Remotes.Notify.OnClientEvent:Connect(notify)
	context.Remotes.ComboChanged.OnClientEvent:Connect(function(count, duration)
		comboExpiresAt = os.clock() + duration
		local bonus = math.floor((count - 1) * context.Config.Economy.CaptureComboRewardPerLevel * 100)
		comboLabel.Text = string.format("CAPTURE COMBO x%d  +%d%%", count, bonus)
		comboPanel.Visible = true
		comboPanel.Size = UDim2.fromOffset(190, 48)
		TweenService:Create(comboPanel, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(230, 58) })
			:Play()
	end)
	RunService.RenderStepped:Connect(function()
		if comboPanel.Visible and os.clock() >= comboExpiresAt then
			comboPanel.Visible = false
		end
	end)
	task.spawn(function()
		local success, initial = pcall(function()
			return context.Remotes.GetState:InvokeServer()
		end)
		if success and initial then
			refresh(initial)
		end
	end)
end

return UIController
