--!nonstrict
-- ServerScriptService/GameJuiceRemotes.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local existing = remotesFolder:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteEvent") then
			existing.Parent = remotesFolder
			return existing
		end

		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

ensureRemoteEvent("RarityReveal")
ensureRemoteEvent("ServerAnnouncement")
ensureRemoteEvent("DailyRewardResult")
ensureRemoteEvent("WorldEventUpdate")
ensureRemoteEvent("ZoneGateFeedback")
ensureRemoteEvent("TrainingFeedback")
ensureRemoteEvent("OfflineRewardResult")
ensureRemoteEvent("CollectionMilestoneReward")
ensureRemoteEvent("RebirthComplete")
local playtimeUpdateRemote = ensureRemoteEvent("PlaytimeRewardUpdate")
local playtimeClaimRemote = ensureRemoteEvent("ClaimPlaytimeReward")
local playtimeResultRemote = ensureRemoteEvent("PlaytimeRewardResult")

local updateCoinsRemote = ReplicatedStorage:FindFirstChild("UpdateCoins")
if not updateCoinsRemote then
	updateCoinsRemote = Instance.new("RemoteEvent")
	updateCoinsRemote.Name = "UpdateCoins"
	updateCoinsRemote.Parent = ReplicatedStorage
end

local PLAYTIME_REWARDS = {
	{ Seconds = 120, Money = 750, Label = "2m Gift" },
	{ Seconds = 300, Money = 2500, Label = "5m Gift" },
	{ Seconds = 600, Money = 7500, Label = "10m Gift" },
	{ Seconds = 900, Money = 15000, Label = "15m Gift" },
}

local CLAIM_COOLDOWN_SECONDS = 0.75
local playtimeState = {}
local claimCooldowns = {}

local function formatMoney(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
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
		return 0
	end

	local money = getMoneyValue(player)
	money.Value += amount
	player:SetAttribute("Money", money.Value)
	player:SetAttribute("Coins", money.Value)
	player:SetAttribute("Cash", money.Value)

	if updateCoinsRemote and updateCoinsRemote:IsA("RemoteEvent") then
		updateCoinsRemote:FireClient(player, money.Value)
	end

	return money.Value
end

local function getState(player)
	local state = playtimeState[player.UserId]
	if not state then
		state = {
			JoinedAt = os.clock(),
			Claimed = {},
		}
		playtimeState[player.UserId] = state
	end
	return state
end

local function getNextReward(player)
	local state = getState(player)
	local elapsed = os.clock() - state.JoinedAt

	for index, reward in ipairs(PLAYTIME_REWARDS) do
		if not state.Claimed[index] then
			local remaining = math.max(0, math.ceil(reward.Seconds - elapsed))
			return index, reward, remaining, elapsed
		end
	end

	return nil, nil, 0, elapsed
end

local function firePlaytimeUpdate(player)
	local index, reward, remaining, elapsed = getNextReward(player)

	if not index or not reward then
		playtimeUpdateRemote:FireClient(player, {
			done = true,
			elapsed = math.floor(elapsed),
		})
		return
	end

	playtimeUpdateRemote:FireClient(player, {
		index = index,
		total = #PLAYTIME_REWARDS,
		label = reward.Label,
		money = reward.Money,
		moneyText = "$" .. formatMoney(reward.Money),
		seconds = reward.Seconds,
		remaining = remaining,
		ready = remaining <= 0,
		elapsed = math.floor(elapsed),
	})
end

playtimeClaimRemote.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local lastClaimRequest = claimCooldowns[player.UserId] or 0
	if now - lastClaimRequest < CLAIM_COOLDOWN_SECONDS then
		return
	end
	claimCooldowns[player.UserId] = now

	local state = getState(player)
	local index, reward, remaining = getNextReward(player)

	if not index or not reward then
		firePlaytimeUpdate(player)
		return
	end

	if remaining > 0 then
		firePlaytimeUpdate(player)
		return
	end

	state.Claimed[index] = true
	addMoney(player, reward.Money)

	playtimeResultRemote:FireClient(player, {
		success = true,
		message = "Free gift claimed: $" .. formatMoney(reward.Money) .. "!",
		money = reward.Money,
		moneyText = "$" .. formatMoney(reward.Money),
		index = index,
	})

	firePlaytimeUpdate(player)
end)

Players.PlayerAdded:Connect(function(player)
	getState(player)
	task.spawn(function()
		while player.Parent do
			firePlaytimeUpdate(player)
			task.wait(1)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	playtimeState[player.UserId] = nil
	claimCooldowns[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(function()
		getState(player)
		firePlaytimeUpdate(player)
	end)
end

print("[GameJuiceRemotes] Loaded.")
