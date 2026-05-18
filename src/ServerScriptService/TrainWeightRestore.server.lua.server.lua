--!nonstrict
-- ServerScriptService/TrainingWeightRestore.server.lua
-- Gives every player the Training Weight tool if it is missing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local TOOL_NAMES = {
	"Training Weight",
	"TrainingWeight",
	"Weight",
	"Stone Weight",
}

local function findExistingTemplate()
	local roots = {
		StarterPack,
		ReplicatedStorage,
		ServerStorage,
	}

	for _, root in ipairs(roots) do
		for _, name in ipairs(TOOL_NAMES) do
			local found = root:FindFirstChild(name, true)
			if found and found:IsA("Tool") then
				return found
			end
		end
	end

	return nil
end

local function hasWeightTool(container)
	if not container then
		return false
	end

	for _, obj in ipairs(container:GetChildren()) do
		if obj:IsA("Tool") then
			for _, name in ipairs(TOOL_NAMES) do
				if obj.Name == name then
					return true
				end
			end

			if obj:GetAttribute("TrainingWeightTool") == true
				or obj:GetAttribute("WeightTrainingTool") == true then
				return true
			end
		end
	end

	return false
end

local function createFallbackWeight()
	local tool = Instance.new("Tool")
	tool.Name = "Training Weight"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Train Strength"

	tool:SetAttribute("TrainingWeightTool", true)
	tool:SetAttribute("WeightTrainingTool", true)
	tool:SetAttribute("ToolType", "TrainingWeight")
	tool:SetAttribute("IsTrainingTool", true)

	return tool
end

local function giveWeight(player)
	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 10)
	local starterGear = player:FindFirstChild("StarterGear")

	if not backpack then
		return
	end

	if hasWeightTool(backpack) or hasWeightTool(player.Character) then
		return
	end

	local template = findExistingTemplate()
	local tool = template and template:Clone() or createFallbackWeight()

	tool.Name = "Training Weight"
	tool:SetAttribute("TrainingWeightTool", true)
	tool:SetAttribute("WeightTrainingTool", true)
	tool:SetAttribute("ToolType", "TrainingWeight")
	tool:SetAttribute("IsTrainingTool", true)

	tool.Parent = backpack

	if starterGear and not hasWeightTool(starterGear) then
		local gearTool = tool:Clone()
		gearTool.Parent = starterGear
	end

	print("[TrainingWeightRestore] Gave Training Weight to", player.Name)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		giveWeight(player)
	end)

	task.delay(1, function()
		giveWeight(player)
	end)

	task.delay(3, function()
		giveWeight(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(giveWeight, player)
end

print("[TrainingWeightRestore] loaded.")