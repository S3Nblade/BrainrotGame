--!nonstrict
-- InventorySell.server.lua
-- Put in: ServerScriptService
-- Robust instant inventory selling. Calls brainrots.service.sellPlacedNPC directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local REMOTE_NAME = "SellBrainrotFromInventory"

local TS = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))

local sellRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not sellRemote then
	sellRemote = Instance.new("RemoteEvent")
	sellRemote.Name = REMOTE_NAME
	sellRemote.Parent = ReplicatedStorage
end

local notifyRemote = ReplicatedStorage:FindFirstChild("NotifyUser")
if not notifyRemote then
	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = "NotifyUser"
	notifyRemote.Parent = ReplicatedStorage
end

local SELL_COOLDOWN = 0.35
local sellCooldowns = {}

local brainrotsService = nil

local function notify(player, message, variant)
	notifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function getBrainrotsService()
	if brainrotsService then
		return brainrotsService
	end

	local ok, result = pcall(function()
		return TS.import(script, ServerScriptService, "Server", "services", "brainrots.service")
	end)

	if not ok then
		warn("[InventorySell] Failed importing brainrots.service:", result)
		return nil
	end

	brainrotsService = result
	return brainrotsService
end

local function getNpcFolder()
	return Workspace:FindFirstChild("BrainrotNPCs")
end

local function getPlotsFolder()
	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	if not spawnMap then
		return nil
	end

	return spawnMap:FindFirstChild("Plots")
end

local function getPlayerPlot(player)
	local plotsFolder = getPlotsFolder()
	if not plotsFolder then
		return nil
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end

		if tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId) then
			return plot
		end

		if tostring(plot:GetAttribute("Owner")) == player.Name then
			return plot
		end
	end

	return nil
end

local function getGoalName(npc)
	return tostring(
		npc:GetAttribute("AssignedHouseGoal")
			or npc:GetAttribute("assignedHouseGoal")
			or ""
	)
end

local function getDisplayName(npc)
	return tostring(
		npc:GetAttribute("TemplateName")
			or npc:GetAttribute("templateName")
			or npc.Name
	)
end

local function getNpcRoot(npc)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function getGoalPartInPlayerPlot(player, goalName)
	local plot = getPlayerPlot(player)
	if not plot then
		return nil
	end

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == goalName then
			return obj
		end
	end

	return nil
end

local function npcOwnedByPlayer(player, npc)
	local placedOwner =
		npc:GetAttribute("PlacedOwnerUserId")
		or npc:GetAttribute("OwnerUserId")
		or npc:GetAttribute("ownerUserId")
		or npc:GetAttribute("PlotOwnerUserId")
		or npc:GetAttribute("PlayerUserId")
		or npc:GetAttribute("UserId")
		or npc:GetAttribute("OwnerId")

	if placedOwner == player.UserId then
		return true
	end

	if tostring(placedOwner) == tostring(player.UserId) then
		return true
	end

	local ownerName =
		npc:GetAttribute("Owner")
		or npc:GetAttribute("PlayerName")

	if tostring(ownerName) == player.Name then
		return true
	end

	-- Fallback: NPC is assigned to a HouseGoal that exists in this player's plot
	-- and the NPC is physically near that goal.
	local goalName = getGoalName(npc)
	if goalName ~= "" then
		local goalPart = getGoalPartInPlayerPlot(player, goalName)
		local root = getNpcRoot(npc)

		if goalPart and root then
			local dist = (goalPart.Position - root.Position).Magnitude
			if dist <= 45 then
				return true
			end
		end
	end

	return false
end

local function npcIsPlaced(npc)
	if npc:GetAttribute("IsPlaced") == true then
		return true
	end

	if getGoalName(npc) ~= "" then
		return true
	end

	return false
end

local function findOwnedNpc(player, goalName, npcName, displayName)
	local npcFolder = getNpcFolder()
	if not npcFolder then
		return nil
	end

	for _, npc in ipairs(npcFolder:GetDescendants()) do
		if npc:IsA("Model") then
			local npcGoal = getGoalName(npc)
			local npcDisplayName = getDisplayName(npc)

			local nameMatches =
				npc.Name == tostring(npcName)
				or npcDisplayName == tostring(displayName)
				or npcDisplayName == tostring(npcName)

			if nameMatches
				and npcGoal == tostring(goalName)
				and npcIsPlaced(npc)
				and npcOwnedByPlayer(player, npc)
			then
				return npc
			end
		end
	end

	return nil
end

local function sellNpc(player, goalName, npcName, displayName)
	local now = tick()
	local last = sellCooldowns[player.UserId] or 0

	if now - last < SELL_COOLDOWN then
		return
	end

	sellCooldowns[player.UserId] = now

	if type(goalName) ~= "string" or type(npcName) ~= "string" then
		return
	end

	local service = getBrainrotsService()
	if not service then
		notify(player, "Sell service failed to load!", "error")
		return
	end

	if type(service.sellPlacedNPC) ~= "function" then
		notify(player, "sellPlacedNPC is not exported from brainrots.service!", "error")
		warn("[InventorySell] Missing export. Add sellPlacedNPC to brainrots.service return table.")
		return
	end

	local npc = findOwnedNpc(player, goalName, npcName, displayName)

	if not npc then
		notify(player, "Brainrot not found or not yours!", "warning")
		warn("[InventorySell] Could not find NPC:", player.Name, goalName, npcName, displayName)
		return
	end

	local ok, err = pcall(function()
		service.sellPlacedNPC(player, npc)
	end)

	if not ok then
		warn("[InventorySell] sellPlacedNPC failed:", err)
		notify(player, "Sell failed. Check output.", "error")
	end
end

sellRemote.OnServerEvent:Connect(function(player, goalName, npcName, displayName)
	sellNpc(player, goalName, npcName, displayName)
end)

Players.PlayerRemoving:Connect(function(player)
	sellCooldowns[player.UserId] = nil
end)

print("[InventorySell] robust instant sell loaded")