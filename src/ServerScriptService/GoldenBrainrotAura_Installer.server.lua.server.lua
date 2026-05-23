--[[
Golden Brainrot Aura VFX Installer + Attacher
Put this Script in: ServerScriptService

BEFORE pressing Play:
1) Upload the PNG files from /textures to Roblox as Images.
2) Copy each image asset ID.
3) Replace the PASTE_ID_HERE values below.

This script creates a professional layered aura using:
- SurfaceGui ground ring
- BillboardGui soft glow/swirl cards
- ParticleEmitters for flame/sparks
- Neon light pulse
- Runtime rotation/following for NPCs

It automatically attaches to NPCs that look Golden.
Detection rules:
- Name contains "gold" or "golden"
- Attribute Mutation/Rarity/Variant/Skin equals "Golden"
- StringValue named Mutation/Rarity/Variant/Skin equals "Golden"
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- =========================================================
-- PASTE YOUR UPLOADED ROBLOX IMAGE IDS HERE
-- Example: "rbxassetid://1234567890"
-- =========================================================
local TEXTURES = {
	SoftGlow = "rbxassetid://89264740074171",        -- golden_soft_glow.png
	FlameWisp = "rbxassetid://109158324213433",      -- golden_flame_wisp.png
	SparkStar = "rbxassetid://98092293773840",      -- golden_spark_star.png
	GroundRing = "rbxassetid://81027883840216",    -- golden_ground_ring.png
	SwirlCrescent = "rbxassetid://72595632584957", -- golden_swirl_crescent.png
	FlameFlipbook = "rbxassetid://116719618296328",    -- optional golden_flame_flipbook_4x4.png
}

-- =========================================================
-- SETTINGS
-- =========================================================
local NPC_CONTAINER_NAMES = {
	"BrainrotNPCs",
	"Brainrots",
	"NPCs",
	"Enemies",
}

local AURA_NAME = "GoldenBrainrotAura_ACTIVE"
local TEMPLATE_NAME = "GoldenBrainrotAura_Template"

local AURA_RADIUS_STUDS = 6.0
local GROUND_OFFSET_Y = -2.85
local FOLLOW_HEIGHT_OFFSET = 0
local ROTATION_SPEED = 70 -- degrees per second
local PULSE_SPEED = 2.6

-- =========================================================
-- HELPERS
-- =========================================================
local function isPlaceholder(id: string): boolean
	return id == nil or id == "" or string.find(id, "PASTE_") ~= nil
end

local function safeSet(object: Instance, property: string, value: any)
	pcall(function()
		(object :: any)[property] = value
	end)
end

local function getRootPart(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart
		or model:FindFirstChild("RootPart")
		or model:FindFirstChild("Torso")
		or model:FindFirstChildWhichIsA("BasePart")
end

local function lower(s: any): string
	return string.lower(tostring(s or ""))
end

local function isGoldenBrainrot(model: Instance): boolean
	if not model:IsA("Model") then
		return false
	end

	local name = lower(model.Name)
	if string.find(name, "gold") or string.find(name, "golden") then
		return true
	end

	for _, attributeName in ipairs({ "Mutation", "Rarity", "Variant", "Skin" }) do
		local value = model:GetAttribute(attributeName)
		if lower(value) == "golden" or lower(value) == "gold" then
			return true
		end

		local child = model:FindFirstChild(attributeName)
		if child and child:IsA("StringValue") then
			local v = lower(child.Value)
			if v == "golden" or v == "gold" then
				return true
			end
		end
	end

	return false
end

local function getNpcContainers(): { Instance }
	local result = {}
	for _, containerName in ipairs(NPC_CONTAINER_NAMES) do
		local found = Workspace:FindFirstChild(containerName)
		if found then
			table.insert(result, found)
		end
	end

	-- fallback: scan workspace if no specific folder exists
	if #result == 0 then
		table.insert(result, Workspace)
	end

	return result
end

local function createInvisiblePart(name: string, size: Vector3, parent: Instance): Part
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

local function makeSurfaceImage(part: BasePart, image: string, name: string): ImageLabel
	local gui = Instance.new("SurfaceGui")
	gui.Name = name .. "SurfaceGui"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.AlwaysOnTop = false
	gui.CanvasSize = Vector2.new(1024, 1024)
	gui.Parent = part

	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Position = UDim2.fromScale(0, 0)
	img.Image = image
	img.ImageColor3 = Color3.fromRGB(255, 210, 45)
	img.ImageTransparency = 0.05
	img.Parent = gui
	return img
end

local function makeBillboardImage(part: BasePart, image: string, name: string, size: number, transparency: number): ImageLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = name .. "BillboardGui"
	gui.Adornee = part
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Size = UDim2.fromScale(size, size)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.2, 0)
	gui.Parent = part

	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Position = UDim2.fromScale(0, 0)
	img.Image = image
	img.ImageTransparency = transparency
	img.ImageColor3 = Color3.fromRGB(255, 215, 55)
	img.Parent = gui
	return img
