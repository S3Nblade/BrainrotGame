--!nonstrict
-- StarterPlayerScripts/OwnerCollectMoneyText.client.lua
-- Shows only the amount of money ready to collect on your own green Money Collect parts.
-- Text is local-only, white, cartoony, black outline.
-- Empty slots / $0 slots show nothing.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local NPC_FOLDER_NAME = "BrainrotNPCs"
local MONEY_COLLECT_NAME = "Money Collect"
local STAND_MODEL_NAME = "Brainrot Stand"

local UPDATE_EVERY = 0.08

local GUI_PREFIX = "OwnerVisibleCollectAmount_"

local MONEY_TEXT_FACES = {
	Enum.NormalId.Top,
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
}

local MONEY_ATTRS = {
	"Earned",
	"PrivateCollectAmount",
	"CollectAmount",
	"MoneyAmount",
	"StoredMoney",
	"PendingMoney",
	"ReadyMoney",
	"ReadyToCollect",
	"MoneyToCollect",
	"GeneratedMoney",
	"UncollectedMoney",
}

local guiCache = {}

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

local function getPlotsFolder()
	return Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
end

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
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

local function ownsPlot(plot)
	if not plot then
		return false
	end

	return tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(plot:GetAttribute("OwnerName")) == player.Name
		or tostring(plot:GetAttribute("Owner")) == player.Name
end

local function getOwnPlot()
	local plotsFolder = getPlotsFolder()
	if not plotsFolder then
		return nil
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if ownsPlot(plot) then
			return plot
		end
	end

	return nil
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

local function getSlotIdFromObject(obj)
	local current = obj

	while current and current ~= Workspace do
		local slotId = current:GetAttribute("BrainrotSlotId")

		if slotId ~= nil and tostring(slotId) ~= "" then
			return tostring(slotId)
		end

		current = current.Parent
	end

	return ""
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

local function ownsNpc(npc)
	if not npc then
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
		and ownsNpc(npc)
		and npc:GetAttribute("InventoryOnly") ~= true
		and (
			npc:GetAttribute("IsPlaced") == true
			or npc:GetAttribute("Placed") == true
			or npc:GetAttribute("AssignedSlotId") ~= nil
		)
end

local function getPlacedNpcs()
	local result = {}
	local npcFolder = getNpcFolder()

	if not npcFolder then
		return result
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) then
			table.insert(result, npc)
		end
	end

	return result
end

local function getNpcBySlot(slotId)
	if not slotId or tostring(slotId) == "" then
		return nil
	end

	for _, npc in ipairs(getPlacedNpcs()) do
		if tostring(npc:GetAttribute("AssignedSlotId")) == tostring(slotId) then
			return npc
		end
	end

	return nil
end

local function getNpcByUid(uid)
	if not uid or tostring(uid) == "" then
		return nil
	end

	for _, npc in ipairs(getPlacedNpcs()) do
		if tostring(getStrongId(npc)) == tostring(uid) then
			return npc
		end
	end

	return nil
end

local function readMoneyAttrs(instance)
	if not instance then
		return 0
	end

	local best = 0

	for _, attrName in ipairs(MONEY_ATTRS) do
		local value = tonumber(instance:GetAttribute(attrName))

		if value and value > best then
			best = value
		end
	end

	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("NumberValue") or child:IsA("IntValue") then
			for _, attrName in ipairs(MONEY_ATTRS) do
				if child.Name == attrName then
					local value = tonumber(child.Value)

					if value and value > best then
						best = value
					end
				end
			end
		end
	end

	return best
end

local function isGreenPart(part)
	local n = normalize(part.Name)
	if string.find(n, "green") then
		return true
	end

	local c = part.Color
	return c.G > c.R * 1.25 and c.G > c.B * 1.25
end

local function getGreenMoneyPart(container)
	if container:IsA("BasePart") then
		return container
	end

	local best = nil
	local bestScore = -math.huge

	for _, part in ipairs(getAllBaseParts(container)) do
		local score = part.Size.X * part.Size.Z * 100

		if isGreenPart(part) then
			score += 100000
		end

		if part:GetAttribute("PrivateCollectGuiPart") == true then
			score += 50000
		end

		if part:GetAttribute("MoneyCollectPart") == true then
			score += 25000
		end

		if readMoneyAttrs(part) > 0 then
			score += 10000
		end

		if score > bestScore then
			bestScore = score
			best = part
		end
	end

	return best or getFirstBasePart(container)
end

local function isMoneyCollectObject(obj)
	local n = normalize(obj.Name)

	return n == normalize(MONEY_COLLECT_NAME)
		or n == "moneycollect"
		or n == "collectmoney"
		or obj:GetAttribute("MoneyCollectPart") == true
		or obj:GetAttribute("PrivateCollectGuiPart") == true
end

