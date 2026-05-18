--!nonstrict
-- StarterPlayerScripts/MutationPictureAura.client.lua
-- Picture-style mutation aura VFX.
-- Matches the generated mutation pictures:
-- big soft aura behind NPC, smoky glow, rotating wisps, ground ring, small sparkles.
-- No cubes, no shards, no clutter.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local NPC_FOLDER_NAME = "BrainrotNPCs"
local AURA_FOLDER_NAME = "ClientPictureMutationAura"
local PREFIX = "PictureAura_"

local UPDATE_EVERY = 0.25
local FULL_DISTANCE = 160
local LOW_DISTANCE = 280

local TEXTURES = {
	SoftGlow = "rbxassetid://78966702140597",
	EnergyWisp = "rbxassetid://117976865332104",
	AuraRing = "rbxassetid://86889279331971",
	SharpSpark = "rbxassetid://79005324753736",
	SmokeWisp = "rbxassetid://135490948679927",
	LightningWisp = "rbxassetid://137294646094424",
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
		secondary = Color3.fromRGB(255, 145, 25),
		third = Color3.fromRGB(255, 255, 185),
		wisp = "EnergyWisp",
		sparkRate = 36,
		wispRate = 22,
		glowTransparency = 0.25,
	},

	Diamond = {
		primary = Color3.fromRGB(85, 235, 255),
		secondary = Color3.fromRGB(235, 255, 255),
		third = Color3.fromRGB(70, 155, 255),
		wisp = "EnergyWisp",
		sparkRate = 42,
		wispRate = 18,
		glowTransparency = 0.28,
	},

	Rainbow = {
		primary = Color3.fromRGB(255, 80, 220),
		secondary = Color3.fromRGB(80, 255, 150),
		third = Color3.fromRGB(80, 170, 255),
		rainbow = true,
		wisp = "EnergyWisp",
		sparkRate = 48,
		wispRate = 28,
		glowTransparency = 0.2,
	},

	Shadow = {
		primary = Color3.fromRGB(135, 55, 215),
		secondary = Color3.fromRGB(25, 8, 45),
		third = Color3.fromRGB(210, 105, 255),
		wisp = "SmokeWisp",
		smoke = true,
		sparkRate = 16,
		wispRate = 34,
		glowTransparency = 0.22,
	},

	Corrupted = {
		primary = Color3.fromRGB(125, 255, 45),
		secondary = Color3.fromRGB(175, 35, 255),
		third = Color3.fromRGB(35, 20, 45),
		wisp = "SmokeWisp",
		smoke = true,
		sparkRate = 34,
		wispRate = 36,
		glowTransparency = 0.2,
	},

	Hacked = {
		primary = Color3.fromRGB(55, 255, 90),
		secondary = Color3.fromRGB(0, 95, 25),
		third = Color3.fromRGB(180, 255, 185),
		wisp = "LightningWisp",
		electric = true,
		sparkRate = 56,
		wispRate = 34,
		glowTransparency = 0.2,
	},

	Lava = {
		primary = Color3.fromRGB(255, 65, 10),
		secondary = Color3.fromRGB(255, 190, 35),
		third = Color3.fromRGB(95, 8, 0),
		wisp = "SmokeWisp",
		smoke = true,
		sparkRate = 44,
		wispRate = 34,
		glowTransparency = 0.18,
	},

	Frozen = {
		primary = Color3.fromRGB(120, 245, 255),
		secondary = Color3.fromRGB(245, 255, 255),
		third = Color3.fromRGB(80, 140, 255),
		wisp = "EnergyWisp",
		sparkRate = 44,
		wispRate = 16,
		glowTransparency = 0.32,
	},

	Galaxy = {
		primary = Color3.fromRGB(125, 75, 255),
		secondary = Color3.fromRGB(255, 70, 230),
		third = Color3.fromRGB(35, 10, 90),
		wisp = "EnergyWisp",
		sparkRate = 46,
		wispRate = 30,
		glowTransparency = 0.2,
	},

	Toxic = {
		primary = Color3.fromRGB(115, 255, 35),
		secondary = Color3.fromRGB(35, 120, 20),
		third = Color3.fromRGB(205, 255, 75),
		wisp = "SmokeWisp",
		smoke = true,
		sparkRate = 24,
		wispRate = 32,
		glowTransparency = 0.24,
	},

	Electric = {
		primary = Color3.fromRGB(65, 170, 255),
		secondary = Color3.fromRGB(255, 255, 80),
		third = Color3.fromRGB(220, 250, 255),
		wisp = "LightningWisp",
		electric = true,
		sparkRate = 70,
		wispRate = 38,
		glowTransparency = 0.18,
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
local lastUpdate = 0

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
	return Color3.fromHSV((globalTime * 0.16 + offset) % 1, 0.95, 1)
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
		local old = npc:FindFirstChild(AURA_FOLDER_NAME)
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

local function makeImage(parent, name, image, color, transparency, sizeScale, rotation)
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(sizeScale, sizeScale)
	img.Image = image
	img.ImageColor3 = color
	img.ImageTransparency = transparency
	img.Rotation = rotation or 0
	img.ZIndex = 1
	img.Parent = parent
	return img
end

local function makeBillboard(root, radius, height, profile)
	local p1, p2, p3 = getColors(profile)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = PREFIX .. "BillboardGlow"
	billboard.Adornee = root
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = LOW_DISTANCE
	billboard.Size = UDim2.fromOffset(math.floor(radius * 145), math.floor(height * 135))
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height * 0.05, 0)
	billboard.Parent = root

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = billboard

	local backGlow = makeImage(holder, "BackGlow", TEXTURES.SoftGlow, p1, profile.glowTransparency or 0.25, 1.28, 0)
	backGlow.ZIndex = 1

	local smoke = nil
	if profile.smoke then
		smoke = makeImage(holder, "SmokeGlow", TEXTURES.SmokeWisp, p2, 0.25, 1.22, 20)
		smoke.ZIndex = 2
	end

	local wisp1 = makeImage(holder, "WispOne", TEXTURES[profile.wisp or "EnergyWisp"], p2, 0.18, 1.05, 0)
	wisp1.ZIndex = 3

	local wisp2 = makeImage(holder, "WispTwo", TEXTURES[profile.wisp or "EnergyWisp"], p3, 0.3, 0.88, 145)
	wisp2.ZIndex = 4

	local core = makeImage(holder, "CoreGlow", TEXTURES.SoftGlow, p3, 0.5, 0.72, 0)
	core.ZIndex = 5

	return {
		billboard = billboard,
		holder = holder,
		backGlow = backGlow,
		smoke = smoke,
		wisp1 = wisp1,
		wisp2 = wisp2,
		core = core,
		baseSize = billboard.Size,
	}
