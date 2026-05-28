--!nonstrict
-- UpgradeService.server.lua
-- Server-authoritative upgrade system. Reads shared UpgradeConfig when Rojo has synced it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

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

local DEFAULT_DEFINITIONS = {
	TrainingPower = {
		order = 10,
		title = "Training Power",
		desc = "More strength every training hit.",
		icon = "STR",
		maxLevel = 5,
		requirements = { 250, 750, 1500, 3000, 5000 },
		effect = {
			attribute = "TrainingMultiplier",
			base = 1,
			perLevel = 0.20,
		},
	},
	AutoTrainRate = {
		order = 20,
		title = "Auto Train Rate",
		desc = "Auto Train clicks faster.",
		icon = "SPD",
		maxLevel = 5,
		requirements = { 500, 1500, 3000, 6000, 10000 },
		effect = {
			attribute = "AutoTrainDelay",
			base = 0.40,
			perLevel = -0.025,
			min = 0.29,
		},
	},
}

local function loadUpgradeDefinitions()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("UpgradeConfig")

	if module and module:IsA("ModuleScript") then
		local ok, config = pcall(require, module)
		if ok and type(config) == "table" and type(config.Definitions) == "table" then
			return config.Definitions
		end

		warn("[UpgradeService] Failed to load UpgradeConfig, using defaults.")
	end

	return DEFAULT_DEFINITIONS
end

local DEFINITIONS = loadUpgradeDefinitions()
local playerUpgrades = {}
local requestCooldown = {}
local REQUEST_COOLDOWN_SECONDS = 0.25

local function emitGameplayEvent(eventName, player, payload)
	local event = ServerStorage:FindFirstChild("BrainrotGameplayEvent")
	if event and event:IsA("BindableEvent") then
		event:Fire(eventName, player, payload or {})
	end
end

local function notify(player, message, variant)
	notifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function getDefaultData()
	local data = {}

	for key in pairs(DEFINITIONS) do
		data[key] = 0
	end

	return data
end

local function getSpeedPower(player)
	return tonumber(player:GetAttribute("SpeedPower"))
		or tonumber(player:GetAttribute("Strength"))
		or tonumber(player:GetAttribute("Power"))
		or 0
end

local function applyConfiguredEffect(player, level, effect)
	if type(effect) ~= "table" or type(effect.attribute) ~= "string" then
		return
	end

	local value = (tonumber(effect.base) or 0) + (level * (tonumber(effect.perLevel) or 0))

	if type(effect.min) == "number" then
		value = math.max(effect.min, value)
	end

	if type(effect.max) == "number" then
		value = math.min(effect.max, value)
	end

	player:SetAttribute(effect.attribute, value)
end

local function applyUpgrades(player)
	local data = playerUpgrades[player.UserId] or getDefaultData()

	for key, def in pairs(DEFINITIONS) do
		local level = tonumber(data[key]) or 0
		applyConfiguredEffect(player, level, def.effect)
	end

	if player:GetAttribute("TrainingMultiplier") == nil then
		player:SetAttribute("TrainingMultiplier", 1)
	end

	if player:GetAttribute("AutoTrainDelay") == nil then
		player:SetAttribute("AutoTrainDelay", 0.40)
	end

	if player:GetAttribute("CapturePowerMultiplier") == nil then
		player:SetAttribute("CapturePowerMultiplier", 1)
	end

	if player:GetAttribute("LuckMultiplier") == nil then
		player:SetAttribute("LuckMultiplier", 1)
	end

	if player:GetAttribute("InventoryCapacityBonus") == nil then
		player:SetAttribute("InventoryCapacityBonus", 0)
	end

	if player:GetAttribute("PlotSlotDiscount") == nil then
		player:SetAttribute("PlotSlotDiscount", 0)
	end

	if player:GetAttribute("ShopCashMultiplier") == nil then
		player:SetAttribute("ShopCashMultiplier", 1)
	end
end

local function buildPayload(player)
	local data = playerUpgrades[player.UserId] or getDefaultData()
	local speed = getSpeedPower(player)
	local upgrades = {}

	for key, def in pairs(DEFINITIONS) do
		local level = tonumber(data[key]) or 0
		local maxLevel = tonumber(def.maxLevel) or 1
		local nextRequirement = nil
		local canUpgrade = false
		local maxed = level >= maxLevel

		if not maxed then
			nextRequirement = tonumber(def.requirements and def.requirements[level + 1]) or 0
			canUpgrade = speed >= nextRequirement
		end

		table.insert(upgrades, {
			key = key,
			order = tonumber(def.order) or 999,
			title = tostring(def.title or key),
			desc = tostring(def.desc or ""),
			icon = tostring(def.icon or ""),
			level = level,
			maxLevel = maxLevel,
			nextRequirement = nextRequirement,
			canUpgrade = canUpgrade,
			maxed = maxed,
		})
	end

	table.sort(upgrades, function(a, b)
		if (tonumber(a.order) or 999) ~= (tonumber(b.order) or 999) then
			return (tonumber(a.order) or 999) < (tonumber(b.order) or 999)
		end

		return tostring(a.key) < tostring(b.key)
	end)

	return {
		speedPower = speed,
		trainingMultiplier = tonumber(player:GetAttribute("TrainingMultiplier")) or 1,
		autoTrainDelay = tonumber(player:GetAttribute("AutoTrainDelay")) or 0.40,
		capturePowerMultiplier = tonumber(player:GetAttribute("CapturePowerMultiplier")) or 1,
		luckMultiplier = tonumber(player:GetAttribute("LuckMultiplier")) or 1,
		inventoryCapacityBonus = tonumber(player:GetAttribute("InventoryCapacityBonus")) or 0,
		plotSlotDiscount = tonumber(player:GetAttribute("PlotSlotDiscount")) or 0,
		shopCashMultiplier = tonumber(player:GetAttribute("ShopCashMultiplier")) or 1,
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
				local def = DEFINITIONS[key]
				local maxLevel = def and tonumber(def.maxLevel) or 0
				data[key] = math.clamp(math.floor(tonumber(value) or 0), 0, maxLevel)
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

	player:GetAttributeChangedSignal("Strength"):Connect(function()
		fireUpdate(player)
	end)

	print("[UpgradeService] loaded for", player.Name)
end

local function upgrade(player, key)
	local now = os.clock()
	if requestCooldown[player.UserId] and now - requestCooldown[player.UserId] < REQUEST_COOLDOWN_SECONDS then
		return
	end
	requestCooldown[player.UserId] = now

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
	local maxLevel = tonumber(def.maxLevel) or 1

	if currentLevel >= maxLevel then
		notify(player, tostring(def.title or key) .. " is already maxed!", "warning")
		fireUpdate(player)
		return
	end

	local requiredSpeed = tonumber(def.requirements and def.requirements[currentLevel + 1]) or 0
	local speed = getSpeedPower(player)

	if speed < requiredSpeed then
		notify(player, "Need " .. tostring(requiredSpeed) .. " Strength!", "warning")
		fireUpdate(player)
		return
	end

	data[key] = currentLevel + 1

	applyUpgrades(player)
	savePlayer(player)
	fireUpdate(player)
	emitGameplayEvent("ShopPurchase", player, {
		upgradeKey = key,
		title = tostring(def.title or key),
		level = data[key],
		requiredStrength = requiredSpeed,
	})

	notify(player, tostring(def.title or key) .. " upgraded to Level " .. tostring(data[key]) .. "!", "success")
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
	requestCooldown[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)

print("[UpgradeService] server loaded with config-driven definitions.")
