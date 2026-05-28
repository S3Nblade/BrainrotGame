--!nonstrict
-- QuestService.server.lua
-- Put in: ServerScriptService
-- Real Hide & Seek quest progression.
-- Counts owned/caught brainrots and gives rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

local npcFolder = workspace:WaitForChild("BrainrotNPCs")
local milestoneStore = DataStoreService:GetDataStore("BrainrotCollectionMilestones_v1")
local questProgressStore = DataStoreService:GetDataStore("BrainrotQuestProgress_v1")
local dailyQuestStore = DataStoreService:GetDataStore("BrainrotDailyQuestProgress_v1")

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

local gameplayEvent = ServerStorage:FindFirstChild("BrainrotGameplayEvent")
if gameplayEvent and not gameplayEvent:IsA("BindableEvent") then
	gameplayEvent:Destroy()
	gameplayEvent = nil
end
if not gameplayEvent then
	gameplayEvent = Instance.new("BindableEvent")
	gameplayEvent.Name = "BrainrotGameplayEvent"
	gameplayEvent.Parent = ServerStorage
end

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

local DEFAULT_DAILY_QUESTS = {
	{ Id = "capture_10", Title = "Daily Hunt", Action = "Capture 10 Brainrots", Event = "CaptureCompleted", Goal = 10, RewardType = "Coins", RewardAmount = 2500 },
	{ Id = "collect_money_5", Title = "Cash Grab", Action = "Collect plot money 5 times", Event = "MoneyCollected", Goal = 5, RewardType = "Coins", RewardAmount = 3500 },
	{ Id = "place_3", Title = "Base Builder", Action = "Place 3 Brainrots", Event = "BrainrotPlaced", Goal = 3, RewardType = "Gems", RewardAmount = 100 },
	{ Id = "rare_capture", Title = "Rare Moment", Action = "Capture 1 Rare+ Brainrot", Event = "CaptureCompleted", Goal = 1, MinRarity = "Rare", RewardType = "Gems", RewardAmount = 150 },
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
				DailyQuests = type(config.DailyQuests) == "table" and config.DailyQuests or DEFAULT_DAILY_QUESTS,
			}
		end

		warn("[QuestService] Failed to load QuestConfig, using defaults.")
	end

	return {
		CollectionMilestones = DEFAULT_COLLECTION_MILESTONES,
		Quests = DEFAULT_QUESTS,
		DailyQuests = DEFAULT_DAILY_QUESTS,
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
local DAILY_QUESTS = QUEST_CONFIG.DailyQuests
local BALANCE_CONFIG = loadBalanceConfig()
local QUEST_UPDATE_INTERVAL = tonumber(BALANCE_CONFIG and BALANCE_CONFIG.Quests and BALANCE_CONFIG.Quests.UpdateInterval) or 2.5
local CLAIM_COOLDOWN = 0.75
local claimCooldowns = {}
local dailyQuestStateByUserId = {}

local DEFAULT_DEBUG_CONFIG = {
	DebugEnabled = false,
	LogGameplayEvents = false,
	LogDataEvents = false,
	LogQuestEvents = false,
	WarnOnInvalidRemotes = true,
	RateLimitWarnings = true,
}

local function loadDebugConfig()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("DebugConfig")

	if module and module:IsA("ModuleScript") then
		local ok, config = pcall(require, module)
		if ok and type(config) == "table" then
			local merged = table.clone(DEFAULT_DEBUG_CONFIG)
			for key, value in pairs(config) do
				merged[key] = value
			end
			return merged
		end
	end

	return DEFAULT_DEBUG_CONFIG
end

local DEBUG_CONFIG = loadDebugConfig()

local function logDebug(category, eventName, player, payload)
	if not DEBUG_CONFIG.DebugEnabled then
		return
	end

	if category == "gameplay" and not DEBUG_CONFIG.LogGameplayEvents then
		return
	elseif category == "data" and not DEBUG_CONFIG.LogDataEvents then
		return
	elseif category == "quest" and not DEBUG_CONFIG.LogQuestEvents then
		return
	end

	local user = if typeof(player) == "Instance" and player:IsA("Player") then (player.Name .. ":" .. tostring(player.UserId)) else "server"
	print("[BrainrotAnalytics]", category, eventName, user, payload or {})
end

local RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
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

local function getMilestoneKey(player)
	return "milestones_" .. tostring(player.UserId)
end

local function getQuestProgressKey(player)
	return "quest_progress_" .. tostring(player.UserId)
end

local function getDailyQuestKey(player)
	return "daily_quests_" .. tostring(player.UserId)
end

local function getDayKey(timestamp)
	local t = os.date("!*t", timestamp or os.time())
	return string.format("%04d-%03d", t.year, t.yday)
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

local function sanitizeQuestLevel(level)
	level = math.floor(tonumber(level) or 1)

	if level < 1 then
		level = 1
	end

	return level
end

local function loadQuestProgress(player)
	local level = 1

	local ok, result = pcall(function()
		return questProgressStore:GetAsync(getQuestProgressKey(player))
	end)

	if ok and type(result) == "table" then
		level = sanitizeQuestLevel(result.level or result.Level)
	elseif ok and type(result) == "number" then
		level = sanitizeQuestLevel(result)
	elseif not ok then
		warn("[QuestService] Failed to load quest progress for", player.Name, result)
	end

	player:SetAttribute("BrainrotQuestLevel", level)
	player:SetAttribute("BrainrotQuestSchemaVersion", 1)
	logDebug("data", "DataLoaded", player, {
		store = "QuestProgress",
		level = level,
	})
	return level
end

local function saveQuestProgress(player)
	local level = sanitizeQuestLevel(player:GetAttribute("BrainrotQuestLevel"))

	local ok, err = pcall(function()
		questProgressStore:SetAsync(getQuestProgressKey(player), {
			schemaVersion = 1,
			level = level,
			savedAt = os.time(),
		})
	end)

	if not ok then
		warn("[QuestService] Failed to save quest progress for", player.Name, err)
	else
		logDebug("data", "DataSaved", player, {
			store = "QuestProgress",
			level = level,
		})
	end
end

local function normalizeDailyQuestState(raw)
	local today = getDayKey()
	local state = {
		dayKey = today,
		progress = {},
		claimed = {},
	}

	if type(raw) == "table" and raw.dayKey == today then
		if type(raw.progress) == "table" then
			for key, value in pairs(raw.progress) do
				state.progress[tostring(key)] = math.max(0, math.floor(tonumber(value) or 0))
			end
		end

		if type(raw.claimed) == "table" then
			for key, value in pairs(raw.claimed) do
				if value == true then
					state.claimed[tostring(key)] = true
				end
			end
		end
	end

	for _, quest in ipairs(DAILY_QUESTS) do
		local id = tostring(quest.Id or quest.Title or "")
		if id ~= "" and state.progress[id] == nil then
			state.progress[id] = 0
		end
	end

	return state
end

local function loadDailyQuestState(player)
	local ok, result = pcall(function()
		return dailyQuestStore:GetAsync(getDailyQuestKey(player))
	end)

	if not ok then
		warn("[QuestService] Failed to load daily quest state for", player.Name, result)
	end

	local state = normalizeDailyQuestState(ok and result or nil)
	dailyQuestStateByUserId[player.UserId] = state
	player:SetAttribute("BrainrotDailyQuestDay", state.dayKey)
	logDebug("data", "DataLoaded", player, {
		store = "DailyQuests",
		dayKey = state.dayKey,
	})

	return state
end

local function getDailyQuestState(player)
	local state = dailyQuestStateByUserId[player.UserId]
	if not state or state.dayKey ~= getDayKey() then
		state = normalizeDailyQuestState(nil)
		dailyQuestStateByUserId[player.UserId] = state
		player:SetAttribute("BrainrotDailyQuestDay", state.dayKey)
	end

	return state
end

local function saveDailyQuestState(player)
	local state = dailyQuestStateByUserId[player.UserId]
	if not state then
		return
	end

	local ok, err = pcall(function()
		dailyQuestStore:SetAsync(getDailyQuestKey(player), {
			schemaVersion = 1,
			dayKey = state.dayKey,
			progress = state.progress,
			claimed = state.claimed,
			savedAt = os.time(),
		})
	end)

	if not ok then
		warn("[QuestService] Failed to save daily quest state for", player.Name, err)
	else
		logDebug("data", "DataSaved", player, {
			store = "DailyQuests",
			dayKey = state.dayKey,
		})
	end
end

local function rarityMeetsMinimum(rarity, minimum)
	if not minimum then
		return true
	end

	return (RARITY_ORDER[tostring(rarity or "Common")] or 1) >= (RARITY_ORDER[tostring(minimum)] or 1)
end

local function dailyQuestMatchesEvent(quest, eventName, payload)
	if tostring(quest.Event or "") ~= tostring(eventName or "") then
		return false
	end

	if quest.MinRarity and not rarityMeetsMinimum(payload and payload.rarity, quest.MinRarity) then
		return false
	end

	return true
end

local function buildDailyQuestPayload(player)
	local state = getDailyQuestState(player)
	local payload = {}

	for _, quest in ipairs(DAILY_QUESTS) do
		local id = tostring(quest.Id or quest.Title or "")
		local goal = math.max(1, math.floor(tonumber(quest.Goal) or 1))
		local progress = math.clamp(tonumber(state.progress[id]) or 0, 0, goal)

		table.insert(payload, {
			id = id,
			title = tostring(quest.Title or "Daily Quest"),
			action = tostring(quest.Action or ""),
			goal = goal,
			progress = progress,
			complete = progress >= goal,
			claimed = state.claimed[id] == true,
			rewardType = tostring(quest.RewardType or "Coins"),
			rewardAmount = math.floor(tonumber(quest.RewardAmount) or 0),
		})
	end

	return payload
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
	player:SetAttribute("BrainrotQuestLevel", sanitizeQuestLevel(level))
	saveQuestProgress(player)
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
		dailyQuests = buildDailyQuestPayload(player),
	})
