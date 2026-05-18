--!nonstrict
-- ServerScriptService/BrainrotStrictCollect.server.lua
-- Strict collect system:
-- 1. Only ONE main part per Money Collect model gets the money GUI attributes.
-- 2. Empty collect parts show nothing.
-- 3. Touching ANY part inside the correct Money Collect model collects.
-- 4. One placed NPC links to one collect model only.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local UPDATE_EVERY = 0.15
local COLLECT_DEBOUNCE = 0.5
local SAME_FLOOR_Y_DISTANCE = 12
local MAX_PAIR_DISTANCE = 45

local collectConnections = {}
local collectDebounce = {}

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

local function notify(player, message, variant)
	if player and player.Parent then
		notifyRemote:FireClient(player, {
			message = message,
			variant = variant or "success",
		})
	end
end

local function normalize(text)
	return string.lower(tostring(text)):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
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

local function playerOwnsPlot(player, plot)
	if not player or not plot then
		return false
	end

	return tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(plot:GetAttribute("OwnerName")) == player.Name
		or tostring(plot:GetAttribute("Owner")) == player.Name
end

local function getPlayerPlot(player)
	local plotsFolder = getPlotsFolder()
	if not plotsFolder then
		return nil
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if (plot:IsA("Model") or plot:IsA("Folder")) and playerOwnsPlot(player, plot) then
			return plot
		end
	end

	return nil
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

local function isMoneyCollectObject(obj)
	local n = normalize(obj.Name)

	if obj:GetAttribute("MoneyCollect") == true then
		return true
	end

	return n == "moneycollect"
		or n == "collectmoney"
		or n == "moneycollectpart"
		or n == "collectmoneypart"
		or string.find(n, "moneycollect") ~= nil
		or string.find(n, "collectmoney") ~= nil
end

local function hasMoneyCollectAncestor(obj)
	local current = obj.Parent

	while current and current ~= Workspace do
		if isMoneyCollectObject(current) then
			return true
		end

		current = current.Parent
	end

	return false
end

local function getTopCollectContainerFromPart(part)
	local current = part
	local found = nil

	while current and current ~= Workspace do
		if isMoneyCollectObject(current) then
			found = current
		end

		current = current.Parent
	end

	return found
end

local function getBestMoneyPart(container)
	if container:IsA("BasePart") then
		return container
	end

	local green = container:FindFirstChild("green", true)
	if green and green:IsA("BasePart") then
		return green
	end

	local best = nil
	local bestScore = -math.huge

	for _, part in ipairs(getAllBaseParts(container)) do
		local n = normalize(part.Name)
		local score = 0

		if string.find(n, "green") then
			score += 150000
		end

		if string.find(n, "money") then
			score += 100000
		end

		if string.find(n, "collect") then
			score += 100000
		end

		score += part.Size.X * part.Size.Z * 1000
		score += part.Position.Y * 20

		if score > bestScore then
			bestScore = score
			best = part
		end
	end

	return best
end

