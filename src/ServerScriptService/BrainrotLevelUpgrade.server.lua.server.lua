--!nonstrict
-- ServerScriptService/BrainrotLevelUpgrade.server.lua
-- Fast mouse-click NPC upgrade system.
-- No upgrade click cooldown.
-- NPCs grow bigger when leveled up.
-- GUI is handled by PlotOwnerText.client.lua.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local STAND_MODEL_NAME = "Brainrot Stand"
local LEVEL_BUTTON_NAME = "LEVEL UP BUTTON"

local CLICK_DETECTOR_NAME = "BrainrotUpgradeClickDetector"

local LOOP_EVERY = 0.35
local MAX_CLICK_DISTANCE = 32

local LEVEL_MPS_BONUS = 0.25
local DEFAULT_BASE_UPGRADE_COST = 100
local COST_GROWTH = 1.65

local LEVEL_SCALE_BONUS = 0.06
local MAX_LEVEL_SCALE = 3.0

local npcFolder = Workspace:FindFirstChild(NPC_FOLDER_NAME)
if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = NPC_FOLDER_NAME
	npcFolder.Parent = Workspace
end

local function ensureRemoteEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteEvent") then
			return existing
		end

		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local notifyRemote = ensureRemoteEvent("NotifyUser")
local updateCoinsEvent = ensureRemoteEvent("UpdateCoins")

local clickConnections = {}

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function formatMoney(value)
	value = tonumber(value) or 0

	if value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(math.floor(value))
end

local function notify(player, message, variant)
	if player and player.Parent then
		notifyRemote:FireClient(player, {
			message = message,
			variant = variant or "success",
		})
	end
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
	local plotsFolder = getPlotsFolder()
	local plots = {}

	if not plotsFolder then
		return plots
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if (plot:IsA("Model") or plot:IsA("Folder") or plot:IsA("BasePart")) and getFirstBasePart(plot) then
			table.insert(plots, plot)
		end
	end

	return plots
end

local function findPlotFromObject(obj)
	local plotsFolder = getPlotsFolder()

	if not plotsFolder then
		return nil
	end

	local current = obj

	while current and current ~= Workspace do
		if current.Parent == plotsFolder then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function playerOwnsPlot(player, plot)
	if not player or not plot then
		return false
	end

	return tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(plot:GetAttribute("OwnerName")) == player.Name
		or tostring(plot:GetAttribute("Owner")) == player.Name
end

local function isNamedContainer(obj, wantedName)
	return (obj:IsA("Model") or obj:IsA("Folder")) and normalize(obj.Name) == normalize(wantedName)
end

local function hasNamedAncestor(obj, wantedName)
	local current = obj.Parent

	while current and current ~= Workspace do
		if isNamedContainer(current, wantedName) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function isBadStandPart(part)
	local n = normalize(part.Name)

	return n == "levelupbutton"
		or string.find(n, "levelup") ~= nil
		or string.find(n, "button") ~= nil
end

local function getBestStandPart(stand)
	local best = nil
	local bestScore = -math.huge

	for _, part in ipairs(getAllBaseParts(stand)) do
		if not isBadStandPart(part) then
			local area = part.Size.X * part.Size.Z
			local score = area * 100 + part.Position.Y * 10

			if part.Size.Y <= 0.35 then
				score += 1000
			end

			if score > bestScore then
				bestScore = score
				best = part
			end
		end
	end

	return best or getFirstBasePart(stand)
end

local function getButtonPart(container)
	if container:IsA("BasePart") then
		return container
	end

	local exact = container:FindFirstChild(LEVEL_BUTTON_NAME)

	if exact and exact:IsA("BasePart") then
		return exact
	end

	return getFirstBasePart(container)
end

local function getStandSlots(plot)
	local slots = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if isNamedContainer(obj, STAND_MODEL_NAME) and not hasNamedAncestor(obj, STAND_MODEL_NAME) then
			local part = getBestStandPart(obj)

			if part then
				table.insert(slots, {
					container = obj,
					part = part,
				})
			end
		end
	end

	table.sort(slots, function(a, b)
		if math.abs(a.part.Position.Y - b.part.Position.Y) > 5 then
			return a.part.Position.Y < b.part.Position.Y
		end

		if math.abs(a.part.Position.X - b.part.Position.X) > 0.1 then
			return a.part.Position.X < b.part.Position.X
		end

		return a.part.Position.Z < b.part.Position.Z
	end)

	local floorYs = {}
	local counters = {}

	for _, slot in ipairs(slots) do
		local floorIndex = nil

		for i, y in ipairs(floorYs) do
			if math.abs(slot.part.Position.Y - y) <= 10 then
				floorIndex = i
				break
			end
		end

		if not floorIndex then
			table.insert(floorYs, slot.part.Position.Y)
			floorIndex = #floorYs
		end

		counters[floorIndex] = (counters[floorIndex] or 0) + 1

		local slotId = "Floor" .. tostring(floorIndex) .. "_Slot" .. string.format("%02d", counters[floorIndex])

		slot.floorIndex = floorIndex
		slot.slotId = slotId

		slot.container:SetAttribute("BrainrotSlotId", slotId)
		slot.container:SetAttribute("BrainrotSlotFloor", floorIndex)

		for _, part in ipairs(getAllBaseParts(slot.container)) do
			part:SetAttribute("BrainrotSlotId", slotId)
			part:SetAttribute("BrainrotSlotFloor", floorIndex)
		end
	end

	return slots
