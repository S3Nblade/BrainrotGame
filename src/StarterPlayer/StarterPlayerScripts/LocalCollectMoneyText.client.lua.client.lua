--!nonstrict
-- StarterPlayerScripts/LocalCollectMoneyText.client.lua
-- Local-only collect money text.
--
-- Fixes:
-- 1. Destroys all old/global collect GUIs locally.
-- 2. Shows collect text only on the local player's plot.
-- 3. Uses NPC Earned from Workspace.BrainrotNPCs.
-- 4. Maps each NPC to only its nearest collect part.
-- 5. Hides text when amount is 0.
-- 6. White text only.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local LOCAL_COLLECT_GUI_NAME = "LocalBrainrotCollectMoneyText"
local NPC_INFO_GUI_NAME = "BrainrotPlacedInfoGui"

local SCAN_INTERVAL = 0.25
local MAX_COLLECT_DISTANCE = 22

local MONEY_ATTRS = {
	"Earned",
	"ReadyMoney",
	"ReadyToCollect",
	"MoneyToCollect",
	"CollectAmount",
	"CollectedAmount",
	"StoredMoney",
	"PendingMoney",
	"GeneratedMoney",
	"UncollectedMoney",
	"CurrentMoney",
	"Money",
	"Cash",
}

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

local function getBrainrotFolder()
	return Workspace:FindFirstChild("BrainrotNPCs")
end

local function isOwnedByLocalPlayer(model)
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

local function plotOwnedByLocalPlayer(plot)
	if not plot then
		return false
	end

	local ownerId =
		plot:GetAttribute("OwnerUserId")
		or plot:GetAttribute("PlacedOwnerUserId")
		or plot:GetAttribute("UserId")
		or plot:GetAttribute("PlayerUserId")

	if tonumber(ownerId) == player.UserId then
		return true
	end

	local ownerName =
		plot:GetAttribute("OwnerName")
		or plot:GetAttribute("PlayerName")

	if ownerName == player.Name then
		return true
	end

	local brainrotFolder = getBrainrotFolder()
	if brainrotFolder then
		for _, obj in ipairs(brainrotFolder:GetDescendants()) do
			if obj:IsA("Model")
				and isPlacedBrainrot(obj)
				and isOwnedByLocalPlayer(obj)
				and npcBelongsToPlot(obj, plot) then

				return true
			end
		end
	end

	return false
end

