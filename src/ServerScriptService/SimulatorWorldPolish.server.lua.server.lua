--!nonstrict
-- SimulatorWorldPolish.server.lua
-- Put in: ServerScriptService
-- Creates a colorful cartoon simulator hub without touching your gameplay systems.

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local ROOT_NAME = "SimulatorVisualPolish"

local function ensureEffect(className, name, props)
	local existing = Lighting:FindFirstChild(name)

	if existing and existing.ClassName ~= className then
		existing:Destroy()
		existing = nil
	end

	local effect = existing or Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting

	for property, value in pairs(props) do
		pcall(function()
			effect[property] = value
		end)
	end

	return effect
end

local function applyLighting()
	Lighting.Brightness = 3
	Lighting.ClockTime = 14.2
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(145, 170, 210)
	Lighting.OutdoorAmbient = Color3.fromRGB(180, 210, 255)
	Lighting.FogColor = Color3.fromRGB(180, 230, 255)
	Lighting.FogStart = 300
	Lighting.FogEnd = 1000

	ensureEffect("Atmosphere", "CartoonAtmosphere", {
		Density = 0.22,
		Offset = 0.1,
		Color = Color3.fromRGB(190, 230, 255),
		Decay = Color3.fromRGB(90, 140, 200),
		Glare = 0.3,
		Haze = 0.8,
	})

	ensureEffect("BloomEffect", "CartoonBloom", {
		Intensity = 0.55,
		Size = 24,
		Threshold = 1.35,
	})

	ensureEffect("ColorCorrectionEffect", "CartoonColors", {
		Brightness = 0.08,
		Contrast = 0.18,
		Saturation = 0.35,
		TintColor = Color3.fromRGB(255, 250, 235),
	})

	ensureEffect("SunRaysEffect", "CartoonSunRays", {
		Intensity = 0.08,
		Spread = 0.85,
	})
end

local function getMapCenter()
	local spawnMap = Workspace:FindFirstChild("SpawnMap")

	if spawnMap then
		local ground = spawnMap:FindFirstChild("GroundBase", true)
		if ground and ground:IsA("BasePart") then
			return ground.Position + Vector3.new(0, ground.Size.Y / 2 + 0.1, 0)
		end

		local base = spawnMap:FindFirstChild("Base", true)
		if base and base:IsA("BasePart") then
			return base.Position + Vector3.new(0, base.Size.Y / 2 + 0.1, 0)
		end
	end

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		return baseplate.Position + Vector3.new(0, baseplate.Size.Y / 2 + 0.1, 0)
	end

	return Vector3.new(0, 3, 0)
end

local old = Workspace:FindFirstChild(ROOT_NAME)
if old then
	old:Destroy()
end

local root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = Workspace

local center = getMapCenter()

