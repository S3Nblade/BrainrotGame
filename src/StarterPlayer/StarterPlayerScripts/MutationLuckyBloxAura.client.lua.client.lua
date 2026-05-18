--!nonstrict
-- StarterPlayerScripts/MutationLuckyBloxAura.client.lua
-- Kick-a-Lucky-Blox style mutation aura.
-- Clean simulator aura: big glow card, rotating wisps, ground ring, sparkles, outline.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local AURA_NAME = "ClientLuckyBloxMutationAura"

local UPDATE_EVERY = 0.25
local MAX_FULL_DISTANCE = 170
local MAX_LOW_DISTANCE = 285

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
		main = Color3.fromRGB(255, 220, 40),
		second = Color3.fromRGB(255, 145, 25),
		third = Color3.fromRGB(255, 255, 190),
		wispTexture = "EnergyWisp",
		glowAlpha = 0.18,
		sparkRate = 34,
		wispRate = 18,
		light = 2.1,
	},

	Diamond = {
		main = Color3.fromRGB(85, 235, 255),
		second = Color3.fromRGB(230, 255, 255),
		third = Color3.fromRGB(70, 155, 255),
		wispTexture = "EnergyWisp",
		glowAlpha = 0.22,
		sparkRate = 42,
		wispRate = 16,
		light = 2,
	},

	Rainbow = {
		main = Color3.fromRGB(255, 80, 220),
		second = Color3.fromRGB(80, 255, 150),
		third = Color3.fromRGB(80, 170, 255),
		wispTexture = "EnergyWisp",
		rainbow = true,
		glowAlpha = 0.14,
		sparkRate = 52,
		wispRate = 26,
		light = 2.5,
	},

	Shadow = {
		main = Color3.fromRGB(135, 55, 215),
		second = Color3.fromRGB(25, 8, 45),
		third = Color3.fromRGB(210, 105, 255),
		wispTexture = "SmokeWisp",
		smoke = true,
		glowAlpha = 0.18,
		sparkRate = 14,
		wispRate = 30,
		light = 1.6,
	},

	Corrupted = {
		main = Color3.fromRGB(125, 255, 45),
		second = Color3.fromRGB(175, 35, 255),
		third = Color3.fromRGB(35, 20, 45),
		wispTexture = "SmokeWisp",
		smoke = true,
		glowAlpha = 0.16,
		sparkRate = 34,
		wispRate = 32,
		light = 2.2,
	},

	Hacked = {
		main = Color3.fromRGB(55, 255, 90),
		second = Color3.fromRGB(0, 95, 25),
		third = Color3.fromRGB(180, 255, 185),
		wispTexture = "LightningWisp",
		electric = true,
		glowAlpha = 0.16,
		sparkRate = 58,
		wispRate = 32,
		light = 2.4,
	},

	Lava = {
		main = Color3.fromRGB(255, 65, 10),
		second = Color3.fromRGB(255, 190, 35),
		third = Color3.fromRGB(95, 8, 0),
		wispTexture = "SmokeWisp",
		smoke = true,
		glowAlpha = 0.14,
		sparkRate = 48,
		wispRate = 32,
		light = 2.7,
	},

	Frozen = {
		main = Color3.fromRGB(120, 245, 255),
		second = Color3.fromRGB(245, 255, 255),
		third = Color3.fromRGB(80, 140, 255),
		wispTexture = "EnergyWisp",
		glowAlpha = 0.25,
		sparkRate = 44,
		wispRate = 14,
		light = 1.9,
	},

	Galaxy = {
		main = Color3.fromRGB(125, 75, 255),
		second = Color3.fromRGB(255, 70, 230),
		third = Color3.fromRGB(35, 10, 90),
		wispTexture = "EnergyWisp",
		glowAlpha = 0.16,
		sparkRate = 48,
		wispRate = 30,
		light = 2.5,
	},

	Toxic = {
		main = Color3.fromRGB(115, 255, 35),
		second = Color3.fromRGB(35, 120, 20),
		third = Color3.fromRGB(205, 255, 75),
		wispTexture = "SmokeWisp",
		smoke = true,
		glowAlpha = 0.2,
		sparkRate = 24,
		wispRate = 30,
		light = 1.8,
	},

	Electric = {
		main = Color3.fromRGB(65, 170, 255),
		second = Color3.fromRGB(255, 255, 80),
		third = Color3.fromRGB(220, 250, 255),
		wispTexture = "LightningWisp",
		electric = true,
		glowAlpha = 0.14,
		sparkRate = 72,
		wispRate = 38,
		light = 2.8,
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

local function getParts(model)
	local parts = {}

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(parts, obj)
		end
	end

	return parts
end

local function getRoot(npc)
	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	local hrp = npc:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	local best
	local bestScore = -math.huge

	for _, part in ipairs(getParts(npc)) do
		local n = normalize(part.Name)
		local score = part.Size.X * part.Size.Y * part.Size.Z

		if n ~= "humanoidrootpart" and n ~= "hitbox" and n ~= "collision" then
			score += 1000
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

	local display = tostring(npc:GetAttribute("DisplayName") or npc:GetAttribute("BrainrotName") or npc.Name or "")

	for key, canonical in pairs(ALIASES) do
		if string.find(normalize(display), key) then
			return canonical
		end
	end

	return "Normal"
end

local function getMutation(npc)
	local n = normalize(getMutationRaw(npc))

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

local function rainbow(offset)
	return Color3.fromHSV((globalTime * 0.15 + offset) % 1, 0.95, 1)
end

local function getColors(profile)
	if profile.rainbow then
		return rainbow(0), rainbow(0.34), rainbow(0.68)
	end

	return profile.main, profile.second, profile.third
end

local function clearAura(npc)
	local fx = active[npc]

	if fx and fx.folder then
		fx.folder:Destroy()
	end

	active[npc] = nil

	if npc then
		local old = npc:FindFirstChild(AURA_NAME)
		if old then
			old:Destroy()
		end
	end
end

local function makeAttachment(root, name, pos)
	local a = Instance.new("Attachment")
	a.Name = "LuckyAura_" .. name
	a.Position = pos or Vector3.zero
	a.Parent = root
	return a
end

local function makeImage(parent, name, textureId, color, transparency, scale, rotation)
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(scale, scale)
	img.Image = textureId
	img.ImageColor3 = color
	img.ImageTransparency = transparency
	img.Rotation = rotation or 0
	img.Parent = parent
	return img
end

local function makeBillboard(root, radius, height, profile)
	local c1, c2, c3 = getColors(profile)

	local gui = Instance.new("BillboardGui")
	gui.Name = "LuckyAura_BigGlow"
	gui.Adornee = root
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = MAX_LOW_DISTANCE
	gui.Size = UDim2.fromOffset(radius * 190, height * 155)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height * 0.04, 0)
	gui.Parent = root

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui

	local backGlow = makeImage(holder, "BackGlow", TEXTURES.SoftGlow, c1, profile.glowAlpha, 1.4, 0)
	local outerWisp = makeImage(holder, "OuterWisp", TEXTURES[profile.wispTexture], c2, 0.18, 1.18, 0)
	local innerWisp = makeImage(holder, "InnerWisp", TEXTURES[profile.wispTexture], c3, 0.35, 0.9, 120)
	local coreGlow = makeImage(holder, "CoreGlow", TEXTURES.SoftGlow, c3, 0.45, 0.72, 0)

	local smoke
	if profile.smoke then
		smoke = makeImage(holder, "SmokeGlow", TEXTURES.SmokeWisp, c2, 0.25, 1.3, 35)
	end

	return {
		gui = gui,
		backGlow = backGlow,
		outerWisp = outerWisp,
		innerWisp = innerWisp,
		coreGlow = coreGlow,
		smoke = smoke,
		baseSize = gui.Size,
	}
