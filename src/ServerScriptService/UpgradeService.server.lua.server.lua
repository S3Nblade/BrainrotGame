--!nonstrict
-- UpgradeService.server.lua
-- Put in: ServerScriptService
-- Real upgrade system for Training Power and Auto Train speed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local upgradeStore = DataStoreService:GetDataStore("PlayerUpgrades_v1")

local REQUEST_REMOTE = "RequestUpgrade"
local UPDATE_REMOTE = "UpdateUpgrades"
local NOTIFY_REMOTE = "NotifyUser"

local requestRemote = ReplicatedStorage:FindFirstChild(REQUEST_REMOTE)
if not requestRemote then
	requestRemote = Instance.new("RemoteEvent")
	requestRemote.Name = REQUEST_REMOTE
	requestRemote.Parent = ReplicatedStorage
end

local updateRemote = ReplicatedStorage:FindFirstChild(UPDATE_REMOTE)
if not updateRemote then
	updateRemote = Instance.new("RemoteEvent")
	updateRemote.Name = UPDATE_REMOTE
	updateRemote.Parent = ReplicatedStorage
end

local notifyRemote = ReplicatedStorage:FindFirstChild(NOTIFY_REMOTE)
if not notifyRemote then
	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = NOTIFY_REMOTE
	notifyRemote.Parent = ReplicatedStorage
end

local DEFINITIONS = {
	TrainingPower = {
		title = "Training Power",
		desc = "More speed every click.",
		icon = "⚡",
		maxLevel = 5,
		requirements = { 250, 750, 1500, 3000, 5000 },
	},
	AutoTrainRate = {
		title = "Auto Train Rate",
		desc = "Auto Train clicks faster.",
		icon = "⏱️",
		maxLevel = 5,
		requirements = { 500, 1500, 3000, 6000, 10000 },
	},
}

local playerUpgrades = {}

local function notify(player, message, variant)
	notifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function getDefaultData()
	return {
		TrainingPower = 0,
		AutoTrainRate = 0,
	}
end

local function getSpeedPower(player)
	return tonumber(player:GetAttribute("SpeedPower")) or 0
end

local function getAutoTrainDelay(autoTrainLevel)
	local delay = 0.40 - (autoTrainLevel * 0.025)

	if delay < 0.29 then
		delay = 0.29
	end

	return delay
end

local function getTrainingMultiplier(trainingLevel)
	return 1 + (trainingLevel * 0.20)
end

local function applyUpgrades(player)
	local data = playerUpgrades[player.UserId] or getDefaultData()

	local trainingLevel = tonumber(data.TrainingPower) or 0
	local autoTrainLevel = tonumber(data.AutoTrainRate) or 0

	player:SetAttribute("TrainingMultiplier", getTrainingMultiplier(trainingLevel))
	player:SetAttribute("AutoTrainDelay", getAutoTrainDelay(autoTrainLevel))
end

local function buildPayload(player)
	local data = playerUpgrades[player.UserId] or getDefaultData()
	local speed = getSpeedPower(player)

	local upgrades = {}

	for key, def in pairs(DEFINITIONS) do
		local level = tonumber(data[key]) or 0
		local nextRequirement = nil
		local canUpgrade = false
		local maxed = level >= def.maxLevel

		if not maxed then
			nextRequirement = def.requirements[level + 1] or 0
			canUpgrade = speed >= nextRequirement
		end

		table.insert(upgrades, {
			key = key,
			title = def.title,
			desc = def.desc,
			icon = def.icon,
			level = level,
			maxLevel = def.maxLevel,
			nextRequirement = nextRequirement,
			canUpgrade = canUpgrade,
			maxed = maxed,
		})
	end

	table.sort(upgrades, function(a, b)
		return a.key < b.key
	end)

	return {
		speedPower = speed,
		trainingMultiplier = tonumber(player:GetAttribute("TrainingMultiplier")) or 1,
		autoTrainDelay = tonumber(player:GetAttribute("AutoTrainDelay")) or 0.40,
		upgrades = upgrades,
	}
end

local function fireUpdate(player)
	updateRemote:FireClient(player, buildPayload(player))
end

local function savePlayer(player)
	local data = playerUpgrades[player.UserId]
	if not data then
		return
	end

	pcall(function()
		upgradeStore:SetAsync("Upgrades_" .. tostring(player.UserId), data)
	end)
end

local function loadPlayer(player)
	local data = getDefaultData()

	local success, loaded = pcall(function()
		return upgradeStore:GetAsync("Upgrades_" .. tostring(player.UserId))
	end)

	if success and type(loaded) == "table" then
		for key, value in pairs(loaded) do
			if data[key] ~= nil then
				data[key] = tonumber(value) or 0
			end
		end
	end

	playerUpgrades[player.UserId] = data

	applyUpgrades(player)
	fireUpdate(player)

	player:GetAttributeChangedSignal("SpeedPower"):Connect(function()
		applyUpgrades(player)
		fireUpdate(player)
	end)

	print("[UpgradeService] loaded for", player.Name)
end

local function upgrade(player, key)
	if key == "_Refresh" then
		fireUpdate(player)
		return
	end

	local def = DEFINITIONS[key]
	if not def then
		notify(player, "Upgrade not found!", "error")
		return
	end

	local data = playerUpgrades[player.UserId] or getDefaultData()
	playerUpgrades[player.UserId] = data

	local currentLevel = tonumber(data[key]) or 0

	if currentLevel >= def.maxLevel then
		notify(player, def.title .. " is already maxed!", "warning")
		fireUpdate(player)
		return
	end

	local requiredSpeed = def.requirements[currentLevel + 1] or 0
	local speed = getSpeedPower(player)

	if speed < requiredSpeed then
		notify(player, "Need " .. tostring(requiredSpeed) .. " Speed!", "warning")
		fireUpdate(player)
		return
	end

	data[key] = currentLevel + 1

	applyUpgrades(player)
	savePlayer(player)
	fireUpdate(player)

	notify(player, def.title .. " upgraded to Level " .. tostring(data[key]) .. "!", "success")
end

requestRemote.OnServerEvent:Connect(function(player, key)
	if type(key) ~= "string" then
		return
	end

	upgrade(player, key)
end)

Players.PlayerAdded:Connect(loadPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	playerUpgrades[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)

print("[UpgradeService] server loaded")