--!nonstrict
-- StarterPlayerScripts/ZoneEggHatchClient.client.lua
-- Client-side hatch reveal: rolling shadows, final NPC, rarity, and mutation result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REMOTE_NAME = "ZoneEggHatchResult"
local FONT = Enum.Font.FredokaOne

local THEME = {
	Ink = Color3.fromRGB(18, 20, 34),
	Cream = Color3.fromRGB(255, 247, 218),
	Gold = Color3.fromRGB(255, 213, 72),
	Pink = Color3.fromRGB(255, 91, 173),
	Blue = Color3.fromRGB(57, 183, 255),
	Green = Color3.fromRGB(88, 231, 105),
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(235, 239, 245),
	Rare = Color3.fromRGB(78, 172, 255),
	Epic = Color3.fromRGB(205, 94, 255),
	Mythic = Color3.fromRGB(255, 77, 171),
	Legendary = Color3.fromRGB(255, 204, 60),
	Divine = Color3.fromRGB(70, 238, 255),
	Celestial = Color3.fromRGB(167, 132, 255),
	Godly = Color3.fromRGB(255, 78, 78),
}

local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME)
local activeGui = nil

local function tween(instance, duration, props, style, direction)
	local tweenInfo = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, tweenInfo, props)
	t:Play()
	return t
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or THEME.Ink
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function addGradient(parent, top, bottom, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom or top),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

