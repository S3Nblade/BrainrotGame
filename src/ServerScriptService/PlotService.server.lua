--!nonstrict
-- ServerScriptService/PlotService.lua
-- Fixed plot ownership system for Workspace.plots / Workspace.Plots.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SIGN_FACE = Enum.NormalId.Back

local assignedPlots = {}
local playerPlots = {}
local signConnections = {}
local plotsInitialized = false

local function looksLikePlotsFolder(container)
	if not container or not (container:IsA("Folder") or container:IsA("Model")) then
		return false
	end

	local name = string.lower(container.Name)
	if name ~= "plots" then
		return false
	end

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") then
			return true
		end
	end

	return false
end

local function getPlotsFolder()
	local direct = Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
	if looksLikePlotsFolder(direct) then
		return direct
	end

	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	if spawnMap then
		local nested = spawnMap:FindFirstChild("plots", true) or spawnMap:FindFirstChild("Plots", true)
		if looksLikePlotsFolder(nested) then
			return nested
		end
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if looksLikePlotsFolder(obj) then
			return obj
		end
	end

	return nil
end

local function waitForPlotsFolder(timeout)
	local started = os.clock()
	local limit = tonumber(timeout) or 20

	while os.clock() - started < limit do
		local folder = getPlotsFolder()
		if folder then
			return folder
		end

		task.wait(0.25)
	end

	return nil
end

local function getFirstBasePart(container)
	if not container then
		return nil
	end

	if container:IsA("BasePart") then
		return container
	end

	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function findBaseFloor(plot)
	if not plot then
		return nil
	end

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj.Name == "BASE FLOOR" then
			if obj:IsA("BasePart") then
				return obj
			end

			local part = getFirstBasePart(obj)
			if part then
				return part
			end
		end
	end

	return getFirstBasePart(plot)
end

local function normalizedName(obj)
	return string.lower(string.gsub(obj and obj.Name or "", "%s+", ""))
end

local function isImportedMapContainer(obj)
	local name = normalizedName(obj)
	return obj == Workspace
		or name == "spawnmap"
		or name == "map"
		or name == "folder"
		or string.sub(name, 1, 6) == "cloud_"
end

local function scorePlotCandidate(candidate)
	if not candidate or not (candidate:IsA("Model") or candidate:IsA("Folder") or candidate:IsA("BasePart")) then
		return 0
	end

	local score = 0
	local descendants = candidate:IsA("BasePart") and {} or candidate:GetDescendants()
	for _, obj in ipairs(descendants) do
		local name = normalizedName(obj)
		if name == "basefloor" then
			score += 8
		elseif name == "nameofplayer" or name == "ownername" then
			score += 5
		elseif string.find(name, "brainrotstand", 1, true) or string.find(name, "npcslot", 1, true) then
			score += 4
		elseif string.find(name, "moneycollect", 1, true) or string.find(name, "collectmoney", 1, true) then
			score += 4
		end

		if obj:GetAttribute("BrainrotSlotId") ~= nil then
			score += 4
		end
		if obj:GetAttribute("MoneyCollectPart") == true or obj:GetAttribute("PrivateCollectGuiPart") == true then
			score += 4
		end
	end

	local ownName = normalizedName(candidate)
	if ownName == "basefloor" then
		score += 8
	elseif string.find(ownName, "plot", 1, true) then
		score += 3
	end

	return score
end

local function findPlotRootFromMarker(marker)
	if normalizedName(marker) == "basefloor" then
		local parent = marker.Parent
		if parent
			and parent ~= Workspace
			and (parent:IsA("Model") or parent:IsA("Folder"))
			and not isImportedMapContainer(parent)
		then
			return parent
		end
	end

	local best
	local bestScore = 0
	local current = marker

	while current and current ~= Workspace do
		if current:IsA("Model") or current:IsA("Folder") or current:IsA("BasePart") then
			local score = scorePlotCandidate(current)
			if score > bestScore and not isImportedMapContainer(current) then
				best = current
				bestScore = score
			end
		end

		current = current.Parent
	end

	if best and bestScore >= 8 and getFirstBasePart(best) then
		return best
	end

	local parent = marker.Parent
	if parent and parent ~= Workspace and (parent:IsA("Model") or parent:IsA("Folder") or parent:IsA("BasePart")) then
		return parent
	end

	return marker:IsA("BasePart") and marker or nil
