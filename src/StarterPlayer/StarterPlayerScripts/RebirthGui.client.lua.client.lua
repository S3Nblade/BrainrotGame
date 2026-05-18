--!nonstrict
-- StarterPlayerScripts/RebirthGui.client.lua
-- Rebirth GUI with visible button backgrounds + black-screen overlay remover.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local guiFolder = ReplicatedStorage:WaitForChild("GUI")
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local rebirthRequest = remotesFolder:WaitForChild("RebirthRequest")
local rebirthUpdate = remotesFolder:WaitForChild("RebirthUpdate")
local rebirthGetState = remotesFolder:WaitForChild("RebirthGetState")

local TEMPLATE_NAMES = {
	"rebirthT",
	"RebirthT",
	"rebirthTemplate",
	"RebirthTemplate",
}

local currentState = {
	rebirths = 0,
	strength = 0,
	requirement = 1000,
	progress = 0,
	moneyMultiplier = 1,
	nextMoneyMultiplier = 2,
	canRebirth = false,
}

local isOpen = false
local overlayCleanerConnection = nil

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

local function tween(instance, duration, properties, style, direction)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		properties
	)

	t:Play()
	return t
end

local function extractImage(asset)
	if not asset then
		return ""
	end

	if asset:IsA("ImageLabel") or asset:IsA("ImageButton") then
		return asset.Image
	elseif asset:IsA("Decal") or asset:IsA("Texture") then
		return asset.Texture
	elseif asset:IsA("StringValue") then
		return asset.Value
	end

	local ok, value = pcall(function()
		return asset.Image
	end)

	if ok and typeof(value) == "string" then
		return value
	end

	return ""
end

local function findTemplateImage()
	for _, name in ipairs(TEMPLATE_NAMES) do
		local asset = guiFolder:FindFirstChild(name)
		if asset then
			local image = extractImage(asset)
			if image ~= "" then
				return image
			end
		end
	end

	return ""
end

local templateImageId = findTemplateImage()

for _, gui in ipairs(playerGui:GetChildren()) do
	if gui.Name == "RebirthGui" then
		gui:Destroy()
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RebirthGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 180
screenGui.Parent = playerGui

local clickOutside = Instance.new("TextButton")
clickOutside.Name = "ClickOutside"
clickOutside.Size = UDim2.fromScale(1, 1)
clickOutside.BackgroundTransparency = 1
clickOutside.Text = ""
clickOutside.AutoButtonColor = false
clickOutside.Visible = false
clickOutside.ZIndex = 1
clickOutside.Parent = screenGui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(760, 460)
root.BackgroundTransparency = 1
root.Visible = false
root.ZIndex = 10
root.Parent = screenGui

local rootScale = Instance.new("UIScale")
rootScale.Scale = 0.82
rootScale.Parent = root

local template = Instance.new("ImageLabel")
template.Name = "Template"
template.AnchorPoint = Vector2.new(0.5, 0.5)
template.Position = UDim2.fromScale(0.5, 0.5)
template.Size = UDim2.fromScale(1, 1)
template.BackgroundTransparency = 1
template.Image = templateImageId
template.ScaleType = Enum.ScaleType.Fit
template.ZIndex = 10
template.Parent = root

local title = Instance.new("TextLabel")
title.Name = "Title"
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.54, 0.13)
title.Size = UDim2.fromScale(0.45, 0.11)
title.BackgroundTransparency = 1
title.Text = "REBIRTH"
title.TextScaled = true
title.Font = Enum.Font.FredokaOne
title.TextColor3 = Color3.fromRGB(255, 235, 70)
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.TextStrokeTransparency = 0
title.ZIndex = 20
title.Parent = root

