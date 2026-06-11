local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIController = {}
local context
local Components = require(ReplicatedStorage.UI.Components)
local Theme = require(ReplicatedStorage.UI.Theme)
local state
local gui
local counters = {}
local windows = {}

local function clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function openOnly(window)
	for _, other in pairs(windows) do
		other.Visible = other == window and not window.Visible
	end
end

local function makeCounter(parent, name, color)
	local panel = Components.Panel(parent, name, UDim2.fromOffset(190, 48), UDim2.new())
	panel.BackgroundColor3 = color
	local label = Components.Label(panel, name .. ": 0", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4))
	label.TextXAlignment = Enum.TextXAlignment.Left
	counters[name] = label
	return panel
end

local function renderInventory(body)
	clear(body)
	Components.Grid(body, UDim2.fromOffset(175, 205))
	for _, item in ipairs(state.Inventory) do
		local definition = context.Config.Brainrots[item.BrainrotId]
		local rarity = context.Config.Rarities[definition.Rarity]
		local mutation = context.Config.Mutations[item.Mutation]
		local card = Components.Card(body, rarity.Color)
		local sprite = Instance.new("Frame")
		sprite.Size = UDim2.new(1, -28, 0, 76)
		sprite.Position = UDim2.fromOffset(14, 12)
		sprite.BackgroundColor3 = definition.Color
		sprite.BorderSizePixel = 0
		sprite.Parent = card
		local info = Components.Label(
			card,
			string.format(
				"%s\n%s %s\nLv. %d | $%s/s",
				definition.Name,
				item.Mutation ~= "None" and item.Mutation or "",
				definition.Rarity,
				item.Level,
				context.Util.FormatNumber(
					definition.MoneyPerSecond
						* mutation.Multiplier
						* context.Config.Economy.LevelIncomeGrowth ^ (item.Level - 1)
				)
			),
			UDim2.new(1, -12, 0, 70),
			UDim2.fromOffset(6, 92)
		)
		info.TextColor3 = rarity.Color
		local place = Components.Button(card, "PLACE", Theme.Colors.Green)
		place.Size = UDim2.new(0.48, -8, 0, 34)
		place.Position = UDim2.new(0.02, 0, 1, -40)
		place.Activated:Connect(function()
			local occupied = {}
			for stand, uid in pairs(state.Placed) do
				occupied[tonumber(stand)] = uid
			end
			local target = 1
			while occupied[target] and target <= context.Config.Economy.PlotStandCount do
				target += 1
			end
			if target > context.Config.Economy.PlotStandCount then
				target = 1
			end
			context.Remotes.PlaceRequest:FireServer(item.Uid, target)
		end)
		local upgrade = Components.Button(card, "UP", Theme.Colors.Yellow)
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
	for productId, product in pairs(context.Config.Shop) do
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
	for id, definition in pairs(context.Config.Brainrots) do
		total += 1
		local discovered = state.Discovered[id]
		if discovered then
			found += 1
		end
		local rarity = context.Config.Rarities[definition.Rarity]
		local card = Components.Card(body, rarity.Color)
		local visual = Instance.new("Frame")
		visual.Size = UDim2.new(1, -30, 0, 80)
		visual.Position = UDim2.fromOffset(15, 12)
		visual.BackgroundColor3 = discovered and definition.Color or Color3.fromRGB(23, 25, 35)
		visual.Parent = card
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
			"REBIRTH %d → %d\n\nCost: $%s\n\nPermanent multiplier: x%s → x%s\n\nRebirth resets money and clears your stands. Your collection stays.",
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
			owned and (zone.DisplayName .. " - UNLOCKED")
				or (zone.DisplayName .. " - $" .. context.Util.FormatNumber(zone.UnlockCost)),
			owned and Theme.Colors.Green or zone.AccentColor
		)
		button.Size = UDim2.new(1, -12, 0, 58)
		button.Active = not owned
		button.Activated:Connect(function()
			if not owned then
				context.Remotes.UnlockZoneRequest:FireServer(zoneId)
			end
		end)
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
	renderInventory(windows.Inventory.Body)
	renderShop(windows.Shop.Body)
	renderIndex(windows.Index.Body)
	renderRebirth(windows.Rebirth.Body)
	renderZones(windows.Zones.Body)
end

local function notify(message, kind)
	local toast = Components.Panel(gui, "Toast", UDim2.fromOffset(360, 56), UDim2.new(0.5, -180, 0, -70))
	toast.BackgroundColor3 = kind == "Error" and Theme.Colors.Red or Theme.Colors.Green
	toast.ZIndex = 30
	local label = Components.Label(toast, message, UDim2.new(1, -20, 1, -10), UDim2.fromOffset(10, 5))
	label.ZIndex = 31
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, -180, 0, 24) })
		:Play()
	task.delay(2.4, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.2), { Position = UDim2.new(0.5, -180, 0, -70) })
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

function UIController.Init(newContext)
	context = newContext
	gui = Instance.new("ScreenGui")
	gui.Name = "PixelHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = context.PlayerGui
	local top = Instance.new("Frame")
	top.Name = "Counters"
	top.Size = UDim2.new(1, -24, 0, 52)
	top.Position = UDim2.fromOffset(12, 10)
	top.BackgroundTransparency = 1
	top.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.Parent = top
	makeCounter(top, "Money", Theme.Colors.Green)
	makeCounter(top, "Gems", Theme.Colors.Blue)
	makeCounter(top, "Rebirths", Theme.Colors.Purple)

	local nav = Instance.new("Frame")
	nav.Name = "Navigation"
	nav.AnchorPoint = Vector2.new(0.5, 1)
	nav.Position = UDim2.new(0.5, 0, 1, -14)
	nav.Size = UDim2.new(0.9, 0, 0, 58)
	nav.BackgroundTransparency = 1
	nav.Parent = gui
	local navConstraint = Instance.new("UISizeConstraint")
	navConstraint.MaxSize = Vector2.new(760, 58)
	navConstraint.Parent = nav
	local navLayout = Instance.new("UIGridLayout")
	navLayout.CellPadding = UDim2.fromOffset(8, 0)
	navLayout.CellSize = UDim2.new(0.19, -7, 1, 0)
	navLayout.FillDirectionMaxCells = 5
	navLayout.Parent = nav

	for _, spec in ipairs({
		{ "Inventory", "BAG", Theme.Colors.Blue },
		{ "Shop", "SHOP", Theme.Colors.Green },
		{ "Index", "INDEX", Theme.Colors.Yellow },
		{ "Zones", "ZONES", Theme.Colors.Red },
		{ "Rebirth", "REBIRTH", Theme.Colors.Purple },
	}) do
		local window, body = Components.Window(gui, spec[1], string.upper(spec[1]))
		windows[spec[1]] = window
		local button = Components.Button(nav, spec[2], spec[3])
		button.Activated:Connect(function()
			openOnly(window)
		end)
	end
end

function UIController.Start()
	context.Remotes.StateChanged.OnClientEvent:Connect(refresh)
	context.Remotes.Notify.OnClientEvent:Connect(notify)
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
