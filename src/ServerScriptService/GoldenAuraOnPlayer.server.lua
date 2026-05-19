local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerAuraEnabled = false

if not PlayerAuraEnabled then
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj.Name == "GoldenImageAura_ACTIVE" or obj.Name == "AuraImageID_TEST" then
			obj:Destroy()
		end
	end

	print("[GoldenAuraOnPlayer] Player aura disabled by config.")
	return
end

local TEXTURES = {
	SoftGlow = "rbxassetid://89264740074171",
	FlameWisp = "rbxassetid://109158324213433",
	SparkStar = "rbxassetid://98092293773840",
	GroundRing = "rbxassetid://81027883840216",
	SwirlCrescent = "rbxassetid://72595632584957",
	FlameFlipbook = "rbxassetid://116719618296328",
}

local active = {}

local BASE_RADIUS = 5.5
local GROUND_Y_OFFSET = -2.8
local CORE_Y_OFFSET = 0.5

local function createPart(name, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

local function createGroundRing(part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GroundRingGui"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 5
	gui.CanvasSize = Vector2.new(1024, 1024)
	gui.Parent = part

	local img = Instance.new("ImageLabel")
	img.Name = "GroundRingImage"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEXTURES.GroundRing
	img.ImageColor3 = Color3.fromRGB(255, 220, 45)
	img.ImageTransparency = 0.03
	img.Parent = gui

	return img
end

local function createBillboard(part, name, image, size, transparency)
	local gui = Instance.new("BillboardGui")
	gui.Name = name .. "Gui"
	gui.Adornee = part
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Brightness = 5
	gui.Size = UDim2.fromOffset(size, size)
	gui.Parent = part

	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = image
	img.ImageColor3 = Color3.fromRGB(255, 220, 60)
	img.ImageTransparency = transparency
	img.Parent = gui

	return img
end

local function createEmitter(parent, name, texture)
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

local function setupAura(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then return end

	if active[character] then
		active[character].Model:Destroy()
	end

	local oldTest = workspace:FindFirstChild("AuraImageID_TEST")
	if oldTest then
		oldTest:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "GoldenImageAura_ACTIVE"
	model.Parent = workspace

	local center = createPart("AuraCenter", model)
	local ground = createPart("GroundRing", model)
	local core = createPart("BillboardCore", model)

	ground.Size = Vector3.new(BASE_RADIUS, 0.05, BASE_RADIUS)

	local att = Instance.new("Attachment")
	att.Name = "CenterAttachment"
	att.Parent = center

	local lowAtt = Instance.new("Attachment")
	lowAtt.Name = "LowFlameAttachment"
	lowAtt.Position = Vector3.new(0, -1.2, 0)
	lowAtt.Parent = center

	local ringImage = createGroundRing(ground)
	local glowImage = createBillboard(core, "SoftGlow", TEXTURES.SoftGlow, 520, 0.18)
	local swirlImage = createBillboard(core, "SwirlCrescent", TEXTURES.SwirlCrescent, 470, 0.08)

	local flame = createEmitter(lowAtt, "GoldenFlameWisps", TEXTURES.FlameWisp)
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 120)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 200, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 0)),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.4, 1.45),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	flame.Rate = 65
	flame.Lifetime = NumberRange.new(0.55, 0.95)
	flame.Speed = NumberRange.new(0.8, 2.2)
	flame.Drag = 3
	flame.SpreadAngle = Vector2.new(360, 360)
	flame.Rotation = NumberRange.new(0, 360)
	flame.RotSpeed = NumberRange.new(-160, 160)
	flame.EmissionDirection = Enum.NormalId.Top

	local sparks = createEmitter(att, "GoldenSparkStars", TEXTURES.SparkStar)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 90), Color3.fromRGB(255, 255, 220))
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.35, 0.45),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparks.Rate = 35
	sparks.Lifetime = NumberRange.new(0.45, 0.9)
	sparks.Speed = NumberRange.new(1.5, 4.5)
	sparks.SpreadAngle = Vector2.new(360, 360)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-220, 220)

	local swirls = createEmitter(att, "GoldenCrescentSwirls", TEXTURES.SwirlCrescent)
	swirls.Color = ColorSequence.new(Color3.fromRGB(255, 220, 45), Color3.fromRGB(255, 255, 170))
	swirls.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.3, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	swirls.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(0.5, 2.3),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	swirls.Rate = 10
	swirls.Lifetime = NumberRange.new(0.7, 1.1)
	swirls.Speed = NumberRange.new(0.2, 0.9)
	swirls.SpreadAngle = Vector2.new(360, 360)
	swirls.Rotation = NumberRange.new(0, 360)
	swirls.RotSpeed = NumberRange.new(90, 180)

	local light = Instance.new("PointLight")
	light.Name = "GoldenAuraLight"
	light.Color = Color3.fromRGB(255, 200, 45)
	light.Brightness = 2.2
	light.Range = 12
	light.Shadows = false
	light.Parent = center

	active[character] = {
		Model = model,
		Root = root,
		Center = center,
		Ground = ground,
		Core = core,
		RingImage = ringImage,
		GlowImage = glowImage,
		SwirlImage = swirlImage,
		Flame = flame,
		Sparks = sparks,
		Swirls = swirls,
		Light = light,
	}
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		setupAura(character)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		task.spawn(function()
			task.wait(1)
			setupAura(player.Character)
		end)
	end

	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		setupAura(character)
	end)
end

RunService.Heartbeat:Connect(function()
	local t = os.clock()

	for character, data in pairs(active) do
		if not character.Parent or not data.Root.Parent then
			data.Model:Destroy()
			active[character] = nil
			continue
		end

		local root = data.Root
		local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		local speedFactor = math.clamp(speed / 32, 0, 2)

		local rotSpeed = 90 + speedFactor * 120
		local pulse = 1 + math.sin(t * (3 + speedFactor * 2)) * (0.05 + speedFactor * 0.025)
		local radius = BASE_RADIUS * pulse * (1 + speedFactor * 0.12)

		data.Center.CFrame = root.CFrame
		data.Core.CFrame = root.CFrame * CFrame.new(0, CORE_Y_OFFSET, 0)

		data.Ground.Size = Vector3.new(radius, 0.05, radius)
		data.Ground.CFrame =
			CFrame.new(root.Position + Vector3.new(0, GROUND_Y_OFFSET, 0))
			* CFrame.Angles(0, math.rad(t * rotSpeed), 0)

		data.RingImage.Rotation = (t * rotSpeed) % 360
		data.SwirlImage.Rotation = -((t * rotSpeed * 0.65) % 360)
		data.GlowImage.ImageTransparency = 0.16 - math.clamp(speedFactor * 0.04, 0, 0.09)

		data.Flame.Rate = 65 + speedFactor * 45
		data.Sparks.Rate = 35 + speedFactor * 35
		data.Swirls.Rate = 10 + speedFactor * 8

		data.Light.Brightness = 2.2 + speedFactor * 1.8
		data.Light.Range = 12 + speedFactor * 4
	end
end)
