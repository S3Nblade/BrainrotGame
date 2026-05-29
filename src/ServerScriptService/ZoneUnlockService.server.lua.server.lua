--!nonstrict
-- ZoneUnlockService.server.lua
-- Put in: ServerScriptService
-- Speed-based zone unlock system for your simulator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local zoneStore = DataStoreService:GetDataStore("PlayerZones_v1")

local PORTAL_FOLDER_NAME = "ZonePortals"

-- Turn this to false after you move/design your own portals.
local AUTO_CREATE_DEMO_PORTALS = true
local REQUEST_COOLDOWN_SECONDS = 0.75
local REMOTE_PORTAL_DISTANCE = 24

local DEFAULT_ZONES = {
	{
		Id = "Starter",
		DisplayName = "Starter Zone",
		RequiredSpeed = 0,
		Color = Color3.fromRGB(120, 255, 90),
		PortalPosition = Vector3.new(0, 5, 0),
		DestinationPosition = Vector3.new(0, 6, 0),
	},
	{
		Id = "Forest",
		DisplayName = "Forest Zone",
		RequiredSpeed = 500,
		Color = Color3.fromRGB(75, 255, 80),
		PortalPosition = Vector3.new(0, 5, -90),
		DestinationPosition = Vector3.new(0, 6, -165),
	},
	{
		Id = "Crystal",
		DisplayName = "Crystal Zone",
		RequiredSpeed = 2500,
		Color = Color3.fromRGB(60, 220, 255),
		PortalPosition = Vector3.new(80, 5, -90),
		DestinationPosition = Vector3.new(80, 6, -165),
	},
	{
		Id = "Lava",
		DisplayName = "Lava Zone",
		RequiredSpeed = 10000,
		Color = Color3.fromRGB(255, 95, 45),
		PortalPosition = Vector3.new(-80, 5, -90),
		DestinationPosition = Vector3.new(-80, 6, -165),
	},
	{
		Id = "Galaxy",
		DisplayName = "Galaxy Zone",
		RequiredSpeed = 50000,
		Color = Color3.fromRGB(175, 80, 255),
		PortalPosition = Vector3.new(0, 5, -230),
		DestinationPosition = Vector3.new(0, 6, -320),
	},
}

local function loadZones()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("ZoneConfig")

	if module and module:IsA("ModuleScript") then
		local ok, config = pcall(require, module)
		if ok and type(config) == "table" and type(config.List) == "table" then
			return config.List
		end

		warn("[ZoneUnlockService] Failed to load ZoneConfig, using defaults.")
	end

	return DEFAULT_ZONES
end

local ZONES = loadZones()
local playerZones = {}
local touchCooldowns = {}
local requestCooldowns = {}

local function ensureRemoteEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteEvent") then
			return existing
		end

		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local updateZonesRemote = ensureRemoteEvent("UpdateZoneData")
local requestZoneRemote = ensureRemoteEvent("RequestZoneTravel")
local notifyRemote = ensureRemoteEvent("NotifyUser")

local function notify(player, message, variant)
	notifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function emitGameplayEvent(eventName, player, payload)
	local event = ServerStorage:FindFirstChild("BrainrotGameplayEvent")
	if event and event:IsA("BindableEvent") then
		event:Fire(eventName, player, payload or {})
	end
end

local function getZoneById(zoneId)
	for _, zone in ipairs(ZONES) do
		if zone.Id == zoneId then
			return zone
		end
	end

	return nil
end

