--!nonstrict
-- ServerScriptService/BrainrotDatabaseSaveBridge.server.lua
-- Saves NPC inventory + placed NPCs to NPCStore.
-- No Earned spam.
-- Supports new NPCSlot_XX system.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local npcFolder = Workspace:WaitForChild("BrainrotNPCs")

local database = nil
local savePlacedNPCSnapshot = nil
local saveNPC = nil

local queuedPlayers = {}
local savingPlayers = {}
local watchedNpcs = {}

local QUICK_SAVE_DELAY = 3
local PERIODIC_SAVE_TIME = 45

local IMPORTANT_ATTRS = {
	InventoryOnly = true,
	IsPlaced = true,
	Placed = true,

	OwnerUserId = true,
	PlacedOwnerUserId = true,
	HeldOwnerUserId = true,
	Owner = true,

	AssignedSlotId = true,
	AssignedSlotPath = true,
	AssignedHouseGoal = true,

	DirectInventoryUid = true,
	InventoryUid = true,
	BrainrotUid = true,

	MPS = true,
	CashPerSecond = true,
	Rarity = true,
	DisplayName = true,
	TemplateName = true,

	ToolIcon = true,
	Icon = true,
	Image = true,
	TextureId = true,
}

local function loadDatabase()
	if savePlacedNPCSnapshot and saveNPC then
		return true
	end

	local ok, result = pcall(function()
		local TS = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
		local DatabaseService = TS.import(
			script,
			ServerScriptService,
			"Server",
			"services",
			"database.service"
		).default

		database = DatabaseService()
		savePlacedNPCSnapshot = database.savePlacedNPCSnapshot
		saveNPC = database.saveNPC
	end)

	if not ok then
		warn("[BrainrotDatabaseSaveBridge] Failed loading database.service:", result)
		return false
	end

	return typeof(savePlacedNPCSnapshot) == "function" and typeof(saveNPC) == "function"
end

local function findOwnerPlayer(npc)
	local ownerUserId =
		npc:GetAttribute("OwnerUserId")
		or npc:GetAttribute("PlacedOwnerUserId")
		or npc:GetAttribute("HeldOwnerUserId")

	if ownerUserId ~= nil then
		for _, player in ipairs(Players:GetPlayers()) do
			if tostring(player.UserId) == tostring(ownerUserId) then
				return player
			end
		end
	end

	local ownerName = npc:GetAttribute("Owner")

	if ownerName ~= nil then
		for _, player in ipairs(Players:GetPlayers()) do
			if tostring(player.Name) == tostring(ownerName) then
				return player
			end
		end
	end

	return nil
end

local function shouldPersistNpc(npc)
	if not npc or not npc:IsA("Model") then
		return false
	end

	return npc:GetAttribute("InventoryOnly") == true
		or npc:GetAttribute("IsPlaced") == true
		or npc:GetAttribute("Placed") == true
end

local function savePlayerNow(player, reason)
	if not player or not player.Parent then
		return
	end

	if savingPlayers[player] then
		return
	end

	if not loadDatabase() then
		return
	end

	savingPlayers[player] = true

	local ok, err = pcall(function()
		savePlacedNPCSnapshot(player, npcFolder)
	end)

	savingPlayers[player] = nil

	if ok then
		print("[BrainrotDatabaseSaveBridge] Snapshot saved:", player.Name, "Reason:", reason or "unknown")
	else
		warn("[BrainrotDatabaseSaveBridge] Snapshot save failed:", player.Name, err)
	end
end

local function queueSavePlayer(player, reason, delayTime)
	if not player or not player.Parent then
		return
	end

	if queuedPlayers[player] then
		queuedPlayers[player].reason = reason or queuedPlayers[player].reason
		return
	end

	queuedPlayers[player] = {
		reason = reason or "queued",
	}

	task.delay(delayTime or QUICK_SAVE_DELAY, function()
		local data = queuedPlayers[player]
		queuedPlayers[player] = nil

		if player and player.Parent then
			savePlayerNow(player, data and data.reason or reason)
		end
	end)
end

local function watchNpc(npc)
	if not npc:IsA("Model") then
		return
	end

	if watchedNpcs[npc] then
		return
	end

	watchedNpcs[npc] = true

	for attrName in pairs(IMPORTANT_ATTRS) do
		npc:GetAttributeChangedSignal(attrName):Connect(function()
			if not shouldPersistNpc(npc) then
				return
			end

			local player = findOwnerPlayer(npc)
			if player then
				queueSavePlayer(player, attrName, QUICK_SAVE_DELAY)
			end
		end)
	end

	npc.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			watchedNpcs[npc] = nil
		end
	end)

	task.delay(2, function()
		if shouldPersistNpc(npc) then
			local player = findOwnerPlayer(npc)
			if player then
				queueSavePlayer(player, "initial npc watch", QUICK_SAVE_DELAY)
			end
		end
	end)
end

for _, npc in ipairs(npcFolder:GetChildren()) do
	if npc:IsA("Model") then
		task.spawn(watchNpc, npc)
	end
end

npcFolder.ChildAdded:Connect(function(npc)
	if npc:IsA("Model") then
		task.spawn(watchNpc, npc)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	queuedPlayers[player] = nil
	savePlayerNow(player, "player leaving")
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerNow(player, "server closing")
	end

	task.wait(1)
end)

task.spawn(function()
	while true do
		task.wait(PERIODIC_SAVE_TIME)

		for _, player in ipairs(Players:GetPlayers()) do
			queueSavePlayer(player, "periodic backup", 1)
		end
	end
end)

print("[BrainrotDatabaseSaveBridge] loaded NEW - saves inventory + placed NPCSlot NPCs")