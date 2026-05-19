
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local hitRemote = ReplicatedStorage:WaitForChild("BoxingFistsSystem"):WaitForChild("Hit")

local DEBUG_FIST_HITBOX = false

local DAMAGE = {
	Jab = 6,
	Cross = 12,
	Hook = 10,
}

local RANGE = {
	Jab = 5.4,
	Cross = 6.1,
	Hook = 5.7,
}

local BOX_SIZE = {
	Jab = Vector3.new(4.2, 4.2, 4.6),
	Cross = Vector3.new(4.6, 4.4, 5.2),
	Hook = Vector3.new(5.2, 4.3, 4.4),
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

local function findTargetModel(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and current:FindFirstChildOfClass("Humanoid") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function hasLineOfSight(character, root, targetRoot)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local direction = targetRoot.Position - root.Position
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 1.4, 0), direction, params)
	if not hit then
		return true
	end

	return hit.Instance:IsDescendantOf(targetRoot.Parent)
end

local function showDebugBox(cframe, size)
	if not DEBUG_FIST_HITBOX then
		return
	end

	local part = Instance.new("Part")
	part.Name = "DebugFistHitbox"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0.72
	part.Color = Color3.fromRGB(255, 80, 80)
	part.Material = Enum.Material.Neon
	part.Size = size
	part.CFrame = cframe
	part.Parent = workspace
	Debris:AddItem(part, 0.18)
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

	local boxSize = BOX_SIZE[punchName] or BOX_SIZE.Jab
	local boxDistance = math.min(RANGE[punchName], boxSize.Z * 0.5 + 2.2)
	local boxCFrame = root.CFrame * CFrame.new(0, 0.6, -boxDistance)
	showDebugBox(boxCFrame, boxSize)

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }

	local parts = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlap)
	local candidates = {}

	for _, part in ipairs(parts) do
		local targetCharacter = findTargetModel(part)
		if targetCharacter and targetCharacter ~= character and not candidates[targetCharacter] then
			local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
			local targetRoot = getRoot(targetCharacter)
			if targetHumanoid and targetHumanoid.Health > 0 and targetRoot then
				local offset = targetRoot.Position - root.Position
				local distance = offset.Magnitude
				local facing = distance > 0 and root.CFrame.LookVector:Dot(offset.Unit) or 0
				if distance <= RANGE[punchName] + 0.75 and facing >= (punchName == "Hook" and -0.05 or 0.15) and hasLineOfSight(character, root, targetRoot) then
					candidates[targetCharacter] = {
						humanoid = targetHumanoid,
						root = targetRoot,
						distance = distance,
					}
				end
			end
		end
	end

	local bestTarget = nil
	local bestDistance = math.huge
	for target, data in pairs(candidates) do
		if data.distance < bestDistance then
			bestTarget = target
			bestDistance = data.distance
		end
	end

	if not bestTarget then
		return
	end

	local data = candidates[bestTarget]
	local eggApi = _G.CleanEggDamageApi
	if eggApi and eggApi.IsEgg and eggApi.IsEgg(bestTarget) then
		eggApi.DamageEgg(player, bestTarget, DAMAGE[punchName])
		return
	end

	data.humanoid:TakeDamage(DAMAGE[punchName])

	if data.root:IsA("BasePart") and not data.root.Anchored then
		data.root.AssemblyLinearVelocity =
			data.root.AssemblyLinearVelocity
			+ root.CFrame.LookVector * KNOCKBACK[punchName]
			+ Vector3.new(0, 5, 0)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastHit[player] = nil
end)

print("[BoxingFistsServer] Loaded clean boxing fist combat.")

