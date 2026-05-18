--!nonstrict
-- StarterPlayerScripts/MutationAuraCinematic.client.lua
-- Cinematic anime-style mutation aura VFX.
-- Layered VFX:
-- highlight glow
-- animated energy beams
-- orbiting neon energy orbs
-- ground shockwave pulses
-- sparks
-- smoke/fire energy
-- point light
-- distance LOD

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local NPC_FOLDER_NAME = "BrainrotNPCs"
local AURA_FOLDER_NAME = "ClientCinematicMutationAura"

local UPDATE_EVERY = 0.25
local FULL_DISTANCE = 150
local LOW_DISTANCE = 260
local SHOCKWAVE_INTERVAL = 1.15

local TWO_PI = math.pi * 2

local TEXTURES = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
}

local PROFILES = {
	Golden = {
		primary = Color3.fromRGB(255, 220, 45),
		secondary = Color3.fromRGB(255, 130, 25),
		third = Color3.fromRGB(255, 255, 180),
		beams = 5,
		orbs = 18,
		rings = 3,
		particleRate = 32,
		sparkRate = 26,
		beamSpeed = 1.4,
		pulseSpeed = 2.4,
		lightBrightness = 2,
		lightRange = 16,
	},

	Diamond = {
		primary = Color3.fromRGB(75, 230, 255),
		secondary = Color3.fromRGB(230, 255, 255),
		third = Color3.fromRGB(50, 150, 255),
		beams = 5,
		orbs = 16,
		rings = 3,
		particleRate = 26,
		sparkRate = 34,
		beamSpeed = 1.25,
		pulseSpeed = 2.2,
		lightBrightness = 1.9,
		lightRange = 17,
	},

	Rainbow = {
		primary = Color3.fromRGB(255, 80, 220),
		secondary = Color3.fromRGB(80, 255, 150),
		third = Color3.fromRGB(80, 170, 255),
		rainbow = true,
		beams = 7,
		orbs = 24,
		rings = 4,
		particleRate = 42,
		sparkRate = 40,
		beamSpeed = 1.8,
		pulseSpeed = 3.1,
		lightBrightness = 2.4,
		lightRange = 19,
	},

	Shadow = {
		primary = Color3.fromRGB(110, 35, 180),
		secondary = Color3.fromRGB(25, 10, 45),
		third = Color3.fromRGB(190, 90, 255),
		smoke = true,
		beams = 5,
		orbs = 16,
		rings = 3,
		particleRate = 36,
		sparkRate = 14,
		beamSpeed = 0.95,
		pulseSpeed = 2,
		lightBrightness = 1.5,
		lightRange = 16,
	},

	Corrupted = {
		primary = Color3.fromRGB(120, 255, 45),
		secondary = Color3.fromRGB(165, 35, 255),
		third = Color3.fromRGB(35, 20, 45),
		smoke = true,
		beams = 7,
		orbs = 22,
		rings = 4,
		particleRate = 46,
		sparkRate = 28,
		beamSpeed = 1.65,
		pulseSpeed = 3,
		lightBrightness = 2.2,
		lightRange = 18,
	},

	Hacked = {
		primary = Color3.fromRGB(55, 255, 85),
		secondary = Color3.fromRGB(0, 80, 25),
		third = Color3.fromRGB(180, 255, 185),
		beams = 7,
		orbs = 24,
		rings = 3,
		particleRate = 40,
		sparkRate = 48,
		beamSpeed = 2.4,
		pulseSpeed = 4.8,
		lightBrightness = 2.1,
		lightRange = 17,
	},

	Lava = {
		primary = Color3.fromRGB(255, 65, 10),
		secondary = Color3.fromRGB(255, 185, 35),
		third = Color3.fromRGB(90, 5, 0),
		fire = true,
		beams = 6,
		orbs = 20,
		rings = 3,
		particleRate = 44,
		sparkRate = 30,
		beamSpeed = 1.35,
		pulseSpeed = 2.8,
		lightBrightness = 2.5,
		lightRange = 20,
	},

	Frozen = {
		primary = Color3.fromRGB(120, 240, 255),
		secondary = Color3.fromRGB(240, 255, 255),
		third = Color3.fromRGB(70, 130, 255),
		beams = 5,
		orbs = 16,
		rings = 3,
		particleRate = 24,
		sparkRate = 38,
		beamSpeed = 0.95,
		pulseSpeed = 1.9,
		lightBrightness = 1.7,
		lightRange = 16,
	},

	Galaxy = {
		primary = Color3.fromRGB(120, 70, 255),
		secondary = Color3.fromRGB(255, 70, 230),
		third = Color3.fromRGB(35, 10, 90),
		beams = 7,
		orbs = 24,
		rings = 4,
		particleRate = 42,
		sparkRate = 36,
		beamSpeed = 1.55,
		pulseSpeed = 3,
		lightBrightness = 2.3,
		lightRange = 20,
	},

	Toxic = {
		primary = Color3.fromRGB(110, 255, 35),
		secondary = Color3.fromRGB(35, 120, 20),
		third = Color3.fromRGB(200, 255, 75),
		smoke = true,
		beams = 5,
		orbs = 16,
		rings = 3,
		particleRate = 34,
		sparkRate = 16,
		beamSpeed = 1.15,
		pulseSpeed = 2.1,
		lightBrightness = 1.7,
		lightRange = 16,
	},

	Electric = {
		primary = Color3.fromRGB(65, 170, 255),
		secondary = Color3.fromRGB(255, 255, 80),
		third = Color3.fromRGB(220, 250, 255),
		beams = 8,
		orbs = 26,
		rings = 4,
		particleRate = 44,
		sparkRate = 60,
		beamSpeed = 2.8,
		pulseSpeed = 5.5,
		lightBrightness = 2.6,
		lightRange = 20,
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

local activeAuras = {}
local timeNow = 0

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function getAllBaseParts(model)
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

local function getNpcRoot(npc)
	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	local root = npc:FindFirstChild("HumanoidRootPart", true)
	if root and root:IsA("BasePart") then
		return root
	end

	local best = nil
	local bestScore = -math.huge

	for _, part in ipairs(getAllBaseParts(npc)) do
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

local function getNpcSize(npc)
	local ok, _, size = pcall(function()
		return npc:GetBoundingBox()
	end)

	if ok and size then
		return size
	end

	return Vector3.new(4, 4, 4)
end

local function getMutationRaw(npc)
	local mutation =
		npc:GetAttribute("Mutation")
		or npc:GetAttribute("MutationName")
		or npc:GetAttribute("ActiveMutation")
		or npc:GetAttribute("MutationType")
		or npc:GetAttribute("CurrentMutation")

	if mutation and tostring(mutation) ~= "" then
		return tostring(mutation)
	end

	local displayName = tostring(
		npc:GetAttribute("DisplayName")
			or npc:GetAttribute("BrainrotName")
			or npc.Name
			or ""
	)

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

local function hsvColor(offset)
	return Color3.fromHSV((timeNow * 0.12 + offset) % 1, 0.95, 1)
end

local function getProfileColors(profile)
	if not profile.rainbow then
		return profile.primary, profile.secondary, profile.third or profile.primary
	end

	return hsvColor(0), hsvColor(0.33), hsvColor(0.66)
end

local function clearAura(npc)
	local aura = activeAuras[npc]

	if aura and aura.folder then
		aura.folder:Destroy()
	end

	activeAuras[npc] = nil

	local old = npc:FindFirstChild(AURA_FOLDER_NAME)
	if old then
		old:Destroy()
	end
end

local function makeAttachment(root, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position or Vector3.zero
	attachment.Parent = root

	return attachment
end

local function makeHighlight(npc, folder, profile)
	local highlight = Instance.new("Highlight")
	highlight.Name = "CinematicAuraHighlight"
	highlight.Adornee = npc
	highlight.FillColor = profile.primary
	highlight.OutlineColor = profile.secondary
	highlight.FillTransparency = 0.56
	highlight.OutlineTransparency = 0.02
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder

	return highlight
end

local function makeLight(root, folder, profile)
	local light = Instance.new("PointLight")
	light.Name = "CinematicAuraLight"
	light.Color = profile.primary
	light.Brightness = profile.lightBrightness or 2
	light.Range = profile.lightRange or 16
	light.Shadows = false
	light.Parent = root

	local ref = Instance.new("ObjectValue")
	ref.Name = "LightRef"
	ref.Value = light
	ref.Parent = folder

	return light
end

local function makeEmitter(name, attachment, folder, profile, kind, radius)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name

	if kind == "fire" then
		emitter.Texture = TEXTURES.fire
	elseif kind == "smoke" then
		emitter.Texture = TEXTURES.smoke
	else
		emitter.Texture = TEXTURES.spark
	end

	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, profile.primary),
		ColorSequenceKeypoint.new(0.45, profile.third or profile.primary),
		ColorSequenceKeypoint.new(1, profile.secondary),
	})

	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, kind == "smoke" and 0.3 or 0.05),
		NumberSequenceKeypoint.new(0.55, kind == "smoke" and 0.55 or 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})

	if kind == "spark" then
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.035),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Rate = profile.sparkRate or 30
		emitter.Lifetime = NumberRange.new(0.22, 0.5)
		emitter.Speed = NumberRange.new(4, 9)
		emitter.Drag = 0.8
		emitter.LightEmission = 1
	elseif kind == "smoke" then
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.15),
			NumberSequenceKeypoint.new(0.6, radius * 0.45),
			NumberSequenceKeypoint.new(1, radius * 0.05),
		})
		emitter.Rate = profile.particleRate or 28
		emitter.Lifetime = NumberRange.new(0.9, 1.7)
		emitter.Speed = NumberRange.new(0.8, 2.2)
		emitter.Drag = 3
		emitter.LightEmission = 0.25
	else
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.08),
			NumberSequenceKeypoint.new(0.45, radius * 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Rate = profile.particleRate or 32
		emitter.Lifetime = NumberRange.new(0.65, 1.25)
		emitter.Speed = NumberRange.new(1.8, 4.2)
		emitter.Drag = 2.2
		emitter.LightEmission = 0.85
	end

	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-220, 220)
	emitter.LockedToPart = false
	emitter.Parent = attachment

	local ref = Instance.new("ObjectValue")
	ref.Name = name .. "Ref"
	ref.Value = emitter
	ref.Parent = folder

	return emitter
