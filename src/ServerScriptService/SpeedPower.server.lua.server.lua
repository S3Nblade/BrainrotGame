--!nonstrict
-- ServerScriptService/SpeedPower.server.lua
-- FIXED: weight training gives Strength again + fires popup reward to WeightTraining.client.lua.
-- Lucky bar stays working.
-- Auto lifting gives strength every 0.8s.
-- Lucky meter gives bonus strength.
-- Syncs Strength / Power / SpeedPower / Speed for old scripts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local REMOTES_FOLDER_NAME = "Remotes"

local START_REMOTE_NAME = "StartWeightTraining"
local STOP_REMOTE_NAME = "StopWeightTraining"
local METER_REMOTE_NAME = "WeightTrainingMeterHit"
local REWARD_REMOTE_NAME = "WeightTrainingReward"
local STATE_REMOTE_NAME = "WeightTrainingState"

local AUTO_GAIN_INTERVAL = 0.8
local AUTO_BASE_GAIN = 1
local METER_BONUS_COOLDOWN = 1.2

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2

local TRAINING_TOOL_KEYWORDS = {
	"weight",
	"training",
	"dumbbell",
	"barbell",
}

local METER_MULTIPLIERS = {
	Perfect = 14,
	Excellent = 9,
	Great = 6,
	Good = 5,
	Average = 3,
	Bad = 1,
}

local remotesFolder = ReplicatedStorage:FindFirstChild(REMOTES_FOLDER_NAME)
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = REMOTES_FOLDER_NAME
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemoteEvent(parent, name)
	local remote = parent:FindFirstChild(name)

	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function getOrCreateBindableFunction(name)
	local bindable = ServerStorage:FindFirstChild(name)

	if bindable and bindable:IsA("BindableFunction") then
		return bindable
	end

	if bindable then
		bindable:Destroy()
	end

	bindable = Instance.new("BindableFunction")
	bindable.Name = name
	bindable.Parent = ServerStorage
	return bindable
end

local startRemote = getOrCreateRemoteEvent(remotesFolder, START_REMOTE_NAME)
local stopRemote = getOrCreateRemoteEvent(remotesFolder, STOP_REMOTE_NAME)
local meterRemote = getOrCreateRemoteEvent(remotesFolder, METER_REMOTE_NAME)
local rewardRemote = getOrCreateRemoteEvent(remotesFolder, REWARD_REMOTE_NAME)
local stateRemote = getOrCreateRemoteEvent(remotesFolder, STATE_REMOTE_NAME)

local updateSpeedStats = getOrCreateRemoteEvent(ReplicatedStorage, "UpdateSpeedStats")

local addSavedSpeedFunction = getOrCreateBindableFunction("AddSavedSpeedFunction")
local saveSpeedFunction = getOrCreateBindableFunction("SaveSpeedFunction")

local trainingStates = {}

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

	if value:IsA("NumberValue") or value:IsA("IntValue") then
		return value
	end

	value:Destroy()

	local newValue = Instance.new("NumberValue")
	newValue.Name = name
	newValue.Value = defaultValue or 0
	newValue.Parent = parent
	return newValue
end