local function getOwnPlot()
	local plots = getPlotsFolder()

	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			if plotOwnedByLocalPlayer(plot) then
				return plot
			end
		end
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if (obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart")) and plotOwnedByLocalPlayer(obj) then
			return obj
		end
	end

	return nil
end

local function readMoneyFromInstance(instance)
	if not instance then
		return 0
	end

	for _, attr in ipairs(MONEY_ATTRS) do
		local value = tonumber(instance:GetAttribute(attr))
		if value and value > 0 then
			return value
		end
	end

	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("NumberValue") or child:IsA("IntValue") then
			for _, attr in ipairs(MONEY_ATTRS) do
				if child.Name == attr then
					local value = tonumber(child.Value)
					if value and value > 0 then
						return value
					end
				end
			end
		end
	end

	return 0
end

local function isMoneyCollectModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	local name = string.lower(model.Name)

	return string.find(name, "money collect") ~= nil
		or string.find(name, "collectmoney") ~= nil
		or string.find(name, "collect money") ~= nil
end

local function getGreenCollectPart(model)
	local greenByName = model:FindFirstChild("green", true) or model:FindFirstChild("Green", true)
	if greenByName and greenByName:IsA("BasePart") then
		return greenByName
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			local c = obj.Color
			if c.G > c.R and c.G > c.B then
				return obj
			end
		end
	end

	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function getCollectPartsInPlot(plot)
	local parts = {}
	local seen = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj:IsA("Model") and isMoneyCollectModel(obj) then
			local part = getGreenCollectPart(obj)
			if part and not seen[part] then
				seen[part] = true
				table.insert(parts, part)
			end
		elseif obj:IsA("BasePart")
			and (obj:GetAttribute("PrivateCollectGuiPart") == true or obj:GetAttribute("MoneyCollectPart") == true) then
			if not seen[obj] then
				seen[obj] = true
				table.insert(parts, obj)
			end
		end
	end

	return parts
end

local function getOwnedNpcsForPlot(plot)
	local list = {}
	local seen = {}

	local function scan(container)
		if not container then
			return
		end

		for _, obj in ipairs(container:GetDescendants()) do
			if obj:IsA("Model") and not seen[obj] then
				seen[obj] = true

				if isPlacedBrainrot(obj)
					and isOwnedByLocalPlayer(obj)
					and npcBelongsToPlot(obj, plot) then

					local root = getRoot(obj)
					if root then
						table.insert(list, obj)
					end
				end
			end
		end
	end

	scan(getBrainrotFolder())
	scan(Workspace)

	return list
end

local function destroyAllNonLocalCollectGuis()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SurfaceGui") or obj:IsA("BillboardGui") then
			local lower = string.lower(obj.Name)

			if obj.Name ~= LOCAL_COLLECT_GUI_NAME and obj.Name ~= NPC_INFO_GUI_NAME then
				if string.find(lower, "collect")
					or string.find(lower, "money") then
					obj:Destroy()
				end
			end
		end
	end
end

local function destroyLocalGuisOutsideOwnPlot(ownPlot)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SurfaceGui") and obj.Name == LOCAL_COLLECT_GUI_NAME then
			local parent = obj.Parent

			if not ownPlot or not parent or not parent:IsDescendantOf(ownPlot) then
				obj:Destroy()
			end
		end
	end
end

local function removeLocalGui(part)
	if not part then
		return
	end

	local gui = part:FindFirstChild(LOCAL_COLLECT_GUI_NAME)
	if gui then
		gui:Destroy()
	end
end

local function createLocalCollectText(part)
	local gui = part:FindFirstChild(LOCAL_COLLECT_GUI_NAME)

	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name = LOCAL_COLLECT_GUI_NAME
		gui.Face = Enum.NormalId.Top
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
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextStrokeTransparency = 0
		label.Parent = gui
	end

	return gui:FindFirstChild("Text")
end

local function buildCollectMap(plot)
	local collectParts = getCollectPartsInPlot(plot)
	local npcs = getOwnedNpcsForPlot(plot)

	local partToNpc = {}
	local npcToDistance = {}

	for _, npc in ipairs(npcs) do
		local root = getRoot(npc)
		local earned = readMoneyFromInstance(npc)

		if root and earned > 0 then
			local bestPart = nil
			local bestDistance = MAX_COLLECT_DISTANCE

			for _, part in ipairs(collectParts) do
				local distance = (root.Position - part.Position).Magnitude

				if distance <= bestDistance then
					bestDistance = distance
					bestPart = part
				end
			end

			if bestPart then
				local existingNpc = partToNpc[bestPart]
				local existingDistance = existingNpc and npcToDistance[existingNpc] or math.huge

				if not existingNpc or bestDistance < existingDistance then
					partToNpc[bestPart] = npc
					npcToDistance[npc] = bestDistance
				end
			end
		end
	end

	return collectParts, partToNpc
end

local function updateOwnCollectTexts()
	local plot = getOwnPlot()

	destroyAllNonLocalCollectGuis()
	destroyLocalGuisOutsideOwnPlot(plot)

	if not plot then
		return
	end

	local collectParts, partToNpc = buildCollectMap(plot)

	for _, part in ipairs(collectParts) do
		local npc = partToNpc[part]

		if npc then
			local amount = readMoneyFromInstance(npc)

			if amount > 0 then
				local label = createLocalCollectText(part)
				if label then
					label.TextColor3 = Color3.fromRGB(255, 255, 255)
					label.Text = "$" .. formatNumber(amount)
				end
			else
				removeLocalGui(part)
			end
		else
			removeLocalGui(part)
		end
	end
end

task.spawn(function()
	while true do
		updateOwnCollectTexts()
		task.wait(SCAN_INTERVAL)
	end
end)

print("[LocalCollectMoneyText] Loaded SLOT-MAPPED local collect text. Own plot only.")