end

local function makeHighlight(npc, folder, profile)
	local c1, c2 = getColors(profile)

	local h = Instance.new("Highlight")
	h.Name = "LuckyAura_Highlight"
	h.Adornee = npc
	h.FillColor = c1
	h.OutlineColor = c2
	h.FillTransparency = 0.72
	h.OutlineTransparency = 0.04
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = folder

	return h
end

local function makeLight(root, profile, radius)
	local c1 = getColors(profile)

	local light = Instance.new("PointLight")
	light.Name = "LuckyAura_Light"
	light.Color = c1
	light.Brightness = profile.light or 2
	light.Range = 15 + radius
	light.Shadows = false
	light.Parent = root

	return light
end

local function makeEmitter(parent, name, textureId, profile, mode, radius)
	local c1, c2, c3 = getColors(profile)

	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = textureId
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(0.5, c3),
		ColorSequenceKeypoint.new(1, c2),
	})
	e.SpreadAngle = Vector2.new(360, 360)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-160, 160)
	e.LockedToPart = false
	e.Parent = parent

	if mode == "spark" then
		e.Rate = profile.sparkRate or 32
		e.Lifetime = NumberRange.new(0.18, 0.45)
		e.Speed = NumberRange.new(4, 9)
		e.Drag = 0.75
		e.LightEmission = 1
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.05),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.75, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif mode == "smoke" then
		e.Rate = profile.wispRate or 28
		e.Lifetime = NumberRange.new(1.0, 1.8)
		e.Speed = NumberRange.new(0.35, 1.4)
		e.Drag = 4
		e.LightEmission = 0.25
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.3),
			NumberSequenceKeypoint.new(0.6, radius * 0.9),
			NumberSequenceKeypoint.new(1, radius * 0.08),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(0.65, 0.62),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		e.Rate = profile.wispRate or 20
		e.Lifetime = NumberRange.new(0.65, 1.25)
		e.Speed = NumberRange.new(1.0, 3.0)
		e.Drag = 2
		e.LightEmission = 1
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.15),
			NumberSequenceKeypoint.new(0.55, radius * 0.55),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.65, 0.28),
			NumberSequenceKeypoint.new(1, 1),
		})
	end

	return e
