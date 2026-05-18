--!nonstrict
-- ZonePortalUI.client.lua
-- Put in: StarterPlayer > StarterPlayerScripts
-- Adds cartoon portal labels and live unlock status.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local updateZonesRemote = ReplicatedStorage:WaitForChild("UpdateZoneData")
local updateSpeedRemote = ReplicatedStorage:WaitForChild("UpdateSpeedStats", 30)

local PORTAL_FOLDER_NAME = "ZonePortals"
local FONT = Enum.Font.FredokaOne

local latestPayload = nil
local currentSpeed = tonumber(player:GetAttribute("SpeedPower")) or 0
local portalGuis = {}

local function formatNumber(n)
	n = math.floor(tonumber(n) or 0)

	if n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	end

	return tostring(n)
end

local function addCorner(obj, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = obj
	return corner
end

local function addStroke(obj, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 2
	stroke.Parent = obj
	return stroke
end

local function addGradient(obj, top, bottom)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	gradient.Parent = obj
	return gradient
end

local function makeText(parent, name, text, pos, size, textSize, color, z)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Text = text
	label.Font = FONT
	label.TextSize = textSize
	label.TextScaled = false
	label.TextWrapped = true
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = z or 10
	label.Parent = parent

	addStroke(label, Color3.fromRGB(0, 0, 0), math.max(2, textSize / 9))

	return label
end

local function getZoneData(zoneId)
	if not latestPayload or not latestPayload.zones then
		return nil
	end

	for _, zone in ipairs(latestPayload.zones) do
		if zone.id == zoneId then
			return zone
		end
	end

	return nil
end

local function getPortalColor(portal)
	local r = tonumber(portal:GetAttribute("ZoneColorR")) or 80
	local g = tonumber(portal:GetAttribute("ZoneColorG")) or 180
	local b = tonumber(portal:GetAttribute("ZoneColorB")) or 255

	return Color3.fromRGB(r, g, b)
end

local function ensurePortalEffects(portal)
	if portal:FindFirstChild("ClientPortalParticles") then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "ClientPortalParticles"
	attachment.Parent = portal

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Sparkles"
	particles.Texture = "rbxassetid://243098098"
	particles.Rate = 18
	particles.Lifetime = NumberRange.new(0.8, 1.4)
	particles.Speed = NumberRange.new(1.5, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Color = ColorSequence.new(getPortalColor(portal))
	particles.Parent = attachment
end

local function createPortalGui(portal)
	if portalGuis[portal] then
		return portalGuis[portal]
	end

	local old = portal:FindFirstChild("ZonePortalBillboard")
	if old then
		old:Destroy()
	end

	local color = getPortalColor(portal)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZonePortalBillboard"
	billboard.Size = UDim2.new(0, 310, 0, 132)
	billboard.StudsOffset = Vector3.new(0, 7.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	billboard.Adornee = portal
	billboard.Parent = portal

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundColor3 = Color3.fromRGB(18, 35, 60)
	holder.BorderSizePixel = 0
	holder.ZIndex = 10
	holder.Parent = billboard

	addCorner(holder, 28)
	addStroke(holder, Color3.fromRGB(0, 0, 0), 5)
	addGradient(holder, color:Lerp(Color3.fromRGB(255, 255, 255), 0.25), color:Lerp(Color3.fromRGB(0, 0, 0), 0.15))

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.new(0, 16, 0, 12)
	shine.Size = UDim2.new(1, -32, 0, 28)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.74
	shine.BorderSizePixel = 0
	shine.ZIndex = 11
	shine.Parent = holder

	addCorner(shine, 18)

	local title = makeText(
		holder,
		"Title",
		"ZONE",
		UDim2.new(0, 12, 0, 8),
		UDim2.new(1, -24, 0, 44),
		30,
		Color3.fromRGB(255, 255, 255),
		12
	)

	local requirement = makeText(
		holder,
		"Requirement",
		"Need Speed",
		UDim2.new(0, 12, 0, 50),
		UDim2.new(1, -24, 0, 30),
		20,
		Color3.fromRGB(255, 235, 70),
		12
	)

	local status = makeText(
		holder,
		"Status",
		"LOCKED",
		UDim2.new(0, 24, 0, 86),
		UDim2.new(1, -48, 0, 34),
		22,
		Color3.fromRGB(255, 255, 255),
		12
	)

	local statusBack = Instance.new("Frame")
	statusBack.Name = "StatusBack"
	statusBack.Position = UDim2.new(0.5, 0, 1, -42)
	statusBack.AnchorPoint = Vector2.new(0.5, 0)
	statusBack.Size = UDim2.new(0, 210, 0, 34)
	statusBack.BackgroundColor3 = Color3.fromRGB(255, 185, 35)
	statusBack.BorderSizePixel = 0
	statusBack.ZIndex = 11
	statusBack.Parent = holder

	addCorner(statusBack, 16)
	addStroke(statusBack, Color3.fromRGB(0, 0, 0), 3)
	addGradient(statusBack, Color3.fromRGB(255, 225, 80), Color3.fromRGB(230, 120, 20))

	status.Parent = statusBack
	status.Position = UDim2.fromScale(0, 0)
	status.Size = UDim2.fromScale(1, 1)
	status.ZIndex = 13

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = holder

	task.spawn(function()
		while billboard.Parent do
			TweenService:Create(
				scale,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Scale = 1.035 }
			):Play()

			task.wait(0.7)

			if not billboard.Parent then
				break
			end

			TweenService:Create(
				scale,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ Scale = 1 }
			):Play()

			task.wait(0.7)
		end
	end)

	local data = {
		billboard = billboard,
		holder = holder,
		title = title,
		requirement = requirement,
		status = status,
		statusBack = statusBack,
	}

	portalGuis[portal] = data

	ensurePortalEffects(portal)

	return data
end

local function updatePortalGui(portal)
	local zoneId = portal:GetAttribute("ZoneId")
	if type(zoneId) ~= "string" then
		return
	end

	local guiData = createPortalGui(portal)
	local zoneData = getZoneData(zoneId)

	local displayName = portal:GetAttribute("DisplayName") or zoneId
	local requiredSpeed = tonumber(portal:GetAttribute("RequiredSpeed")) or 0

	local unlocked = false
	local canUnlock = currentSpeed >= requiredSpeed

	if zoneData then
		displayName = zoneData.displayName or displayName
		requiredSpeed = tonumber(zoneData.requiredSpeed) or requiredSpeed
		unlocked = zoneData.unlocked == true
		canUnlock = zoneData.canUnlock == true
	else
		unlocked = player:GetAttribute("Zone_" .. zoneId .. "_Unlocked") == true
	end

	guiData.title.Text = string.upper(displayName)

	if unlocked then
		guiData.requirement.Text = "Unlocked"
		guiData.status.Text = "ENTER"
		guiData.statusBack.BackgroundColor3 = Color3.fromRGB(75, 235, 45)

		local gradient = guiData.statusBack:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(135, 255, 75)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 175, 15)),
			})
		end
	elseif canUnlock then
		guiData.requirement.Text = formatNumber(requiredSpeed) .. " Speed Required"
		guiData.status.Text = "READY!"
		guiData.statusBack.BackgroundColor3 = Color3.fromRGB(75, 235, 45)

		local gradient = guiData.statusBack:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(135, 255, 75)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 175, 15)),
			})
		end
	else
		guiData.requirement.Text = formatNumber(currentSpeed) .. " / " .. formatNumber(requiredSpeed) .. " Speed"
		guiData.status.Text = "LOCKED"
		guiData.statusBack.BackgroundColor3 = Color3.fromRGB(255, 185, 35)

		local gradient = guiData.statusBack:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 80)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 120, 20)),
			})
		end
	end
