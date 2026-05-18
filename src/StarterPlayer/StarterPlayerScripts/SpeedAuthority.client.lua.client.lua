-- StarterPlayerScripts/SpeedAuthority.client.lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local BASE_WALK_SPEED = 16
local MAX_WALK_SPEED = 115
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2

local currentHumanoid = nil
local walkSpeedConnection = nil

local function getTargetWalkSpeed()
	local attributeWalkSpeed = player:GetAttribute("WalkSpeed")

	if typeof(attributeWalkSpeed) == "number" and attributeWalkSpeed > BASE_WALK_SPEED then
		return math.clamp(attributeWalkSpeed, BASE_WALK_SPEED, MAX_WALK_SPEED)
	end

	local speedPower = player:GetAttribute("SpeedPower") or player:GetAttribute("Speed") or 0

	if typeof(speedPower) ~= "number" then
		speedPower = 0
	end

	return math.clamp(BASE_WALK_SPEED + math.sqrt(math.max(0, speedPower)) * 1.55, BASE_WALK_SPEED, MAX_WALK_SPEED)
end

local function enforceLocalSpeed()
	if player:GetAttribute("WeightTrainingActive") == true then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local targetWalkSpeed = getTargetWalkSpeed()

	if math.abs(humanoid.WalkSpeed - targetWalkSpeed) > 0.05 then
		humanoid.WalkSpeed = targetWalkSpeed
	end

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true

	if humanoid.UseJumpPower then
		if humanoid.JumpPower <= 0 then
			humanoid.JumpPower = DEFAULT_JUMP_POWER
		end
	else
		if humanoid.JumpHeight <= 0 then
			humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
		end
	end

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
	end)
end

local function hookCharacter(character)
	if walkSpeedConnection then
		walkSpeedConnection:Disconnect()
		walkSpeedConnection = nil
	end

	currentHumanoid = character:WaitForChild("Humanoid", 5)

	if currentHumanoid then
		walkSpeedConnection = currentHumanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			task.defer(enforceLocalSpeed)
		end)
	end

	task.wait(0.3)
	enforceLocalSpeed()

	task.wait(1)
	enforceLocalSpeed()
end

if player.Character then
	task.spawn(hookCharacter, player.Character)
end

player.CharacterAdded:Connect(hookCharacter)

RunService.RenderStepped:Connect(function()
	enforceLocalSpeed()
end)

print("[SpeedAuthority] Client speed authority loaded.")