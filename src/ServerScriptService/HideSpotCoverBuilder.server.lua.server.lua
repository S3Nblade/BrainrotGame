--!nonstrict
-- HideSpotCoverBuilder.server.lua
-- Creates 3D mesh-style bushes, rocks, logs, and hidden cover
-- from parts inside Workspace.HideSpots.

local Workspace = game:GetService("Workspace")

local HIDE_SPOTS_FOLDER_NAME = "HideSpots"
local OUTPUT_FOLDER_NAME = "GeneratedHidePlaces"

local REBUILD_ON_START = true
local HIDE_MARKER_PARTS = true
local RANDOM_SEED = 55210

local hideSpotsFolder = Workspace:WaitForChild(HIDE_SPOTS_FOLDER_NAME)

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

local outputFolder = ensureFolder(Workspace, OUTPUT_FOLDER_NAME)

if REBUILD_ON_START then
	outputFolder:ClearAllChildren()
end

math.randomseed(RANDOM_SEED)

local LEAF_COLORS = {
	Color3.fromRGB(35, 145, 65),
	Color3.fromRGB(45, 185, 75),
	Color3.fromRGB(65, 225, 90),
	Color3.fromRGB(90, 245, 105),
}

local DARK_LEAF_COLORS = {
	Color3.fromRGB(20, 105, 45),
	Color3.fromRGB(25, 130, 55),
	Color3.fromRGB(35, 160, 65),
}

local FLOWER_COLORS = {
	Color3.fromRGB(255, 90, 160),
	Color3.fromRGB(255, 225, 70),
	Color3.fromRGB(95, 220, 255),
	Color3.fromRGB(210, 120, 255),
}

local ROCK_COLORS = {
	Color3.fromRGB(85, 90, 100),
	Color3.fromRGB(105, 110, 120),
	Color3.fromRGB(130, 135, 145),
}