local function getCurrentStrength(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats then
		local strength = leaderstats:FindFirstChild("Strength")
		if strength and strength:IsA("ValueBase") then
			return tonumber(strength.Value) or 0
		end
	end

	return tonumber(player:GetAttribute("Strength"))
		or tonumber(player:GetAttribute("Power"))
		or tonumber(player:GetAttribute("SpeedPower"))
		or tonumber(player:GetAttribute("Speed"))
		or 0
end

local function getWalkSpeedFromStrength(strength)
	return math.clamp(DEFAULT_WALK_SPEED + math.sqrt(math.max(0, strength)) * 1.55, DEFAULT_WALK_SPEED, 115)
end

local function syncStrength(player, strength)
	strength = math.max(0, math.floor(tonumber(strength) or 0))

	local walkSpeed = getWalkSpeedFromStrength(strength)

	player:SetAttribute("Strength", strength)
	player:SetAttribute("Power", strength)
	player:SetAttribute("SpeedPower", strength)
	player:SetAttribute("Speed", strength)
	player:SetAttribute("WalkSpeed", walkSpeed)

	local leaderstats = getLeaderstats(player)

	local strengthValue = getOrCreateNumberValue(leaderstats, "Strength", strength)
	strengthValue.Value = strength

	local oldSpeed = leaderstats:FindFirstChild("Speed")
	if oldSpeed and oldSpeed:IsA("ValueBase") then
		oldSpeed.Value = strength
	end

	local oldSpeedPower = leaderstats:FindFirstChild("SpeedPower")
	if oldSpeedPower and oldSpeedPower:IsA("ValueBase") then
		oldSpeedPower.Value = strength
	end

	local speedPerTrain = tonumber(player:GetAttribute("SpeedPerTrain"))
		or tonumber(player:GetAttribute("StrengthPerTrain"))
		or AUTO_BASE_GAIN

	updateSpeedStats:FireClient(player, {
		strength = strength,
		speedPower = strength,
		walkSpeed = walkSpeed,
		speedPerTrain = speedPerTrain,
		strengthPerTrain = speedPerTrain,
	})

	return strength
end

local function isTrainingTool(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	if tool:GetAttribute("TrainingTool") == true then
		return true
	end

	if tool:GetAttribute("TrainingWeightTool") == true then
		return true
	end

	if tool:GetAttribute("WeightTrainingTool") == true then
		return true
	end

	if tool:GetAttribute("IsTrainingTool") == true then
		return true
	end

	if tool:GetAttribute("ToolType") == "Weight" then
		return true
	end

	if tool:GetAttribute("ToolType") == "TrainingWeight" then
		return true
	end

	if tool:GetAttribute("ItemType") == "Weight" then
		return true
	end

	local lowerName = string.lower(tool.Name)

	for _, keyword in ipairs(TRAINING_TOOL_KEYWORDS) do
		if string.find(lowerName, keyword) then
			return true
		end
	end

	return false
end

local function getEquippedTrainingTool(player)
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if isTrainingTool(child) then
			return child
		end
	end

	return nil
end

local function isTraining(player)
	local state = trainingStates[player]
	return state ~= nil and state.active == true
end

local function freezeCharacter(player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.Jump = false

	if humanoid.UseJumpPower then
		humanoid.JumpPower = 0
	else
		humanoid.JumpHeight = 0
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function unfreezeCharacter(player)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local strength = getCurrentStrength(player)
	local walkSpeed = getWalkSpeedFromStrength(strength)

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = walkSpeed
	humanoid.Jump = false

	if humanoid.UseJumpPower then
		humanoid.JumpPower = DEFAULT_JUMP_POWER
	else
		humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
	end

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
	end)
end

local function getAutoGain(player)
	local gain =
		tonumber(player:GetAttribute("StrengthPerTrain"))
		or tonumber(player:GetAttribute("SpeedPerTrain"))
		or AUTO_BASE_GAIN

	return math.max(1, math.floor(gain))
end

local function invokeSpeedServiceAdd(player, gain)
	local done = false
	local success = false
	local result = nil

	task.spawn(function()
		success, result = pcall(function()
			return addSavedSpeedFunction:Invoke(player, gain, false)
		end)

		done = true
	end)

	local startedAt = os.clock()

	while not done and os.clock() - startedAt < 0.45 do
		task.wait()
	end

	if done and success and typeof(result) == "number" then
		return result
	end

	return nil
end

local function addStrength(player, gain, rewardType, quality)
	gain = math.max(1, math.floor(tonumber(gain) or 1))

	local newTotal = invokeSpeedServiceAdd(player, gain)

	if typeof(newTotal) ~= "number" then
		local current = getCurrentStrength(player)
		newTotal = current + gain
	end

	newTotal = syncStrength(player, newTotal)

	if isTraining(player) then
		freezeCharacter(player)
	end

	rewardRemote:FireClient(player, rewardType, quality or "", gain, newTotal)

	print("[SpeedPower]", player.Name, rewardType, quality or "", "+" .. tostring(gain), "Strength Total:", newTotal)
end

local function saveStrength(player)
	task.spawn(function()
		pcall(function()
			saveSpeedFunction:Invoke(player)
		end)
	end)
end

local function forceStopClient(player, reason)
	player:SetAttribute("WeightTrainingActive", false)
	stateRemote:FireClient(player, false, reason or "Stopped")
end

local function stopTraining(player, reason)
	local state = trainingStates[player]

	if state then
		state.active = false
		trainingStates[player] = nil
	end

	forceStopClient(player, reason or "Stopped")
	unfreezeCharacter(player)
	saveStrength(player)

	print("[SpeedPower]", player.Name, "stopped training:", reason or "Stopped")
end

local function startTraining(player)
	if isTraining(player) then
		return
	end

	local tool = getEquippedTrainingTool(player)

	if not tool then
		warn("[SpeedPower] Start blocked. No training weight equipped:", player.Name)
		forceStopClient(player, "NoWeight")
		unfreezeCharacter(player)
		return
	end

	local state = {
		active = true,
		lastMeterHit = 0,
		startedAt = os.clock(),
	}

	trainingStates[player] = state
	player:SetAttribute("WeightTrainingActive", true)

	freezeCharacter(player)
	stateRemote:FireClient(player, true, "Started")

	print("[SpeedPower]", player.Name, "started weight training with:", tool.Name)

	task.spawn(function()
		while trainingStates[player] == state and state.active do
			task.wait(AUTO_GAIN_INTERVAL)

			if trainingStates[player] ~= state or not state.active then
				break
			end

			if not getEquippedTrainingTool(player) then
				stopTraining(player, "WeightUnequipped")
				break
			end

			addStrength(player, getAutoGain(player), "Auto", "Training")
		end
	end)
end

local function handleMeterHit(player, quality, alpha)
	if not isTraining(player) then
		return
	end

	local state = trainingStates[player]
	if not state then
		return
	end

	local now = os.clock()
	if now - state.lastMeterHit < METER_BONUS_COOLDOWN then
		return
	end

	state.lastMeterHit = now

	quality = tostring(quality or "")
	local multiplier = METER_MULTIPLIERS[quality]

	if not multiplier then
		local alphaNumber = tonumber(alpha)
		if alphaNumber then
			if alphaNumber >= 0.66 then
				quality = "Perfect"
				multiplier = METER_MULTIPLIERS.Perfect
			elseif alphaNumber >= 0.43 then
				quality = "Good"
				multiplier = METER_MULTIPLIERS.Good
			elseif alphaNumber >= 0.23 then
				quality = "Average"
				multiplier = METER_MULTIPLIERS.Average
			else
				quality = "Bad"
				multiplier = METER_MULTIPLIERS.Bad
			end
		else
			quality = "Bad"
			multiplier = METER_MULTIPLIERS.Bad
		end
	end

	local baseGain = getAutoGain(player)
	local bonusGain = math.max(1, math.floor(baseGain * multiplier))

	addStrength(player, bonusGain, "Meter", quality)
end

startRemote.OnServerEvent:Connect(function(player)
	startTraining(player)
end)

stopRemote.OnServerEvent:Connect(function(player)
	stopTraining(player, "ClientStopped")
end)

meterRemote.OnServerEvent:Connect(function(player, quality, alpha)
	handleMeterHit(player, quality, alpha)
end)

RunService.Heartbeat:Connect(function()
	for player, state in pairs(trainingStates) do
		if state.active then
			if player:GetAttribute("WeightTrainingActive") ~= true then
				stopTraining(player, "TrainingFlagOff")
			elseif not getEquippedTrainingTool(player) then
				stopTraining(player, "WeightUnequipped")
			else
				freezeCharacter(player)
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("WeightTrainingActive", false)

	task.defer(function()
		syncStrength(player, getCurrentStrength(player))
	end)

	player.CharacterAdded:Connect(function()
		trainingStates[player] = nil
		forceStopClient(player, "CharacterReset")

		task.wait(0.25)
		syncStrength(player, getCurrentStrength(player))
		unfreezeCharacter(player)

		task.wait(1)
		unfreezeCharacter(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveStrength(player)
	trainingStates[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveStrength(player)
	end

	task.wait(1)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player:SetAttribute("WeightTrainingActive", false)
	syncStrength(player, getCurrentStrength(player))
	forceStopClient(player, "ServerReload")
	unfreezeCharacter(player)
end

print("[SpeedPower] Loaded FIXED strength reward + popup sync.")