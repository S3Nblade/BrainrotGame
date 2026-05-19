--!nonstrict
-- StarterPlayer/StarterPlayerScripts/ScreenGoalArrow.client.lua
-- 2D simulator-style GUI arrow that follows/points to the next goal.
-- Client-only. No RemoteEvents needed.
--
-- Steps:
-- 1. Catch 1 Brainrot
-- 2. Place it on your plot
-- 3. Collect money
--
-- Test reset:
-- Type in chat: !arrowreset

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local TutorialEnabled = false

if not TutorialEnabled then
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("ScreenGoalArrowGui")
	if old then
		old:Destroy()
	end
	print("[ScreenGoalArrow] Tutorial disabled by config.")
	return
end

local STEP_CATCH = 1
local STEP_PLACE = 2
local STEP_COLLECT = 3
local STEP_DONE = 4

local currentStep = STEP_CATCH
local currentTargetPart = nil
local lastTargetRefresh = 0
local TARGET_REFRESH_EVERY = 0.45

local baseline = {
	tools = 0,
	placed = 0,
	money = 0,
}

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

local ui = {}

local function safeNumber(value)
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return 0
	end

	return n
end

local function getCharacter()
	return player.Character
end

local function getHRP()
	local character = getCharacter()
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
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

	if string.find(lowerName, "weight") then
		return false
	end

	if string.find(lowerName, "net") then
		return false
	end

	if string.find(lowerName, "train") then
		return false
	end

	for _, attr in ipairs(BRAINROT_TOOL_ATTRS) do
		local value = tool:GetAttribute(attr)
		if value ~= nil and value ~= false then
			return true
		end
	end

	if string.find(lowerName, "brainrot") then
		return true
	end

	return false
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
			if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
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
	if ownerName == player.Name then
		return true
	end

	return false
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
	if not model or not model:IsA("Model") then
		return false
	end

	if model == getCharacter() then
		return false
	end

	if modelLooksPlaced(model) then
		return false
	end

	if modelOwnedByPlayer(model) then
		return false
	end

	local lowerName = string.lower(model.Name)

	if string.find(lowerName, "brainrot") then
		return true
	end

	if model:GetAttribute("BrainrotName") ~= nil then
		return true
	end

	if model:GetAttribute("Rarity") ~= nil then
		return true
	end

	if model:FindFirstChildOfClass("Humanoid") and model.Parent and model.Parent.Name == "BrainrotNPCs" then
		return true
	end

	return false
end

local function findNearestWildBrainrot()
	local hrp = getHRP()
	if not hrp then
		return nil
	end

	local bestPart = nil
	local bestDist = math.huge

	local searchRoots = {}

	local brainrotFolder = Workspace:FindFirstChild("BrainrotNPCs")
	if brainrotFolder then
		table.insert(searchRoots, brainrotFolder)
	end

	local forestMap = Workspace:FindFirstChild("ForestMap1")
	if forestMap then
		table.insert(searchRoots, forestMap)
	end

	table.insert(searchRoots, Workspace)

	for _, root in ipairs(searchRoots) do
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

	local lowerName = string.lower(inst.Name)
	if string.find(lowerName, string.lower(player.Name)) then
		return true
	end

	return false
end

local function findOwnPlot()
	local roots = {}

	local plotsLower = Workspace:FindFirstChild("plots")
	if plotsLower then
		table.insert(roots, plotsLower)
	end

	local plotsUpper = Workspace:FindFirstChild("Plots")
	if plotsUpper then
		table.insert(roots, plotsUpper)
	end

	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	if spawnMap then
		local nestedPlots = spawnMap:FindFirstChild("Plots")
		if nestedPlots then
			table.insert(roots, nestedPlots)
		end
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

				if string.find(lowerName, "brainrot stand") then
					return d
				end

				if string.find(lowerName, "stand") then
					return d
				end

				if string.find(lowerName, "slot") then
					return d
				end
			end
		end
	end

	return findNearestPartByNames({
		"brainrot stand",
		"stand",
	})
end

local function findMoneyTarget()
	local plot = findOwnPlot()

	if plot then
		for _, d in ipairs(plot:GetDescendants()) do
			if d:IsA("BasePart") then
				local lowerName = string.lower(d.Name)

				if string.find(lowerName, "money collect") then
					return d
				end

				if string.find(lowerName, "collectmoney") then
					return d
				end

				if string.find(lowerName, "collect money") then
					return d
				end
			end
		end
	end

	return findNearestPartByNames({
		"money collect",
		"collectmoney",
		"collect money",
	})
