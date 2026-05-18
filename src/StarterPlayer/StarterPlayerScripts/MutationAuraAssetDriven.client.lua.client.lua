--!nonstrict
-- StarterPlayerScripts/MutationSpecialVFX.client.lua
-- Adds unique mutation-specific VFX on top of the main aura system.
-- Keep MutationAuraAssetDriven.client.lua enabled.
-- This script adds:
-- Golden: radiant rings + gold sparks
-- Diamond: ice crystals + clean cyan sparks
-- Rainbow: rainbow orbit rings
-- Shadow: dark smoke + purple tendrils
-- Corrupted: toxic purple/green shards + corruption smoke
-- Hacked: matrix cubes + green lightning
-- Lava: embers + smoke + fire ring
-- Frozen: ice crystals + snow sparks
-- Galaxy: planets/stars orbit + cosmic rings
-- Toxic: green bubbles + poison smoke
-- Electric: fast lightning beams + sparks

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local NPC_FOLDER_NAME = "BrainrotNPCs"
local FX_FOLDER_NAME = "ClientMutationSpecialVFX"
local PREFIX = "MutationSpecialFX_"

local UPDATE_EVERY = 0.3
local FULL_DISTANCE = 160
local LOW_DISTANCE = 260

local TWO_PI = math.pi * 2

local TEXTURES = {
	SoftGlow = "rbxasset://textures/particles/sparkles_main.dds",
	EnergyWisp = "rbxasset://textures/particles/sparkles_main.dds",
	AuraRing = "",
	SharpSpark = "rbxasset://textures/particles/sparkles_main.dds",
	SmokeWisp = "rbxasset://textures/particles/smoke_main.dds",
	LightningWisp = "rbxasset://textures/particles/sparkles_main.dds",
}

local function loadTextureConfig()
	local vfx = ReplicatedStorage:FindFirstChild("VFX")
	local config = vfx and vfx:FindFirstChild("AuraTextureConfig")

	if config and config:IsA("ModuleScript") then
		local ok, result = pcall(require, config)

		if ok and typeof(result) == "table" then
			for key, value in pairs(result) do
				if typeof(value) == "string" and value ~= "" then
					TEXTURES[key] = value
				end
			end
		end
	end
end

loadTextureConfig()

local PROFILES = {
	Golden = {
		primary = Color3.fromRGB(255, 220, 45),
		secondary = Color3.fromRGB(255, 135, 20),
		third = Color3.fromRGB(255, 255, 190),
	},

	Diamond = {
		primary = Color3.fromRGB(90, 235, 255),
		secondary = Color3.fromRGB(235, 255, 255),
		third = Color3.fromRGB(80, 150, 255),
	},

	Rainbow = {
		primary = Color3.fromRGB(255, 80, 220),
		secondary = Color3.fromRGB(80, 255, 150),
		third = Color3.fromRGB(80, 170, 255),
		rainbow = true,
	},

	Shadow = {
		primary = Color3.fromRGB(135, 55, 215),
		secondary = Color3.fromRGB(15, 8, 35),
		third = Color3.fromRGB(205, 95, 255),
	},

	Corrupted = {
		primary = Color3.fromRGB(125, 255, 45),
		secondary = Color3.fromRGB(175, 35, 255),
		third = Color3.fromRGB(35, 20, 45),
	},

	Hacked = {
		primary = Color3.fromRGB(55, 255, 90),
		secondary = Color3.fromRGB(0, 85, 25),
		third = Color3.fromRGB(180, 255, 185),
	},

	Lava = {
		primary = Color3.fromRGB(255, 65, 10),
		secondary = Color3.fromRGB(255, 190, 35),
		third = Color3.fromRGB(100, 8, 0),
	},

	Frozen = {
		primary = Color3.fromRGB(120, 245, 255),
		secondary = Color3.fromRGB(245, 255, 255),
		third = Color3.fromRGB(80, 140, 255),
	},

	Galaxy = {
		primary = Color3.fromRGB(125, 75, 255),
		secondary = Color3.fromRGB(255, 70, 230),
		third = Color3.fromRGB(35, 10, 90),
	},

	Toxic = {
		primary = Color3.fromRGB(115, 255, 35),
		secondary = Color3.fromRGB(35, 120, 20),
		third = Color3.fromRGB(205, 255, 75),
	},

	Electric = {
		primary = Color3.fromRGB(65, 170, 255),
		secondary = Color3.fromRGB(255, 255, 80),
		third = Color3.fromRGB(220, 250, 255),
	},
}