end

local function discoverPlotsFromMarkers()
	local plots = {}
	local used = {}

	local function addPlot(plot)
		if not plot or used[plot] or not getFirstBasePart(plot) then
			return
		end

		used[plot] = true
		table.insert(plots, plot)
	end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		local name = normalizedName(obj)
		local marker = name == "basefloor"
			or name == "nameofplayer"
			or string.find(name, "brainrotstand", 1, true) ~= nil
			or string.find(name, "moneycollect", 1, true) ~= nil
			or string.find(name, "collectmoney", 1, true) ~= nil
			or obj:GetAttribute("BrainrotSlotId") ~= nil
			or obj:GetAttribute("MoneyCollectPart") == true
			or obj:GetAttribute("PrivateCollectGuiPart") == true

		if marker then
			addPlot(findPlotRootFromMarker(obj))
		end
	end

	return plots
end

local function getAllPlots()
	local plotsFolder = getPlotsFolder()
	local plots = {}

	if plotsFolder then
		for _, plot in ipairs(plotsFolder:GetChildren()) do
			if (plot:IsA("Model") or plot:IsA("Folder") or plot:IsA("BasePart")) and getFirstBasePart(plot) then
				table.insert(plots, plot)
			end
		end
	end

	if #plots == 0 then
		plots = discoverPlotsFromMarkers()
	end

	table.sort(plots, function(a, b)
		local aBase = findBaseFloor(a)
		local bBase = findBaseFloor(b)

		if aBase and bBase then
			if math.abs(aBase.Position.X - bBase.Position.X) > 0.1 then
				return aBase.Position.X < bBase.Position.X
			end

			return aBase.Position.Z < bBase.Position.Z
		end

		return a.Name < b.Name
	end)

	return plots
end

local function waitForAnyPlots(timeout)
	local started = os.clock()
	local limit = tonumber(timeout) or 20

	while os.clock() - started < limit do
		local plots = getAllPlots()
		if #plots > 0 then
			return plots
		end

		task.wait(0.25)
	end

	return {}
end

local function getRebirths(player)
	local attr = tonumber(player:GetAttribute("Rebirths"))
	if attr then
		return math.floor(attr)
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local rebirths = leaderstats:FindFirstChild("Rebirths")
		if rebirths and rebirths:IsA("ValueBase") then
			return math.floor(tonumber(rebirths.Value) or 0)
		end
	end

	return 0
end

local function clearGuiOnPart(part)
	if not part then
		return
	end

	for _, child in ipairs(part:GetChildren()) do
		if child.Name == "PlotNameSurfaceGui" or child.Name == "OwnerNameGui" then
			child:Destroy()
		end
	end
end

