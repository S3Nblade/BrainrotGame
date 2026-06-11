local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local InputController = {}
local player = Players.LocalPlayer
local context
local highlight
local targetLabel
local guidePanel
local guideLabel
local attackHeld = false
local unlockedZones = { Grass = true }
local questStage = 1

local function questGuide()
	if questStage == 2 then
		return "NEXT: OPEN BAG AND PLACE YOUR CREATURE"
	end
	if questStage == 3 then
		return "NEXT: OPEN BAG AND UPGRADE"
	end
	if questStage == 5 then
		return "NEXT: OPEN ZONES AND UNLOCK DESERT"
	end
	if questStage == 6 then
		return "NEXT: EARN $10K AND REBIRTH"
	end
	return nil
end

local function closestBrainrot(requireStunned)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best
	local bestDistance = math.huge
	for _, model in ipairs(CollectionService:GetTagged("Brainrot")) do
		local modelRoot = model.PrimaryPart
		if modelRoot then
			local stunned = model:GetAttribute("Stunned") == true
			local zoneUnlocked = unlockedZones[model:GetAttribute("ZoneId")] == true
			if zoneUnlocked and (requireStunned == nil or stunned == requireStunned) then
				local distance = (root.Position - modelRoot.Position).Magnitude
				if distance < bestDistance then
					best = model
					bestDistance = distance
				end
			end
		end
	end
	return best, bestDistance
end

local function canStartAttack(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		for _, object in ipairs(context.PlayerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y)) do
			if object:IsA("GuiButton") or object:FindFirstAncestorWhichIsA("GuiButton") then
				return false
			end
		end
	end
	return true
end

local function tryAttack()
	local model, distance = closestBrainrot(false)
	if model and distance <= context.Config.Economy.AttackRange then
		context.Remotes.AttackRequest:FireServer(model)
	end
end

local function attack(_, state, input)
	if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		attackHeld = false
		return Enum.ContextActionResult.Pass
	end
	if state ~= Enum.UserInputState.Begin or not canStartAttack(input) then
		return Enum.ContextActionResult.Pass
	end
	if attackHeld then
		return Enum.ContextActionResult.Sink
	end
	attackHeld = true
	tryAttack()
	task.spawn(function()
		while attackHeld do
			task.wait(context.Config.Economy.AttackCooldown * 0.9)
			if attackHeld then
				tryAttack()
			end
		end
	end)
	return input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.ContextActionResult.Pass
		or Enum.ContextActionResult.Sink
end