local ALIASES = {
	gold = "Golden",
	golden = "Golden",

	diamond = "Diamond",

	rainbow = "Rainbow",

	shadow = "Shadow",
	dark = "Shadow",

	corrupt = "Corrupted",
	corrupted = "Corrupted",

	hack = "Hacked",
	hacked = "Hacked",
	glitch = "Hacked",
	glitched = "Hacked",

	lava = "Lava",
	fire = "Lava",
	magma = "Lava",

	frozen = "Frozen",
	ice = "Frozen",
	icy = "Frozen",

	galaxy = "Galaxy",
	cosmic = "Galaxy",
	space = "Galaxy",

	toxic = "Toxic",
	nuclear = "Toxic",
	radioactive = "Toxic",

	electric = "Electric",
	lightning = "Electric",
	thunder = "Electric",
}

local active = {}
local watched = {}
local globalTime = 0
local lastScan = 0

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function getAllParts(model)
	local parts = {}

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(parts, obj)
		end
	end

	return parts
end

local function isUtilityPart(part)
	local n = normalize(part.Name)

	return n == "humanoidrootpart"
		or n == "root"
		or n == "hitbox"
		or n == "range"
		or n == "collision"
end

local function getRoot(npc)
	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	local hrp = npc:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	local best = nil
	local bestScore = -math.huge

	for _, part in ipairs(getAllParts(npc)) do
		local score = part.Size.X * part.Size.Y * part.Size.Z

		if not isUtilityPart(part) then
			score += 5000
		end

		if score > bestScore then
			bestScore = score
			best = part
		end
	end

	return best
end

local function getSize(npc)
	local ok, _, size = pcall(function()
		return npc:GetBoundingBox()
	end)

	if ok and size then
		return size
	end

	return Vector3.new(4, 4, 4)
end

local function getMutationRaw(npc)
	local value =
		npc:GetAttribute("Mutation")
		or npc:GetAttribute("MutationName")
		or npc:GetAttribute("ActiveMutation")
		or npc:GetAttribute("MutationType")
		or npc:GetAttribute("CurrentMutation")

	if value and tostring(value) ~= "" then
		return tostring(value)
	end

	local displayName = tostring(npc:GetAttribute("DisplayName") or npc:GetAttribute("BrainrotName") or npc.Name or "")

	for key, canonical in pairs(ALIASES) do
		if string.find(normalize(displayName), key) then
			return canonical
		end
	end

	return "Normal"
end

local function canonicalMutation(raw)
	local n = normalize(raw)

	if n == "" or n == "normal" or n == "none" then
		return "Normal"
	end

	for key, canonical in pairs(ALIASES) do
		if n == key or string.find(n, key) then
			return canonical
		end
	end

	for canonical in pairs(PROFILES) do
		if normalize(canonical) == n then
			return canonical
		end
	end

	return "Normal"
end

local function getMutation(npc)
	return canonicalMutation(getMutationRaw(npc))
end

local function rainbowColor(offset)
	return Color3.fromHSV((globalTime * 0.14 + offset) % 1, 0.95, 1)
end

local function getColors(profile)
	if profile.rainbow then
		return rainbowColor(0), rainbowColor(0.35), rainbowColor(0.7)
	end

	return profile.primary, profile.secondary, profile.third
end