end

local function makeRing(folder, profile, radius)
	local c1, c2 = getColors(profile)

	local part = Instance.new("Part")
	part.Name = "LuckyAura_Ring"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(radius * 2.5, 0.04, radius * 2.5)
	part.Parent = folder

	local top = Instance.new("Decal")
	top.Name = "Top"
	top.Texture = TEXTURES.AuraRing
	top.Face = Enum.NormalId.Top
	top.Color3 = c1
	top.Transparency = 0.08
	top.Parent = part

	local bottom = Instance.new("Decal")
	bottom.Name = "Bottom"
	bottom.Texture = TEXTURES.AuraRing
	bottom.Face = Enum.NormalId.Bottom
	bottom.Color3 = c2
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
	clearAura(npc)

	local profile = PROFILES[mutation]
	if not profile then
		return
	end

	local root = getRoot(npc)
	if not root then
		return
	end

	local size = getSize(npc)
	local radius = math.max(size.X, size.Z, 3.5) * 0.72
	local height = math.max(size.Y, 3.5)

	local folder = Instance.new("Folder")
	folder.Name = AURA_NAME
	folder.Parent = npc

	local center = makeAttachment(root, "Center", Vector3.new(0, height * 0.05, 0))
	local top = makeAttachment(root, "Top", Vector3.new(0, height * 0.45, 0))
	local bottom = makeAttachment(root, "Bottom", Vector3.new(0, -height * 0.35, 0))

	local billboard = makeBillboard(root, radius, height, profile)
	local highlight = makeHighlight(npc, folder, profile)
	local light = makeLight(root, profile, radius)
	local ring = makeRing(folder, profile, radius)

	local emitters = {
		makeEmitter(center, "LuckyAura_Wisps", TEXTURES[profile.wispTexture], profile, "wisp", radius),
		makeEmitter(top, "LuckyAura_Sparks", TEXTURES.SharpSpark, profile, "spark", radius),
	}

	if profile.smoke then
		table.insert(emitters, makeEmitter(bottom, "LuckyAura_Smoke", TEXTURES.SmokeWisp, profile, "smoke", radius))
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

	if fx.billboard and fx.billboard.gui then
		fx.billboard.gui.Enabled = enabled
	end

	if fx.highlight then
		fx.highlight.Enabled = enabled
	end

	if fx.light then
		fx.light.Enabled = enabled and not lowQuality
	end

	for _, e in ipairs(fx.emitters) do
		e.Enabled = enabled and not lowQuality
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

	local cam = camera.CFrame.Position

	for npc, fx in pairs(active) do
		if not npc.Parent or not fx.root or not fx.root.Parent then
			clearAura(npc)
		else
			local distance = (fx.root.Position - cam).Magnitude

			if distance > MAX_LOW_DISTANCE then
				setEnabled(fx, false, true)
			elseif distance > MAX_FULL_DISTANCE then
				setEnabled(fx, true, true)
			else
				setEnabled(fx, true, false)
			end
		end
	end