local function makeText(name, pos, size, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = pos
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.ZIndex = 20
	label.Parent = root

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize or 32
	constraint.MinTextSize = 10
	constraint.Parent = label

	return label
end

local benefitLeft = makeText("BenefitLeft", UDim2.fromScale(0.37, 0.36), UDim2.fromScale(0.35, 0.08), 32)
benefitLeft.TextXAlignment = Enum.TextXAlignment.Left
benefitLeft.TextColor3 = Color3.fromRGB(120, 255, 75)

local benefitRight = makeText("BenefitRight", UDim2.fromScale(0.65, 0.36), UDim2.fromScale(0.36, 0.08), 32)
benefitRight.TextXAlignment = Enum.TextXAlignment.Left
benefitRight.TextColor3 = Color3.fromRGB(120, 255, 75)

local rebirthsText = makeText("RebirthsText", UDim2.fromScale(0.25, 0.56), UDim2.fromScale(0.34, 0.07), 30)
rebirthsText.TextXAlignment = Enum.TextXAlignment.Left

local progressText = makeText("ProgressText", UDim2.fromScale(0.5, 0.65), UDim2.fromScale(0.5, 0.06), 26)
local requirementText = makeText("RequirementText", UDim2.fromScale(0.5, 0.73), UDim2.fromScale(0.62, 0.06), 25)

local barBack = Instance.new("Frame")
barBack.Name = "ProgressBarBack"
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.645)
barBack.Size = UDim2.fromScale(0.68, 0.045)
barBack.BackgroundTransparency = 1
barBack.BorderSizePixel = 0
barBack.ClipsDescendants = true
barBack.ZIndex = 21
barBack.Parent = root

local barFill = Instance.new("Frame")
barFill.Name = "ProgressBarFill"
barFill.AnchorPoint = Vector2.new(0, 0.5)
barFill.Position = UDim2.fromScale(0, 0.5)
barFill.Size = UDim2.fromScale(0, 0.72)
barFill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
barFill.BorderSizePixel = 0
barFill.ZIndex = 22
barFill.Parent = barBack

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = barFill

local barGradient = Instance.new("UIGradient")
barGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 225, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 120, 255)),
})
barGradient.Parent = barFill

local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.AnchorPoint = Vector2.new(0.5, 0.5)
rebirthButton.Position = UDim2.fromScale(0.5, 0.84)
rebirthButton.Size = UDim2.fromScale(0.36, 0.12)
rebirthButton.BackgroundColor3 = Color3.fromRGB(95, 255, 25)
rebirthButton.BackgroundTransparency = 0.05
rebirthButton.AutoButtonColor = false
rebirthButton.Text = "REBIRTH"
rebirthButton.TextScaled = true
rebirthButton.Font = Enum.Font.FredokaOne
rebirthButton.TextColor3 = Color3.fromRGB(255, 245, 70)
rebirthButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
rebirthButton.TextStrokeTransparency = 0
rebirthButton.ZIndex = 30
rebirthButton.Parent = root

local rebirthButtonCorner = Instance.new("UICorner")
rebirthButtonCorner.CornerRadius = UDim.new(0, 22)
rebirthButtonCorner.Parent = rebirthButton

local rebirthButtonStroke = Instance.new("UIStroke")
rebirthButtonStroke.Name = "ButtonStroke"
rebirthButtonStroke.Thickness = 4
rebirthButtonStroke.Color = Color3.fromRGB(235, 255, 35)
rebirthButtonStroke.Parent = rebirthButton

local rebirthButtonGradient = Instance.new("UIGradient")
rebirthButtonGradient.Name = "ButtonGradient"
rebirthButtonGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 255, 45)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(85, 230, 15)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 145, 0)),
})
rebirthButtonGradient.Rotation = 90
rebirthButtonGradient.Parent = rebirthButton

local buttonConstraint = Instance.new("UITextSizeConstraint")
buttonConstraint.MaxTextSize = 42
buttonConstraint.MinTextSize = 16
buttonConstraint.Parent = rebirthButton

