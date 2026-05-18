--!nonstrict
-- QuestService.server.lua
-- Put in: ServerScriptService
-- Real Hide & Seek quest progression.
-- Counts owned/caught brainrots and gives rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local npcFolder = workspace:WaitForChild("BrainrotNPCs")

local function getOrCreateRemote(name)
	local remote = ReplicatedStorage:FindFirstChild(name)

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end

	return remote
end

local updateQuestRemote = getOrCreateRemote("UpdateQuestProgress")
local claimQuestRemote = getOrCreateRemote("ClaimQuestReward")

local updateCoinsRemote = ReplicatedStorage:FindFirstChild("UpdateCoins")
local updateGemsRemote = ReplicatedStorage:FindFirstChild("UpdateGems")

local QUESTS = {
	{
		Goal = 3,
		RewardType = "Coins",
		RewardAmount = 500,
	},
	{
		Goal = 5,
		RewardType = "Coins",
		RewardAmount = 1500,
	},
	{
		Goal = 10,
		RewardType = "Gems",
		RewardAmount = 250,
	},
	{
		Goal = 15,
		RewardType = "Gems",
		RewardAmount = 1000,
	},
	{
		Goal = 25,
		RewardType = "Coins",
		RewardAmount = 10000,
	},
	{
		Goal = 40,
		RewardType = "Gems",
		RewardAmount = 2500,
	},
}

local function getQuestForLevel(level)
	return QUESTS[level] or QUESTS[#QUESTS]
end

local function getOrCreateLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	return leaderstats
end

local function getOrCreateNumberValue(parent, name)
	local value = parent:FindFirstChild(name)

	if not value then
		value = Instance.new("NumberValue")
		value.Name = name
		value.Value = 0
		value.Parent = parent
	end

	return value
end

local function getPlayerCurrency(player, currencyName)
	local leaderstats = getOrCreateLeaderstats(player)
	local value = getOrCreateNumberValue(leaderstats, currencyName)
	return value
end

local function fireCurrencyUpdate(player, currencyName, amount)
	if currencyName == "Coins" then
		if updateCoinsRemote and updateCoinsRemote:IsA("RemoteEvent") then
			updateCoinsRemote:FireClient(player, amount)
		end
	elseif currencyName == "Gems" then
		if updateGemsRemote and updateGemsRemote:IsA("RemoteEvent") then
			updateGemsRemote:FireClient(player, amount)
		end
	end
end

local function addCurrency(player, currencyName, amount)
	local value = getPlayerCurrency(player, currencyName)
	value.Value += amount

	player:SetAttribute(currencyName, value.Value)

	fireCurrencyUpdate(player, currencyName, value.Value)

	return value.Value
end

local function isOwnedByPlayer(npc, player)
	if not npc:IsA("Model") then
		return false
	end

	local owner =
		npc:GetAttribute("PlacedOwnerUserId")
		or npc:GetAttribute("OwnerUserId")
		or npc:GetAttribute("ownerUserId")
		or npc:GetAttribute("CaughtOwnerUserId")
		or npc:GetAttribute("ClaimedOwnerUserId")

	if owner == player.UserId then
		return true
	end

	if tostring(owner) == tostring(player.UserId) then
		return true
	end

	return false
end

local function countOwnedBrainrots(player)
	local counted = {}
	local total = 0

	for _, obj in ipairs(npcFolder:GetDescendants()) do
		if obj:IsA("Model") and not counted[obj] then
			if isOwnedByPlayer(obj, player) then
				counted[obj] = true
				total += 1
			end
		end
	end

	return total
end

local function getQuestLevel(player)
	local level = player:GetAttribute("BrainrotQuestLevel")

	if typeof(level) ~= "number" or level < 1 then
		level = 1
		player:SetAttribute("BrainrotQuestLevel", level)
	end

	return level
end

local function setQuestLevel(player, level)
	player:SetAttribute("BrainrotQuestLevel", level)
end

local function sendQuestUpdate(player)
	local level = getQuestLevel(player)
	local quest = getQuestForLevel(level)

	local owned = countOwnedBrainrots(player)
	local progress = math.clamp(owned, 0, quest.Goal)
	local complete = progress >= quest.Goal

	updateQuestRemote:FireClient(player, {
		level = level,
		goal = quest.Goal,
		progress = progress,
		owned = owned,
		complete = complete,
		rewardType = quest.RewardType,
		rewardAmount = quest.RewardAmount,
	})
end

local function sendAllQuestUpdates()
	for _, player in ipairs(Players:GetPlayers()) do
		sendQuestUpdate(player)
	end
end

claimQuestRemote.OnServerEvent:Connect(function(player)
	local level = getQuestLevel(player)
	local quest = getQuestForLevel(level)

	local owned = countOwnedBrainrots(player)
	local progress = math.clamp(owned, 0, quest.Goal)

	if progress < quest.Goal then
		sendQuestUpdate(player)
		return
	end

	addCurrency(player, quest.RewardType, quest.RewardAmount)

	setQuestLevel(player, level + 1)

	task.wait(0.1)
	sendQuestUpdate(player)
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		getQuestLevel(player)

		local leaderstats = getOrCreateLeaderstats(player)

		local coins = leaderstats:FindFirstChild("Coins")
		if coins and coins:IsA("NumberValue") then
			player:SetAttribute("Coins", coins.Value)
			fireCurrencyUpdate(player, "Coins", coins.Value)
		end

		local gems = leaderstats:FindFirstChild("Gems")
		if gems and gems:IsA("NumberValue") then
			player:SetAttribute("Gems", gems.Value)
			fireCurrencyUpdate(player, "Gems", gems.Value)
		end

		sendQuestUpdate(player)
	end)
end)

npcFolder.DescendantAdded:Connect(function()
	task.delay(0.2, sendAllQuestUpdates)
end)

npcFolder.DescendantRemoving:Connect(function()
	task.delay(0.2, sendAllQuestUpdates)
end)

for _, npc in ipairs(npcFolder:GetDescendants()) do
	if npc:IsA("Model") then
		npc.AttributeChanged:Connect(function(attributeName)
			if attributeName == "OwnerUserId"
				or attributeName == "ownerUserId"
				or attributeName == "PlacedOwnerUserId"
				or attributeName == "CaughtOwnerUserId"
				or attributeName == "ClaimedOwnerUserId"
			then
				task.delay(0.1, sendAllQuestUpdates)
			end
		end)
	end
end

npcFolder.DescendantAdded:Connect(function(obj)
	if obj:IsA("Model") then
		obj.AttributeChanged:Connect(function(attributeName)
			if attributeName == "OwnerUserId"
				or attributeName == "ownerUserId"
				or attributeName == "PlacedOwnerUserId"
				or attributeName == "CaughtOwnerUserId"
				or attributeName == "ClaimedOwnerUserId"
			then
				task.delay(0.1, sendAllQuestUpdates)
			end
		end)
	end
end)

task.spawn(function()
	while true do
		sendAllQuestUpdates()
		task.wait(1)
	end
end)

print("[QuestService] loaded")