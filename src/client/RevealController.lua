local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RevealController = {}
local context
local overlay
local egg
local crack
local silhouettes
local creature
local creatureScale
local result
local busy = false
local queue = {}

local function tween(instance, time, properties, style, direction)
	local animation = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		properties
	)
	animation:Play()
	return animation
end

local function clearCreature()
	for _, child in ipairs(creature:GetChildren()) do
		if child ~= creatureScale then
			child:Destroy()
		end
	end
end

local function addFallbackCreature(definition, rarity, mutation)
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(146, 146)
	glow.BackgroundColor3 = mutation.Color
	glow.BackgroundTransparency = mutation.Multiplier > 1 and 0.62 or 1
	glow.BorderSizePixel = 0
	glow.Rotation = 45
	glow.Parent = creature

	local body = Instance.new("Frame")
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromOffset(124, 124)
	body.BackgroundColor3 = definition.Color
	body.BorderSizePixel = 0
	body.Parent = creature
	local stroke = Instance.new("UIStroke")
	stroke.Color = rarity.Color
	stroke.Thickness = 7
	stroke.Parent = body

	for _, x in ipairs({ 0.28, 0.66 }) do
		local eye = Instance.new("Frame")
		eye.Size = UDim2.fromOffset(22, 26)
		eye.Position = UDim2.new(x, 0, 0.3, 0)
		eye.BackgroundColor3 = Color3.fromRGB(245, 248, 255)
		eye.BorderSizePixel = 0
		eye.Parent = body
		local pupil = Instance.new("Frame")
		pupil.Size = UDim2.fromOffset(9, 12)
		pupil.Position = UDim2.fromOffset(7, 8)
		pupil.BackgroundColor3 = Color3.fromRGB(24, 26, 38)
		pupil.BorderSizePixel = 0
		pupil.Parent = eye
	end
	local mouth = Instance.new("Frame")
	mouth.Size = UDim2.fromOffset(36, 9)
	mouth.Position = UDim2.new(0.5, -18, 0.72, 0)
	mouth.BackgroundColor3 = Color3.fromRGB(38, 40, 54)
	mouth.BorderSizePixel = 0
	mouth.Parent = body

	for _, position in ipairs({
		UDim2.fromOffset(-8, -8),
		UDim2.new(1, -8, 0, -8),
		UDim2.new(0, -8, 1, -8),
		UDim2.new(1, -8, 1, -8),
	}) do
		local pixel = Instance.new("Frame")
		pixel.Size = UDim2.fromOffset(16, 16)
		pixel.Position = position
		pixel.BackgroundColor3 = mutation.Multiplier > 1 and mutation.Color or rarity.Color
		pixel.BorderSizePixel = 0
		pixel.Parent = body
	end
end

local function buildCreature(item, definition, rarity, mutation)
	clearCreature()
	local spriteId = context.AssetIds.Brainrots[item.BrainrotId]
	if spriteId and spriteId ~= "rbxassetid://0" then
		local image = Instance.new("ImageLabel")
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = spriteId
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		image.Parent = creature
		local stroke = Instance.new("UIStroke")
		stroke.Color = mutation.Multiplier > 1 and mutation.Color or rarity.Color
		stroke.Thickness = 5
		stroke.Parent = image
	else
		addFallbackCreature(definition, rarity, mutation)
	end
end

local function rarityBurst(color)
	for index = 1, 16 do
		local angle = math.pi * 2 * index / 16
		local pixel = Instance.new("Frame")
		pixel.AnchorPoint = Vector2.new(0.5, 0.5)
		pixel.Position = UDim2.fromScale(0.5, 0.44)
		pixel.Size = UDim2.fromOffset(index % 3 == 0 and 18 or 10, index % 3 == 0 and 18 or 10)
		pixel.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), index % 2 == 0 and 0.35 or 0)
		pixel.BorderSizePixel = 0
		pixel.Rotation = index * 23
		pixel.Parent = overlay
		local target = UDim2.new(0.5, math.cos(angle) * 250, 0.44, math.sin(angle) * 180)
		tween(pixel, 0.48, {
			Position = target,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(3, 3),
		}, Enum.EasingStyle.Quart)
		task.delay(0.5, function()
			pixel:Destroy()
		end)
	end
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
	creature = Instance.new("Frame")
	creature.AnchorPoint = Vector2.new(0.5, 0.5)
	creature.Position = UDim2.fromScale(0.5, 0.43)
	creature.Size = UDim2.fromOffset(180, 180)
	creature.BackgroundTransparency = 1
	creature.Visible = false
	creature.Parent = overlay
	creatureScale = Instance.new("UIScale")
	creatureScale.Name = "RevealScale"
	creatureScale.Parent = creature
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

local function revealOne(item)
	local definition = context.Config.Brainrots[item.BrainrotId]
	local rarity = context.Config.Rarities[definition.Rarity]
	local mutation = context.Config.Mutations[item.Mutation]
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	egg.Visible = true
	egg.BackgroundColor3 = Color3.fromRGB(242, 239, 220)
	egg.BackgroundTransparency = 0
	egg.Size = UDim2.fromOffset(80, 105)
	egg.Rotation = 0
	crack.Visible = false
	silhouettes.Visible = false
	creature.Visible = false
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
	buildCreature(item, definition, rarity, mutation)
	creatureScale.Scale = 0.35
	creature.Visible = true
	rarityBurst(rarity.Color)
	tween(creatureScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	result.TextColor3 = rarity.Color
	local zone = context.Config.Zones[definition.Zone]
	result.Text = string.format(
		"%s\n%s%s\nLv. %d  |  $%s / sec",
		definition.Name,
		item.Mutation ~= "None" and item.Mutation .. " " or "",
		definition.Rarity,
		item.Level or 1,
		context.Util.FormatNumber(definition.MoneyPerSecond * mutation.Multiplier * zone.RewardMultiplier)
	)
	tween(result, 0.2, { TextTransparency = 0 }, Enum.EasingStyle.Back)
	task.wait(1.6)
	tween(result, 0.2, { TextTransparency = 1 })
	tween(creatureScale, 0.2, { Scale = 0.2 })
	tween(overlay, 0.25, { BackgroundTransparency = 1 })
	task.wait(0.25)
	creature.Visible = false
	overlay.Visible = false
end

function RevealController.Play(item)
	table.insert(queue, item)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		while #queue > 0 do
			revealOne(table.remove(queue, 1))
		end
		busy = false
	end)
end

function RevealController.Start()
	context.Remotes.RevealBrainrot.OnClientEvent:Connect(RevealController.Play)
end

return RevealController
