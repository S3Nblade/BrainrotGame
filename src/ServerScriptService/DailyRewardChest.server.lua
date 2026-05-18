--!nonstrict
-- ServerScriptService/DailyRewardChest.server.lua
-- Fixed: only sends one daily reward GUI message.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local CHEST_NAMES = {
	chest = true,
	DailyRewardChest = true,
}

local PROMPT_NAME = "DailyRewardPrompt"
local COOLDOWN_SECONDS = 24 * 60 * 60
local CHECK_EVERY = 1

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
local lastClaimCache = {}

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

local function getLastClaim(player)
	if lastClaimCache[player.UserId] ~= nil then
		return lastClaimCache[player.UserId]
	end

	local success, result = pcall(function()
		return dailyStore:GetAsync(tostring(player.UserId))
	end)

	if success and typeof(result) == "number" then
		lastClaimCache[player.UserId] = result
		return result
	end

	lastClaimCache[player.UserId] = 0
	return 0
end

local function setLastClaim(player, timestamp)
	lastClaimCache[player.UserId] = timestamp

	pcall(function()
		dailyStore:SetAsync(tostring(player.UserId), timestamp)
	end)
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

local function calculateReward(player, chest)
	local baseReward = tonumber(chest:GetAttribute("RewardMoney")) or 5000
	local rebirths = tonumber(player:GetAttribute("Rebirths")) or 0

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirthStat = leaderstats:FindFirstChild("Rebirths")
		if rebirthStat and rebirthStat:IsA("ValueBase") then
			rebirths = tonumber(rebirthStat.Value) or rebirths
		end
	end

	return math.floor(baseReward + (rebirths * 15000))
end

local function claim(player, chest)
	local now = os.time()
	local cooldown = tonumber(chest:GetAttribute("CooldownSeconds")) or COOLDOWN_SECONDS
	local lastClaim = getLastClaim(player)
	local remaining = cooldown - (now - lastClaim)

	if remaining > 0 then
		dailyRemote:FireClient(player, {
			success = false,
			message = "Daily chest ready in " .. formatTime(remaining) .. ".",
			remaining = remaining,
		})
		return
	end

	local reward = calculateReward(player, chest)

	addMoney(player, reward)
	setLastClaim(player, now)

	dailyRemote:FireClient(player, {
		success = true,
		message = "Daily reward: $" .. formatMoney(reward) .. "!",
		reward = reward,
		remaining = cooldown,
	})
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
	lastClaimCache[player.UserId] = nil
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

print("[DailyRewardChest] Loaded fixed one-message daily chest.")