--!nonstrict
-- ZoneNPCSpawner.server.lua
-- Full replacement.
-- Spawns polished, zone-themed wild NPCs without requiring imported meshes or
-- Workspace.SpawnMap.Zones. This repo currently syncs scripts only, so NPC
-- templates are generated from Roblox parts at runtime.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local TEMPLATE_ROOT_NAME = "ZoneThemedBrainrotNPCPools"
local SPAWNER_ID = "ZoneThemedNPCSpawner_v2"

local GLOBAL_SPAWN_INTERVAL = 4
local AREA_REFRESH_INTERVAL = 10
local INITIAL_DELAY = 2.5

local rng = Random.new()
local areaCache = {}
local lastAreaRefresh = 0

local RARITY_CAPTURE_HP = {
	Common = 45,
	Rare = 80,
	Epic = 140,
	Mythic = 230,
	Legendary = 360,
	Divine = 550,
	Celestial = 800,
	Godly = 1150,
}

local RARITY_SELL_MULTIPLIER = {
	Common = 8,
	Rare = 10,
	Epic = 12,
	Mythic = 15,
	Legendary = 20,
	Divine = 25,
	Celestial = 35,
	Godly = 50,
}

local ZONES = {
	Starter = {
		DisplayName = "Starter Plaza",
		Style = "Starter",
		MaxAlive = 6,
		InitialAlive = 4,
		WalkSpeed = 12,
		SpawnYOffset = 5,
		AreaNames = { "GeneratedFirstMap", "MainPlaza", "SpawnMap", "Baseplate" },
		MarkerPrefixes = { "StarterNPC", "SpawnNPC", "Starter", "Spawn" },
		Rarities = {
			{ "Common", 80 },
			{ "Rare", 18 },
			{ "Epic", 2 },
		},
		MPS = {
			Common = { 20, 60 },
			Rare = { 60, 130 },
			Epic = { 130, 230 },
		},
		Templates = {
			{
				Name = "Poppi Plazito",
				Rarity = "Common",
				Main = Color3.fromRGB(95, 205, 255),
				Second = Color3.fromRGB(255, 232, 90),
				Accent = Color3.fromRGB(255, 95, 150),
			},
			{
				Name = "Bello Bouncini",
				Rarity = "Rare",
				Main = Color3.fromRGB(255, 126, 80),
				Second = Color3.fromRGB(255, 245, 170),
				Accent = Color3.fromRGB(75, 190, 255),
			},
			{
				Name = "Jumbo Jellino",
				Rarity = "Epic",
				Main = Color3.fromRGB(185, 95, 255),
				Second = Color3.fromRGB(95, 245, 210),
				Accent = Color3.fromRGB(255, 218, 70),
			},
		},
	},

	Forest = {
		DisplayName = "Forest",
		Style = "Forest",
		MaxAlive = 10,
		InitialAlive = 6,
		WalkSpeed = 14,
		SpawnYOffset = 5,
		AreaNames = { "ForestMap1", "Forest", "forest", "ForestZone", "ForestArea", "ForestMap" },
		MarkerPrefixes = { "ForestNPC", "Forest_HideSpot", "ForestHideSpot", "ForestSpawn" },
		FallbackCenter = Vector3.new(0, 6, -165),
		FallbackSize = Vector3.new(124, 18, 124),
		Rarities = {
			{ "Rare", 55 },
			{ "Epic", 35 },
			{ "Mythic", 10 },
		},
		MPS = {
			Rare = { 90, 180 },
			Epic = { 180, 350 },
			Mythic = { 350, 650 },
		},
		Templates = {
			{
				Name = "Mossito Bambino",
				Rarity = "Rare",
				Main = Color3.fromRGB(58, 170, 78),
				Second = Color3.fromRGB(128, 235, 96),
				Accent = Color3.fromRGB(102, 72, 38),
			},
			{
				Name = "Vinecap Troppi",
				Rarity = "Epic",
				Main = Color3.fromRGB(36, 125, 68),
				Second = Color3.fromRGB(92, 224, 126),
				Accent = Color3.fromRGB(240, 190, 74),
			},
			{
				Name = "Oakleaf Orbitini",
				Rarity = "Mythic",
				Main = Color3.fromRGB(31, 112, 62),
				Second = Color3.fromRGB(180, 245, 115),
				Accent = Color3.fromRGB(126, 82, 42),
			},
		},
	},

	Desert = {
		DisplayName = "Desert",
		Style = "Desert",
		MaxAlive = 9,
		InitialAlive = 5,
		WalkSpeed = 13,
		SpawnYOffset = 5,
		AreaNames = { "DesertMap2", "Desert", "DesertZone", "Dunes" },
		MarkerPrefixes = { "DesertNPC", "Desert_HideSpot", "DuneNPC" },
		Rarities = {
			{ "Common", 30 },
			{ "Rare", 45 },
			{ "Epic", 20 },
			{ "Mythic", 5 },
		},
		MPS = {
			Common = { 45, 95 },
			Rare = { 95, 190 },
			Epic = { 190, 390 },
			Mythic = { 390, 720 },
		},
		Templates = {
			{
				Name = "Sandy Sahurino",
				Rarity = "Common",
				Main = Color3.fromRGB(222, 176, 92),
				Second = Color3.fromRGB(255, 222, 138),
				Accent = Color3.fromRGB(158, 102, 45),
			},
			{
				Name = "Cactus Calabro",
				Rarity = "Rare",
				Main = Color3.fromRGB(82, 172, 91),
				Second = Color3.fromRGB(238, 194, 102),
				Accent = Color3.fromRGB(255, 96, 80),
			},
			{
				Name = "Dune Dancerino",
				Rarity = "Epic",
				Main = Color3.fromRGB(194, 125, 62),
				Second = Color3.fromRGB(255, 211, 116),
				Accent = Color3.fromRGB(72, 190, 210),
			},
			{
				Name = "Mirage Munchini",
				Rarity = "Mythic",
				Main = Color3.fromRGB(232, 156, 76),
				Second = Color3.fromRGB(95, 222, 235),
				Accent = Color3.fromRGB(255, 236, 150),
			},
		},
	},

	Crystal = {
		DisplayName = "Crystal",
		Style = "Crystal",
		MaxAlive = 8,
		InitialAlive = 5,
		WalkSpeed = 13,
		SpawnYOffset = 5,
		AreaNames = { "CrystalMap3", "CrystalMap", "Crystal", "CrystalZone" },
		MarkerPrefixes = { "CrystalNPC", "Crystal_HideSpot" },
		Rarities = {
			{ "Epic", 55 },
			{ "Mythic", 30 },
			{ "Legendary", 15 },
		},
		MPS = {
			Epic = { 250, 450 },
			Mythic = { 450, 800 },
			Legendary = { 800, 1400 },
		},
		Templates = {
			{
				Name = "Prisma Puffino",
				Rarity = "Epic",
				Main = Color3.fromRGB(92, 224, 255),
				Second = Color3.fromRGB(190, 110, 255),
				Accent = Color3.fromRGB(255, 255, 255),
			},
			{
				Name = "Quartz Quirkini",
				Rarity = "Mythic",
				Main = Color3.fromRGB(116, 255, 238),
				Second = Color3.fromRGB(235, 245, 255),
				Accent = Color3.fromRGB(130, 88, 255),
			},
			{
				Name = "Shardino Splendito",
				Rarity = "Legendary",
				Main = Color3.fromRGB(152, 88, 255),
				Second = Color3.fromRGB(90, 242, 255),
				Accent = Color3.fromRGB(255, 226, 90),
			},
		},
	},

	Lava = {
		DisplayName = "Lava",
		Style = "Lava",
		MaxAlive = 8,
		InitialAlive = 5,
		WalkSpeed = 15,
		SpawnYOffset = 5,
		AreaNames = { "LavaMap4", "LavaMap", "Lava", "LavaZone", "Volcano" },
		MarkerPrefixes = { "LavaNPC", "Lava_HideSpot", "MagmaNPC" },
		Rarities = {
			{ "Mythic", 50 },
			{ "Legendary", 35 },
			{ "Divine", 15 },
		},
		MPS = {
			Mythic = { 700, 1200 },
			Legendary = { 1200, 2200 },
			Divine = { 2200, 4000 },
		},
		Templates = {
			{
				Name = "Magma Munchino",
				Rarity = "Mythic",
				Main = Color3.fromRGB(255, 88, 42),
				Second = Color3.fromRGB(48, 42, 44),
				Accent = Color3.fromRGB(255, 196, 58),
			},
			{
				Name = "Ember Bambino",
				Rarity = "Legendary",
				Main = Color3.fromRGB(198, 42, 35),
				Second = Color3.fromRGB(255, 138, 48),
				Accent = Color3.fromRGB(32, 28, 34),
			},
			{
				Name = "Cinder Crownini",
				Rarity = "Divine",
				Main = Color3.fromRGB(255, 120, 36),
				Second = Color3.fromRGB(255, 224, 82),
				Accent = Color3.fromRGB(92, 28, 32),
			},
		},
	},

	Galaxy = {
		DisplayName = "Galaxy",
		Style = "Galaxy",
		MaxAlive = 7,
		InitialAlive = 4,
		WalkSpeed = 16,
		SpawnYOffset = 5,
		AreaNames = { "GalaxyMap5", "GalaxyMap", "Galaxy", "GalaxyZone", "Space" },
		MarkerPrefixes = { "GalaxyNPC", "Galaxy_HideSpot", "SpaceNPC" },
		Rarities = {
			{ "Legendary", 35 },
			{ "Divine", 30 },
			{ "Celestial", 25 },
			{ "Godly", 10 },
		},
		MPS = {
			Legendary = { 2500, 4500 },
			Divine = { 4500, 8000 },
			Celestial = { 8000, 15000 },
			Godly = { 15000, 30000 },
		},
		Templates = {
			{
				Name = "Nebula Nino",
				Rarity = "Legendary",
				Main = Color3.fromRGB(72, 56, 178),
				Second = Color3.fromRGB(95, 240, 255),
				Accent = Color3.fromRGB(255, 95, 220),
			},
			{
				Name = "Orbitto Maximo",
				Rarity = "Divine",
				Main = Color3.fromRGB(36, 32, 92),
				Second = Color3.fromRGB(255, 221, 78),
				Accent = Color3.fromRGB(105, 255, 232),
			},
			{
				Name = "Cosmo Spaghettini",
				Rarity = "Celestial",
				Main = Color3.fromRGB(115, 82, 255),
				Second = Color3.fromRGB(255, 102, 240),
				Accent = Color3.fromRGB(84, 255, 255),
			},
			{
				Name = "Starlord Bambini",
				Rarity = "Godly",
				Main = Color3.fromRGB(255, 72, 178),
				Second = Color3.fromRGB(42, 32, 88),
				Accent = Color3.fromRGB(255, 235, 95),
			},
		},
	},
}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)

	if folder and folder:IsA("Folder") then
		return folder
	end

	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	return folder
