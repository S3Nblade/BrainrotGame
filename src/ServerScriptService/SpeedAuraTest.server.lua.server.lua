local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AURA_TEMPLATE = ReplicatedStorage:WaitForChild("GoldenBrainrotAura")

local BASE_SCALE = 1.0
local MAX_EXTRA_SCALE = 0.55

local BASE_ROTATION_SPEED = 1.4
local EXTRA_ROTATION_FROM_SPEED = 0.12

local HEIGHT_OFFSET = -2.7
local POSITION_LERP_ALPHA = 0.22
local SCALE_LERP_ALPHA = 0.18

local activeAuras = {}

local function prepareAura(aura)
	for _, obj in ipairs(aura:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.Massless = true
			obj.CastShadow = false
			obj.Material = Enum.Material.Neon
			obj.Color = Color3.fromRGB(255, 200, 35)
			obj.Transparency = 0
		elseif obj:IsA("ParticleEmitter") then
			obj.Enabled = true
		elseif obj:IsA("Trail") then
			obj.Enabled = true
		elseif obj:IsA("Beam") then
			obj.Enabled = true
		end
	end
end

local function cleanupCharacterAura(character)
	local record = activeAuras[character]
	if not record then
		return
	end

	if record.Aura then
		record.Aura:Destroy()
	end

	activeAuras[character] = nil
end

local function attachAura(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not hrp or not humanoid then
		return
	end

	cleanupCharacterAura(character)

	local aura = AURA_TEMPLATE:Clone()
	aura.Name = "GoldenBrainrotAura_ACTIVE"
	aura.Parent = workspace

	prepareAura(aura)

	local ok, err = pcall(function()
		aura:ScaleTo(BASE_SCALE)
	end)

	if not ok then
		warn("ScaleTo failed on aura:", err)
	end

	local startCF = hrp.CFrame * CFrame.new(0, HEIGHT_OFFSET, 0)
	aura:PivotTo(startCF)

	activeAuras[character] = {
		Aura = aura,
		Humanoid = humanoid,
		Root = hrp,
		CurrentScale = BASE_SCALE,
		CurrentCFrame = startCF,
		RandomOffset = math.random() * 1000,
	}
end

local function characterAdded(character)
	task.wait(1)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not hrp then
		humanoid = character:WaitForChild("Humanoid", 10)
		hrp = character:WaitForChild("HumanoidRootPart", 10)
	end

	if humanoid and hrp then
		attachAura(character)
	end

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cleanupCharacterAura(character)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(characterAdded)

	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
	player.CharacterAdded:Connect(characterAdded)
end

RunService.Heartbeat:Connect(function(dt)
	local timeNow = os.clock()

	for character, record in pairs(activeAuras) do
		local aura = record.Aura
		local humanoid = record.Humanoid
		local hrp = record.Root

		if not aura or not aura.Parent or not character.Parent or not humanoid or not hrp then
			cleanupCharacterAura(character)
			continue
		end

		local velocity = hrp.AssemblyLinearVelocity
		local planarSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

		local walkSpeed = humanoid.WalkSpeed
		local walkFactor = math.clamp((walkSpeed - 16) / 32, 0, 1.5)
		local moveFactor = math.clamp(planarSpeed / math.max(walkSpeed, 1), 0, 2)

		local rotationSpeed = BASE_ROTATION_SPEED
			+ (walkSpeed * 0.02)
			+ (planarSpeed * EXTRA_ROTATION_FROM_SPEED)

		local pulse = math.sin(timeNow * (4 + planarSpeed * 0.08) + record.RandomOffset) * 0.05

		local targetScale = BASE_SCALE
			+ (walkFactor * 0.18)
			+ (moveFactor * MAX_EXTRA_SCALE * 0.5)
			+ pulse

		targetScale = math.clamp(targetScale, 0.9, BASE_SCALE + MAX_EXTRA_SCALE)

		record.CurrentScale = record.CurrentScale + (targetScale - record.CurrentScale) * SCALE_LERP_ALPHA

		pcall(function()
			aura:ScaleTo(record.CurrentScale)
		end)

		local targetCF =
			hrp.CFrame
			* CFrame.new(0, HEIGHT_OFFSET, 0)
			* CFrame.Angles(0, timeNow * rotationSpeed, 0)

		record.CurrentCFrame = record.CurrentCFrame:Lerp(targetCF, POSITION_LERP_ALPHA)
		aura:PivotTo(record.CurrentCFrame)

		for _, obj in ipairs(aura:GetDescendants()) do
			if obj:IsA("PointLight") then
				obj.Brightness = 1.5 + moveFactor * 2 + walkFactor
				obj.Range = 10 + moveFactor * 6
			elseif obj:IsA("ParticleEmitter") then
				obj.Rate = 8 + moveFactor * 18 + walkFactor * 8
			end
		end
	end
end)