local function getMoneyTargets(plot)
	local targets = {}
	local usedParts = {}
	local usedContainers = {}

	if not plot then
		return targets
	end

	for _, obj in ipairs(plot:GetDescendants()) do
		if isNamedContainer(obj, MONEY_COLLECT_NAME) and not hasNamedAncestor(obj, MONEY_COLLECT_NAME) then
			local greenPart = getGreenMoneyPart(obj)

			if greenPart and not usedParts[greenPart] then
				usedParts[greenPart] = true
				usedContainers[obj] = true

				table.insert(targets, {
					part = greenPart,
					container = obj,
				})
			end
		end
	end

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj:IsA("BasePart") and isMoneyCollectObject(obj) then
			local container = findNamedAncestor(obj, MONEY_COLLECT_NAME)

			if not container or not usedContainers[container] then
				local greenPart = getGreenMoneyPart(container or obj)

				if greenPart and not usedParts[greenPart] then
					usedParts[greenPart] = true

					table.insert(targets, {
						part = greenPart,
						container = container or obj,
					})
				end
			end
		end
	end

	return targets
end

local function getBestStandPart(stand)
	local best = nil
	local bestScore = -math.huge

	for _, part in ipairs(getAllBaseParts(stand)) do
		local n = normalize(part.Name)

		if not string.find(n, "button") and not string.find(n, "level") then
			local score = part.Size.X * part.Size.Z * 100 + part.Position.Y * 10

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

local function getFallbackSlotIdFromNearestStand(part, plot)
	local bestSlotId = ""
	local bestScore = math.huge

	for _, obj in ipairs(plot:GetDescendants()) do
		if isNamedContainer(obj, STAND_MODEL_NAME) and not hasNamedAncestor(obj, STAND_MODEL_NAME) then
			local standPart = getBestStandPart(obj)
			local slotId = getSlotIdFromObject(obj)

			if standPart and slotId ~= "" then
				local yDiff = math.abs(standPart.Position.Y - part.Position.Y)
				local distance = (standPart.Position - part.Position).Magnitude
				local score = distance + yDiff * 5

				if yDiff <= 18 and score < bestScore then
					bestScore = score
					bestSlotId = slotId
				end
			end
		end
	end

	return bestSlotId
end

local function getNpcForTarget(target, plot)
	local part = target.part
	local container = target.container

	local slotId = getSlotIdFromObject(part)

	if slotId == "" and container then
		slotId = getSlotIdFromObject(container)
	end

	if slotId == "" then
		slotId = getFallbackSlotIdFromNearestStand(part, plot)
	end

	local npc = getNpcBySlot(slotId)

	if npc then
		return npc
	end

	local current = part

	while current and current ~= Workspace do
		local uid = current:GetAttribute("LinkedBrainrotUID")

		if uid and tostring(uid) ~= "" then
			npc = getNpcByUid(uid)

			if npc then
				return npc
			end
		end

		current = current.Parent
	end

	return nil
end

local function getAmount(target, npc)
	if not npc then
		return 0
	end

	local amount = 0

	amount = math.max(amount, readMoneyAttrs(npc))
	amount = math.max(amount, readMoneyAttrs(target.part))
	amount = math.max(amount, readMoneyAttrs(target.container))

	if target.container then
		for _, part in ipairs(getAllBaseParts(target.container)) do
			amount = math.max(amount, readMoneyAttrs(part))
		end
	end

	return amount
end

local function clearOldCollectGuis()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SurfaceGui") and string.sub(obj.Name, 1, #GUI_PREFIX) == GUI_PREFIX then
			obj:Destroy()
		end
	end
end

local function clearPartGuis(part)
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") and string.sub(child.Name, 1, #GUI_PREFIX) == GUI_PREFIX then
			child:Destroy()
		end
	end
end

local function createFaceGui(part, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = GUI_PREFIX .. face.Name
	gui.Adornee = part
	gui.Face = face
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 85
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = gui

	return gui, label
end

local function ensureGuis(part)
	local cached = guiCache[part]

	if cached then
		local alive = true

		for _, item in ipairs(cached) do
			if not item.gui or not item.gui.Parent then
				alive = false
				break
			end
		end

		if alive then
			return cached
		end
	end

	clearPartGuis(part)

	local list = {}

	for _, face in ipairs(MONEY_TEXT_FACES) do
		local gui, label = createFaceGui(part, face)

		table.insert(list, {
			gui = gui,
			label = label,
		})
	end

	guiCache[part] = list

	return list
end

local function setPartText(part, text)
	local guis = ensureGuis(part)

	for _, item in ipairs(guis) do
		if item.label and item.label.Text ~= text then
			item.label.Text = text
		end
	end
end

local function cleanupCache(validParts)
	for part, guis in pairs(guiCache) do
		if not validParts[part] or not part or not part.Parent then
			for _, item in ipairs(guis) do
				if item.gui then
					item.gui:Destroy()
				end
			end

			guiCache[part] = nil
		end
	end
end

clearOldCollectGuis()

task.spawn(function()
	while true do
		local ownPlot = getOwnPlot()
		local validParts = {}

		if ownPlot then
			for _, target in ipairs(getMoneyTargets(ownPlot)) do
				local part = target.part
				validParts[part] = true

				local npc = getNpcForTarget(target, ownPlot)
				local amount = getAmount(target, npc)

				if npc and amount > 0 then
					setPartText(part, "$" .. formatMoney(amount))
				else
					setPartText(part, "")
				end
			end
		end

		cleanupCache(validParts)

		task.wait(UPDATE_EVERY)
	end
end)

print("[OwnerCollectMoneyText] Loaded visible owner-only collect amount text.")