end

local function updateColors(fx)
	local c1, c2, c3 = getColors(fx.profile)

	local seq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(0.5, c3),
		ColorSequenceKeypoint.new(1, c2),
	})

	for _, e in ipairs(fx.emitters) do
		e.Color = seq
	end

	fx.highlight.FillColor = c1
	fx.highlight.OutlineColor = c2
	fx.light.Color = c1
	fx.ring.top.Color3 = c1
	fx.ring.bottom.Color3 = c2

	local bb = fx.billboard
	bb.backGlow.ImageColor3 = c1
	bb.outerWisp.ImageColor3 = c2
	bb.innerWisp.ImageColor3 = c3
	bb.coreGlow.ImageColor3 = c3

	if bb.smoke then
		bb.smoke.ImageColor3 = c2
	end
end

local function updateAura(fx)
	if not fx.enabled or not fx.root or not fx.root.Parent then
		return
	end

	local elapsed = os.clock() - fx.start
	local pulse = 1 + math.sin(elapsed * 2.25) * 0.055

	updateColors(fx)

	local bb = fx.billboard
	local baseX = bb.baseSize.X.Offset
	local baseY = bb.baseSize.Y.Offset

	bb.gui.Size = UDim2.fromOffset(baseX * pulse, baseY * pulse)
	bb.backGlow.Rotation = math.sin(elapsed * 0.45) * 8
	bb.outerWisp.Rotation = elapsed * 18
	bb.innerWisp.Rotation = -elapsed * 12

	bb.backGlow.ImageTransparency = fx.profile.glowAlpha + math.sin(elapsed * 2) * 0.04
	bb.outerWisp.ImageTransparency = 0.18 + math.sin(elapsed * 2.7) * 0.05
	bb.innerWisp.ImageTransparency = 0.35 + math.cos(elapsed * 2.1) * 0.05
	bb.coreGlow.ImageTransparency = 0.45 + math.sin(elapsed * 2.3) * 0.04

	if bb.smoke then
		bb.smoke.Rotation = -elapsed * 7
		bb.smoke.ImageTransparency = 0.25 + math.sin(elapsed * 1.5) * 0.08
	end

	fx.highlight.FillTransparency = 0.72 + math.sin(elapsed * 2.1) * 0.05
	fx.light.Brightness = fx.profile.light * pulse

	local ringSize = fx.radius * (2.45 + math.sin(elapsed * 2.2) * 0.16)
	fx.ring.part.Size = Vector3.new(ringSize, 0.04, ringSize)
	fx.ring.part.CFrame =
		CFrame.new(fx.root.Position + Vector3.new(0, -fx.height * 0.48, 0))
		* CFrame.Angles(0, elapsed * 1.1, 0)
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
				refreshNpc(npc)
			end
		end

		updateDistance()
	end

	for _, fx in pairs(active) do
		updateAura(fx)
	end
end)

print("[MutationLuckyBloxAura] Loaded clean Kick-a-Lucky-Blox-style mutation auras.")