local function clear(npc)
	local fx = active[npc]

	if fx and fx.folder then
		fx.folder:Destroy()
	end

	active[npc] = nil

	if npc then
		local old = npc:FindFirstChild(FX_FOLDER_NAME)
		if old then
			old:Destroy()
		end

		for _, obj in ipairs(npc:GetDescendants()) do
			if string.sub(obj.Name, 1, #PREFIX) == PREFIX then
				obj:Destroy()
			end
		end
	end
end

local function makeAttachment(root, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = PREFIX .. name
	attachment.Position = position or Vector3.zero
	attachment.Parent = root
	return attachment
end

local function makeEmitter(parent, name, textureName, profile, mode, radius)
	local p1, p2, p3 = getColors(profile)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = TEXTURES[textureName] or TEXTURES.SharpSpark
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, p1),
		ColorSequenceKeypoint.new(0.5, p3),
		ColorSequenceKeypoint.new(1, p2),
	})
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-240, 240)
	emitter.LockedToPart = false
	emitter.Parent = parent

	if mode == "spark" then
		emitter.Rate = 38
		emitter.Lifetime = NumberRange.new(0.18, 0.5)
		emitter.Speed = NumberRange.new(5, 11)
		emitter.Drag = 0.7
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.055),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif mode == "smoke" then
		emitter.Rate = 26
		emitter.Lifetime = NumberRange.new(0.9, 1.7)
		emitter.Speed = NumberRange.new(0.4, 1.8)
		emitter.Drag = 4
		emitter.LightEmission = 0.25
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.22),
			NumberSequenceKeypoint.new(0.55, radius * 0.72),
			NumberSequenceKeypoint.new(1, radius * 0.08),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(0.65, 0.62),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif mode == "wisp" then
		emitter.Rate = 30
		emitter.Lifetime = NumberRange.new(0.55, 1.2)
		emitter.Speed = NumberRange.new(1.3, 3.7)
		emitter.Drag = 1.8
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.13),
			NumberSequenceKeypoint.new(0.52, radius * 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.6, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		emitter.Rate = 24
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(0.5, 1.4)
		emitter.Drag = 2.5
		emitter.LightEmission = 0.8
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.28),
			NumberSequenceKeypoint.new(0.45, radius * 0.9),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.12),
			NumberSequenceKeypoint.new(1, 1),
		})
	end

	return emitter
end

local function makeRing(folder, profile, radius, alpha)
	local p1, p2 = getColors(profile)

	local part = Instance.new("Part")
	part.Name = "SpecialAuraRing"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(radius * 2, 0.03, radius * 2)
	part.Parent = folder

	local top = Instance.new("Decal")
	top.Name = "Top"
	top.Texture = TEXTURES.AuraRing
	top.Face = Enum.NormalId.Top
	top.Color3 = p1
	top.Transparency = alpha or 0.15
	top.Parent = part

	local bottom = Instance.new("Decal")
	bottom.Name = "Bottom"
	bottom.Texture = TEXTURES.AuraRing
	bottom.Face = Enum.NormalId.Bottom
	bottom.Color3 = p2
	bottom.Transparency = alpha or 0.15
	bottom.Parent = part

	return {
		part = part,
		top = top,
		bottom = bottom,
		radius = radius,
		alpha = alpha or 0.15,
	}
end

local function makeOrb(folder, profile, radius, sizeScale)
	local p1 = getColors(profile)

	local part = Instance.new("Part")
	part.Name = "SpecialAuraOrb"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = p1
	part.Size = Vector3.new(radius, radius, radius) * (sizeScale or 1)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0.08
	part.Parent = folder

	local light = Instance.new("PointLight")
	light.Color = p1
	light.Brightness = 0.35
	light.Range = radius * 8
	light.Shadows = false
	light.Parent = part

	return part
end

local function makeCube(folder, profile, size)
	local p1 = getColors(profile)

	local part = Instance.new("Part")
	part.Name = "SpecialAuraCube"
	part.Material = Enum.Material.Neon
	part.Color = p1
	part.Size = Vector3.new(size, size, size)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0.12
	part.Parent = folder

	return part
end

