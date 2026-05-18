--!nonstrict
-- StarterPlayerScripts/ZoneGateClient.client.lua
-- Gate requirement UI with icons.
-- If requirements are met, touching gate hides it locally.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UPDATE_EVERY = 0.25
local GUI_NAME = "LocalZoneGateRequirementGui"

local gateGuis = {}
local openedGates = {}
local lastUpdate = 0

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function formatNumber(value)
	value = tonumber(value) or 0

	if value >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end

	return tostring(math.floor(value))
end

local function getStat(names)
	for _, attr in ipairs(names) do
		local value = tonumber(player:GetAttribute(attr))
		if value then
			return value
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		for _, statName in ipairs(names) do
			local stat = leaderstats:FindFirstChild(statName)
			if stat and stat:IsA("ValueBase") then
				return tonumber(stat.Value) or 0
			end
		end
	end

	return 0
end

local function getStrength()
	return getStat({ "Strength", "KickPower", "Kick Power", "Power" })
end

local function getRebirths()
	return getStat({ "Rebirths", "Rebirth" })
end

local function isGateObject(obj)
	if obj:GetAttribute("IsZoneGate") == true or obj:GetAttribute("ZoneGate") == true then
		return true
	end

	local n = normalize(obj.Name)
	return n == "zonegate" or string.find(n, "gate") ~= nil
end

local function getGatePart(gate)
	if gate:IsA("BasePart") then
		return gate
	end

	for _, obj in ipairs(gate:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function getGateParts(gate)
	local parts = {}

	if gate:IsA("BasePart") then
		table.insert(parts, gate)
	else
		for _, obj in ipairs(gate:GetDescendants()) do
			if obj:IsA("BasePart") then
				table.insert(parts, obj)
			end
		end
	end

	return parts
end

local function getRequirement(gate, attrName)
	local value = gate:GetAttribute(attrName)

	if value == nil then
		local part = getGatePart(gate)
		value = part and part:GetAttribute(attrName)
	end

	return tonumber(value) or 0
end

local function getZoneName(gate)
	return tostring(gate:GetAttribute("ZoneName") or gate.Name)
end

local function isUnlocked(gate)
	return getStrength() >= getRequirement(gate, "RequiredStrength")
		and getRebirths() >= getRequirement(gate, "RequiredRebirths")
end

local function getRequirementText(gate)
	local requiredStrength = getRequirement(gate, "RequiredStrength")
	local requiredRebirths = getRequirement(gate, "RequiredRebirths")

	if isUnlocked(gate) then
		return "UNLOCKED\nTOUCH TO ENTER"
	end

	local lines = {}

	if requiredStrength > 0 then
		table.insert(lines, "💪 " .. formatNumber(requiredStrength))
	end

	if requiredRebirths > 0 then
		table.insert(lines, "🔁 " .. tostring(requiredRebirths))
	end

	if #lines == 0 then
		return "TOUCH TO ENTER"
	end

	return getZoneName(gate) .. "\n" .. table.concat(lines, "   ")
end

local function setGateLocalVisible(gate, visible)
	for _, part in ipairs(getGateParts(gate)) do
		part.LocalTransparencyModifier = visible and 0 or 1
	end
end

local function ensureGui(gate)
	local part = getGatePart(gate)
	if not part then
		return nil
	end

	local gui = gateGuis[gate]

	if gui and gui.Parent then
		gui.Adornee = part
		return gui
	end

	gui = Instance.new("BillboardGui")
	gui.Name = GUI_NAME
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(260, 86)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.MaxDistance = 120
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Parent = gui

	gateGuis[gate] = gui
	return gui
end

local function updateGate(gate)
	if openedGates[gate] then
		setGateLocalVisible(gate, false)

		local gui = gateGuis[gate]
		if gui then
			gui.Enabled = false
		end

		return
	end

	setGateLocalVisible(gate, true)

	local gui = ensureGui(gate)
	if not gui then
		return
	end

	gui.Enabled = true

	local label = gui:FindFirstChild("Text")
	if not label or not label:IsA("TextLabel") then
		return
	end

	local unlocked = isUnlocked(gate)

	label.Text = getRequirementText(gate)
	label.TextColor3 = unlocked and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 255, 255)
end

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function checkTouchToOpen(gate)
	if openedGates[gate] then
		return
	end

	if not isUnlocked(gate) then
		return
	end

	local root = getCharacterRoot()
	if not root then
		return
	end

	local gatePart = getGatePart(gate)
	if not gatePart then
		return
	end

	local distance = (root.Position - gatePart.Position).Magnitude
	local touchDistance = math.max(gatePart.Size.X, gatePart.Size.Y, gatePart.Size.Z) * 0.5 + 5

	if distance <= touchDistance then
		openedGates[gate] = true
		setGateLocalVisible(gate, false)

		local gui = gateGuis[gate]
		if gui then
			gui.Enabled = false
		end
	end
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if isGateObject(obj) then
			checkTouchToOpen(obj)
		end
	end

	if now - lastUpdate < UPDATE_EVERY then
		return
	end

	lastUpdate = now

	local valid = {}

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if isGateObject(obj) then
			valid[obj] = true
			updateGate(obj)
		end
	end

	for gate, gui in pairs(gateGuis) do
		if not valid[gate] or not gate.Parent then
			if gui then
				gui:Destroy()
			end

			gateGuis[gate] = nil
			openedGates[gate] = nil
		end
	end
end)

print("[ZoneGateClient] Loaded local gate requirement UI.")