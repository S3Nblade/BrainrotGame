-- StarterPlayerScripts/JumpUnstick.client.lua
-- Strong client-side jump restore after weight training.
-- Does not fight training while Training Weight is equipped.
-- Restores jump immediately after unequipping/stopping training.

--!nonstrict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local TRAINING_TOOL_KEYWORDS = {
	"weight",
	"training",
	"dumbbell",
	"barbell",
}

local function isTrainingTool(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	if tool:GetAttribute("TrainingTool") == true then
		return true
	end

	if tool:GetAttribute("ToolType") == "Weight" then
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

local function hasTrainingToolEquipped()
	local character = player.Character
	if not character then
		return false
	end

	for _, child in ipairs(character:GetChildren()) do
		if isTrainingTool(child) then
			return true
		end
	end

	return false
end

local function getRestoredWalkSpeed()
	local speed = player:GetAttribute("WalkSpeed")

	if typeof(speed) == "number" and speed > 0 then
		return speed
	end

	return 16
end

local function restoreJump()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
	end)

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true

	if humanoid.WalkSpeed <= 0 then
		humanoid.WalkSpeed = getRestoredWalkSpeed()
	end

	if humanoid.UseJumpPower then
		humanoid.JumpPower = 50
	else
		humanoid.JumpHeight = 7.2
	end
end

local function forceRestoreForSeconds(seconds)
	local start = os.clock()

	while os.clock() - start < seconds do
		if not hasTrainingToolEquipped() then
			restoreJump()
		end

		RunService.Heartbeat:Wait()
	end
end

local function hookCharacter(character)
	character.ChildRemoved:Connect(function(child)
		if isTrainingTool(child) then
			task.spawn(forceRestoreForSeconds, 2.5)
		end
	end)

	task.spawn(forceRestoreForSeconds, 1.5)
end

if player.Character then
	hookCharacter(player.Character)
end

player.CharacterAdded:Connect(hookCharacter)

task.spawn(function()
	while true do
		task.wait(0.2)

		if not hasTrainingToolEquipped() then
			restoreJump()
		end
	end
end)

print("[JumpUnstick] loaded stronger jump restore")