local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local MapService = {}
local context
local world
local plotsFolder
local claimedPlots = {}

local function part(name, size, position, color, parent)
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.Size = size
	item.Position = position
	item.Color = color
	item.Material = Enum.Material.SmoothPlastic
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

local function label(adornee, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PixelLabel"
	gui.Adornee = adornee
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(230, 52)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.Parent = adornee
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundColor3 = Color3.fromRGB(25, 28, 42)
	textLabel.BackgroundTransparency = 0.08
	textLabel.BorderSizePixel = 0
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.6
	textLabel.Font = Enum.Font.GothamBlack
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = textLabel
end

local function buildZone(zoneId, zone)
	local folder = Instance.new("Folder")
	folder.Name = zoneId
	folder.Parent = world.Zones
	local floor = part("Floor", Vector3.new(zone.Size.X, 1, zone.Size.Y), zone.Center, zone.TileColor, folder)
	floor:SetAttribute("ZoneId", zoneId)
	for x = -zone.Size.X / 2 + 8, zone.Size.X / 2 - 8, 16 do
		for z = -zone.Size.Y / 2 + 8, zone.Size.Y / 2 - 8, 16 do
			if (math.floor(x / 16) + math.floor(z / 16)) % 2 == 0 then
				part(
					"Tile",
					Vector3.new(15.7, 0.12, 15.7),
					zone.Center + Vector3.new(x, 0.56, z),
					zone.AccentColor,
					folder
				)
			end
		end
	end
	local sign = part(
		"ZoneSign",
		Vector3.new(22, 1, 5),
		zone.Center + Vector3.new(0, 2, -zone.Size.Y / 2 + 8),
		zone.AccentColor,
		folder
	)
	label(sign, zone.DisplayName, Color3.new(1, 1, 1))
	local spawnRegion = part(
		"SpawnRegion",
		Vector3.new(zone.Size.X - 20, 1, zone.Size.Y - 28),
		zone.Center + Vector3.new(0, 1, 5),
		zone.TileColor,
		folder
	)
	spawnRegion.Transparency = 1
	spawnRegion.CanCollide = false
	CollectionService:AddTag(spawnRegion, "BrainrotSpawnRegion")
	spawnRegion:SetAttribute("ZoneId", zoneId)
end

local function buildGate(zoneId, zone, previous)
	local midpoint = (zone.Center + previous.Center) / 2
	local gate =
		part(zoneId .. "Gate", Vector3.new(5, 12, 90), midpoint + Vector3.new(0, 6, 0), zone.AccentColor, world.Gates)
	gate.Transparency = 0.18
	gate:SetAttribute("ZoneId", zoneId)
	CollectionService:AddTag(gate, "ZoneGate")
	label(
		gate,
		string.format("%s\n$%s", zone.DisplayName, context.Util.FormatNumber(zone.UnlockCost)),
		Color3.new(1, 1, 1)
	)
end

local function buildPlots()
	for index = 1, 8 do
		local origin = Vector3.new((index - 1) * 68, 0, -105)
		local model = Instance.new("Model")
		model.Name = "Plot" .. index
		model:SetAttribute("PlotIndex", index)
		model.Parent = plotsFolder
		local floor = part("Floor", Vector3.new(60, 1, 46), origin, Color3.fromRGB(54, 61, 82), model)
		model.PrimaryPart = floor
		local sign =
			part("Sign", Vector3.new(18, 1, 4), origin + Vector3.new(0, 2, -18), Color3.fromRGB(93, 98, 130), model)
		label(sign, "Unclaimed Plot", Color3.new(1, 1, 1))
		for standIndex = 1, context.Config.Economy.PlotStandCount do
			local column = (standIndex - 1) % 3
			local row = math.floor((standIndex - 1) / 3)
			local stand = part(
				"Stand" .. standIndex,
				Vector3.new(14, 1.5, 12),
				origin + Vector3.new((column - 1) * 18, 1, row * 17 - 3),
				Color3.fromRGB(118, 124, 160),
				model
			)
			stand:SetAttribute("StandIndex", standIndex)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "CollectPrompt"
			prompt.ActionText = "Collect"
			prompt.ObjectText = "Stand " .. standIndex
			prompt.KeyboardKeyCode = Enum.KeyCode.F
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = stand
			CollectionService:AddTag(stand, "PlotStand")
		end
	end
end

function MapService.Init(newContext)
	context = newContext
	world = Instance.new("Folder")
	world.Name = "PixelWorld"
	world.Parent = workspace
	for _, name in ipairs({ "Zones", "Gates", "Brainrots", "Effects", "Plots" }) do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = world
	end
	plotsFolder = world.Plots
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = context.Config.Zones.Grass.Center + Vector3.new(0, 2, -35)
	spawn.Color = Color3.fromRGB(255, 232, 91)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = world
	for index, zoneId in ipairs(context.Config.Zones.Order) do
		local zone = context.Config.Zones[zoneId]
		buildZone(zoneId, zone)
		if index > 1 then
			buildGate(zoneId, zone, context.Config.Zones[context.Config.Zones.Order[index - 1]])
		end
	end
	buildPlots()
end

function MapService.GetWorld()
	return world
end

function MapService.GetZoneAt(position)
	for _, zoneId in ipairs(context.Config.Zones.Order) do
		local zone = context.Config.Zones[zoneId]
		if
			math.abs(position.X - zone.Center.X) <= zone.Size.X / 2
			and math.abs(position.Z - zone.Center.Z) <= zone.Size.Y / 2
		then
			return zoneId
		end
	end
	return nil
end

function MapService.ClaimPlot(player)
	if claimedPlots[player] then
		return claimedPlots[player]
	end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if not plot:GetAttribute("OwnerUserId") then
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot.Sign.PixelLabel.TextLabel.Text = player.DisplayName .. "'s Plot"
			claimedPlots[player] = plot
			return plot
		end
	end
end

function MapService.GetPlot(player)
	return claimedPlots[player]
end

function MapService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.defer(MapService.ClaimPlot, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local plot = claimedPlots[player]
		if plot then
			plot:SetAttribute("OwnerUserId", nil)
			plot.Sign.PixelLabel.TextLabel.Text = "Unclaimed Plot"
		end
		claimedPlots[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.defer(MapService.ClaimPlot, player)
	end
end

return MapService