end

local function makeHighlight(npc, folder, profile)
	local p1, p2 = getColors(profile)

	local h = Instance.new("Highlight")
	h.Name = "PictureAuraHighlight"
	h.Adornee = npc
	h.FillColor = p1
	h.OutlineColor = p2
	h.FillTransparency = 0.7
	h.OutlineTransparency = 0.05
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = folder

	return h
end

local function makeLight(root, profile)
	local p1 = getColors(profile)

	local light = Instance.new("PointLight")
	light.Name = PREFIX .. "Light"
	light.Color = p1
	light.Brightness = profile.electric and 2.6 or 1.8
	light.Range = 16
	light.Shadows = false
	light.Parent = root

	return light
end

local function makeEmitter(parent, name, textureId, profile, mode, radius)
	local p1, p2, p3 = getColors(profile)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = textureId
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, p1),
		ColorSequenceKeypoint.new(0.5, p3),
		ColorSequenceKeypoint.new(1, p2),
	})
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.LockedToPart = false
	emitter.Parent = parent

	if mode == "glow" then
		emitter.Rate = 16
		emitter.Lifetime = NumberRange.new(0.9, 1.6)
		emitter.Speed = NumberRange.new(0.15, 0.6)
		emitter.Drag = 3
		emitter.LightEmission = 0.8
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.75),
			NumberSequenceKeypoint.new(0.5, radius * 1.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.45, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif mode == "wisp" then
		emitter.Rate = profile.wispRate or 24
		emitter.Lifetime = NumberRange.new(0.65, 1.25)
		emitter.Speed = NumberRange.new(1.1, 3.4)
		emitter.Drag = 1.9
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.18),
			NumberSequenceKeypoint.new(0.55, radius * 0.62),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.65, 0.28),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif mode == "smoke" then
		emitter.Rate = profile.wispRate or 30
		emitter.Lifetime = NumberRange.new(1.0, 1.9)
		emitter.Speed = NumberRange.new(0.35, 1.4)
		emitter.Drag = 4
		emitter.LightEmission = 0.25
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.35),
			NumberSequenceKeypoint.new(0.6, radius * 0.95),
			NumberSequenceKeypoint.new(1, radius * 0.08),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(0.65, 0.62),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		emitter.Rate = profile.sparkRate or 32
		emitter.Lifetime = NumberRange.new(0.2, 0.5)
		emitter.Speed = NumberRange.new(4.5, 10)
		emitter.Drag = 0.7
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.055),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.75, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
	end

	return emitter
