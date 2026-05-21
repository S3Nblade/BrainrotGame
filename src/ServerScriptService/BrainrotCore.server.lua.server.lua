--!nonstrict
-- ServerScriptService/BrainrotCore.server.lua
-- Fixed core system for:
-- plot brainrot stands, NPC placement, NPC returning, earning, and Money Collect pads.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local STAND_MODEL_NAME = "Brainrot Stand"
local MONEY_COLLECT_NAME = "Money Collect"

local STAND_PROMPT_NAME = "BrainrotCoreStandPrompt"
local PICKUP_REMOTE_NAME = "BrainrotCorePickup"

local LOOP_EVERY = 0.35
local MONEY_TICK_EVERY = 1.00
local COLLECT_DEBOUNCE = 0.85
local PLACE_DEBOUNCE = 0.45
local PROMPT_DISTANCE = 12
local PLACE_Y_OFFSET = 0.28

local CONFLICTING_SERVER_SCRIPTS = {
	"BrainrotStrictCollect.server.lua",
	"BrainrotToolPlacement.server.lua",
	"DirectBrainrotInventory.server.lua",
	"BrainrotToolInventoryRestore.server,lua",
	"BrainrotPlacedCoreRepair.server.lua",
	"BrainrotStandSnapFix.server.lua",
	"PlacedBrainrotVisualRepair.server.lua",
	"BrainrotPlacementStateGuard.server.lua",
	"BrainrotLevelUpSystem.server.lua",
}

for _, scriptName in ipairs(CONFLICTING_SERVER_SCRIPTS) do
	local old = ServerScriptService:FindFirstChild(scriptName)
	if old and old:IsA("BaseScript") and old ~= script then
		old.Disabled = true
	end
end

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
local pickupRemote = ensureRemoteEvent(PICKUP_REMOTE_NAME)

local promptConnections = {}
local collectConnections = {}
local collectDebounce = {}
local placeDebounce = {}
local lastMoneyTick = os.clock()

local BLOCKED_TOOL_NAMES = {
	["Training Weight"] = true,
	["Weight"] = true,
	["Capture Net"] = true,
}

local BLOCKED_CAPTURE_ATTRIBUTES = {
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
	local direct = Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
	if direct then
		return direct
	end

	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	if spawnMap then
		return spawnMap:FindFirstChild("plots") or spawnMap:FindFirstChild("Plots")
	end

	return nil
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

	if tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId) then
		return true
	end

	if tostring(plot:GetAttribute("OwnerName")) == player.Name then
		return true
	end

	if tostring(plot:GetAttribute("Owner")) == player.Name then
		return true
	end

	return false
end

local function getPlayerPlot(player)
	for _, plot in ipairs(getAllPlots()) do
		if playerOwnsPlot(player, plot) then
			return plot
		end
	end

	return nil
end

local function getStrongId(instance)
	if not instance then
		return nil
	end

	return instance:GetAttribute("BrainrotUID")
		or instance:GetAttribute("UID")
		or instance:GetAttribute("BrainrotUid")
		or instance:GetAttribute("DirectInventoryUid")
		or instance:GetAttribute("InventoryUid")
end

local function ensureId(instance)
	local uid = getStrongId(instance)

	if uid == nil or tostring(uid) == "" then
		uid = HttpService:GenerateGUID(false)
	end

	uid = tostring(uid)

	instance:SetAttribute("BrainrotUID", uid)
	instance:SetAttribute("UID", uid)
	instance:SetAttribute("BrainrotUid", uid)
	instance:SetAttribute("DirectInventoryUid", uid)
	instance:SetAttribute("InventoryUid", uid)

	return uid
end

local function getBrainrotName(instance)
	if not instance then
		return "Brainrot"
	end

	local name =
		instance:GetAttribute("DisplayName")
		or instance:GetAttribute("BrainrotName")
		or instance:GetAttribute("BaseBrainrotName")
		or instance:GetAttribute("OriginalBrainrotName")
		or instance:GetAttribute("TemplateName")
		or instance.Name
		or "Brainrot"

	name = tostring(name)

	if name == "" or name == "Model" or name == "Tool" then
		name = "Brainrot"
	end

	return name
end

local function copySafeAttributes(fromInstance, toInstance)
	if not fromInstance or not toInstance then
		return
	end

	for key, value in pairs(fromInstance:GetAttributes()) do
		local valueType = typeof(value)

		if valueType == "string" or valueType == "number" or valueType == "boolean" then
			pcall(function()
				toInstance:SetAttribute(key, value)
			end)
		end
	end
