--!nonstrict
-- ServerScriptService/BrainrotLevelUpSystem.server.lua
-- Final slot-safe Brainrot level-up system.
--
-- Fixes:
-- 1. Empty slots show no text.
-- 2. Upgrade uses LEFT CLICK only.
-- 3. No E prompt is used, so Return Brainrot E remains free.
-- 4. Each NPC is assigned to only ONE nearest level button.
-- 5. Each button upgrades only its assigned NPC.
-- 6. Server does not create collect-money text.
-- 7. NPC overhead GUI is small, stable, no background.
-- 8. Level-up spam is throttled.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LEVEL_BUTTON_NAME = "LEVEL UP BUTTON"
local STAND_NAME = "Brainrot Stand"

local LEVEL_CLICK_NAME = "BrainrotLevelUpClickDetector"
local LEVEL_PROMPT_NAME = "BrainrotLevelUpPrompt"
local LEVEL_BUTTON_GUI_NAME = "BrainrotLevelButtonText"
local NPC_INFO_GUI_NAME = "BrainrotPlacedInfoGui"

local MAX_LEVEL = 50
local LEVEL_BONUS_PER_LEVEL = 0.25
local BASE_UPGRADE_COST = 250
local COST_GROWTH = 1.45

local SCAN_INTERVAL = 0.75
local MAX_BUTTON_DISTANCE = 5.5
local UPGRADE_COOLDOWN = 0.65

local connectedButtons = {}
local lastUpgrade = {}

local BAD_CAPTURE_ATTRIBUTES = {
	"CanPickup",
	"CanPickUp",
	"PickupReady",
	"ReadyToPick",
	"ReadyToPickup",
	"ReadyToPickUp",
	"CaptureStunned",
	"Defeated",
	"IsDefeated",
	"Stunned",
	"IsStunned",
	"MutationRevealRunning",
}

local BAD_PROMPT_NAMES = {
	BrainrotCinematicCapturePrompt = true,
	CapturePrompt = true,
	PickupPrompt = true,
	PickUpPrompt = true,
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(255, 255, 255),
	Uncommon = Color3.fromRGB(110, 255, 125),
	Rare = Color3.fromRGB(75, 170, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 55),
	Mythic = Color3.fromRGB(255, 75, 100),
	Divine = Color3.fromRGB(255, 110, 255),
	Secret = Color3.fromRGB(255, 255, 120),
}

local MUTATION_COLORS = {
	Normal = Color3.fromRGB(255, 255, 255),
	Golden = Color3.fromRGB(255, 205, 60),
	Diamond = Color3.fromRGB(105, 235, 255),
	Shadow = Color3.fromRGB(130, 90, 255),
	Corrupted = Color3.fromRGB(255, 55, 90),
	Rainbow = Color3.fromRGB(255, 95, 240),
	Celestial = Color3.fromRGB(190, 145, 255),
}

local currentButtonToNpc = {}

local function formatNumber(n)
	n = tonumber(n) or 0

	if n >= 1000000000 then
		return string.format("%.2fB", n / 1000000000)
	elseif n >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	end

	if math.floor(n) == n then
		return tostring(n)
	end

	return string.format("%.1f", n)
end

local function getRoot(model)
	if not model then
		return nil
	end

	return model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getPlotsFolder()
	return Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
end

local function getBrainrotFolder()
	return Workspace:FindFirstChild("BrainrotNPCs")
end

local function getPlotAncestor(instance)
	local plots = getPlotsFolder()
	if not plots then
		return nil
	end

	local current = instance
	while current and current ~= Workspace do
		if current.Parent == plots then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function plotOwnedByPlayer(plot, player)
	if not plot or not player then
		return false
	end

	local ownerUserId =
		plot:GetAttribute("OwnerUserId")
		or plot:GetAttribute("PlacedOwnerUserId")
		or plot:GetAttribute("UserId")
		or plot:GetAttribute("PlayerUserId")

	if tonumber(ownerUserId) == player.UserId then
		return true
	end

	local ownerName =
		plot:GetAttribute("OwnerName")
		or plot:GetAttribute("PlayerName")

	if ownerName == player.Name then
		return true
	end

	return ownerUserId == nil and ownerName == nil
end