local function getPortalFolder()
	local folder = Workspace:FindFirstChild(PORTAL_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PORTAL_FOLDER_NAME
		folder.Parent = Workspace
	end

	return folder
end

local function formatNumber(n)
	n = math.floor(tonumber(n) or 0)

	if n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	end

	return tostring(n)
end

local function getPlayerSpeed(player)
	return tonumber(player:GetAttribute("SpeedPower")) or 0
end

local function getDefaultZoneData()
	return {
		Starter = true,
	}
end

local function applyZoneAttributes(player)
	local data = playerZones[player.UserId] or getDefaultZoneData()

	for _, zone in ipairs(ZONES) do
		player:SetAttribute("Zone_" .. zone.Id .. "_Unlocked", data[zone.Id] == true)
	end
end

local function buildZonePayload(player)
	local data = playerZones[player.UserId] or getDefaultZoneData()
	local speed = getPlayerSpeed(player)

	local zonesPayload = {}

	for _, zone in ipairs(ZONES) do
		table.insert(zonesPayload, {
			id = zone.Id,
			displayName = zone.DisplayName,
			requiredSpeed = zone.RequiredSpeed,
			color = zone.Color,
			unlocked = data[zone.Id] == true,
			canUnlock = speed >= zone.RequiredSpeed,
		})
	end

	return {
		speedPower = speed,
		zones = zonesPayload,
	}
end

local function fireZoneUpdate(player)
	updateZonesRemote:FireClient(player, buildZonePayload(player))
end

local function savePlayerZones(player)
	local data = playerZones[player.UserId]
	if not data then
		return
	end

	pcall(function()
		zoneStore:SetAsync("Zones_" .. tostring(player.UserId), data)
	end)
end

local function loadPlayerZones(player)
	local data = getDefaultZoneData()

	local success, saved = pcall(function()
		return zoneStore:GetAsync("Zones_" .. tostring(player.UserId))
	end)

	if success and type(saved) == "table" then
		for zoneId, unlocked in pairs(saved) do
			if unlocked == true then
				data[zoneId] = true
			end
		end
	end

	data.Starter = true

	playerZones[player.UserId] = data
	applyZoneAttributes(player)
	fireZoneUpdate(player)
end

local function teleportPlayerToPart(player, part)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	character:PivotTo(part.CFrame + Vector3.new(0, 4, 0))
end

local function getDestinationForZone(zoneId)
	local folder = getPortalFolder()

	local portal = folder:FindFirstChild(zoneId .. "Portal")
	if portal then
		local destination = portal:FindFirstChild("Destination")
		if destination and destination:IsA("BasePart") then
			return destination
		end
	end

	local directDestination = folder:FindFirstChild(zoneId .. "Spawn")
	if directDestination and directDestination:IsA("BasePart") then
		return directDestination
	end

	return nil
end

local function getPortalForZone(zoneId)
	local folder = getPortalFolder()
	local portal = folder:FindFirstChild(tostring(zoneId) .. "Portal")
	if portal and portal:IsA("BasePart") then
		return portal
	end

	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("BasePart") and tostring(obj:GetAttribute("ZoneId") or "") == tostring(zoneId) then
			return obj
		end
	end

	return nil
end

local function isPlayerAlive(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function playerCloseToPortal(player, zoneId)
	local portal = getPortalForZone(zoneId)
	if not portal then
		return true
	end

	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	return (root.Position - portal.Position).Magnitude <= REMOTE_PORTAL_DISTANCE
end

local function unlockZone(player, zone)
	local data = playerZones[player.UserId]
	if not data then
		data = getDefaultZoneData()
		playerZones[player.UserId] = data
	end

	if data[zone.Id] == true then
		return
	end

	data[zone.Id] = true
	applyZoneAttributes(player)
	fireZoneUpdate(player)
	savePlayerZones(player)

	notify(player, "Unlocked " .. zone.DisplayName .. "!", "success")
	emitGameplayEvent("ZoneUnlocked", player, {
		zoneId = zone.Id,
		displayName = zone.DisplayName,
		requiredSpeed = zone.RequiredSpeed,
	})
end

local function tryEnterZone(player, zoneId)
	local zone = getZoneById(zoneId)
	if not zone then
		return
	end

	local data = playerZones[player.UserId] or getDefaultZoneData()
	local speed = getPlayerSpeed(player)

	if data[zone.Id] ~= true then
		if speed < zone.RequiredSpeed then
			local missing = zone.RequiredSpeed - speed

			notify(
				player,
				"Need " .. formatNumber(zone.RequiredSpeed) .. " Speed for " .. zone.DisplayName .. "! " ..
					"Missing " .. formatNumber(missing) .. ".",
				"warning"
			)

			fireZoneUpdate(player)
			return
		end

		unlockZone(player, zone)
	end

	local destination = getDestinationForZone(zone.Id)

	if destination then
		teleportPlayerToPart(player, destination)
		notify(player, "Entered " .. zone.DisplayName .. "!", "success")
	else
		notify(player, zone.DisplayName .. " unlocked, but no Destination part was found.", "warning")
	end
end

local function createDemoPortal(zone)
	if zone.Id == "Starter" then
		return
	end

	local folder = getPortalFolder()

	local portalName = zone.Id .. "Portal"
	local existing = folder:FindFirstChild(portalName)

	if existing then
		return existing
	end

	local portal = Instance.new("Part")
	portal.Name = portalName
	portal.Size = Vector3.new(12, 8, 1.5)
	portal.Position = zone.PortalPosition
	portal.Anchored = true
	portal.CanCollide = false
	portal.CanTouch = true
	portal.Material = Enum.Material.Neon
	portal.Color = zone.Color
	portal.Transparency = 0.15
	portal:SetAttribute("ZoneId", zone.Id)
	portal:SetAttribute("DisplayName", zone.DisplayName)
	portal:SetAttribute("RequiredSpeed", zone.RequiredSpeed)
	portal.Parent = folder

	local destination = Instance.new("Part")
	destination.Name = "Destination"
	destination.Size = Vector3.new(8, 1, 8)
	destination.Position = zone.DestinationPosition
	destination.Anchored = true
	destination.CanCollide = false
	destination.CanTouch = false
	destination.Transparency = 0.55
	destination.Material = Enum.Material.Neon
	destination.Color = zone.Color
	destination.Parent = portal

	local light = Instance.new("PointLight")
	light.Name = "PortalGlow"
	light.Color = zone.Color
	light.Brightness = 2
	light.Range = 18
	light.Parent = portal

	return portal
end

local function setupPortalVisualAttributes(portal, zone)
	portal:SetAttribute("ZoneId", zone.Id)
	portal:SetAttribute("DisplayName", zone.DisplayName)
	portal:SetAttribute("RequiredSpeed", zone.RequiredSpeed)
	portal:SetAttribute("ZoneColorR", math.floor(zone.Color.R * 255))
	portal:SetAttribute("ZoneColorG", math.floor(zone.Color.G * 255))
	portal:SetAttribute("ZoneColorB", math.floor(zone.Color.B * 255))
end

local function bindPortal(portal)
	if not portal:IsA("BasePart") then
		return
	end

	if portal:GetAttribute("ZonePortalBound") == true then
		return
	end

	local zoneId = portal:GetAttribute("ZoneId")
	if type(zoneId) ~= "string" then
		return
	end

	local zone = getZoneById(zoneId)
	if not zone then
		return
	end

	portal:SetAttribute("ZonePortalBound", true)
	setupPortalVisualAttributes(portal, zone)

	local prompt = portal:FindFirstChild("ZonePrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ZonePrompt"
		prompt.ActionText = "Enter"
		prompt.ObjectText = zone.DisplayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = portal
	end

	prompt.Triggered:Connect(function(player)
		tryEnterZone(player, zone.Id)
	end)

	portal.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then
			return
		end

		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local key = tostring(player.UserId) .. "_" .. zone.Id
		local now = os.clock()

		if touchCooldowns[key] and now - touchCooldowns[key] < 1.25 then
			return
		end

		touchCooldowns[key] = now
		tryEnterZone(player, zone.Id)
	end)
end

local function setupPortals()
	local folder = getPortalFolder()

	if AUTO_CREATE_DEMO_PORTALS then
		for _, zone in ipairs(ZONES) do
			createDemoPortal(zone)
		end
	end

	for _, obj in ipairs(folder:GetChildren()) do
		bindPortal(obj)
	end

	folder.ChildAdded:Connect(function(obj)
		task.wait(0.1)
		bindPortal(obj)
	end)
end

requestZoneRemote.OnServerEvent:Connect(function(player, zoneId)
	if type(zoneId) ~= "string" then
		return
	end

	local now = os.clock()
	local last = requestCooldowns[player.UserId] or 0
	if now - last < REQUEST_COOLDOWN_SECONDS then
		return
	end
	requestCooldowns[player.UserId] = now

	if not isPlayerAlive(player) then
		notify(player, "You need to be alive to enter zones.", "warning")
		return
	end

	if not playerCloseToPortal(player, zoneId) then
		notify(player, "Use the zone portal to travel.", "warning")
		return
	end

	tryEnterZone(player, zoneId)
end)

Players.PlayerAdded:Connect(function(player)
	loadPlayerZones(player)

	player:GetAttributeChangedSignal("SpeedPower"):Connect(function()
		fireZoneUpdate(player)
	end)

	task.delay(1, function()
		if player.Parent then
			fireZoneUpdate(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	savePlayerZones(player)
	playerZones[player.UserId] = nil

	for key in pairs(touchCooldowns) do
		if string.find(key, tostring(player.UserId) .. "_") == 1 then
			touchCooldowns[key] = nil
		end
	end

	requestCooldowns[player.UserId] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerZones(player)
	end
end)

setupPortals()

print("[ZoneUnlockService] loaded")