end

local function clearCaptureAttributes(instance)
	for _, attrName in ipairs(BLOCKED_CAPTURE_ATTRIBUTES) do
		instance:SetAttribute(attrName, false)
	end

	for _, obj in ipairs(instance:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local n = normalize(obj.Name)
			if string.find(n, "capture") or string.find(n, "pickup") then
				obj:Destroy()
			end
		end
	end
end

local function isNamedContainer(obj, wantedName)
	return (obj:IsA("Model") or obj:IsA("Folder")) and normalize(obj.Name) == normalize(wantedName)
end

local function findNamedAncestor(obj, wantedName)
	local current = obj

	while current and current ~= Workspace do
		if isNamedContainer(current, wantedName) then
			return current
		end

		current = current.Parent
	end

	return nil
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
	return n == "levelupbutton" or string.find(n, "levelup") ~= nil or string.find(n, "button") ~= nil
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

local function getBestMoneyPart(container)
	local best = nil
	local bestScore = -math.huge

	for _, part in ipairs(getAllBaseParts(container)) do
		local area = part.Size.X * part.Size.Z
		local score = area * 100 + part.Position.Y * 100

		if normalize(part.Name):find("green") then
			score += 1000
		end

		if score > bestScore then
			bestScore = score
			best = part
		end
	end

	return best or getFirstBasePart(container)
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
		slot.part:SetAttribute("BrainrotSlotId", slotId)
		slot.part:SetAttribute("BrainrotSlotFloor", floorIndex)

		for _, part in ipairs(getAllBaseParts(slot.container)) do
			part:SetAttribute("BrainrotSlotId", slotId)
			part:SetAttribute("BrainrotSlotFloor", floorIndex)
		end
	end

	return slots
end

local function getCollectContainers(plot)
	local collects = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if isNamedContainer(obj, MONEY_COLLECT_NAME) and not hasNamedAncestor(obj, MONEY_COLLECT_NAME) then
			local mainPart = getBestMoneyPart(obj)

			if mainPart then
				table.insert(collects, {
					container = obj,
					part = mainPart,
				})
			end
		elseif obj:IsA("BasePart") and normalize(obj.Name) == normalize(MONEY_COLLECT_NAME) then
			table.insert(collects, {
				container = obj,
				part = obj,
			})
		end
	end

	return collects
end

local function bindCollectsToNearestStand(plot, slots)
	local collects = getCollectContainers(plot)

	for _, collect in ipairs(collects) do
		local bestSlot = nil
		local bestScore = math.huge

		for _, slot in ipairs(slots) do
			local yDiff = math.abs(collect.part.Position.Y - slot.part.Position.Y)
			local distance = (collect.part.Position - slot.part.Position).Magnitude
			local score = distance + yDiff * 5

			if yDiff <= 15 and score < bestScore then
				bestScore = score
				bestSlot = slot
			end
		end

		if not bestSlot then
			for _, slot in ipairs(slots) do
				local distance = (collect.part.Position - slot.part.Position).Magnitude
				if distance < bestScore then
					bestScore = distance
					bestSlot = slot
				end
			end
		end

		if bestSlot then
			collect.container:SetAttribute("BrainrotSlotId", bestSlot.slotId)
			collect.container:SetAttribute("BrainrotSlotFloor", bestSlot.floorIndex)
			collect.part:SetAttribute("BrainrotSlotId", bestSlot.slotId)
			collect.part:SetAttribute("BrainrotSlotFloor", bestSlot.floorIndex)

			for _, part in ipairs(getAllBaseParts(collect.container)) do
				part:SetAttribute("BrainrotSlotId", bestSlot.slotId)
				part:SetAttribute("BrainrotSlotFloor", bestSlot.floorIndex)
				part:SetAttribute("MoneyCollectPart", true)
				part:SetAttribute("PrivateCollectGuiPart", part == collect.part)
			end
		end
	end

	return collects
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

local function isInventoryNpc(npc)
	return npc
		and npc:IsA("Model")
		and npc:GetAttribute("InventoryOnly") == true
		and not (npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true)
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
	if ownerName == player.Name then
		return true
	end

	return false
end

local function getNpcBySlot(player, slotId)
	if not slotId then
		return nil
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) and ownsNpc(player, npc) and tostring(npc:GetAttribute("AssignedSlotId")) == tostring(slotId) then
			return npc
		end
	end

	return nil