end

local function makeGroundRing(folder, profile, radius)
	local p1, p2 = getColors(profile)

	local part = Instance.new("Part")
	part.Name = "PictureAuraGroundRing"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(radius * 2.4, 0.03, radius * 2.4)
	part.Parent = folder

	local top = Instance.new("Decal")
	top.Name = "TopRing"
	top.Texture = TEXTURES.AuraRing
	top.Face = Enum.NormalId.Top
	top.Color3 = p1
	top.Transparency = 0.08
	top.Parent = part

	local bottom = Instance.new("Decal")
	bottom.Name = "BottomRing"
	bottom.Texture = TEXTURES.AuraRing
	bottom.Face = Enum.NormalId.Bottom
	bottom.Color3 = p2
	bottom.Transparency = 0.08
	bottom.Parent = part

	return {
		part = part,
		top = top,
		bottom = bottom,
		baseRadius = radius,
	}
end

local function createAura(npc, mutation)
	clear(npc)

	local profile = PROFILES[mutation]
	if not profile then
		return
	end

	local root = getRoot(npc)
	if not root then
		return
	end

	local size = getSize(npc)
	local radius = math.max(size.X, size.Z, 3.5) * 0.68
	local height = math.max(size.Y, 3.5)

	local folder = Instance.new("Folder")
	folder.Name = AURA_FOLDER_NAME
	folder.Parent = npc

	local center = makeAttachment(root, "Center", Vector3.new(0, height * 0.08, 0))
	local top = makeAttachment(root, "Top", Vector3.new(0, height * 0.45, 0))
	local bottom = makeAttachment(root, "Bottom", Vector3.new(0, -height * 0.35, 0))

	local billboard = makeBillboard(root, radius, height, profile)
	local highlight = makeHighlight(npc, folder, profile)
	local light = makeLight(root, profile)
	local ring = makeGroundRing(folder, profile, radius)

	local emitters = {}

	table.insert(emitters, makeEmitter(center, "PictureAuraGlowParticles", TEXTURES.SoftGlow, profile, "glow", radius))
	table.insert(emitters, makeEmitter(center, "PictureAuraWispParticles", TEXTURES[profile.wisp or "EnergyWisp"], profile, "wisp", radius))
	table.insert(emitters, makeEmitter(top, "PictureAuraSparkParticles", TEXTURES.SharpSpark, profile, "spark", radius))

	if profile.smoke then
		table.insert(emitters, makeEmitter(bottom, "PictureAuraSmokeParticles", TEXTURES.SmokeWisp, profile, "smoke", radius))
	end

	active[npc] = {
		npc = npc,
		root = root,
		folder = folder,
		mutation = mutation,
		profile = profile,
		radius = radius,
		height = height,
		billboard = billboard,
		highlight = highlight,
		light = light,
		ring = ring,
		emitters = emitters,
		start = os.clock(),
		enabled = true,
		lowQuality = false,
	}
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

	createAura(npc, mutation)
