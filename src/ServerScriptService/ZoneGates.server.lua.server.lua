--!nonstrict
-- ZoneGates.server.lua
-- Put in: ServerScriptService
-- Speed-locked zone gate / portal system.
-- Uses:
-- Workspace > SpawnMap > Zones
-- Workspace > SpawnMap > ZoneGates

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SpawnMap = Workspace:WaitForChild("SpawnMap")
local ZonesFolder = SpawnMap:WaitForChild("Zones")

local NotifyRemote = ReplicatedStorage:FindFirstChild("NotifyUser")
if not NotifyRemote then
	NotifyRemote = Instance.new("RemoteEvent")
	NotifyRemote.Name = "NotifyUser"
	NotifyRemote.Parent = ReplicatedStorage
end

local AUTO_CREATE_GATE_PARTS = true

local GateFolder = SpawnMap:FindFirstChild("ZoneGates")
if not GateFolder then
	GateFolder = Instance.new("Folder")
	GateFolder.Name = "ZoneGates"
	GateFolder.Parent = SpawnMap
end

local GATES = {
	ForestGate = {
		DisplayName = "Forest Zone",
		TargetZoneName = "forest",
		RequiredSpeed = 250,
		Color = Color3.fromRGB(80, 255, 80),
		DemoPosition = Vector3.new(0, 5, -85),
	},

	CrystalGate = {
		DisplayName = "Crystal Zone",
		TargetZoneName = "crystal",
		RequiredSpeed = 1500,
		Color = Color3.fromRGB(80, 210, 255),
		DemoPosition = Vector3.new(75, 5, -130),
	},

	LavaGate = {
		DisplayName = "Lava Zone",
		TargetZoneName = "lava",
		RequiredSpeed = 5000,
		Color = Color3.fromRGB(255, 90, 45),
		DemoPosition = Vector3.new(-75, 5, -130),
	},

	GalaxyGate = {
		DisplayName = "Galaxy Zone",
		TargetZoneName = "galaxy",
		RequiredSpeed = 12000,
		Color = Color3.fromRGB(180, 80, 255),
		DemoPosition = Vector3.new(0, 5, -230),
	},
}

local touchCooldowns = {}

local function formatNumber(n)
	n = math.floor(tonumber(n) or 0)

	if n >= 1_000_000_000 then
		return string.format("%.1fB", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	end

	return tostring(n)
end

local function notify(player, message, variant)
	NotifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function getPlayerSpeed(player)
	return tonumber(player:GetAttribute("SpeedPower")) or 0
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function findZoneTarget(zoneName)
	local cleanZoneName = string.lower(tostring(zoneName))

	for _, obj in ipairs(ZonesFolder:GetDescendants()) do
		if obj:IsA("BasePart") and string.lower(obj.Name) == cleanZoneName then
			return obj
		end
	end

	return nil
end

local function getGatePart(gateName)
	local existing = GateFolder:FindFirstChild(gateName)

	if existing and existing:IsA("BasePart") then
		return existing
	end

	return nil
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

local function makeGateBillboard(gatePart, gateData)
	local old = gatePart:FindFirstChild("ZoneGateBillboard")
	if old then
		old:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneGateBillboard"
	billboard.Size = UDim2.new(0, 270, 0, 105)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	billboard.Parent = gatePart

	local frame = Instance.new("Frame")
	frame.Name = "Holder"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = gateData.Color
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	addCorner(frame, 20)
	addStroke(frame, Color3.fromRGB(0, 0, 0), 4)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, gateData.Color:Lerp(Color3.fromRGB(255, 255, 255), 0.35)),
		ColorSequenceKeypoint.new(1, gateData.Color:Lerp(Color3.fromRGB(0, 0, 0), 0.18)),
	})
	gradient.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 10, 0, 8)
	title.Size = UDim2.new(1, -20, 0, 45)
	title.Font = Enum.Font.FredokaOne
	title.Text = string.upper(gateData.DisplayName)
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextScaled = true
	title.ZIndex = 2
	title.Parent = frame

	addStroke(title, Color3.fromRGB(0, 0, 0), 3)

	local requirement = Instance.new("TextLabel")
	requirement.Name = "Requirement"
	requirement.BackgroundTransparency = 1
	requirement.Position = UDim2.new(0, 10, 0, 55)
	requirement.Size = UDim2.new(1, -20, 0, 32)
	requirement.Font = Enum.Font.FredokaOne
	requirement.Text = "Need " .. formatNumber(gateData.RequiredSpeed) .. " Speed"
	requirement.TextColor3 = Color3.fromRGB(255, 245, 90)
	requirement.TextScaled = true
	requirement.ZIndex = 2
	requirement.Parent = frame

	addStroke(requirement, Color3.fromRGB(0, 0, 0), 2)