end

local function makeParticleEmitter(parent: Instance, name: string, texture: string): ParticleEmitter
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

-- =========================================================
-- CREATE TEMPLATE
-- =========================================================
local function createTemplate(): Model
	local old = ReplicatedStorage:FindFirstChild(TEMPLATE_NAME)
	if old then
		old:Destroy()
	end

	local template = Instance.new("Model")
	template.Name = TEMPLATE_NAME
	template.Parent = ReplicatedStorage

	local center = createInvisiblePart("AuraCenter", Vector3.new(0.5, 0.5, 0.5), template)
	template.PrimaryPart = center

	local groundRing = createInvisiblePart("GroundRing", Vector3.new(AURA_RADIUS_STUDS, 0.05, AURA_RADIUS_STUDS), template)
	local billboardPart = createInvisiblePart("BillboardCore", Vector3.new(0.5, 0.5, 0.5), template)

	local centerAttachment = Instance.new("Attachment")
	centerAttachment.Name = "CenterAttachment"
	centerAttachment.Parent = center

	local lowAttachment = Instance.new("Attachment")
	lowAttachment.Name = "LowFlameAttachment"
	lowAttachment.Position = Vector3.new(0, -1.2, 0)
	lowAttachment.Parent = center

	-- Ground ring / soft UI cards
	local ringImage = makeSurfaceImage(groundRing, TEXTURES.GroundRing, "GroundRingImage")
	local glowImage = makeBillboardImage(billboardPart, TEXTURES.SoftGlow, "SoftCoreGlow", 5.6, 0.18)
	local swirlImage = makeBillboardImage(billboardPart, TEXTURES.SwirlCrescent, "SwirlCrescent", 4.7, 0.10)

	-- Outer golden flame particles
	local flame = makeParticleEmitter(lowAttachment, "GoldenFlameWisps", TEXTURES.FlameWisp)
	flame.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 120)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 198, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 118, 0)),
	})
	flame.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.10),
		NumberSequenceKeypoint.new(0.65, 0.22),
		NumberSequenceKeypoint.new(1, 1.00),
	})
	flame.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(0.35, 1.35),
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

	-- Spark stars
	local sparks = makeParticleEmitter(centerAttachment, "GoldenSparkStars", TEXTURES.SparkStar)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 95), Color3.fromRGB(255, 255, 220))
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.0),
		NumberSequenceKeypoint.new(0.65, 0.2),
		NumberSequenceKeypoint.new(1, 1.0),
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

	-- Swirl crescent particles
	local swirls = makeParticleEmitter(centerAttachment, "GoldenCrescentSwirls", TEXTURES.SwirlCrescent)
	swirls.Color = ColorSequence.new(Color3.fromRGB(255, 215, 35), Color3.fromRGB(255, 255, 160))
	swirls.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.25, 0.08),
		NumberSequenceKeypoint.new(1, 1.0),
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

	-- Optional flipbook emitter, if you paste that asset id too
	if not isPlaceholder(TEXTURES.FlameFlipbook) then
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
	end

	local light = Instance.new("PointLight")
	light.Name = "GoldenAuraLight"
	light.Color = Color3.fromRGB(255, 197, 42)
	light.Brightness = 2.1
	light.Range = 10
	light.Shadows = false
	light.Parent = center

	template:SetAttribute("CreatedBy", "ChatGPT Golden Brainrot Aura Pack")
	template:SetAttribute("AuraRadiusStuds", AURA_RADIUS_STUDS)

	return template
end

local function warnMissingTextureIds()
	for name, id in pairs(TEXTURES) do
		if name ~= "FlameFlipbook" and isPlaceholder(id) then
			warn("[GoldenAura] Missing texture id for", name, "Upload the PNG and paste its rbxassetid in the script.")
		end
	end
end

warnMissingTextureIds()
local template = createTemplate()
print("[GoldenAura] Template created:", template:GetFullName())

