local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NPC_FOLDERS = {
	"BrainrotNPCs",
	"Brainrots",
	"NPCs",
	"Enemies",
}

local AURA_NAME = "GoldenNPCImageAura_ACTIVE"

local BASE_RADIUS = 5.2
local GROUND_Y_OFFSET = -2.7
local CORE_Y_OFFSET = 0.4

local active = {}

local function getImage(name)
	local obj = ReplicatedStorage:FindFirstChild(name)
	if not obj then
		warn("[GoldenAura] Missing image in ReplicatedStorage:", name)
		return ""
	end

	local ok, value = pcall(function()
		return obj.Texture
	end)

	if ok and typeof(value) == "string" and value ~= "" then
		return value
	end

	ok, value = pcall(function()
		return obj.Image
	end)

	if ok and typeof(value) == "string" and value ~= "" then
		return value
	end

	if obj:IsA("StringValue") then
		return obj.Value
	end

	warn("[GoldenAura] Could not read image from:", obj.Name, obj.ClassName)
	return ""
end

local TEXTURES = {
	SoftGlow = getImage("golden_soft_glow"),
	FlameWisp = getImage("golden_flame_wisp"),
	SparkStar = getImage("golden_spark_star"),
	GroundRing = getImage("golden_ground_ring"),
}

local function isGoldenNPC(model)
	if not model:IsA("Model") then
		return false
	end

	local modelName = string.lower(model.Name)

	if string.find(modelName, "gold") or string.find(modelName, "golden") then
		return true
	end

	for _, key in ipairs({ "Mutation", "Rarity", "Variant", "Skin" }) do
		local attr = model:GetAttribute(key)
		if attr and (string.lower(tostring(attr)) == "golden" or string.lower(tostring(attr)) == "gold") then
			return true
		end

		local valueObj = model:FindFirstChild(key)
		if valueObj and valueObj:IsA("StringValue") then
			local v = string.lower(valueObj.Value)
			if v == "golden" or v == "gold" then
				return true
			end
		end
	end

	return false
end

local function getRootPart(model)
	return model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart
		or model:FindFirstChild("RootPart")
		or model:FindFirstChild("Torso")
		or model:FindFirstChildWhichIsA("BasePart")
end

local function makeInvisiblePart(name, parent)
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