end

local function makeBeam(folder, a0, a1, profile, index)
	local beam = Instance.new("Beam")
	beam.Name = "CinematicEnergyBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.Segments = 18
	beam.Width0 = 0.16
	beam.Width1 = 0.025
	beam.CurveSize0 = 2 + index * 0.2
	beam.CurveSize1 = -2 - index * 0.2
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, profile.primary),
		ColorSequenceKeypoint.new(0.5, profile.third or profile.primary),
		ColorSequenceKeypoint.new(1, profile.secondary),
	})
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.55, 0.05),
		NumberSequenceKeypoint.new(1, 0.65),
	})
	beam.Parent = folder

	return beam
end

local function makeOrb(folder, profile, radius)
	local part = Instance.new("Part")
	part.Name = "CinematicAuraOrb"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = profile.primary
	part.Size = Vector3.new(radius * 0.11, radius * 0.11, radius * 0.11)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 0.08
	part.Parent = folder

	local light = Instance.new("PointLight")
	light.Name = "OrbLight"
	light.Color = part.Color
	light.Brightness = 0.45
	light.Range = radius * 1.3
	light.Shadows = false
	light.Parent = part

	return part
end

local function spawnShockwave(aura)
	if not aura.enabled or aura.lowQuality then
		return
	end

	local profile = aura.profile
	local primary, secondary = getProfileColors(profile)
	local count = 28
	local radiusStart = aura.radius * 0.55
	local radiusEnd = aura.radius * 1.75

	local folder = Instance.new("Folder")
	folder.Name = "CinematicShockwave"
	folder.Parent = aura.folder

	for i = 1, count do
		local part = Instance.new("Part")
		part.Name = "ShockwaveShard"
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Material = Enum.Material.Neon
		part.Color = i % 2 == 0 and primary or secondary
		part.Size = Vector3.new(aura.radius * 0.18, 0.055, aura.radius * 0.045)
		part.Transparency = 0.2
		part.Parent = folder

		local angle = (i / count) * TWO_PI
		local center = aura.root.Position
		local position = center + Vector3.new(math.cos(angle) * radiusStart, -aura.height * 0.43, math.sin(angle) * radiusStart)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))

		part.CFrame = CFrame.lookAt(position, position + tangent)

		task.spawn(function()
			local startTime = os.clock()
			local duration = 0.55

			while part.Parent and os.clock() - startTime < duration do
				local alpha = (os.clock() - startTime) / duration
				local radius = radiusStart + (radiusEnd - radiusStart) * alpha
				local p = center + Vector3.new(math.cos(angle) * radius, -aura.height * 0.43, math.sin(angle) * radius)

				part.CFrame = CFrame.lookAt(p, p + tangent)
				part.Transparency = 0.2 + alpha * 0.8
				part.Size = Vector3.new(aura.radius * (0.22 + alpha * 0.12), 0.05, aura.radius * 0.045)

				RunService.RenderStepped:Wait()
			end

			if part then
				part:Destroy()
			end
		end)
	end

	Debris:AddItem(folder, 0.7)