end

local function getUpgradeButtons(plot)
	local buttons = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if isNamedContainer(obj, LEVEL_BUTTON_NAME) and not hasNamedAncestor(obj, LEVEL_BUTTON_NAME) then
			local part = getButtonPart(obj)

			if part then
				table.insert(buttons, {
					container = obj,
					part = part,
				})
			end
		elseif obj:IsA("BasePart") and normalize(obj.Name) == normalize(LEVEL_BUTTON_NAME) then
			table.insert(buttons, {
				container = obj,
				part = obj,
			})
		end
	end

	return buttons
end

local function bindButtonsToNearestStand(plot, slots)
	local buttons = getUpgradeButtons(plot)

	for _, button in ipairs(buttons) do
		local bestSlot = nil
		local bestScore = math.huge

		for _, slot in ipairs(slots) do
			local yDiff = math.abs(button.part.Position.Y - slot.part.Position.Y)
			local distance = (button.part.Position - slot.part.Position).Magnitude
			local score = distance + yDiff * 5

			if yDiff <= 15 and score < bestScore then
				bestScore = score
				bestSlot = slot
			end
		end

		if not bestSlot then
			for _, slot in ipairs(slots) do
				local distance = (button.part.Position - slot.part.Position).Magnitude

				if distance < bestScore then
					bestScore = distance
					bestSlot = slot
				end
			end
		end

		if bestSlot then
			button.container:SetAttribute("BrainrotSlotId", bestSlot.slotId)
			button.container:SetAttribute("BrainrotSlotFloor", bestSlot.floorIndex)

			for _, part in ipairs(getAllBaseParts(button.container)) do
				part:SetAttribute("BrainrotSlotId", bestSlot.slotId)
				part:SetAttribute("BrainrotSlotFloor", bestSlot.floorIndex)
				part:SetAttribute("BrainrotLevelButton", true)
			end
		end
	end

	return buttons
end

local function ownsNpc(player, npc)
	if not player or not npc then
		return false
	end

	local owner =
		npc:GetAttribute("PlacedOwnerUserId")
		or npc:GetAttribute("OwnerUserId")
		or npc:GetAttribute("HeldOwnerUserId")
		or npc:GetAttribute("CapturedByUserId")
		or npc:GetAttribute("CaughtOwnerUserId")

	if tostring(owner) == tostring(player.UserId) then
		return true
	end

	local ownerName = npc:GetAttribute("OwnerName") or npc:GetAttribute("PlayerName")
	return ownerName == player.Name
end

local function isPlacedNpc(npc)
	return npc
		and npc:IsA("Model")
		and npc:GetAttribute("InventoryOnly") ~= true
		and (
			npc:GetAttribute("IsPlaced") == true
			or npc:GetAttribute("Placed") == true
			or npc:GetAttribute("AssignedSlotId") ~= nil
		)
end

local function getNpcBySlot(player, slotId)
	if not slotId or tostring(slotId) == "" then
		return nil
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc)
			and ownsNpc(player, npc)
			and tostring(npc:GetAttribute("AssignedSlotId")) == tostring(slotId) then
			return npc
		end
	end

	return nil
end

local function getBrainrotName(instance)
	if not instance then
		return "Brainrot"
	end

	return tostring(
		instance:GetAttribute("DisplayName")
			or instance:GetAttribute("BrainrotName")
			or instance:GetAttribute("TemplateName")
			or instance.Name
			or "Brainrot"
	)
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
	money.Value =
		tonumber(player:GetAttribute("Money"))
		or tonumber(player:GetAttribute("Coins"))
		or tonumber(player:GetAttribute("Cash"))
		or 0
	money.Parent = leaderstats

	return money
end

local function setMoney(player, value)
	value = math.floor(tonumber(value) or 0)

	local money = getMoneyValue(player)
	money.Value = value

	player:SetAttribute("Money", value)
	player:SetAttribute("Coins", value)
	player:SetAttribute("Cash", value)

	updateCoinsEvent:FireClient(player, value)