end

local function getCurrentStepInfo()
	if currentStep == STEP_CATCH then
		return {
			icon = "🧠",
			title = "Catch 1 Brainrot",
			subtitle = "Follow the arrow to a wild Brainrot.",
			targetName = "Brainrot",
			target = findNearestWildBrainrot(),
		}
	end

	if currentStep == STEP_PLACE then
		return {
			icon = "🏠",
			title = "Place your Brainrot",
			subtitle = "Go to your plot stand.",
			targetName = "Plot",
			target = findStandTarget(),
		}
	end

	if currentStep == STEP_COLLECT then
		return {
			icon = "💵",
			title = "Collect money",
			subtitle = "Go to your money collect part.",
			targetName = "Money",
			target = findMoneyTarget(),
		}
	end

	return {
		icon = "🏆",
		title = "Tutorial complete",
		subtitle = "Now hunt rares, upgrade, and unlock zones.",
		targetName = "Done",
		target = nil,
	}
end

local function makeBaseline()
	baseline.tools = countBrainrotTools()
	baseline.placed = countPlacedBrainrots()
	baseline.money = getMoney()
end

local function makeUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ScreenGoalArrowGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local goalCard = Instance.new("Frame")
	goalCard.Name = "GoalCard"
	goalCard.AnchorPoint = Vector2.new(0.5, 0)
	goalCard.Position = UDim2.fromScale(0.5, 0.035)
	goalCard.Size = UDim2.fromOffset(390, 70)
	goalCard.BackgroundColor3 = Color3.fromRGB(18, 24, 18)
	goalCard.BackgroundTransparency = 0.04
	goalCard.BorderSizePixel = 0
	goalCard.Parent = gui

	local goalCorner = Instance.new("UICorner")
	goalCorner.CornerRadius = UDim.new(0, 20)
	goalCorner.Parent = goalCard

	local goalStroke = Instance.new("UIStroke")
	goalStroke.Color = Color3.fromRGB(72, 255, 105)
	goalStroke.Thickness = 3
	goalStroke.Transparency = 0.08
	goalStroke.Parent = goalCard

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(13, 8)
	icon.Size = UDim2.fromOffset(54, 54)
	icon.Font = Enum.Font.GothamBlack
	icon.Text = "🧠"
	icon.TextScaled = true
	icon.TextColor3 = Color3.fromRGB(255, 255, 255)
	icon.Parent = goalCard

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(76, 10)
	title.Size = UDim2.new(1, -94, 0, 25)
	title.Font = Enum.Font.GothamBlack
	title.Text = "Catch 1 Brainrot"
	title.TextSize = 19
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(96, 255, 126)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = goalCard

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(76, 37)
	subtitle.Size = UDim2.new(1, -94, 0, 21)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = "Follow the arrow to a wild Brainrot."
	subtitle.TextSize = 14
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Color3.fromRGB(230, 255, 232)
	subtitle.TextTruncate = Enum.TextTruncate.AtEnd
	subtitle.Parent = goalCard

	local arrowHolder = Instance.new("Frame")
	arrowHolder.Name = "ArrowHolder"
	arrowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowHolder.Position = UDim2.fromScale(0.5, 0.5)
	arrowHolder.Size = UDim2.fromOffset(96, 96)
	arrowHolder.BackgroundColor3 = Color3.fromRGB(20, 30, 20)
	arrowHolder.BackgroundTransparency = 0.05
	arrowHolder.BorderSizePixel = 0
	arrowHolder.Visible = false
	arrowHolder.Parent = gui

	local arrowCorner = Instance.new("UICorner")
	arrowCorner.CornerRadius = UDim.new(1, 0)
	arrowCorner.Parent = arrowHolder

	local arrowStroke = Instance.new("UIStroke")
	arrowStroke.Color = Color3.fromRGB(72, 255, 105)
	arrowStroke.Thickness = 4
	arrowStroke.Transparency = 0.02
	arrowStroke.Parent = arrowHolder

	local arrowScale = Instance.new("UIScale")
	arrowScale.Scale = 1
	arrowScale.Parent = arrowHolder

	local arrowText = Instance.new("TextLabel")
	arrowText.Name = "ArrowText"
	arrowText.BackgroundTransparency = 1
	arrowText.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowText.Position = UDim2.fromScale(0.5, 0.43)
	arrowText.Size = UDim2.fromOffset(80, 60)
	arrowText.Font = Enum.Font.GothamBlack
	arrowText.Text = "➤"
	arrowText.TextScaled = true
	arrowText.TextColor3 = Color3.fromRGB(72, 255, 105)
	arrowText.TextStrokeTransparency = 0
	arrowText.TextStrokeColor3 = Color3.fromRGB(0, 55, 10)
	arrowText.Parent = arrowHolder

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name = "ArrowLabel"
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Position = UDim2.fromScale(0, 0.67)
	arrowLabel.Size = UDim2.fromScale(1, 0.22)
	arrowLabel.Font = Enum.Font.GothamBlack
	arrowLabel.Text = "GO"
	arrowLabel.TextScaled = true
	arrowLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	arrowLabel.TextStrokeTransparency = 0.25
	arrowLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	arrowLabel.Parent = arrowHolder

	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "DistanceLabel"
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Position = UDim2.fromScale(0, 0.86)
	distanceLabel.Size = UDim2.fromScale(1, 0.16)
	distanceLabel.Font = Enum.Font.GothamBold
	distanceLabel.Text = ""
	distanceLabel.TextScaled = true
	distanceLabel.TextColor3 = Color3.fromRGB(190, 255, 198)
	distanceLabel.TextStrokeTransparency = 0.4
	distanceLabel.Parent = arrowHolder

	ui.gui = gui
	ui.goalCard = goalCard
	ui.goalStroke = goalStroke
	ui.icon = icon
	ui.title = title
	ui.subtitle = subtitle
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
end