local function makeGroundRing(part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GroundRingSurface"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.CanvasSize = Vector2.new(1024, 1024)

	pcall(function()
		gui.Brightness = 5
	end)

	gui.Parent = part

	local img = Instance.new("ImageLabel")
	img.Name = "GroundRingImage"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = TEXTURES.GroundRing
	img.ImageColor3 = Color3.fromRGB(255, 220, 45)
	img.ImageTransparency = 0.08
	img.Parent = gui

	return img
end

local function makeBillboard(part, name, texture, sizePx, transparency)
	local gui = Instance.new("BillboardGui")
	gui.Name = name .. "Gui"
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(sizePx, sizePx)

	pcall(function()
		gui.Brightness = 5
	end)

	gui.Parent = part

	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = texture
	img.ImageColor3 = Color3.fromRGB(255, 220, 60)
	img.ImageTransparency = transparency
	img.Parent = gui

	return img
end

local function makeEmitter(parent, name, texture)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = texture
	emitter.Enabled = true
	emitter.LockedToPart = false
	emitter.LightEmission = 0.9
	emitter.LightInfluence = 0
	emitter.Parent = parent
	return emitter
end

local function removeAura(npc)
	local data = active[npc]
	if data and data.Model then
		data.Model:Destroy()
	end
	active[npc] = nil
end

local function attachAura(npc)
	if active[npc] then
		return
	end

	local root = getRootPart(npc)
	if not root then
		return
	end

	local model = Instance.new("Model")
	model.Name = AURA_NAME
	model.Parent = Workspace

	local center = makeInvisiblePart("AuraCenter", model)
	local ground = makeInvisiblePart("GroundRing", model)
	local core = makeInvisiblePart("CoreGlow", model)

	ground.Size = Vector3.new(BASE_RADIUS, 0.05, BASE_RADIUS)

	local centerAttachment = Instance.new("Attachment")
	centerAttachment.Name = "CenterAttachment"
	centerAttachment.Parent = center

	local lowAttachment = Instance.new("Attachment")
	lowAttachment.Name = "LowFlameAttachment"
	lowAttachment.Position = Vector3.new(0, -1.15, 0)
	lowAttachment.Parent = center

	local ringImage = makeGroundRing(ground)
	local glowImage = makeBillboard(core, "SoftGlow", TEXTURES.SoftGlow, 330, 0.30)

	local flame = makeEmitter(lowAttachment, "SubtleGoldenFlames", TEXTURES.FlameWisp)
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 235, 110)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 190, 35)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 0)),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.55, 0.42),
		NumberSequenceKeypoint.new(1, 1),
	})
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.45, 0.85),
		NumberSequenceKeypoint.new(1, 0.12),
	})
	flame.Rate = 16
	flame.Lifetime = NumberRange.new(0.55, 0.85)
	flame.Speed = NumberRange.new(0.35, 0.95)
	flame.Drag = 4
	flame.SpreadAngle = Vector2.new(360, 360)
	flame.Rotation = NumberRange.new(0, 360)
	flame.RotSpeed = NumberRange.new(-65, 65)
	flame.EmissionDirection = Enum.NormalId.Top

	pcall(function()
		flame.Shape = Enum.ParticleEmitterShape.Disc
		flame.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		flame.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	end)

	local sparks = makeEmitter(centerAttachment, "SubtleGoldenSparks", TEXTURES.SparkStar)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 230, 85), Color3.fromRGB(255, 255, 210))
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.7, 0.38),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.10),
		NumberSequenceKeypoint.new(0.35, 0.22),
		NumberSequenceKeypoint.new(1, 0.03),
	})
	sparks.Rate = 6
	sparks.Lifetime = NumberRange.new(0.45, 0.75)
	sparks.Speed = NumberRange.new(0.7, 1.8)
	sparks.Drag = 2.5
	sparks.SpreadAngle = Vector2.new(360, 360)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-110, 110)

	local light = Instance.new("PointLight")
	light.Name = "GoldenAuraLight"
	light.Color = Color3.fromRGB(255, 195, 45)
	light.Brightness = 1.4
	light.Range = 9
	light.Shadows = false
	light.Parent = center

	active[npc] = {
		Model = model,
		Root = root,
		Center = center,
		Ground = ground,
		Core = core,
		RingImage = ringImage,
		GlowImage = glowImage,
		Flame = flame,
		Sparks = sparks,
		Light = light,
		RandomOffset = math.random() * 1000,
	}

	print("[GoldenAura] Attached clean aura to NPC:", npc:GetFullName())
end

local function scanNPCs()
	for _, folderName in ipairs(NPC_FOLDERS) do
		local folder = Workspace:FindFirstChild(folderName)

		if folder then
			for _, obj in ipairs(folder:GetDescendants()) do
				if obj:IsA("Model") and isGoldenNPC(obj) then
					attachAura(obj)
				end
			end
		end
	end
end

scanNPCs()

task.spawn(function()
	while true do
		task.wait(2)
		scanNPCs()
	end
end)

RunService.Heartbeat:Connect(function()
	local t = os.clock()

	for npc, data in pairs(active) do
		local root = getRootPart(npc)

		if not npc.Parent or not root then
			removeAura(npc)
			continue
		end

		local speed = root.AssemblyLinearVelocity.Magnitude
		local speedFactor = math.clamp(speed / 24, 0, 1.3)

		local rotSpeed = 38 + speedFactor * 38
		local pulse = 1 + math.sin(t * 2 + data.RandomOffset) * 0.025
		local radius = BASE_RADIUS * pulse * (1 + speedFactor * 0.04)

		data.Center.CFrame = root.CFrame
		data.Core.CFrame = root.CFrame * CFrame.new(0, CORE_Y_OFFSET, 0)

		data.Ground.Size = Vector3.new(radius, 0.05, radius)
		data.Ground.CFrame =
			CFrame.new(root.Position + Vector3.new(0, GROUND_Y_OFFSET, 0))
			* CFrame.Angles(0, math.rad(t * rotSpeed), 0)

		data.RingImage.Rotation = (t * rotSpeed) % 360
		data.RingImage.ImageTransparency = 0.08 - speedFactor * 0.015

		data.GlowImage.Rotation = -((t * rotSpeed * 0.18) % 360)
		data.GlowImage.ImageTransparency = 0.30 - speedFactor * 0.045

		data.Flame.Rate = 16 + speedFactor * 8
		data.Sparks.Rate = 6 + speedFactor * 5

		data.Light.Brightness = 1.4 + speedFactor * 0.5
		data.Light.Range = 9 + speedFactor * 1.5
	end
end)

print("[GoldenAura] GoldenAuraOnNPC loaded.")
