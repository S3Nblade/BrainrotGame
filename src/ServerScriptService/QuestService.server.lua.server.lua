--!nonstrict
-- QuestService.server.lua
-- Put in: ServerScriptService
-- Real Hide & Seek quest progression.
-- Counts owned/caught brainrots and gives rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local npcFolder = workspace:WaitForChild("BrainrotNPCs")
local milestoneStore = DataStoreService:GetDataStore("BrainrotCollectionMilestones_v1")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name)
	local remote = ReplicatedStorage:FindFirstChild(name)

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end

	return remote
end

local function getOrCreateRemotesFolderRemote(name)
	local remote = remotesFolder:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name)

	if remote then
		if remote:IsA("RemoteEvent") then
			remote.Parent = remotesFolder
			return remote
		end

		remote:Destroy()
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local updateQuestRemote = getOrCreateRemote("UpdateQuestProgress")
local claimQuestRemote = getOrCreateRemote("ClaimQuestReward")
local notifyRemote = getOrCreateRemote("NotifyUser")
local collectionMilestoneRemote = getOrCreateRemotesFolderRemote("CollectionMilestoneReward")

local updateCoinsRemote = ReplicatedStorage:FindFirstChild("UpdateCoins")
local updateGemsRemote = ReplicatedStorage:FindFirstChild("UpdateGems")

local DEFAULT_COLLECTION_MILESTONES = {
	{
		Id = "first_brainrot",
		Goal = 1,
		Title = "First Brainrot!",
		RewardType = "Coins",
		RewardAmount = 250,
	},
	{
		Id = "small_squad",
		Goal = 3,
		Title = "Small Squad",
		RewardType = "Coins",
		RewardAmount = 750,
	},
	{
		Id = "base_builder",
		Goal = 5,
		Title = "Base Builder",
		RewardType = "Coins",
		RewardAmount = 2000,
	},
	{
		Id = "collector",
		Goal = 10,
		Title = "Collector",
		RewardType = "Gems",
		RewardAmount = 150,
	},
	{
		Id = "brainrot_tycoon",
		Goal = 20,
		Title = "Brainrot Tycoon",
		RewardType = "Gems",
		RewardAmount = 500,
	},
	{
		Id = "simulator_star",
		Goal = 35,
		Title = "Simulator Star",
		RewardType = "Coins",
		RewardAmount = 25000,
	},
	{
		Id = "collection_legend",
		Goal = 50,
		Title = "Collection Legend",
		RewardType = "Gems",
		RewardAmount = 1500,
	},
}

local claimedMilestones = {}

local DEFAULT_QUESTS = {
	{
		Title = "Build Your Squad",
		Action = "Collect 3 Brainrots",
		Goal = 3,
		RewardType = "Coins",
		RewardAmount = 500,
	},
	{
		Title = "Grow The Base",
		Action = "Collect 5 Brainrots",
		Goal = 5,
		RewardType = "Coins",
		RewardAmount = 1500,
	},
	{
		Title = "Rare Hunter",
		Action = "Collect 10 Brainrots",
		Goal = 10,
		RewardType = "Gems",
		RewardAmount = 250,
	},
	{
		Title = "Brainrot Boss",
		Action = "Collect 15 Brainrots",
		Goal = 15,
		RewardType = "Gems",
		RewardAmount = 1000,
	},
	{
		Title = "Money Machine",
		Action = "Collect 25 Brainrots",
		Goal = 25,
		RewardType = "Coins",
		RewardAmount = 10000,
	},
	{
		Title = "Simulator Legend",
		Action = "Collect 40 Brainrots",
		Goal = 40,
		RewardType = "Gems",
		RewardAmount = 2500,
	},
}

local function loadQuestConfig()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("QuestConfig")

	if module and module:IsA("ModuleScript") then
		local ok, config = pcall(require, module)
		if ok and type(config) == "table" then
			return {
				CollectionMilestones = type(config.CollectionMilestones) == "table"
					and config.CollectionMilestones
					or DEFAULT_COLLECTION_MILESTONES,
				Quests = type(config.Quests) == "table" and config.Quests or DEFAULT_QUESTS,
			}
		end

		warn("[QuestService] Failed to load QuestConfig, using defaults.")
	end

	return {
		CollectionMilestones = DEFAULT_COLLECTION_MILESTONES,
		Quests = DEFAULT_QUESTS,
	}
end

local function loadBalanceConfig()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("BalanceConfig")

	if module and module:IsA("ModuleScript") then
		local ok, config = pcall(require, module)
		if ok and type(config) == "table" then
			return config
		end
	end

	return nil
end

local QUEST_CONFIG = loadQuestConfig()
local COLLECTION_MILESTONES = QUEST_CONFIG.CollectionMilestones
local QUESTS = QUEST_CONFIG.Quests
local BALANCE_CONFIG = loadBalanceConfig()
local QUEST_UPDATE_INTERVAL = tonumber(BALANCE_CONFIG and BALANCE_CONFIG.Quests and BALANCE_CONFIG.Quests.UpdateInterval) or 2.5

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

local function getMilestoneKey(player)
	return "milestones_" .. tostring(player.UserId)
end

local function loadMilestones(player)
	local claimed = {}

	local ok, result = pcall(function()
		return milestoneStore:GetAsync(getMilestoneKey(player))
	end)

	if ok and type(result) == "table" then
		for key, value in pairs(result) do
			if value == true then
				claimed[tostring(key)] = true
			end
		end
	end

	claimedMilestones[player.UserId] = claimed
	return claimed
end

local function saveMilestones(player)
	local claimed = claimedMilestones[player.UserId]
	if not claimed then
		return
	end

	pcall(function()
		milestoneStore:SetAsync(getMilestoneKey(player), claimed)
	end)
end

local function getClaimedMilestones(player)
	return claimedMilestones[player.UserId] or loadMilestones(player)
end

local function awardCollectionMilestones(player, owned)
	local claimed = getClaimedMilestones(player)
	local changed = false

	for _, milestone in ipairs(COLLECTION_MILESTONES) do
		if owned >= milestone.Goal and claimed[milestone.Id] ~= true then
			claimed[milestone.Id] = true
			changed = true

			addCurrency(player, milestone.RewardType, milestone.RewardAmount)
			collectionMilestoneRemote:FireClient(player, {
				title = milestone.Title,
				goal = milestone.Goal,
				owned = owned,
				rewardType = milestone.RewardType,
				rewardAmount = milestone.RewardAmount,
			})
			notifyRemote:FireClient(player, {
				message = milestone.Title .. " milestone! +" .. tostring(milestone.RewardAmount) .. " " .. tostring(milestone.RewardType),
				variant = "success",
			})
		end
	end

	if changed then
		saveMilestones(player)
	end
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
	awardCollectionMilestones(player, owned)
	local progress = math.clamp(owned, 0, quest.Goal)
	local complete = progress >= quest.Goal

	updateQuestRemote:FireClient(player, {
		level = level,
		title = quest.Title,
		action = quest.Action,
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
	notifyRemote:FireClient(player, {
		message = "Quest complete! +" .. tostring(quest.RewardAmount) .. " " .. tostring(quest.RewardType),
		variant = "success",
	})

	setQuestLevel(player, level + 1)

	task.wait(0.1)
	sendQuestUpdate(player)
end)

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		loadMilestones(player)
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

Players.PlayerRemoving:Connect(function(player)
	saveMilestones(player)
	claimedMilestones[player.UserId] = nil
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
		task.wait(QUEST_UPDATE_INTERVAL)
	end
end)

print("[QuestService] loaded with config-driven quest definitions")