end

local function createAura(npc, mutation)
	clearAura(npc)

	local profile = PROFILES[mutation]
	if not profile then
		return
	end

	local root = getNpcRoot(npc)
	if not root then
		return
	end

	local size = getNpcSize(npc)
	local radius = math.max(size.X, size.Z, 3.5) * 0.62
	local height = math.max(size.Y, 3.5)

	local folder = Instance.new("Folder")
	folder.Name = AURA_FOLDER_NAME
	folder.Parent = npc

	local centerAttachment = makeAttachment(root, "AuraCenter", Vector3.new(0, height * 0.05, 0))
	local topAttachment = makeAttachment(root, "AuraTop", Vector3.new(0, height * 0.42, 0))
	local bottomAttachment = makeAttachment(root, "AuraBottom", Vector3.new(0, -height * 0.35, 0))

	local highlight = makeHighlight(npc, folder, profile)
	local light = makeLight(root, folder, profile)

	local mainEmitter = makeEmitter(
		"CinematicEnergyParticles",
		centerAttachment,
		folder,
		profile,
		profile.fire and "fire" or profile.smoke and "smoke" or "energy",
		radius
	)

	local sparkEmitter = makeEmitter(
		"CinematicSparks",
		topAttachment,
		folder,
		profile,
		"spark",
		radius
	)

	local lowEmitter = nil

	if profile.smoke or profile.fire then
		lowEmitter = makeEmitter(
			"CinematicLowAura",
			bottomAttachment,
			folder,
			profile,
			profile.fire and "fire" or "smoke",
			radius
		)
	end

	local beamData = {}

	for i = 1, profile.beams do
		local a0 = makeAttachment(root, "BeamA" .. i, Vector3.zero)
		local a1 = makeAttachment(root, "BeamB" .. i, Vector3.zero)
		local beam = makeBeam(folder, a0, a1, profile, i)

		table.insert(beamData, {
			a0 = a0,
			a1 = a1,
			beam = beam,
			offset = i / profile.beams,
			heightOffset = ((i % 3) - 1) * height * 0.18,
		})
	end

	local orbs = {}

	for i = 1, profile.orbs do
		local ringIndex = ((i - 1) % profile.rings) + 1
		local orb = makeOrb(folder, profile, radius)

		table.insert(orbs, {
			part = orb,
			index = i,
			ringIndex = ringIndex,
			radius = radius * (0.78 + ringIndex * 0.18),
			height = -height * 0.22 + ((ringIndex - 1) / math.max(profile.rings - 1, 1)) * height * 0.58,
			baseSize = orb.Size,
		})
	end

	activeAuras[npc] = {
		npc = npc,
		root = root,
		folder = folder,
		mutation = mutation,
		profile = profile,
		radius = radius,
		height = height,
		highlight = highlight,
		light = light,
		mainEmitter = mainEmitter,
		sparkEmitter = sparkEmitter,
		lowEmitter = lowEmitter,
		beams = beamData,
		orbs = orbs,
		enabled = true,
		lowQuality = false,
		startTime = os.clock(),
		lastShockwave = 0,
	}
