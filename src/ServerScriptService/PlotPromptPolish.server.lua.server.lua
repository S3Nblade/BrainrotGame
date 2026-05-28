--!nonstrict
-- ServerScriptService/PlotPromptPolish.server.lua
-- Makes plot prompts small/simple like the reference.

local Workspace = game:GetService("Workspace")

local FALLBACK_SCAN_SECONDS = 10

local function polishPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then
		return
	end

	if prompt.Name == "BrainrotCoreStandPrompt" then
		prompt.Style = Enum.ProximityPromptStyle.Default
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = 0.18
		prompt.MaxActivationDistance = 10
		prompt.ObjectText = ""

		if string.find(string.lower(prompt.ActionText), "return") then
			prompt.ActionText = "Pickup"
		elseif string.find(string.lower(prompt.ActionText), "place") then
			prompt.ActionText = "Place"
		else
			prompt.ActionText = "Pickup"
		end
	end
end

local function scanPrompts()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			polishPrompt(obj)
		end
	end
end

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("ProximityPrompt") then
		task.defer(polishPrompt, obj)
	end
end)

task.defer(scanPrompts)

task.spawn(function()
	while true do
		task.wait(FALLBACK_SCAN_SECONDS)
		scanPrompts()
	end
end)

print("[PlotPromptPolish] Loaded small simple plot prompt style.")
