--!nonstrict
-- StarterPlayer/StarterPlayerScripts/ScreenGoalArrow.client.lua
-- Clean first-session simulator guide: catch, place, collect.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local STEP_CATCH = 1
local STEP_PLACE = 2
local STEP_COLLECT = 3
local STEP_DONE = 4

local TARGET_REFRESH_EVERY = 0.45
local VETERAN_CHECK_DELAY = 2

local currentStep = STEP_CATCH
local currentTargetPart = nil
local lastTargetRefresh = 0
local completed = false

local baseline = {
	tools = 0,
	placed = 0,
	money = 0,
}

local ui = {}

local BRAINROT_TOOL_ATTRS = {
	"IsBrainrot",
	"BrainrotTool",
	"BrainrotUID",
	"UID",
	"BrainrotUid",
	"DirectInventoryUid",
	"InventoryUid",
	"CashPerSecond",
	"MPS",
	"Rarity",
	"BrainrotName",
	"DisplayName",
	"TemplateName",
}

local MONEY_NAMES = {
	"Money",
	"Cash",
	"Coins",
}

local function safeNumber(value)
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end

	return n
end

local function tween(instance, duration, props, style, direction)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function getCharacter()
	return player.Character
end

local function getHRP()
	local character = getCharacter()
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getFirstBasePart(inst)
	if not inst then
		return nil
	end

	if inst:IsA("BasePart") then
		return inst
	end

	if inst:IsA("Model") then
		if inst.PrimaryPart then
			return inst.PrimaryPart
		end

		local hrp = inst:FindFirstChild("HumanoidRootPart", true)
		if hrp and hrp:IsA("BasePart") then
			return hrp
		end
	end

	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			return d
		end
	end

	return nil
end

