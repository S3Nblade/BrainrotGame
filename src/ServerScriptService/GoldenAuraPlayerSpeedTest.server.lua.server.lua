local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TEXTURES = {
	SoftGlow = "rbxassetid://89264740074171",
	FlameWisp = "rbxassetid://109158324213433",
	SparkStar = "rbxassetid://98092293773840",
	GroundRing = "rbxassetid://81027883840216",
	SwirlCrescent = "rbxassetid://72595632584957",
	FlameFlipbook = "rbxassetid://116719618296328",
}

local AURA_NAME = "GoldenBrainrotAura_IMAGE_ACTIVE"
local TEMPLATE_NAME = "GoldenBrainrotAura_ImageTemplate"

local BASE_RADIUS = 5.4
local GROUND_OFFSET_Y = -2.85
local BILLBOARD_OFFSET_Y = 0.4

local BASE_ROTATION_SPEED = 75
local SPEED_ROTATION_MULTIPLIER = 4.5
local PULSE_SPEED = 3.2

local active = {}

local function createInvisiblePart(name, size, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function makeSurfaceImage(part, image, name)
	local gui = Instance.new("SurfaceGui")
	gui.Name = name .. "SurfaceGui"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 3
	gui.AlwaysOnTop = false
	gui.CanvasSize = Vector2.new(1024, 1024)
	gui.Parent = part

	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageColor3 = Color3.fromRGB(255, 220, 55)
	img.ImageTransparency = 0.03
	img.Parent = gui

	return img
end

local function makeBillboardImage(part, image, name, size, transparency)
	local gui = Instance.new("BillboardGui")
	gui.Name = name .. "BillboardGui"
	gui.Adornee = part
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Brightness = 3
	gui.Size = UDim2.fromScale(size, size)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.2, 0)
	gui.Parent = part

	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageColor3 = Color3.fromRGB(255, 220, 65)
	img.ImageTransparency = transparency
	img.Parent = gui

	return img
end

local function makeParticleEmitter(parent, name, texture)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = texture
	emitter.Enabled = true
	emitter.LockedToPart = false
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Parent = parent
	return emitter
end

local function safeSet(object, property, value)
	pcall(function()
		object[property] = value
	end)
end