end

local function sendAllQuestUpdates()
	for _, player in ipairs(Players:GetPlayers()) do
		sendQuestUpdate(player)
	end
end

claimQuestRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if claimCooldowns[player.UserId] and now - claimCooldowns[player.UserId] < CLAIM_COOLDOWN then
		return
	end
	claimCooldowns[player.UserId] = now

	local level = getQuestLevel(player)
	local quest = getQuestForLevel(level)

	local owned = countOwnedBrainrots(player)
	local progress = math.clamp(owned, 0, quest.Goal)

	if progress < quest.Goal then
		sendQuestUpdate(player)
		return
	end

	addCurrency(player, quest.RewardType, quest.RewardAmount)
	logDebug("quest", "QuestCompleted", player, {
		level = level,
		title = quest.Title,
		rewardType = quest.RewardType,
		rewardAmount = quest.RewardAmount,
	})
	notifyRemote:FireClient(player, {
		message = "Quest complete! +" .. tostring(quest.RewardAmount) .. " " .. tostring(quest.RewardType),
		variant = "success",
	})

	setQuestLevel(player, level + 1)

	task.wait(0.1)
	sendQuestUpdate(player)
end)

local function claimReadyDailyQuests(player)
	local state = getDailyQuestState(player)
	local claimedAny = false

	for _, quest in ipairs(DAILY_QUESTS) do
		local id = tostring(quest.Id or quest.Title or "")
		local goal = math.max(1, math.floor(tonumber(quest.Goal) or 1))
		local progress = tonumber(state.progress[id]) or 0

		if id ~= "" and progress >= goal and state.claimed[id] ~= true then
			state.claimed[id] = true
			claimedAny = true

			addCurrency(player, tostring(quest.RewardType or "Coins"), math.floor(tonumber(quest.RewardAmount) or 0))
			logDebug("quest", "DailyQuestCompleted", player, {
				id = id,
				title = quest.Title,
				rewardType = quest.RewardType,
				rewardAmount = quest.RewardAmount,
			})
			notifyRemote:FireClient(player, {
				message = "Daily complete: " .. tostring(quest.Title or "Quest") .. "!",
				variant = "success",
			})
		end
	end

	if claimedAny then
		saveDailyQuestState(player)
		sendQuestUpdate(player)
	end