local function clearOldPlotGuis(plot)
	for _, obj in ipairs(plot:GetDescendants()) do
		if (obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")) and (obj.Name == "OwnerNameGui" or obj.Name == "PlotNameSurfaceGui") then
			obj:Destroy()
		end
	end
end

local function findNameSignPart(plot)
	local signModel = plot:FindFirstChild("NAME OF PLAYER", true)

	if signModel then
		local textPart = signModel:FindFirstChild("Text Here", true)
		if textPart and textPart:IsA("BasePart") then
			return textPart
		end

		local first = getFirstBasePart(signModel)
		if first then
			return first
		end
	end

	return findBaseFloor(plot)
end

local function makeSurfaceText(signPart, playerName, displayName, rebirths, isEmpty)
	if not signPart then
		return
	end

	clearGuiOnPart(signPart)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "PlotNameSurfaceGui"
	gui.Adornee = signPart
	gui.AlwaysOnTop = true
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 45
	gui.Face = SIGN_FACE
	gui.Parent = signPart

	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(18, 24, 32)
	bg.BackgroundTransparency = 0.08
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = bg

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = isEmpty and Color3.fromRGB(180, 180, 180) or Color3.fromRGB(80, 255, 70)
	stroke.Parent = bg

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromScale(0.04, 0.08)
	nameLabel.Size = UDim2.fromScale(0.92, 0.45)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.25
	nameLabel.Text = isEmpty and "EMPTY PLOT" or tostring(displayName or playerName)
	nameLabel.Parent = bg

	local userLabel = Instance.new("TextLabel")
	userLabel.Name = "Username"
	userLabel.BackgroundTransparency = 1
	userLabel.Position = UDim2.fromScale(0.04, 0.53)
	userLabel.Size = UDim2.fromScale(0.92, 0.2)
	userLabel.Font = Enum.Font.FredokaOne
	userLabel.TextScaled = true
	userLabel.TextWrapped = true
	userLabel.TextColor3 = isEmpty and Color3.fromRGB(210, 210, 210) or Color3.fromRGB(160, 255, 160)
	userLabel.TextStrokeTransparency = 0.35
	userLabel.Text = isEmpty and "Waiting for player" or ("@" .. tostring(playerName))
	userLabel.Parent = bg

	local rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "Rebirths"
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.Position = UDim2.fromScale(0.04, 0.74)
	rebirthLabel.Size = UDim2.fromScale(0.92, 0.18)
	rebirthLabel.Font = Enum.Font.FredokaOne
	rebirthLabel.TextScaled = true
	rebirthLabel.TextWrapped = true
	rebirthLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	rebirthLabel.TextStrokeTransparency = 0.35
	rebirthLabel.Text = isEmpty and "" or ("Rebirths: " .. tostring(rebirths or 0))
	rebirthLabel.Parent = bg
end

local function setEmptySign(plot)
	if not plot then
		return
	end

	makeSurfaceText(findNameSignPart(plot), nil, nil, 0, true)
end

local function updatePlotSign(plot, player)
	if not plot or not player then
		return
	end

	makeSurfaceText(findNameSignPart(plot), player.Name, player.DisplayName, getRebirths(player), false)
end

local function disconnectSignListeners(player)
	local list = signConnections[player]
	if not list then
		return
	end

	for _, connection in ipairs(list) do
		if connection then
			connection:Disconnect()
		end
	end

	signConnections[player] = nil
end

local function connectSignListeners(player, plot)
	disconnectSignListeners(player)

	signConnections[player] = {}

	local function refresh()
		if player.Parent and plot.Parent then
			updatePlotSign(plot, player)
		end
	end

	table.insert(signConnections[player], player:GetAttributeChangedSignal("Rebirths"):Connect(refresh))

	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats", 15)
		if not leaderstats then
			return
		end

		local rebirths = leaderstats:WaitForChild("Rebirths", 15)
		if rebirths and rebirths:IsA("ValueBase") then
			table.insert(signConnections[player], rebirths.Changed:Connect(refresh))
			refresh()
		end
	end)
end

local function plotAlreadyOwnedByOnlinePlayer(plot)
	local ownerId = tonumber(plot:GetAttribute("OwnerUserId"))
	if not ownerId then
		return false
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == ownerId then
			return true
		end
	end

	return false
end

local function clearPlotOwner(plot)
	if not plot then
		return
	end

	assignedPlots[plot] = nil

	plot:SetAttribute("OwnerUserId", nil)
	plot:SetAttribute("OwnerName", nil)
	plot:SetAttribute("OwnerDisplayName", nil)
	plot:SetAttribute("Claimed", false)
	plot:SetAttribute("Owner", nil)

	clearOldPlotGuis(plot)
	setEmptySign(plot)
