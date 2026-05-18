--!nonstrict
-- ServerScriptService/BrainrotPersistentSaveBridge.server.lua
-- Permanent backup save system for:
-- money
-- inventory brainrots
-- placed plot brainrots
-- earned money on placed brainrots
--
-- Uses its own safe DataStore so it does not break your existing database.service.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local STORE_NAME = "BrainrotPersistentSave_v4"
local NPC_FOLDER_NAME = "BrainrotNPCs"

local SAVE_EVERY = 10
local RESTORE_AFTER_SECONDS = 6

local store = DataStoreService:GetDataStore(STORE_NAME)

local dirtyPlayers = {}
local savingPlayers = {}
local connectedNpcs = {}

local function log(...)
	print("[BrainrotPersistentSaveBridge]", ...)
end

local function warnLog(...)
	warn("[BrainrotPersistentSaveBridge]", ...)
end

local function getNpcFolder()
	local folder = Workspace:FindFirstChild(NPC_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = NPC_FOLDER_NAME
		folder.Parent = Workspace
	end

	return folder
end

local function getKey(player)
	return "player_" .. tostring(player.UserId)
end

local function primitiveAttributes(instance)
	local attrs = {}

	for key, value in pairs(instance:GetAttributes()) do
		local t = typeof(value)

		if t == "string" or t == "number" or t == "boolean" then
			attrs[key] = value
		end
	end

	return attrs
end

local function getUid(instance)
	return instance:GetAttribute("BrainrotUID")
		or instance:GetAttribute("UID")
		or instance:GetAttribute("BrainrotUid")
		or instance:GetAttribute("DirectInventoryUid")
		or instance:GetAttribute("InventoryUid")
end

local function ensureUid(instance)
	local uid = getUid(instance)

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

local function ownsNpc(player, npc)
	return tostring(npc:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("PlacedOwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("HeldOwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("CapturedByUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("OwnerName")) == player.Name
		or tostring(npc:GetAttribute("Owner")) == player.Name
end

local function isBrainrotNpc(npc)
	if not npc:IsA("Model") then
		return false
	end

	return npc:GetAttribute("BrainrotUID") ~= nil
		or npc:GetAttribute("UID") ~= nil
		or npc:GetAttribute("BrainrotUid") ~= nil
		or npc:GetAttribute("DirectInventoryUid") ~= nil
		or npc:GetAttribute("InventoryUid") ~= nil
		or npc:GetAttribute("InventoryOnly") ~= nil
		or npc:GetAttribute("IsPlaced") ~= nil
		or npc:GetAttribute("Placed") ~= nil
		or npc:GetAttribute("CashPerSecond") ~= nil
		or npc:GetAttribute("MPS") ~= nil
end

local function isSavedNpc(player, npc)
	if not isBrainrotNpc(npc) then
		return false
	end

	if not ownsNpc(player, npc) then
		return false
	end

	local inventoryOnly = npc:GetAttribute("InventoryOnly") == true
	local placed = npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true

	return inventoryOnly or placed
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

local function getMoneyAmount(player)
	local value = getMoneyValue(player)
	return tonumber(value.Value) or 0
end

local function setMoneyAmount(player, amount)
	amount = tonumber(amount) or 0

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local money = leaderstats:FindFirstChild("Money")
	if not money then
		money = Instance.new("NumberValue")
		money.Name = "Money"
		money.Parent = leaderstats
	end

	if money:IsA("ValueBase") then
		money.Value = amount
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if coins and coins:IsA("ValueBase") then
		coins.Value = amount
	end

	local cash = leaderstats:FindFirstChild("Cash")
	if cash and cash:IsA("ValueBase") then
		cash.Value = amount
	end

	player:SetAttribute("Money", amount)
	player:SetAttribute("Coins", amount)
	player:SetAttribute("Cash", amount)

	local updateCoinsEvent = ReplicatedStorage:FindFirstChild("UpdateCoins")
	if updateCoinsEvent and updateCoinsEvent:IsA("RemoteEvent") then
		updateCoinsEvent:FireClient(player, amount)
	end
end

local function serializeNpc(player, npc)
	local uid = ensureUid(npc)
	local cf = npc:GetPivot()
	local components = { cf:GetComponents() }

	local attrs = primitiveAttributes(npc)

	attrs.BrainrotUID = uid
	attrs.UID = uid
	attrs.BrainrotUid = uid
	attrs.DirectInventoryUid = uid
	attrs.InventoryUid = uid
	attrs.OwnerUserId = player.UserId
	attrs.OwnerName = player.Name

	local placed = npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true
	local inventoryOnly = npc:GetAttribute("InventoryOnly") == true

	return {
		uid = uid,
		name = tostring(npc.Name),
		attrs = attrs,
		pivot = components,
		placed = placed,
		inventoryOnly = inventoryOnly,
		earned = tonumber(npc:GetAttribute("Earned")) or 0,
		assignedSlotId = tostring(npc:GetAttribute("AssignedSlotId") or ""),
		assignedSlotFloor = tonumber(npc:GetAttribute("AssignedSlotFloor")) or 1,
		assignedSlotPath = tostring(npc:GetAttribute("AssignedSlotPath") or ""),
		templateName = tostring(
			npc:GetAttribute("TemplateName")
				or npc:GetAttribute("BrainrotName")
				or npc:GetAttribute("DisplayName")
				or npc.Name
		),
	}
end

local function collectSaveData(player)
	local npcs = {}

	for _, npc in ipairs(getNpcFolder():GetChildren()) do
		if isSavedNpc(player, npc) then
			table.insert(npcs, serializeNpc(player, npc))
		end
	end

	return {
		version = 4,
		userId = player.UserId,
		name = player.Name,
		savedAt = os.time(),
		money = getMoneyAmount(player),
		npcs = npcs,
	}
end

local function markDirty(player, reason)
	if not player or not player.Parent then
		return
	end

	dirtyPlayers[player] = reason or "changed"
end

local function savePlayer(player, reason)
	if not player or not player.Parent then
		return
	end

	if savingPlayers[player] then
		return
	end

	savingPlayers[player] = true

	local data = collectSaveData(player)
	local encoded = HttpService:JSONEncode(data)

	local ok, err = pcall(function()
		store:SetAsync(getKey(player), encoded)
	end)

	savingPlayers[player] = nil

	if ok then
		dirtyPlayers[player] = nil
		log("Saved:", player.Name, "Money:", data.money, "NPCs:", #data.npcs, "Reason:", reason or "manual")
	else
		warnLog("SAVE FAILED:", player.Name, err)
		warnLog("Enable Game Settings > Security > Enable Studio Access to API Services")
	end
end

local function getExistingNpcByUid(uid)
	if not uid or tostring(uid) == "" then
		return nil
	end

	for _, npc in ipairs(getNpcFolder():GetChildren()) do
		if npc:IsA("Model") and tostring(getUid(npc)) == tostring(uid) then
			return npc
		end
	end

	return nil
end

local function findTemplate(entry)
	local names = {
		entry.templateName,
		entry.name,
		entry.attrs and entry.attrs.TemplateName,
		entry.attrs and entry.attrs.BrainrotName,
		entry.attrs and entry.attrs.DisplayName,
	}

	local roots = {
		ReplicatedStorage,
		ServerStorage,
	}

	for _, root in ipairs(roots) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("Model") then
				for _, wanted in ipairs(names) do
					if wanted and tostring(wanted) ~= "" then
						if obj.Name == tostring(wanted)
							or tostring(obj:GetAttribute("TemplateName")) == tostring(wanted)
							or tostring(obj:GetAttribute("BrainrotName")) == tostring(wanted)
							or tostring(obj:GetAttribute("DisplayName")) == tostring(wanted) then
							return obj
						end
					end
				end
			end
		end
	end

	return nil
end

local function createFallbackNpc(entry)
	local npc = Instance.new("Model")
	npc.Name = tostring(entry.name or entry.templateName or "Brainrot")

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2, 2)
	body.Color = Color3.fromRGB(255, 220, 70)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = npc

	npc.PrimaryPart = body

	return npc
end

local function restoreNpc(player, entry)
	if not entry or not entry.uid then
		return
	end

	local npc = getExistingNpcByUid(entry.uid)

	if not npc then
		local template = findTemplate(entry)

		if template then
			npc = template:Clone()
			npc.Name = tostring(entry.name or template.Name)
		else
			npc = createFallbackNpc(entry)
		end

		npc.Parent = getNpcFolder()
	end

	if entry.attrs then
		for key, value in pairs(entry.attrs) do
			local t = typeof(value)
			if t == "string" or t == "number" or t == "boolean" then
				pcall(function()
					npc:SetAttribute(key, value)
				end)
			end
		end
	end

	npc:SetAttribute("BrainrotUID", entry.uid)
	npc:SetAttribute("UID", entry.uid)
	npc:SetAttribute("BrainrotUid", entry.uid)
	npc:SetAttribute("DirectInventoryUid", entry.uid)
	npc:SetAttribute("InventoryUid", entry.uid)

	npc:SetAttribute("OwnerUserId", player.UserId)
	npc:SetAttribute("OwnerName", player.Name)

	if entry.placed then
		npc:SetAttribute("InventoryOnly", false)
		npc:SetAttribute("IsPlaced", true)
		npc:SetAttribute("Placed", true)
		npc:SetAttribute("PlacedOwnerUserId", player.UserId)
		npc:SetAttribute("AssignedSlotId", entry.assignedSlotId or "")
		npc:SetAttribute("AssignedSlotFloor", entry.assignedSlotFloor or 1)
		npc:SetAttribute("AssignedSlotPath", entry.assignedSlotPath or "")
	else
		npc:SetAttribute("InventoryOnly", true)
		npc:SetAttribute("IsPlaced", false)
		npc:SetAttribute("Placed", false)
		npc:SetAttribute("PlacedOwnerUserId", nil)
		npc:SetAttribute("HeldOwnerUserId", player.UserId)
		npc:SetAttribute("AssignedSlotId", nil)
		npc:SetAttribute("AssignedSlotFloor", nil)
		npc:SetAttribute("AssignedSlotPath", nil)
	end

	npc:SetAttribute("Earned", tonumber(entry.earned) or tonumber(npc:GetAttribute("Earned")) or 0)

	if entry.pivot and type(entry.pivot) == "table" and #entry.pivot >= 12 then
		pcall(function()
			npc:PivotTo(CFrame.new(table.unpack(entry.pivot)))
		end)
	end

	return npc
end

local function restorePlayer(player)
	local ok, result = pcall(function()
		return store:GetAsync(getKey(player))
	end)

	if not ok then
		warnLog("RESTORE FAILED:", player.Name, result)
		return
	end

	if not result or result == "" then
		log("No persistent save found for:", player.Name)
		return
	end

	local decoded

	local okDecode, decodeErr = pcall(function()
		if type(result) == "string" then
			decoded = HttpService:JSONDecode(result)
		elseif type(result) == "table" then
			decoded = result
		end
	end)

	if not okDecode or type(decoded) ~= "table" then
		warnLog("Could not decode save for:", player.Name, decodeErr)
		return
	end

	setMoneyAmount(player, tonumber(decoded.money) or 0)

	local restored = 0

	for _, entry in ipairs(decoded.npcs or {}) do
		local npc = restoreNpc(player, entry)
		if npc then
			restored += 1
		end
	end

	log("Restored:", player.Name, "Money:", decoded.money or 0, "NPCs:", restored)
end

local function connectMoneyWatch(player)
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 20)
		if not leaderstats then
			return
		end

		for _, child in ipairs(leaderstats:GetChildren()) do
			if child:IsA("ValueBase") and (child.Name == "Money" or child.Name == "Coins" or child.Name == "Cash") then
				child.Changed:Connect(function()
					markDirty(player, "money changed")
				end)
			end
		end

		leaderstats.ChildAdded:Connect(function(child)
			if child:IsA("ValueBase") and (child.Name == "Money" or child.Name == "Coins" or child.Name == "Cash") then
				child.Changed:Connect(function()
					markDirty(player, "money changed")
				end)
			end
		end)
	end)
end

local function connectNpcWatch(npc)
	if connectedNpcs[npc] then
		return
	end

	connectedNpcs[npc] = true

	npc.AttributeChanged:Connect(function(attr)
		local ownerId =
			npc:GetAttribute("OwnerUserId")
			or npc:GetAttribute("PlacedOwnerUserId")
			or npc:GetAttribute("HeldOwnerUserId")

		if ownerId then
			local player = Players:GetPlayerByUserId(tonumber(ownerId))
			if player then
				markDirty(player, "npc " .. attr)
			end
		end
	end)

	npc.AncestryChanged:Connect(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if ownsNpc(player, npc) then
				markDirty(player, "npc moved/destroyed")
			end
		end
	end)
end

getNpcFolder().ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		connectNpcWatch(child)

		task.defer(function()
			for _, player in ipairs(Players:GetPlayers()) do
				if ownsNpc(player, child) then
					markDirty(player, "npc added")
				end
			end
		end)
	end
end)

for _, npc in ipairs(getNpcFolder():GetChildren()) do
	if npc:IsA("Model") then
		connectNpcWatch(npc)
	end
end

Players.PlayerAdded:Connect(function(player)
	connectMoneyWatch(player)

	task.delay(RESTORE_AFTER_SECONDS, function()
		if player.Parent then
			restorePlayer(player)
			markDirty(player, "after restore")
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player, "leaving")
end)

task.spawn(function()
	while true do
		for _, npc in ipairs(getNpcFolder():GetChildren()) do
			if npc:IsA("Model") then
				connectNpcWatch(npc)
			end
		end

		for player, reason in pairs(dirtyPlayers) do
			if player and player.Parent then
				savePlayer(player, reason)
			else
				dirtyPlayers[player] = nil
			end
		end

		task.wait(SAVE_EVERY)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player, "server close")
	end

	task.wait(2)
end)

print("[BrainrotPersistentSaveBridge] Loaded. Money + inventory + placed NPC backup save active.")