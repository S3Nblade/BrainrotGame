--!nonstrict
-- ServerScriptService/PlotFloorUpgrade.server.lua
-- FULL REPLACEMENT
-- New system:
-- Player buys ONE Brainrot slot at a time.
-- First floor has its normal maximum slots.
-- When first floor is full, next slot creates floor 2 with 1 slot.
-- Then each purchase adds another slot to floor 2.
-- Saves unlocked slot count to DataStore.
-- Fixes old broken generated floors.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SLOT_STORE = DataStoreService:GetDataStore("PlayerPlotUnlockedSlots_v1")

local SCRIPT_VERSION = 10

local MAX_FLOORS = 5
local FLOOR_HEIGHT = 22

local UPGRADE_BUTTON_NAME = "PlotSlotUpgradeButton"
local OLD_UPGRADE_BUTTON_NAME = "PlotFloorUpgradeButton"

local GENERATED_FLOOR_PREFIX = "Generated Plot Floor "
local GENERATED_LADDER_PREFIX = "Generated Ladder "

local SLOT_PRICE_START = 25000
local SLOT_PRICE_MULTIPLIER = 1.35

local notifyRemote = ReplicatedStorage:FindFirstChild("NotifyUser")
if not notifyRemote then
	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = "NotifyUser"
	notifyRemote.Parent = ReplicatedStorage
end

local updateCoinsEvent = ReplicatedStorage:FindFirstChild("UpdateCoins")
if not updateCoinsEvent then
	updateCoinsEvent = Instance.new("RemoteEvent")
	updateCoinsEvent.Name = "UpdateCoins"
	updateCoinsEvent.Parent = ReplicatedStorage
end

local playerSlotCache = {}
local connectedPrompts = {}

local function formatMoney(value)
	value = tonumber(value) or 0

	if value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end

	return tostring(math.floor(value))
end

local function notify(player, message, variant)
	notifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function getPlotsFolder()
	return Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
end

local function getFirstBasePart(container)
	if not container then
		return nil
	end

	if container:IsA("BasePart") then
		return container
	end

	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function getAllBaseParts(container)
	local parts = {}

	if not container then
		return parts
	end

	if container:IsA("BasePart") then
		table.insert(parts, container)
	end

	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(parts, obj)
		end
	end

	return parts
end

local function getAllPlots()
	local folder = getPlotsFolder()
	local plots = {}

	if not folder then
		return plots
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") then
			if getFirstBasePart(child) then
				table.insert(plots, child)
			end
		end
	end

	return plots
end

local function playerOwnsPlot(player, plot)
	if not player or not plot then
		return false
	end

	return tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(plot:GetAttribute("OwnerName")) == player.Name
end

local function getPlayerPlot(player)
	for _, plot in ipairs(getAllPlots()) do
		if playerOwnsPlot(player, plot) then
			return plot
		end
	end

	return nil
end

local function getMoneyValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local money = leaderstats:FindFirstChild("Money")
		or leaderstats:FindFirstChild("Coins")
		or leaderstats:FindFirstChild("Cash")

	if money and money:IsA("ValueBase") then
		return money
	end

	money = Instance.new("NumberValue")
	money.Name = "Money"
	money.Value = tonumber(player:GetAttribute("Money"))
		or tonumber(player:GetAttribute("Coins"))
		or tonumber(player:GetAttribute("Cash"))
		or 0
	money.Parent = leaderstats

	return money
end

local function setMoney(player, amount)
	amount = math.max(0, math.floor(tonumber(amount) or 0))

	local money = getMoneyValue(player)
	money.Value = amount

	player:SetAttribute("Money", amount)
	player:SetAttribute("Coins", amount)
	player:SetAttribute("Cash", amount)

	updateCoinsEvent:FireClient(player, amount)
end

local function getBoundsFromParts(parts)
	if #parts == 0 then
		return nil
	end

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(parts) do
		local cf = part.CFrame
		local size = part.Size

		for _, x in ipairs({ -0.5, 0.5 }) do
			for _, y in ipairs({ -0.5, 0.5 }) do
				for _, z in ipairs({ -0.5, 0.5 }) do
					local p = cf * Vector3.new(size.X * x, size.Y * y, size.Z * z)

					minV = Vector3.new(
						math.min(minV.X, p.X),
						math.min(minV.Y, p.Y),
						math.min(minV.Z, p.Z)
					)

					maxV = Vector3.new(
						math.max(maxV.X, p.X),
						math.max(maxV.Y, p.Y),
						math.max(maxV.Z, p.Z)
					)
				end
			end
		end
	end

	return {
		min = minV,
		max = maxV,
		center = (minV + maxV) * 0.5,
		size = maxV - minV,
	}