local function getCollectContainers(plot)
	local result = {}
	local used = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if (obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart"))
			and isMoneyCollectObject(obj)
			and not hasMoneyCollectAncestor(obj)
			and not used[obj] then

			local mainPart = getBestMoneyPart(obj)

			if mainPart then
				used[obj] = true
				table.insert(result, {
					container = obj,
					mainPart = mainPart,
				})
			end
		end
	end

	return result
end

local function isPlacedNpc(npc)
	return npc
		and npc:IsA("Model")
		and npc:GetAttribute("InventoryOnly") ~= true
		and (
			npc:GetAttribute("IsPlaced") == true
			or npc:GetAttribute("Placed") == true
		)
end

local function ownsNpc(player, npc)
	return tostring(npc:GetAttribute("PlacedOwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("OwnerName")) == player.Name
		or tostring(npc:GetAttribute("Owner")) == player.Name
end

local function getNpcUid(npc)
	return npc:GetAttribute("BrainrotUID")
		or npc:GetAttribute("UID")
		or npc:GetAttribute("BrainrotUid")
		or npc:GetAttribute("DirectInventoryUid")
		or npc:GetAttribute("InventoryUid")
end

local function getNpcRoot(npc)
	return npc.PrimaryPart
		or npc:FindFirstChild("HumanoidRootPart", true)
		or npc:FindFirstChildWhichIsA("BasePart", true)
end

local function getPlacedNpcData(player)
	local npcFolder = getNpcFolder()
	local result = {}

	if not npcFolder then
		return result
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) and ownsNpc(player, npc) then
			local root = getNpcRoot(npc)

			if root then
				table.insert(result, {
					model = npc,
					root = root,
					uid = tostring(getNpcUid(npc) or ""),
					slotId = tostring(npc:GetAttribute("AssignedSlotId") or ""),
				})
			end
		end
	end

	return result
end

local function getEarned(npc)
	return math.floor(tonumber(npc:GetAttribute("Earned")) or 0)
end

local function clearPrivateAttributesFromPart(part)
	part:SetAttribute("PrivateCollectGuiPart", nil)
	part:SetAttribute("PrivateOwnerUserId", nil)
	part:SetAttribute("PrivateCollectAmount", nil)
	part:SetAttribute("LinkedBrainrotUID", nil)
end

local function clearContainerPrivateAttributes(collect)
	for _, part in ipairs(getAllBaseParts(collect.container)) do
		clearPrivateAttributesFromPart(part)
	end
end

local function assignCollects(player, plot)
	local collects = getCollectContainers(plot)
	local npcs = getPlacedNpcData(player)

	local assignedMainPartToNpc = {}
	local usedCollects = {}
	local usedNpcs = {}

	-- Exact slot pass.
	for _, npcData in ipairs(npcs) do
		if npcData.slotId ~= "" then
			local bestCollect = nil
			local bestDistance = math.huge

			for _, collect in ipairs(collects) do
				if not usedCollects[collect] then
					local collectSlot =
						tostring(collect.mainPart:GetAttribute("BrainrotSlotId") or collect.container:GetAttribute("BrainrotSlotId") or "")

					if collectSlot == npcData.slotId then
						local distance = (npcData.root.Position - collect.mainPart.Position).Magnitude

						if distance < bestDistance then
							bestDistance = distance
							bestCollect = collect
						end
					end
				end
			end

			if bestCollect then
				assignedMainPartToNpc[bestCollect.mainPart] = npcData.model
				usedCollects[bestCollect] = true
				usedNpcs[npcData.model] = true
			end
		end
	end

	-- Fallback pass: nearest same-floor collect, but still one NPC to one collect only.
	for _, npcData in ipairs(npcs) do
		if not usedNpcs[npcData.model] then
			local bestCollect = nil
			local bestScore = math.huge

			for _, collect in ipairs(collects) do
				if not usedCollects[collect] then
					local yDiff = math.abs(npcData.root.Position.Y - collect.mainPart.Position.Y)

					if yDiff <= SAME_FLOOR_Y_DISTANCE then
						local distance = (npcData.root.Position - collect.mainPart.Position).Magnitude

						if distance <= MAX_PAIR_DISTANCE then
							local score = distance + yDiff * 5

							if score < bestScore then
								bestScore = score
								bestCollect = collect
							end
						end
					end
				end
			end

			if bestCollect then
				assignedMainPartToNpc[bestCollect.mainPart] = npcData.model
				usedCollects[bestCollect] = true
				usedNpcs[npcData.model] = true
			end
		end
	end

	-- Clear all containers first, then mark only the main part if assigned.
	for _, collect in ipairs(collects) do
		clearContainerPrivateAttributes(collect)

		local npc = assignedMainPartToNpc[collect.mainPart]

		if npc then
			collect.mainPart:SetAttribute("PrivateCollectGuiPart", true)
			collect.mainPart:SetAttribute("PrivateOwnerUserId", player.UserId)
			collect.mainPart:SetAttribute("PrivateCollectAmount", getEarned(npc))
			collect.mainPart:SetAttribute("LinkedBrainrotUID", getNpcUid(npc))
		else
			collect.mainPart:SetAttribute("PrivateCollectGuiPart", true)
			collect.mainPart:SetAttribute("PrivateOwnerUserId", player.UserId)
			collect.mainPart:SetAttribute("PrivateCollectAmount", 0)
			collect.mainPart:SetAttribute("LinkedBrainrotUID", nil)
		end
	end

	return collects, assignedMainPartToNpc
end

local function findAssignedNpcForTouchedPart(player, touchedPart)
	local plot = findPlotFromObject(touchedPart)
	if not plot or not playerOwnsPlot(player, plot) then
		return nil, nil, nil
	end

	local collectContainer = getTopCollectContainerFromPart(touchedPart)
	if not collectContainer then
		return nil, nil, nil
	end

	local mainPart = getBestMoneyPart(collectContainer)
	if not mainPart then
		return nil, nil, nil
	end

	local _, assigned = assignCollects(player, plot)
	local npc = assigned[mainPart]

	return npc, mainPart, collectContainer
end

local function getMoneyValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local money =
		leaderstats:FindFirstChild("Money")
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

local function addMoney(player, amount)
	amount = math.floor(tonumber(amount) or 0)

	if amount <= 0 then
		return
	end

	local money = getMoneyValue(player)
	money.Value += amount

	player:SetAttribute("Money", money.Value)
	player:SetAttribute("Coins", money.Value)
	player:SetAttribute("Cash", money.Value)

	updateCoinsEvent:FireClient(player, money.Value)
end

local function collectFromPart(touchedPart, hit)
	local character = hit and hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local npc, mainPart, collectContainer = findAssignedNpcForTouchedPart(player, touchedPart)

	if not mainPart or not collectContainer then
		return
	end

	local key = tostring(player.UserId) .. ":" .. collectContainer:GetFullName()

	if collectDebounce[key] and os.clock() - collectDebounce[key] < COLLECT_DEBOUNCE then
		return
	end

	collectDebounce[key] = os.clock()

	if not npc then
		mainPart:SetAttribute("PrivateCollectAmount", 0)
		mainPart:SetAttribute("LinkedBrainrotUID", nil)
		return
	end

	local amount = getEarned(npc)

	if amount <= 0 then
		mainPart:SetAttribute("PrivateCollectAmount", 0)
		return
	end

	npc:SetAttribute("Earned", 0)

	mainPart:SetAttribute("PrivateCollectGuiPart", true)
	mainPart:SetAttribute("PrivateOwnerUserId", player.UserId)
	mainPart:SetAttribute("PrivateCollectAmount", 0)
	mainPart:SetAttribute("LinkedBrainrotUID", getNpcUid(npc))

	addMoney(player, amount)
	notify(player, "+$" .. formatMoney(amount), "success")
end

local function connectCollectContainer(collect)
	for _, part in ipairs(getAllBaseParts(collect.container)) do
		part.CanTouch = true

		if not collectConnections[part] then
			collectConnections[part] = part.Touched:Connect(function(hit)
				collectFromPart(part, hit)
			end)
		end
	end
end

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local plot = getPlayerPlot(player)

			if plot then
				local collects = assignCollects(player, plot)

				for _, collect in ipairs(collects) do
					connectCollectContainer(collect)
				end
			end
		end

		task.wait(UPDATE_EVERY)
	end
end)

print("[BrainrotStrictCollect] Loaded. One GUI per occupied collect slot, strict collection.")