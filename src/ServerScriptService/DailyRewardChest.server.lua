--!nonstrict
-- ServerScriptService/DailyRewardChest.server.lua
-- Daily streak chest with simulator-style reward scaling.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local CHEST_NAMES = {
	chest = true,
	DailyRewardChest = true,
}

local DEFAULT_DAILY_CONFIG = {
	CooldownSeconds = 24 * 60 * 60,
	CheckEverySeconds = 1,
	StreakResetSeconds = 2 * 24 * 60 * 60,
	BaseRewardMoney = 5000,
	RewardPerRebirth = 15000,
	StreakRewards = {
		{ Day = 1, Multiplier = 1.0, Label = "Day 1" },
		{ Day = 2, Multiplier = 1.25, Label = "Day 2" },
		{ Day = 3, Multiplier = 1.55, Label = "Day 3" },
		{ Day = 4, Multiplier = 1.9, Label = "Day 4" },
		{ Day = 5, Multiplier = 2.35, Label = "Day 5" },
		{ Day = 6, Multiplier = 2.8, Label = "Day 6" },
		{ Day = 7, Multiplier = 4.0, Label = "MEGA" },
	},
}

local function loadDailyConfig()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("DailyRewardConfig")

	if module and module:IsA("ModuleScript") then
		local ok, config = pcall(require, module)
		if ok and type(config) == "table" then
			return config
		end

		warn("[DailyRewardChest] Failed to load DailyRewardConfig, using defaults.")
	end

	return DEFAULT_DAILY_CONFIG
end

local DAILY_CONFIG = loadDailyConfig()
local PROMPT_NAME = "DailyRewardPrompt"
local COOLDOWN_SECONDS = tonumber(DAILY_CONFIG.CooldownSeconds) or DEFAULT_DAILY_CONFIG.CooldownSeconds
local CHECK_EVERY = tonumber(DAILY_CONFIG.CheckEverySeconds) or DEFAULT_DAILY_CONFIG.CheckEverySeconds
local STREAK_RESET_SECONDS = tonumber(DAILY_CONFIG.StreakResetSeconds) or (COOLDOWN_SECONDS * 2)
local STREAK_REWARDS = type(DAILY_CONFIG.StreakRewards) == "table"
	and DAILY_CONFIG.StreakRewards
	or DEFAULT_DAILY_CONFIG.StreakRewards
if #STREAK_REWARDS <= 0 then
	STREAK_REWARDS = DEFAULT_DAILY_CONFIG.StreakRewards
end

local dailyStore = DataStoreService:GetDataStore("DailyRewardChest_v2")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local dailyRemote = remotesFolder:FindFirstChild("DailyRewardResult")
if not dailyRemote then
	dailyRemote = Instance.new("RemoteEvent")
	dailyRemote.Name = "DailyRewardResult"
	dailyRemote.Parent = remotesFolder
end

local boundChests = {}
local dailyStateCache = {}

local function formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)

	if hours > 0 then
		return tostring(hours) .. "h " .. tostring(minutes) .. "m"
	end

	return tostring(minutes) .. "m"
end

local function formatMoney(value)
	value = tonumber(value) or 0

	if value >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end

	return tostring(math.floor(value))
end