end

local function updateAllPortals()
	local folder = Workspace:FindFirstChild(PORTAL_FOLDER_NAME)
	if not folder then
		return
	end

	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("BasePart") and type(obj:GetAttribute("ZoneId")) == "string" then
			updatePortalGui(obj)
		end
	end
end

local function bindPortalFolder()
	local folder = Workspace:WaitForChild(PORTAL_FOLDER_NAME, 30)
	if not folder then
		warn("[ZonePortalUI] ZonePortals folder not found")
		return
	end

	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("BasePart") then
			updatePortalGui(obj)
		end
	end

	folder.ChildAdded:Connect(function(obj)
		task.wait(0.2)

		if obj:IsA("BasePart") then
			updatePortalGui(obj)
		end
	end)
end

updateZonesRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	latestPayload = payload
	currentSpeed = tonumber(payload.speedPower) or currentSpeed

	updateAllPortals()
end)

if updateSpeedRemote then
	updateSpeedRemote.OnClientEvent:Connect(function(data)
		if typeof(data) ~= "table" then
			return
		end

		currentSpeed = tonumber(data.speedPower) or currentSpeed
		updateAllPortals()
	end)
end

player:GetAttributeChangedSignal("SpeedPower"):Connect(function()
	currentSpeed = tonumber(player:GetAttribute("SpeedPower")) or currentSpeed
	updateAllPortals()
end)

task.spawn(bindPortalFolder)

task.spawn(function()
	while true do
		updateAllPortals()
		task.wait(0.5)
	end
end)

print("[ZonePortalUI] loaded")