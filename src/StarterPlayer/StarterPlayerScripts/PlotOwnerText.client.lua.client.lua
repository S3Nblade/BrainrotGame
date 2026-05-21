--!nonstrict
-- StarterPlayerScripts/PlotOwnerText.client.lua
-- Polished owner-only plot UI:
-- 1. Upgrade text on LEVEL UP BUTTON.
-- 2. Money amount directly on green Money Collect parts.
-- 3. Empty slots show nothing.
-- 4. Small clean local money effect near collect pad.
-- 5. NPC info above your NPCs.
-- 6. No UI on other players' plots.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local NPC_FOLDER_NAME = "BrainrotNPCs"

local LEVEL_BUTTON_NAME = "LEVEL UP BUTTON"
local MONEY_COLLECT_NAME = "Money Collect"

local UPDATE_EVERY = 0.08

local UPGRADE_GUI_NAME = "PolishedOwnerUpgradeSurfaceGui"
local MONEY_GUI_PREFIX = "PolishedOwnerMoneySurfaceGui_"
local NPC_GUI_NAME = "PolishedOwnerNpcInfoGui"
local MONEY_FX_NAME = "PolishedMoneyCollectFX"

local UPGRADE_TEXT_FACE = Enum.NormalId.Top

local MONEY_TEXT_FACES = {
	Enum.NormalId.Top,
	Enum.NormalId.Front,
	Enum.NormalId.Back,
}

local LEVEL_MPS_BONUS = 0.25
local DEFAULT_BASE_UPGRADE_COST = 100
local COST_GROWTH = 1.65

local upgradeGuis = {}
local moneyGuis = {}
local npcGuis = {}
local previousAmounts = {}
local lastMoneyFx = {}

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

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function formatMoney(value)
	value = tonumber(value) or 0

	if value >= 1000000000000000 then
		return string.format("%.1fQ", value / 1000000000000000)
	elseif value >= 1000000000000 then
		return string.format("%.1fT", value / 1000000000000)
	elseif value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(math.floor(value))
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

	if plotsFolder then
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			if ownsPlot(plot) then
				return plot
			end
		end
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if (obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart")) and ownsPlot(obj) then
			return obj
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
	local list = {}
	local npcFolder = getNpcFolder()

	if not npcFolder then
		return list
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) then
			table.insert(list, npc)
		end
	end

	return list
end

local function getNpcRoot(npc)
	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	local root = npc:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then
		return root
	end

	return npc:FindFirstChildWhichIsA("BasePart", true)
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

local function getNpcForObjectStrict(obj)
	local slotId = getSlotIdFromObject(obj)
	local npc = getNpcBySlot(slotId)

	if npc then
		return npc
	end

	local current = obj

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

local function getBrainrotName(instance)
	if not instance then
		return "Brainrot"
	end

	local name = tostring(
		instance:GetAttribute("DisplayName")
			or instance:GetAttribute("BrainrotName")
			or instance:GetAttribute("BaseBrainrotName")
			or instance:GetAttribute("OriginalBrainrotName")
			or instance:GetAttribute("TemplateName")
			or instance.Name
			or "Brainrot"
	)

	name = string.gsub(name, "^%s*Desert%s*[:%-|]*%s*", "")
	name = string.gsub(name, "%s*[:%-|]*%s*Desert%s*$", "")
	return name
end

local function getMutation(npc)
	local mutation =
		npc:GetAttribute("Mutation")
		or npc:GetAttribute("MutationName")
		or npc:GetAttribute("ActiveMutation")
		or npc:GetAttribute("MutationType")
		or npc:GetAttribute("CurrentMutation")

	if mutation == nil or tostring(mutation) == "" then
		return "Normal"
	end

	return tostring(mutation)
end

local function getMps(npc)
	return tonumber(npc:GetAttribute("CashPerSecond"))
		or tonumber(npc:GetAttribute("MPS"))
		or 1
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

	local level = getLevel(npc)
	local multiplier = 1 + ((level - 1) * LEVEL_MPS_BONUS)

	return math.max(1, getMps(npc) / multiplier)
end

local function calculateUpgradeCost(npc)
	if not npc then
		return 0
	end

	local stored =
		tonumber(npc:GetAttribute("NextUpgradeCost"))
		or tonumber(npc:GetAttribute("UpgradeCost"))

	if stored and stored > 0 then
		return math.floor(stored)
	end

	local level = getLevel(npc)
	local baseMps = getBaseMps(npc)
	local baseCost = tonumber(npc:GetAttribute("BaseUpgradeCost")) or DEFAULT_BASE_UPGRADE_COST
	local mpsFactor = math.max(1, baseMps * 0.35)

	return math.floor(baseCost * mpsFactor * (COST_GROWTH ^ (level - 1)))
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

