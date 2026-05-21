--!nonstrict
-- ServerScriptService/PlotService.lua
-- Fixed plot ownership system for Workspace.plots / Workspace.Plots.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local SIGN_FACE = Enum.NormalId.Back

local assignedPlots = {}
local playerPlots = {}
local signConnections = {}

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

local function getAllPlots()
	local plotsFolder = getPlotsFolder()
	local plots = {}

	if not plotsFolder then
		warn("[PlotService] Missing Workspace.plots or Workspace.Plots")
		return plots
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if (plot:IsA("Model") or plot:IsA("Folder") or plot:IsA("BasePart")) and getFirstBasePart(plot) then
			table.insert(plots, plot)
		end
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

local function assignPlayer(player)
	if playerPlots[player] and playerPlots[player].Parent then
		updatePlotSign(playerPlots[player], player)
		connectSignListeners(player, playerPlots[player])
		return playerPlots[player]
	end

	local plot = getFreePlot()
	if not plot then
		warn("[PlotService] No free plot for", player.Name)
		return nil
	end

	assignedPlots[plot] = player
	playerPlots[player] = plot

	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("OwnerName", player.Name)
	plot:SetAttribute("OwnerDisplayName", player.DisplayName)
	plot:SetAttribute("Claimed", true)
	plot:SetAttribute("Owner", player.Name)

	clearOldPlotGuis(plot)
	updatePlotSign(plot, player)
	connectSignListeners(player, plot)

	print("[PlotService]", player.Name, "assigned to", plot:GetFullName())

	return plot
end

local function teleportToPlot(player, character)
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
end

for _, plot in ipairs(getAllPlots()) do
	clearPlotOwner(plot)
end

Players.PlayerAdded:Connect(function(player)
	assignPlayer(player)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.25)
		assignPlayer(player)
		teleportToPlot(player, character)
	end)
end)

Players.PlayerRemoving:Connect(releasePlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(function()
		assignPlayer(player)

		if player.Character then
			teleportToPlot(player, player.Character)
		end
	end)
end

print("[PlotService] Loaded fixed plot ownership system.")
