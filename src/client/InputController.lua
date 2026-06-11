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
local attackHeld = false
local unlockedZones = { Grass = true }

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
	targetLabel.Size = UDim2.fromOffset(310, 42)
	targetLabel.BackgroundColor3 = Color3.fromRGB(31, 35, 51)
	targetLabel.BackgroundTransparency = 0.08
	targetLabel.BorderSizePixel = 0
	targetLabel.Font = Enum.Font.GothamBlack
	targetLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
	targetLabel.TextStrokeTransparency = 0.55
	targetLabel.TextScaled = true
	targetLabel.Visible = false
	targetLabel.Parent = gui
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 20
	constraint.MinTextSize = 12
	constraint.Parent = targetLabel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(16, 18, 29)
	stroke.Thickness = 3
	stroke.Parent = targetLabel
end

local function updateTarget()
	local target, distance = closestBrainrot(nil)
	highlight.Adornee = target
	if not target then
		targetLabel.Visible = false
		return
	end
	local stunned = target:GetAttribute("Stunned") == true
	local inRange = distance <= (stunned and context.Config.Economy.CaptureRange or context.Config.Economy.AttackRange)
	highlight.FillColor = stunned and Color3.fromRGB(255, 226, 74) or Color3.fromRGB(255, 92, 92)
	highlight.OutlineColor = inRange and Color3.new(1, 1, 1) or Color3.fromRGB(90, 94, 112)
	highlight.FillTransparency = inRange and 0.68 or 0.88
	local definition = context.Config.Brainrots[target:GetAttribute("BrainrotId")]
	local action = stunned and "E: CAPTURE" or "CLICK / SPACE: ATTACK"
	targetLabel.Text =
		string.format("%s  |  %.0f studs  |  %s", definition and definition.Name or target.Name, distance, action)
	targetLabel.TextColor3 = inRange and Color3.fromRGB(245, 248, 255) or Color3.fromRGB(170, 180, 204)
	targetLabel.Visible = true
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
	end)
	task.spawn(function()
		local success, initial = pcall(function()
			return context.Remotes.GetState:InvokeServer()
		end)
		if success and initial then
			unlockedZones = initial.UnlockedZones or unlockedZones
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
	if not UserInputService.TouchEnabled then
		ContextActionService:SetImage("PixelAttack", "")
	end
	RunService.RenderStepped:Connect(updateTarget)
end

return InputController
