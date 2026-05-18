--!nonstrict
-- ServerScriptService/ONE_TIME_PLOT_RESET.server.lua
-- TEMP SCRIPT: resets your plot upgrades, floors, placed NPCs, inventory brainrots, tools, and saved NPC/plot data.
-- Run once in Play Solo. When it prints DONE, stop Play Solo and delete this script.

local USERNAME = "berkovichitay"

local CLEAR_INVENTORY_BRAINROTS = true -- true = delete all your brainrots/tools too
local BASE_SLOTS = 4
local CLEANUP_SECONDS = 12

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local function log(...)
	print("[ONE_TIME_PLOT_RESET]", ...)
end

local function warnLog(...)
	warn("[ONE_TIME_PLOT_RESET]", ...)
end

local function norm(s)
	return string.lower(tostring(s)):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function waitForPlayer()
	for _ = 1, 160 do
		local player = Players:FindFirstChild(USERNAME) or Players:GetPlayers()[1]
		if player then
			return player
		end
		task.wait(0.25)
	end

	return nil
end

local function getPlotsFolder()
	return Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
end

local function waitForPlot(player)
	for _ = 1, 160 do
		local plotsFolder = getPlotsFolder()

		if plotsFolder then
			for _, plot in ipairs(plotsFolder:GetChildren()) do
				if tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
					or tostring(plot:GetAttribute("OwnerName")) == player.Name
					or tostring(plot:GetAttribute("Owner")) == player.Name then
					return plot
				end
			end
		end

		task.wait(0.25)
	end

	return nil
end

local function safeSet(storeName, key, value)
	local ok, err = pcall(function()
		local store = DataStoreService:GetDataStore(storeName)
		store:SetAsync(key, value)
	end)

	if ok then
		log("DataStore set:", storeName, key)
	else
		warnLog("DataStore set FAILED:", storeName, key, err)
		warnLog("If this fails, enable: Game Settings > Security > Enable Studio Access to API Services")
	end
end

local function safeRemove(storeName, key)
	local ok, err = pcall(function()
		local store = DataStoreService:GetDataStore(storeName)
		store:RemoveAsync(key)
	end)

	if ok then
		log("DataStore removed:", storeName, key)
	else
		warnLog("DataStore remove FAILED:", storeName, key, err)
	end
end

local function disableResetConflicts()
	local names = {
		"PlotFloorUpgrade.server.lua",
		"BrainrotFloorSlotLock.server.lua",
		"BrainrotDuplicateFloorCleaner.server.lua",
		"BrainrotPlacedFeedback.server.lua",
		"PlacedBrainrotVisualRepair.server.lua",
		"BrainrotPlacedCoreRepair.server.lua",
		"BrainrotStandSnapFix.server.lua",
		"BrainrotToolPlacement.server.lua",
		"DirectBrainrotInventory.server.lua",
		"BrainrotToolInventoryRestore.server,lua",
		"MoneyGuiLoadSync.server.lua",
		"BrainrotCollectMoney.server.lua",
		"MoneyCollectTextScaleFix.server.lua",
		"BrainrotCollectText_FORCE.server.lua",
	}

	for _, name in ipairs(names) do
		local s = ServerScriptService:FindFirstChild(name)
		if s and s:IsA("BaseScript") and s ~= script then
			s.Disabled = true
			log("Disabled during reset:", s.Name)
		end
	end
end

local function resetDataStores(player)
	local userId = tostring(player.UserId)

	-- Plot upgrade slots.
	safeSet("PlayerPlotUnlockedSlots_v1", "player_" .. userId, BASE_SLOTS)
	safeRemove("PlayerPlotUnlockedSlots_v1", userId)

	-- Possible extra plot stores, harmless if unused.
	safeRemove("PlotUnlockedSlots_v1", "player_" .. userId)
	safeRemove("PlotUnlockedSlots_v1", userId)
	safeRemove("PlayerPlotData_v1", "player_" .. userId)
	safeRemove("PlayerPlotData_v1", userId)

	-- NPC database.
	local emptyNpcPayload = HttpService:JSONEncode({
		lastLogoutAt = 0,
		npcs = {},
	})

	safeSet("NPCStore", "NPCs_" .. userId, emptyNpcPayload)

	-- Extra possible NPC stores, harmless if unused.
	safeRemove("BrainrotNPCStore", "NPCs_" .. userId)
	safeRemove("BrainrotNPCs_v1", "NPCs_" .. userId)
	safeRemove("PlayerNPCs_v1", "NPCs_" .. userId)
	safeRemove("PlayerBrainrots_v1", "NPCs_" .. userId)
