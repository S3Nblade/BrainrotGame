--!nonstrict
-- StarterPlayerScripts/ZoneEggHatchClient.client.lua
-- Professional egg reveal: egg intro, shadow roulette, final reward, clean luck text.

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

local function createText(parent, name, value, pos, size, color, maxSize, font)
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
	label.ZIndex = 30
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 10
	constraint.MaxTextSize = maxSize or 28
	constraint.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(10, 12, 18)
	stroke.Thickness = 1.8
	stroke.Transparency = 0.12
	stroke.Parent = label

	return label
end

local function createSoftCircle(parent, name, color, transparency, zIndex)
	local circle = Instance.new("Frame")
	circle.Name = name
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.BackgroundColor3 = color
	circle.BackgroundTransparency = transparency or 0.55
	circle.BorderSizePixel = 0
	circle.Position = UDim2.fromScale(0.5, 0.42)
	circle.Size = UDim2.fromOffset(300, 300)
	circle.ZIndex = zIndex or 5
	circle.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.58, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = circle

	return circle
end

local function createViewport(parent, name, zIndex)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = name
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = zIndex or 10
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Ambient = Color3.fromRGB(155, 160, 178)
	viewport.Parent = parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0, 0.25, 7), Vector3.new(0, 0.35, 0))
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

local function clearWorld(world)
	for _, child in ipairs(world:GetChildren()) do
		child:Destroy()
	end
end