local function pick(list)
	return list[math.random(1, #list)]
end

local function createBasePart(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent

	return part
end

local function createMeshBlob(parent, name, position, scale, color)
	local part = createBasePart(
		parent,
		name,
		Vector3.new(1, 1, 1),
		CFrame.new(position)
			* CFrame.Angles(
				math.rad(math.random(-10, 10)),
				math.rad(math.random(0, 360)),
				math.rad(math.random(-10, 10))
			),
		color,
		Enum.Material.Grass
	)

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(
		math.random(150, 260) / 100 * scale,
		math.random(115, 210) / 100 * scale,
		math.random(150, 260) / 100 * scale
	)
	mesh.Parent = part

	return part
end

local function createLeafSpike(parent, name, position, rotation, scale, color)
	local part = createBasePart(
		parent,
		name,
		Vector3.new(1, 1, 1),
		CFrame.new(position) * rotation,
		color,
		Enum.Material.Grass
	)

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Wedge
	mesh.Scale = Vector3.new(
		0.75 * scale,
		0.8 * scale,
		1.35 * scale
	)
	mesh.Parent = part

	return part
end

local function createRockBlob(parent, name, position, scale)
	local part = createBasePart(
		parent,
		name,
		Vector3.new(1, 1, 1),
		CFrame.new(position)
			* CFrame.Angles(
				math.rad(math.random(-15, 15)),
				math.rad(math.random(0, 360)),
				math.rad(math.random(-15, 15))
			),
		pick(ROCK_COLORS),
		Enum.Material.Slate
	)

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(
		math.random(80, 150) / 100 * scale,
		math.random(55, 115) / 100 * scale,
		math.random(80, 160) / 100 * scale
	)
	mesh.Parent = part

	return part
end

local function getGroundPosition(worldPosition)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		hideSpotsFolder,
		outputFolder,
	}

	local result = Workspace:Raycast(
		worldPosition + Vector3.new(0, 80, 0),
		Vector3.new(0, -180, 0),
		params
	)

	if result then
		return result.Position
	end

	return worldPosition
end

local function randomPointInside(marker)
	local x = math.random(-marker.Size.X * 50, marker.Size.X * 50) / 100
	local z = math.random(-marker.Size.Z * 50, marker.Size.Z * 50) / 100

	return getGroundPosition(marker.CFrame:PointToWorldSpace(Vector3.new(x, 0, z)))
end

local function makeTrunk(model, center, scale)
	local trunk = createBasePart(
		model,
		"BushTrunk",
		Vector3.new(0.45 * scale, 1.1 * scale, 0.45 * scale),
		CFrame.new(center + Vector3.new(0, 0.55 * scale, 0)),
		Color3.fromRGB(105, 70, 35),
		Enum.Material.Wood
	)

	trunk.Shape = Enum.PartType.Cylinder
	trunk.Orientation = Vector3.new(0, 0, 0)

	return trunk
end

local function makeMainBush(model, center, scale)
	makeTrunk(model, center, scale)

	createMeshBlob(
		model,
		"MainLeafCore",
		center + Vector3.new(0, 1.55 * scale, 0),
		1.35 * scale,
		pick(LEAF_COLORS)
	)

	local blobs = math.random(7, 11)

	for i = 1, blobs do
		local angle = (math.pi * 2 / blobs) * i
		local radius = math.random(55, 115) / 100 * scale

		local pos = center + Vector3.new(
			math.cos(angle) * radius,
			math.random(90, 190) / 100 * scale,
			math.sin(angle) * radius
		)

		createMeshBlob(
			model,
			"LeafBlob_" .. tostring(i),
			pos,
			math.random(75, 115) / 100 * scale,
			pick(LEAF_COLORS)
		)
	end

	local spikes = math.random(8, 12)

	for i = 1, spikes do
		local angle = (math.pi * 2 / spikes) * i
		local radius = math.random(110, 160) / 100 * scale

		local pos = center + Vector3.new(
			math.cos(angle) * radius,
			math.random(90, 145) / 100 * scale,
			math.sin(angle) * radius
		)

		local rotation =
			CFrame.Angles(0, -angle, 0)
			* CFrame.Angles(math.rad(math.random(-20, 20)), 0, math.rad(math.random(-22, 22)))

		createLeafSpike(
			model,
			"OuterLeaf_" .. tostring(i),
			pos,
			rotation,
			math.random(60, 90) / 100 * scale,
			pick(DARK_LEAF_COLORS)
		)
	end
end

local function makeFlowers(model, center, scale)
	local amount = math.random(4, 8)

	for i = 1, amount do
		local pos = center + Vector3.new(
			math.random(-165, 165) / 100 * scale,
			math.random(175, 245) / 100 * scale,
			math.random(-165, 165) / 100 * scale
		)

		local flower = createMeshBlob(
			model,
			"Flower_" .. tostring(i),
			pos,
			0.18 * scale,
			pick(FLOWER_COLORS)
		)

		flower.Material = Enum.Material.Neon
	end
end

local function makeRocks(model, center, scale)
	local amount = math.random(3, 6)

	for i = 1, amount do
		local pos = center + Vector3.new(
			math.random(-220, 220) / 100 * scale,
			0.35 * scale,
			math.random(-220, 220) / 100 * scale
		)

		createRockBlob(model, "Rock_" .. tostring(i), pos, math.random(70, 120) / 100 * scale)
	end
end

local function makeLog(model, center, scale)
	local angle = math.rad(math.random(0, 360))

	local log = createBasePart(
		model,
		"HidingLog",
		Vector3.new(0.65 * scale, 3.4 * scale, 0.65 * scale),
		CFrame.new(center + Vector3.new(0, 0.55 * scale, 0))
			* CFrame.Angles(0, angle, math.rad(90)),
		Color3.fromRGB(125, 75, 35),
		Enum.Material.Wood
	)

	log.Shape = Enum.PartType.Cylinder

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Cylinder
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = log
end

local function addHideAnchor(model, marker, center)
	local anchor = createBasePart(
		model,
		"HideSpotAnchor",
		Vector3.new(1, 1, 1),
		CFrame.new(center + Vector3.new(0, 1.1, 0)),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic
	)

	anchor.Transparency = 1
	anchor.CanQuery = false
	anchor:SetAttribute("HideSpotMarkerName", marker.Name)
end

local function decorateMarker(marker, index)
	if not marker:IsA("BasePart") then
		return
	end

	local model = Instance.new("Model")
	model.Name = "MeshBushHidePlace_" .. tostring(index) .. "_" .. marker.Name
	model.Parent = outputFolder

	local center = getGroundPosition(marker.Position)
	local scale = math.random(95, 140) / 100

	makeMainBush(model, center, scale)
	makeFlowers(model, center, scale)

	local styleRoll = math.random(1, 3)

	if styleRoll == 1 then
		makeRocks(model, randomPointInside(marker), scale * 0.8)
	elseif styleRoll == 2 then
		makeLog(model, randomPointInside(marker), scale * 0.85)
	else
		makeRocks(model, randomPointInside(marker), scale * 0.7)
		makeLog(model, randomPointInside(marker), scale * 0.7)
	end

	addHideAnchor(model, marker, center)

	if HIDE_MARKER_PARTS then
		marker.Transparency = 1
		marker.CanCollide = false
		marker.CanTouch = false
		marker.CanQuery = false
	end

	marker:SetAttribute("GeneratedHideCover", true)
end

local function buildAll()
	if REBUILD_ON_START then
		outputFolder:ClearAllChildren()
	end

	local count = 0

	for _, marker in ipairs(hideSpotsFolder:GetChildren()) do
		if marker:IsA("BasePart") then
			count += 1
			decorateMarker(marker, count)
		end
	end

	print("[HideSpotCoverBuilder] Built", count, "3D mesh-style bush hide places")
end

buildAll()

hideSpotsFolder.ChildAdded:Connect(function(child)
	task.wait(0.2)

	if child:IsA("BasePart") then
		buildAll()
	end
end)

hideSpotsFolder.ChildRemoved:Connect(function()
	task.wait(0.2)
	buildAll()
end)