local function setStep(step)
	currentStep = step

	if currentStep == STEP_PLACE then
		baseline.placed = countPlacedBrainrots()
	elseif currentStep == STEP_COLLECT then
		baseline.money = getMoney()
	end

	local info = getCurrentStepInfo()
	currentTargetPart = info.target
	updateGoalCard(info)

	if currentStep == STEP_DONE then
		ui.arrowHolder.Visible = false
	end
end

local function resetTutorial()
	makeBaseline()
	setStep(STEP_CATCH)
end

local function evaluateProgress()
	if currentStep == STEP_CATCH then
		if countBrainrotTools() > baseline.tools then
			setStep(STEP_PLACE)
			return
		end
	end

	if currentStep == STEP_PLACE then
		if countPlacedBrainrots() > baseline.placed then
			setStep(STEP_COLLECT)
			return
		end
	end

	if currentStep == STEP_COLLECT then
		if getMoney() > baseline.money then
			setStep(STEP_DONE)
			return
		end
	end
end

local function refreshTarget()
	local info = getCurrentStepInfo()
	updateGoalCard(info)
	currentTargetPart = info.target

	if not currentTargetPart then
		if currentStep ~= STEP_DONE then
			ui.arrowHolder.Visible = false
			ui.subtitle.Text = "Looking for the next target..."
		end
	end
end

local function updateScreenArrow()
	local camera = Workspace.CurrentCamera
	if not camera or currentStep == STEP_DONE or not currentTargetPart or not currentTargetPart.Parent then
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

	local margin = 72
	local isInside =
		point.Z > 0
		and screenPos.X > margin
		and screenPos.X < viewport.X - margin
		and screenPos.Y > margin
		and screenPos.Y < viewport.Y - margin

	local arrowX
	local arrowY
	local rotation

	if visible and isInside then
		arrowX = screenPos.X
		arrowY = math.max(margin, screenPos.Y - 76)

		ui.arrowText.Text = "⬇"
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

		rotation = math.deg(math.atan2(edgeDirection.Y, edgeDirection.X))

		ui.arrowText.Text = "➤"
		ui.arrowText.Rotation = rotation
	end

	ui.arrowHolder.Visible = true
	ui.arrowHolder.Position = UDim2.fromOffset(arrowX, arrowY)

	local distance = (currentTargetPart.Position - hrp.Position).Magnitude
	ui.distanceLabel.Text = tostring(math.floor(distance)) .. " studs"
end

makeUI()
resetTutorial()

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
	while true do
		task.wait(0.25)
		evaluateProgress()
	end
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()

	if now - lastTargetRefresh >= TARGET_REFRESH_EVERY then
		lastTargetRefresh = now
		refreshTarget()
	end

	updateScreenArrow()

	local pulse = (math.sin(now * 4) + 1) / 2
	ui.arrowScale.Scale = 1 + pulse * 0.06
	ui.arrowStroke.Transparency = 0.02 + pulse * 0.18
	ui.goalStroke.Transparency = 0.08 + pulse * 0.14
end)

print("[ScreenGoalArrow] Loaded 2D GUI arrow tutorial.")
