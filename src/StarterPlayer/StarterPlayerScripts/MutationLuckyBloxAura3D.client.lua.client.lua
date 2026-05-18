--!nonstrict
-- StarterPlayerScripts/MutationLuckyBloxAura3D.client.lua
-- Clean Kick-a-Lucky-Blox style 3D mutation aura.
-- No BillboardGui. No square cards. No flat yellow boxes.
-- Uses:
-- 3D particles
-- neon segmented ground ring
-- tilted body aura rings
-- soft highlight
-- point light pulse

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local AURA_FOLDER_NAME = "ClientLuckyBloxAura3D"

local UPDATE_EVERY = 0.25
local FULL_DISTANCE = 150
local LOW_DISTANCE = 260

local TWO_PI = math.pi * 2

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
		main = Color3.fromRGB(255, 220, 45),
		second = Color3.fromRGB(255, 145, 25),
		third = Color3.fromRGB(255, 255, 190),
		wisp = "EnergyWisp",
		glowRate = 12,
		wispRate = 18,
		sparkRate = 34,
		light = 2.1,
		speed = 1.1,
	},

	Diamond = {
		main = Color3.fromRGB(85, 235, 255),
		second = Color3.fromRGB(235, 255, 255),
		third = Color3.fromRGB(70, 155, 255),
		wisp = "EnergyWisp",
		glowRate = 10,
		wispRate = 16,
		sparkRate = 44,
		light = 2,
		speed = 1,
	},

	Rainbow = {
		main = Color3.fromRGB(255, 80, 220),
		second = Color3.fromRGB(80, 255, 150),
		third = Color3.fromRGB(80, 170, 255),
		wisp = "EnergyWisp",
		rainbow = true,
		glowRate = 14,
		wispRate = 26,
		sparkRate = 52,
		light = 2.6,
		speed = 1.4,
	},

	Shadow = {
		main = Color3.fromRGB(135, 55, 215),
		second = Color3.fromRGB(25, 8, 45),
		third = Color3.fromRGB(210, 105, 255),
		wisp = "SmokeWisp",
		smoke = true,
		glowRate = 10,
		wispRate = 30,
		sparkRate = 14,
		light = 1.5,
		speed = 0.85,
	},

	Corrupted = {
		main = Color3.fromRGB(125, 255, 45),
		second = Color3.fromRGB(175, 35, 255),
		third = Color3.fromRGB(35, 20, 45),
		wisp = "SmokeWisp",
		smoke = true,
		glowRate = 13,
		wispRate = 34,
		sparkRate = 34,
		light = 2.2,
		speed = 1.3,
	},

	Hacked = {
		main = Color3.fromRGB(55, 255, 90),
		second = Color3.fromRGB(0, 95, 25),
		third = Color3.fromRGB(180, 255, 185),
		wisp = "LightningWisp",
		electric = true,
		glowRate = 12,
		wispRate = 34,
		sparkRate = 60,
		light = 2.4,
		speed = 2.1,
	},

	Lava = {
		main = Color3.fromRGB(255, 65, 10),
		second = Color3.fromRGB(255, 190, 35),
		third = Color3.fromRGB(95, 8, 0),
		wisp = "SmokeWisp",
		smoke = true,
		glowRate = 13,
		wispRate = 34,
		sparkRate = 46,
		light = 2.7,
		speed = 1.2,
	},

	Frozen = {
		main = Color3.fromRGB(120, 245, 255),
		second = Color3.fromRGB(245, 255, 255),
		third = Color3.fromRGB(80, 140, 255),
		wisp = "EnergyWisp",
		glowRate = 9,
		wispRate = 14,
		sparkRate = 46,
		light = 1.9,
		speed = 0.9,
	},

	Galaxy = {
		main = Color3.fromRGB(125, 75, 255),
		second = Color3.fromRGB(255, 70, 230),
		third = Color3.fromRGB(35, 10, 90),
		wisp = "EnergyWisp",
		glowRate = 14,
		wispRate = 30,
		sparkRate = 48,
		light = 2.5,
		speed = 1.35,
	},

	Toxic = {
		main = Color3.fromRGB(115, 255, 35),
		second = Color3.fromRGB(35, 120, 20),
		third = Color3.fromRGB(205, 255, 75),
		wisp = "SmokeWisp",
		smoke = true,
		glowRate = 10,
		wispRate = 30,
		sparkRate = 24,
		light = 1.8,
		speed = 1,
	},

	Electric = {
		main = Color3.fromRGB(65, 170, 255),
		second = Color3.fromRGB(255, 255, 80),
		third = Color3.fromRGB(220, 250, 255),
		wisp = "LightningWisp",
		electric = true,
		glowRate = 13,
		wispRate = 40,
		sparkRate = 76,
		light = 2.8,
		speed = 2.5,
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

	local best = nil
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
	return Color3.fromHSV((globalTime * 0.14 + offset) % 1, 0.95, 1)
end

local function getColors(profile)
	if profile.rainbow then
		return rainbow(0), rainbow(0.35), rainbow(0.7)
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
		local old = npc:FindFirstChild(AURA_FOLDER_NAME)
		if old then
			old:Destroy()
		end
	end
end

local function makeAttachment(root, name, pos)
	local attachment = Instance.new("Attachment")
	attachment.Name = "Lucky3DAura_" .. name
	attachment.Position = pos or Vector3.zero
	attachment.Parent = root
	return attachment
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

	if mode == "glow" then
		e.Rate = profile.glowRate or 10
		e.Lifetime = NumberRange.new(0.9, 1.45)
		e.Speed = NumberRange.new(0.15, 0.65)
		e.Drag = 3.2
		e.LightEmission = 0.85
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.45),
			NumberSequenceKeypoint.new(0.45, radius * 1.05),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.62),
			NumberSequenceKeypoint.new(0.45, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
	elseif mode == "spark" then
		e.Rate = profile.sparkRate or 32
		e.Lifetime = NumberRange.new(0.18, 0.45)
		e.Speed = NumberRange.new(4, 9)
		e.Drag = 0.75
		e.LightEmission = 1
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.045),
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
			NumberSequenceKeypoint.new(0, radius * 0.22),
			NumberSequenceKeypoint.new(0.6, radius * 0.65),
			NumberSequenceKeypoint.new(1, radius * 0.05),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.65, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		e.Rate = profile.wispRate or 20
		e.Lifetime = NumberRange.new(0.65, 1.2)
		e.Speed = NumberRange.new(1.0, 3.0)
		e.Drag = 2
		e.LightEmission = 1
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, radius * 0.12),
			NumberSequenceKeypoint.new(0.55, radius * 0.42),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.65, 0.32),
			NumberSequenceKeypoint.new(1, 1),
		})
	end

	return e
