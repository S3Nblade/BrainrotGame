--!nonstrict
-- ServerScriptService/MutationRollService.server.lua
-- Rolls mutation for newly captured Brainrots and applies mutation multipliers.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("MutationConfig"))

local NPC_FOLDER_NAME = "BrainrotNPCs"
local IGNORE_RESTORED_SECONDS = 8

local playerJoinTime = {}
local processed = {}

local function getNpcFolder()
	local folder = Workspace:FindFirstChild(NPC_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = NPC_FOLDER_NAME
		folder.Parent = Workspace
	end

	return folder
end

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function isBrainrotInstance(obj)
	if not obj then
		return false
	end

	if obj:GetAttribute("IsBrainrot") == true
		or obj:GetAttribute("BrainrotTool") == true
		or obj:GetAttribute("BrainrotUID") ~= nil
		or obj:GetAttribute("UID") ~= nil
		or obj:GetAttribute("BrainrotName") ~= nil
		or obj:GetAttribute("CashPerSecond") ~= nil
		or obj:GetAttribute("MPS") ~= nil then
		return true
	end

	return string.find(normalize(obj.Name), "brainrot") ~= nil
end

local function getOwnerPlayer(obj)
	local ownerId =
		obj:GetAttribute("OwnerUserId")
		or obj:GetAttribute("HeldOwnerUserId")
		or obj:GetAttribute("CaughtOwnerUserId")
		or obj:GetAttribute("CapturedByUserId")

	ownerId = tonumber(ownerId)

	if ownerId then
		return Players:GetPlayerByUserId(ownerId)
	end

	local ownerName =
		obj:GetAttribute("OwnerName")
		or obj:GetAttribute("PlayerName")

	if ownerName then
		return Players:FindFirstChild(tostring(ownerName))
	end

	return nil
end

local function isStillLoadingRestoredData(player)
	local joined = playerJoinTime[player.UserId]

	if not joined then
		return false
	end

	return os.clock() - joined < IGNORE_RESTORED_SECONDS
end

local function hasMutation(obj)
	local mutation =
		obj:GetAttribute("Mutation")
		or obj:GetAttribute("MutationName")
		or obj:GetAttribute("ActiveMutation")
		or obj:GetAttribute("MutationType")
		or obj:GetAttribute("CurrentMutation")

	return mutation ~= nil and tostring(mutation) ~= ""
end

local function applyMoneyMultiplier(obj, mutation)
	if not obj or not mutation then
		return
	end

	if obj:GetAttribute("MutationEconomyApplied") == true then
		return
	end

	local oldMps =
		tonumber(obj:GetAttribute("CashPerSecond"))
		or tonumber(obj:GetAttribute("MPS"))
		or tonumber(obj:GetAttribute("MoneyPerSecond"))

	if not oldMps or oldMps <= 0 then
		return
	end

	local newMps = math.max(1, math.floor(oldMps * mutation.MoneyMultiplier))

	obj:SetAttribute("BaseCashPerSecondBeforeMutation", oldMps)
	obj:SetAttribute("CashPerSecond", newMps)
	obj:SetAttribute("MPS", newMps)
	obj:SetAttribute("MoneyPerSecond", newMps)
	obj:SetAttribute("MutationEconomyApplied", true)
end

local function rollMutationFor(obj, force)
	if not obj or processed[obj] then
		return
	end

	if not isBrainrotInstance(obj) then
		return
	end

	local player = getOwnerPlayer(obj)

	if not player and not force then
		return
	end

	if player and not force and isStillLoadingRestoredData(player) then
		return
	end

	if hasMutation(obj) then
		processed[obj] = true
		return
	end

	processed[obj] = true

	local mutation = MutationConfig.Roll()

	MutationConfig.ApplyAttributes(obj, mutation)
	applyMoneyMultiplier(obj, mutation)

	print("[MutationRollService] Rolled", mutation.Name, "for", obj:GetFullName())
end

local function watchModel(model)
	if not model:IsA("Model") then
		return
	end

	for _, attr in ipairs({
		"OwnerUserId",
		"HeldOwnerUserId",
		"CaughtOwnerUserId",
		"CapturedByUserId",
		"OwnerName",
		"InventoryOnly",
		"CashPerSecond",
		"MPS",
		"BrainrotUID",
		"UID",
	}) do
		model:GetAttributeChangedSignal(attr):Connect(function()
			task.delay(0.1, function()
				if model.Parent then
					rollMutationFor(model, false)
				end
			end)
		end)
	end

	task.delay(0.2, function()
		if model.Parent then
			rollMutationFor(model, false)
		end
	end)
end

local function watchTool(player, tool)
	if not tool:IsA("Tool") then
		return
	end

	task.delay(0.15, function()
		if tool.Parent == player.Backpack or tool.Parent == player.Character then
			rollMutationFor(tool, false)
		end
	end)

	tool.AttributeChanged:Connect(function()
		task.delay(0.1, function()
			if tool.Parent == player.Backpack or tool.Parent == player.Character then
				rollMutationFor(tool, false)
			end
		end)
	end)
end

local function watchPlayer(player)
	playerJoinTime[player.UserId] = os.clock()

	local backpack = player:WaitForChild("Backpack", 20)

	if backpack then
		backpack.ChildAdded:Connect(function(tool)
			watchTool(player, tool)
		end)
	end

	player.CharacterAdded:Connect(function(character)
		character.ChildAdded:Connect(function(tool)
			watchTool(player, tool)
		end)
	end)
end

local npcFolder = getNpcFolder()

npcFolder.ChildAdded:Connect(function(child)
	task.wait(0.1)

	if child:IsA("Model") then
		watchModel(child)
	end
end)

for _, child in ipairs(npcFolder:GetChildren()) do
	if child:IsA("Model") then
		watchModel(child)
	end
end

Players.PlayerAdded:Connect(watchPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(watchPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	playerJoinTime[player.UserId] = nil
end)

print("[MutationRollService] Loaded.")
