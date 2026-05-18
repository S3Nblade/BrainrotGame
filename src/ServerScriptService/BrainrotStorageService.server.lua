--!strict
-- BrainrotStorageService: simple server-side brainrot spawning + storing onto the owner's plot storage pad.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local REMOTES_FOLDER_NAME = "Remotes"
local SPAWN_BRAINROT_EVENT = "SpawnBrainrot"

-- Where the map plots are
local SPAWNMAP_NAME = "SpawnMap"
local PLOTS_NAME = "Plots"

local function getPlotsContainer(): Instance?
	local spawnMap = Workspace:FindFirstChild(SPAWNMAP_NAME)
	if not spawnMap then return nil end
	return spawnMap:FindFirstChild(PLOTS_NAME)
end

local function findPlotByOwner(userId: number): Instance?
	local plotsContainer = getPlotsContainer()
	if not plotsContainer then return nil end

	for _, plot in plotsContainer:GetChildren() do
		local ownerId = plot:GetAttribute("OwnerUserId")
		if type(ownerId) == "number" and ownerId == userId then
			return plot
		end
	end
	return nil
end

local function getStoragePad(plot: Instance): BasePart?
	local pad = plot:FindFirstChild("StoragePad")
	if pad and pad:IsA("BasePart") then
		return pad
	end
	-- fallback: look for attribute
	for _, d in plot:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("BrainrotStorage") == true then
			return d
		end
	end
	return nil
end

local function getOrCreatePlayerFolder(userId: number): Folder
	local root = Workspace:FindFirstChild("BrainrotStorage")
	if not root then
		root = Instance.new("Folder")
		root.Name = "BrainrotStorage"
		root.Parent = Workspace
	end
	local f = root:FindFirstChild(tostring(userId))
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = tostring(userId)
	nf.Parent = root
	return nf
end

local function computeNextPlacement(pad: BasePart, index: number): CFrame
	-- place items in a simple grid on the pad
	local cols = 4
	local spacing = 6
	local col = (index - 1) % cols
	local row = math.floor((index - 1) / cols)

	local localX = (col - (cols-1)/2) * spacing
	local localZ = (row - 0) * spacing

	return pad.CFrame * CFrame.new(localX, (pad.Size.Y/2) + 2.5, localZ)
end

local function createBrainrotModel(kind: string): Model
	-- Placeholder "brainrot" (cartoony)
	local m = Instance.new("Model")
	m.Name = kind

	local base = Instance.new("Part")	
	base.Name = "Brainrot"
	base.Anchored = true
	base.Size = Vector3.new(4, 4, 4)
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(255, 140, 220)
	base.Shape = Enum.PartType.Ball
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent = m

	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	-- no external asset links; leave blank for now
	face.Texture = ""
	face.Parent = base

	m.PrimaryPart = base
	return m
end

-- NOTE: Old press-B spawning has been removed.
-- Brainrots are now acquired by interacting with walking NPCs (see BrainrotNpcService).
