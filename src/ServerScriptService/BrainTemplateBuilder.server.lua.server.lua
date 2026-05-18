--!nonstrict
-- BrainrotTemplateBuilder.server.lua
-- Put in: ServerScriptService
-- Run once in Studio, then disable/delete this script.
-- Creates cartoon simulator brainrot NPC templates for your existing hide-and-seek system.

local ServerStorage = game:GetService("ServerStorage")

local POOLS_FOLDER_NAME = "BrainrotNPCPools"

local REBUILD_GENERATED_ONLY = true

local RARITY_STATS = {
	Common = {
		MPS = 35,
		SellPrice = 150,
		CaptureMaxHP = 45,
		LimitAFK = 2500,
	},

	Rare = {
		MPS = 75,
		SellPrice = 450,
		CaptureMaxHP = 80,
		LimitAFK = 6000,
	},

	Epic = {
		MPS = 150,
		SellPrice = 1200,
		CaptureMaxHP = 140,
		LimitAFK = 12000,
	},

	Mythic = {
		MPS = 300,
		SellPrice = 3500,
		CaptureMaxHP = 230,
		LimitAFK = 25000,
	},

	Legendary = {
		MPS = 650,
		SellPrice = 9000,
		CaptureMaxHP = 360,
		LimitAFK = 60000,
	},

	Divine = {
		MPS = 1200,
		SellPrice = 22000,
		CaptureMaxHP = 550,
		LimitAFK = 130000,
	},

	Celestial = {
		MPS = 2500,
		SellPrice = 60000,
		CaptureMaxHP = 800,
		LimitAFK = 300000,
	},

	Godly = {
		MPS = 6000,
		SellPrice = 175000,
		CaptureMaxHP = 1150,
		LimitAFK = 900000,
	},
}