local function makeShard(folder, profile, size)
	local p1 = getColors(profile)

	local shard = Instance.new("WedgePart")
	shard.Name = "SpecialAuraShard"
	shard.Material = Enum.Material.Neon
	shard.Color = p1
	shard.Size = Vector3.new(size * 0.45, size, size * 0.28)
	shard.Anchored = true
	shard.CanCollide = false
	shard.CanTouch = false
	shard.CanQuery = false
	shard.Transparency = 0.08
	shard.Parent = folder

	return shard
end

local function makeBeam(folder, root, profile, radius, textureName)
	local a0 = makeAttachment(root, "BeamA", Vector3.zero)
	local a1 = makeAttachment(root, "BeamB", Vector3.zero)

	local p1, p2, p3 = getColors(profile)

	local beam = Instance.new("Beam")
	beam.Name = "SpecialAuraBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = TEXTURES[textureName] or TEXTURES.EnergyWisp
	beam.TextureLength = 1.4
	beam.TextureSpeed = 2
	beam.FaceCamera = true
	beam.Segments = 24
	beam.Width0 = radius * 0.08
	beam.Width1 = radius * 0.015
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.CurveSize0 = 2
	beam.CurveSize1 = -2
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, p1),
		ColorSequenceKeypoint.new(0.5, p3),
		ColorSequenceKeypoint.new(1, p2),
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.5, 0.05),
		NumberSequenceKeypoint.new(1, 0.68),
	})
	beam.Parent = folder

	return {
		a0 = a0,
		a1 = a1,
		beam = beam,
		radius = radius,
	}
end

local function createBase(npc, mutation)
	clear(npc)

	local profile = PROFILES[mutation]
	if not profile then
		return nil
	end

	local root = getRoot(npc)
	if not root then
		return nil
	end

	local size = getSize(npc)
	local radius = math.max(size.X, size.Z, 3.5) * 0.65
	local height = math.max(size.Y, 3.5)

	local folder = Instance.new("Folder")
	folder.Name = FX_FOLDER_NAME
	folder.Parent = npc

	local center = makeAttachment(root, "Center", Vector3.new(0, height * 0.06, 0))
	local top = makeAttachment(root, "Top", Vector3.new(0, height * 0.45, 0))
	local bottom = makeAttachment(root, "Bottom", Vector3.new(0, -height * 0.35, 0))

	local fx = {
		npc = npc,
		root = root,
		folder = folder,
		mutation = mutation,
		profile = profile,
		radius = radius,
		height = height,
		center = center,
		top = top,
		bottom = bottom,
		emitters = {},
		rings = {},
		parts = {},
		beams = {},
		start = os.clock(),
		enabled = true,
		lowQuality = false,
	}

	active[npc] = fx

	return fx
end

local function addOrbitPart(fx, part, kind, index, count, ringIndex, radiusMult, heightAlpha)
	table.insert(fx.parts, {
		part = part,
		kind = kind,
		index = index,
		count = count,
		ringIndex = ringIndex or 1,
		radius = fx.radius * (radiusMult or 1),
		height = -fx.height * 0.22 + (heightAlpha or 0.5) * fx.height * 0.65,
		baseSize = part.Size,
	})
end

local function buildGolden(fx)
	table.insert(fx.emitters, makeEmitter(fx.top, "GoldenSparks", "SharpSpark", fx.profile, "spark", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "GoldenWisps", "EnergyWisp", fx.profile, "wisp", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.25, 0.08))
	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 0.78, 0.12))

	for i = 1, 12 do
		addOrbitPart(fx, makeOrb(fx.folder, fx.profile, fx.radius * 0.12, 1), "goldOrb", i, 12, 1, 1.12, 0.45)
	end

	for i = 1, 4 do
		local beam = makeBeam(fx.folder, fx.root, fx.profile, fx.radius, "EnergyWisp")
		beam.index = i
		beam.count = 4
		table.insert(fx.beams, beam)
	end
end