end

local function makeHighlight(npc, folder, profile)
	local c1, c2 = getColors(profile)

	local h = Instance.new("Highlight")
	h.Name = "Lucky3DAura_Highlight"
	h.Adornee = npc
	h.FillColor = c1
	h.OutlineColor = c2
	h.FillTransparency = 0.75
	h.OutlineTransparency = 0.05
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = folder

	return h
end

local function makeLight(root, profile, radius)
	local c1 = getColors(profile)

	local light = Instance.new("PointLight")
	light.Name = "Lucky3DAura_Light"
	light.Color = c1
	light.Brightness = profile.light or 2
	light.Range = 14 + radius
	light.Shadows = false
	light.Parent = root

	return light
end

local function makeRingSegment(folder, profile, radius, thickness)
	local c1 = getColors(profile)

	local part = Instance.new("Part")
	part.Name = "Lucky3DAura_RingSegment"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = c1
	part.Transparency = 0.12
	part.Size = Vector3.new(radius * 0.24, thickness or 0.035, radius * 0.045)
	part.Parent = folder

	return part
end

local function createRingSegments(folder, profile, count, radius, yOffset, tilt, thickness)
	local segments = {}

	for i = 1, count do
		local part = makeRingSegment(folder, profile, radius, thickness)

		table.insert(segments, {
			part = part,
			index = i,
			count = count,
			radius = radius,
			yOffset = yOffset,
			tilt = tilt or 0,
			baseSize = part.Size,
		})
	end

	return segments
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
	folder.Name = AURA_FOLDER_NAME
	folder.Parent = npc

	local center = makeAttachment(root, "Center", Vector3.new(0, height * 0.05, 0))
	local top = makeAttachment(root, "Top", Vector3.new(0, height * 0.42, 0))
	local bottom = makeAttachment(root, "Bottom", Vector3.new(0, -height * 0.34, 0))

	local emitters = {}

	table.insert(emitters, makeEmitter(center, "Lucky3DAura_Glow", TEXTURES.SoftGlow, profile, "glow", radius))
	table.insert(emitters, makeEmitter(center, "Lucky3DAura_Wisps", TEXTURES[profile.wisp], profile, "wisp", radius))
	table.insert(emitters, makeEmitter(top, "Lucky3DAura_Sparks", TEXTURES.SharpSpark, profile, "spark", radius))

	if profile.smoke then
		table.insert(emitters, makeEmitter(bottom, "Lucky3DAura_Smoke", TEXTURES.SmokeWisp, profile, "smoke", radius))
	end

	local groundRing = createRingSegments(folder, profile, 32, radius * 1.45, -height * 0.48, 0, 0.035)
	local bodyRingOne = createRingSegments(folder, profile, 24, radius * 0.92, height * 0.05, math.rad(68), 0.03)
	local bodyRingTwo = createRingSegments(folder, profile, 24, radius * 0.75, height * 0.34, math.rad(-62), 0.03)

	local highlight = makeHighlight(npc, folder, profile)
	local light = makeLight(root, profile, radius)

	active[npc] = {
		npc = npc,
		root = root,
		folder = folder,
		mutation = mutation,
		profile = profile,
		radius = radius,
		height = height,
		emitters = emitters,
		groundRing = groundRing,
		bodyRingOne = bodyRingOne,
		bodyRingTwo = bodyRingTwo,
		highlight = highlight,
		light = light,
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

	for _, emitter in ipairs(fx.emitters) do
		emitter.Enabled = enabled and not lowQuality
	end

	if fx.highlight then
		fx.highlight.Enabled = enabled
	end

	if fx.light then
		fx.light.Enabled = enabled and not lowQuality
	end

	local transparency = enabled and (lowQuality and 0.7 or 0.12) or 1

	for _, ringGroup in ipairs({ fx.groundRing, fx.bodyRingOne, fx.bodyRingTwo }) do
		for _, seg in ipairs(ringGroup) do
			if seg.part then
				seg.part.Transparency = transparency
			end
		end
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
	local c1, c2, c3 = getColors(fx.profile)

	local seq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(0.5, c3),
		ColorSequenceKeypoint.new(1, c2),
	})

	for _, emitter in ipairs(fx.emitters) do
		emitter.Color = seq
	end

	if fx.highlight then
		fx.highlight.FillColor = c1
		fx.highlight.OutlineColor = c2
	end

	if fx.light then
		fx.light.Color = c1
	end

	for _, ringGroup in ipairs({ fx.groundRing, fx.bodyRingOne, fx.bodyRingTwo }) do
		for _, seg in ipairs(ringGroup) do
			if seg.part then
				if seg.index % 3 == 0 then
					seg.part.Color = c3
				elseif seg.index % 2 == 0 then
					seg.part.Color = c2
				else
					seg.part.Color = c1
				end
			end
		end
	end
