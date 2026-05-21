--!nonstrict
-- StarterPlayerScripts/BrainrotCoreClient.client.lua
-- Shows:
-- Place Brainrot only when holding a brainrot tool.
-- Return Brainrot when the slot is occupied.
-- Hides prompts on other players' plots.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local pickupRemote = ReplicatedStorage:WaitForChild("BrainrotCorePickup")

local STAND_PROMPT_NAME = "BrainrotCoreStandPrompt"

local pickupCooldown = false

local BLOCKED_TOOL_NAMES = {
	["Training Weight"] = true,
	["Weight"] = true,
	["Capture Net"] = true,
}

local function getPlotsFolder()
	local direct = Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
	if direct then
		return direct
	end

	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	if spawnMap then
		return spawnMap:FindFirstChild("plots") or spawnMap:FindFirstChild("Plots")
	end

	return nil
end

local function findPlotFromObject(obj)
	local plotsFolder = getPlotsFolder()
	if not plotsFolder then
		return nil
	end

	local current = obj

	while current and current ~= Workspace do
		if current.Parent == plotsFolder then
			return current
		end

		current = current.Parent
	end

	return nil
end

local function playerOwnsPlot(plot)
	if not plot then
		return false
	end

	return tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(plot:GetAttribute("OwnerName")) == player.Name
		or tostring(plot:GetAttribute("Owner")) == player.Name
end

local function getHeldTool()
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end

	return nil
end

local function isBrainrotTool(tool)
	if not tool then
		return false
	end

	if BLOCKED_TOOL_NAMES[tool.Name] then
		return false
	end

	if tool:GetAttribute("IsBrainrot") == true
		or tool:GetAttribute("BrainrotUID") ~= nil
		or tool:GetAttribute("UID") ~= nil
		or tool:GetAttribute("BrainrotUid") ~= nil
		or tool:GetAttribute("DirectInventoryUid") ~= nil
		or tool:GetAttribute("CashPerSecond") ~= nil
		or tool:GetAttribute("MPS") ~= nil
		or tool:GetAttribute("Rarity") ~= nil then
		return true
	end

	return string.find(string.lower(tool.Name), "brainrot") ~= nil
end

local function updatePrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end

	if prompt.Name ~= STAND_PROMPT_NAME then
		return
	end

	local plot = findPlotFromObject(prompt)
	if not playerOwnsPlot(plot) then
		prompt.Enabled = false
		return
	end

	local parent = prompt.Parent
	local occupied =
		parent
		and parent:GetAttribute("BrainrotCoreOccupied") == true
		and tostring(parent:GetAttribute("BrainrotCoreOccupiedOwnerUserId")) == tostring(player.UserId)

	if occupied then
		prompt.Enabled = true
		prompt.ActionText = "Return Brainrot"
		prompt.ObjectText = "Brainrot Stand"
		return
	end

	if isBrainrotTool(getHeldTool()) then
		prompt.Enabled = true
		prompt.ActionText = "Place Brainrot"
		prompt.ObjectText = "Brainrot Stand"
	else
		prompt.Enabled = false
	end
end

local function refreshPrompts()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Name == STAND_PROMPT_NAME then
			updatePrompt(obj)
		end
	end
end

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("ProximityPrompt") and obj.Name == STAND_PROMPT_NAME then
		task.defer(function()
			updatePrompt(obj)
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		if pickupCooldown then
			return
		end

		pickupCooldown = true
		pickupRemote:FireServer()

		task.delay(0.35, function()
			pickupCooldown = false
		end)
	end
end)

task.spawn(function()
	while true do
		refreshPrompts()
		task.wait(0.1)
	end
end)

print("[BrainrotCoreClient] Loaded exact stand prompt filter.")