end

local function getNpcRoot(npc)
	if not npc then
		return nil
	end

	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	local root = npc:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then
		npc.PrimaryPart = root
		return root
	end

	local part = npc:FindFirstChildWhichIsA("BasePart", true)
	if part then
		npc.PrimaryPart = part
		return part
	end

	return nil
end

local function isUtilityPart(part)
	local n = normalize(part.Name)
	return n == "humanoidrootpart" or n == "root" or n == "hitbox" or n == "range" or n == "collision"
end

local function getVisibleBounds(model)
	local parts = {}

	for _, part in ipairs(getAllBaseParts(model)) do
		if not isUtilityPart(part) then
			table.insert(parts, part)
		end
	end

	if #parts == 0 then
		parts = getAllBaseParts(model)
	end

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(parts) do
		local half = part.Size * 0.5
		local p = part.Position

		minV = Vector3.new(
			math.min(minV.X, p.X - half.X),
			math.min(minV.Y, p.Y - half.Y),
			math.min(minV.Z, p.Z - half.Z)
		)

		maxV = Vector3.new(
			math.max(maxV.X, p.X + half.X),
			math.max(maxV.Y, p.Y + half.Y),
			math.max(maxV.Z, p.Z + half.Z)
		)
	end

	return minV, maxV
end

local function makeNpcVisible(npc)
	for _, part in ipairs(getAllBaseParts(npc)) do
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true

		if isUtilityPart(part) then
			part.Transparency = 1
		else
			local old = part:GetAttribute("OriginalTransparency")
			if old ~= nil then
				part.Transparency = tonumber(old) or 0
			elseif part.Transparency >= 0.98 then
				part.Transparency = 0
			end
		end
	end

	clearCaptureAttributes(npc)
end

local function hideInventoryNpc(npc)
	for _, part in ipairs(getAllBaseParts(npc)) do
		if part:GetAttribute("OriginalTransparency") == nil then
			part:SetAttribute("OriginalTransparency", part.Transparency)
		end

		part.Transparency = 1
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Anchored = true
	end

	if getNpcRoot(npc) then
		npc:PivotTo(CFrame.new(0, -10000, 0))
	end
end

local function snapNpcToStand(npc, standPart)
	if not npc or not standPart then
		return
	end

	local root = getNpcRoot(npc)
	if not root then
		return
	end

	makeNpcVisible(npc)

	local minV, maxV = getVisibleBounds(npc)
	local height = math.max(maxV.Y - minV.Y, 2)

	local target = standPart.CFrame * CFrame.new(0, standPart.Size.Y / 2 + height / 2 + PLACE_Y_OFFSET, 0)
	npc:PivotTo(target)

	for _, part in ipairs(getAllBaseParts(npc)) do
		part.Anchored = true
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
	end
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

