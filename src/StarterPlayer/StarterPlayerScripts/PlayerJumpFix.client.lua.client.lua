--!nonstrict
-- StarterPlayerScripts/PlayerJumpFix.client.lua
-- Fixes random "player cannot jump" bug.
-- Keeps jump enabled unless the player is intentionally training/locked.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2

local CHECK_EVERY = 0.15

local function hasLockAttribute(instance)
	if not instance then
		return false
	end

	local lockNames = {
		"Training",
		"IsTraining",
		"TrainingActive",
		"WeightTraining",
		"WeightTrainingActive",
		"MovementLocked",
		"DisableMovement",
		"DisableJump",
		"NoJump",
		"Stunned",
		"Captured",
	}

	for _, name in ipairs(lockNames) do
		if instance:GetAttribute(name) == true then
			return true
		end
	end

	return false
end

local function shouldAllowJump(character, humanoid)
	if not character or not humanoid then
		return false
	end

	if hasLockAttribute(player)
		or hasLockAttribute(character)
		or hasLockAttribute(humanoid) then
		return false
	end

	if humanoid.Sit then
		return false
	end

	if humanoid.SeatPart then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	return true
end

local function fixHumanoid(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if not shouldAllowJump(character, humanoid) then
		return
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end)

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
	end)

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
	end)

	if humanoid.UseJumpPower then
		if humanoid.JumpPower < 10 then
			humanoid.JumpPower = DEFAULT_JUMP_POWER
		end
	else
		if humanoid.JumpHeight < 2 then
			humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
		end
	end

	if humanoid.WalkSpeed <= 0 then
		humanoid.WalkSpeed = DEFAULT_WALK_SPEED
	end
end

local function setupCharacter(character)
	task.wait(0.5)

	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end)

	humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
		task.defer(function()
			fixHumanoid(character)
		end)
	end)

	humanoid:GetPropertyChangedSignal("JumpHeight"):Connect(function()
		task.defer(function()
			fixHumanoid(character)
		end)
	end)

	humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function()
		task.defer(function()
			fixHumanoid(character)
		end)
	end)

	humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
		task.defer(function()
			fixHumanoid(character)
		end)
	end)

	task.spawn(function()
		while character.Parent and humanoid.Parent do
			fixHumanoid(character)
			task.wait(CHECK_EVERY)
		end
	end)
end

if player.Character then
	task.spawn(setupCharacter, player.Character)
end

player.CharacterAdded:Connect(setupCharacter)

print("[PlayerJumpFix] Loaded. Player jump will restore automatically.")