--!nonstrict
-- StarterPlayerScripts/PrivateCollectMoneyText.client.lua
-- Shows collect money ONLY to the plot owner.
-- Reads fixed server attributes:
-- PrivateOwnerUserId
-- PrivateCollectAmount

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GUI_PREFIX = "PrivateCollectMoneyText_"
local UPDATE_EVERY = 0.15
local MAX_DISTANCE = 95

local guisByPart = {}

for _, obj in ipairs(playerGui:GetChildren()) do
	if obj:IsA("BillboardGui") and string.sub(obj.Name, 1, #GUI_PREFIX) == GUI_PREFIX then
		obj:Destroy()
	end
end

local function normalize(text)
	return string.lower(tostring(text)):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
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

local function getPlotsFolder()
	local direct = Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
	if direct then
		return direct
	end

	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	if spawnMap then
		return spawnMap:FindFirstChild("plots") or spawnMap:FindFirstChild("Plots")
	end

	return nil
end

local function ownsPlot(plot)
	return tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(plot:GetAttribute("OwnerName")) == player.Name
		or tostring(plot:GetAttribute("Owner")) == player.Name
end

local function getMyPlot()
	local plotsFolder = getPlotsFolder()
	if not plotsFolder then
		return nil
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if (plot:IsA("Model") or plot:IsA("Folder")) and ownsPlot(plot) then
			return plot
		end
	end

	return nil
end

local function isMoneyCollectPart(obj)
	if not obj:IsA("BasePart") then
		return false
	end

	if obj:GetAttribute("PrivateOwnerUserId") ~= nil then
		return true
	end

	local n = normalize(obj.Name)

	return n == "moneycollect"
		or n == "collectmoney"
		or n == "moneycollectpart"
		or n == "collectmoneypart"
		or string.find(n, "moneycollect") ~= nil
		or string.find(n, "collectmoney") ~= nil
end

local function getCollectParts(plot)
	local parts = {}
	local used = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if isMoneyCollectPart(obj) and not used[obj] then
			used[obj] = true
			table.insert(parts, obj)
		end
	end

	return parts
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

task.spawn(function()
	while true do
		local plot = getMyPlot()

		if not plot then
			cleanup({})
			task.wait(UPDATE_EVERY)
			continue
		end

		local validParts = {}

		for _, part in ipairs(getCollectParts(plot)) do
			validParts[part] = true

			local ownerId = part:GetAttribute("PrivateOwnerUserId")
			local amount = tonumber(part:GetAttribute("PrivateCollectAmount")) or 0

			if tostring(ownerId) ~= tostring(player.UserId) then
				hideGui(part)
				continue
			end

			local linkedUid = part:GetAttribute("LinkedBrainrotUID")
			if linkedUid == nil or tostring(linkedUid) == "" then
				hideGui(part)
				continue
			end

			local gui = ensureGui(part)
			local label = gui:FindFirstChild("Amount")

			if label and label:IsA("TextLabel") then
				if amount > 0 then
					gui.Enabled = true
					label.Text = "$" .. formatMoney(amount)
				else
					gui.Enabled = false
					label.Text = ""
				end
			end
		end

		cleanup(validParts)

		task.wait(UPDATE_EVERY)
	end
end)

print("[PrivateCollectMoneyText] Loaded server-linked version.")
