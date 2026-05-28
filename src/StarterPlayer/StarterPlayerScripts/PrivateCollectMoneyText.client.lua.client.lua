--!nonstrict
-- StarterPlayerScripts/PrivateCollectMoneyText.client.lua
-- Shows collect money only on parts marked:
-- PrivateCollectGuiPart = true
-- PrivateOwnerUserId = LocalPlayer.UserId
-- LinkedBrainrotUID exists
-- PrivateCollectAmount > 0

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GUI_PREFIX = "PrivateCollectMoneyText_"
local SCAN_EVERY = 2
local MAX_DISTANCE = 95

local guisByPart = {}
local trackedParts = {}
local partConnections = {}

for _, obj in ipairs(playerGui:GetChildren()) do
	if obj:IsA("BillboardGui") and string.sub(obj.Name, 1, #GUI_PREFIX) == GUI_PREFIX then
		obj:Destroy()
	end
end

local function formatMoney(value)
	value = tonumber(value) or 0

	if value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(math.floor(value))
end

local function shouldShowOnPart(part)
	if not part:IsA("BasePart") then
		return false
	end

	if part:GetAttribute("PrivateCollectGuiPart") ~= true then
		return false
	end

	if tostring(part:GetAttribute("PrivateOwnerUserId")) ~= tostring(player.UserId) then
		return false
	end

	local uid = part:GetAttribute("LinkedBrainrotUID")
	if uid == nil or tostring(uid) == "" then
		return false
	end

	local amount = tonumber(part:GetAttribute("PrivateCollectAmount")) or 0
	if amount <= 0 then
		return false
	end

	return true
end

local function ensureGui(part)
	local gui = guisByPart[part]

	if gui and gui.Parent then
		gui.Adornee = part
		gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 1.2, 0)
		return gui
	end

	gui = Instance.new("BillboardGui")
	gui.Name = GUI_PREFIX .. tostring(math.random(100000, 999999))
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(210, 58)
	gui.StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + 1.55, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = MAX_DISTANCE
	gui.Enabled = false
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Amount"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = gui

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 44
	constraint.MinTextSize = 18
	constraint.Parent = label

	guisByPart[part] = gui

	return gui
end

local function hideGui(part)
	local gui = guisByPart[part]
	if not gui then
		return
	end

	gui.Enabled = false

	local label = gui:FindFirstChild("Amount")
	if label and label:IsA("TextLabel") then
		label.Text = ""
	end
end

local function cleanup(validParts)
	for part, gui in pairs(guisByPart) do
		if not validParts[part] or not part.Parent then
			if gui then
				gui:Destroy()
			end

			guisByPart[part] = nil
		end
	end
end

local function disconnectPart(part)
	local connections = partConnections[part]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end

	partConnections[part] = nil
	trackedParts[part] = nil
	hideGui(part)
end

local function updatePart(part)
	if not part or not part.Parent or not part:IsA("BasePart") then
		disconnectPart(part)
		return
	end

	if part:GetAttribute("PrivateCollectGuiPart") ~= true then
		disconnectPart(part)
		return
	end

	trackedParts[part] = true

	if shouldShowOnPart(part) then
		local gui = ensureGui(part)
		local label = gui:FindFirstChild("Amount")

		if label and label:IsA("TextLabel") then
			local amount = tonumber(part:GetAttribute("PrivateCollectAmount")) or 0
			label.Text = "$" .. formatMoney(amount)
			gui.Enabled = true
		end
	else
		hideGui(part)
	end
end

local function trackPart(part)
	if not part or not part:IsA("BasePart") or partConnections[part] then
		updatePart(part)
		return
	end

	partConnections[part] = {
		part:GetAttributeChangedSignal("PrivateCollectGuiPart"):Connect(function()
			updatePart(part)
		end),
		part:GetAttributeChangedSignal("PrivateOwnerUserId"):Connect(function()
			updatePart(part)
		end),
		part:GetAttributeChangedSignal("LinkedBrainrotUID"):Connect(function()
			updatePart(part)
		end),
		part:GetAttributeChangedSignal("PrivateCollectAmount"):Connect(function()
			updatePart(part)
		end),
		part.AncestryChanged:Connect(function()
			if not part.Parent then
				disconnectPart(part)
			end
		end),
	}

	updatePart(part)
end

local function scanCollectParts()
	local validParts = {}

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj:GetAttribute("PrivateCollectGuiPart") == true then
			validParts[obj] = true
			trackPart(obj)
		end
	end

	for part in pairs(trackedParts) do
		validParts[part] = true
		updatePart(part)
	end

	cleanup(validParts)
end

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") then
		task.defer(function()
			if obj:GetAttribute("PrivateCollectGuiPart") == true then
				trackPart(obj)
			end
		end)
	end
end)

task.defer(scanCollectParts)

task.spawn(function()
	while true do
		task.wait(SCAN_EVERY)
		scanCollectParts()
	end
end)

print("[PrivateCollectMoneyText] Loaded strict GUI version.")