local function getMoneyValue(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local money = leaderstats:FindFirstChild("Money")
		or leaderstats:FindFirstChild("Coins")
		or leaderstats:FindFirstChild("Cash")

	if money and money:IsA("ValueBase") then
		return money
	end

	money = Instance.new("NumberValue")
	money.Name = "Money"
	money.Value = tonumber(player:GetAttribute("Money")) or tonumber(player:GetAttribute("Coins")) or 0
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

	local updateCoins = ReplicatedStorage:FindFirstChild("UpdateCoins")
	if updateCoins and updateCoins:IsA("RemoteEvent") then
		updateCoins:FireClient(player, money.Value)
	end
end

local function isChest(obj)
	return CHEST_NAMES[obj.Name] == true or obj:GetAttribute("IsDailyRewardChest") == true
end

local function getChestPart(chest)
	if chest:IsA("BasePart") then
		return chest
	end

	for _, obj in ipairs(chest:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function getBaseReward(player, chest)
	local baseReward = tonumber(chest:GetAttribute("RewardMoney"))
		or tonumber(DAILY_CONFIG.BaseRewardMoney)
		or DEFAULT_DAILY_CONFIG.BaseRewardMoney
	local rebirths = tonumber(player:GetAttribute("Rebirths")) or 0

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthStat = leaderstats:FindFirstChild("Rebirths")
		if rebirthStat and rebirthStat:IsA("ValueBase") then
			rebirths = tonumber(rebirthStat.Value) or rebirths
		end
	end

	local perRebirth = tonumber(DAILY_CONFIG.RewardPerRebirth) or DEFAULT_DAILY_CONFIG.RewardPerRebirth

	return math.floor(baseReward + (rebirths * perRebirth))
end

local function getStreakDay(streak)
	return ((math.max(1, math.floor(tonumber(streak) or 1)) - 1) % #STREAK_REWARDS) + 1
end

local function normalizeState(raw)
	if typeof(raw) == "number" then
		return {
			lastClaim = raw,
			streak = raw > 0 and 1 or 0,
			bestStreak = raw > 0 and 1 or 0,
		}
	end

	if typeof(raw) == "table" then
		return {
			lastClaim = tonumber(raw.lastClaim) or tonumber(raw.LastClaim) or 0,
			streak = math.max(0, math.floor(tonumber(raw.streak) or tonumber(raw.Streak) or 0)),
			bestStreak = math.max(0, math.floor(tonumber(raw.bestStreak) or tonumber(raw.BestStreak) or 0)),
		}
	end

	return {
		lastClaim = 0,
		streak = 0,
		bestStreak = 0,
	}
end

local function getDailyState(player)
	if dailyStateCache[player.UserId] then
		return dailyStateCache[player.UserId]
	end

	local success, result = pcall(function()
		return dailyStore:GetAsync(tostring(player.UserId))
	end)

	local state = success and normalizeState(result) or normalizeState(nil)
	dailyStateCache[player.UserId] = state
	player:SetAttribute("DailyLastClaim", tonumber(state.lastClaim) or 0)
	player:SetAttribute("DailyStreak", tonumber(state.streak) or 0)
	player:SetAttribute("DailyBestStreak", tonumber(state.bestStreak) or 0)
	return state
end

local function saveDailyState(player, state)
	dailyStateCache[player.UserId] = state
	player:SetAttribute("DailyLastClaim", tonumber(state.lastClaim) or 0)
	player:SetAttribute("DailyStreak", tonumber(state.streak) or 0)
	player:SetAttribute("DailyBestStreak", tonumber(state.bestStreak) or 0)

	pcall(function()
		dailyStore:SetAsync(tostring(player.UserId), state)
	end)
end

local function buildCalendar(baseReward, streak, claimedToday)
	local calendar = {}
	local currentDay = getStreakDay(math.max(1, streak + (claimedToday and 0 or 1)))

	for _, rewardInfo in ipairs(STREAK_REWARDS) do
		table.insert(calendar, {
			day = rewardInfo.Day,
			label = rewardInfo.Label,
			multiplier = rewardInfo.Multiplier,
			reward = math.floor(baseReward * rewardInfo.Multiplier),
			rewardText = "$" .. formatMoney(baseReward * rewardInfo.Multiplier),
			current = rewardInfo.Day == currentDay,
			claimed = claimedToday and rewardInfo.Day == currentDay,
		})
	end

	return calendar
end

local function buildPayload(player, chest, success, message, reward, remaining)
	local state = getDailyState(player)
	local baseReward = getBaseReward(player, chest)
	local now = os.time()
	local cooldown = tonumber(chest:GetAttribute("CooldownSeconds")) or COOLDOWN_SECONDS
	local claimedToday = (now - (tonumber(state.lastClaim) or 0)) < cooldown

	return {
		success = success,
		message = message,
		reward = reward or 0,
		rewardText = reward and ("$" .. formatMoney(reward)) or "$0",
		remaining = math.max(0, math.floor(remaining or 0)),
		remainingText = formatTime(remaining or 0),
		streak = state.streak or 0,
		bestStreak = state.bestStreak or 0,
		nextDay = getStreakDay(math.max(1, (state.streak or 0) + 1)),
		calendar = buildCalendar(baseReward, state.streak or 0, claimedToday),
	}
end

local function claim(player, chest)
	local now = os.time()
	local cooldown = tonumber(chest:GetAttribute("CooldownSeconds")) or COOLDOWN_SECONDS
	local state = getDailyState(player)
	local lastClaim = tonumber(state.lastClaim) or 0
	local remaining = cooldown - (now - lastClaim)

	if remaining > 0 then
		dailyRemote:FireClient(
			player,
			buildPayload(player, chest, false, "Daily chest ready in " .. formatTime(remaining) .. ".", 0, remaining)
		)
		return
	end

	if lastClaim > 0 and now - lastClaim <= STREAK_RESET_SECONDS then
		state.streak = math.max(1, math.floor(tonumber(state.streak) or 0) + 1)
	else
		state.streak = 1
	end

	state.bestStreak = math.max(math.floor(tonumber(state.bestStreak) or 0), state.streak)
	state.lastClaim = now

	local baseReward = getBaseReward(player, chest)
	local streakInfo = STREAK_REWARDS[getStreakDay(state.streak)]
	local reward = math.floor(baseReward * (streakInfo.Multiplier or 1))

	addMoney(player, reward)
	saveDailyState(player, state)

	dailyRemote:FireClient(
		player,
		buildPayload(player, chest, true, "Daily streak " .. tostring(state.streak) .. ": $" .. formatMoney(reward) .. "!", reward, cooldown)
	)
end

local function bindChest(chest)
	if boundChests[chest] then
		return
	end

	local part = getChestPart(chest)
	if not part then
		return
	end

	boundChests[chest] = true

	chest:SetAttribute("IsDailyRewardChest", true)

	local prompt = part:FindFirstChild(PROMPT_NAME)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.ActionText = "Daily Reward"
		prompt.ObjectText = ""
		prompt.HoldDuration = 0.25
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 12
		prompt.Parent = part
	end

	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Enabled = true

	prompt.Triggered:Connect(function(player)
		claim(player, chest)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	dailyStateCache[player.UserId] = nil
end)

task.spawn(function()
	while true do
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if isChest(obj) then
				bindChest(obj)
			end
		end

		task.wait(CHECK_EVERY)
	end
end)

print("[DailyRewardChest] Loaded streak daily chest.")
