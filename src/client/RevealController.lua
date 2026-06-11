local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RevealController = {}
local context
local overlay
local egg
local crack
local silhouettes
local result
local busy = false

local function tween(instance, time, properties, style, direction)
	local animation = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		properties
	)
	animation:Play()
	return animation
end

function RevealController.Init(newContext)
	context = newContext
	local gui = Instance.new("ScreenGui")
	gui.Name = "RevealGui"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.Parent = context.PlayerGui
	overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	overlay.BackgroundTransparency = 1
	overlay.Visible = false
	overlay.Parent = gui
	egg = Instance.new("Frame")
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.Position = UDim2.fromScale(0.5, 0.48)
	egg.Size = UDim2.fromOffset(130, 170)
	egg.BackgroundColor3 = Color3.fromRGB(242, 239, 220)
	egg.BorderSizePixel = 0
	egg.Parent = overlay
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.45, 0)
	corner.Parent = egg
	crack = Instance.new("Frame")
	crack.AnchorPoint = Vector2.new(0.5, 0.5)
	crack.Position = UDim2.fromScale(0.5, 0.52)
	crack.Size = UDim2.fromOffset(8, 80)
	crack.Rotation = 24
	crack.BackgroundColor3 = Color3.fromRGB(60, 57, 68)
	crack.BorderSizePixel = 0
	crack.Visible = false
	crack.Parent = egg
	silhouettes = Instance.new("Frame")
	silhouettes.AnchorPoint = Vector2.new(0.5, 0.5)
	silhouettes.Position = UDim2.fromScale(0.75, 0.5)
	silhouettes.Size = UDim2.fromOffset(820, 100)
	silhouettes.BackgroundTransparency = 1
	silhouettes.Visible = false
	silhouettes.Parent = overlay
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stripLayout.Padding = UDim.new(0, 18)
	stripLayout.Parent = silhouettes
	for index = 1, 9 do
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow" .. index
		shadow.Size = UDim2.fromOffset(70, 82)
		shadow.BackgroundColor3 = Color3.fromRGB(8, 9, 15)
		shadow.BorderSizePixel = 0
		shadow.Parent = silhouettes
		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(0.35, 0)
		shadowCorner.Parent = shadow
	end
	result = Instance.new("TextLabel")
	result.AnchorPoint = Vector2.new(0.5, 0)
	result.Position = UDim2.fromScale(0.5, 0.68)
	result.Size = UDim2.fromScale(0.7, 0.2)
	result.BackgroundTransparency = 1
	result.Font = Enum.Font.GothamBlack
	result.TextScaled = true
	result.TextStrokeTransparency = 0
	result.TextTransparency = 1
	result.Parent = overlay
end

function RevealController.Play(item)
	if busy then
		return
	end
	busy = true
	local definition = context.Config.Brainrots[item.BrainrotId]
	local rarity = context.Config.Rarities[definition.Rarity]
	local mutation = context.Config.Mutations[item.Mutation]
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	egg.Visible = true
	egg.BackgroundColor3 = Color3.fromRGB(242, 239, 220)
	egg.Size = UDim2.fromOffset(80, 105)
	egg.Rotation = 0
	crack.Visible = false
	silhouettes.Visible = false
	result.TextTransparency = 1
	tween(overlay, 0.18, { BackgroundTransparency = 0.18 })
	tween(egg, 0.28, { Size = UDim2.fromOffset(130, 170) }, Enum.EasingStyle.Back)
	task.wait(0.3)
	for index = 1, 7 do
		egg.Rotation = index % 2 == 0 and -10 or 10
		if index >= 4 then
			crack.Visible = true
		end
		task.wait(0.07 - index * 0.004)
	end
	egg.Rotation = 0
	silhouettes.Position = UDim2.fromScale(0.75, 0.5)
	silhouettes.Visible = true
	tween(silhouettes, 0.42, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quart)
	task.wait(0.42)
	silhouettes.Visible = false
	egg.BackgroundColor3 = rarity.Color
	tween(egg, 0.16, { Size = UDim2.fromScale(1.5, 1.5), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart)
	task.wait(0.16)
	egg.Visible = false
	result.TextColor3 = rarity.Color
	result.Text = string.format(
		"%s\n%s%s\n$%s / sec",
		definition.Name,
		item.Mutation ~= "None" and item.Mutation .. " " or "",
		definition.Rarity,
		context.Util.FormatNumber(definition.MoneyPerSecond * mutation.Multiplier)
	)
	tween(result, 0.2, { TextTransparency = 0 }, Enum.EasingStyle.Back)
	task.wait(1.6)
	tween(result, 0.2, { TextTransparency = 1 })
	tween(overlay, 0.25, { BackgroundTransparency = 1 })
	task.wait(0.25)
	overlay.Visible = false
	busy = false
end

function RevealController.Start()
	context.Remotes.RevealBrainrot.OnClientEvent:Connect(RevealController.Play)
end

return RevealController
