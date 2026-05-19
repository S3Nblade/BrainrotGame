--!nonstrict
-- StarterPlayerScripts/ZoneEggHatchClient.client.lua
-- Clean egg reveal UI: soft dim, egg shake/pop, reward glow, readable result text.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT_BOLD = Enum.Font.GothamBold
local FONT = Enum.Font.GothamMedium
local QUEUE_LIMIT = 4

local RARITY_COLORS = {
	Common = Color3.fromRGB(232, 238, 246),
	Rare = Color3.fromRGB(92, 178, 255),
	Epic = Color3.fromRGB(190, 105, 255),
	Mythic = Color3.fromRGB(255, 91, 177),
	Legendary = Color3.fromRGB(255, 207, 70),
	Divine = Color3.fromRGB(102, 239, 255),
	Celestial = Color3.fromRGB(170, 138, 255),
	Godly = Color3.fromRGB(255, 88, 88),
	Secret = Color3.fromRGB(92, 255, 166),
}

local playing = false
local queue = {}
local seen = {}
local activeGui = nil

local function rarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "Common")] or RARITY_COLORS.Common
end

local function tween(instance, duration, props, style, direction)
	local tw = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function text(parent, name, value, pos, size, color, maxSize, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Font = font or FONT
	label.Text = value or ""
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextTransparency = 1
	label.ZIndex = 20
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 10
	constraint.MaxTextSize = maxSize or 28
	constraint.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(12, 14, 20)
	stroke.Thickness = 1.6
	stroke.Transparency = 0.18
	stroke.Parent = label

	return label
end

local function rounded(parent, name, pos, size, color, transparency, radius, zIndex)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = pos
	frame.Size = size
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = transparency or 0
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex or 1
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = frame

	return frame
end

local function createViewport(parent, name, zIndex)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = name
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = zIndex or 10
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Ambient = Color3.fromRGB(160, 165, 180)
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0, 0.3, 7), Vector3.new(0, 0.35, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	return viewport, world
end

local function part(parent, name, size, cframe, color, shape, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Shape = shape or Enum.PartType.Ball
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Parent = parent
	return p
end

local function buildEgg(world, eggRarity)
	local color = rarityColor(eggRarity)
	local body = eggRarity == "Common" and Color3.fromRGB(240, 235, 214) or color:Lerp(Color3.fromRGB(255, 255, 255), 0.28)
	part(world, "EggBody", Vector3.new(2.1, 2.85, 2.1), CFrame.new(0, 0, 0), body, Enum.PartType.Ball)
	part(world, "BandLow", Vector3.new(2.22, 0.14, 2.22), CFrame.new(0, -0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	part(world, "BandHigh", Vector3.new(2.2, 0.14, 2.2), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder, Enum.Material.Neon, 0.1)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = eggRarity == "Common" and 0.7 or 1.15
	light.Range = 8
	light.Parent = world:FindFirstChild("EggBody")
end

local function buildReward(world, rarity)
	local color = rarityColor(rarity)
	part(world, "Body", Vector3.new(1.55, 1.8, 1.05), CFrame.new(0, -0.25, 0), color, Enum.PartType.Ball)
	part(world, "Head", Vector3.new(1.32, 1.32, 1.32), CFrame.new(0, 1.15, 0), color:Lerp(Color3.fromRGB(255, 255, 255), 0.36), Enum.PartType.Ball)
	part(world, "LeftArm", Vector3.new(0.38, 1, 0.38), CFrame.new(-0.95, -0.2, 0) * CFrame.Angles(0, 0, math.rad(14)), color:Lerp(Color3.fromRGB(25, 28, 38), 0.15), Enum.PartType.Cylinder)
	part(world, "RightArm", Vector3.new(0.38, 1, 0.38), CFrame.new(0.95, -0.2, 0) * CFrame.Angles(0, 0, math.rad(-14)), color:Lerp(Color3.fromRGB(25, 28, 38), 0.15), Enum.PartType.Cylinder)
	part(world, "LeftEye", Vector3.new(0.18, 0.18, 0.05), CFrame.new(-0.26, 1.22, -0.62), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	part(world, "RightEye", Vector3.new(0.18, 0.18, 0.05), CFrame.new(0.26, 1.22, -0.62), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	part(world, "Smile", Vector3.new(0.42, 0.06, 0.05), CFrame.new(0, 0.95, -0.66), Color3.fromRGB(18, 20, 28), Enum.PartType.Block)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 1.35
	light.Range = 10
	light.Parent = world:FindFirstChild("Body")
end

local function clearWorld(world)
	for _, child in ipairs(world:GetChildren()) do
		child:Destroy()
	end
end

local function normalized(payload)
	payload = type(payload) == "table" and payload or {}
	local selected = payload.selectedNPC or {}
	local mutation = tostring(payload.MutationDisplayName or payload.Mutation or selected.mutationDisplayName or selected.mutation or "Normal")

	return {
		revealId = tostring(payload.revealId or payload.RevealId or payload.EggId or os.clock()),
		eggName = tostring(payload.EggName or "Egg"),
		eggRarity = tostring(payload.EggRarity or "Common"),
		luckText = tostring(payload.LuckText or ("Luck Bonus: +" .. tostring(payload.LuckBonus or 0) .. "%")),
		luckHint = tostring(payload.LuckHint or "Better odds for Rare Brainrots"),
		name = tostring(payload.ResultName or selected.displayName or selected.name or "Brainrot"),
		rarity = tostring(payload.Rarity or payload.selectedRarity or selected.rarity or "Common"),
		mutation = mutation,
	}
end

local function playReveal(rawPayload)
	local payload = normalized(rawPayload)
	local rewardColor = rarityColor(payload.rarity)
	local eggColor = rarityColor(payload.eggRarity)

	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CleanEggReveal"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.Parent = playerGui
	activeGui = gui

	local blur = Instance.new("BlurEffect")
	blur.Name = "EggRevealBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local overlay = rounded(gui, "Overlay", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromRGB(8, 10, 16), 1, 0, 1)
	tween(overlay, 0.25, { BackgroundTransparency = 0.34 })
	tween(blur, 0.28, { Size = 10 })

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(440, 500)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 5
	stage.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.82
	scale.Parent = stage
	tween(scale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local glow = rounded(stage, "RewardGlow", UDim2.fromScale(0.16, 0.1), UDim2.fromScale(0.68, 0.54), rewardColor, 1, 140, 6)
	glow.AnchorPoint = Vector2.new(0, 0)
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGradient.Parent = glow

	local viewHolder = Instance.new("Frame")
	viewHolder.Name = "ViewHolder"
	viewHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	viewHolder.Position = UDim2.fromScale(0.5, 0.36)
	viewHolder.Size = UDim2.fromOffset(230, 230)
	viewHolder.BackgroundTransparency = 1
	viewHolder.ZIndex = 12
	viewHolder.Parent = stage

	local viewScale = Instance.new("UIScale")
	viewScale.Scale = 0.35
	viewScale.Parent = viewHolder

	local viewport, world = createViewport(viewHolder, "RevealViewport", 12)
	buildEgg(world, payload.eggRarity)

	local title = text(stage, "Title", payload.eggName, UDim2.fromScale(0.08, 0.03), UDim2.fromScale(0.84, 0.08), Color3.fromRGB(255, 255, 255), 30, FONT_BOLD)
	local rewardName = text(stage, "RewardName", payload.name, UDim2.fromScale(0.06, 0.64), UDim2.fromScale(0.88, 0.1), Color3.fromRGB(255, 255, 255), 34, FONT_BOLD)
	local rarity = text(stage, "Rarity", payload.rarity, UDim2.fromScale(0.16, 0.735), UDim2.fromScale(0.68, 0.06), rewardColor, 24, FONT_BOLD)
	local mutation = text(stage, "Mutation", payload.mutation ~= "Normal" and payload.mutation or "Normal", UDim2.fromScale(0.18, 0.795), UDim2.fromScale(0.64, 0.05), Color3.fromRGB(232, 238, 246), 20, FONT)
	local luck = text(stage, "Luck", payload.luckText, UDim2.fromScale(0.16, 0.865), UDim2.fromScale(0.68, 0.045), eggColor, 18, FONT_BOLD)
	local hint = text(stage, "LuckHint", payload.luckHint, UDim2.fromScale(0.12, 0.91), UDim2.fromScale(0.76, 0.04), Color3.fromRGB(200, 208, 224), 16, FONT)

	tween(title, 0.24, { TextTransparency = 0 })
	local titleStroke = title:FindFirstChildOfClass("UIStroke")
	if titleStroke then
		tween(titleStroke, 0.24, { Transparency = 0.18 })
	end
	tween(viewScale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.wait(0.34)

	for i = 1, 3 do
		local offset = i % 2 == 1 and -10 or 10
		tween(viewHolder, 0.07, { Position = UDim2.new(0.5, offset, 0.36, 0), Rotation = offset * 0.45 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.wait(0.08)
		tween(viewHolder, 0.07, { Position = UDim2.fromScale(0.5, 0.36), Rotation = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.wait(0.07)
	end

	tween(viewScale, 0.14, { Scale = 1.18 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(0.12)
	tween(viewScale, 0.18, { Scale = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.16)

	clearWorld(world)
	buildReward(world, payload.rarity)
	glow.BackgroundTransparency = 0.42
	tween(glow, 0.36, { BackgroundTransparency = 0.58, Size = UDim2.fromScale(0.76, 0.58), Position = UDim2.fromScale(0.12, 0.08) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(viewScale, 0.34, { Scale = 1.12 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.wait(0.15)
	for _, label in ipairs({ rewardName, rarity, mutation, luck, hint }) do
		tween(label, 0.24, { TextTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, 0.24, { Transparency = 0.18 })
		end
		task.wait(0.05)
	end

	local closeRequested = false
	local button = Instance.new("TextButton")
	button.Name = "Close"
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 200
	button.Parent = gui
	local conn = button.Activated:Connect(function()
		closeRequested = true
	end)

	local started = os.clock()
	while not closeRequested and os.clock() - started < 2.7 do
		task.wait(0.05)
	end
	conn:Disconnect()

	tween(overlay, 0.18, { BackgroundTransparency = 1 })
	tween(blur, 0.18, { Size = 0 })
	tween(scale, 0.18, { Scale = 0.88 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, child in ipairs(stage:GetDescendants()) do
		if child:IsA("TextLabel") then
			tween(child, 0.14, { TextTransparency = 1 })
		elseif child:IsA("Frame") then
			tween(child, 0.14, { BackgroundTransparency = 1 })
		end
	end

	task.wait(0.2)
	if gui then
		gui:Destroy()
	end
	if blur then
		blur:Destroy()
	end
	activeGui = nil
end

local function processQueue()
	if playing then
		return
	end

	playing = true
	while #queue > 0 do
		local payload = table.remove(queue, 1)
		local ok, err = pcall(playReveal, payload)
		if not ok then
			warn("[CleanEggReveal] Reveal failed:", err)
			if activeGui then
				activeGui:Destroy()
				activeGui = nil
			end
		end
		task.wait(0.1)
	end
	playing = false
end

local function enqueue(payload)
	local data = normalized(payload)
	if seen[data.revealId] then
		return
	end
	seen[data.revealId] = true

	table.insert(queue, payload)
	while #queue > QUEUE_LIMIT do
		table.remove(queue, 1)
	end

	task.defer(processQueue)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if remotes then
	for _, remoteName in ipairs({ "EggRevealResult" }) do
		local remote = remotes:WaitForChild(remoteName, 15)
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(enqueue)
		end
	end
end

local legacy = ReplicatedStorage:WaitForChild("ZoneEggHatchResult", 15)
if legacy and legacy:IsA("RemoteEvent") then
	legacy.OnClientEvent:Connect(enqueue)
end

print("[CleanEggReveal] Loaded simple egg reveal animation.")