local function modelOwnedByPlayer(model, player)
	if not model or not player then
		return false
	end

	local ownerId =
		model:GetAttribute("PlacedOwnerUserId")
		or model:GetAttribute("OwnerUserId")
		or model:GetAttribute("HeldOwnerUserId")
		or model:GetAttribute("PlayerUserId")
		or model:GetAttribute("UserId")

	if tonumber(ownerId) == player.UserId then
		return true
	end

	local ownerName =
		model:GetAttribute("OwnerName")
		or model:GetAttribute("PlacedOwnerName")
		or model:GetAttribute("PlayerName")

	if ownerName == player.Name then
		return true
	end

	return false
end

local function npcBelongsToPlot(npc, plot)
	if not npc or not plot then
		return false
	end

	local path = tostring(npc:GetAttribute("AssignedSlotPath") or "")
	if path ~= "" and string.find(path, plot:GetFullName(), 1, true) then
		return true
	end

	return false
end

local function isPlacedBrainrot(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if model:GetAttribute("InventoryOnly") == true then
		return false
	end

	if model:GetAttribute("IsPlaced") == true then
		return true
	end

	if model:GetAttribute("Placed") == true then
		return true
	end

	if model:GetAttribute("PlacedOwnerUserId") ~= nil then
		return true
	end

	if model:GetAttribute("AssignedSlotId") ~= nil then
		return true
	end

	if model:GetAttribute("AssignedSlotPath") ~= nil then
		return true
	end

	return false
end

local function clearCaptureState(model)
	for _, attrName in ipairs(BAD_CAPTURE_ATTRIBUTES) do
		if model:GetAttribute(attrName) ~= nil then
			model:SetAttribute(attrName, false)
		end
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and BAD_PROMPT_NAMES[obj.Name] then
			obj.Enabled = false
			obj:Destroy()
		end
	end
end

local function getBrainrotName(model)
	local name =
		model:GetAttribute("DisplayName")
		or model:GetAttribute("BrainrotName")
		or model:GetAttribute("BaseBrainrotName")
		or model:GetAttribute("OriginalBrainrotName")
		or model:GetAttribute("TemplateName")
		or model.Name

	name = tostring(name)

	if name == "" or name == "Model" then
		name = "Brainrot"
	end

	name = string.gsub(name, "^%s*Desert%s*[:%-|]*%s*", "")
	name = string.gsub(name, "%s*[:%-|]*%s*Desert%s*$", "")

	return name
end

local function getRarity(model)
	return tostring(model:GetAttribute("Rarity") or "Common")
end

local function getMutation(model)
	return tostring(model:GetAttribute("MutationDisplayName") or model:GetAttribute("Mutation") or "Normal")
end

local function getCurrentLevel(model)
	local level = tonumber(model:GetAttribute("BrainrotLevel")) or tonumber(model:GetAttribute("Level")) or 1
	level = math.floor(level)

	if level < 1 then
		level = 1
	end

	if level > MAX_LEVEL then
		level = MAX_LEVEL
	end

	return level
end

local function getMutationMultiplier(model)
	return tonumber(model:GetAttribute("MutationMultiplier")) or 1
end

local function getLevelMultiplier(level)
	return 1 + ((level - 1) * LEVEL_BONUS_PER_LEVEL)
end

local function getBaseMps(model)
	local level = getCurrentLevel(model)
	local levelMultiplier = getLevelMultiplier(level)
	local mutationMultiplier = getMutationMultiplier(model)

	local current =
		tonumber(model:GetAttribute("CashPerSecond"))
		or tonumber(model:GetAttribute("MPS"))
		or 1

	local base =
		tonumber(model:GetAttribute("BaseCashPerSecond"))
		or tonumber(model:GetAttribute("OriginalCashPerSecond"))

	if not base then
		base = current / math.max(levelMultiplier * mutationMultiplier, 1)
	end

	base = math.max(base, 1)

	model:SetAttribute("BaseCashPerSecond", base)
	model:SetAttribute("OriginalCashPerSecond", base)

	return base
end

local function calculateMps(model, level)
	local base = getBaseMps(model)
	local mutationMultiplier = getMutationMultiplier(model)
	local levelMultiplier = getLevelMultiplier(level)

	local final = base * mutationMultiplier * levelMultiplier
	final = math.floor(final * 100) / 100

	return final
end

local function getUpgradeCost(model, level)
	if level >= MAX_LEVEL then
		return math.huge
	end

	local baseMps = getBaseMps(model)
	local rarity = getRarity(model)

	local rarityMultiplier = 1
	if rarity == "Uncommon" then
		rarityMultiplier = 1.15
	elseif rarity == "Rare" then
		rarityMultiplier = 1.35
	elseif rarity == "Epic" then
		rarityMultiplier = 1.7
	elseif rarity == "Legendary" then
		rarityMultiplier = 2.25
	elseif rarity == "Mythic" then
		rarityMultiplier = 3
	elseif rarity == "Divine" then
		rarityMultiplier = 3.5
	elseif rarity == "Secret" then
		rarityMultiplier = 4
	end

	local baseCost = math.max(BASE_UPGRADE_COST, baseMps * 90)
	local cost = baseCost * rarityMultiplier * (COST_GROWTH ^ (level - 1))

	cost = math.floor(cost / 5 + 0.5) * 5
	return math.max(cost, BASE_UPGRADE_COST)
end

local function applyLevelStats(model)
	local level = getCurrentLevel(model)
	local mps = calculateMps(model, level)
	local nextCost = getUpgradeCost(model, level)

	model:SetAttribute("BrainrotLevel", level)
	model:SetAttribute("Level", level)
	model:SetAttribute("LevelMultiplier", getLevelMultiplier(level))
	model:SetAttribute("CashPerSecond", mps)
	model:SetAttribute("MPS", mps)

	if nextCost ~= math.huge then
		model:SetAttribute("NextUpgradeCost", nextCost)
	else
		model:SetAttribute("NextUpgradeCost", 0)
	end

	return mps, nextCost
end

local function applyVisualLevelScale(npc)
	if not npc or not npc:IsA("Model") then
		return
	end

	local level = getCurrentLevel(npc)

	local currentScale = 1
	pcall(function()
		currentScale = npc:GetScale()
	end)

	local baseScale = tonumber(npc:GetAttribute("BaseVisualScale"))
	if not baseScale then
		baseScale = currentScale
		npc:SetAttribute("BaseVisualScale", baseScale)
	end

	local sizeMultiplier = 1 + ((level - 1) * 0.035)
	sizeMultiplier = math.clamp(sizeMultiplier, 1, 1.85)

	local targetScale = baseScale * sizeMultiplier

	pcall(function()
		npc:ScaleTo(targetScale)
	end)

	npc:SetAttribute("VisualLevelScale", targetScale)
end

local function getMoneyValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		for _, name in ipairs({ "Money", "Cash", "Coins" }) do
			local value = leaderstats:FindFirstChild(name)
			if value and value:IsA("ValueBase") then
				return value
			end
		end
	end

	for _, name in ipairs({ "Money", "Cash", "Coins" }) do
		local value = player:FindFirstChild(name)
		if value and value:IsA("ValueBase") then
			return value
		end
	end

	return nil
end

local function getPlayerMoney(player)
	local value = getMoneyValue(player)
	if value then
		return tonumber(value.Value) or 0
	end

	return tonumber(player:GetAttribute("Money")) or tonumber(player:GetAttribute("Cash")) or 0
end

local function setPlayerMoney(player, amount)
	local value = getMoneyValue(player)
	if value then
		value.Value = amount
		return true
	end

	if player:GetAttribute("Money") ~= nil then
		player:SetAttribute("Money", amount)
		return true
	end

	if player:GetAttribute("Cash") ~= nil then
		player:SetAttribute("Cash", amount)
		return true
	end

	return false
end

local function getLevelButtonsInPlot(plot)
	local buttons = {}

	if not plot then
		return buttons
	end

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == LEVEL_BUTTON_NAME then
			table.insert(buttons, obj)
		end
	end

	return buttons
end

local function getPlacedBrainrotsForPlot(plot)
	local result = {}
	local already = {}

	local function scan(container)
		if not container then
			return
		end

		for _, obj in ipairs(container:GetDescendants()) do
			if obj:IsA("Model") and not already[obj] then
				already[obj] = true

				if isPlacedBrainrot(obj) and npcBelongsToPlot(obj, plot) then
					local root = getRoot(obj)
					if root then
						table.insert(result, obj)
					end
				end
			end
		end
	end

	scan(getBrainrotFolder())
	scan(Workspace)

	return result
end

local function buildButtonMapForPlot(plot)
	local buttons = getLevelButtonsInPlot(plot)
	local npcs = getPlacedBrainrotsForPlot(plot)

	local buttonToNpc = {}
	local npcToButton = {}
	local npcToDistance = {}

	for _, npc in ipairs(npcs) do
		local root = getRoot(npc)
		if root then
			local bestButton = nil
			local bestDistance = MAX_BUTTON_DISTANCE

			for _, button in ipairs(buttons) do
				local distance = (root.Position - button.Position).Magnitude

				if distance <= bestDistance then
					bestDistance = distance
					bestButton = button
				end
			end

			if bestButton then
				local existingNpc = buttonToNpc[bestButton]
				local existingDistance = existingNpc and npcToDistance[existingNpc] or math.huge

				if not existingNpc or bestDistance < existingDistance then
					if existingNpc then
						npcToButton[existingNpc] = nil
					end

					buttonToNpc[bestButton] = npc
					npcToButton[npc] = bestButton
					npcToDistance[npc] = bestDistance
				end
			end
		end
	end

	return buttonToNpc
end

local function rebuildAllButtonMaps()
	local result = {}
	local plots = getPlotsFolder()

	if not plots then
		return result
	end

	for _, plot in ipairs(plots:GetChildren()) do
		local map = buildButtonMapForPlot(plot)

		for button, npc in pairs(map) do
			result[button] = npc
		end
	end

	currentButtonToNpc = result
end

local function createSurfaceText(part, guiName, face)
	if not part or not part:IsA("BasePart") then
		return nil
	end

	local gui = part:FindFirstChild(guiName)

	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = guiName
		gui.Face = face or Enum.NormalId.Top
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 45
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextWrapped = true
		label.RichText = true
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.Parent = gui
	end

	local label = gui:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	return label
end

local function setLevelButtonText(button, npc, temporaryText)
	local label = createSurfaceText(button, LEVEL_BUTTON_GUI_NAME, Enum.NormalId.Top)
	if not label then
		return
	end

	label.TextColor3 = Color3.fromRGB(255, 255, 255)

	if temporaryText then
		label.Text = temporaryText
		return
	end

	if not npc or not npc.Parent then
		label.Text = ""
		return
	end

	local level = getCurrentLevel(npc)
	local _, cost = applyLevelStats(npc)

	if level >= MAX_LEVEL then
		label.Text = "LEVEL " .. tostring(level) .. "\nMAX LEVEL"
	else
		label.Text = "LEVEL " .. tostring(level) .. "\nCLICK $" .. formatNumber(cost)
	end
end

local function createNpcInfoGui(npc)
	local root = getRoot(npc)
	if not root then
		return nil
	end

	local old = root:FindFirstChild(NPC_INFO_GUI_NAME)
	if old and old:IsA("BillboardGui") then
		old.Enabled = true
		old:SetAttribute("SmallNoBackgroundVersion", true)
		return old
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = NPC_INFO_GUI_NAME
	gui:SetAttribute("SmallNoBackgroundVersion", true)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 55
	gui.Size = UDim2.fromOffset(185, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.65, 0)
	gui.Parent = root

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameText"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromScale(0, 0)
	nameLabel.Size = UDim2.fromScale(1, 0.34)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Parent = holder

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityText"
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Position = UDim2.fromScale(0, 0.32)
	rarityLabel.Size = UDim2.fromScale(1, 0.31)
	rarityLabel.Font = Enum.Font.FredokaOne
	rarityLabel.TextScaled = true
	rarityLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	rarityLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	rarityLabel.TextStrokeTransparency = 0
	rarityLabel.Parent = holder

	local mpsLabel = Instance.new("TextLabel")
	mpsLabel.Name = "MpsText"
	mpsLabel.BackgroundTransparency = 1
	mpsLabel.Position = UDim2.fromScale(0, 0.62)
	mpsLabel.Size = UDim2.fromScale(1, 0.34)
	mpsLabel.Font = Enum.Font.FredokaOne
	mpsLabel.TextScaled = true
	mpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	mpsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	mpsLabel.TextStrokeTransparency = 0
	mpsLabel.Parent = holder

	return gui
end

local function updateNpcInfoGui(npc)
	clearCaptureState(npc)

	local gui = createNpcInfoGui(npc)
	if not gui then
		return
	end

	local holder = gui:FindFirstChild("Holder")
	if not holder then
		return
	end

	local nameLabel = holder:FindFirstChild("NameText")
	local rarityLabel = holder:FindFirstChild("RarityText")
	local mpsLabel = holder:FindFirstChild("MpsText")

	local mps = calculateMps(npc, getCurrentLevel(npc))
	local name = getBrainrotName(npc)
	local mutation = getMutation(npc)

	local mutationColor = MUTATION_COLORS[mutation] or Color3.fromRGB(255, 255, 255)

	if nameLabel then
		nameLabel.Text = name
		nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	if rarityLabel then
		rarityLabel.Text = mutation ~= "" and mutation or "Normal"
		rarityLabel.TextColor3 = mutationColor
	end

	if mpsLabel then
		mpsLabel.Text = "$" .. formatNumber(mps) .. "/s"
		mpsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function removeLevelPrompt(button)
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("ProximityPrompt") then
			if child.Name == LEVEL_PROMPT_NAME or child.ObjectText == "Brainrot Level" then
				child.Enabled = false
				child:Destroy()
			end
		end
	end
end

local function removeGlobalCollectGuis()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
			local lower = string.lower(obj.Name)

			if obj.Name ~= NPC_INFO_GUI_NAME and (
				string.find(lower, "collect")
					or string.find(lower, "moneycollect")
					or obj.Name == "BrainrotCollectPartText"
				) then
				obj:Destroy()
			end
		end
	end
end

local function upgradeBrainrotFromButton(player, button)
	local now = os.clock()
	local key = tostring(player.UserId) .. ":" .. button:GetFullName()

	if lastUpgrade[key] and now - lastUpgrade[key] < UPGRADE_COOLDOWN then
		return
	end

	lastUpgrade[key] = now

	rebuildAllButtonMaps()

	local npc = currentButtonToNpc[button]

	if not npc or not npc.Parent then
		setLevelButtonText(button, nil, "NO BRAINROT")
		task.delay(0.75, function()
			if button and button.Parent then
				setLevelButtonText(button, nil)
			end
		end)
		return
	end

	local plot = getPlotAncestor(button)
	if plot and not plotOwnedByPlayer(plot, player) then
		setLevelButtonText(button, npc, "NOT YOUR\nPLOT")
		task.delay(0.75, function()
			if button and button.Parent then
				setLevelButtonText(button, currentButtonToNpc[button])
			end
		end)
		return
	end

	if not modelOwnedByPlayer(npc, player) then
		setLevelButtonText(button, npc, "NOT YOUR\nBRAINROT")
		task.delay(0.75, function()
			if button and button.Parent then
				setLevelButtonText(button, currentButtonToNpc[button])
			end
		end)
		return
	end

	local npcKey = tostring(player.UserId) .. ":NPC:" .. npc:GetFullName()
	if lastUpgrade[npcKey] and now - lastUpgrade[npcKey] < UPGRADE_COOLDOWN then
		return
	end

	lastUpgrade[npcKey] = now

	clearCaptureState(npc)

	local level = getCurrentLevel(npc)

	if level >= MAX_LEVEL then
		setLevelButtonText(button, npc, "MAX\nLEVEL")
		task.delay(0.75, function()
			if button and button.Parent then
				setLevelButtonText(button, npc)
			end
		end)
		return
	end

	local cost = getUpgradeCost(npc, level)
	local money = getPlayerMoney(player)

	if money < cost then
		setLevelButtonText(button, npc, "NEED\n$" .. formatNumber(cost))
		task.delay(0.75, function()
			if button and button.Parent then
				setLevelButtonText(button, npc)
			end
		end)
		return
	end

	if not setPlayerMoney(player, money - cost) then
		setLevelButtonText(button, npc, "MONEY\nERROR")
		task.delay(0.75, function()
			if button and button.Parent then
				setLevelButtonText(button, npc)
			end
		end)
		return
	end

	local newLevel = level + 1

	npc:SetAttribute("BrainrotLevel", newLevel)
	npc:SetAttribute("Level", newLevel)

	local newMps = calculateMps(npc, newLevel)
	npc:SetAttribute("CashPerSecond", newMps)
	npc:SetAttribute("MPS", newMps)
	npc:SetAttribute("LevelMultiplier", getLevelMultiplier(newLevel))

	applyVisualLevelScale(npc)
	clearCaptureState(npc)
	updateNpcInfoGui(npc)

	setLevelButtonText(button, npc, "LEVEL UP!\nLVL " .. tostring(newLevel))

	print("[BrainrotLevelUp] Upgraded", npc:GetFullName(), "to level", newLevel, "MPS:", newMps)

	task.delay(0.75, function()
		if button and button.Parent then
			rebuildAllButtonMaps()
			setLevelButtonText(button, currentButtonToNpc[button])
		end
	end)
end

local function ensureLevelClick(button)
	if not button or not button:IsA("BasePart") then
		return
	end

	removeLevelPrompt(button)

	local clickDetector = button:FindFirstChild(LEVEL_CLICK_NAME)

	if not clickDetector then
		clickDetector = Instance.new("ClickDetector")
		clickDetector.Name = LEVEL_CLICK_NAME
		clickDetector.MaxActivationDistance = 16
		clickDetector.Parent = button
	end

	clickDetector.MaxActivationDistance = 16

	if connectedButtons[button] then
		return
	end

	connectedButtons[button] = true

	clickDetector.MouseClick:Connect(function(player)
		upgradeBrainrotFromButton(player, button)
	end)
end

local function updateAllLevelButtons()
	rebuildAllButtonMaps()

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == LEVEL_BUTTON_NAME then
			ensureLevelClick(obj)
			setLevelButtonText(obj, currentButtonToNpc[obj])
		end
	end
end

local function updateAllPlacedNpcGuis()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and isPlacedBrainrot(obj) then
			clearCaptureState(obj)
			applyLevelStats(obj)
			applyVisualLevelScale(obj)
			updateNpcInfoGui(obj)
		end
	end
end

local function cleanTool(tool)
	if not tool:IsA("Tool") then
		return
	end

	if tool:GetAttribute("IsBrainrot") ~= true
		and tool:GetAttribute("BrainrotTool") ~= true
		and tool:GetAttribute("InventoryOnly") ~= true then
		return
	end

	for _, attrName in ipairs(BAD_CAPTURE_ATTRIBUTES) do
		if tool:GetAttribute(attrName) ~= nil then
			tool:SetAttribute(attrName, false)
		end
	end

	local visual = tool:FindFirstChild("BrainrotVisual")
	if visual then
		visual:Destroy()
	end

	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj:Destroy()
		end
	end
end

local function cleanPlayerTools(player)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			cleanTool(item)
		end
	end

	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			cleanTool(item)
		end
	end

	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, item in ipairs(starterGear:GetChildren()) do
			cleanTool(item)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		cleanPlayerTools(player)
	end)

	task.delay(3, function()
		cleanPlayerTools(player)
	end)
end)

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") and obj.Name == LEVEL_BUTTON_NAME then
		task.delay(0.25, function()
			if obj and obj.Parent then
				ensureLevelClick(obj)
				rebuildAllButtonMaps()
				setLevelButtonText(obj, currentButtonToNpc[obj])
			end
		end)
	elseif obj:IsA("Model") then
		task.delay(0.35, function()
			if obj and obj.Parent and isPlacedBrainrot(obj) then
				clearCaptureState(obj)
				applyLevelStats(obj)
				applyVisualLevelScale(obj)
				updateNpcInfoGui(obj)
			end
		end)
	end
end)

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			cleanPlayerTools(player)
		end

		removeGlobalCollectGuis()
		updateAllLevelButtons()
		updateAllPlacedNpcGuis()

		task.wait(SCAN_INTERVAL)
	end
end)

print("[BrainrotLevelUpSystem] Loaded SLOT-LOCKED version. One NPC per button, no server collect GUI.")