local function buildDiamond(fx)
	table.insert(fx.emitters, makeEmitter(fx.top, "DiamondSparks", "SharpSpark", fx.profile, "spark", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "DiamondWisps", "EnergyWisp", fx.profile, "wisp", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.15, 0.1))

	for i = 1, 10 do
		addOrbitPart(fx, makeShard(fx.folder, fx.profile, fx.radius * 0.32), "iceShard", i, 10, 1, 1.08, 0.55)
	end
end

local function buildRainbow(fx)
	table.insert(fx.emitters, makeEmitter(fx.center, "RainbowGlow", "SoftGlow", fx.profile, "glow", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "RainbowWisps", "EnergyWisp", fx.profile, "wisp", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.top, "RainbowSparks", "SharpSpark", fx.profile, "spark", fx.radius))

	for i = 1, 3 do
		table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * (0.85 + i * 0.22), 0.1))
	end

	for i = 1, 18 do
		addOrbitPart(fx, makeOrb(fx.folder, fx.profile, fx.radius * 0.1, 1), "rainbowOrb", i, 18, ((i - 1) % 3) + 1, 0.9 + ((i - 1) % 3) * 0.18, (i % 3) / 3)
	end
end

local function buildShadow(fx)
	table.insert(fx.emitters, makeEmitter(fx.bottom, "ShadowSmoke", "SmokeWisp", fx.profile, "smoke", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "ShadowWisps", "SmokeWisp", fx.profile, "wisp", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.2, 0.18))

	for i = 1, 6 do
		local beam = makeBeam(fx.folder, fx.root, fx.profile, fx.radius, "EnergyWisp")
		beam.index = i
		beam.count = 6
		beam.kind = "shadowTendril"
		table.insert(fx.beams, beam)
	end

	for i = 1, 8 do
		addOrbitPart(fx, makeOrb(fx.folder, fx.profile, fx.radius * 0.11, 1.1), "shadowOrb", i, 8, 1, 1.05, 0.5)
	end
end

local function buildCorrupted(fx)
	table.insert(fx.emitters, makeEmitter(fx.bottom, "CorruptSmoke", "SmokeWisp", fx.profile, "smoke", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "CorruptWisps", "EnergyWisp", fx.profile, "wisp", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.top, "CorruptSparks", "SharpSpark", fx.profile, "spark", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.3, 0.12))

	for i = 1, 14 do
		addOrbitPart(fx, makeShard(fx.folder, fx.profile, fx.radius * 0.28), "corruptShard", i, 14, ((i - 1) % 2) + 1, 0.95 + ((i - 1) % 2) * 0.24, (i % 4) / 4)
	end

	for i = 1, 6 do
		addOrbitPart(fx, makeOrb(fx.folder, fx.profile, fx.radius * 0.16, 1), "corruptBubble", i, 6, 1, 0.8, 0.2)
	end
end

local function buildHacked(fx)
	table.insert(fx.emitters, makeEmitter(fx.top, "HackedSparks", "SharpSpark", fx.profile, "spark", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "HackedLightning", "LightningWisp", fx.profile, "wisp", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.15, 0.08))
	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 0.75, 0.16))

	for i = 1, 18 do
		addOrbitPart(fx, makeCube(fx.folder, fx.profile, fx.radius * 0.13), "hackCube", i, 18, ((i - 1) % 3) + 1, 0.85 + ((i - 1) % 3) * 0.17, (i % 3) / 3)
	end

	for i = 1, 7 do
		local beam = makeBeam(fx.folder, fx.root, fx.profile, fx.radius, "LightningWisp")
		beam.index = i
		beam.count = 7
		beam.kind = "electric"
		table.insert(fx.beams, beam)
	end
end

local function buildLava(fx)
	table.insert(fx.emitters, makeEmitter(fx.bottom, "LavaSmoke", "SmokeWisp", fx.profile, "smoke", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "LavaEmbers", "SharpSpark", fx.profile, "spark", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "LavaHeat", "EnergyWisp", fx.profile, "wisp", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.25, 0.08))

	for i = 1, 12 do
		addOrbitPart(fx, makeOrb(fx.folder, fx.profile, fx.radius * 0.13, 1), "lavaEmber", i, 12, 1, 1.05, 0.35)
	end