local function makePart(name, size, cf, color, material, shape, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.Transparency = transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = root
	return part
end

local function addCornerLight(part, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness or 1
	light.Range = range or 12
	light.Parent = part
	return light
end

local function makeBillboard(part, title, subtitle, titleColor)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CartoonLabel"
	gui.Size = UDim2.new(0, 260, 0, 95)
	gui.StudsOffset = Vector3.new(0, 4.8, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	gui.Parent = part

	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 0, 54)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.Text = title
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = titleColor or Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 5
	stroke.Parent = titleLabel

	local subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Size = UDim2.new(1, 0, 0, 34)
	subLabel.Position = UDim2.new(0, 0, 0, 50)
	subLabel.Text = subtitle or ""
	subLabel.Font = Enum.Font.FredokaOne
	subLabel.TextScaled = true
	subLabel.TextColor3 = Color3.fromRGB(255, 235, 80)
	subLabel.TextXAlignment = Enum.TextXAlignment.Center
	subLabel.TextYAlignment = Enum.TextYAlignment.Center
	subLabel.Parent = holder

	local subStroke = Instance.new("UIStroke")
	subStroke.Color = Color3.fromRGB(0, 0, 0)
	subStroke.Thickness = 3
	subStroke.Parent = subLabel
end

local function makeSign(name, pos, title, subtitle, color)
	local post = makePart(
		name .. "_Post",
		Vector3.new(2, 9, 2),
		CFrame.new(pos + Vector3.new(0, 4.5, 0)),
		Color3.fromRGB(120, 75, 35),
		Enum.Material.Wood
	)

	local board = makePart(
		name,
		Vector3.new(20, 6, 2),
		CFrame.new(pos + Vector3.new(0, 10, 0)),
		color,
		Enum.Material.SmoothPlastic
	)

	makeBillboard(board, title, subtitle, Color3.fromRGB(255, 255, 255))
	return board
end

local function makePath(name, a, b, width)
	local delta = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local dist = delta.Magnitude

	if dist < 2 then
		return
	end

	local mid = (a + b) / 2
	local y = center.Y + 0.08

	local path = makePart(
		name,
		Vector3.new(width or 10, 0.35, dist),
		CFrame.new(Vector3.new(mid.X, y, mid.Z), Vector3.new(b.X, y, b.Z)),
		Color3.fromRGB(255, 218, 155),
		Enum.Material.SmoothPlastic
	)

	local stroke = makePart(
		name .. "_Trim",
		Vector3.new((width or 10) + 1.5, 0.18, dist + 1),
		CFrame.new(Vector3.new(mid.X, y - 0.08, mid.Z), Vector3.new(b.X, y - 0.08, b.Z)),
		Color3.fromRGB(210, 155, 95),
		Enum.Material.SmoothPlastic
	)

	stroke.CanCollide = false
	return path
end

local function makeTree(pos)
	local trunk = makePart(
		"CartoonTree_Trunk",
		Vector3.new(3, 9, 3),
		CFrame.new(pos + Vector3.new(0, 4.5, 0)),
		Color3.fromRGB(120, 75, 35),
		Enum.Material.Wood
	)

	local leaves1 = makePart(
		"CartoonTree_Leaves",
		Vector3.new(11, 11, 11),
		CFrame.new(pos + Vector3.new(0, 11, 0)),
		Color3.fromRGB(75, 210, 70),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)

	local leaves2 = makePart(
		"CartoonTree_Leaves",
		Vector3.new(8, 8, 8),
		CFrame.new(pos + Vector3.new(4, 14, 0)),
		Color3.fromRGB(95, 230, 75),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)

	return trunk, leaves1, leaves2
end

local function makeGem(pos, color)
	local gem = makePart(
		"FloatingGem",
		Vector3.new(3, 3, 3),
		CFrame.new(pos),
		color,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)

	gem.CanCollide = false
	addCornerLight(gem, color, 1.6, 14)
	return gem
end

local function makeCoin(pos)
	local coin = makePart(
		"FloatingCoin",
		Vector3.new(2.3, 0.35, 2.3),
		CFrame.new(pos),
		Color3.fromRGB(255, 205, 35),
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)

	coin.CanCollide = false
	addCornerLight(coin, Color3.fromRGB(255, 220, 80), 1, 10)
	return coin
end

local function makeEgg(pos, color, name)
	local egg = makePart(
		name or "PetEgg",
		Vector3.new(5, 6, 5),
		CFrame.new(pos),
		color,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)

	addCornerLight(egg, color, 1.3, 12)
	return egg
end

local function makeDumbbell(pos)
	local bar = makePart(
		"GiantDumbbell_Bar",
		Vector3.new(0.7, 15, 0.7),
		CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(40, 55, 75),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)

	local left = makePart(
		"GiantDumbbell_Weight",
		Vector3.new(5, 2.2, 5),
		CFrame.new(pos + Vector3.new(-8, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(60, 150, 255),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)

	local right = makePart(
		"GiantDumbbell_Weight",
		Vector3.new(5, 2.2, 5),
		CFrame.new(pos + Vector3.new(8, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(60, 150, 255),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)

	addCornerLight(left, Color3.fromRGB(60, 160, 255), 1, 14)
	addCornerLight(right, Color3.fromRGB(60, 160, 255), 1, 14)

	return bar, left, right
end

local function makePortal(pos)
	local base = makePart(
		"NextWorldPortal_Base",
		Vector3.new(22, 2, 8),
		CFrame.new(pos + Vector3.new(0, 1, 0)),
		Color3.fromRGB(80, 60, 120),
		Enum.Material.SmoothPlastic
	)

	local portal = makePart(
		"NextWorldPortal_Glow",
		Vector3.new(16, 1, 16),
		CFrame.new(pos + Vector3.new(0, 10, 0)) * CFrame.Angles(math.rad(90), 0, 0),
		Color3.fromRGB(40, 220, 255),
		Enum.Material.Neon,
		Enum.PartType.Cylinder,
		0.18
	)

	portal.CanCollide = false
	addCornerLight(portal, Color3.fromRGB(40, 220, 255), 4, 35)

	makePart(
		"NextWorldPortal_LeftPillar",
		Vector3.new(3, 18, 3),
		CFrame.new(pos + Vector3.new(-10, 9, 0)),
		Color3.fromRGB(115, 85, 165),
		Enum.Material.SmoothPlastic
	)

	makePart(
		"NextWorldPortal_RightPillar",
		Vector3.new(3, 18, 3),
		CFrame.new(pos + Vector3.new(10, 9, 0)),
		Color3.fromRGB(115, 85, 165),
		Enum.Material.SmoothPlastic
	)

	local sign = makePart(
		"NextWorldPortal_Sign",
		Vector3.new(24, 5, 3),
		CFrame.new(pos + Vector3.new(0, 20, 0)),
		Color3.fromRGB(255, 165, 35),
		Enum.Material.SmoothPlastic
	)

	makeBillboard(sign, "NEXT WORLD", "???", Color3.fromRGB(255, 255, 255))
end

local function makeShop(pos)
	local base = makePart(
		"UpgradeShop_Base",
		Vector3.new(22, 10, 18),
		CFrame.new(pos + Vector3.new(0, 5, 0)),
		Color3.fromRGB(255, 225, 160),
		Enum.Material.SmoothPlastic
	)

	local roof = makePart(
		"UpgradeShop_Roof",
		Vector3.new(26, 5, 22),
		CFrame.new(pos + Vector3.new(0, 12.5, 0)),
		Color3.fromRGB(255, 65, 65),
		Enum.Material.SmoothPlastic
	)

	local door = makePart(
		"UpgradeShop_Door",
		Vector3.new(6, 7, 1),
		CFrame.new(pos + Vector3.new(0, 3.5, -9.5)),
		Color3.fromRGB(120, 70, 35),
		Enum.Material.Wood
	)

	local sign = makePart(
		"UpgradeShop_Sign",
		Vector3.new(22, 5, 2),
		CFrame.new(pos + Vector3.new(0, 17, -10)),
		Color3.fromRGB(255, 80, 80),
		Enum.Material.SmoothPlastic
	)

	makeBillboard(sign, "SHOP", "UPGRADES!", Color3.fromRGB(255, 255, 255))
	return base, roof, door
end

local function makeBrainrotPlaza(pos)
	local fountainBase = makePart(
		"BrainrotPlaza_Fountain",
		Vector3.new(18, 2, 18),
		CFrame.new(pos + Vector3.new(0, 1, 0)),
		Color3.fromRGB(150, 210, 255),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)

	local crystal = makeGem(pos + Vector3.new(0, 6, 0), Color3.fromRGB(180, 70, 255))

	makePart(
		"BrainrotPlaza_LeftPost",
		Vector3.new(4, 15, 4),
		CFrame.new(pos + Vector3.new(-15, 7.5, 0)),
		Color3.fromRGB(185, 145, 90),
		Enum.Material.SmoothPlastic
	)

	makePart(
		"BrainrotPlaza_RightPost",
		Vector3.new(4, 15, 4),
		CFrame.new(pos + Vector3.new(15, 7.5, 0)),
		Color3.fromRGB(185, 145, 90),
		Enum.Material.SmoothPlastic
	)

	local arch = makePart(
		"BrainrotPlaza_Arch",
		Vector3.new(36, 6, 4),
		CFrame.new(pos + Vector3.new(0, 17, 0)),
		Color3.fromRGB(140, 85, 255),
		Enum.Material.SmoothPlastic
	)

	makeBillboard(arch, "BRAINROT PLAZA", "Find • Catch • Train", Color3.fromRGB(255, 255, 255))

	return fountainBase, crystal, arch
end

local function makeTrainingZone(pos)
	makeSign(
		"TrainingZoneSign",
		pos + Vector3.new(0, 0, -14),
		"TRAINING",
		"GET STRONGER!",
		Color3.fromRGB(65, 145, 255)
	)

	makeDumbbell(pos)

	for i = -1, 1 do
		makePart(
			"TrainingPad",
			Vector3.new(7, 0.8, 7),
			CFrame.new(pos + Vector3.new(i * 9, 0.4, 12)),
			Color3.fromRGB(70, 210, 255),
			Enum.Material.Neon,
			Enum.PartType.Cylinder,
			0.1
		)
	end
end

local function makeEggZone(pos)
	makeSign(
		"PetEggZoneSign",
		pos + Vector3.new(0, 0, -14),
		"PET EGGS",
		"HATCH & COLLECT!",
		Color3.fromRGB(190, 80, 255)
	)

	makeEgg(pos + Vector3.new(-8, 3, 0), Color3.fromRGB(255, 235, 90), "GoldenEgg")
	makeEgg(pos + Vector3.new(0, 3, 0), Color3.fromRGB(80, 170, 255), "BlueEgg")
	makeEgg(pos + Vector3.new(8, 3, 0), Color3.fromRGB(255, 90, 220), "PinkEgg")
end

local function makeHideSeekZone(pos)
	makeSign(
		"HideSeekZoneSign",
		pos,
		"HIDE & SEEK",
		"Collect cute NPCs!",
		Color3.fromRGB(85, 210, 80)
	)

	for i = 1, 5 do
		local offset = Vector3.new(math.random(-14, 14), 2, math.random(8, 22))
		local color = Color3.fromRGB(math.random(80, 255), math.random(120, 255), math.random(80, 255))

		local npc = makePart(
			"DecorBrainrotNPC",
			Vector3.new(4, 4, 4),
			CFrame.new(pos + offset),
			color,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)

		makeBillboard(npc, "NPC", "find me!", Color3.fromRGB(255, 255, 255))
	end
end

local function makeMyPlotZone(pos)
	makeSign(
		"MyPlotZoneSign",
		pos,
		"MY PLOT",
		"Your NPC home!",
		Color3.fromRGB(120, 85, 45)
	)

	local house = makePart(
		"DecorPlotHouse_Base",
		Vector3.new(20, 11, 18),
		CFrame.new(pos + Vector3.new(0, 5.5, 16)),
		Color3.fromRGB(255, 230, 170),
		Enum.Material.SmoothPlastic
	)

	local roof = makePart(
		"DecorPlotHouse_Roof",
		Vector3.new(24, 5, 22),
		CFrame.new(pos + Vector3.new(0, 13.5, 16)),
		Color3.fromRGB(230, 75, 50),
		Enum.Material.SmoothPlastic
	)

	return house, roof
end

local function scatterRewards()
	for i = 1, 18 do
		local angle = (math.pi * 2 / 18) * i
		local radius = math.random(18, 58)
		local pos = center + Vector3.new(math.cos(angle) * radius, 2.2, math.sin(angle) * radius)

		if i % 3 == 0 then
			makeGem(pos, Color3.fromRGB(60, 220, 255))
		else
			makeCoin(pos)
		end
	end
end

local function scatterTrees()
	local positions = {
		Vector3.new(-70, 0, -50),
		Vector3.new(-62, 0, 44),
		Vector3.new(68, 0, -42),
		Vector3.new(72, 0, 46),
		Vector3.new(-35, 0, 62),
		Vector3.new(38, 0, 64),
		Vector3.new(-78, 0, 8),
		Vector3.new(82, 0, 12),
	}

	for _, offset in ipairs(positions) do
		makeTree(center + offset)
	end
end

applyLighting()

local plazaPos = center + Vector3.new(0, 0, 0)
local trainingPos = center + Vector3.new(-48, 0, -8)
local shopPos = center + Vector3.new(-25, 0, -42)
local eggPos = center + Vector3.new(36, 0, -38)
local portalPos = center + Vector3.new(66, 0, 4)
local hideSeekPos = center + Vector3.new(-52, 0, 38)
local plotPos = center + Vector3.new(38, 0, 38)

makePart(
	"MainPlaza",
	Vector3.new(58, 0.45, 58),
	CFrame.new(plazaPos + Vector3.new(0, 0.05, 0)),
	Color3.fromRGB(235, 190, 135),
	Enum.Material.SmoothPlastic,
	Enum.PartType.Cylinder
)

makePath("Path_To_Training", plazaPos, trainingPos, 10)
makePath("Path_To_Shop", plazaPos, shopPos, 10)
makePath("Path_To_Eggs", plazaPos, eggPos, 10)
makePath("Path_To_Portal", plazaPos, portalPos, 10)
makePath("Path_To_HideSeek", plazaPos, hideSeekPos, 10)
makePath("Path_To_Plot", plazaPos, plotPos, 10)

makeBrainrotPlaza(plazaPos)
makeTrainingZone(trainingPos)
makeShop(shopPos)
makeEggZone(eggPos)
makePortal(portalPos)
makeHideSeekZone(hideSeekPos)
makeMyPlotZone(plotPos)

scatterRewards()
scatterTrees()

print("[SimulatorWorldPolish] Cartoon simulator world polish loaded")