end

local function updateRingGroup(fx, ringGroup, elapsed, spinSpeed, pulseAmount)
	local rootPos = fx.root.Position

	for _, seg in ipairs(ringGroup) do
		local part = seg.part

		if part and part.Parent then
			local alpha = seg.index / seg.count
			local angle = alpha * TWO_PI + elapsed * spinSpeed
			local pulse = 1 + math.sin(elapsed * 2.2 + seg.index) * pulseAmount
			local radius = seg.radius * pulse

			local localPos = Vector3.new(
				math.cos(angle) * radius,
				seg.yOffset,
				math.sin(angle) * radius
			)

			local worldPos = rootPos + localPos

			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			local cf = CFrame.lookAt(worldPos, worldPos + tangent)

			if seg.tilt ~= 0 then
				cf = CFrame.new(rootPos)
					* CFrame.Angles(seg.tilt, elapsed * spinSpeed, 0)
					* CFrame.new(math.cos(alpha * TWO_PI) * radius, seg.yOffset, math.sin(alpha * TWO_PI) * radius)
					* CFrame.Angles(0, alpha * TWO_PI, 0)
			end

			part.CFrame = cf
			part.Size = seg.baseSize * (0.9 + math.sin(elapsed * 3 + seg.index) * 0.08)
		end
	end
end

local function updateAura(fx)
	if not fx.enabled or not fx.root or not fx.root.Parent then
		return
	end

	local elapsed = os.clock() - fx.start
	local profile = fx.profile
	local pulse = 1 + math.sin(elapsed * 2.1) * 0.06

	updateColors(fx)

	if fx.light then
		fx.light.Brightness = (profile.light or 2) * pulse
	end

	if fx.highlight then
		fx.highlight.FillTransparency = 0.75 + math.sin(elapsed * 2.2) * 0.05
	end

	updateRingGroup(fx, fx.groundRing, elapsed, profile.speed * 0.85, 0.05)
	updateRingGroup(fx, fx.bodyRingOne, elapsed, profile.speed * 1.15, 0.04)
	updateRingGroup(fx, fx.bodyRingTwo, elapsed, -profile.speed * 0.95, 0.04)
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

print("[MutationLuckyBloxAura3D] Loaded clean 3D Lucky Blox style auras.")