end

local function getLevel(npc)
	return math.max(1, math.floor(tonumber(npc:GetAttribute("BrainrotLevel") or npc:GetAttribute("Level")) or 1))
end

local function getBaseMps(npc)
	local base =
		tonumber(npc:GetAttribute("BaseMPS"))
		or tonumber(npc:GetAttribute("BaseCashPerSecond"))
		or tonumber(npc:GetAttribute("OriginalMPS"))
		or tonumber(npc:GetAttribute("OriginalCashPerSecond"))

	if base and base > 0 then
		return base
	end

	local current =
		tonumber(npc:GetAttribute("CashPerSecond"))
		or tonumber(npc:GetAttribute("MPS"))
		or 1

	local level = getLevel(npc)
	local multiplier = 1 + ((level - 1) * LEVEL_MPS_BONUS)

	return math.max(1, current / multiplier)
end

local function calculateMps(baseMps, level)
	return baseMps * (1 + ((level - 1) * LEVEL_MPS_BONUS))
end

local function calculateUpgradeCost(npc)
	local level = getLevel(npc)

	local stored =
		tonumber(npc:GetAttribute("NextUpgradeCost"))
		or tonumber(npc:GetAttribute("UpgradeCost"))

	if stored and stored > 0 then
		return math.floor(stored)
	end

	local baseMps = getBaseMps(npc)
	local baseCost = tonumber(npc:GetAttribute("BaseUpgradeCost")) or DEFAULT_BASE_UPGRADE_COST
	local mpsFactor = math.max(1, baseMps * 0.35)

	return math.floor(baseCost * mpsFactor * (COST_GROWTH ^ (level - 1)))
end

local function getModelMinY(model)
	local minY = math.huge

	for _, part in ipairs(getAllBaseParts(model)) do
		local bottom = part.Position.Y - (part.Size.Y * 0.5)

		if bottom < minY then
			minY = bottom
		end
	end

	if minY == math.huge then
		return nil
	end

	return minY
end

local function getModelScale(model)
	local ok, scale = pcall(function()
		return model:GetScale()
	end)

	if ok and typeof(scale) == "number" then
		return scale
	end

	return tonumber(model:GetAttribute("BrainrotScale")) or 1
end

local function applyNpcLevelScale(npc, level)
	if not npc or not npc:IsA("Model") then
		return
	end

	level = math.max(1, math.floor(tonumber(level) or 1))

	local baseScale = tonumber(npc:GetAttribute("BrainrotBaseScale"))

	if not baseScale or baseScale <= 0 then
		baseScale = getModelScale(npc)

		if baseScale <= 0 then
			baseScale = 1
		end

		npc:SetAttribute("BrainrotBaseScale", baseScale)
	end

	local multiplier = 1 + ((level - 1) * LEVEL_SCALE_BONUS)
	local targetScale = math.clamp(baseScale * multiplier, 0.25, MAX_LEVEL_SCALE)
	local currentScale = getModelScale(npc)

	if math.abs(currentScale - targetScale) < 0.005 then
		npc:SetAttribute("BrainrotScale", targetScale)
		npc:SetAttribute("SizeScale", targetScale)
		return
	end

	local oldMinY = getModelMinY(npc)

	local ok = pcall(function()
		npc:ScaleTo(targetScale)
	end)

	if ok then
		local newMinY = getModelMinY(npc)

		if oldMinY and newMinY then
			local deltaY = oldMinY - newMinY

			if math.abs(deltaY) > 0.01 then
				npc:PivotTo(npc:GetPivot() + Vector3.new(0, deltaY, 0))
			end
		end

		for _, part in ipairs(getAllBaseParts(npc)) do
			part.Anchored = true
			part.CanCollide = false
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end

	npc:SetAttribute("BrainrotScale", targetScale)
	npc:SetAttribute("SizeScale", targetScale)
end

local function setNpcUpgradeStats(npc, newLevel)
	local baseMps = getBaseMps(npc)
	local newMps = calculateMps(baseMps, newLevel)

	npc:SetAttribute("BaseMPS", baseMps)
	npc:SetAttribute("BaseCashPerSecond", baseMps)

	npc:SetAttribute("BrainrotLevel", newLevel)
	npc:SetAttribute("Level", newLevel)

	npc:SetAttribute("CashPerSecond", newMps)
	npc:SetAttribute("MPS", newMps)

	local nextCost = math.floor(
		(tonumber(npc:GetAttribute("BaseUpgradeCost")) or DEFAULT_BASE_UPGRADE_COST)
			* math.max(1, baseMps * 0.35)
			* (COST_GROWTH ^ (newLevel - 1))
	)

	npc:SetAttribute("UpgradeCost", nextCost)
	npc:SetAttribute("NextUpgradeCost", nextCost)

	applyNpcLevelScale(npc, newLevel)

	return newMps, nextCost