local function isBrainrotTool(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	local lowerName = string.lower(tool.Name)
	if string.find(lowerName, "weight") or string.find(lowerName, "net") or string.find(lowerName, "train") then
		return false
	end

	for _, attr in ipairs(BRAINROT_TOOL_ATTRS) do
		local value = tool:GetAttribute(attr)
		if value ~= nil and value ~= false then
			return true
		end
	end

	return string.find(lowerName, "brainrot") ~= nil
end

local function countBrainrotTools()
	local count = 0
	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if isBrainrotTool(child) then
				count += 1
			end
		end
	end

	local character = getCharacter()
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if isBrainrotTool(child) then
				count += 1
			end
		end
	end

	return count
end

local function getMoney()
	local best = 0

	for _, name in ipairs(MONEY_NAMES) do
		best = math.max(best, safeNumber(player:GetAttribute(name)))
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		for _, name in ipairs(MONEY_NAMES) do
			local value = leaderstats:FindFirstChild(name)
			if value and value:IsA("ValueBase") then
				best = math.max(best, safeNumber(value.Value))
			end
		end
	end

	return best
end

local function modelLooksPlaced(model)
	if not model or not model:IsA("Model") then
		return false
	end

	return model:GetAttribute("IsPlaced") == true
		or model:GetAttribute("Placed") == true
		or model:GetAttribute("AssignedSlotId") ~= nil
		or model:GetAttribute("SlotId") ~= nil
		or model:GetAttribute("StandId") ~= nil
end

local function modelOwnedByPlayer(model)
	if not model then
		return false
	end

	local ownerId = math.max(
		safeNumber(model:GetAttribute("PlacedOwnerUserId")),
		safeNumber(model:GetAttribute("OwnerUserId")),
		safeNumber(model:GetAttribute("CapturedByUserId")),
		safeNumber(model:GetAttribute("PlayerUserId"))
	)

	if ownerId == player.UserId then
		return true
	end

	local ownerName = tostring(model:GetAttribute("OwnerName") or model:GetAttribute("PlayerName") or model:GetAttribute("ClaimedBy") or "")
	return ownerName == player.Name
end

local function countPlacedBrainrots()
	local count = 0

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and modelLooksPlaced(inst) and modelOwnedByPlayer(inst) then
			count += 1
		end
	end

	return count
end

local function isWildBrainrot(model)
	if not model or not model:IsA("Model") or model == getCharacter() then
		return false
	end

	if modelLooksPlaced(model) or modelOwnedByPlayer(model) then
		return false
	end

	local lowerName = string.lower(model.Name)
	return string.find(lowerName, "brainrot") ~= nil
		or model:GetAttribute("BrainrotName") ~= nil
		or model:GetAttribute("Rarity") ~= nil
		or (model:FindFirstChildOfClass("Humanoid") and model.Parent and model.Parent.Name == "BrainrotNPCs")
end

local function findNearestWildBrainrot()
	local hrp = getHRP()
	if not hrp then
		return nil
	end

	local bestPart = nil
	local bestDist = math.huge
	local roots = {}

	local brainrotFolder = Workspace:FindFirstChild("BrainrotNPCs")
	if brainrotFolder then
		table.insert(roots, brainrotFolder)
	end

	table.insert(roots, Workspace)

	for _, root in ipairs(roots) do
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("Model") and isWildBrainrot(inst) then
				local part = getFirstBasePart(inst)
				if part then
					local dist = (part.Position - hrp.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestPart = part
					end
				end
			end
		end

		if bestPart then
			return bestPart
		end
	end

	return nil
end

local function instanceLooksOwnedByPlayer(inst)
	if not inst then
		return false
	end

	local ownerId = math.max(
		safeNumber(inst:GetAttribute("OwnerUserId")),
		safeNumber(inst:GetAttribute("PlayerUserId")),
		safeNumber(inst:GetAttribute("ClaimedByUserId"))
	)

	if ownerId == player.UserId then
		return true
	end

	local ownerName = tostring(inst:GetAttribute("OwnerName") or inst:GetAttribute("PlayerName") or inst:GetAttribute("ClaimedBy") or "")
	if ownerName == player.Name then
		return true
	end

	return string.find(string.lower(inst.Name), string.lower(player.Name)) ~= nil
end

local function findOwnPlot()
	local roots = {}

	for _, name in ipairs({ "plots", "Plots" }) do
		local root = Workspace:FindFirstChild(name)
		if root then
			table.insert(roots, root)
		end
	end

	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	local nestedPlots = spawnMap and spawnMap:FindFirstChild("Plots")
	if nestedPlots then
		table.insert(roots, nestedPlots)
	end

	for _, root in ipairs(roots) do
		for _, plot in ipairs(root:GetChildren()) do
			if instanceLooksOwnedByPlayer(plot) then
				return plot
			end

			for _, d in ipairs(plot:GetDescendants()) do
				if instanceLooksOwnedByPlayer(d) then
					return plot
				end
			end
		end
	end

	return nil
end

local function findNearestPartByNames(names)
	local hrp = getHRP()
	if not hrp then
		return nil
	end

	local bestPart = nil
	local bestDist = math.huge

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") then
			local lowerName = string.lower(inst.Name)

			for _, wanted in ipairs(names) do
				if string.find(lowerName, string.lower(wanted)) then
					local dist = (inst.Position - hrp.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestPart = inst
					end
				end
			end
		end
	end

	return bestPart
end

local function findStandTarget()
	local plot = findOwnPlot()

	if plot then
		for _, d in ipairs(plot:GetDescendants()) do
			if d:IsA("BasePart") then
				local lowerName = string.lower(d.Name)
				if string.find(lowerName, "brainrot stand")
					or string.find(lowerName, "stand")
					or string.find(lowerName, "slot") then
					return d
				end
			end
		end
	end

	return findNearestPartByNames({ "brainrot stand", "stand" })
end

local function findMoneyTarget()
	local plot = findOwnPlot()

	if plot then
		for _, d in ipairs(plot:GetDescendants()) do
			if d:IsA("BasePart") then
				local lowerName = string.lower(d.Name)
				if string.find(lowerName, "money collect")
					or string.find(lowerName, "collectmoney")
					or string.find(lowerName, "collect money") then
					return d
				end
			end
		end
	end

	return findNearestPartByNames({ "money collect", "collectmoney", "collect money" })
end

local function shouldSkipTutorial()
	return countPlacedBrainrots() > 0 and getMoney() > 0
end

local function getCurrentStepInfo()
	if currentStep == STEP_CATCH then
		return {
			icon = "1",
			title = "Catch 1 Brainrot",
			subtitle = "Follow the arrow to a wild Brainrot.",
			targetName = "Catch",
			target = findNearestWildBrainrot(),
		}
	end

	if currentStep == STEP_PLACE then
		return {
			icon = "2",
			title = "Place your Brainrot",
			subtitle = "Go to your plot stand and place it.",
			targetName = "Place",
			target = findStandTarget(),
		}
	end

	if currentStep == STEP_COLLECT then
		return {
			icon = "3",
			title = "Collect your money",
			subtitle = "Step on the green collect pad.",
			targetName = "Collect",
			target = findMoneyTarget(),
		}
	end

	return {
		icon = "OK",
		title = "Tutorial complete",
		subtitle = "Now hunt rares, upgrade, rebirth, and unlock zones.",
		targetName = "Done",
		target = nil,
	}
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
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function makeUI()
	local old = player:WaitForChild("PlayerGui"):FindFirstChild("ScreenGoalArrowGui")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ScreenGoalArrowGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 925
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player.PlayerGui

	local goalCard = Instance.new("Frame")
	goalCard.Name = "GoalCard"
	goalCard.AnchorPoint = Vector2.new(0.5, 0)
	goalCard.Position = UDim2.fromScale(0.5, 0.035)
	goalCard.Size = UDim2.fromOffset(430, 92)
	goalCard.BackgroundColor3 = Color3.fromRGB(255, 225, 79)
	goalCard.BorderSizePixel = 0
	goalCard.Parent = gui
	addCorner(goalCard, 22)

	local goalStroke = addStroke(goalCard, Color3.fromRGB(23, 27, 55), 4)

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 239, 107)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 139, 63)),
	})
	gradient.Parent = goalCard

	local shine = Instance.new("Frame")
	shine.Name = "TopShine"
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.76
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 10, 0, 8)
	shine.Size = UDim2.new(1, -20, 0, 18)
	shine.ZIndex = 2
	shine.Parent = goalCard
	addCorner(shine, 16)

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(14, 12)
	icon.Size = UDim2.fromOffset(56, 56)
	icon.Font = Enum.Font.FredokaOne
	icon.Text = "1"
	icon.TextScaled = true
	icon.TextColor3 = Color3.fromRGB(255, 255, 255)
	icon.TextStrokeTransparency = 0
	icon.TextStrokeColor3 = Color3.fromRGB(23, 27, 55)
	icon.ZIndex = 4
	icon.Parent = goalCard

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(82, 10)
	title.Size = UDim2.new(1, -104, 0, 27)
	title.Font = Enum.Font.FredokaOne
	title.Text = "Catch 1 Brainrot"
	title.TextSize = 21
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(23, 27, 55)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.ZIndex = 4
	title.Parent = goalCard

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(82, 39)
	subtitle.Size = UDim2.new(1, -104, 0, 21)
	subtitle.Font = Enum.Font.FredokaOne
	subtitle.Text = "Follow the arrow to a wild Brainrot."
	subtitle.TextSize = 14
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Color3.fromRGB(73, 45, 39)
	subtitle.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle.ZIndex = 4
	subtitle.Parent = goalCard

	local progressRow = Instance.new("Frame")
	progressRow.Name = "ProgressRow"
	progressRow.BackgroundTransparency = 1
	progressRow.Position = UDim2.fromOffset(82, 66)
	progressRow.Size = UDim2.new(1, -104, 0, 16)
	progressRow.ZIndex = 4
	progressRow.Parent = goalCard

	local progressLayout = Instance.new("UIListLayout")
	progressLayout.FillDirection = Enum.FillDirection.Horizontal
	progressLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	progressLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	progressLayout.Padding = UDim.new(0, 7)
	progressLayout.SortOrder = Enum.SortOrder.LayoutOrder
	progressLayout.Parent = progressRow

	local progressDots = {}
	for i = 1, 3 do
		local dot = Instance.new("Frame")
		dot.Name = "Step" .. tostring(i)
		dot.LayoutOrder = i
		dot.Size = UDim2.fromOffset(74, 12)
		dot.BackgroundColor3 = Color3.fromRGB(255, 247, 210)
		dot.BorderSizePixel = 0
		dot.ZIndex = 5
		dot.Parent = progressRow
		addCorner(dot, 12)
		addStroke(dot, Color3.fromRGB(23, 27, 55), 2)
		progressDots[i] = dot
	end

	local arrowHolder = Instance.new("Frame")
	arrowHolder.Name = "ArrowHolder"
	arrowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowHolder.Position = UDim2.fromScale(0.5, 0.5)
	arrowHolder.Size = UDim2.fromOffset(104, 104)
	arrowHolder.BackgroundColor3 = Color3.fromRGB(101, 238, 94)
	arrowHolder.BorderSizePixel = 0
	arrowHolder.Visible = false
	arrowHolder.Parent = gui
	addCorner(arrowHolder, 104)

	local arrowStroke = addStroke(arrowHolder, Color3.fromRGB(23, 27, 55), 4)

	local arrowGradient = Instance.new("UIGradient")
	arrowGradient.Rotation = 90
	arrowGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(137, 255, 108)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 188, 88)),
	})
	arrowGradient.Parent = arrowHolder

	local arrowScale = Instance.new("UIScale")
	arrowScale.Scale = 1
	arrowScale.Parent = arrowHolder

	local arrowText = Instance.new("TextLabel")
	arrowText.Name = "ArrowText"
	arrowText.BackgroundTransparency = 1
	arrowText.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowText.Position = UDim2.fromScale(0.5, 0.43)
	arrowText.Size = UDim2.fromOffset(80, 60)
	arrowText.Font = Enum.Font.FredokaOne
	arrowText.Text = ">"
	arrowText.TextScaled = true
	arrowText.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrowText.TextStrokeTransparency = 0
	arrowText.TextStrokeColor3 = Color3.fromRGB(23, 27, 55)
	arrowText.ZIndex = 4
	arrowText.Parent = arrowHolder

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name = "ArrowLabel"
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Position = UDim2.fromScale(0, 0.67)
	arrowLabel.Size = UDim2.fromScale(1, 0.22)
	arrowLabel.Font = Enum.Font.FredokaOne
	arrowLabel.Text = "GO"
	arrowLabel.TextScaled = true
	arrowLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrowLabel.TextStrokeTransparency = 0
	arrowLabel.TextStrokeColor3 = Color3.fromRGB(23, 27, 55)
	arrowLabel.ZIndex = 4
	arrowLabel.Parent = arrowHolder

	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Position = UDim2.fromScale(0, 0.86)
	distanceLabel.Size = UDim2.fromScale(1, 0.16)
	distanceLabel.Font = Enum.Font.FredokaOne
	distanceLabel.Text = ""
	distanceLabel.TextScaled = true
	distanceLabel.TextColor3 = Color3.fromRGB(255, 247, 210)
	distanceLabel.TextStrokeTransparency = 0
	distanceLabel.TextStrokeColor3 = Color3.fromRGB(23, 27, 55)
	distanceLabel.ZIndex = 4
	distanceLabel.Parent = arrowHolder

	ui.gui = gui
	ui.goalCard = goalCard
	ui.goalStroke = goalStroke
	ui.icon = icon
	ui.title = title
	ui.subtitle = subtitle
	ui.progressDots = progressDots
	ui.arrowHolder = arrowHolder
	ui.arrowStroke = arrowStroke
	ui.arrowScale = arrowScale
	ui.arrowText = arrowText
	ui.arrowLabel = arrowLabel
	ui.distanceLabel = distanceLabel
