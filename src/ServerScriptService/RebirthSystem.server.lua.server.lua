--!nonstrict
-- ServerScriptService/RebirthSystem.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

local REBIRTH_STORE = DataStoreService:GetDataStore("PlayerRebirths_v1")

local DEFAULT_REBIRTH_CONFIG = {
	BaseStrengthRequirement = 1000,
	RequirementMultiplierPerRebirth = 3,
	MoneyMultiplierPerRebirth = 2,
	ResetStats = { "Strength", "Power", "SpeedPower", "Speed" },
}

local function loadRebirthConfig()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("RebirthConfig")

	if module and module:IsA("ModuleScript") then
		local ok, config = pcall(require, module)
		if ok and type(config) == "table" then
			return config
		end

		warn("[RebirthSystem] Failed to load RebirthConfig, using defaults.")
	end

	return DEFAULT_REBIRTH_CONFIG
end

local REBIRTH_CONFIG = loadRebirthConfig()

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(name)
	local remote = remotesFolder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local function getOrCreateRemoteFunction(name)
	local remote = remotesFolder:FindFirstChild(name)
	if remote and remote:IsA("RemoteFunction") then
		return remote
	end

	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local rebirthRequest = getOrCreateRemoteEvent("RebirthRequest")
local rebirthUpdate = getOrCreateRemoteEvent("RebirthUpdate")
local rebirthComplete = getOrCreateRemoteEvent("RebirthComplete")
local rebirthGetState = getOrCreateRemoteFunction("RebirthGetState")

local notifyRemote = ReplicatedStorage:FindFirstChild("NotifyUser")
if not notifyRemote then
	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = "NotifyUser"
	notifyRemote.Parent = ReplicatedStorage
end

local playerRebirths = {}
local rebirthCooldowns = {}
local rebirthStateCooldowns = {}

local updateSpeedStats = ReplicatedStorage:FindFirstChild("UpdateSpeedStats")
if not updateSpeedStats then
	updateSpeedStats = Instance.new("RemoteEvent")
	updateSpeedStats.Name = "UpdateSpeedStats"
	updateSpeedStats.Parent = ReplicatedStorage
end

local function notify(player, message, variant)
	notifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function emitGameplayEvent(eventName, player, payload)
	local event = ServerStorage:FindFirstChild("BrainrotGameplayEvent")
	if event and event:IsA("BindableEvent") then
		event:Fire(eventName, player, payload or {})
	end
end

local function getLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	return leaderstats
end

local function getOrCreateNumberValue(parent, name, defaultValue)
	local value = parent:FindFirstChild(name)

	if not value then
		value = Instance.new("NumberValue")
		value.Name = name
		value.Value = defaultValue or 0
		value.Parent = parent
	end

	return value
end