local function addMoney(player, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return
	end

	local money = getMoneyValue(player)
	setMoney(player, (tonumber(money.Value) or 0) + amount)
end

local function getToolContainers(player)
	local containers = {}

	if player.Backpack then
		table.insert(containers, player.Backpack)
	end

	if player.Character then
		table.insert(containers, player.Character)
	end

	return containers
end

local function isBrainrotTool(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	if BLOCKED_TOOL_NAMES[tool.Name] then
		return false
	end

	if tool:GetAttribute("IsBrainrot") == true
		or tool:GetAttribute("BrainrotTool") == true
		or tool:GetAttribute("BrainrotUID") ~= nil
		or tool:GetAttribute("UID") ~= nil
		or tool:GetAttribute("BrainrotUid") ~= nil
		or tool:GetAttribute("DirectInventoryUid") ~= nil
		or tool:GetAttribute("CashPerSecond") ~= nil
		or tool:GetAttribute("MPS") ~= nil
		or tool:GetAttribute("Rarity") ~= nil
		or string.find(normalize(tool.Name), "brainrot") ~= nil then
		return true
	end

	return false
end

local function getHeldBrainrotTool(player)
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if isBrainrotTool(child) then
			return child
		end
	end

	return nil
end

local function toolMatchesNpc(tool, npc)
	local toolUid = getStrongId(tool)
	local npcUid = getStrongId(npc)

	if toolUid and npcUid and tostring(toolUid) == tostring(npcUid) then
		return true
	end

	if getBrainrotName(tool) == getBrainrotName(npc) then
		return true
	end

	return false
end

local function findInventoryNpcForTool(player, tool)
	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isInventoryNpc(npc) and ownsNpc(player, npc) and toolMatchesNpc(tool, npc) then
			return npc
		end
	end

	return nil
end

local function createFallbackNpcFromTool(player, tool)
	local npc = Instance.new("Model")
	npc.Name = getBrainrotName(tool)

	local copiedVisual = false

	for _, child in ipairs(tool:GetChildren()) do
		if child:IsA("BasePart") then
			local clone = child:Clone()
			clone.Anchored = true
			clone.CanCollide = false
			clone.Parent = npc
			copiedVisual = true
		elseif child:IsA("Model") then
			local clone = child:Clone()
			clone.Parent = npc
			copiedVisual = true
		end
	end

	if not copiedVisual then
		local part = Instance.new("Part")
		part.Name = "Brainrot"
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.SmoothPlastic
		part.Size = Vector3.new(3.5, 3.5, 3.5)
		part.Color = Color3.fromRGB(255, 140, 220)
		part.Anchored = true
		part.CanCollide = false
		part.Parent = npc
	end

	local root = getNpcRoot(npc)
	if root then
		npc.PrimaryPart = root
	end

	copySafeAttributes(tool, npc)

	local uid = ensureId(npc)
	tool:SetAttribute("BrainrotUID", uid)
	tool:SetAttribute("UID", uid)
	tool:SetAttribute("BrainrotUid", uid)
	tool:SetAttribute("DirectInventoryUid", uid)
	tool:SetAttribute("InventoryUid", uid)

	npc:SetAttribute("OwnerUserId", player.UserId)
	npc:SetAttribute("OwnerName", player.Name)
	npc:SetAttribute("HeldOwnerUserId", player.UserId)
	npc:SetAttribute("BrainrotName", getBrainrotName(tool))
	npc:SetAttribute("DisplayName", getBrainrotName(tool))
	npc:SetAttribute("TemplateName", tostring(tool:GetAttribute("TemplateName") or getBrainrotName(tool)))

	npc.Parent = npcFolder
	hideInventoryNpc(npc)

	return npc
end

local function removeToolsForNpc(player, npc)
	local uid = getStrongId(npc)

	for _, container in ipairs(getToolContainers(player)) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and isBrainrotTool(child) then
				local childUid = getStrongId(child)

				if (uid and childUid and tostring(uid) == tostring(childUid)) or getBrainrotName(child) == getBrainrotName(npc) then
					child:Destroy()
				end
			end
		end
	end
end

local function createToolFromNpc(player, npc)
	local tool = Instance.new("Tool")
	tool.Name = getBrainrotName(npc)
	tool.RequiresHandle = false
	tool.CanBeDropped = false

	copySafeAttributes(npc, tool)

	local uid = ensureId(npc)

	tool:SetAttribute("BrainrotUID", uid)
	tool:SetAttribute("UID", uid)
	tool:SetAttribute("BrainrotUid", uid)
	tool:SetAttribute("DirectInventoryUid", uid)
	tool:SetAttribute("InventoryUid", uid)

	tool:SetAttribute("IsBrainrot", true)
	tool:SetAttribute("BrainrotTool", true)
	tool:SetAttribute("InventoryOnly", true)
	tool:SetAttribute("IsPlaced", false)
	tool:SetAttribute("Placed", false)
	tool:SetAttribute("PlacedOwnerUserId", nil)
	tool:SetAttribute("AssignedSlotId", nil)
	tool:SetAttribute("AssignedSlotFloor", nil)
	tool:SetAttribute("AssignedSlotPath", nil)
	tool:SetAttribute("HeldOwnerUserId", player.UserId)
	tool:SetAttribute("OwnerUserId", player.UserId)
	tool:SetAttribute("OwnerName", player.Name)
	tool:SetAttribute("BrainrotName", getBrainrotName(npc))
	tool:SetAttribute("DisplayName", getBrainrotName(npc))

	for _, attrName in ipairs(BLOCKED_CAPTURE_ATTRIBUTES) do
		tool:SetAttribute(attrName, false)
	end

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		tool.Parent = backpack
	else
		tool.Parent = player
	end

	return tool
end

local function updateSlotOccupiedAttributes(plot, slots)
	local ownerId = tonumber(plot:GetAttribute("OwnerUserId"))
	local player = ownerId and Players:GetPlayerByUserId(ownerId)

	for _, slot in ipairs(slots) do
		local npc = nil

		if player then
			npc = getNpcBySlot(player, slot.slotId)
		end

		local occupied = npc ~= nil

		slot.container:SetAttribute("BrainrotCoreOccupied", occupied)
		slot.part:SetAttribute("BrainrotCoreOccupied", occupied)

		if occupied and player then
			slot.container:SetAttribute("BrainrotCoreOccupiedOwnerUserId", player.UserId)
			slot.part:SetAttribute("BrainrotCoreOccupiedOwnerUserId", player.UserId)
		else
			slot.container:SetAttribute("BrainrotCoreOccupiedOwnerUserId", nil)
			slot.part:SetAttribute("BrainrotCoreOccupiedOwnerUserId", nil)
		end
	end
end

local function updateCollectAttributesForPlot(plot)
	local ownerId = tonumber(plot:GetAttribute("OwnerUserId"))
	local player = ownerId and Players:GetPlayerByUserId(ownerId)

	for _, collect in ipairs(getCollectContainers(plot)) do
		local slotId = tostring(collect.part:GetAttribute("BrainrotSlotId") or collect.container:GetAttribute("BrainrotSlotId") or "")
		local npc = player and getNpcBySlot(player, slotId) or nil

		for _, part in ipairs(getAllBaseParts(collect.container)) do
			part:SetAttribute("PrivateCollectGuiPart", part == collect.part)
			part:SetAttribute("PrivateOwnerUserId", ownerId)
			part:SetAttribute("BrainrotSlotId", slotId)
			part:SetAttribute("MoneyCollectPart", true)
		end

		if npc then
			collect.part:SetAttribute("LinkedBrainrotUID", getStrongId(npc))
			collect.part:SetAttribute("PrivateCollectAmount", math.floor(tonumber(npc:GetAttribute("Earned")) or 0))
		else
			collect.part:SetAttribute("LinkedBrainrotUID", nil)
			collect.part:SetAttribute("PrivateCollectAmount", 0)
		end
	end
end

local function buildSlotFromPart(part)
	local container = findNamedAncestor(part, STAND_MODEL_NAME) or part

	return {
		container = container,
		part = part,
		slotId = tostring(part:GetAttribute("BrainrotSlotId") or container:GetAttribute("BrainrotSlotId") or ""),
		floorIndex = tonumber(part:GetAttribute("BrainrotSlotFloor") or container:GetAttribute("BrainrotSlotFloor")) or 1,
	}
end

local function placeNpcOnSlot(player, slot)
	local key = tostring(player.UserId)

	if placeDebounce[key] and os.clock() - placeDebounce[key] < PLACE_DEBOUNCE then
		return
	end

	placeDebounce[key] = os.clock()

	local plot = findPlotFromObject(slot.part)

	if not playerOwnsPlot(player, plot) then
		notify(player, "This is not your plot.", "error")
		return
	end

	if slot.slotId == "" then
		notify(player, "This stand is not linked to a slot yet.", "error")
		return
	end

	if getNpcBySlot(player, slot.slotId) then
		notify(player, "This slot already has a brainrot.", "warning")
		return
	end

	local tool = getHeldBrainrotTool(player)
	if not tool then
		notify(player, "Hold a brainrot tool first.", "warning")
		return
	end

	local toolUid = ensureId(tool)
	local npc = findInventoryNpcForTool(player, tool)

	if not npc then
		npc = createFallbackNpcFromTool(player, tool)
	end

	copySafeAttributes(tool, npc)

	local uid = getStrongId(npc) or toolUid
	npc:SetAttribute("BrainrotUID", uid)
	npc:SetAttribute("UID", uid)
	npc:SetAttribute("BrainrotUid", uid)
	npc:SetAttribute("DirectInventoryUid", uid)
	npc:SetAttribute("InventoryUid", uid)

	local displayName = getBrainrotName(tool)
	npc.Name = displayName
	npc.Parent = npcFolder

	npc:SetAttribute("BrainrotName", displayName)
	npc:SetAttribute("DisplayName", displayName)
	npc:SetAttribute("TemplateName", tostring(npc:GetAttribute("TemplateName") or displayName))

	npc:SetAttribute("OwnerUserId", player.UserId)
	npc:SetAttribute("OwnerName", player.Name)
	npc:SetAttribute("PlacedOwnerUserId", player.UserId)
	npc:SetAttribute("HeldOwnerUserId", nil)

	npc:SetAttribute("InventoryOnly", false)
	npc:SetAttribute("IsPlaced", true)
	npc:SetAttribute("Placed", true)

	npc:SetAttribute("AssignedSlotId", slot.slotId)
	npc:SetAttribute("AssignedSlotFloor", slot.floorIndex)
	npc:SetAttribute("AssignedSlotPath", slot.part:GetFullName())

	local baseMps =
		tonumber(npc:GetAttribute("BaseMPS"))
		or tonumber(npc:GetAttribute("BaseCashPerSecond"))
		or tonumber(npc:GetAttribute("CashPerSecond"))
		or tonumber(npc:GetAttribute("MPS"))
		or tonumber(tool:GetAttribute("CashPerSecond"))
		or tonumber(tool:GetAttribute("MPS"))
		or 1

	local level = math.max(1, math.floor(tonumber(npc:GetAttribute("BrainrotLevel") or npc:GetAttribute("Level")) or 1))
	local levelMultiplier = 1 + ((level - 1) * 0.25)
	local mps = baseMps * levelMultiplier

	npc:SetAttribute("BaseMPS", baseMps)
	npc:SetAttribute("BaseCashPerSecond", baseMps)
	npc:SetAttribute("BrainrotLevel", level)
	npc:SetAttribute("Level", level)
	npc:SetAttribute("CashPerSecond", mps)
	npc:SetAttribute("MPS", mps)

	if npc:GetAttribute("Earned") == nil then
		npc:SetAttribute("Earned", 0)
	end

	removeToolsForNpc(player, npc)
	snapNpcToStand(npc, slot.part)

	slot.container:SetAttribute("BrainrotCoreOccupied", true)
	slot.part:SetAttribute("BrainrotCoreOccupied", true)
	slot.container:SetAttribute("BrainrotCoreOccupiedOwnerUserId", player.UserId)
	slot.part:SetAttribute("BrainrotCoreOccupiedOwnerUserId", player.UserId)

	updateCollectAttributesForPlot(plot)

end

local function returnNpcFromSlot(player, slot)
	local plot = findPlotFromObject(slot.part)

	if not playerOwnsPlot(player, plot) then
		notify(player, "This is not your plot.", "error")
		return
	end

	local npc = getNpcBySlot(player, slot.slotId)
	if not npc then
		return
	end

	local earned = math.floor(tonumber(npc:GetAttribute("Earned")) or 0)
	if earned > 0 then
		addMoney(player, earned)
	end

	npc:SetAttribute("InventoryOnly", true)
	npc:SetAttribute("IsPlaced", false)
	npc:SetAttribute("Placed", false)
	npc:SetAttribute("PlacedOwnerUserId", nil)
	npc:SetAttribute("HeldOwnerUserId", player.UserId)
	npc:SetAttribute("AssignedSlotId", nil)
	npc:SetAttribute("AssignedSlotFloor", nil)
	npc:SetAttribute("AssignedSlotPath", nil)
	npc:SetAttribute("Earned", 0)

	removeToolsForNpc(player, npc)
	createToolFromNpc(player, npc)
	hideInventoryNpc(npc)

	slot.container:SetAttribute("BrainrotCoreOccupied", false)
	slot.part:SetAttribute("BrainrotCoreOccupied", false)
	slot.container:SetAttribute("BrainrotCoreOccupiedOwnerUserId", nil)
	slot.part:SetAttribute("BrainrotCoreOccupiedOwnerUserId", nil)

	updateCollectAttributesForPlot(plot)

end

local function setupStandPrompt(slot)
	local prompt = slot.part:FindFirstChild(STAND_PROMPT_NAME)

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = STAND_PROMPT_NAME
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.ObjectText = "Brainrot Stand"
		prompt.Parent = slot.part
	end

	local plot = findPlotFromObject(slot.part)
	local ownerId = plot and tonumber(plot:GetAttribute("OwnerUserId"))
	local player = ownerId and Players:GetPlayerByUserId(ownerId)
	local occupied = player and getNpcBySlot(player, slot.slotId) ~= nil

	prompt.ActionText = occupied and "Return Brainrot" or "Place Brainrot"
	prompt.Enabled = true

	if not promptConnections[prompt] then
		promptConnections[prompt] = prompt.Triggered:Connect(function(triggeringPlayer)
			local currentSlot = buildSlotFromPart(prompt.Parent)
			local currentPlot = findPlotFromObject(currentSlot.part)

			if not playerOwnsPlot(triggeringPlayer, currentPlot) then
				notify(triggeringPlayer, "This is not your plot.", "error")
				return
			end

			local currentNpc = getNpcBySlot(triggeringPlayer, currentSlot.slotId)

			if currentNpc then
				returnNpcFromSlot(triggeringPlayer, currentSlot)
			else
				placeNpcOnSlot(triggeringPlayer, currentSlot)
			end
		end)
	end
end

local function findAssignedNpcForCollect(player, collectPart)
	local slotId = tostring(collectPart:GetAttribute("BrainrotSlotId") or "")

	if slotId ~= "" then
		return getNpcBySlot(player, slotId)
	end

	local uid = collectPart:GetAttribute("LinkedBrainrotUID")
	if uid and tostring(uid) ~= "" then
		for _, npc in ipairs(npcFolder:GetChildren()) do
			if isPlacedNpc(npc) and ownsNpc(player, npc) and tostring(getStrongId(npc)) == tostring(uid) then
				return npc
			end
		end
	end

	return nil
end

local function collectFromPart(collectPart, hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local plot = findPlotFromObject(collectPart)
	if not playerOwnsPlot(player, plot) then
		return
	end

	local npc = findAssignedNpcForCollect(player, collectPart)

	if not npc then
		collectPart:SetAttribute("PrivateCollectAmount", 0)
		collectPart:SetAttribute("LinkedBrainrotUID", nil)
		return
	end

	local npcKey =
		tostring(player.UserId)
		.. ":"
		.. tostring(getStrongId(npc) or npc:GetAttribute("AssignedSlotId") or collectPart:GetFullName())

	if collectDebounce[npcKey] and os.clock() - collectDebounce[npcKey] < COLLECT_DEBOUNCE then
		return
	end

	collectDebounce[npcKey] = os.clock()

	local amount = math.floor(tonumber(npc:GetAttribute("Earned")) or 0)

	if amount <= 0 then
		collectPart:SetAttribute("PrivateCollectAmount", 0)
		collectPart:SetAttribute("LinkedBrainrotUID", getStrongId(npc))
		return
	end

	npc:SetAttribute("Earned", 0)

	collectPart:SetAttribute("PrivateCollectAmount", 0)
	collectPart:SetAttribute("LinkedBrainrotUID", getStrongId(npc))

	addMoney(player, amount)
	-- Local pad effect handles collect feedback.
end

local function setupCollectTouch(collect)
	for _, part in ipairs(getAllBaseParts(collect.container)) do
		part.CanTouch = true
		part:SetAttribute("MoneyCollectPart", true)

		if not collectConnections[part] then
			collectConnections[part] = part.Touched:Connect(function(hit)
				local mainPart = part

				local collectContainer = findNamedAncestor(part, MONEY_COLLECT_NAME)
				if collectContainer then
					mainPart = getBestMoneyPart(collectContainer) or part
				end

				collectFromPart(mainPart, hit)
			end)
		end
	end
end

local function hasToolForNpc(player, npc)
	local uid = getStrongId(npc)

	for _, container in ipairs(getToolContainers(player)) do
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") and isBrainrotTool(child) then
				local childUid = getStrongId(child)

				if (uid and childUid and tostring(uid) == tostring(childUid)) or getBrainrotName(child) == getBrainrotName(npc) then
					return true
				end
			end
		end
	end

	return false
end

local function restoreInventoryTools(player)
	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isInventoryNpc(npc) and ownsNpc(player, npc) then
			if not hasToolForNpc(player, npc) then
				createToolFromNpc(player, npc)
			end

			hideInventoryNpc(npc)
		end
	end
end

local function repairPlacedNpcs(player)
	local plot = getPlayerPlot(player)
	if not plot then
		return
	end

	local slots = getStandSlots(plot)
	bindCollectsToNearestStand(plot, slots)

	local validSlots = {}
	for _, slot in ipairs(slots) do
		validSlots[slot.slotId] = slot
	end

	local usedSlots = {}
	local usedUids = {}

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) and ownsNpc(player, npc) then
			local uid = ensureId(npc)

			if usedUids[uid] then
				npc:Destroy()
			else
				usedUids[uid] = true

				local slotId = tostring(npc:GetAttribute("AssignedSlotId") or "")
				local slot = validSlots[slotId]

				if slot and not usedSlots[slotId] then
					usedSlots[slotId] = true

					npc:SetAttribute("OwnerUserId", player.UserId)
					npc:SetAttribute("OwnerName", player.Name)
					npc:SetAttribute("PlacedOwnerUserId", player.UserId)
					npc:SetAttribute("InventoryOnly", false)
					npc:SetAttribute("IsPlaced", true)
					npc:SetAttribute("Placed", true)
					npc:SetAttribute("AssignedSlotFloor", slot.floorIndex)
					npc:SetAttribute("AssignedSlotPath", slot.part:GetFullName())

					snapNpcToStand(npc, slot.part)
				elseif slotId == "" then
					for _, freeSlot in ipairs(slots) do
						if not usedSlots[freeSlot.slotId] and not getNpcBySlot(player, freeSlot.slotId) then
							usedSlots[freeSlot.slotId] = true

							npc:SetAttribute("OwnerUserId", player.UserId)
							npc:SetAttribute("OwnerName", player.Name)
							npc:SetAttribute("PlacedOwnerUserId", player.UserId)
							npc:SetAttribute("InventoryOnly", false)
							npc:SetAttribute("IsPlaced", true)
							npc:SetAttribute("Placed", true)
							npc:SetAttribute("AssignedSlotId", freeSlot.slotId)
							npc:SetAttribute("AssignedSlotFloor", freeSlot.floorIndex)
							npc:SetAttribute("AssignedSlotPath", freeSlot.part:GetFullName())

							snapNpcToStand(npc, freeSlot.part)
							break
						end
					end
				else
					npc:SetAttribute("InventoryOnly", true)
					npc:SetAttribute("IsPlaced", false)
					npc:SetAttribute("Placed", false)
					npc:SetAttribute("PlacedOwnerUserId", nil)
					npc:SetAttribute("HeldOwnerUserId", player.UserId)
					npc:SetAttribute("AssignedSlotId", nil)
					npc:SetAttribute("AssignedSlotFloor", nil)
					npc:SetAttribute("AssignedSlotPath", nil)
					npc:SetAttribute("Earned", 0)

					removeToolsForNpc(player, npc)
					createToolFromNpc(player, npc)
					hideInventoryNpc(npc)
				end
			end
		end
	end

	updateSlotOccupiedAttributes(plot, slots)
	updateCollectAttributesForPlot(plot)
end

local function tickMoney(dt)
	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) then
			local mps =
				tonumber(npc:GetAttribute("CashPerSecond"))
				or tonumber(npc:GetAttribute("MPS"))
				or 1

			local current = tonumber(npc:GetAttribute("Earned")) or 0
			npc:SetAttribute("Earned", current + mps * dt)
		end
	end
end

pickupRemote.OnServerEvent:Connect(function(player)
	notify(player, "Use your plot stands to place or return brainrots.", "warning")
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		restoreInventoryTools(player)
	end)

	task.defer(function()
		task.wait(3)
		restoreInventoryTools(player)
		repairPlacedNpcs(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	placeDebounce[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(function()
		task.wait(3)
		restoreInventoryTools(player)
		repairPlacedNpcs(player)
	end)
end

task.spawn(function()
	while true do
		for _, plot in ipairs(getAllPlots()) do
			local slots = getStandSlots(plot)
			local collects = bindCollectsToNearestStand(plot, slots)

			for _, slot in ipairs(slots) do
				setupStandPrompt(slot)
			end

			for _, collect in ipairs(collects) do
				setupCollectTouch(collect)
			end

			updateSlotOccupiedAttributes(plot, slots)
			updateCollectAttributesForPlot(plot)
		end

		task.wait(LOOP_EVERY)
	end
end)

task.spawn(function()
	while true do
		local now = os.clock()
		local dt = now - lastMoneyTick

		if dt >= MONEY_TICK_EVERY then
			lastMoneyTick = now
			tickMoney(dt)

			for _, player in ipairs(Players:GetPlayers()) do
				repairPlacedNpcs(player)
			end
		end

		task.wait(0.2)
	end
end)

print("[BrainrotCore] Loaded fixed placement, earning, collection, and return system.")