local NPC_DEFINITIONS = {
	{
		Name = "Trippi Troppi",
		Rarity = "Common",
		Main = Color3.fromRGB(120, 255, 95),
		Second = Color3.fromRGB(255, 235, 95),
		Accent = Color3.fromRGB(70, 180, 50),
		Style = "Goofy",
	},

	{
		Name = "Bombo Blippi",
		Rarity = "Common",
		Main = Color3.fromRGB(255, 180, 85),
		Second = Color3.fromRGB(255, 245, 160),
		Accent = Color3.fromRGB(180, 110, 45),
		Style = "Bucket",
	},

	{
		Name = "Zingi Zangini",
		Rarity = "Rare",
		Main = Color3.fromRGB(70, 165, 255),
		Second = Color3.fromRGB(120, 240, 255),
		Accent = Color3.fromRGB(30, 75, 210),
		Style = "Sneaky",
	},

	{
		Name = "Frigo Frigolino",
		Rarity = "Rare",
		Main = Color3.fromRGB(90, 230, 255),
		Second = Color3.fromRGB(220, 255, 255),
		Accent = Color3.fromRGB(40, 140, 255),
		Style = "Ice",
	},

	{
		Name = "Glitchi Glatchi",
		Rarity = "Epic",
		Main = Color3.fromRGB(190, 75, 255),
		Second = Color3.fromRGB(255, 90, 230),
		Accent = Color3.fromRGB(80, 25, 180),
		Style = "Glitch",
	},

	{
		Name = "Plinko Plonko",
		Rarity = "Epic",
		Main = Color3.fromRGB(160, 80, 255),
		Second = Color3.fromRGB(255, 220, 90),
		Accent = Color3.fromRGB(90, 40, 190),
		Style = "Runner",
	},

	{
		Name = "Frutti Frattino",
		Rarity = "Mythic",
		Main = Color3.fromRGB(255, 65, 165),
		Second = Color3.fromRGB(255, 125, 85),
		Accent = Color3.fromRGB(130, 0, 80),
		Style = "Horns",
	},

	{
		Name = "Bubblo Bambini",
		Rarity = "Mythic",
		Main = Color3.fromRGB(255, 90, 210),
		Second = Color3.fromRGB(90, 255, 220),
		Accent = Color3.fromRGB(170, 20, 135),
		Style = "Bubble",
	},

	{
		Name = "Kingo Mangalini",
		Rarity = "Legendary",
		Main = Color3.fromRGB(255, 205, 45),
		Second = Color3.fromRGB(255, 245, 120),
		Accent = Color3.fromRGB(190, 100, 15),
		Style = "Crown",
	},

	{
		Name = "Oro Oro Nino",
		Rarity = "Legendary",
		Main = Color3.fromRGB(255, 180, 35),
		Second = Color3.fromRGB(255, 80, 80),
		Accent = Color3.fromRGB(120, 70, 15),
		Style = "Treasure",
	},

	{
		Name = "Angelino Bellino",
		Rarity = "Divine",
		Main = Color3.fromRGB(255, 245, 185),
		Second = Color3.fromRGB(90, 245, 255),
		Accent = Color3.fromRGB(255, 215, 90),
		Style = "Angel",
	},

	{
		Name = "Luma Luma Lumino",
		Rarity = "Divine",
		Main = Color3.fromRGB(255, 255, 210),
		Second = Color3.fromRGB(150, 255, 255),
		Accent = Color3.fromRGB(255, 220, 100),
		Style = "Halo",
	},

	{
		Name = "Galaxi Spaghettini",
		Rarity = "Celestial",
		Main = Color3.fromRGB(105, 85, 255),
		Second = Color3.fromRGB(85, 255, 255),
		Accent = Color3.fromRGB(255, 90, 230),
		Style = "Galaxy",
	},

	{
		Name = "Astro Trottolino",
		Rarity = "Celestial",
		Main = Color3.fromRGB(70, 40, 180),
		Second = Color3.fromRGB(255, 220, 80),
		Accent = Color3.fromRGB(100, 255, 255),
		Style = "Stars",
	},

	{
		Name = "Diablo Fruttino",
		Rarity = "Godly",
		Main = Color3.fromRGB(255, 65, 65),
		Second = Color3.fromRGB(35, 35, 45),
		Accent = Color3.fromRGB(255, 190, 45),
		Style = "Demon",
	},

	{
		Name = "Rumblo Rumbini",
		Rarity = "Godly",
		Main = Color3.fromRGB(255, 40, 40),
		Second = Color3.fromRGB(255, 230, 75),
		Accent = Color3.fromRGB(80, 0, 0),
		Style = "Overlord",
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

local poolsFolder = ensureFolder(ServerStorage, POOLS_FOLDER_NAME)

local function createPart(parent, name, size, cframe, color, shape, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = true
	part.CanQuery = true
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	return part
end

local function weld(part0, part1)
	local w = Instance.new("WeldConstraint")
	w.Part0 = part0
	w.Part1 = part1
	w.Parent = part0
	return w
end

local function addGlow(parent, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Name = "CartoonGlow"
	light.Color = color
	light.Brightness = brightness or 0.8
	light.Range = range or 8
	light.Parent = parent

	return light
end

local function addHighlight(model, fill, outline)
	local h = Instance.new("Highlight")
	h.Name = "RarityHighlight"
	h.FillColor = fill
	h.OutlineColor = outline or Color3.fromRGB(255, 255, 255)
	h.FillTransparency = 0.45
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = model

	return h
end

local function addFace(model, head, root)
	local leftEye = createPart(
		model,
		"LeftEye",
		Vector3.new(0.32, 0.32, 0.08),
		head.CFrame * CFrame.new(-0.35, 0.2, -0.88),
		Color3.fromRGB(255, 255, 255),
		Enum.PartType.Ball
	)
	weld(root, leftEye)

	local rightEye = createPart(
		model,
		"RightEye",
		Vector3.new(0.32, 0.32, 0.08),
		head.CFrame * CFrame.new(0.35, 0.2, -0.88),
		Color3.fromRGB(255, 255, 255),
		Enum.PartType.Ball
	)
	weld(root, rightEye)

	local leftPupil = createPart(
		model,
		"LeftPupil",
		Vector3.new(0.13, 0.13, 0.04),
		head.CFrame * CFrame.new(-0.35, 0.2, -1.05),
		Color3.fromRGB(0, 0, 0),
		Enum.PartType.Ball
	)
	weld(root, leftPupil)

	local rightPupil = createPart(
		model,
		"RightPupil",
		Vector3.new(0.13, 0.13, 0.04),
		head.CFrame * CFrame.new(0.35, 0.2, -1.05),
		Color3.fromRGB(0, 0, 0),
		Enum.PartType.Ball
	)
	weld(root, rightPupil)

	local mouth = createPart(
		model,
		"Mouth",
		Vector3.new(0.65, 0.09, 0.08),
		head.CFrame * CFrame.new(0, -0.32, -1.02),
		Color3.fromRGB(25, 15, 20),
		Enum.PartType.Block
	)
	weld(root, mouth)
end

local function addCrown(model, root, head, color)
	for i = 1, 5 do
		local x = (i - 3) * 0.28
		local spike = createPart(
			model,
			"CrownSpike_" .. tostring(i),
			Vector3.new(0.22, 0.55, 0.22),
			head.CFrame * CFrame.new(x, 0.96, -0.05),
			color,
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		weld(root, spike)
	end

	local band = createPart(
		model,
		"CrownBand",
		Vector3.new(1.55, 0.22, 1.15),
		head.CFrame * CFrame.new(0, 0.72, 0),
		color,
		Enum.PartType.Block,
		Enum.Material.Neon
	)
	weld(root, band)
end

local function addHorns(model, root, head, color)
	local left = createPart(
		model,
		"LeftHorn",
		Vector3.new(0.35, 0.85, 0.35),
		head.CFrame * CFrame.new(-0.58, 0.75, 0),
		color,
		Enum.PartType.Cylinder,
		Enum.Material.Neon
	)
	left.Rotation = Vector3.new(0, 0, -25)
	weld(root, left)

	local right = createPart(
		model,
		"RightHorn",
		Vector3.new(0.35, 0.85, 0.35),
		head.CFrame * CFrame.new(0.58, 0.75, 0),
		color,
		Enum.PartType.Cylinder,
		Enum.Material.Neon
	)
	right.Rotation = Vector3.new(0, 0, 25)
	weld(root, right)
end

local function addHalo(model, root, head, color)
	local halo = createPart(
		model,
		"Halo",
		Vector3.new(1.9, 0.18, 1.9),
		head.CFrame * CFrame.new(0, 1.1, 0),
		color,
		Enum.PartType.Cylinder,
		Enum.Material.Neon
	)
	halo.Rotation = Vector3.new(90, 0, 0)
	weld(root, halo)
end

local function addWings(model, root, body, color)
	local leftWing = createPart(
		model,
		"LeftWing",
		Vector3.new(0.35, 1.75, 1.15),
		body.CFrame * CFrame.new(-1.55, 0.2, 0.25),
		color,
		Enum.PartType.Block,
		Enum.Material.Neon
	)
	leftWing.Rotation = Vector3.new(0, 0, -20)
	weld(root, leftWing)

	local rightWing = createPart(
		model,
		"RightWing",
		Vector3.new(0.35, 1.75, 1.15),
		body.CFrame * CFrame.new(1.55, 0.2, 0.25),
		color,
		Enum.PartType.Block,
		Enum.Material.Neon
	)
	rightWing.Rotation = Vector3.new(0, 0, 20)
	weld(root, rightWing)
end

local function addStars(model, root, body, color)
	for i = 1, 7 do
		local angle = (math.pi * 2 / 7) * i
		local x = math.cos(angle) * 2.1
		local z = math.sin(angle) * 2.1

		local star = createPart(
			model,
			"OrbitStar_" .. tostring(i),
			Vector3.new(0.28, 0.28, 0.28),
			body.CFrame * CFrame.new(x, math.random(0, 120) / 100, z),
			color,
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		weld(root, star)
	end
end

local function addGlitchBlocks(model, root, body, color)
	for i = 1, 8 do
		local block = createPart(
			model,
			"GlitchBlock_" .. tostring(i),
			Vector3.new(
				math.random(18, 35) / 100,
				math.random(18, 35) / 100,
				math.random(18, 35) / 100
			),
			body.CFrame * CFrame.new(
				math.random(-180, 180) / 100,
				math.random(-80, 140) / 100,
				math.random(-130, 130) / 100
			),
			color,
			Enum.PartType.Block,
			Enum.Material.Neon
		)
		weld(root, block)
	end
end

local function addStyleAccessories(model, root, body, head, def)
	local style = def.Style

	if style == "Crown" or style == "Treasure" then
		addCrown(model, root, head, def.Accent)
	end

	if style == "Horns" or style == "Demon" or style == "Overlord" then
		addHorns(model, root, head, def.Accent)
	end

	if style == "Angel" or style == "Halo" then
		addHalo(model, root, head, def.Accent)
		addWings(model, root, body, def.Second)
	end

	if style == "Galaxy" or style == "Stars" then
		addStars(model, root, body, def.Second)
	end

	if style == "Glitch" then
		addGlitchBlocks(model, root, body, def.Second)
	end

	if style == "Ice" then
		for i = 1, 4 do
			local crystal = createPart(
				model,
				"IceCrystal_" .. tostring(i),
				Vector3.new(0.28, 0.75, 0.28),
				body.CFrame * CFrame.new((i - 2.5) * 0.35, 1.35, 0.2),
				def.Second,
				Enum.PartType.Block,
				Enum.Material.Neon
			)
			crystal.Rotation = Vector3.new(0, 0, math.random(-30, 30))
			weld(root, crystal)
		end
	end

	if style == "Bucket" then
		local bucket = createPart(
			model,
			"FunnyBucket",
			Vector3.new(1.55, 0.6, 1.55),
			head.CFrame * CFrame.new(0, 0.85, 0),
			Color3.fromRGB(125, 125, 135),
			Enum.PartType.Cylinder,
			Enum.Material.Metal
		)
		weld(root, bucket)
	end

	if style == "Bubble" then
		for i = 1, 6 do
			local bubble = createPart(
				model,
				"Bubble_" .. tostring(i),
				Vector3.new(0.35, 0.35, 0.35),
				body.CFrame * CFrame.new(
					math.random(-170, 170) / 100,
					math.random(-60, 160) / 100,
					math.random(-150, 150) / 100
				),
				def.Second,
				Enum.PartType.Ball,
				Enum.Material.Neon
			)
			bubble.Transparency = 0.35
			weld(root, bubble)
		end
	end
end

local function createBrainrotTemplate(def)
	local stats = RARITY_STATS[def.Rarity] or RARITY_STATS.Common

	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("GeneratedBrainrotNPC", true)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("MPS", stats.MPS)
	model:SetAttribute("SellPrice", stats.SellPrice)
	model:SetAttribute("CaptureMaxHP", stats.CaptureMaxHP)
	model:SetAttribute("CaptureHP", stats.CaptureMaxHP)
	model:SetAttribute("CaptureStunned", false)
	model:SetAttribute("limitRegeneratedAFK", stats.LimitAFK)

	local rootCFrame = CFrame.new(0, 4, 0)

	local root = createPart(
		model,
		"HumanoidRootPart",
		Vector3.new(2, 2, 2),
		rootCFrame,
		Color3.fromRGB(255, 255, 255),
		Enum.PartType.Block
	)
	root.Transparency = 1
	root.Massless = false
	root.CanCollide = false

	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 16
	humanoid.HipHeight = 2
	humanoid.Parent = model

	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	local body = createPart(
		model,
		"Body",
		Vector3.new(2.25, 2.25, 2.25),
		rootCFrame * CFrame.new(0, -0.15, 0),
		def.Main,
		Enum.PartType.Ball
	)
	weld(root, body)

	local head = createPart(
		model,
		"Head",
		Vector3.new(1.75, 1.75, 1.75),
		rootCFrame * CFrame.new(0, 1.55, -0.05),
		def.Second,
		Enum.PartType.Ball
	)
	weld(root, head)

	local leftArm = createPart(
		model,
		"LeftArm",
		Vector3.new(0.55, 1.3, 0.55),
		rootCFrame * CFrame.new(-1.35, 0.05, -0.05),
		def.Accent,
		Enum.PartType.Cylinder
	)
	leftArm.Rotation = Vector3.new(0, 0, 22)
	weld(root, leftArm)

	local rightArm = createPart(
		model,
		"RightArm",
		Vector3.new(0.55, 1.3, 0.55),
		rootCFrame * CFrame.new(1.35, 0.05, -0.05),
		def.Accent,
		Enum.PartType.Cylinder
	)
	rightArm.Rotation = Vector3.new(0, 0, -22)
	weld(root, rightArm)

	local leftLeg = createPart(
		model,
		"LeftLeg",
		Vector3.new(0.55, 1.15, 0.55),
		rootCFrame * CFrame.new(-0.55, -1.55, 0),
		def.Accent,
		Enum.PartType.Cylinder
	)
	weld(root, leftLeg)

	local rightLeg = createPart(
		model,
		"RightLeg",
		Vector3.new(0.55, 1.15, 0.55),
		rootCFrame * CFrame.new(0.55, -1.55, 0),
		def.Accent,
		Enum.PartType.Cylinder
	)
	weld(root, rightLeg)

	local leftFoot = createPart(
		model,
		"LeftFoot",
		Vector3.new(0.75, 0.35, 0.95),
		rootCFrame * CFrame.new(-0.55, -2.2, -0.25),
		def.Second,
		Enum.PartType.Ball
	)
	weld(root, leftFoot)

	local rightFoot = createPart(
		model,
		"RightFoot",
		Vector3.new(0.75, 0.35, 0.95),
		rootCFrame * CFrame.new(0.55, -2.2, -0.25),
		def.Second,
		Enum.PartType.Ball
	)
	weld(root, rightFoot)

	addFace(model, head, root)
	addStyleAccessories(model, root, body, head, def)

	addGlow(head, def.Main, 0.9, 9)

	if def.Rarity ~= "Common" then
		addHighlight(model, def.Main, Color3.fromRGB(255, 255, 255))
	end

	model:PivotTo(CFrame.new(0, 5, 0))

	return model
end

local function clearGeneratedTemplates(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("GeneratedBrainrotNPC") == true then
			child:Destroy()
		end
	end
end

for rarityName in pairs(RARITY_STATS) do
	local rarityFolder = ensureFolder(poolsFolder, rarityName)

	if REBUILD_GENERATED_ONLY then
		clearGeneratedTemplates(rarityFolder)
	end
end

for _, def in ipairs(NPC_DEFINITIONS) do
	local rarityFolder = ensureFolder(poolsFolder, def.Rarity)

	local existing = rarityFolder:FindFirstChild(def.Name)
	if existing then
		existing:Destroy()
	end

	local template = createBrainrotTemplate(def)
	template.Parent = rarityFolder

	print("[BrainrotTemplateBuilder] Created:", def.Rarity, def.Name)
end

print("[BrainrotTemplateBuilder] Done. You can now disable/delete this script.")