local fallbackOpenButton = Instance.new("TextButton")
fallbackOpenButton.Name = "OpenRebirthButton"
fallbackOpenButton.AnchorPoint = Vector2.new(1, 0.5)
fallbackOpenButton.Position = UDim2.new(1, -22, 0.5, 70)
fallbackOpenButton.Size = UDim2.fromOffset(142, 48)
fallbackOpenButton.BackgroundColor3 = Color3.fromRGB(85, 255, 25)
fallbackOpenButton.BackgroundTransparency = 0.03
fallbackOpenButton.AutoButtonColor = false
fallbackOpenButton.Text = "REBIRTH"
fallbackOpenButton.TextScaled = true
fallbackOpenButton.Font = Enum.Font.FredokaOne
fallbackOpenButton.TextColor3 = Color3.fromRGB(255, 245, 70)
fallbackOpenButton.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
fallbackOpenButton.TextStrokeTransparency = 0
fallbackOpenButton.ZIndex = 50
fallbackOpenButton.Parent = screenGui

local fallbackCorner = Instance.new("UICorner")
fallbackCorner.CornerRadius = UDim.new(0, 16)
fallbackCorner.Parent = fallbackOpenButton

local fallbackStroke = Instance.new("UIStroke")
fallbackStroke.Thickness = 3
fallbackStroke.Color = Color3.fromRGB(235, 255, 35)
fallbackStroke.Parent = fallbackOpenButton

local fallbackGradient = Instance.new("UIGradient")
fallbackGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 255, 45)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 155, 0)),
})
fallbackGradient.Rotation = 90
fallbackGradient.Parent = fallbackOpenButton

local function isFullScreenDarkOverlay(obj)
	if not obj:IsA("GuiObject") then
		return false
	end

	if obj:IsDescendantOf(screenGui) then
		return false
	end

	if not obj.Visible then
		return false
	end

	local absSize = obj.AbsoluteSize
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)

	local coversScreen = absSize.X >= viewport.X * 0.65 and absSize.Y >= viewport.Y * 0.65
	if not coversScreen then
		return false
	end

	local bg = obj.BackgroundColor3
	local dark = bg.R < 0.15 and bg.G < 0.15 and bg.B < 0.15
	local visibleBg = obj.BackgroundTransparency < 0.98

	if dark and visibleBg then
		return true
	end

	local lowerName = string.lower(obj.Name)
	if lowerName == "dim"
		or lowerName == "overlay"
		or lowerName == "black"
		or lowerName == "background"
		or string.find(lowerName, "dim")
		or string.find(lowerName, "overlay") then
		return true
	end

	return false
end

local function removeBlackScreenOverlays()
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if isFullScreenDarkOverlay(obj) then
			obj.BackgroundTransparency = 1

			if obj:IsA("TextButton") or obj:IsA("ImageButton") then
				obj.AutoButtonColor = false
			end
		end
	end
end

local function killOldDuplicateRebirthTemplates()
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if not obj:IsDescendantOf(screenGui) then
			local shouldHide = false

			if (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and templateImageId ~= "" and obj.Image == templateImageId then
				shouldHide = true
			end

			if obj:IsA("GuiObject") then
				local lowerName = string.lower(obj.Name)

				if lowerName == "rebirthpopup"
					or lowerName == "rebirthtemplate"
					or lowerName == "rebirthpanel"
					or lowerName == "rebirthroot" then
					shouldHide = true
				end
			end

			if shouldHide and obj:IsA("GuiObject") then
				obj.Visible = false
			end
		end
	end
end

local function setButtonUnlocked()
	rebirthButton.Text = "REBIRTH"
	rebirthButton.TextColor3 = Color3.fromRGB(255, 245, 70)
	rebirthButton.BackgroundColor3 = Color3.fromRGB(95, 255, 25)
	rebirthButtonStroke.Color = Color3.fromRGB(235, 255, 35)
	rebirthButtonGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 255, 45)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(85, 230, 15)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 145, 0)),
	})
end