end

local function refreshNpc(npc)
	if not npc or not npc:IsA("Model") or not npc:IsDescendantOf(Workspace) then
		clearAura(npc)
		return
	end

	local mutation = getMutation(npc)

	if mutation == "Normal" then
		clearAura(npc)
		return
	end

	local active = activeAuras[npc]

	if active and active.mutation == mutation and active.root and active.root.Parent then
		return
	end

	createAura(npc, mutation)
end

local function setAuraEnabled(aura, enabled, lowQuality)
	if aura.enabled == enabled and aura.lowQuality == lowQuality then
		return
	end

	aura.enabled = enabled
	aura.lowQuality = lowQuality

	if aura.highlight then
		aura.highlight.Enabled = enabled
	end

	if aura.light then
		aura.light.Enabled = enabled and not lowQuality
	end

	if aura.mainEmitter then
		aura.mainEmitter.Enabled = enabled
		aura.mainEmitter.Rate = lowQuality and math.floor((aura.profile.particleRate or 32) * 0.25) or (aura.profile.particleRate or 32)
	end

	if aura.sparkEmitter then
		aura.sparkEmitter.Enabled = enabled and not lowQuality
	end

	if aura.lowEmitter then
		aura.lowEmitter.Enabled = enabled and not lowQuality
	end

	for _, data in ipairs(aura.beams) do
		if data.beam then
			data.beam.Enabled = enabled and not lowQuality
		end
	end

	for _, data in ipairs(aura.orbs) do
		if data.part then
			data.part.Transparency = enabled and (lowQuality and 0.72 or 0.08) or 1
		end
	end
end

local function updateDistance()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local camPos = camera.CFrame.Position

	for npc, aura in pairs(activeAuras) do
		if not npc.Parent or not aura.root or not aura.root.Parent then
			clearAura(npc)
		else
			local distance = (aura.root.Position - camPos).Magnitude

			if distance > LOW_DISTANCE then
				setAuraEnabled(aura, false, true)
			elseif distance > FULL_DISTANCE then
				setAuraEnabled(aura, true, true)
			else
				setAuraEnabled(aura, true, false)
			end
		end
	end