end

local function updateGoalCard(info)
	ui.icon.Text = info.icon
	ui.title.Text = info.title
	ui.subtitle.Text = info.subtitle
	ui.arrowLabel.Text = string.upper(info.targetName or "GO")

	for index, dot in ipairs(ui.progressDots or {}) do
		if currentStep == STEP_DONE or index < currentStep then
			dot.BackgroundColor3 = Color3.fromRGB(104, 242, 101)
		elseif index == currentStep then
			dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		else
			dot.BackgroundColor3 = Color3.fromRGB(255, 204, 128)
		end
	end
end

local function showStepPop()
	if not ui.goalCard then
		return
	end

	local scale = ui.goalCard:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = ui.goalCard
	end

	tween(scale, 0.08, { Scale = 1.07 }, Enum.EasingStyle.Back)
	task.delay(0.08, function()
		if scale.Parent then
			tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

local function makeBaseline()
	baseline.tools = countBrainrotTools()
	baseline.placed = countPlacedBrainrots()
	baseline.money = getMoney()
end

local function setStep(step)
	if completed then
		return
	end

	currentStep = step

	if currentStep == STEP_PLACE then
		baseline.placed = countPlacedBrainrots()
	elseif currentStep == STEP_COLLECT then
		baseline.money = getMoney()
	end

	local info = getCurrentStepInfo()
	currentTargetPart = info.target
	updateGoalCard(info)
	showStepPop()

	if currentStep == STEP_DONE then
		completed = true
		ui.arrowHolder.Visible = false

		task.delay(4, function()
			if ui.gui and ui.gui.Parent then
				tween(ui.goalCard, 0.24, { Position = UDim2.fromScale(0.5, -0.12) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.3, function()
					if ui.gui then
						ui.gui:Destroy()
					end
				end)
			end
		end)
	end
end

local function resetTutorial()
	completed = false
	makeBaseline()
	setStep(STEP_CATCH)
end

local function evaluateProgress()
	if completed then
		return
	end

	if currentStep == STEP_CATCH and countBrainrotTools() > baseline.tools then
		setStep(STEP_PLACE)
	elseif currentStep == STEP_PLACE and countPlacedBrainrots() > baseline.placed then
		setStep(STEP_COLLECT)
	elseif currentStep == STEP_COLLECT and getMoney() > baseline.money then
		setStep(STEP_DONE)
	end
end

local function refreshTarget()
	if completed then
		return
	end

	local info = getCurrentStepInfo()
	updateGoalCard(info)
	currentTargetPart = info.target

	if not currentTargetPart then
		ui.arrowHolder.Visible = false
		ui.subtitle.Text = "Looking for the next target..."
	end
end

local function updateScreenArrow()
	local camera = Workspace.CurrentCamera
	if not camera or completed or currentStep == STEP_DONE or not currentTargetPart or not currentTargetPart.Parent then
		ui.arrowHolder.Visible = false
		return
	end

	local hrp = getHRP()
	if not hrp then
		ui.arrowHolder.Visible = false
		return
	end

	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		ui.arrowHolder.Visible = false
		return
	end

	local targetWorldPos = currentTargetPart.Position + Vector3.new(0, 4, 0)
	local point, visible = camera:WorldToViewportPoint(targetWorldPos)
	local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
	local screenPos = Vector2.new(point.X, point.Y)

	if point.Z < 0 then
		screenPos = center - (screenPos - center)
		visible = false
	end

	local margin = 76
	local inside = point.Z > 0
		and screenPos.X > margin
		and screenPos.X < viewport.X - margin
		and screenPos.Y > margin
		and screenPos.Y < viewport.Y - margin

	local arrowX
	local arrowY

	if visible and inside then
		arrowX = screenPos.X
		arrowY = math.max(margin, screenPos.Y - 82)
		ui.arrowText.Text = "v"
		ui.arrowText.Rotation = 0
	else
		local direction = screenPos - center
		if direction.Magnitude < 1 then
			direction = Vector2.new(0, -1)
		end

		local unit = direction.Unit
		arrowX = math.clamp(center.X + unit.X * 9999, margin, viewport.X - margin)
		arrowY = math.clamp(center.Y + unit.Y * 9999, margin, viewport.Y - margin)

		local edgeDirection = Vector2.new(arrowX, arrowY) - center
		if edgeDirection.Magnitude < 1 then
			edgeDirection = unit
		end

		ui.arrowText.Text = ">"
		ui.arrowText.Rotation = math.deg(math.atan2(edgeDirection.Y, edgeDirection.X))
	end

	ui.arrowHolder.Visible = true
	ui.arrowHolder.Position = UDim2.fromOffset(arrowX, arrowY)
	ui.distanceLabel.Text = tostring(math.floor((currentTargetPart.Position - hrp.Position).Magnitude)) .. " studs"
end

makeUI()
resetTutorial()

task.delay(VETERAN_CHECK_DELAY, function()
	if not completed and shouldSkipTutorial() then
		setStep(STEP_DONE)
	end
end)

player.CharacterAdded:Connect(function()
	task.wait(1)
	refreshTarget()
end)

player.Chatted:Connect(function(message)
	local lower = string.lower(message)
	if lower == "!arrowreset" or lower == "/arrowreset" or lower == "!tutorialreset" then
		resetTutorial()
	end
end)

task.spawn(function()
	while ui.gui and ui.gui.Parent do
		task.wait(0.25)
		evaluateProgress()
	end
end)

RunService.RenderStepped:Connect(function()
	if not ui.gui or not ui.gui.Parent then
		return
	end

	local now = os.clock()
	if now - lastTargetRefresh >= TARGET_REFRESH_EVERY then
		lastTargetRefresh = now
		refreshTarget()
	end

	updateScreenArrow()

	local pulse = (math.sin(now * 4) + 1) / 2
	ui.arrowScale.Scale = 1 + pulse * 0.06
	ui.arrowStroke.Transparency = pulse * 0.12
	ui.goalStroke.Transparency = pulse * 0.08
end)

print("[ScreenGoalArrow] Loaded first-session simulator guide.")