-- =========================================================
-- ATTACHER
-- =========================================================
local active: { [Model]: Model } = {}
local modelParts: { [Model]: { [string]: BasePart } } = {}
local ringImages: { [Model]: ImageLabel } = {}
local swirlImages: { [Model]: ImageLabel } = {}
local glowImages: { [Model]: ImageLabel } = {}

local function prepareAuraModel(aura: Model)
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

local function attachAura(npc: Model)
	if active[npc] then
		return
	end

	local root = getRootPart(npc)
	if not root then
		return
	end

	local aura = template:Clone()
	aura.Name = AURA_NAME
	aura.Parent = Workspace
	prepareAuraModel(aura)
	active[npc] = aura

	modelParts[aura] = {
		Center = aura:FindFirstChild("AuraCenter") :: BasePart,
		GroundRing = aura:FindFirstChild("GroundRing") :: BasePart,
		BillboardCore = aura:FindFirstChild("BillboardCore") :: BasePart,
	}

	local groundRing = modelParts[aura].GroundRing
	if groundRing then
		local surfaceGui = groundRing:FindFirstChild("GroundRingImageSurfaceGui")
		local image = surfaceGui and surfaceGui:FindFirstChild("GroundRingImage")
		if image and image:IsA("ImageLabel") then
			ringImages[aura] = image
		end
	end

	local billboard = modelParts[aura].BillboardCore
	if billboard then
		for _, child in ipairs(billboard:GetDescendants()) do
			if child:IsA("ImageLabel") and child.Name == "SwirlCrescent" then
				swirlImages[aura] = child
			elseif child:IsA("ImageLabel") and child.Name == "SoftCoreGlow" then
				glowImages[aura] = child
			end
		end
	end

	print("[GoldenAura] Attached aura to", npc:GetFullName())
end

local function removeAura(npc: Model)
	local aura = active[npc]
	if aura then
		modelParts[aura] = nil
		ringImages[aura] = nil
		swirlImages[aura] = nil
		glowImages[aura] = nil
		aura:Destroy()
	end
	active[npc] = nil
end

local function scanForGoldenNpcs()
	for _, container in ipairs(getNpcContainers()) do
		for _, descendant in ipairs(container:GetDescendants()) do
			if descendant:IsA("Model") and isGoldenBrainrot(descendant) then
				attachAura(descendant)
			end
		end
	end
end

scanForGoldenNpcs()

task.spawn(function()
	while true do
		task.wait(2)
		scanForGoldenNpcs()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	local timeNow = os.clock()
	local rot = math.rad((timeNow * ROTATION_SPEED) % 360)
	local pulse = 1 + math.sin(timeNow * PULSE_SPEED) * 0.055

	for npc, aura in pairs(active) do
		if not npc.Parent then
			removeAura(npc)
			continue
		end

		local root = getRootPart(npc)
		if not root then
			removeAura(npc)
			continue
		end

		local parts = modelParts[aura]
		if not parts then
			continue
		end

		local centerCF = root.CFrame * CFrame.new(0, FOLLOW_HEIGHT_OFFSET, 0)

		if parts.Center then
			parts.Center.CFrame = centerCF
		end

		if parts.BillboardCore then
			parts.BillboardCore.CFrame = root.CFrame * CFrame.new(0, 0.15, 0)
		end

		if parts.GroundRing then
			parts.GroundRing.Size = Vector3.new(AURA_RADIUS_STUDS * pulse, 0.05, AURA_RADIUS_STUDS * pulse)
			parts.GroundRing.CFrame = CFrame.new(root.Position + Vector3.new(0, GROUND_OFFSET_Y, 0)) * CFrame.Angles(0, rot, 0)
		end

		local ringImg = ringImages[aura]
		if ringImg then
			ringImg.Rotation = (timeNow * ROTATION_SPEED) % 360
			ringImg.ImageTransparency = 0.04 + (1 - pulse) * 0.6
		end

		local swirlImg = swirlImages[aura]
		if swirlImg then
			swirlImg.Rotation = -((timeNow * ROTATION_SPEED * 0.65) % 360)
			local size = 1 + math.sin(timeNow * 2.4) * 0.025
			swirlImg.Size = UDim2.fromScale(size, size)
		end

		local glowImg = glowImages[aura]
		if glowImg then
			glowImg.ImageTransparency = 0.16 + math.sin(timeNow * 3.1) * 0.04
		end
	end
end)