local function getStrength(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats then
		local strengthValue = leaderstats:FindFirstChild("Strength")
		if strengthValue and (strengthValue:IsA("NumberValue") or strengthValue:IsA("IntValue")) then
			return tonumber(strengthValue.Value) or 0
		end
	end

	return tonumber(player:GetAttribute("Strength"))
		or tonumber(player:GetAttribute("Power"))
		or tonumber(player:GetAttribute("SpeedPower"))
		or tonumber(player:GetAttribute("Speed"))
		or 0
end

local function resetStrength(player)
	for _, name in ipairs(REBIRTH_CONFIG.ResetStats or DEFAULT_REBIRTH_CONFIG.ResetStats) do
		player:SetAttribute(name, 0)
	end

	player:SetAttribute("WalkSpeed", 16)

	local leaderstats = getLeaderstats(player)
	for _, name in ipairs(REBIRTH_CONFIG.ResetStats or DEFAULT_REBIRTH_CONFIG.ResetStats) do
		local value = leaderstats:FindFirstChild(name)
		if value and value:IsA("ValueBase") then
			value.Value = 0
		end
	end

	if updateSpeedStats and updateSpeedStats:IsA("RemoteEvent") then
		local perTrain = tonumber(player:GetAttribute("StrengthPerTrain"))
			or tonumber(player:GetAttribute("SpeedPerTrain"))
			or 1

		updateSpeedStats:FireClient(player, {
			strength = 0,
			speedPower = 0,
			walkSpeed = 16,
			speedPerTrain = perTrain,
			strengthPerTrain = perTrain,
		})
	end

	task.spawn(function()
		local saveSpeedFunction = ServerStorage:FindFirstChild("SaveSpeedFunction")
		if saveSpeedFunction and saveSpeedFunction:IsA("BindableFunction") then
			pcall(function()
				saveSpeedFunction:Invoke(player)
			end)
		end
	end)
end

local function getRequirement(rebirths)
	rebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	local baseRequirement = tonumber(REBIRTH_CONFIG.BaseStrengthRequirement) or DEFAULT_REBIRTH_CONFIG.BaseStrengthRequirement
	local multiplier = tonumber(REBIRTH_CONFIG.RequirementMultiplierPerRebirth)
		or DEFAULT_REBIRTH_CONFIG.RequirementMultiplierPerRebirth

	return math.floor(baseRequirement * (multiplier ^ rebirths))
end

local function getMoneyMultiplier(rebirths)
	rebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	local multiplier = tonumber(REBIRTH_CONFIG.MoneyMultiplierPerRebirth)
		or DEFAULT_REBIRTH_CONFIG.MoneyMultiplierPerRebirth

	return multiplier ^ rebirths
end

local function syncPlayer(player)
	local rebirths = playerRebirths[player.UserId] or 0
	local moneyMultiplier = getMoneyMultiplier(rebirths)
	local requirement = getRequirement(rebirths)

	player:SetAttribute("Rebirths", rebirths)
	player:SetAttribute("MoneyMultiplier", moneyMultiplier)
	player:SetAttribute("MoneyRegenMultiplier", moneyMultiplier)
	player:SetAttribute("NextRebirthStrengthRequirement", requirement)

	local leaderstats = getLeaderstats(player)
	getOrCreateNumberValue(leaderstats, "Rebirths", rebirths).Value = rebirths
end

local function buildPayload(player)
	local rebirths = playerRebirths[player.UserId] or 0
	local strength = getStrength(player)
	local requirement = getRequirement(rebirths)
	local moneyMultiplier = getMoneyMultiplier(rebirths)

	return {
		rebirths = rebirths,
		strength = strength,
		requirement = requirement,
		progress = math.clamp(strength / math.max(requirement, 1), 0, 1),
		moneyMultiplier = moneyMultiplier,
		nextMoneyMultiplier = moneyMultiplier
			* (tonumber(REBIRTH_CONFIG.MoneyMultiplierPerRebirth) or DEFAULT_REBIRTH_CONFIG.MoneyMultiplierPerRebirth),
		canRebirth = strength >= requirement,
	}
end

local function sendUpdate(player)
	syncPlayer(player)
	rebirthUpdate:FireClient(player, buildPayload(player))
end

local function getKey(player)
	return "Rebirths_" .. tostring(player.UserId)
end

local function savePlayer(player)
	local rebirths = playerRebirths[player.UserId]

	if rebirths == nil then
		return
	end

	local success, err = pcall(function()
		REBIRTH_STORE:SetAsync(getKey(player), rebirths)
	end)

	if not success then
		warn("[RebirthSystem] Failed saving rebirths for", player.Name, err)
	end
end

local function loadPlayer(player)
	local loaded = 0

	local success, result = pcall(function()
		return REBIRTH_STORE:GetAsync(getKey(player))
	end)

	if success and type(result) == "number" then
		loaded = math.max(0, math.floor(result))
	elseif not success then
		warn("[RebirthSystem] Failed loading rebirths for", player.Name, result)
	end

	playerRebirths[player.UserId] = loaded
	syncPlayer(player)

	task.defer(function()
		sendUpdate(player)
	end)

	player:GetAttributeChangedSignal("Strength"):Connect(function()
		sendUpdate(player)
	end)

	player:GetAttributeChangedSignal("SpeedPower"):Connect(function()
		sendUpdate(player)
	end)

	player:GetAttributeChangedSignal("Power"):Connect(function()
		sendUpdate(player)
	end)

	player:GetAttributeChangedSignal("Speed"):Connect(function()
		sendUpdate(player)
	end)

	task.spawn(function()
		while player.Parent do
			task.wait(5)
			sendUpdate(player)
		end
	end)
end

rebirthGetState.OnServerInvoke = function(player)
	local now = os.clock()
	if rebirthStateCooldowns[player.UserId] and now - rebirthStateCooldowns[player.UserId] < 0.35 then
		return buildPayload(player)
	end

	rebirthStateCooldowns[player.UserId] = now
	return buildPayload(player)
end

rebirthRequest.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if rebirthCooldowns[player.UserId] and now - rebirthCooldowns[player.UserId] < 1 then
		return
	end
	rebirthCooldowns[player.UserId] = now

	local rebirths = playerRebirths[player.UserId] or 0
	local strength = getStrength(player)
	local requirement = getRequirement(rebirths)

	if strength < requirement then
		notify(player, "Need " .. tostring(requirement) .. " Strength to rebirth!", "warning")
		sendUpdate(player)
		return
	end

	rebirths += 1
	playerRebirths[player.UserId] = rebirths

	resetStrength(player)
	syncPlayer(player)
	savePlayer(player)
	sendUpdate(player)

	local payload = buildPayload(player)
	payload.rewardText = "x" .. tostring(getMoneyMultiplier(rebirths)) .. " Money"
	payload.rebirths = rebirths
	rebirthComplete:FireClient(player, payload)
	emitGameplayEvent("RebirthCompleted", player, {
		rebirths = rebirths,
		requirement = requirement,
		moneyMultiplier = getMoneyMultiplier(rebirths),
	})

	notify(player, "Rebirth complete! Brainrot money is now x" .. tostring(getMoneyMultiplier(rebirths)) .. "!", "success")
end)

Players.PlayerAdded:Connect(loadPlayer)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	playerRebirths[player.UserId] = nil
	rebirthCooldowns[player.UserId] = nil
	rebirthStateCooldowns[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end

	task.wait(1)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(loadPlayer, player)
end

print("[RebirthSystem] Loaded. Rebirth requires Strength and gives x2 money per rebirth.")