end

local function getFirstFloorBaseObjects(plot)
	local objects = {}

	for _, child in ipairs(plot:GetChildren()) do
		if child.Name == "BASE FLOOR" or child.Name == "Pillar" then
			table.insert(objects, child)
		end
	end

	return objects
end

local function getFirstFloorStands(plot)
	local stands = {}

	for _, child in ipairs(plot:GetChildren()) do
		if child.Name == "Brainrot Stand" then
			local part = getFirstBasePart(child)

			if part then
				table.insert(stands, {
					container = child,
					part = part,
				})
			end
		end
	end

	table.sort(stands, function(a, b)
		if math.abs(a.part.Position.X - b.part.Position.X) > 0.1 then
			return a.part.Position.X < b.part.Position.X
		end

		return a.part.Position.Z < b.part.Position.Z
	end)

	return stands
end

local function getFirstFloorMoneyCollects(plot)
	local collects = {}

	for _, child in ipairs(plot:GetChildren()) do
		if child.Name == "Money Collect" then
			local part = child:FindFirstChild("green", true)

			if not part or not part:IsA("BasePart") then
				part = getFirstBasePart(child)
			end

			if part then
				table.insert(collects, {
					container = child,
					part = part,
				})
			end
		end
	end

	return collects
end

local function getFirstFloorSlotTemplates(plot)
	local stands = getFirstFloorStands(plot)
	local collects = getFirstFloorMoneyCollects(plot)
	local usedCollects = {}
	local slots = {}

	for _, stand in ipairs(stands) do
		local nearestCollect = nil
		local nearestDistance = math.huge

		for _, collect in ipairs(collects) do
			if not usedCollects[collect] then
				local distance = (stand.part.Position - collect.part.Position).Magnitude

				if distance < nearestDistance then
					nearestDistance = distance
					nearestCollect = collect
				end
			end
		end

		if nearestCollect then
			usedCollects[nearestCollect] = true

			table.insert(slots, {
				stand = stand.container,
				money = nearestCollect.container,
				standPart = stand.part,
				moneyPart = nearestCollect.part,
			})
		end
	end

	return slots
end

local function getFirstFloorBounds(plot)
	local parts = {}

	for _, obj in ipairs(getFirstFloorBaseObjects(plot)) do
		for _, part in ipairs(getAllBaseParts(obj)) do
			table.insert(parts, part)
		end
	end

	for _, slot in ipairs(getFirstFloorSlotTemplates(plot)) do
		for _, part in ipairs(getAllBaseParts(slot.stand)) do
			table.insert(parts, part)
		end

		for _, part in ipairs(getAllBaseParts(slot.money)) do
			table.insert(parts, part)
		end
	end

	return getBoundsFromParts(parts) or getBoundsFromParts(getAllBaseParts(plot))
end

local function getBaseSlotsPerFloor(plot)
	local count = #getFirstFloorSlotTemplates(plot)

	if count <= 0 then
		count = 10
	end

	plot:SetAttribute("BaseSlotsPerFloor", count)

	return count
end

local function getMaxTotalSlots(plot)
	return getBaseSlotsPerFloor(plot) * MAX_FLOORS
end

local function getSlotPrice(plot, nextSlot)
	local baseSlots = getBaseSlotsPerFloor(plot)
	local extraIndex = math.max(1, nextSlot - baseSlots)

	local raw = SLOT_PRICE_START * (SLOT_PRICE_MULTIPLIER ^ (extraIndex - 1))
	local rounded = math.floor(raw / 100) * 100

	return math.max(SLOT_PRICE_START, rounded)
end

local function getFloorForSlot(plot, slotNumber)
	local baseSlots = getBaseSlotsPerFloor(plot)

	local floorIndex = math.ceil(slotNumber / baseSlots)
	local slotInFloor = ((slotNumber - 1) % baseSlots) + 1

	return floorIndex, slotInFloor
end

local function isProtectedRootName(name)
	return name == "BASE FLOOR"
		or name == "Brainrot Stand"
		or name == "Money Collect"
		or name == "Pillar"
		or name == "green"
end

