--!nonstrict
-- StarterPlayerScripts/BrainrotSlotPromptClient.client.lua
-- FULL REPLACEMENT
-- Fixes: cannot press E to return brainrot.
-- Shows prompt when:
-- 1. It is your plot
-- 2. The stand has Return Brainrot
-- OR
-- 3. You are holding a brainrot tool

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer

local PROMPT_NAME = "BrainrotStandPrompt"
local CHECK_EVERY = 0.15

local BLOCKED_TOOL_NAMES = {
	["Training Weight"] = true,
	["Weight"] = true,
	["Capture Net"] = true,
}

local function getPlotsFolder()
	return Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
end

local function isPlotObject(obj)
	if not obj then
		return false
	end

	if tostring(obj:GetAttribute("OwnerUserId")) ~= "" and obj:GetAttribute("OwnerUserId") ~= nil then
		return true
	end

	if tostring(obj:GetAttribute("OwnerName")) ~= "" and obj:GetAttribute("OwnerName") ~= nil then
		return true
	end

	return false
end

local function findPlotFromPrompt(prompt)
	local plotsFolder = getPlotsFolder()

	if not plotsFolder then
		return nil
	end

	local current = prompt.Parent

	while current and current ~= Workspace do
		if current.Parent == plotsFolder or isPlotObject(current) then
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
		or tool:GetAttribute("BrainrotId") ~= nil
		or tool:GetAttribute("UID") ~= nil
		or tool:GetAttribute("Uuid") ~= nil
		or tool:GetAttribute("CashPerSecond") ~= nil
		or tool:GetAttribute("MPS") ~= nil
		or tool:GetAttribute("Rarity") ~= nil then
		return true
	end

	local lower = string.lower(tool.Name)

	if string.find(lower, "brainrot")
		or string.find(lower, "npc")
		or string.find(lower, "tralal")
		or string.find(lower, "ballerina")
		or string.find(lower, "cappuccina")
		or string.find(lower, "boneca")
		or string.find(lower, "tung")
		or string.find(lower, "sahur")
		or string.find(lower, "bombardino")
		or string.find(lower, "patapim") then
		return true
	end

	return false
end

local function isReturnPrompt(prompt)
	local action = string.lower(tostring(prompt.ActionText or ""))

	return string.find(action, "return") ~= nil
end

local function shouldShowPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return false
	end

	if prompt.Name ~= PROMPT_NAME then
		return true
	end

	local plot = findPlotFromPrompt(prompt)

	if not playerOwnsPlot(plot) then
		return false
	end

	if isReturnPrompt(prompt) then
		return true
	end

	local heldTool = getHeldTool()

	if isBrainrotTool(heldTool) then
		return true
	end

	return false
end

local function updatePrompt(prompt)
	if prompt:IsA("ProximityPrompt") and prompt.Name == PROMPT_NAME then
		prompt.Enabled = shouldShowPrompt(prompt)
	end
end

local function refreshAll()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Name == PROMPT_NAME then
			updatePrompt(obj)
		end
	end
end

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("ProximityPrompt") and obj.Name == PROMPT_NAME then
		task.defer(function()
			updatePrompt(obj)
		end)
	end
end)

ProximityPromptService.PromptShown:Connect(function(prompt)
	updatePrompt(prompt)
end)

task.spawn(function()
	while true do
		refreshAll()
		task.wait(CHECK_EVERY)
	end
end)

print("[BrainrotSlotPromptClient] Loaded. Return prompt is always allowed on your plot.")