local function addTextStroke(label, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Ink
	stroke.Thickness = thickness or 2
	stroke.Transparency = 0.04
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	return stroke
end

local function constrainText(label, maxSize, minSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize or 30
	constraint.MinTextSize = minSize or 10
	constraint.Parent = label
end

local function makeLabel(parent, name, text, size, position, maxSize, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.fromScale(0, 0)
	label.Font = FONT
	label.Text = text or ""
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zIndex or 1
	label.Parent = parent
	addTextStroke(label, 2)
	constrainText(label, maxSize or 30, 10)
	return label
end

local function makePanel(parent, name, top, bottom, radius, zIndex)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = top
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex or 1
	frame.Parent = parent
	addCorner(frame, radius or 16)
	addStroke(frame, THEME.Ink, 3)
	addGradient(frame, top, bottom or top)
	return frame
end

local function colorFromPayload(value)
	if typeof(value) == "Color3" then
		return value
	end

	if type(value) == "table" then
		if typeof(value.R) == "number" and typeof(value.G) == "number" and typeof(value.B) == "number" then
			return Color3.new(value.R, value.G, value.B)
		end
	end

	return Color3.fromRGB(255, 255, 255)
end

local function formatNumber(value)
	value = tonumber(value) or 0
	if value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value))
end

local function buildShadowCard(parent, name, offsetScale, zIndex)
	local card = makePanel(parent, name, Color3.fromRGB(37, 42, 67), Color3.fromRGB(17, 20, 35), 22, zIndex)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(offsetScale, 0.5)
	card.Size = UDim2.fromOffset(190, 210)

	local oval = Instance.new("Frame")
	oval.Name = "ShadowBody"
	oval.AnchorPoint = Vector2.new(0.5, 0.5)
	oval.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	oval.BorderSizePixel = 0
	oval.Position = UDim2.fromScale(0.5, 0.42)
	oval.Size = UDim2.fromOffset(86, 106)
	oval.ZIndex = zIndex + 2
	oval.Parent = card
	addCorner(oval, 48)

	local head = Instance.new("Frame")
	head.Name = "ShadowHead"
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.BackgroundColor3 = Color3.fromRGB(5, 7, 13)
	head.BorderSizePixel = 0
	head.Position = UDim2.fromScale(0.5, 0.22)
	head.Size = UDim2.fromOffset(72, 72)
	head.ZIndex = zIndex + 3
	head.Parent = card
	addCorner(head, 38)

	local question = makeLabel(card, "Question", "?", UDim2.fromOffset(62, 58), UDim2.fromScale(0.5, 0.2), 38, Color3.fromRGB(255, 250, 216), zIndex + 4)
	question.AnchorPoint = Vector2.new(0.5, 0.5)

	local nameLabel = makeLabel(card, "Name", "???", UDim2.new(1, -18, 0, 42), UDim2.new(0, 9, 1, -54), 20, Color3.fromRGB(207, 218, 255), zIndex + 4)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center

	return card, nameLabel
end

local function setCardName(card, text)
	local label = card and card:FindFirstChild("Name")
	if label and label:IsA("TextLabel") then
		label.Text = tostring(text or "???")
	end
end

local function showHatch(payload)
	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ZoneEggHatchReveal"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9500
	gui.Parent = playerGui
	activeGui = gui

	local blur = Instance.new("BlurEffect")
	blur.Name = "ZoneEggHatchBlur"
	blur.Size = 0
	blur.Parent = Lighting
	tween(blur, 0.25, { Size = 16 })

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.fromRGB(9, 11, 22)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 1
	dim.Parent = gui
	tween(dim, 0.22, { BackgroundTransparency = 0.18 })

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(820, 520)
	holder.ZIndex = 5
	holder.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.78
	scale.Parent = holder
	tween(scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local fit = math.clamp(math.min((viewport.X - 28) / 820, (viewport.Y - 28) / 520), 0.52, 1)
	scale.Scale = 0.78 * fit
	tween(scale, 0.32, { Scale = fit }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local title = makeLabel(holder, "Title", "HATCHING", UDim2.new(1, 0, 0, 64), UDim2.fromOffset(0, 0), 48, THEME.Cream, 10)
	local subtitle = makeLabel(
		holder,
		"Subtitle",
		tostring(payload.ZoneDisplayName or payload.ZoneName or "Zone") .. " Egg",
		UDim2.new(1, 0, 0, 34),
		UDim2.fromOffset(0, 58),
		22,
		Color3.fromRGB(204, 233, 255),
		10
	)

	local slamStage = Instance.new("Frame")
	slamStage.Name = "SlamStage"
	slamStage.BackgroundTransparency = 1
	slamStage.Position = UDim2.new(0, 0, 0, 98)
	slamStage.Size = UDim2.new(1, 0, 0, 292)
	slamStage.ZIndex = 30
	slamStage.Parent = holder

	local floor = Instance.new("Frame")
	floor.Name = "ImpactFloor"
	floor.AnchorPoint = Vector2.new(0.5, 1)
	floor.BackgroundColor3 = Color3.fromRGB(255, 232, 118)
	floor.BorderSizePixel = 0
	floor.Position = UDim2.new(0.5, 0, 1, -16)
	floor.Size = UDim2.fromOffset(520, 18)
	floor.ZIndex = 31
	floor.Parent = slamStage
	addCorner(floor, 12)
	addStroke(floor, THEME.Ink, 3)

	local block = makePanel(slamStage, "LuckyEggBlock", THEME.Gold, Color3.fromRGB(245, 118, 42), 26, 36)
	block.AnchorPoint = Vector2.new(0.5, 0.5)
	block.Position = UDim2.new(0.5, 0, 0, -96)
	block.Size = UDim2.fromOffset(180, 180)
	block.Rotation = -10

	local blockScale = Instance.new("UIScale")
	blockScale.Scale = 1
	blockScale.Parent = block

	local q = makeLabel(block, "Question", "?", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 98, Color3.fromRGB(255, 249, 216), 40)
	q.Rotation = 4

	local sparkleHolder = Instance.new("Frame")
	sparkleHolder.Name = "ImpactBursts"
	sparkleHolder.BackgroundTransparency = 1
	sparkleHolder.Size = UDim2.fromScale(1, 1)
	sparkleHolder.ZIndex = 45
	sparkleHolder.Parent = slamStage

	local crackLines = {}
	for i = 1, 7 do
		local line = Instance.new("Frame")
		line.Name = "Crack_" .. tostring(i)
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = Color3.fromRGB(42, 33, 42)
		line.BackgroundTransparency = 1
		line.BorderSizePixel = 0
		line.Position = UDim2.new(0.5, (i - 4) * 26, 1, -31 - math.abs(i - 4) * 3)
		line.Size = UDim2.fromOffset(58 + math.abs(i - 4) * 8, 6)
		line.Rotation = (i - 4) * 13
		line.ZIndex = 35
		line.Parent = sparkleHolder
		addCorner(line, 6)
		table.insert(crackLines, line)
	end

	local function burstShard(index, color)
		local shard = Instance.new("Frame")
		shard.Name = "ImpactShard"
		shard.AnchorPoint = Vector2.new(0.5, 0.5)
		shard.BackgroundColor3 = color
		shard.BorderSizePixel = 0
		shard.Position = UDim2.new(0.5, 0, 1, -82)
		shard.Size = UDim2.fromOffset(18, 18)
		shard.Rotation = index * 23
		shard.ZIndex = 44
		shard.Parent = sparkleHolder
		addCorner(shard, 5)

		local angle = (math.pi * 2 / 12) * index
		tween(shard, 0.38, {
			Position = UDim2.new(0.5, math.cos(angle) * 190, 1, -82 + math.sin(angle) * 92),
			Rotation = shard.Rotation + 120,
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	task.wait(0.12)
	tween(block, 0.34, {
		Position = UDim2.new(0.5, 0, 1, -104),
		Rotation = 7,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.34)
	tween(blockScale, 0.08, { Scale = 1.15 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(floor, 0.08, { Size = UDim2.fromOffset(610, 16) })
	for _, line in ipairs(crackLines) do
		tween(line, 0.08, { BackgroundTransparency = 0.05 })
	end
	for i = 1, 12 do
		burstShard(i, i % 2 == 0 and THEME.Pink or THEME.Blue)
	end
	task.wait(0.09)
	tween(blockScale, 0.16, { Scale = 0.96 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(block, 0.16, { Position = UDim2.new(0.5, 0, 1, -126), Rotation = -5 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(0.16)
	tween(blockScale, 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(block, 0.12, { Position = UDim2.new(0.5, 0, 1, -108), Rotation = 2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.16)
	tween(slamStage, 0.22, { BackgroundTransparency = 1 })
	for _, child in ipairs(slamStage:GetDescendants()) do
		if child:IsA("GuiObject") then
			tween(child, 0.2, { BackgroundTransparency = 1 })
		end
	end
	task.wait(0.2)
	slamStage.Visible = false

	local reel = Instance.new("Frame")
	reel.Name = "ShadowReel"
	reel.BackgroundTransparency = 1
	reel.Position = UDim2.new(0, 0, 0, 122)
	reel.Size = UDim2.new(1, 0, 0, 242)
	reel.ZIndex = 8
	reel.Parent = holder

	local leftCard = buildShadowCard(reel, "LeftShadow", 0.24, 10)
	local centerCard, centerName = buildShadowCard(reel, "CenterShadow", 0.5, 12)
	local rightCard = buildShadowCard(reel, "RightShadow", 0.76, 10)
	leftCard.Size = UDim2.fromOffset(156, 176)
	rightCard.Size = UDim2.fromOffset(156, 176)
	leftCard.BackgroundTransparency = 0.18
	rightCard.BackgroundTransparency = 0.18

	local rollNames = type(payload.RollNames) == "table" and payload.RollNames or { "Mystery Brainrot" }
	local resultName = tostring(payload.ResultName or "Brainrot")
	local spinConnection = nil
	local spinAngle = 0
	spinConnection = RunService.RenderStepped:Connect(function(dt)
		spinAngle += dt * 7
		centerCard.Rotation = math.sin(spinAngle) * 2.6
		leftCard.Rotation = math.sin(spinAngle + 0.8) * 1.5
		rightCard.Rotation = math.sin(spinAngle + 1.7) * 1.5
	end)

	for i = 1, 24 do
		local text = rollNames[((i - 1) % #rollNames) + 1]
		setCardName(leftCard, rollNames[((i + 1) % #rollNames) + 1])
		setCardName(centerCard, text)
		setCardName(rightCard, rollNames[((i + 2) % #rollNames) + 1])
		centerName.TextColor3 = Color3.fromRGB(222, 229, 255)
		tween(centerCard, 0.055, { Size = UDim2.fromOffset(202, 222) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.wait(0.045 + math.min(i * 0.008, 0.09))
		tween(centerCard, 0.055, { Size = UDim2.fromOffset(190, 210) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	setCardName(centerCard, resultName)
	centerName.TextColor3 = Color3.fromRGB(255, 249, 214)
	tween(centerCard, 0.25, { Size = UDim2.fromOffset(232, 250) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(leftCard, 0.25, { BackgroundTransparency = 0.48, Position = UDim2.fromScale(0.2, 0.53) })
	tween(rightCard, 0.25, { BackgroundTransparency = 0.48, Position = UDim2.fromScale(0.8, 0.53) })

	local rarity = tostring(payload.Rarity or "Common")
	local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	local mutationColor = colorFromPayload(payload.MutationColor)
	local mutationText = tostring(payload.MutationDisplayName or payload.Mutation or "Normal")

	local result = makePanel(holder, "Result", rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.15), rarityColor:Lerp(THEME.Ink, 0.35), 24, 20)
	result.AnchorPoint = Vector2.new(0.5, 1)
	result.Position = UDim2.new(0.5, 0, 1, -8)
	result.Size = UDim2.fromOffset(620, 126)
	result.BackgroundTransparency = 1

	local resultScale = Instance.new("UIScale")
	resultScale.Scale = 0.84
	resultScale.Parent = result

	makeLabel(result, "Name", resultName, UDim2.new(1, -28, 0, 42), UDim2.new(0, 14, 0, 12), 32, Color3.fromRGB(255, 255, 255), 24)
	local details = makeLabel(
		result,
		"Details",
		rarity .. "  |  " .. mutationText .. "  |  $" .. formatNumber(payload.MPS) .. "/s",
		UDim2.new(1, -28, 0, 36),
		UDim2.new(0, 14, 0, 58),
		23,
		Color3.fromRGB(255, 250, 222),
		24
	)
	details.TextColor3 = mutationText == "Normal" and Color3.fromRGB(255, 250, 222) or mutationColor

	local shine = Instance.new("Frame")
	shine.Name = "MutationShine"
	shine.BackgroundColor3 = mutationColor
	shine.BackgroundTransparency = 0.1
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 18, 1, -24)
	shine.Size = UDim2.new(1, -36, 0, 8)
	shine.ZIndex = 25
	shine.Parent = result
	addCorner(shine, 8)

	tween(result, 0.2, { BackgroundTransparency = 0 })
	tween(resultScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.wait(2.15)

	if spinConnection then
		spinConnection:Disconnect()
	end

	tween(dim, 0.22, { BackgroundTransparency = 1 })
	tween(scale, 0.22, { Scale = fit * 0.88 })
	tween(blur, 0.22, { Size = 0 })
	task.wait(0.24)

	if gui == activeGui then
		activeGui = nil
	end

	gui:Destroy()
	blur:Destroy()
end

remote.OnClientEvent:Connect(function(payload)
	task.spawn(function()
		showHatch(type(payload) == "table" and payload or {})
	end)
end)

print("[ZoneEggHatchClient] Loaded.")
