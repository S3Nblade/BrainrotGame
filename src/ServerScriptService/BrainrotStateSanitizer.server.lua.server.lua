--!nonstrict
-- ServerScriptService/BrainrotStateSanitizer.server.lua
-- Cleans bad capture attributes from inventory tools and placed plot NPCs.
-- This fixes:
-- 1. placed NPC showing "Ready to Pick"
-- 2. Place/Return E prompt becoming unstable
-- 3. old saved broken NPC/tool state

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BAD_CAPTURE_ATTRIBUTES = {
	"CanPickup",
	"CanPickUp",
	"PickupReady",
	"ReadyToPick",
	"ReadyToPickup",
	"ReadyToPickUp",
	"CaptureStunned",
	"Defeated",
	"IsDefeated",
	"Stunned",
	"IsStunned",
	"MutationRevealRunning",
}

local BAD_PROMPT_NAMES = {
	BrainrotCinematicCapturePrompt = true,
	CapturePrompt = true,
	PickupPrompt = true,
	PickUpPrompt = true,
}

local function isBrainrotTool(tool)
	return tool:IsA("Tool")
		and (
			tool:GetAttribute("IsBrainrot") == true
			or tool:GetAttribute("BrainrotTool") == true
			or tool:GetAttribute("InventoryOnly") == true
		)
end

local function isPlacedBrainrot(model)
	if not model:IsA("Model") then
		return false
	end

	if model:GetAttribute("IsPlaced") == true then
		return true
	end

	if model:GetAttribute("Placed") == true then
		return true
	end

	if model:GetAttribute("PlacedOwnerUserId") ~= nil then
		return true
	end

	if model:GetAttribute("AssignedSlotId") ~= nil then
		return true
	end

	if model:GetAttribute("AssignedSlotPath") ~= nil then
		return true
	end

	return false
end

local function isInventoryRecord(model)
	if not model:IsA("Model") then
		return false
	end

	return model:GetAttribute("InventoryOnly") == true
end

local function clearCaptureAttributes(instance)
	for _, attrName in ipairs(BAD_CAPTURE_ATTRIBUTES) do
		if instance:GetAttribute(attrName) ~= nil then
			instance:SetAttribute(attrName, false)
		end
	end
end

local function removeBadCapturePrompts(instance)
	for _, obj in ipairs(instance:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and BAD_PROMPT_NAMES[obj.Name] then
			obj.Enabled = false
			obj:Destroy()
		end
	end
end

local function sanitizeTool(tool)
	if not isBrainrotTool(tool) then
		return
	end

	clearCaptureAttributes(tool)

	tool:SetAttribute("IsBrainrot", true)
	tool:SetAttribute("BrainrotTool", true)
	tool:SetAttribute("InventoryOnly", true)
	tool:SetAttribute("IsPlaced", false)
	tool:SetAttribute("Placed", false)

	tool:SetAttribute("PlacedOwnerUserId", nil)
	tool:SetAttribute("AssignedSlotId", nil)
	tool:SetAttribute("AssignedSlotFloor", nil)
	tool:SetAttribute("AssignedSlotPath", nil)

	-- Tool should not contain world visual clones.
	local visual = tool:FindFirstChild("BrainrotVisual")
	if visual then
		visual:Destroy()
	end

	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj:Destroy()
		end
	end
end

local function sanitizePlacedModel(model)
	if not isPlacedBrainrot(model) and not isInventoryRecord(model) then
		return
	end

	clearCaptureAttributes(model)
	removeBadCapturePrompts(model)

	if isPlacedBrainrot(model) then
		model:SetAttribute("InventoryOnly", false)
		model:SetAttribute("IsPlaced", true)
		model:SetAttribute("Placed", true)
	end
end

local function sanitizePlayer(player)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				sanitizeTool(item)
			end
		end
	end

	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		for _, item in ipairs(starterGear:GetChildren()) do
			if item:IsA("Tool") then
				sanitizeTool(item)
			end
		end
	end

	local character = player.Character
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") then
				sanitizeTool(item)
			end
		end
	end
end

local function sanitizeWorkspace()
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") then
			sanitizePlacedModel(obj)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		sanitizePlayer(player)
	end)

	player.ChildAdded:Connect(function()
		task.wait(0.2)
		sanitizePlayer(player)
	end)

	task.delay(3, function()
		sanitizePlayer(player)
	end)
end)

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			sanitizePlayer(player)
		end

		sanitizeWorkspace()

		task.wait(3)
	end
end)

print("[BrainrotStateSanitizer] Loaded. Cleaning capture attrs from tools/placed NPCs.")