end

local function buildFrozen(fx)
	table.insert(fx.emitters, makeEmitter(fx.top, "FrozenSnow", "SharpSpark", fx.profile, "spark", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "FrozenWisps", "EnergyWisp", fx.profile, "wisp", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.18, 0.08))

	for i = 1, 12 do
		addOrbitPart(fx, makeShard(fx.folder, fx.profile, fx.radius * 0.3), "frozenCrystal", i, 12, ((i - 1) % 2) + 1, 0.9 + ((i - 1) % 2) * 0.2, (i % 4) / 4)
	end
end

local function buildGalaxy(fx)
	table.insert(fx.emitters, makeEmitter(fx.center, "GalaxyGlow", "SoftGlow", fx.profile, "glow", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "GalaxyWisps", "EnergyWisp", fx.profile, "wisp", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.top, "GalaxyStars", "SharpSpark", fx.profile, "spark", fx.radius))

	for i = 1, 3 do
		table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * (0.9 + i * 0.18), 0.1))
	end

	for i = 1, 20 do
		addOrbitPart(fx, makeOrb(fx.folder, fx.profile, fx.radius * (i % 4 == 0 and 0.16 or 0.09), 1), "galaxyStar", i, 20, ((i - 1) % 3) + 1, 0.8 + ((i - 1) % 3) * 0.22, (i % 5) / 5)
	end
end

local function buildToxic(fx)
	table.insert(fx.emitters, makeEmitter(fx.bottom, "ToxicSmoke", "SmokeWisp", fx.profile, "smoke", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "ToxicWisps", "SmokeWisp", fx.profile, "wisp", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.22, 0.13))

	for i = 1, 14 do
		addOrbitPart(fx, makeOrb(fx.folder, fx.profile, fx.radius * 0.13, 1), "toxicBubble", i, 14, ((i - 1) % 2) + 1, 0.75 + ((i - 1) % 2) * 0.25, (i % 4) / 4)
	end
end

local function buildElectric(fx)
	table.insert(fx.emitters, makeEmitter(fx.top, "ElectricSparks", "SharpSpark", fx.profile, "spark", fx.radius))
	table.insert(fx.emitters, makeEmitter(fx.center, "ElectricLightning", "LightningWisp", fx.profile, "wisp", fx.radius))

	table.insert(fx.rings, makeRing(fx.folder, fx.profile, fx.radius * 1.2, 0.08))

	for i = 1, 8 do
		local beam = makeBeam(fx.folder, fx.root, fx.profile, fx.radius, "LightningWisp")
		beam.index = i
		beam.count = 8
		beam.kind = "electric"
		table.insert(fx.beams, beam)
	end

	for i = 1, 16 do
		addOrbitPart(fx, makeOrb(fx.folder, fx.profile, fx.radius * 0.1, 1), "electricOrb", i, 16, ((i - 1) % 3) + 1, 0.82 + ((i - 1) % 3) * 0.18, (i % 3) / 3)
	end
end

local BUILDERS = {
	Golden = buildGolden,
	Diamond = buildDiamond,
	Rainbow = buildRainbow,
	Shadow = buildShadow,
	Corrupted = buildCorrupted,
	Hacked = buildHacked,
	Lava = buildLava,
	Frozen = buildFrozen,
	Galaxy = buildGalaxy,
	Toxic = buildToxic,
	Electric = buildElectric,
}

local function create(npc, mutation)
	local builder = BUILDERS[mutation]
	if not builder then
		clear(npc)
		return
	end

	local fx = createBase(npc, mutation)
	if not fx then
		return
	end

	builder(fx)
end

