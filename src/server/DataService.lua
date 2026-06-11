local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = {}

local STORE_NAME = "PixelBrainrotSimulator_v1"
local SESSION_TIMEOUT = 180
local RETRIES = 5

local template = {
	Money = 0,
	Gems = 0,
	Rebirths = 0,
	Inventory = {},
	Placed = {},
	Discovered = {},
	UnlockedZones = { Grass = true },
	Settings = { Music = true, SFX = true },
	StorageLevel = 0,
	Boosts = { LuckUntil = 0, SpeedUntil = 0, MoneyUntil = 0 },
	QuestStage = 1,
	QuestProgress = 0,
	LastSeen = 0,
	Daily = { LastClaimDay = -1, Streak = 0 },
}

local profiles = {}
local store
local context
local dataStoreAvailable = false

local function reconcile(target, source)
	for key, value in pairs(source) do
		if target[key] == nil then
			target[key] = context.Util.DeepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function retry(callback)
	local lastError
	for attempt = 1, RETRIES do
		local success, result = pcall(callback)
		if success then
			return true, result
		end
		lastError = result
		task.wait(math.min(2 ^ (attempt - 1), 8))
	end
	return false, lastError
end

local function publicState(data)
	return {
		Money = data.Money,
		Gems = data.Gems,
		Rebirths = data.Rebirths,
		Inventory = data.Inventory,
		Placed = data.Placed,
		Discovered = data.Discovered,
		UnlockedZones = data.UnlockedZones,
		Settings = data.Settings,
		StorageLevel = data.StorageLevel,
		Boosts = data.Boosts,
		QuestStage = data.QuestStage,
		QuestProgress = data.QuestProgress,
		Power = context.EconomyService.GetPlayerDamage(data),
		Daily = {
			LastClaimDay = data.Daily.LastClaimDay,
			Streak = data.Daily.Streak,
			CanClaim = data.Daily.LastClaimDay < math.floor(os.time() / 86400),
		},
	}
end

function DataService.Init(newContext)
	context = newContext
	template.Money = context.Config.Economy.StartingMoney
	template.Gems = context.Config.Economy.StartingGems
	if game.PlaceId == 0 then
		return
	end
	local success, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if success then
		store = result
		dataStoreAvailable = true
	else
		warn("DataStore unavailable; using temporary session data:", result)
	end
end

function DataService.Get(player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService.GetPublicState(player)
	local data = DataService.Get(player)
	return data and publicState(data) or nil
end

function DataService.PushState(player)
	local state = DataService.GetPublicState(player)
	if state then
		context.Remotes.StateChanged:FireClient(player, state)
	end
end

function DataService.Update(player, callback)
	local data = DataService.Get(player)
	if not data then
		return false
	end
	callback(data)
	DataService.PushState(player)
	return true
end

function DataService.Load(player)
	local key = "Player_" .. player.UserId
	if not dataStoreAvailable then
		profiles[player] = {
			Key = key,
			Data = context.Util.DeepCopy(template),
			Temporary = true,
		}
		context.OfflineEarningsService.Apply(profiles[player].Data)
		DataService.PushState(player)
		return true
	end
	local loaded
	local success, err = retry(function()
		loaded = store:UpdateAsync(key, function(current)
			current = current or { Data = context.Util.DeepCopy(template) }
			local session = current.Session
			if session and session.JobId ~= game.JobId and os.time() - (session.Timestamp or 0) < SESSION_TIMEOUT then
				return nil
			end
			reconcile(current.Data, template)
			current.Session = { JobId = game.JobId, Timestamp = os.time() }
			return current
		end)
	end)

	if not success or not loaded then
		if RunService:IsStudio() then
			warn("DataStore unavailable in Studio; using temporary data:", err)
			loaded = { Data = context.Util.DeepCopy(template) }
		else
			player:Kick("Your data is active on another server. Please try again shortly.")
			return false
		end
	end

	profiles[player] = { Key = key, Data = loaded.Data, Dirty = false }
	local offlineReward, secondsAway = context.OfflineEarningsService.Apply(loaded.Data)
	DataService.PushState(player)
	if offlineReward > 0 then
		task.delay(2, function()
			if player.Parent then
				context.Remotes.Notify:FireClient(
					player,
					string.format(
						"Welcome back! Your stands earned $%s while you were away for %s.",
						context.Util.FormatNumber(offlineReward),
						context.OfflineEarningsService.FormatDuration(secondsAway)
					),
					"Success"
				)
			end
		end)
	end
	return true
end

function DataService.Save(player, release)
	local profile = profiles[player]
	if not profile then
		return true
	end
	if profile.Temporary or not dataStoreAvailable then
		if release then
			profiles[player] = nil
		end
		return true
	end
	profile.Data.LastSeen = os.time()
	local snapshot = context.Util.DeepCopy(profile.Data)
	local success, err = retry(function()
		store:UpdateAsync(profile.Key, function(current)
			current = current or {}
			local session = current.Session
			if session and session.JobId ~= game.JobId then
				return nil
			end
			current.Data = snapshot
			current.Session = release and nil or { JobId = game.JobId, Timestamp = os.time() }
			return current
		end)
	end)
	if not success then
		warn("Failed to save", player.Name, err)
	end
	if release then
		profiles[player] = nil
	end
	return success
end

function DataService.Start()
	Players.PlayerAdded:Connect(DataService.Load)
	Players.PlayerRemoving:Connect(function(player)
		DataService.Save(player, true)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(DataService.Load, player)
	end
	task.spawn(function()
		while task.wait(context.Config.Economy.AutosaveSeconds) do
			for player in pairs(profiles) do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		for player in pairs(profiles) do
			DataService.Save(player, true)
		end
	end)
end

return DataService