end

local function createDemoGate(gateName, gateData)
	if not AUTO_CREATE_GATE_PARTS then
		return nil
	end

	local existing = getGatePart(gateName)
	if existing then
		return existing
	end

	local gate = Instance.new("Part")
	gate.Name = gateName
	gate.Size = Vector3.new(12, 8, 2)
	gate.Position = gateData.DemoPosition
	gate.Anchored = true
	gate.CanCollide = false
	gate.CanTouch = true
	gate.CanQuery = true
	gate.Material = Enum.Material.Neon
	gate.Color = gateData.Color
	gate.Transparency = 0.25
	gate.Parent = GateFolder

	local light = Instance.new("PointLight")
	light.Name = "GateGlow"
	light.Color = gateData.Color
	light.Brightness = 1.4
	light.Range = 18
	light.Parent = gate

	makeGateBillboard(gate, gateData)

	return gate
end

local function teleportPlayerToZone(player, gateName, gateData)
	local root = getCharacterRoot(player)
	if not root then
		return
	end

	local target = findZoneTarget(gateData.TargetZoneName)

	if not target then
		notify(player, gateData.DisplayName .. " target does not exist yet!", "warning")
		warn("[ZoneGates] Missing target zone part named:", gateData.TargetZoneName)
		return
	end

	local character = player.Character
	if not character then
		return
	end

	character:PivotTo(target.CFrame + Vector3.new(0, 6, 0))

	notify(player, "Entered " .. gateData.DisplayName .. "!", "success")
end

local function onGateTouched(gateName, gateData, hit)
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

	local key = tostring(player.UserId) .. "_" .. gateName
	local now = os.clock()

	if touchCooldowns[key] and now - touchCooldowns[key] < 2 then
		return
	end

	touchCooldowns[key] = now

	local speed = getPlayerSpeed(player)

	if speed < gateData.RequiredSpeed then
		notify(
			player,
			"Need " .. formatNumber(gateData.RequiredSpeed) .. " Speed to enter " .. gateData.DisplayName .. "!",
			"warning"
		)
		return
	end

	teleportPlayerToZone(player, gateName, gateData)
end

local function bindGate(gateName, gateData)
	local gate = getGatePart(gateName)

	if not gate then
		gate = createDemoGate(gateName, gateData)
	end

	if not gate then
		warn("[ZoneGates] Missing gate part:", gateName)
		return
	end

	gate.CanTouch = true
	makeGateBillboard(gate, gateData)

	if gate:GetAttribute("ZoneGateBound") == true then
		return
	end

	gate:SetAttribute("ZoneGateBound", true)

	gate.Touched:Connect(function(hit)
		onGateTouched(gateName, gateData, hit)
	end)

	print("[ZoneGates] Bound:", gateName)
end

for gateName, gateData in pairs(GATES) do
	bindGate(gateName, gateData)
end

GateFolder.ChildAdded:Connect(function(child)
	task.wait(0.1)

	for gateName, gateData in pairs(GATES) do
		if child.Name == gateName and child:IsA("BasePart") then
			bindGate(gateName, gateData)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for key, _ in pairs(touchCooldowns) do
		if string.find(key, tostring(player.UserId) .. "_") == 1 then
			touchCooldowns[key] = nil
		end
	end
end)

print("[ZoneGates] loaded")