local function getCollectAmount(part, container, npc)
	if not npc then
		return 0
	end

	local amount = 0

	amount = math.max(amount, readMoneyAttrs(npc))
	amount = math.max(amount, readMoneyAttrs(part))
	amount = math.max(amount, readMoneyAttrs(container))

	if container then
		for _, childPart in ipairs(getAllBaseParts(container)) do
			amount = math.max(amount, readMoneyAttrs(childPart))
		end
	end

	return amount
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

local function getUpgradeButtonParts(plot)
	local result = {}
	local used = {}

	if not plot then
		return result
	end

	for _, obj in ipairs(plot:GetDescendants()) do
		if isNamedContainer(obj, LEVEL_BUTTON_NAME) and not hasNamedAncestor(obj, LEVEL_BUTTON_NAME) then
			local part = getButtonPart(obj)

			if part and not used[part] then
				used[part] = true
				table.insert(result, part)
			end
		elseif obj:IsA("BasePart") and normalize(obj.Name) == normalize(LEVEL_BUTTON_NAME) then
			if not used[obj] then
				used[obj] = true
				table.insert(result, obj)
			end
		end
	end

	return result
end

local function clearOldGuiObjects()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == "BrainrotUpgradeButtonGui"
			or obj.Name == "BrainrotUpgradeBillboardGui"
			or obj.Name == "BrainrotUpgradeSurfaceGui"
			or obj.Name == "MoneyCollectBillboardGui"
			or obj.Name == "MoneyCollectSurfaceGui"
			or obj.Name == "LocalOwnerMoneySurfaceGui"
			or obj.Name == "LocalOwnerUpgradeSurfaceGui"
			or obj.Name == "LocalOwnerNpcInfoGui"
			or obj.Name == "OwnerOnlyMoneyBillboardGui"
			or obj.Name == "OwnerOnlyMoneySurfaceGui"
			or string.sub(obj.Name, 1, #MONEY_GUI_PREFIX) == MONEY_GUI_PREFIX
			or obj.Name == MONEY_FX_NAME then
			obj:Destroy()
		end
	end
end

local function createCleanLabel(parent, textColor, strokeTransparency)
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = textColor or Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = strokeTransparency or 0
	label.Text = ""
	label.Parent = parent

	return label
end

local function ensureUpgradeGui(part)
	local gui = upgradeGuis[part]

	if gui and gui.Parent then
		gui.Adornee = part
		return gui
	end

	gui = Instance.new("SurfaceGui")
	gui.Name = UPGRADE_GUI_NAME
	gui.Adornee = part
	gui.Face = UPGRADE_TEXT_FACE
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 55
	gui.Parent = part

	createCleanLabel(gui, Color3.fromRGB(255, 255, 255), 0)

	upgradeGuis[part] = gui
	return gui
end

local function ensureMoneyGuis(part)
	local cached = moneyGuis[part]

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

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("SurfaceGui") and string.sub(child.Name, 1, #MONEY_GUI_PREFIX) == MONEY_GUI_PREFIX then
			child:Destroy()
		end
	end

	local list = {}

	for _, face in ipairs(MONEY_TEXT_FACES) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = MONEY_GUI_PREFIX .. face.Name
		gui.Adornee = part
		gui.Face = face
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 85
		gui.Parent = part

		local label = createCleanLabel(gui, Color3.fromRGB(255, 255, 255), 0)

		table.insert(list, {
			gui = gui,
			label = label,
		})
	end

	moneyGuis[part] = list
	return list
end

local function ensureNpcGui(npc)
	local root = getNpcRoot(npc)

	if not root then
		return nil
	end

	local gui = npcGuis[npc]

	if gui and gui.Parent then
		gui.Adornee = root
		return gui
	end

	local height = 4
	local ok, _, size = pcall(function()
		return npc:GetBoundingBox()
	end)

	if ok and size then
		height = math.max(3, size.Y)
	end

	gui = Instance.new("BillboardGui")
	gui.Name = NPC_GUI_NAME
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(160, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 1.2, 0)
	gui.MaxDistance = 80
	gui.Parent = root

	createCleanLabel(gui, Color3.fromRGB(255, 255, 255), 0.1)

	npcGuis[npc] = gui
	return gui
end

local function setSurfaceGuiText(gui, text)
	local label = gui and gui:FindFirstChild("Text")

	if label and label:IsA("TextLabel") and label.Text ~= text then
		label.Text = text
	end
end

local function setMoneyPartText(part, text)
	local list = ensureMoneyGuis(part)

	for _, item in ipairs(list) do
		if item.label and item.label.Text ~= text then
			item.label.Text = text
		end
	end
end

local function spawnSmallMoneyEffect(part, amount)
	amount = math.floor(tonumber(amount) or 0)

	if amount <= 0 then
		return
	end

	local now = os.clock()
	local last = lastMoneyFx[part] or 0

	if now - last < 0.16 then
		return
	end

	lastMoneyFx[part] = now

	local count = 2

	for i = 1, count do
		local gui = Instance.new("BillboardGui")
		gui.Name = MONEY_FX_NAME
		gui.Adornee = part
		gui.AlwaysOnTop = true
		gui.Size = UDim2.fromOffset(i == 1 and 90 or 36, i == 1 and 28 or 24)
		gui.MaxDistance = 70
		gui.StudsOffsetWorldSpace = Vector3.new(
			math.random(-8, 8) / 10,
			part.Size.Y / 2 + 0.55 + (i * 0.12),
			math.random(-8, 8) / 10
		)
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextWrapped = true
		label.TextColor3 = Color3.fromRGB(170, 255, 90)
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0.15
		label.TextTransparency = 0
		label.Text = i == 1 and ("+$" .. formatMoney(amount)) or "$"
		label.Parent = gui

		local rise = TweenService:Create(
			gui,
			TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(
					math.random(-4, 4) / 10,
					1.1 + math.random() * 0.35,
					math.random(-4, 4) / 10
				),
			}
		)

		local fade = TweenService:Create(
			label,
			TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}
		)

		rise:Play()
		fade:Play()

		Debris:AddItem(gui, 0.85)
	end