end

local function updateAura(aura)
	if not aura.enabled or not aura.root or not aura.root.Parent then
		return
	end

	local profile = aura.profile
	local primary, secondary, third = getProfileColors(profile)

	local elapsed = os.clock() - aura.startTime
	local pulse = 1 + math.sin(elapsed * (profile.pulseSpeed or 3)) * 0.09
	local rootPosition = aura.root.Position

	if aura.highlight then
		aura.highlight.FillColor = primary
		aura.highlight.OutlineColor = secondary
		aura.highlight.FillTransparency = 0.55 + math.sin(elapsed * 2.2) * 0.08
	end

	if aura.light then
		aura.light.Color = primary
		aura.light.Brightness = (profile.lightBrightness or 2) * pulse
	end

	local colorSeq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, primary),
		ColorSequenceKeypoint.new(0.5, third),
		ColorSequenceKeypoint.new(1, secondary),
	})

	if aura.mainEmitter then
		aura.mainEmitter.Color = colorSeq
	end

	if aura.sparkEmitter then
		aura.sparkEmitter.Color = colorSeq
	end

	if aura.lowEmitter then
		aura.lowEmitter.Color = colorSeq
	end

	for _, data in ipairs(aura.beams) do
		local t = elapsed * (profile.beamSpeed or 1.5) + data.offset * TWO_PI
		local r1 = aura.radius * (1.05 + math.sin(t * 1.6) * 0.08)
		local r2 = aura.radius * (0.65 + math.cos(t * 1.3) * 0.08)

		data.a0.Position = Vector3.new(
			math.cos(t) * r1,
			data.heightOffset + math.sin(t * 1.7) * aura.height * 0.28,
			math.sin(t) * r1
		)

		data.a1.Position = Vector3.new(
			math.cos(t + math.pi) * r2,
			-data.heightOffset + math.cos(t * 1.5) * aura.height * 0.32,
			math.sin(t + math.pi) * r2
		)

		if data.beam then
			data.beam.Color = colorSeq
			data.beam.Width0 = aura.lowQuality and 0.08 or 0.16 * pulse
			data.beam.Width1 = aura.lowQuality and 0.02 or 0.035
		end
	end

	for _, data in ipairs(aura.orbs) do
		local direction = data.ringIndex % 2 == 0 and -1 or 1
		local angle = elapsed * (profile.beamSpeed or 1.5) * direction + (data.index / #aura.orbs) * TWO_PI + data.ringIndex
		local bob = math.sin(elapsed * 2.4 + data.index) * aura.height * 0.055

		local radius = data.radius * pulse
		local position = rootPosition + Vector3.new(
			math.cos(angle) * radius,
			data.height + bob,
			math.sin(angle) * radius
		)

		if data.part and data.part.Parent then
			data.part.CFrame = CFrame.new(position)
			data.part.Size = data.baseSize * (0.8 + math.sin(elapsed * 4 + data.index) * 0.18)

			if profile.rainbow then
				data.part.Color = hsvColor(data.index / math.max(#aura.orbs, 1))
			else
				data.part.Color = data.index % 2 == 0 and primary or secondary
			end

			local light = data.part:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = data.part.Color
			end
		end
	end

	if not aura.lowQuality and os.clock() - aura.lastShockwave > SHOCKWAVE_INTERVAL then
		aura.lastShockwave = os.clock()
		spawnShockwave(aura)
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
				refreshNpc(npc)
			end)
		end)
	end

	npc.AncestryChanged:Connect(function(_, parent)
		if not parent then
			clearAura(npc)
		end
	end)

	task.defer(function()
		refreshNpc(npc)
	end)
end

local function scan()
	local folder = getNpcFolder()
	if not folder then
		return
	end

	for _, npc in ipairs(folder:GetChildren()) do
		watchNpc(npc)
	end

	folder.ChildAdded:Connect(function(npc)
		task.wait(0.1)
		watchNpc(npc)
	end)
end

scan()

task.spawn(function()
	while true do
		local folder = getNpcFolder()

		if folder then
			for _, npc in ipairs(folder:GetChildren()) do
				refreshNpc(npc)
			end
		end

		updateDistance()

		task.wait(UPDATE_EVERY)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	timeNow += dt

	for _, aura in pairs(activeAuras) do
		updateAura(aura)
	end
end)

print("[MutationAuraCinematic] Loaded cinematic anime mutation aura VFX.")