local function buildEgg(world, eggRarity)
	local color = rarityColor(eggRarity)
	local body = eggRarity == "Common" and Color3.fromRGB(240, 235, 214) or color:Lerp(Color3.fromRGB(255, 255, 255), 0.28)
	part(world, "EggBody", Vector3.new(2.1, 2.85, 2.1), CFrame.new(0, 0, 0), body, Enum.PartType.Ball)
	part(world, "BandLow", Vector3.new(2.22, 0.14, 2.22), CFrame.new(0, -0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder)
	part(world, "BandHigh", Vector3.new(2.2, 0.14, 2.2), CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder, Enum.Material.Neon, 0.08)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = eggRarity == "Common" and 0.8 or 1.25
	light.Range = 8
	light.Parent = world:FindFirstChild("EggBody")
end

local function buildReward(world, rarity, shadowMode)
	local color = shadowMode and Color3.fromRGB(7, 9, 16) or rarityColor(rarity)
	local second = shadowMode and Color3.fromRGB(11, 13, 22) or color:Lerp(Color3.fromRGB(255, 255, 255), 0.36)
	local accent = shadowMode and Color3.fromRGB(4, 5, 10) or color:Lerp(Color3.fromRGB(25, 28, 38), 0.15)

	part(world, "Body", Vector3.new(1.55, 1.8, 1.05), CFrame.new(0, -0.25, 0), color, Enum.PartType.Ball)
	part(world, "Head", Vector3.new(1.32, 1.32, 1.32), CFrame.new(0, 1.15, 0), second, Enum.PartType.Ball)
	part(world, "LeftArm", Vector3.new(0.38, 1, 0.38), CFrame.new(-0.95, -0.2, 0) * CFrame.Angles(0, 0, math.rad(14)), accent, Enum.PartType.Cylinder)
	part(world, "RightArm", Vector3.new(0.38, 1, 0.38), CFrame.new(0.95, -0.2, 0) * CFrame.Angles(0, 0, math.rad(-14)), accent, Enum.PartType.Cylinder)

	if not shadowMode then
		part(world, "LeftEye", Vector3.new(0.18, 0.18, 0.05), CFrame.new(-0.26, 1.22, -0.62), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
		part(world, "RightEye", Vector3.new(0.18, 0.18, 0.05), CFrame.new(0.26, 1.22, -0.62), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
		part(world, "Smile", Vector3.new(0.42, 0.06, 0.05), CFrame.new(0, 0.95, -0.66), Color3.fromRGB(18, 20, 28), Enum.PartType.Block)
	end

	local light = Instance.new("PointLight")
	light.Color = shadowMode and Color3.fromRGB(60, 65, 90) or rarityColor(rarity)
	light.Brightness = shadowMode and 0.45 or 1.35
	light.Range = 10
	light.Parent = world:FindFirstChild("Body")
end

local function normalizeNPC(entry, fallbackRarity)
	if type(entry) == "table" then
		local name = tostring(entry.displayName or entry.DisplayName or entry.name or entry.Name or entry.id or "Brainrot")
		return {
			displayName = name,
			rarity = tostring(entry.rarity or entry.Rarity or fallbackRarity or "Common"),
		}
	end

	return {
		displayName = tostring(entry or "Brainrot"),
		rarity = tostring(fallbackRarity or "Common"),
	}
end

local function normalized(payload)
	payload = type(payload) == "table" and payload or {}
	local selected = payload.selectedNPC or {}
	local mutation = tostring(payload.MutationDisplayName or payload.Mutation or selected.mutationDisplayName or selected.mutation or "Normal")
	local possible = {}

	if type(payload.possibleNPCs) == "table" then
		for _, entry in ipairs(payload.possibleNPCs) do
			table.insert(possible, normalizeNPC(entry, payload.Rarity))
		end
	end

	if #possible <= 0 then
		for _, name in ipairs({ "Mystery Brainrot", "Forest Brainrot", "Rare Brainrot", "Lucky Brainrot" }) do
			table.insert(possible, normalizeNPC(name, payload.Rarity))
		end
	end

	local resultName = tostring(payload.ResultName or selected.displayName or selected.name or "Brainrot")
	table.insert(possible, normalizeNPC({ displayName = resultName, rarity = payload.Rarity }, payload.Rarity))

	return {
		revealId = tostring(payload.revealId or payload.RevealId or payload.EggId or os.clock()),
		eggName = tostring(payload.EggName or "Egg"),
		eggRarity = tostring(payload.EggRarity or "Common"),
		luckText = "Egg Luck: +" .. tostring(payload.LuckBonus or 0) .. "%",
		name = resultName,
		rarity = tostring(payload.Rarity or payload.selectedRarity or selected.rarity or "Common"),
		mutation = mutation,
		possibleNPCs = possible,
	}
end

local function fadeText(label, visible)
	tween(label, 0.2, { TextTransparency = visible and 0 or 1 })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		tween(stroke, 0.2, { Transparency = visible and 0.12 or 1 })
	end
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

	local overlay = Instance.new("Frame")
	overlay.Name = "SoftOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Parent = gui
	tween(overlay, 0.25, { BackgroundTransparency = 0.26 })
	tween(blur, 0.28, { Size = 9 })

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(460, 520)
	stage.Parent = gui

	local stageScale = Instance.new("UIScale")
	stageScale.Scale = 0.86
	stageScale.Parent = stage
	tween(stageScale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local glow = createSoftCircle(stage, "RarityGlow", rewardColor, 1, 5)
	local eggGlow = createSoftCircle(stage, "EggGlow", eggColor, 0.72, 4)
	eggGlow.Size = UDim2.fromOffset(235, 235)

	local viewHolder = Instance.new("Frame")
	viewHolder.Name = "ViewportHolder"
	viewHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	viewHolder.BackgroundTransparency = 1
	viewHolder.Position = UDim2.fromScale(0.5, 0.4)
	viewHolder.Size = UDim2.fromOffset(235, 235)
	viewHolder.ZIndex = 15
	viewHolder.Parent = stage

	local viewScale = Instance.new("UIScale")
	viewScale.Scale = 0.25
	viewScale.Parent = viewHolder

	local viewport, world = createViewport(viewHolder, "RevealViewport", 15)
	buildEgg(world, payload.eggRarity)

	local title = createText(stage, "Title", payload.eggName, UDim2.fromScale(0.08, 0.04), UDim2.fromScale(0.84, 0.075), Color3.fromRGB(255, 255, 255), 30, FONT_BOLD)
	local rollingName = createText(stage, "RollingName", "???", UDim2.fromScale(0.08, 0.69), UDim2.fromScale(0.84, 0.07), Color3.fromRGB(218, 226, 242), 24, FONT_BOLD)
	local rewardName = createText(stage, "RewardName", payload.name, UDim2.fromScale(0.06, 0.64), UDim2.fromScale(0.88, 0.09), Color3.fromRGB(255, 255, 255), 34, FONT_BOLD)
	local rarity = createText(stage, "Rarity", payload.rarity, UDim2.fromScale(0.16, 0.735), UDim2.fromScale(0.68, 0.055), rewardColor, 23, FONT_BOLD)
	local mutationText = payload.mutation ~= "Normal" and (payload.mutation .. " Mutation") or ""
	local mutation = createText(stage, "Mutation", mutationText, UDim2.fromScale(0.16, 0.795), UDim2.fromScale(0.68, 0.05), Color3.fromRGB(232, 238, 246), 19, FONT)
	local luck = createText(stage, "Luck", payload.luckText, UDim2.fromScale(0.16, 0.855), UDim2.fromScale(0.68, 0.05), eggColor, 19, FONT_BOLD)

	fadeText(title, true)
	tween(viewScale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	for i = 1, 4 do
		local y = 0.4 + math.sin(i * 1.4) * 0.012
		tween(viewHolder, 0.16, { Position = UDim2.fromScale(0.5, y) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(0.16)
	end

	for i = 1, 3 do
		local offset = i % 2 == 1 and -9 or 9
		tween(viewHolder, 0.06, { Position = UDim2.new(0.5, offset, 0.4, 0), Rotation = offset * 0.42 })
		task.wait(0.07)
		tween(viewHolder, 0.06, { Position = UDim2.fromScale(0.5, 0.4), Rotation = 0 })
		task.wait(0.06)
	end

	tween(viewScale, 0.14, { Scale = 1.16 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(0.1)
	tween(viewScale, 0.18, { Scale = 0.08 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(eggGlow, 0.18, { BackgroundTransparency = 1 })
	task.wait(0.18)

	fadeText(title, false)
	fadeText(rollingName, true)

	local steps = 16
	for step = 1, steps do
		local ratio = step / steps
		local npc = payload.possibleNPCs[((step - 1) % #payload.possibleNPCs) + 1]
		clearWorld(world)
		buildReward(world, npc.rarity or payload.rarity, true)
		rollingName.Text = npc.displayName
		rollingName.TextColor3 = Color3.fromRGB(218, 226, 242)

		local pulse = 0.92 + (1 - ratio) * 0.16
		viewScale.Scale = pulse
		tween(viewScale, 0.08, { Scale = 1.04 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		task.wait(0.045 + ratio * ratio * 0.075)
	end

	clearWorld(world)
	buildReward(world, payload.rarity, false)
	rollingName.Text = ""
	fadeText(rollingName, false)
	glow.BackgroundColor3 = rewardColor
	tween(glow, 0.34, {
		BackgroundTransparency = 0.52,
		Size = UDim2.fromOffset(360, 360),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(viewScale, 0.34, { Scale = 1.15 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.wait(0.12)
	for _, label in ipairs({ rewardName, rarity, mutation, luck }) do
		if label.Text ~= "" then
			fadeText(label, true)
			task.wait(0.05)
		end
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
	while not closeRequested and os.clock() - started < 3.1 do
		task.wait(0.05)
	end
	conn:Disconnect()

	tween(overlay, 0.18, { BackgroundTransparency = 1 })
	tween(blur, 0.18, { Size = 0 })
	tween(stageScale, 0.18, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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
	local remote = remotes:WaitForChild("EggRevealResult", 15)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(enqueue)
	end
end

local legacy = ReplicatedStorage:WaitForChild("ZoneEggHatchResult", 15)
if legacy and legacy:IsA("RemoteEvent") then
	legacy.OnClientEvent:Connect(enqueue)
end

print("[CleanEggReveal] Loaded egg intro and shadow roulette reveal.")