end

local function updateUpgradeText(part)
	local npc = getNpcForObjectStrict(part)
	local gui = ensureUpgradeGui(part)

	if not npc then
		setSurfaceGuiText(gui, "")
		return
	end

	local level = getLevel(npc)
	local cost = calculateUpgradeCost(npc)

	setSurfaceGuiText(gui, "LV " .. tostring(level) .. " > LV " .. tostring(level + 1) .. "\n$" .. formatMoney(cost))
end

local function updateMoneyText(target)
	local part = target.part
	local container = target.container
	local npc = getNpcForObjectStrict(part)
	local amount = getCollectAmount(part, container, npc)

	local previous = previousAmounts[part]

	-- Money FX disabled. Old collect display only.

	previousAmounts[part] = amount

	if not npc or amount <= 0 then
		setMoneyPartText(part, "")
		return
	end

	setMoneyPartText(part, "$" .. formatMoney(amount))
end

local function updateNpcInfo(npc)
	local gui = ensureNpcGui(npc)

	if not gui then
		return
	end

	local text = getBrainrotName(npc)
		.. "\n"
		.. getMutation(npc)
		.. "\n$"
		.. formatMoney(getMps(npc))
		.. "/s"

	setSurfaceGuiText(gui, text)
end

local function cleanupDict(dict, valid)
	for key, value in pairs(dict) do
		if not valid[key] or not key or not key.Parent then
			if typeof(value) == "table" then
				for _, item in ipairs(value) do
					if item.gui then
						item.gui:Destroy()
					end
				end
			elseif value then
				value:Destroy()
			end

			dict[key] = nil
			previousAmounts[key] = nil
			lastMoneyFx[key] = nil
		end
	end
end

clearOldGuiObjects()

task.spawn(function()
	local cleanupTimer = 0

	while true do
		local ownPlot = getOwnPlot()

		local validUpgrade = {}
		local validMoney = {}
		local validNpc = {}

		if ownPlot then
			for _, part in ipairs(getUpgradeButtonParts(ownPlot)) do
				validUpgrade[part] = true
				updateUpgradeText(part)
			end

			for _, target in ipairs(getMoneyTargets(ownPlot)) do
				validMoney[target.part] = true
				updateMoneyText(target)
			end

			for _, npc in ipairs(getPlacedNpcs()) do
				validNpc[npc] = true
				updateNpcInfo(npc)
			end
		end

		cleanupDict(upgradeGuis, validUpgrade)
		cleanupDict(moneyGuis, validMoney)
		cleanupDict(npcGuis, validNpc)

		cleanupTimer += UPDATE_EVERY

		if cleanupTimer >= 5 then
			cleanupTimer = 0
			clearOldGuiObjects()
		end

		task.wait(UPDATE_EVERY)
	end
end)

print("[PlotOwnerText] Loaded polished owner-only plot UI and subtle money effects.")