local function isBrainrotModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if isProtectedRootName(model.Name) then
		return false
	end

	if model:FindFirstChildOfClass("Humanoid") then
		return true
	end

	if model:FindFirstChildOfClass("AnimationController") then
		return true
	end

	if model:GetAttribute("IsPlaced") == true
		or model:GetAttribute("Placed") == true
		or model:GetAttribute("InventoryOnly") == true
		or model:GetAttribute("CashPerSecond") ~= nil
		or model:GetAttribute("MPS") ~= nil
		or model:GetAttribute("Earned") ~= nil
		or model:GetAttribute("PlacedOwnerUserId") ~= nil
		or model:GetAttribute("AssignedSlotId") ~= nil
		or model:GetAttribute("BrainrotId") ~= nil
		or model:GetAttribute("UID") ~= nil
		or model:GetAttribute("Uuid") ~= nil then
		return true
	end

	local lower = string.lower(model.Name)

	return string.find(lower, "brainrot")
		or string.find(lower, "npc")
		or string.find(lower, "tralal")
		or string.find(lower, "ballerina")
		or string.find(lower, "cappuccina")
		or string.find(lower, "boneca")
		or string.find(lower, "tung")
		or string.find(lower, "sahur")
		or string.find(lower, "bombardino")
		or string.find(lower, "patapim")
end

local function removeCopiedNPCsOnly(clone)
	local toDestroy = {}

	for _, obj in ipairs(clone:GetDescendants()) do
		if obj:IsA("Tool") then
			toDestroy[obj] = true
		elseif obj:IsA("Humanoid") or obj:IsA("AnimationController") then
			local model = obj:FindFirstAncestorOfClass("Model")

			if model and model ~= clone and not isProtectedRootName(model.Name) then
				toDestroy[model] = true
			end
		elseif obj:IsA("Model") and isBrainrotModel(obj) then
			if obj ~= clone and not isProtectedRootName(obj.Name) then
				toDestroy[obj] = true
			end
		end
	end

	for obj in pairs(toDestroy) do
		if obj and obj.Parent and obj ~= clone then
			obj:Destroy()
		end
	end
end

local function clearGameplayAttributes(obj)
	local attrs = {
		"BrainrotSlotId",
		"IsOccupied",
		"Occupied",
		"Placed",
		"IsPlaced",
		"InventoryOnly",
		"PlacedOwnerUserId",
		"AssignedSlotId",
		"AssignedSlotPath",
		"AssignedHouseGoal",
		"Earned",
		"MPS",
		"CashPerSecond",
		"BrainrotId",
		"UID",
		"Uuid",
	}

	for _, attr in ipairs(attrs) do
		obj:SetAttribute(attr, nil)
	end
end

local function cleanClone(clone)
	removeCopiedNPCsOnly(clone)
	clearGameplayAttributes(clone)

	for _, obj in ipairs(clone:GetDescendants()) do
		clearGameplayAttributes(obj)

		if obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
			obj:Destroy()
		elseif obj:IsA("ProximityPrompt") then
			obj:Destroy()
		elseif obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanQuery = true
			obj.CanCollide = true

			if clone.Name == "Money Collect" or string.lower(obj.Name) == "green" then
				obj.CanTouch = true
			end
		end
	end

	removeCopiedNPCsOnly(clone)
end

local function moveByOffset(instance, offset)
	if instance:IsA("Model") then
		instance:PivotTo(instance:GetPivot() + offset)
	elseif instance:IsA("BasePart") then
		instance.CFrame = instance.CFrame + offset
	else
		for _, part in ipairs(getAllBaseParts(instance)) do
			part.CFrame = part.CFrame + offset
		end
	end
end

local function clearOldGeneratedFloorsAndLadders(plot)
	for _, child in ipairs(plot:GetChildren()) do
		if string.match(child.Name, "^" .. GENERATED_FLOOR_PREFIX .. "%d+$")
			or string.match(child.Name, "^" .. GENERATED_LADDER_PREFIX .. "%d+$") then
			child:Destroy()
		end
	end
end

local function removeOldUpgradeButtons(plot)
	local old = plot:FindFirstChild(OLD_UPGRADE_BUTTON_NAME)

	if old then
		old:Destroy()
	end
end