local function refresh(npc)
	if not npc or not npc:IsA("Model") or not npc:IsDescendantOf(Workspace) then
		clear(npc)
		return
	end

	local mutation = getMutation(npc)

	if mutation == "Normal" then
		clear(npc)
		return
	end

	local fx = active[npc]

	if fx and fx.mutation == mutation and fx.root and fx.root.Parent then
		return
	end

	create(npc, mutation)
end

local function setFxEnabled(fx, enabled, lowQuality)
	if fx.enabled == enabled and fx.lowQuality == lowQuality then
		return
	end

	fx.enabled = enabled
	fx.lowQuality = lowQuality

	for _, emitter in ipairs(fx.emitters) do
		emitter.Enabled = enabled and not lowQuality
	end

	for _, beam in ipairs(fx.beams) do
		beam.beam.Enabled = enabled and not lowQuality
	end

	for _, data in ipairs(fx.parts) do
		if data.part then
			data.part.Transparency = enabled and (lowQuality and 0.72 or 0.08) or 1
		end
	end

	for _, ring in ipairs(fx.rings) do
		if ring.top then
			ring.top.Transparency = enabled and (lowQuality and 0.65 or ring.alpha) or 1
		end

		if ring.bottom then
			ring.bottom.Transparency = enabled and (lowQuality and 0.65 or ring.alpha) or 1
		end
	end
end

local function updateDistance()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local camPos = camera.CFrame.Position

	for npc, fx in pairs(active) do
		if not npc.Parent or not fx.root or not fx.root.Parent then
			clear(npc)
		else
			local distance = (fx.root.Position - camPos).Magnitude

			if distance > LOW_DISTANCE then
				setFxEnabled(fx, false, true)
			elseif distance > FULL_DISTANCE then
				setFxEnabled(fx, true, true)
			else
				setFxEnabled(fx, true, false)
			end
		end
	end
end

local function updateColors(fx)
	local p1, p2, p3 = getColors(fx.profile)

	local colorSeq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, p1),
		ColorSequenceKeypoint.new(0.5, p3),
		ColorSequenceKeypoint.new(1, p2),
	})

	for _, emitter in ipairs(fx.emitters) do
		emitter.Color = colorSeq
	end

	for _, beam in ipairs(fx.beams) do
		beam.beam.Color = colorSeq
	end

	for _, ring in ipairs(fx.rings) do
		ring.top.Color3 = p1
		ring.bottom.Color3 = p2
	end
end

local function updateRing(fx, ring, i, elapsed)
	local rootPos = fx.root.Position
	local spin = elapsed * (0.7 + i * 0.25)
	local pulse = 1 + math.sin(elapsed * 2 + i) * 0.08
	local size = ring.radius * 2 * pulse

	ring.part.Size = Vector3.new(size, 0.03, size)
	ring.part.CFrame =
		CFrame.new(rootPos + Vector3.new(0, -fx.height * 0.48 + i * fx.height * 0.16, 0))
		* CFrame.Angles(i == 1 and 0 or math.rad(72), spin, math.rad(i * 18))
end

local function updatePart(fx, data, elapsed)
	local p1, p2, p3 = getColors(fx.profile)
	local part = data.part

	if not part or not part.Parent then
		return
	end

	local speed = 1.15

	if data.kind == "hackCube" or data.kind == "electricOrb" then
		speed = 2.8
	elseif data.kind == "shadowOrb" then
		speed = 0.85
	elseif data.kind == "rainbowOrb" or data.kind == "galaxyStar" then
		speed = 1.55
	end

	local direction = data.ringIndex % 2 == 0 and -1 or 1
	local angle = elapsed * speed * direction + (data.index / math.max(data.count, 1)) * TWO_PI + data.ringIndex
	local bob = math.sin(elapsed * 2.5 + data.index) * fx.height * 0.06

	if data.kind == "toxicBubble" or data.kind == "corruptBubble" then
		bob += ((elapsed * 0.35 + data.index * 0.13) % 1) * fx.height * 0.5
	end

	local position = fx.root.Position + Vector3.new(
		math.cos(angle) * data.radius,
		data.height + bob,
		math.sin(angle) * data.radius
	)

	part.CFrame =
		CFrame.new(position)
		* CFrame.Angles(elapsed * speed + data.index, elapsed * 1.3 + data.index, elapsed * 0.8)

	part.Size = data.baseSize * (0.85 + math.sin(elapsed * 4 + data.index) * 0.16)

	if fx.profile.rainbow or data.kind == "rainbowOrb" then
		part.Color = rainbowColor(data.index / math.max(data.count, 1))
	elseif data.index % 3 == 0 then
		part.Color = p3
	elseif data.index % 2 == 0 then
		part.Color = p2
	else
		part.Color = p1
	end

	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = part.Color
	end