local function capture(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local model, distance = closestBrainrot(true)
	if model and distance <= context.Config.Economy.CaptureRange then
		context.Remotes.CaptureRequest:FireServer(model)
	end
	return Enum.ContextActionResult.Sink
end

local function makeTargetGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TargetGuide"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 12
	gui.Parent = context.PlayerGui
	targetLabel = Instance.new("TextLabel")
	targetLabel.AnchorPoint = Vector2.new(1, 0)
	targetLabel.Position = UDim2.new(1, -18, 0, 112)
	targetLabel.Size = UDim2.new(0.58, 0, 0, 42)
	targetLabel.BackgroundColor3 = Color3.fromRGB(31, 35, 51)
	targetLabel.BackgroundTransparency = 0.08
	targetLabel.BorderSizePixel = 0
	targetLabel.Font = Enum.Font.GothamBlack
	targetLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
	targetLabel.TextStrokeTransparency = 0.55
	targetLabel.TextScaled = true
	targetLabel.Visible = false
	targetLabel.Parent = gui
	local targetSizeConstraint = Instance.new("UISizeConstraint")
	targetSizeConstraint.MinSize = Vector2.new(220, 42)
	targetSizeConstraint.MaxSize = Vector2.new(310, 42)
	targetSizeConstraint.Parent = targetLabel
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 20
	constraint.MinTextSize = 12
	constraint.Parent = targetLabel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(16, 18, 29)
	stroke.Thickness = 3
	stroke.Parent = targetLabel

	guidePanel = Instance.new("Frame")
	guidePanel.Name = "NextMove"
	guidePanel.AnchorPoint = Vector2.new(0.5, 1)
	guidePanel.Position = UDim2.new(0.5, 0, 1, -22)
	guidePanel.Size = UDim2.new(0.7, 0, 0, 54)
	guidePanel.BackgroundColor3 = Color3.fromRGB(31, 35, 51)
	guidePanel.BackgroundTransparency = 0.04
	guidePanel.BorderSizePixel = 0
	guidePanel.Parent = gui
	local guideStroke = Instance.new("UIStroke")
	guideStroke.Color = Color3.fromRGB(255, 218, 72)
	guideStroke.Thickness = 3
	guideStroke.Parent = guidePanel
	local guideConstraint = Instance.new("UISizeConstraint")
	guideConstraint.MinSize = Vector2.new(230, 48)
	guideConstraint.MaxSize = Vector2.new(430, 54)
	guideConstraint.Parent = guidePanel
	guideLabel = Instance.new("TextLabel")
	guideLabel.Size = UDim2.new(1, -20, 1, -10)
	guideLabel.Position = UDim2.fromOffset(10, 5)
	guideLabel.BackgroundTransparency = 1
	guideLabel.Font = Enum.Font.GothamBlack
	guideLabel.TextColor3 = Color3.fromRGB(255, 218, 72)
	guideLabel.TextStrokeTransparency = 0.55
	guideLabel.TextScaled = true
	guideLabel.Parent = guidePanel
	local guideTextConstraint = Instance.new("UITextSizeConstraint")
	guideTextConstraint.MaxTextSize = 22
	guideTextConstraint.MinTextSize = 12
	guideTextConstraint.Parent = guideLabel
end

local function updateTarget()
	local target, distance = closestBrainrot(nil)
	highlight.Adornee = target
	local touch = UserInputService.TouchEnabled
	local questInstruction = questGuide()
	if not target then
		targetLabel.Visible = false
		guideLabel.Text = questInstruction
			or (questStage <= 4 and "NEXT: FIND A PIXEL CREATURE" or "NEXT: FOLLOW YOUR QUEST")
		return
	end
	local stunned = target:GetAttribute("Stunned") == true
	local inRange = distance <= (stunned and context.Config.Economy.CaptureRange or context.Config.Economy.AttackRange)
	highlight.FillColor = stunned and Color3.fromRGB(255, 226, 74) or Color3.fromRGB(255, 92, 92)
	highlight.OutlineColor = inRange and Color3.new(1, 1, 1) or Color3.fromRGB(90, 94, 112)
	highlight.FillTransparency = inRange and 0.68 or 0.88
	local definition = context.Config.Brainrots[target:GetAttribute("BrainrotId")]
	local action
	if stunned then
		action = touch and "TAP CAPTURE" or "E: CAPTURE"
	else
		action = touch and "HOLD ATTACK" or "HOLD CLICK / SPACE"
	end
	targetLabel.Text =
		string.format("%s  |  %.0f studs  |  %s", definition and definition.Name or target.Name, distance, action)
	targetLabel.TextColor3 = inRange and Color3.fromRGB(245, 248, 255) or Color3.fromRGB(170, 180, 204)
	targetLabel.Visible = true
	if not inRange then
		guideLabel.Text = string.format("NEXT: GET CLOSER  %.0f STUDS", distance)
	elseif stunned then
		guideLabel.Text = touch and "NEXT: TAP CAPTURE!" or "NEXT: PRESS E TO CAPTURE!"
	else
		guideLabel.Text = touch and "NEXT: HOLD ATTACK!" or "NEXT: HOLD CLICK OR SPACE!"
	end
	if questInstruction then
		guideLabel.Text = questInstruction
	end
end

local function styleTouchButton(actionName, color)
	task.defer(function()
		local button
		for _ = 1, 20 do
			button = ContextActionService:GetButton(actionName)
			if button then
				break
			end
			task.wait(0.05)
		end
		if not button then
			return
		end
		button.Size = UDim2.fromOffset(86, 86)
		button.BackgroundColor3 = color
		button.BackgroundTransparency = 0.08
		button.ImageTransparency = 1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(18, 20, 31)
		stroke.Thickness = 4
		stroke.Parent = button
		for _, descendant in ipairs(button:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				descendant.Font = Enum.Font.GothamBlack
				descendant.TextColor3 = Color3.fromRGB(245, 248, 255)
				descendant.TextStrokeTransparency = 0.45
				descendant.TextScaled = true
			end
		end
	end)
end

function InputController.Init(newContext)
	context = newContext
	highlight = Instance.new("Highlight")
	highlight.Name = "TargetHighlight"
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = true
	highlight.Parent = workspace.CurrentCamera
	makeTargetGui()
end

function InputController.Start()
	context.Remotes.StateChanged.OnClientEvent:Connect(function(newState)
		unlockedZones = newState.UnlockedZones or unlockedZones
		questStage = newState.QuestStage or questStage
	end)
	task.spawn(function()
		local success, initial = pcall(function()
			return context.Remotes.GetState:InvokeServer()
		end)
		if success and initial then
			unlockedZones = initial.UnlockedZones or unlockedZones
			questStage = initial.QuestStage or questStage
		end
	end)
	ContextActionService:BindAction(
		"PixelAttack",
		attack,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle("PixelAttack", "ATTACK")
	ContextActionService:SetPosition("PixelAttack", UDim2.new(1, -150, 1, -155))
	ContextActionService:BindAction("PixelCapture", capture, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("PixelCapture", "CAPTURE")
	ContextActionService:SetPosition("PixelCapture", UDim2.new(1, -265, 1, -110))
	if UserInputService.TouchEnabled then
		styleTouchButton("PixelAttack", Color3.fromRGB(255, 89, 104))
		styleTouchButton("PixelCapture", Color3.fromRGB(255, 196, 63))
	else
		ContextActionService:SetImage("PixelAttack", "")
	end
	RunService.RenderStepped:Connect(updateTarget)
end

return InputController
