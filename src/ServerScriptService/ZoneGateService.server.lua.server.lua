--!nonstrict
-- ServerScriptService/ZoneGateService.server.lua

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CHECK_EVERY = 0.75
local TOUCH_DEBOUNCE = 0.8

local function getRemotesFolder()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	return folder
end

local zoneFeedbackRemote = getRemotesFolder():WaitForChild("ZoneGateFeedback")

local touchDebounce = {}

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function formatNumber(value)
	value = tonumber(value) or 0

	if value >= 1000000000000 then
		return string.format("%.1fT", value / 1000000000000)
	elseif value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(math.floor(value))
end

local function getStat(player, names)
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

local function getStrength(player)
	return getStat(player, {
		"Strength",
		"KickPower",
		"Kick Power",
		"Power",
	})
end

local function getRebirths(player)
	return getStat(player, {
		"Rebirths",
		"Rebirth",
	})
end

local function isGateObject(obj)
	if obj:GetAttribute("IsZoneGate") == true or obj:GetAttribute("ZoneGate") == true then
		return true
	end

	local n = normalize(obj.Name)
	return n == "zonegate" or string.find(n, "zonegate") ~= nil
end

local function getGateRoot(obj)
	if obj:IsA("BasePart") then
		return obj
	end

	for _, child in ipairs(obj:GetDescendants()) do
		if child:IsA("BasePart") then
			return child
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

	if value == nil and gate:IsA("BasePart") == false then
		local root = getGateRoot(gate)
		value = root and root:GetAttribute(attrName)
	end

	return tonumber(value) or 0
end

local function getZoneName(gate)
	return tostring(gate:GetAttribute("ZoneName") or gate:GetAttribute("TargetZoneName") or gate.Name)
end

local function playerCanPass(player, gate)
	local requiredStrength = getRequirement(gate, "RequiredStrength")
	local requiredRebirths = getRequirement(gate, "RequiredRebirths")

	return getStrength(player) >= requiredStrength and getRebirths(player) >= requiredRebirths
end

local function requirementMessage(player, gate)
	local requiredStrength = getRequirement(gate, "RequiredStrength")
	local requiredRebirths = getRequirement(gate, "RequiredRebirths")
	local missing = {}

	if getStrength(player) < requiredStrength then
		table.insert(missing, formatNumber(requiredStrength) .. " Strength")
	end

	if getRebirths(player) < requiredRebirths then
		table.insert(missing, tostring(requiredRebirths) .. " Rebirths")
	end

	if #missing == 0 then
		return "Unlocked!"
	end

	return getZoneName(gate) .. " locked. Need " .. table.concat(missing, " + ") .. "."
end

local function pushPlayerBack(player, gatePart)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local direction = root.Position - gatePart.Position
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, -1)
	end

	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = root.CFrame + direction * 8 + Vector3.new(0, 1, 0)
end

local function bindGate(gate)
	if gate:GetAttribute("ZoneGateBound") == true then
		return
	end

	gate:SetAttribute("ZoneGateBound", true)

	for _, part in ipairs(getGateParts(gate)) do
		part.CanCollide = false
		part.CanTouch = true
		part:SetAttribute("IsZoneGatePart", true)

		part.Touched:Connect(function(hit)
			local character = hit and hit:FindFirstAncestorOfClass("Model")
			if not character then
				return
			end

			local player = Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end

			if playerCanPass(player, gate) then
				return
			end

			local key = tostring(player.UserId) .. ":" .. gate:GetDebugId()

			if touchDebounce[key] and os.clock() - touchDebounce[key] < TOUCH_DEBOUNCE then
				return
			end

			touchDebounce[key] = os.clock()

			pushPlayerBack(player, part)

			zoneFeedbackRemote:FireClient(player, {
				gate = gate.Name,
				message = requirementMessage(player, gate),
			})
		end)
	end
end

task.spawn(function()
	while true do
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if isGateObject(obj) then
				bindGate(obj)
			end
		end

		task.wait(CHECK_EVERY)
	end
end)

print("[ZoneGateService] Loaded.")