local function createTemplate()
	local old = ReplicatedStorage:FindFirstChild(TEMPLATE_NAME)
	if old then
		old:Destroy()
	end

	local template = Instance.new("Model")
	template.Name = TEMPLATE_NAME
	template.Parent = ReplicatedStorage

	local center = createInvisiblePart("AuraCenter", Vector3.new(0.5, 0.5, 0.5), template)
	template.PrimaryPart = center

	local groundRing = createInvisiblePart("GroundRing", Vector3.new(BASE_RADIUS, 0.05, BASE_RADIUS), template)
	local billboardCore = createInvisiblePart("BillboardCore", Vector3.new(0.5, 0.5, 0.5), template)

	local centerAttachment = Instance.new("Attachment")
	centerAttachment.Name = "CenterAttachment"
	centerAttachment.Parent = center

	local lowAttachment = Instance.new("Attachment")
	lowAttachment.Name = "LowFlameAttachment"
	lowAttachment.Position = Vector3.new(0, -1.25, 0)
	lowAttachment.Parent = center

	makeSurfaceImage(groundRing, TEXTURES.GroundRing, "GroundRingImage")
	makeBillboardImage(billboardCore, TEXTURES.SoftGlow, "SoftCoreGlow", 5.8, 0.16)
	makeBillboardImage(billboardCore, TEXTURES.SwirlCrescent, "SwirlCrescent", 4.9, 0.08)

	local flame = makeParticleEmitter(lowAttachment, "GoldenFlameWisps", TEXTURES.FlameWisp)
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 130)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 198, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 118, 0)),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.65, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(0.35, 1.45),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	flame.Rate = 55
	flame.Lifetime = NumberRange.new(0.55, 0.95)
	flame.Speed = NumberRange.new(0.7, 2.1)
	flame.Drag = 3
	flame.SpreadAngle = Vector2.new(360, 360)
	flame.Rotation = NumberRange.new(0, 360)
	flame.RotSpeed = NumberRange.new(-130, 130)
	flame.EmissionDirection = Enum.NormalId.Top
	safeSet(flame, "Shape", Enum.ParticleEmitterShape.Disc)
	safeSet(flame, "ShapeInOut", Enum.ParticleEmitterShapeInOut.Outward)
	safeSet(flame, "ShapeStyle", Enum.ParticleEmitterShapeStyle.Surface)

	local sparks = makeParticleEmitter(centerAttachment, "GoldenSparkStars", TEXTURES.SparkStar)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 95), Color3.fromRGB(255, 255, 220))
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.65, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.3, 0.42),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparks.Rate = 30
	sparks.Lifetime = NumberRange.new(0.45, 0.85)
	sparks.Speed = NumberRange.new(1.5, 4.5)
	sparks.Drag = 1.8
	sparks.SpreadAngle = Vector2.new(360, 360)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-240, 240)

	local swirls = makeParticleEmitter(centerAttachment, "GoldenCrescentSwirls", TEXTURES.SwirlCrescent)
	swirls.Color = ColorSequence.new(Color3.fromRGB(255, 215, 35), Color3.fromRGB(255, 255, 160))
	swirls.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.25, 0.08),
		NumberSequenceKeypoint.new(1, 1),
	})
	swirls.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(0.55, 2.3),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	swirls.Rate = 9
	swirls.Lifetime = NumberRange.new(0.7, 1.1)
	swirls.Speed = NumberRange.new(0.2, 0.9)
	swirls.Drag = 2
	swirls.SpreadAngle = Vector2.new(360, 360)
	swirls.Rotation = NumberRange.new(0, 360)
	swirls.RotSpeed = NumberRange.new(80, 180)

	local flip = makeParticleEmitter(lowAttachment, "GoldenFlipbookFlame", TEXTURES.FlameFlipbook)
	flip.Color = ColorSequence.new(Color3.fromRGB(255, 210, 55), Color3.fromRGB(255, 255, 190))
	flip.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	flip.Size = NumberSequence.new(1.2, 0.25)
	flip.Rate = 16
	flip.Lifetime = NumberRange.new(0.55, 0.8)
	flip.Speed = NumberRange.new(0.5, 1.5)
	flip.SpreadAngle = Vector2.new(360, 360)
	flip.Rotation = NumberRange.new(0, 360)
	flip.RotSpeed = NumberRange.new(-80, 80)
	safeSet(flip, "FlipbookLayout", Enum.ParticleFlipbookLayout.Grid4x4)
	safeSet(flip, "FlipbookMode", Enum.ParticleFlipbookMode.Loop)
	safeSet(flip, "FlipbookFramerate", NumberRange.new(18, 24))

	local light = Instance.new("PointLight")
	light.Name = "GoldenAuraLight"
	light.Color = Color3.fromRGB(255, 197, 42)
	light.Brightness = 2.2
	light.Range = 11
	light.Shadows = false
	light.Parent = center

	return template
end

local template = createTemplate()
print("[GoldenAura] Image aura template created:", template:GetFullName())

local function getRoot(character)
	return character:FindFirstChild("HumanoidRootPart")
end