local function createLadder(plot, floorIndex, bounds)
	local ladderName = GENERATED_LADDER_PREFIX .. tostring(floorIndex)

	local folder = Instance.new("Folder")
	folder.Name = ladderName
	folder:SetAttribute("GeneratedPlotLadder", true)
	folder:SetAttribute("FloorIndex", floorIndex)
	folder.Parent = plot

	local baseTopY = bounds.max.Y
	local centerY = baseTopY + ((floorIndex - 1.5) * FLOOR_HEIGHT)

	local ladderX = bounds.min.X - 3
	local ladderZ = bounds.center.Z

	local ladder = Instance.new("TrussPart")
	ladder.Name = "Climb Ladder"
	ladder.Anchored = true
	ladder.CanCollide = true
	ladder.CanTouch = true
	ladder.CanQuery = true
	ladder.Size = Vector3.new(2.4, FLOOR_HEIGHT + 2, 2.4)
	ladder.CFrame = CFrame.new(ladderX, centerY, ladderZ)
	ladder.Color = Color3.fromRGB(255, 203, 84)
	ladder.Material = Enum.Material.Metal
	ladder.Parent = folder
end

local function createGeneratedFloor(plot, floorIndex, slotsOnThisFloor)
	if floorIndex <= 1 or slotsOnThisFloor <= 0 then
		return
	end

	local floorName = GENERATED_FLOOR_PREFIX .. tostring(floorIndex)
	local bounds = getFirstFloorBounds(plot)
	local slotTemplates = getFirstFloorSlotTemplates(plot)
	local baseObjects = getFirstFloorBaseObjects(plot)

	if not bounds then
		warn("[PlotSlotUpgrade] Missing first floor bounds:", plot:GetFullName())
		return
	end

	local floorModel = Instance.new("Model")
	floorModel.Name = floorName
	floorModel:SetAttribute("GeneratedPlotFloor", true)
	floorModel:SetAttribute("FloorIndex", floorIndex)
	floorModel:SetAttribute("GeneratedFloorIndex", floorIndex)
	floorModel:SetAttribute("GeneratedFloorVersion", SCRIPT_VERSION)
	floorModel:SetAttribute("UnlockedSlotsOnFloor", slotsOnThisFloor)
	floorModel.Parent = plot

	local offset = Vector3.new(0, (floorIndex - 1) * FLOOR_HEIGHT, 0)

	for _, baseObj in ipairs(baseObjects) do
		local clone = baseObj:Clone()
		cleanClone(clone)
		clone.Parent = floorModel
		moveByOffset(clone, offset)

		clone:SetAttribute("GeneratedFloorIndex", floorIndex)

		for _, part in ipairs(getAllBaseParts(clone)) do
			part:SetAttribute("GeneratedFloorIndex", floorIndex)
		end
	end

	for index = 1, math.min(slotsOnThisFloor, #slotTemplates) do
		local slot = slotTemplates[index]

		local standClone = slot.stand:Clone()
		cleanClone(standClone)
		standClone.Parent = floorModel
		moveByOffset(standClone, offset)
		standClone:SetAttribute("GeneratedFloorIndex", floorIndex)

		for _, part in ipairs(getAllBaseParts(standClone)) do
			part:SetAttribute("GeneratedFloorIndex", floorIndex)
		end

		local moneyClone = slot.money:Clone()
		cleanClone(moneyClone)
		moneyClone.Parent = floorModel
		moveByOffset(moneyClone, offset)
		moneyClone:SetAttribute("GeneratedFloorIndex", floorIndex)

		for _, part in ipairs(getAllBaseParts(moneyClone)) do
			part:SetAttribute("GeneratedFloorIndex", floorIndex)
		end
	end

	removeCopiedNPCsOnly(floorModel)
	createLadder(plot, floorIndex, bounds)

	print("[PlotSlotUpgrade] Created floor", floorIndex, "with", slotsOnThisFloor, "slot(s).")
end

local function rebuildGeneratedFloors(plot, unlockedSlots)
	local baseSlots = getBaseSlotsPerFloor(plot)

	clearOldGeneratedFloorsAndLadders(plot)

	for floorIndex = 2, MAX_FLOORS do
		local slotsBeforeFloor = (floorIndex - 1) * baseSlots
		local remainingSlots = unlockedSlots - slotsBeforeFloor
		local slotsOnThisFloor = math.clamp(remainingSlots, 0, baseSlots)

		if slotsOnThisFloor > 0 then
			createGeneratedFloor(plot, floorIndex, slotsOnThisFloor)
		end
	end

	plot:SetAttribute("GeneratedFloorVersion", SCRIPT_VERSION)
	plot:SetAttribute("LastAppliedUnlockedSlots", unlockedSlots)
end

local function applyUnlockedSlots(plot, unlockedSlots)
	local baseSlots = getBaseSlotsPerFloor(plot)
	local maxSlots = getMaxTotalSlots(plot)

	unlockedSlots = math.clamp(math.floor(tonumber(unlockedSlots) or baseSlots), baseSlots, maxSlots)

	plot:SetAttribute("UnlockedBrainrotSlots", unlockedSlots)
	plot:SetAttribute("PlotFloorLevel", math.ceil(unlockedSlots / baseSlots))

	for index, slot in ipairs(getFirstFloorSlotTemplates(plot)) do
		local unlocked = index <= baseSlots

		slot.stand:SetAttribute("SlotUnlocked", unlocked)
		slot.money:SetAttribute("SlotUnlocked", unlocked)

		for _, part in ipairs(getAllBaseParts(slot.stand)) do
			part:SetAttribute("SlotUnlocked", unlocked)
			part:SetAttribute("GeneratedFloorIndex", 1)
		end

		for _, part in ipairs(getAllBaseParts(slot.money)) do
			part:SetAttribute("SlotUnlocked", unlocked)
			part:SetAttribute("GeneratedFloorIndex", 1)
		end
	end

	local lastApplied = tonumber(plot:GetAttribute("LastAppliedUnlockedSlots")) or -1
	local version = tonumber(plot:GetAttribute("GeneratedFloorVersion")) or -1

	if lastApplied ~= unlockedSlots or version ~= SCRIPT_VERSION then
		rebuildGeneratedFloors(plot, unlockedSlots)
	end
end

local function saveUnlockedSlots(player, unlockedSlots)
	local plot = getPlayerPlot(player)

	if plot then
		local baseSlots = getBaseSlotsPerFloor(plot)
		local maxSlots = getMaxTotalSlots(plot)
		unlockedSlots = math.clamp(math.floor(tonumber(unlockedSlots) or baseSlots), baseSlots, maxSlots)
	end

	playerSlotCache[player.UserId] = unlockedSlots
	player:SetAttribute("UnlockedBrainrotSlots", unlockedSlots)

	task.defer(function()
		pcall(function()
			SLOT_STORE:SetAsync("player_" .. tostring(player.UserId), unlockedSlots)
		end)
	end)
end

local function loadUnlockedSlots(player)
	local key = "player_" .. tostring(player.UserId)
	local loaded = nil

	local ok, result = pcall(function()
		return SLOT_STORE:GetAsync(key)
	end)

	if ok and tonumber(result) then
		loaded = tonumber(result)
	end

	playerSlotCache[player.UserId] = loaded
	if loaded then
		player:SetAttribute("UnlockedBrainrotSlots", loaded)
	end

	return loaded
end

local function makeButtonGui(button, text)
	local surface = button:FindFirstChild("UpgradeSurfaceGui")

	if not surface or not surface:IsA("SurfaceGui") then
		if surface then
			surface:Destroy()
		end

		surface = Instance.new("SurfaceGui")
		surface.Name = "UpgradeSurfaceGui"
		surface.Parent = button
	end

	surface.Face = Enum.NormalId.Top
	surface.Adornee = button
	surface.AlwaysOnTop = true
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 45

	local label = surface:FindFirstChild("Text")

	if not label or not label:IsA("TextLabel") then
		if label then
			label:Destroy()
		end

		label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Parent = surface
	end

	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = text
end

local function getOrCreateUpgradeButton(plot)
	removeOldUpgradeButtons(plot)

	local button = plot:FindFirstChild(UPGRADE_BUTTON_NAME)

	if button and not button:IsA("BasePart") then
		button:Destroy()
		button = nil
	end

	local bounds = getFirstFloorBounds(plot)
	if not bounds then
		return nil, nil
	end

	if not button then
		button = Instance.new("Part")
		button.Name = UPGRADE_BUTTON_NAME
		button.Anchored = true
		button.CanCollide = true
		button.CanTouch = false
		button.CanQuery = true
		button.Size = Vector3.new(7.5, 0.8, 5)
		button.Color = Color3.fromRGB(64, 210, 83)
		button.Material = Enum.Material.SmoothPlastic
		button.Parent = plot
	end

	button.CFrame = CFrame.new(bounds.center.X, bounds.max.Y + 0.45, bounds.min.Z - 5.5)

	local prompt = button:FindFirstChild("UpgradePrompt")

	if not prompt or not prompt:IsA("ProximityPrompt") then
		if prompt then
			prompt:Destroy()
		end

		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UpgradePrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.45
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = button
	end

	return button, prompt
end

local function updateUpgradeButton(plot)
	local button, prompt = getOrCreateUpgradeButton(plot)
	if not button or not prompt then
		return
	end

	local unlockedSlots = tonumber(plot:GetAttribute("UnlockedBrainrotSlots")) or getBaseSlotsPerFloor(plot)
	local maxSlots = getMaxTotalSlots(plot)

	if unlockedSlots >= maxSlots then
		prompt.Enabled = false
		prompt.ActionText = "Max Slots"
		prompt.ObjectText = "Plot Upgrade"
		makeButtonGui(button, "MAX\nSLOTS")
		return
	end

	local nextSlot = unlockedSlots + 1
	local floorIndex, slotInFloor = getFloorForSlot(plot, nextSlot)
	local price = getSlotPrice(plot, nextSlot)

	prompt.Enabled = true
	prompt.ActionText = "Buy Slot"
	prompt.ObjectText = "$" .. formatMoney(price)

	makeButtonGui(
		button,
		"BUY\nSLOT " .. tostring(nextSlot)
			.. "\nFLOOR " .. tostring(floorIndex)
			.. " #" .. tostring(slotInFloor)
			.. "\n$" .. formatMoney(price)
	)

	if not connectedPrompts[prompt] then
		connectedPrompts[prompt] = true

		prompt.Triggered:Connect(function(player)
			if not playerOwnsPlot(player, plot) then
				notify(player, "This is not your plot.", "error")
				return
			end

			local currentSlots = tonumber(plot:GetAttribute("UnlockedBrainrotSlots")) or getBaseSlotsPerFloor(plot)
			local maxTotalSlots = getMaxTotalSlots(plot)

			if currentSlots >= maxTotalSlots then
				notify(player, "You already have max slots!", "warning")
				updateUpgradeButton(plot)
				return
			end

			local buySlot = currentSlots + 1
			local cost = getSlotPrice(plot, buySlot)
			local money = getMoneyValue(player)

			if money.Value < cost then
				notify(player, "Not enough money. Need $" .. formatMoney(cost), "error")
				return
			end

			setMoney(player, money.Value - cost)

			applyUnlockedSlots(plot, buySlot)
			saveUnlockedSlots(player, buySlot)
			updateUpgradeButton(plot)

			local floorIndex, slotInFloor = getFloorForSlot(plot, buySlot)

			notify(
				player,
				"New Brainrot Slot unlocked! Floor "
					.. tostring(floorIndex)
					.. " Slot "
					.. tostring(slotInFloor),
				"success"
			)

			print("[PlotSlotUpgrade]", player.Name, "bought slot", buySlot, "floor", floorIndex, "slot", slotInFloor)
		end)
	end
end

local function setupPlayerPlot(player)
	local plot = getPlayerPlot(player)
	if not plot then
		return
	end

	local baseSlots = getBaseSlotsPerFloor(plot)
	local loadedSlots = playerSlotCache[player.UserId] or tonumber(player:GetAttribute("UnlockedBrainrotSlots")) or baseSlots

	loadedSlots = math.max(baseSlots, loadedSlots)

	applyUnlockedSlots(plot, loadedSlots)
	updateUpgradeButton(plot)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		loadUnlockedSlots(player)

		for _ = 1, 30 do
			setupPlayerPlot(player)
			task.wait(1)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local plot = getPlayerPlot(player)

	if plot then
		saveUnlockedSlots(player, tonumber(plot:GetAttribute("UnlockedBrainrotSlots")) or getBaseSlotsPerFloor(plot))
	end

	playerSlotCache[player.UserId] = nil
end)

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			setupPlayerPlot(player)
		end

		task.wait(2)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local plot = getPlayerPlot(player)

		if plot then
			pcall(function()
				SLOT_STORE:SetAsync(
					"player_" .. tostring(player.UserId),
					tonumber(plot:GetAttribute("UnlockedBrainrotSlots")) or getBaseSlotsPerFloor(plot)
				)
			end)
		end
	end
end)

print("[PlotSlotUpgrade] Loaded. Players now buy slots one by one.")