local function setButtonLocked()
	rebirthButton.Text = "LOCKED"
	rebirthButton.TextColor3 = Color3.fromRGB(230, 230, 230)
	rebirthButton.BackgroundColor3 = Color3.fromRGB(95, 95, 95)
	rebirthButtonStroke.Color = Color3.fromRGB(180, 180, 180)
	rebirthButtonGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(145, 145, 145)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(65, 65, 65)),
	})
end

local function refresh()
	local s = currentState

	benefitLeft.Text = "+2X MONEY"
	benefitRight.Text = "BRAINROT CASH"
	rebirthsText.Text = "Rebirths: " .. tostring(s.rebirths or 0)
	progressText.Text = formatNumber(s.strength) .. " / " .. formatNumber(s.requirement)
	requirementText.Text = "Need " .. formatNumber(s.requirement) .. " Strength  •  Current money boost x" .. tostring(s.moneyMultiplier)

	if s.canRebirth then
		setButtonUnlocked()
	else
		setButtonLocked()
	end

	tween(barFill, 0.18, {
		Size = UDim2.fromScale(math.clamp(s.progress or 0, 0, 1), 0.72),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
end

local function requestState()
	local ok, result = pcall(function()
		return rebirthGetState:InvokeServer()
	end)

	if ok and type(result) == "table" then
		currentState = result
		refresh()
	end
end

local function startOverlayCleaner()
	if overlayCleanerConnection then
		overlayCleanerConnection:Disconnect()
	end

	overlayCleanerConnection = RunService.RenderStepped:Connect(function()
		if isOpen then
			removeBlackScreenOverlays()
		end
	end)
end

local function stopOverlayCleaner()
	if overlayCleanerConnection then
		overlayCleanerConnection:Disconnect()
		overlayCleanerConnection = nil
	end
end

local function openGui()
	if isOpen then
		return
	end

	isOpen = true
	requestState()

	killOldDuplicateRebirthTemplates()
	removeBlackScreenOverlays()
	startOverlayCleaner()

	clickOutside.Visible = true
	root.Visible = true
	rootScale.Scale = 0.72

	tween(rootScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.delay(0.05, removeBlackScreenOverlays)
	task.delay(0.15, removeBlackScreenOverlays)
	task.delay(0.35, removeBlackScreenOverlays)
end

local function closeGui()
	if not isOpen then
		return
	end

	isOpen = false
	stopOverlayCleaner()

	tween(rootScale, 0.14, { Scale = 0.72 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	task.delay(0.15, function()
		if not isOpen then
			clickOutside.Visible = false
			root.Visible = false
		end
	end)
end

local function buttonPop(button)
	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = button
	end

	tween(scale, 0.08, { Scale = 0.92 })
	task.delay(0.08, function()
		if scale.Parent then
			tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

rebirthButton.MouseButton1Click:Connect(function()
	buttonPop(rebirthButton)
	rebirthRequest:FireServer()
	task.delay(0.2, requestState)
end)

clickOutside.MouseButton1Click:Connect(closeGui)
fallbackOpenButton.MouseButton1Click:Connect(openGui)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.R then
		if isOpen then
			closeGui()
		else
			openGui()
		end
	elseif input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closeGui()
	end
end)

rebirthUpdate.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	currentState = payload
	refresh()
end)

local connectedButtons = {}

local function tryBindExistingRebirthButtons()
	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("GuiButton") and not connectedButtons[obj] then
			local lowerName = string.lower(obj.Name)

			if string.find(lowerName, "rebirth") and obj ~= rebirthButton and obj ~= fallbackOpenButton then
				connectedButtons[obj] = true
				obj.MouseButton1Click:Connect(function()
					task.defer(openGui)
				end)

				fallbackOpenButton.Visible = false
			end
		end
	end
end

playerGui.DescendantAdded:Connect(function()
	task.defer(tryBindExistingRebirthButtons)
end)

task.defer(function()
	requestState()
	task.wait(1)
	tryBindExistingRebirthButtons()
end)

print("[RebirthGui] Loaded with button backgrounds.")