end

local function isGeneratedFloor(obj)
	local n = norm(obj.Name)

	local index =
		tonumber(obj:GetAttribute("GeneratedFloorIndex"))
		or tonumber(obj:GetAttribute("FloorIndex"))
		or tonumber(obj:GetAttribute("Floor"))
		or tonumber(obj:GetAttribute("Level"))

	if index and index > 1 then
		return true
	end

	return n:find("generatedplotfloor")
		or n:find("generatedladder")
		or n:find("floor2")
		or n:find("floor3")
		or n:find("floor4")
		or n:find("level2")
		or n:find("level3")
		or n:find("secondfloor")
		or n:find("thirdfloor")
end

local function deleteGeneratedFloors(plot)
	local deleted = 0

	for _, child in ipairs(plot:GetChildren()) do
		if isGeneratedFloor(child) then
			deleted += 1
			log("Deleting generated floor/object:", child:GetFullName())
			child:Destroy()
		end
	end

	return deleted
end

local function resetPlotAttributes(plot)
	local attrs = {
		"UnlockedBrainrotSlots",
		"PlotFloorLevel",
		"LastAppliedUnlockedSlots",
		"GeneratedFloorVersion",
		"UnlockedFloors",
		"PurchasedFloors",
		"CurrentFloor",
		"MaxFloor",
		"FloorCount",
		"OwnedFloors",
		"BoughtFloors",
		"UnlockedSlots",
		"PurchasedSlots",
		"SlotCount",
		"BrainrotSlots",
		"MaxBrainrotSlots",
	}

	for _, attr in ipairs(attrs) do
		plot:SetAttribute(attr, nil)
	end

	plot:SetAttribute("BaseSlotsPerFloor", BASE_SLOTS)
	plot:SetAttribute("UnlockedBrainrotSlots", BASE_SLOTS)
	plot:SetAttribute("PlotFloorLevel", 1)
	plot:SetAttribute("LastAppliedUnlockedSlots", BASE_SLOTS)
	plot:SetAttribute("GeneratedFloorVersion", 999)
end

local function resetPlayerAttributes(player)
	local attrs = {
		"UnlockedBrainrotSlots",
		"PlotFloorLevel",
		"LastAppliedUnlockedSlots",
		"GeneratedFloorVersion",
		"UnlockedFloors",
		"PurchasedFloors",
		"CurrentFloor",
		"MaxFloor",
		"FloorCount",
		"OwnedFloors",
		"BoughtFloors",
		"UnlockedSlots",
		"PurchasedSlots",
		"SlotCount",
		"BrainrotSlots",
		"MaxBrainrotSlots",
	}

	for _, attr in ipairs(attrs) do
		player:SetAttribute(attr, nil)
	end

	player:SetAttribute("UnlockedBrainrotSlots", BASE_SLOTS)
	player:SetAttribute("PlotFloorLevel", 1)
end

local function clearPlotRuntime(plot)
	local clearedGui = 0
	local deletedClones = 0

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Model") or obj:IsA("Folder") then
			obj:SetAttribute("BrainrotCoreOccupied", false)
			obj:SetAttribute("BrainrotCoreOccupiedOwnerUserId", nil)
			obj:SetAttribute("BrainrotSlotId", nil)
			obj:SetAttribute("BrainrotSlotFloor", nil)
			obj:SetAttribute("AssignedSlotId", nil)
			obj:SetAttribute("AssignedSlotFloor", nil)
			obj:SetAttribute("AssignedSlotPath", nil)
			obj:SetAttribute("PrivateCollectAmount", nil)
			obj:SetAttribute("LinkedBrainrotUID", nil)
		end

		if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
			if obj.Name:find("Money") or obj.Name:find("Collect") or obj.Name:find("Brainrot") then
				clearedGui += 1
				obj:Destroy()
			end
		end

		if obj:IsA("Model") then
			local looksLikeBrainrotClone =
				obj:GetAttribute("BrainrotUID") ~= nil
				or obj:GetAttribute("UID") ~= nil
				or obj:GetAttribute("BrainrotUid") ~= nil
				or obj:GetAttribute("DirectInventoryUid") ~= nil
				or obj:GetAttribute("InventoryUid") ~= nil
				or obj:GetAttribute("IsPlaced") == true
				or obj:GetAttribute("Placed") == true

			if looksLikeBrainrotClone then
				deletedClones += 1
				obj:Destroy()
			end
		end
	end

	return clearedGui, deletedClones
