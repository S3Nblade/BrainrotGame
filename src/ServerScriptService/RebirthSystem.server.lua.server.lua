--!nonstrict
-- ServerScriptService/RebirthSystem.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

local REBIRTH_STORE = DataStoreService:GetDataStore("PlayerRebirths_v1")

local BASE_REBIRTH_STRENGTH_REQUIREMENT = 1000
local REQUIREMENT_MULTIPLIER_PER_REBIRTH = 3
local MONEY_MULTIPLIER_PER_REBIRTH = 2

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
	player:SetAttribute("Strength", 0)
	player:SetAttribute("Power", 0)
	player:SetAttribute("SpeedPower", 0)
	player:SetAttribute("Speed", 0)
	player:SetAttribute("WalkSpeed", 16)

	local leaderstats = getLeaderstats(player)
	for _, name in ipairs({ "Strength", "Power", "SpeedPower", "Speed" }) do
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
	return math.floor(BASE_REBIRTH_STRENGTH_REQUIREMENT * (REQUIREMENT_MULTIPLIER_PER_REBIRTH ^ rebirths))
end

local function getMoneyMultiplier(rebirths)
	rebirths = math.max(0, math.floor(tonumber(rebirths) or 0))
	return MONEY_MULTIPLIER_PER_REBIRTH ^ rebirths
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
		nextMoneyMultiplier = moneyMultiplier * MONEY_MULTIPLIER_PER_REBIRTH,
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
			task.wait(2)
			sendUpdate(player)
		end
	end)
end

rebirthGetState.OnServerInvoke = function(player)
	return buildPayload(player)
end

rebirthRequest.OnServerEvent:Connect(function(player)
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

	notify(player, "Rebirth complete! Brainrot money is now x" .. tostring(getMoneyMultiplier(rebirths)) .. "!", "success")
end)

Players.PlayerAdded:Connect(loadPlayer)

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	playerRebirths[player.UserId] = nil
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