end

local function updateButtonAttributes(buttonPart, npc)
	if npc then
		local level = getLevel(npc)
		local cost = calculateUpgradeCost(npc)
		local mps = tonumber(npc:GetAttribute("CashPerSecond")) or tonumber(npc:GetAttribute("MPS")) or 1

		buttonPart:SetAttribute("UpgradeNpcName", getBrainrotName(npc))
		buttonPart:SetAttribute("UpgradeLevel", level)
		buttonPart:SetAttribute("UpgradeNextLevel", level + 1)
		buttonPart:SetAttribute("UpgradeCost", cost)
		buttonPart:SetAttribute("UpgradeMPS", mps)
		buttonPart:SetAttribute("HasUpgradeNpc", true)

		applyNpcLevelScale(npc, level)
	else
		buttonPart:SetAttribute("UpgradeNpcName", nil)
		buttonPart:SetAttribute("UpgradeLevel", nil)
		buttonPart:SetAttribute("UpgradeNextLevel", nil)
		buttonPart:SetAttribute("UpgradeCost", nil)
		buttonPart:SetAttribute("UpgradeMPS", nil)
		buttonPart:SetAttribute("HasUpgradeNpc", false)
	end
end

local function upgradeFromButton(player, buttonPart)
	local plot = findPlotFromObject(buttonPart)

	if not playerOwnsPlot(player, plot) then
		notify(player, "This is not your plot.", "error")
		return
	end

	local slotId = tostring(buttonPart:GetAttribute("BrainrotSlotId") or "")

	if slotId == "" then
		notify(player, "This level button is not linked yet.", "error")
		return
	end

	local npc = getNpcBySlot(player, slotId)

	if not npc then
		notify(player, "Place a brainrot on this stand first.", "warning")
		updateButtonAttributes(buttonPart, nil)
		return
	end

	local moneyValue = getMoneyValue(player)
	local currentMoney = tonumber(moneyValue.Value) or 0
	local cost = calculateUpgradeCost(npc)

	if currentMoney < cost then
		notify(player, "Need $" .. formatMoney(cost) .. " to upgrade.", "error")
		updateButtonAttributes(buttonPart, npc)
		return
	end

	local newLevel = getLevel(npc) + 1

	setMoney(player, currentMoney - cost)

	local newMps, nextCost = setNpcUpgradeStats(npc, newLevel)

	buttonPart:SetAttribute("UpgradeCost", nextCost)
	buttonPart:SetAttribute("UpgradeLevel", newLevel)
	buttonPart:SetAttribute("UpgradeNextLevel", newLevel + 1)
	buttonPart:SetAttribute("UpgradeMPS", newMps)
	buttonPart:SetAttribute("HasUpgradeNpc", true)

	updateButtonAttributes(buttonPart, npc)

	notify(player, getBrainrotName(npc) .. " upgraded to Level " .. tostring(newLevel) .. "!", "success")
end

local function bindClick(buttonPart)
	buttonPart:SetAttribute("BrainrotLevelButton", true)
	buttonPart.CanQuery = true

	local clickDetector = buttonPart:FindFirstChild(CLICK_DETECTOR_NAME)

	if not clickDetector then
		clickDetector = Instance.new("ClickDetector")
		clickDetector.Name = CLICK_DETECTOR_NAME
		clickDetector.Parent = buttonPart
	end

	clickDetector.MaxActivationDistance = MAX_CLICK_DISTANCE

	if not clickConnections[clickDetector] then
		clickConnections[clickDetector] = clickDetector.MouseClick:Connect(function(player)
			upgradeFromButton(player, buttonPart)
		end)
	end
end

local function updatePlotButtons(plot)
	local slots = getStandSlots(plot)
	local buttons = bindButtonsToNearestStand(plot, slots)

	local ownerId = tonumber(plot:GetAttribute("OwnerUserId"))
	local player = ownerId and Players:GetPlayerByUserId(ownerId)

	for _, button in ipairs(buttons) do
		bindClick(button.part)

		local slotId = tostring(button.part:GetAttribute("BrainrotSlotId") or "")
		local npc = player and getNpcBySlot(player, slotId) or nil

		updateButtonAttributes(button.part, npc)
	end
end

task.spawn(function()
	while true do
		for _, plot in ipairs(getAllPlots()) do
			updatePlotButtons(plot)
		end

		task.wait(LOOP_EVERY)
	end
end)

print("[BrainrotLevelUpgrade] Loaded fast click upgrade system with level scaling.")