local function prepareAura(aura)
	for _, obj in ipairs(aura:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.CastShadow = false
		elseif obj:IsA("ParticleEmitter") then
			obj.Enabled = true
		end
	end
end

local function attachToCharacter(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)

	if not root or not humanoid then
		return
	end

	if active[character] then
		active[character].Aura:Destroy()
		active[character] = nil
	end

	local aura = template:Clone()
	aura.Name = AURA_NAME
	aura.Parent = Workspace
	prepareAura(aura)

	local parts = {
		Center = aura:FindFirstChild("AuraCenter"),
		GroundRing = aura:FindFirstChild("GroundRing"),
		BillboardCore = aura:FindFirstChild("BillboardCore"),
	}

	local images = {
		Ring = nil,
		Swirl = nil,
		Glow = nil,
	}

	if parts.GroundRing then
		local gui = parts.GroundRing:FindFirstChild("GroundRingImageSurfaceGui")
		images.Ring = gui and gui:FindFirstChild("GroundRingImage")
	end

	if parts.BillboardCore then
		for _, child in ipairs(parts.BillboardCore:GetDescendants()) do
			if child:IsA("ImageLabel") and child.Name == "SwirlCrescent" then
				images.Swirl = child
			elseif child:IsA("ImageLabel") and child.Name == "SoftCoreGlow" then
				images.Glow = child
			end
		end
	end

	active[character] = {
		Aura = aura,
		Root = root,
		Humanoid = humanoid,
		Parts = parts,
		Images = images,
		RandomOffset = math.random() * 1000,
	}

	print("[GoldenAura] Image aura attached to player:", character.Name)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		attachToCharacter(character)
	end)

	if player.Character then
		task.wait(1)
		attachToCharacter(player.Character)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		task.spawn(function()
			task.wait(1)
			attachToCharacter(player.Character)
		end)
	end

	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		attachToCharacter(character)
	end)
end

RunService.Heartbeat:Connect(function()
	local timeNow = os.clock()

	for character, data in pairs(active) do
		local aura = data.Aura
		local root = data.Root
		local humanoid = data.Humanoid
		local parts = data.Parts
		local images = data.Images

		if not character.Parent or not aura.Parent or not root.Parent then
			if aura then
				aura:Destroy()
			end
			active[character] = nil
			continue
		end

		local velocity = root.AssemblyLinearVelocity
		local planarSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local speedFactor = math.clamp(planarSpeed / 32, 0, 2)

		local rotationSpeed = BASE_ROTATION_SPEED + speedFactor * SPEED_ROTATION_MULTIPLIER * 20
		local rot = math.rad((timeNow * rotationSpeed) % 360)

		local pulse = 1 + math.sin(timeNow * (PULSE_SPEED + speedFactor * 1.8) + data.RandomOffset) * (0.055 + speedFactor * 0.025)
		local radius = BASE_RADIUS * (1 + speedFactor * 0.18) * pulse

		if parts.Center then
			parts.Center.CFrame = root.CFrame
		end

		if parts.BillboardCore then
			parts.BillboardCore.CFrame = root.CFrame * CFrame.new(0, BILLBOARD_OFFSET_Y, 0)
		end

		if parts.GroundRing then
			parts.GroundRing.Size = Vector3.new(radius, 0.05, radius)
			parts.GroundRing.CFrame =
				CFrame.new(root.Position + Vector3.new(0, GROUND_OFFSET_Y, 0))
				* CFrame.Angles(0, rot, 0)
		end

		if images.Ring and images.Ring:IsA("ImageLabel") then
			images.Ring.Rotation = (timeNow * rotationSpeed) % 360
			images.Ring.ImageTransparency = 0.03 + speedFactor * 0.02
		end

		if images.Swirl and images.Swirl:IsA("ImageLabel") then
			images.Swirl.Rotation = -((timeNow * rotationSpeed * 0.7) % 360)
			local s = 1 + math.sin(timeNow * 2.7) * 0.035 + speedFactor * 0.05
			images.Swirl.Size = UDim2.fromScale(s, s)
		end

		if images.Glow and images.Glow:IsA("ImageLabel") then
			images.Glow.ImageTransparency = 0.14 - math.clamp(speedFactor * 0.035, 0, 0.08)
		end

		for _, obj in ipairs(aura:GetDescendants()) do
			if obj:IsA("ParticleEmitter") then
				if obj.Name == "GoldenFlameWisps" then
					obj.Rate = 55 + speedFactor * 40
				elseif obj.Name == "GoldenSparkStars" then
					obj.Rate = 30 + speedFactor * 35
				elseif obj.Name == "GoldenCrescentSwirls" then
					obj.Rate = 9 + speedFactor * 8
				elseif obj.Name == "GoldenFlipbookFlame" then
					obj.Rate = 16 + speedFactor * 16
				end
			elseif obj:IsA("PointLight") then
				obj.Brightness = 2.2 + speedFactor * 1.8
				obj.Range = 11 + speedFactor * 4
			end
		end
	end
end)