end

local NPC_FOLDER = ensureFolder(Workspace, NPC_FOLDER_NAME)
local TEMPLATE_ROOT = ensureFolder(ServerStorage, TEMPLATE_ROOT_NAME)

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function getRandomMPS(zoneConfig, rarity)
	local range = zoneConfig.MPS[rarity]

	if not range then
		return 50
	end

	return rng:NextInteger(range[1], range[2])
end

local function getSellPriceFromMPS(mps, rarity)
	return math.floor(mps * (RARITY_SELL_MULTIPLIER[rarity] or 10))
end

local function createPart(parent, name, size, cframe, color, shape, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Transparency = transparency or 0
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = true
	part.CanQuery = true
	part.Massless = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	return part
end

local function weld(root, part)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = part
	constraint.Parent = root
	return constraint
end

local function addLight(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Name = "ZoneGlow"
	light.Color = color
	light.Brightness = brightness or 0.9
	light.Range = range or 9
	light.Parent = parent
	return light
end

local function addHighlight(model, fill, outline)
	local highlight = Instance.new("Highlight")
	highlight.Name = "ZoneRarityHighlight"
	highlight.FillColor = fill
	highlight.OutlineColor = outline or Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	return highlight
end

local function addBillboardMarker(model, head, def, zoneConfig)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneNPCStyleMarker"
	billboard.Size = UDim2.new(0, 120, 0, 34)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = string.upper(zoneConfig.DisplayName)
	label.TextScaled = true
	label.TextColor3 = def.Second
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(18, 18, 24)
	stroke.Thickness = 2
	stroke.Parent = label
end

local function addFace(model, root, head)
	local eyeColor = Color3.fromRGB(255, 255, 255)
	local pupilColor = Color3.fromRGB(16, 16, 20)

	for _, side in ipairs({
		{ "Left", -0.35 },
		{ "Right", 0.35 },
	}) do
		local eye = createPart(
			model,
			side[1] .. "Eye",
			Vector3.new(0.32, 0.32, 0.08),
			head.CFrame * CFrame.new(side[2], 0.17, -0.88),
			eyeColor,
			Enum.PartType.Ball
		)
		weld(root, eye)

		local pupil = createPart(
			model,
			side[1] .. "Pupil",
			Vector3.new(0.13, 0.13, 0.04),
			head.CFrame * CFrame.new(side[2], 0.17, -1.04),
			pupilColor,
			Enum.PartType.Ball
		)
		weld(root, pupil)
	end

	local smile = createPart(
		model,
		"Smile",
		Vector3.new(0.7, 0.09, 0.08),
		head.CFrame * CFrame.new(0, -0.32, -1.01),
		Color3.fromRGB(22, 14, 16)
	)
	weld(root, smile)
end

local function addOrbRing(model, root, centerPart, color, radius, amount, namePrefix)
	for i = 1, amount do
		local angle = (math.pi * 2 / amount) * i
		local orb = createPart(
			model,
			namePrefix .. tostring(i),
			Vector3.new(0.28, 0.28, 0.28),
			centerPart.CFrame * CFrame.new(math.cos(angle) * radius, 0.2 + (i % 2) * 0.45, math.sin(angle) * radius),
			color,
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		weld(root, orb)
	end
end

local function addCrystalShard(model, root, baseCFrame, name, color, offset, scale, rotation)
	local shard = createPart(
		model,
		name,
		Vector3.new(0.35 * scale, 1.2 * scale, 0.35 * scale),
		baseCFrame * CFrame.new(offset) * rotation,
		color,
		Enum.PartType.Block,
		Enum.Material.Neon
	)
	weld(root, shard)
	return shard
end

local function addZoneStyle(model, root, body, head, def, zoneConfig)
	local style = zoneConfig.Style

	if style == "Starter" then
		local cap = createPart(
			model,
			"StarterCap",
			Vector3.new(1.45, 0.34, 1.45),
			head.CFrame * CFrame.new(0, 0.82, 0),
			def.Accent,
			Enum.PartType.Cylinder,
			Enum.Material.SmoothPlastic
		)
		weld(root, cap)

		addOrbRing(model, root, body, def.Second, 1.8, 5, "Confetti_")
	end

	if style == "Forest" then
		for i = 1, 6 do
			local angle = (math.pi * 2 / 6) * i
			local leaf = createPart(
				model,
				"LeafCluster_" .. tostring(i),
				Vector3.new(0.55, 0.22, 0.9),
				body.CFrame
					* CFrame.new(math.cos(angle) * 1.25, 0.65 + (i % 2) * 0.28, math.sin(angle) * 1.25)
					* CFrame.Angles(math.rad(18), -angle, math.rad(28)),
				def.Second,
				Enum.PartType.Block,
				Enum.Material.Grass
			)
			weld(root, leaf)
		end

		local twigLeft = createPart(
			model,
			"LeftTwigAntler",
			Vector3.new(0.22, 0.85, 0.22),
			head.CFrame * CFrame.new(-0.58, 0.86, 0) * CFrame.Angles(0, 0, math.rad(-22)),
			def.Accent,
			Enum.PartType.Cylinder,
			Enum.Material.Wood
		)
		weld(root, twigLeft)

		local twigRight = createPart(
			model,
			"RightTwigAntler",
			Vector3.new(0.22, 0.85, 0.22),
			head.CFrame * CFrame.new(0.58, 0.86, 0) * CFrame.Angles(0, 0, math.rad(22)),
			def.Accent,
			Enum.PartType.Cylinder,
			Enum.Material.Wood
		)
		weld(root, twigRight)
	end

	if style == "Desert" then
		local scarf = createPart(
			model,
			"TurquoiseScarf",
			Vector3.new(1.9, 0.28, 1.9),
			head.CFrame * CFrame.new(0, -0.78, 0),
			def.Accent,
			Enum.PartType.Cylinder,
			Enum.Material.SmoothPlastic
		)
		weld(root, scarf)

		local cactusArmLeft = createPart(
			model,
			"LeftCactusArm",
			Vector3.new(0.35, 1.1, 0.35),
			body.CFrame * CFrame.new(-1.35, 0.25, 0) * CFrame.Angles(0, 0, math.rad(-28)),
			Color3.fromRGB(58, 150, 80),
			Enum.PartType.Cylinder,
			Enum.Material.Grass
		)
		weld(root, cactusArmLeft)

		local cactusArmRight = createPart(
			model,
			"RightCactusArm",
			Vector3.new(0.35, 1.1, 0.35),
			body.CFrame * CFrame.new(1.35, 0.25, 0) * CFrame.Angles(0, 0, math.rad(28)),
			Color3.fromRGB(58, 150, 80),
			Enum.PartType.Cylinder,
			Enum.Material.Grass
		)
		weld(root, cactusArmRight)

		addOrbRing(model, root, body, Color3.fromRGB(255, 236, 150), 1.95, 6, "SandSpark_")
	end

	if style == "Crystal" then
		for i = 1, 7 do
			local angle = (math.pi * 2 / 7) * i
			addCrystalShard(
				model,
				root,
				body.CFrame,
				"CrystalShard_" .. tostring(i),
				i % 2 == 0 and def.Second or def.Accent,
				Vector3.new(math.cos(angle) * 1.15, 0.9 + (i % 3) * 0.25, math.sin(angle) * 1.15),
				rng:NextNumber(0.65, 1.05),
				CFrame.Angles(math.rad(rng:NextInteger(-25, 25)), angle, math.rad(rng:NextInteger(-35, 35)))
			)
		end

		addLight(head, def.Second, 1.4, 12)
	end

	if style == "Lava" then
		for _, side in ipairs({
			{ "Left", -0.58, -24 },
			{ "Right", 0.58, 24 },
		}) do
			local horn = createPart(
				model,
				side[1] .. "BasaltHorn",
				Vector3.new(0.35, 0.95, 0.35),
				head.CFrame * CFrame.new(side[2], 0.78, 0) * CFrame.Angles(0, 0, math.rad(side[3])),
				def.Accent,
				Enum.PartType.Cylinder,
				Enum.Material.Neon
			)
			weld(root, horn)
		end

		addOrbRing(model, root, body, Color3.fromRGB(255, 190, 55), 1.95, 7, "Ember_")
		addLight(body, Color3.fromRGB(255, 118, 45), 1.8, 13)
	end

	if style == "Galaxy" then
		local ring = createPart(
			model,
			"GalaxyOrbitRing",
			Vector3.new(3.4, 0.12, 3.4),
			body.CFrame * CFrame.new(0, 0.15, 0) * CFrame.Angles(math.rad(90), 0, math.rad(18)),
			def.Accent,
			Enum.PartType.Cylinder,
			Enum.Material.Neon,
			0.18
		)
		weld(root, ring)

		addOrbRing(model, root, body, def.Second, 2.05, 9, "OrbitStar_")
		addLight(head, def.Second, 1.6, 14)
	end
end

local function createTemplate(zoneName, zoneConfig, def)
	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("GeneratedZoneNPC", true)
	model:SetAttribute("GeneratedBrainrotNPC", true)
	model:SetAttribute("NativeZone", zoneName)
	model:SetAttribute("ZoneStyle", zoneConfig.Style)
	model:SetAttribute("DisplayName", def.Name)
	model:SetAttribute("BrainrotName", def.Name)
	model:SetAttribute("BaseBrainrotName", def.Name)
	model:SetAttribute("TemplateName", def.Name)
	model:SetAttribute("Rarity", def.Rarity)

	local rootCFrame = CFrame.new(0, 5, 0)
	local root = createPart(
		model,
		"HumanoidRootPart",
		Vector3.new(2, 2, 2),
		rootCFrame,
		Color3.fromRGB(255, 255, 255),
		Enum.PartType.Block,
		Enum.Material.SmoothPlastic,
		1
	)
	root.Massless = false
	root.CanCollide = false
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = zoneConfig.WalkSpeed or 14
	humanoid.HipHeight = 2
	humanoid.AutoRotate = true
	humanoid.Parent = model

	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	local body = createPart(
		model,
		"Body",
		Vector3.new(2.3, 2.3, 2.3),
		rootCFrame * CFrame.new(0, -0.15, 0),
		def.Main,
		Enum.PartType.Ball,
		Enum.Material.SmoothPlastic
	)
	weld(root, body)

	local head = createPart(
		model,
		"Head",
		Vector3.new(1.72, 1.72, 1.72),
		rootCFrame * CFrame.new(0, 1.52, -0.06),
		def.Second,
		Enum.PartType.Ball,
		Enum.Material.SmoothPlastic
	)
	weld(root, head)

	for _, limb in ipairs({
		{ "LeftArm", -1.38, 0.08, 22 },
		{ "RightArm", 1.38, 0.08, -22 },
		{ "LeftLeg", -0.55, -1.45, 0 },
		{ "RightLeg", 0.55, -1.45, 0 },
	}) do
		local part = createPart(
			model,
			limb[1],
			Vector3.new(0.56, 1.25, 0.56),
			rootCFrame * CFrame.new(limb[2], limb[3], -0.04) * CFrame.Angles(0, 0, math.rad(limb[4])),
			def.Accent,
			Enum.PartType.Cylinder,
			Enum.Material.SmoothPlastic
		)
		weld(root, part)
	end

	for _, foot in ipairs({
		{ "LeftFoot", -0.55 },
		{ "RightFoot", 0.55 },
	}) do
		local part = createPart(
			model,
			foot[1],
			Vector3.new(0.78, 0.36, 0.98),
			rootCFrame * CFrame.new(foot[2], -2.1, -0.3),
			def.Second,
			Enum.PartType.Ball,
			Enum.Material.SmoothPlastic
		)
		weld(root, part)
	end

	addFace(model, root, head)
	addZoneStyle(model, root, body, head, def, zoneConfig)
	addBillboardMarker(model, head, def, zoneConfig)

	if def.Rarity ~= "Common" then
		addHighlight(model, def.Main, def.Second)
	end

	model:PivotTo(CFrame.new(0, 5, 0))
	return model
end

local function buildTemplates()
	TEMPLATE_ROOT:ClearAllChildren()

	for zoneName, zoneConfig in pairs(ZONES) do
		local zoneFolder = ensureFolder(TEMPLATE_ROOT, zoneName)

		for _, def in ipairs(zoneConfig.Templates) do
			local template = createTemplate(zoneName, zoneConfig, def)
			template.Parent = zoneFolder
		end
	end

	print("[ZoneNPCSpawner] Built zone-themed NPC template pool.")
end

local function nameContainsAny(name, fragments)
	local lowerName = string.lower(tostring(name or ""))

	for _, fragment in ipairs(fragments) do
		local lowerFragment = string.lower(tostring(fragment or ""))
		if lowerFragment ~= "" and string.find(lowerName, lowerFragment, 1, true) then
			return true
		end
	end

	return false
end

local function collectParts(root, result)
	if not root then
		return
	end

	if root:IsA("BasePart") then
		table.insert(result, root)
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(result, obj)
		end
	end
end

local function getBoundingBox(root, parts)
	if root:IsA("Model") then
		local ok, cf, size = pcall(function()
			return root:GetBoundingBox()
		end)

		if ok and cf and size then
			return cf, size
		end
	end

	if root:IsA("BasePart") then
		return root.CFrame, root.Size
	end

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(parts) do
		local half = part.Size * 0.5
		local low = part.Position - half
		local high = part.Position + half

		minV = Vector3.new(math.min(minV.X, low.X), math.min(minV.Y, low.Y), math.min(minV.Z, low.Z))
		maxV = Vector3.new(math.max(maxV.X, high.X), math.max(maxV.Y, high.Y), math.max(maxV.Z, high.Z))
	end

	if minV.X == math.huge then
		return nil, nil
	end

	return CFrame.new((minV + maxV) * 0.5), maxV - minV
end

local function makeArea(root)
	local parts = {}
	collectParts(root, parts)

	if #parts <= 0 then
		return nil
	end

	local cf, size = getBoundingBox(root, parts)
	if not cf or not size then
		return nil
	end

	return {
		root = root,
		parts = parts,
		cframe = cf,
		size = size,
	}
end

local function makeScatterArea(position, size, sourceName)
	return {
		root = Workspace,
		parts = {},
		cframe = CFrame.new(position),
		size = size,
		synthetic = true,
		sourceName = sourceName or "Fallback",
	}
end

local function areaIsTooSmall(area, zoneConfig)
	if not area or not zoneConfig.FallbackSize then
		return false
	end

	return area.size.X < math.min(42, zoneConfig.FallbackSize.X * 0.35)
		or area.size.Z < math.min(42, zoneConfig.FallbackSize.Z * 0.35)
end

local function findPortalDestinationArea(zoneName, zoneConfig)
	local portals = Workspace:FindFirstChild("ZonePortals")
	if not portals then
		return nil
	end

	for _, portal in ipairs(portals:GetChildren()) do
		if portal:GetAttribute("ZoneId") == zoneName then
			local destination = portal:FindFirstChild("Destination")
			if destination and destination:IsA("BasePart") then
				return makeScatterArea(destination.Position, zoneConfig.FallbackSize or Vector3.new(100, 18, 100), "PortalDestination")
			end

			if portal:IsA("BasePart") then
				return makeScatterArea(portal.Position, zoneConfig.FallbackSize or Vector3.new(100, 18, 100), "Portal")
			end
		end
	end

	return nil
end

local function getExpandedArea(area, zoneConfig)
	if not area or not zoneConfig.FallbackSize then
		return area
	end

	if areaIsTooSmall(area, zoneConfig) then
		return makeScatterArea(area.cframe.Position, zoneConfig.FallbackSize, "ExpandedSmallZone")
	end

	return area
end

local function getFallbackArea(zoneConfig)
	if not zoneConfig.FallbackCenter then
		return nil
	end

	return makeScatterArea(zoneConfig.FallbackCenter, zoneConfig.FallbackSize or Vector3.new(100, 18, 100), "ConfiguredFallback")
end

local function findWorkspaceChildByNames(names)
	for _, wantedName in ipairs(names) do
		local direct = Workspace:FindFirstChild(wantedName)
		if direct then
			return direct
		end
	end

	for _, wantedName in ipairs(names) do
		local found = Workspace:FindFirstChild(wantedName, true)
		if found then
			return found
		end
	end

	return nil
end

local function findMarkerParts(zoneConfig)
	local markers = {}
	local searchRoots = {}

	local hideSpots = Workspace:FindFirstChild("HideSpots")
	if hideSpots then
		table.insert(searchRoots, hideSpots)
	end

	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	if spawnMap then
		table.insert(searchRoots, spawnMap)
	end

	for _, root in ipairs(searchRoots) do
		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("BasePart") and nameContainsAny(obj.Name, zoneConfig.MarkerPrefixes) then
				table.insert(markers, obj)
			end
		end
	end

	return markers
end

local function refreshAreas(force)
	local now = os.clock()

	if not force and now - lastAreaRefresh < AREA_REFRESH_INTERVAL then
		return
	end

	lastAreaRefresh = now
	areaCache = {}

	for zoneName, zoneConfig in pairs(ZONES) do
		local root = findWorkspaceChildByNames(zoneConfig.AreaNames)
		local area = root and makeArea(root) or nil
		area = getExpandedArea(area, zoneConfig)
		area = area or findPortalDestinationArea(zoneName, zoneConfig) or getFallbackArea(zoneConfig)
		local markers = findMarkerParts(zoneConfig)

		areaCache[zoneName] = {
			area = area,
			markers = markers,
		}
	end
end

local function getZoneRuntime(zoneName)
	refreshAreas(false)
	return areaCache[zoneName]
end

local function raycastToArea(area, origin)
	if not area then
		return nil
	end

	local params = RaycastParams.new()
	local distance = math.max(350, area.size.Y + 260)

	if area.synthetic == true then
		local exclude = { NPC_FOLDER }
		local portals = Workspace:FindFirstChild("ZonePortals")
		local spawnMap = Workspace:FindFirstChild("SpawnMap")
		local zoneGates = spawnMap and spawnMap:FindFirstChild("ZoneGates")

		if portals then
			table.insert(exclude, portals)
		end

		if zoneGates then
			table.insert(exclude, zoneGates)
		end

		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclude
		return Workspace:Raycast(origin, Vector3.new(0, -distance, 0), params)
	end

	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { area.root }
	return Workspace:Raycast(origin, Vector3.new(0, -distance, 0), params)
end

local function randomPointOnMarker(marker, zoneConfig)
	local x = rng:NextNumber(-marker.Size.X * 0.42, marker.Size.X * 0.42)
	local z = rng:NextNumber(-marker.Size.Z * 0.42, marker.Size.Z * 0.42)
	local point = marker.CFrame:PointToWorldSpace(Vector3.new(x, marker.Size.Y * 0.5, z))
	return point + Vector3.new(0, zoneConfig.SpawnYOffset or 5, 0)
end

local function randomPointInArea(area, zoneConfig)
	if not area then
		return nil
	end

	for _ = 1, 8 do
		local x = rng:NextNumber(-area.size.X * 0.43, area.size.X * 0.43)
		local z = rng:NextNumber(-area.size.Z * 0.43, area.size.Z * 0.43)
		local top = area.cframe:PointToWorldSpace(Vector3.new(x, area.size.Y * 0.5 + 180, z))
		local hit = raycastToArea(area, top)

		if hit then
			return hit.Position + Vector3.new(0, zoneConfig.SpawnYOffset or 5, 0)
		end
	end

	return area.cframe.Position + Vector3.new(0, (zoneConfig.SpawnYOffset or 5) + area.size.Y * 0.1, 0)
end

local function chooseSpawnPosition(zoneName)
	local zoneConfig = ZONES[zoneName]
	local runtime = getZoneRuntime(zoneName)

	if not runtime then
		return nil
	end

	if #runtime.markers > 0 then
		return randomPointOnMarker(pick(runtime.markers), zoneConfig)
	end

	return randomPointInArea(runtime.area, zoneConfig)
end

local function chooseWeightedRarity(zoneConfig)
	local total = 0

	for _, pair in ipairs(zoneConfig.Rarities) do
		total += pair[2]
	end

	if total <= 0 then
		return "Common"
	end

	local roll = rng:NextNumber(0, total)
	local running = 0

	for _, pair in ipairs(zoneConfig.Rarities) do
		running += pair[2]

		if roll <= running then
			return pair[1]
		end
	end

	return zoneConfig.Rarities[1][1]
end

local function getTemplatesForZone(zoneName, rarity)
	local folder = TEMPLATE_ROOT:FindFirstChild(zoneName)

	if not folder then
		return {}
	end

	local result = {}

	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Model") and obj:GetAttribute("Rarity") == rarity then
			table.insert(result, obj)
		end
	end

	return result
end

local function chooseTemplate(zoneName, rarity)
	local templates = getTemplatesForZone(zoneName, rarity)

	if #templates > 0 then
		return pick(templates)
	end

	local folder = TEMPLATE_ROOT:FindFirstChild(zoneName)
	if not folder then
		return nil
	end

	templates = {}

	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Model") then
			table.insert(templates, obj)
		end
	end

	if #templates <= 0 then
		return nil
	end

	return pick(templates)
end

local function isWildNpc(npc)
	if not npc:IsA("Model") then
		return false
	end

	if npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true then
		return false
	end

	local heldBy = npc:GetAttribute("HeldBy")
	if heldBy ~= nil and heldBy ~= 0 and heldBy ~= "" then
		return false
	end

	if npc:GetAttribute("InventoryOnly") == true then
		return false
	end

	return true
end

local function countAliveInZone(zoneName)
	local count = 0

	for _, npc in ipairs(NPC_FOLDER:GetChildren()) do
		if isWildNpc(npc) and npc:GetAttribute("SpawnZone") == zoneName then
			count += 1
		end
	end

	return count
end

local function prepareNPC(npc, zoneName, rarity, mps)
	local uid = HttpService:GenerateGUID(false)
	local zoneConfig = ZONES[zoneName]
	local captureMaxHP = RARITY_CAPTURE_HP[rarity] or RARITY_CAPTURE_HP.Common

	npc:SetAttribute("NPCId", uid)
	npc:SetAttribute("BrainrotUID", uid)
	npc:SetAttribute("UID", uid)
	npc:SetAttribute("BrainrotUid", uid)
	npc:SetAttribute("DirectInventoryUid", uid)
	npc:SetAttribute("InventoryUid", uid)

	npc:SetAttribute("SpawnZone", zoneName)
	npc:SetAttribute("ZoneSpawned", true)
	npc:SetAttribute("ForestSpawned", zoneName == "Forest")
	npc:SetAttribute("NativeZone", zoneName)
	npc:SetAttribute("ZoneStyle", zoneConfig.Style)
	npc:SetAttribute("ZoneDisplayName", zoneConfig.DisplayName)
	npc:SetAttribute("ZoneSpawnerId", SPAWNER_ID)
	npc:SetAttribute("Rarity", rarity)
	npc:SetAttribute("MPS", mps)
	npc:SetAttribute("Earned", 0)
	npc:SetAttribute("SellPrice", getSellPriceFromMPS(mps, rarity))
	npc:SetAttribute("CaptureMaxHP", captureMaxHP)
	npc:SetAttribute("CaptureHP", captureMaxHP)
	npc:SetAttribute("CaptureStunned", false)
	npc:SetAttribute("CapturePanic", false)
	npc:SetAttribute("CaptureShielded", false)
	npc:SetAttribute("CaptureShieldEndTime", 0)
	npc:SetAttribute("CanPickup", false)
	npc:SetAttribute("PickupReady", false)
	npc:SetAttribute("ReadyToPickup", false)

	npc:SetAttribute("IsPlaced", false)
	npc:SetAttribute("Placed", false)
	npc:SetAttribute("HeldBy", nil)
	npc:SetAttribute("PlacedOwnerUserId", nil)
	npc:SetAttribute("AssignedHouseGoal", nil)
	npc:SetAttribute("AssignedSlotId", nil)
	npc:SetAttribute("InventoryOnly", false)

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.WalkSpeed = zoneConfig.WalkSpeed or 14
		humanoid.AutoRotate = true
		humanoid.Health = humanoid.MaxHealth
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = false
			obj.CanCollide = false
			obj.CanTouch = true
			obj.CanQuery = true
			obj.Massless = obj.Name ~= "HumanoidRootPart"
			pcall(function()
				obj:SetNetworkOwner(nil)
			end)
		end
	end
end

local function shouldWander(npc)
	if not npc or not npc.Parent then
		return false
	end

	if not isWildNpc(npc) then
		return false
	end

	if npc:GetAttribute("CaptureStunned") == true
		or npc:GetAttribute("CapturePanic") == true
		or npc:GetAttribute("CaptureChaseActive") == true then
		return false
	end

	local hp = tonumber(npc:GetAttribute("CaptureHP"))
	if hp ~= nil and hp <= 0 then
		return false
	end

	return true
end

local function startWander(npc, zoneName)
	local token = HttpService:GenerateGUID(false)
	npc:SetAttribute("ZoneWanderToken", token)

	task.spawn(function()
		task.wait(rng:NextNumber(0.5, 2.0))

		while npc.Parent == NPC_FOLDER and npc:GetAttribute("ZoneWanderToken") == token do
			local humanoid = npc:FindFirstChildOfClass("Humanoid")

			if humanoid and shouldWander(npc) then
				local target = chooseSpawnPosition(zoneName)

				if target then
					humanoid.WalkSpeed = ZONES[zoneName].WalkSpeed or humanoid.WalkSpeed
					humanoid:MoveTo(target)

					local done = false
					local conn = humanoid.MoveToFinished:Connect(function()
						done = true
					end)

					local started = os.clock()
					while not done and os.clock() - started < 5 and shouldWander(npc) do
						task.wait(0.25)
					end

					conn:Disconnect()
				end
			end

			task.wait(rng:NextNumber(2.0, 4.5))
		end
	end)
end

local function spawnNPCInZone(zoneName)
	local zoneConfig = ZONES[zoneName]

	if not zoneConfig then
		return false
	end

	local runtime = getZoneRuntime(zoneName)
	if not runtime or (#runtime.markers <= 0 and not runtime.area) then
		return false
	end

	if countAliveInZone(zoneName) >= zoneConfig.MaxAlive then
		return false
	end

	local rarity = chooseWeightedRarity(zoneConfig)
	local template = chooseTemplate(zoneName, rarity)

	if not template then
		warn("[ZoneNPCSpawner] No template available for zone:", zoneName)
		return false
	end

	local spawnPosition = chooseSpawnPosition(zoneName)
	if not spawnPosition then
		return false
	end

	local npc = template:Clone()
	local mps = getRandomMPS(zoneConfig, rarity)

	prepareNPC(npc, zoneName, rarity, mps)
	npc:PivotTo(CFrame.new(spawnPosition) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	startWander(npc, zoneName)
	npc.Parent = NPC_FOLDER

	print(
		"[ZoneNPCSpawner] Spawned",
		npc.Name,
		"Zone:",
		zoneName,
		"Rarity:",
		rarity,
		"MPS:",
		mps
	)

	return true
end

local function spawnInitialBatch()
	refreshAreas(true)

	for zoneName, zoneConfig in pairs(ZONES) do
		local runtime = areaCache[zoneName]

		if runtime and (#runtime.markers > 0 or runtime.area) then
			for _ = 1, zoneConfig.InitialAlive do
				spawnNPCInZone(zoneName)
				task.wait(0.08)
			end
		else
			warn("[ZoneNPCSpawner] No spawnable map area found for zone:", zoneName)
		end
	end
end

buildTemplates()

task.delay(INITIAL_DELAY, function()
	spawnInitialBatch()
end)

task.spawn(function()
	while true do
		for zoneName, _zoneConfig in pairs(ZONES) do
			spawnNPCInZone(zoneName)
			task.wait(0.15)
		end

		task.wait(GLOBAL_SPAWN_INTERVAL)
	end
end)

NPC_FOLDER.ChildAdded:Connect(function(child)
	if child:IsA("Model")
		and child:GetAttribute("ZoneSpawnerId") == SPAWNER_ID
		and child:GetAttribute("ZoneWanderToken") == nil then
		local zoneName = child:GetAttribute("SpawnZone")
		if ZONES[zoneName] then
			startWander(child, zoneName)
		end
	end
end)

print("[ZoneNPCSpawner] loaded. Zone-themed NPCs scatter by real map areas.")