end

local function ownsNpc(player, npc)
	return tostring(npc:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("PlacedOwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("HeldOwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("CapturedByUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("HeldBy")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("OwnerName")) == player.Name
		or tostring(npc:GetAttribute("Owner")) == player.Name
		or tostring(npc:GetAttribute("CapturedBy")) == player.Name
end

local function looksLikeBrainrotNpc(npc)
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
end

local function deleteOwnedNpcs(player)
	local folder = Workspace:FindFirstChild("BrainrotNPCs")
	if not folder then
		return 0
	end

	local deleted = 0

	for _, npc in ipairs(folder:GetChildren()) do
		if looksLikeBrainrotNpc(npc) and ownsNpc(player, npc) then
			if CLEAR_INVENTORY_BRAINROTS
				or npc:GetAttribute("IsPlaced") == true
				or npc:GetAttribute("Placed") == true then
				deleted += 1
				log("Deleting owned brainrot:", npc.Name)
				npc:Destroy()
			end
		end
	end

	return deleted
end

local function deleteBrainrotTools(player)
	if not CLEAR_INVENTORY_BRAINROTS then
		return 0
	end

	local deleted = 0
	local containers = {}

	if player.Character then
		table.insert(containers, player.Character)
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end

	for _, container in ipairs(containers) do
		for _, obj in ipairs(container:GetChildren()) do
			if obj:IsA("Tool") then
				local isBrainrot =
					obj:GetAttribute("IsBrainrot") == true
					or obj:GetAttribute("BrainrotUID") ~= nil
					or obj:GetAttribute("UID") ~= nil
					or obj:GetAttribute("BrainrotUid") ~= nil
					or norm(obj.Name):find("brainrot") ~= nil

				if isBrainrot then
					deleted += 1
					log("Deleting brainrot tool:", obj.Name)
					obj:Destroy()
				end
			end
		end
	end

	return deleted
end

task.spawn(function()
	log("START")

	local player = waitForPlayer()
	if not player then
		warnLog("No player found. Press Play Solo.")
		return
	end

	log("Player:", player.Name, player.UserId)

	local plot = waitForPlot(player)
	if not plot then
		warnLog("Plot not found. PlotService did not assign a plot.")
		return
	end

	log("Plot:", plot:GetFullName())

	disableResetConflicts()
	resetDataStores(player)

	local totalFloors = 0
	local totalNpcs = 0
	local totalTools = 0
	local totalGuis = 0
	local totalClones = 0

	local endTime = os.clock() + CLEANUP_SECONDS

	while os.clock() < endTime do
		totalFloors += deleteGeneratedFloors(plot)
		totalNpcs += deleteOwnedNpcs(player)
		totalTools += deleteBrainrotTools(player)

		local guis, clones = clearPlotRuntime(plot)
		totalGuis += guis
		totalClones += clones

		resetPlotAttributes(plot)
		resetPlayerAttributes(player)

		task.wait(0.35)
	end

	log("DONE")
	log("Deleted generated floors:", totalFloors)
	log("Deleted owned NPCs:", totalNpcs)
	log("Deleted brainrot tools:", totalTools)
	log("Deleted plot clones:", totalClones)
	log("Deleted old money GUIs:", totalGuis)
	log("Reset plot slots to:", BASE_SLOTS)
	log("NOW: stop Play Solo, delete ONE_TIME_PLOT_RESET.server.lua, then start Play Solo again.")
end)