end

local function updateBeam(fx, data, elapsed)
	if not data.beam or not data.beam.Enabled then
		return
	end

	local speed = data.kind == "electric" and 3.4 or data.kind == "shadowTendril" and 0.9 or 1.5
	local t = elapsed * speed + (data.index / math.max(data.count, 1)) * TWO_PI
	local r1 = fx.radius * (1.1 + math.sin(t * 1.7) * 0.1)
	local r2 = fx.radius * (0.55 + math.cos(t * 1.3) * 0.1)

	local jitter = 0
	if data.kind == "electric" then
		jitter = math.sin(elapsed * 24 + data.index) * fx.radius * 0.12
	end

	data.a0.Position = Vector3.new(
		math.cos(t) * r1 + jitter,
		math.sin(t * 1.5) * fx.height * 0.32,
		math.sin(t) * r1
	)

	data.a1.Position = Vector3.new(
		math.cos(t + math.pi) * r2 - jitter,
		math.cos(t * 1.4) * fx.height * 0.32,
		math.sin(t + math.pi) * r2
	)
end

local function updateFx(fx)
	if not fx.enabled or not fx.root or not fx.root.Parent then
		return
	end

	local elapsed = os.clock() - fx.start

	updateColors(fx)

	for i, ring in ipairs(fx.rings) do
		updateRing(fx, ring, i, elapsed)
	end

	for _, data in ipairs(fx.parts) do
		updatePart(fx, data, elapsed)
	end

	for _, data in ipairs(fx.beams) do
		updateBeam(fx, data, elapsed)
	end
end

local function watchNpc(npc)
	if not npc:IsA("Model") then
		return
	end

	for _, attr in ipairs({
		"Mutation",
		"MutationName",
		"ActiveMutation",
		"MutationType",
		"CurrentMutation",
		"DisplayName",
		"BrainrotName",
		}) do
		npc:GetAttributeChangedSignal(attr):Connect(function()
			task.defer(function()
				refresh(npc)
			end)
		end)
	end

	npc.AncestryChanged:Connect(function(_, parent)
		if not parent then
			clear(npc)
		end
	end)

	task.defer(function()
		refresh(npc)
	end)
end

local function scan()
	local folder = getNpcFolder()
	if not folder then
		return
	end

	for _, npc in ipairs(folder:GetChildren()) do
		if npc:IsA("Model") and not watched[npc] then
			watched[npc] = true
			watchNpc(npc)
		end
	end
end

local folder = getNpcFolder()
if folder then
	folder.ChildAdded:Connect(function(npc)
		task.wait(0.1)

		if npc:IsA("Model") and not watched[npc] then
			watched[npc] = true
			watchNpc(npc)
		end
	end)
end

scan()

RunService.RenderStepped:Connect(function(dt)
	globalTime += dt

	if os.clock() - lastScan >= UPDATE_EVERY then
		lastScan = os.clock()
		loadTextureConfig()
		scan()

		local npcFolder = getNpcFolder()
		if npcFolder then
			for _, npc in ipairs(npcFolder:GetChildren()) do
				refresh(npc)
			end
		end

		updateDistance()
	end

	for _, fx in pairs(active) do
		updateFx(fx)
	end
end)

print("[MutationSpecialVFX] Loaded unique special VFX for every mutation.")