end

local function applyGameplayEvent(eventName, player, payload)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		if DEBUG_CONFIG.DebugEnabled and DEBUG_CONFIG.WarnOnInvalidRemotes then
			warn("[QuestService] Ignored gameplay event without valid player:", eventName)
		end
		return
	end

	logDebug("gameplay", "GameplayEvent", player, {
		eventName = tostring(eventName or ""),
		payload = payload,
	})

	local state = getDailyQuestState(player)
	local changed = false

	for _, quest in ipairs(DAILY_QUESTS) do
		local id = tostring(quest.Id or quest.Title or "")
		if id ~= "" and state.claimed[id] ~= true and dailyQuestMatchesEvent(quest, eventName, payload or {}) then
			local goal = math.max(1, math.floor(tonumber(quest.Goal) or 1))
			local current = tonumber(state.progress[id]) or 0

			if current < goal then
				state.progress[id] = math.min(goal, current + 1)
				changed = true
			end
		end
	end

	if changed then
		saveDailyQuestState(player)
		claimReadyDailyQuests(player)
		sendQuestUpdate(player)
	end
end

gameplayEvent.Event:Connect(applyGameplayEvent)

Players.PlayerAdded:Connect(function(player)
	task.defer(function()
		loadMilestones(player)
		loadQuestProgress(player)
		loadDailyQuestState(player)

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
	saveQuestProgress(player)
	saveDailyQuestState(player)
	claimedMilestones[player.UserId] = nil
	claimCooldowns[player.UserId] = nil
	dailyQuestStateByUserId[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveMilestones(player)
		saveQuestProgress(player)
		saveDailyQuestState(player)
	end
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