end

local function setEnabled(fx, enabled, lowQuality)
	if fx.enabled == enabled and fx.lowQuality == lowQuality then
		return
	end

	fx.enabled = enabled
	fx.lowQuality = lowQuality

	if fx.billboard and fx.billboard.billboard then
		fx.billboard.billboard.Enabled = enabled
	end

	if fx.highlight then
		fx.highlight.Enabled = enabled
	end

	if fx.light then
		fx.light.Enabled = enabled and not lowQuality
	end

	for _, emitter in ipairs(fx.emitters) do
		emitter.Enabled = enabled
		if lowQuality then
			emitter.Rate = math.max(4, math.floor(emitter.Rate * 0.25))
		end
	end

	if fx.ring then
		fx.ring.top.Transparency = enabled and (lowQuality and 0.45 or 0.08) or 1
		fx.ring.bottom.Transparency = enabled and (lowQuality and 0.45 or 0.08) or 1
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
				setEnabled(fx, false, true)
			elseif distance > FULL_DISTANCE then
				setEnabled(fx, true, true)
			else
				setEnabled(fx, true, false)
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

	if fx.highlight then
		fx.highlight.FillColor = p1
		fx.highlight.OutlineColor = p2
	end

	if fx.light then
		fx.light.Color = p1
	end

	if fx.ring then
		fx.ring.top.Color3 = p1
		fx.ring.bottom.Color3 = p2
	end

	local bb = fx.billboard
	if bb then
		bb.backGlow.ImageColor3 = p1
		bb.wisp1.ImageColor3 = p2
		bb.wisp2.ImageColor3 = p3
		bb.core.ImageColor3 = p3

		if bb.smoke then
			bb.smoke.ImageColor3 = p2
		end
	end
end

local function updateAura(fx)
	if not fx.enabled or not fx.root or not fx.root.Parent then
		return
	end

	local elapsed = os.clock() - fx.start
	local pulse = 1 + math.sin(elapsed * 2.4) * 0.065
	local p1 = getColors(fx.profile)

	updateColors(fx)

	local bb = fx.billboard
	if bb and bb.billboard then
		local baseX = bb.baseSize.X.Offset
		local baseY = bb.baseSize.Y.Offset

		bb.billboard.Size = UDim2.fromOffset(baseX * pulse, baseY * pulse)

		bb.backGlow.Rotation = math.sin(elapsed * 0.55) * 8
		bb.wisp1.Rotation = elapsed * 22
		bb.wisp2.Rotation = -elapsed * 16

		bb.backGlow.ImageTransparency = (fx.profile.glowTransparency or 0.25) + math.sin(elapsed * 2) * 0.05
		bb.wisp1.ImageTransparency = 0.18 + math.sin(elapsed * 2.7) * 0.06
		bb.wisp2.ImageTransparency = 0.3 + math.cos(elapsed * 2.2) * 0.06

		if bb.smoke then
			bb.smoke.Rotation = -elapsed * 9
			bb.smoke.ImageTransparency = 0.25 + math.sin(elapsed * 1.7) * 0.08
		end
	end

	if fx.highlight then
		fx.highlight.FillTransparency = 0.7 + math.sin(elapsed * 2.2) * 0.06
	end

	if fx.light then
		fx.light.Brightness = (fx.profile.electric and 2.5 or 1.8) * pulse
		fx.light.Range = 14 + fx.radius * 1.5
	end

	if fx.ring and fx.ring.part then
		local ringSize = fx.radius * (2.35 + math.sin(elapsed * 2.1) * 0.18)

		fx.ring.part.Size = Vector3.new(ringSize, 0.03, ringSize)
		fx.ring.part.CFrame =
			CFrame.new(fx.root.Position + Vector3.new(0, -fx.height * 0.48, 0))
			* CFrame.Angles(0, elapsed * 1.25, 0)
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

	if os.clock() - lastUpdate >= UPDATE_EVERY then
		lastUpdate = os.clock()

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
		updateAura(fx)
	end
end)

print("[MutationPictureAura] Loaded picture-style mutation auras.")