end

local function getFreePlot()
	for _, plot in ipairs(getAllPlots()) do
		if not assignedPlots[plot] and not plotAlreadyOwnedByOnlinePlayer(plot) then
			return plot
		end
	end

	return nil
end

local function setPlayerPlotAttributes(player, plot)
	if not player then
		return
	end

	if plot then
		player:SetAttribute("AssignedPlotName", plot.Name)
		player:SetAttribute("AssignedPlotFullName", plot:GetFullName())
	else
		player:SetAttribute("AssignedPlotName", nil)
		player:SetAttribute("AssignedPlotFullName", nil)
	end
end

local function assignPlayer(player)
	if not plotsInitialized then
		setPlayerPlotAttributes(player, nil)
		return nil
	end

	if playerPlots[player] and playerPlots[player].Parent then
		updatePlotSign(playerPlots[player], player)
		connectSignListeners(player, playerPlots[player])
		setPlayerPlotAttributes(player, playerPlots[player])
		return playerPlots[player]
	end

	local plot = getFreePlot()
	if not plot then
		warn("[PlotService] No free plot for", player.Name)
		setPlayerPlotAttributes(player, nil)
		return nil
	end

	assignedPlots[plot] = player
	playerPlots[player] = plot

	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.Name)
	plot:SetAttribute("OwnerDisplayName", player.DisplayName)
	plot:SetAttribute("Claimed", true)
	plot:SetAttribute("Owner", player.Name)
	setPlayerPlotAttributes(player, plot)

	clearOldPlotGuis(plot)
	updatePlotSign(plot, player)
	connectSignListeners(player, plot)

	print("[PlotService]", player.Name, "assigned to", plot:GetFullName())

	return plot
end

local teleportToPlot

local function assignPlayerWithRetry(player)
	task.spawn(function()
		for attempt = 1, 80 do
			if not player.Parent then
				return
			end

			local plot = assignPlayer(player)
			if plot then
				if teleportToPlot and player.Character then
					teleportToPlot(player, player.Character)
				end
				return
			end

			if attempt == 1 or attempt % 10 == 0 then
				warn("[PlotService] Waiting for an assignable plot for", player.Name, "attempt", attempt)
			end

			task.wait(0.5)
		end
	end)
end

teleportToPlot = function(player, character)
	local plot = playerPlots[player]
	if not plot then
		return
	end

	local base = findBaseFloor(plot)
	if not base then
		return
	end

	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end

	task.wait(0.2)

	root.CFrame = base.CFrame + Vector3.new(0, 6, 0)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function releasePlayer(player)
	local plot = playerPlots[player]

	if plot then
		clearPlotOwner(plot)
	end

	disconnectSignListeners(player)
	playerPlots[player] = nil
	setPlayerPlotAttributes(player, nil)
end

task.spawn(function()
	local plots = waitForAnyPlots(25)
	if #plots == 0 then
		warn("[PlotService] Could not find assignable plots during startup.")
		return
	end

	for _, plot in ipairs(plots) do
		clearPlotOwner(plot)
	end

	plotsInitialized = true

	for _, player in ipairs(Players:GetPlayers()) do
		assignPlayerWithRetry(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	assignPlayerWithRetry(player)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.25)
		assignPlayerWithRetry(player)
		teleportToPlot(player, character)
	end)
end)

Players.PlayerRemoving:Connect(releasePlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(function()
		assignPlayerWithRetry(player)

		if player.Character then
			teleportToPlot(player, player.Character)
		end
	end)
end

_G.BrainrotPlotService = {
	GetAllPlots = getAllPlots,
	GetPlayerPlot = function(player)
		return playerPlots[player]
	end,
}

print("[PlotService] Loaded fixed plot ownership system.")
