-- ServerScriptService/SpeedAuthority.server.lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BASE_WALK_SPEED = 16
local MAX_WALK_SPEED = 115
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2

local function getTargetWalkSpeed(player)
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

local function enforcePlayerSpeed(player)
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

	local targetWalkSpeed = getTargetWalkSpeed(player)

	if math.abs(humanoid.WalkSpeed - targetWalkSpeed) > 0.05 then
		humanoid.WalkSpeed = targetWalkSpeed
	end

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	humanoid.Jump = false

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

RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		enforcePlayerSpeed(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.3)
		enforcePlayerSpeed(player)

		task.wait(1)
		enforcePlayerSpeed(player)
	end)
end)

print("[SpeedAuthority] Server speed authority loaded.")