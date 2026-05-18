--!nonstrict
-- StarterPlayerScripts/JumpAuthorityFinal.client.lua
-- Final client-side jump authority.
-- Fixes local scripts leaving jump disabled.
-- Does not create infinite jump.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2

local BAD_STATES = {
	[Enum.HumanoidStateType.Physics] = true,
	[Enum.HumanoidStateType.PlatformStanding] = true,
	[Enum.HumanoidStateType.Ragdoll] = true,
	[Enum.HumanoidStateType.FallingDown] = true,
}

local function fixHumanoid(humanoid)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if humanoid.Sit or humanoid.SeatPart then
		return
	end

	local character = humanoid.Parent
	if not character then
		return
	end

	for _, obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Anchored then
			obj.Anchored = false
		end
	end

	humanoid.PlatformStand = false
	humanoid.AutoRotate = true

	pcall(function()
		humanoid.UseJumpPower = true
	end)

	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
	end)

	if humanoid.WalkSpeed <= 0 then
		humanoid.WalkSpeed = DEFAULT_WALK_SPEED
	end

	if humanoid.JumpPower < 25 then
		humanoid.JumpPower = DEFAULT_JUMP_POWER
	end

	if humanoid.JumpHeight < 4 then
		humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
	end

	local state = humanoid:GetState()
	if BAD_STATES[state] then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

		task.delay(0.05, function()
			if humanoid.Parent and humanoid.Health > 0 and not humanoid.Sit then
				humanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
		end)
	end
end

local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end

	local function repair()
		fixHumanoid(humanoid)
	end

	humanoid:GetPropertyChangedSignal("JumpPower"):Connect(repair)
	humanoid:GetPropertyChangedSignal("JumpHeight"):Connect(repair)
	humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(repair)
	humanoid:GetPropertyChangedSignal("Sit"):Connect(repair)
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(repair)

	RunService.RenderStepped:Connect(function()
		if humanoid.Parent and character.Parent then
			repair()
		end
	end)
end

if player.Character then
	task.spawn(setupCharacter, player.Character)
end

player.CharacterAdded:Connect(setupCharacter)

print("[JumpAuthorityFinalClient] Loaded.")