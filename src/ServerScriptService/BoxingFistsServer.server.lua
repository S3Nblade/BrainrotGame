
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local hitRemote = ReplicatedStorage:WaitForChild("BoxingFistsSystem"):WaitForChild("Hit")

local DAMAGE = {
	Jab = 6,
	Cross = 12,
	Hook = 10,
}

local RANGE = {
	Jab = 5.5,
	Cross = 6.4,
	Hook = 5.8,
}

local KNOCKBACK = {
	Jab = 10,
	Cross = 28,
	Hook = 20,
}

local COOLDOWN = 0.16
local lastHit = {}

local function getRoot(model)
	if not model then
		return nil
	end

	return model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("UpperTorso")
		or model:FindFirstChild("Torso")
		or model:FindFirstChildWhichIsA("BasePart")
end

hitRemote.OnServerEvent:Connect(function(player, punchName)
	if typeof(punchName) ~= "string" then
		return
	end

	if not DAMAGE[punchName] then
		return
	end

	local now = os.clock()

	if lastHit[player] and now - lastHit[player] < COOLDOWN then
		return
	end

	lastHit[player] = now

	local character = player.Character
	if not character then
		return
	end

	if not character:FindFirstChild("Fists") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = getRoot(character)

	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	for _, targetHumanoid in ipairs(workspace:GetDescendants()) do
		if targetHumanoid:IsA("Humanoid") and targetHumanoid ~= humanoid and targetHumanoid.Health > 0 then
			local targetCharacter = targetHumanoid.Parent
			local targetRoot = getRoot(targetCharacter)

			if targetRoot then
				local offset = targetRoot.Position - root.Position
				local distance = offset.Magnitude

				if distance > 0 and distance <= RANGE[punchName] then
					local facing = root.CFrame.LookVector:Dot(offset.Unit)
					local neededFacing = punchName == "Hook" and -0.15 or 0.05

					if facing >= neededFacing then
						local eggApi = _G.CleanEggDamageApi
						if eggApi and eggApi.IsEgg and eggApi.IsEgg(targetCharacter) then
							eggApi.DamageEgg(player, targetCharacter, DAMAGE[punchName])
							continue
						end

						targetHumanoid:TakeDamage(DAMAGE[punchName])

						if targetRoot:IsA("BasePart") and not targetRoot.Anchored then
							targetRoot.AssemblyLinearVelocity =
								targetRoot.AssemblyLinearVelocity
								+ root.CFrame.LookVector * KNOCKBACK[punchName]
								+ Vector3.new(0, 5, 0)
						end
					end
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastHit[player] = nil
end)

print("[BoxingFistsServer] Loaded clean boxing fist combat.")

