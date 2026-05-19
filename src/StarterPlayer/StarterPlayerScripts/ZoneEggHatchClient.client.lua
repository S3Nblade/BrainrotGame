--!nonstrict
-- StarterPlayerScripts/ZoneEggHatchClient.client.lua
-- Clean cartoony NPC reward reveal roll. Server chooses/grants; client only displays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local REMOTES_FOLDER_NAME = "Remotes"
local START_REVEAL_REMOTE_NAME = "StartNPCReveal"
local LEGACY_REVEAL_REMOTE_NAME = "ZoneEggHatchResult"

local FONT = Enum.Font.FredokaOne
local TICK_SOUND_ID = ""
local FINAL_SOUND_ID = ""

local ROLL_TICKS = 24
local QUEUE_LIMIT = 5

local THEME = {
	Ink = Color3.fromRGB(25, 28, 44),
	InkSoft = Color3.fromRGB(54, 63, 94),
	Cream = Color3.fromRGB(255, 248, 220),
	Panel = Color3.fromRGB(255, 241, 177),
	PanelDeep = Color3.fromRGB(255, 178, 82),
	Blue = Color3.fromRGB(71, 181, 255),
	Pink = Color3.fromRGB(255, 101, 178),
	Green = Color3.fromRGB(98, 232, 112),
	White = Color3.fromRGB(255, 255, 255),
}

local RARITY = {
	Common = { color = Color3.fromRGB(230, 236, 244), deep = Color3.fromRGB(132, 143, 162), flash = 0.16 },
	Rare = { color = Color3.fromRGB(75, 170, 255), deep = Color3.fromRGB(37, 99, 214), flash = 0.2 },
	Epic = { color = Color3.fromRGB(202, 91, 255), deep = Color3.fromRGB(111, 55, 202), flash = 0.24 },
	Mythic = { color = Color3.fromRGB(255, 84, 171), deep = Color3.fromRGB(181, 45, 118), flash = 0.28 },
	Legendary = { color = Color3.fromRGB(255, 202, 55), deep = Color3.fromRGB(222, 123, 31), flash = 0.34 },
	Divine = { color = Color3.fromRGB(75, 236, 255), deep = Color3.fromRGB(34, 137, 214), flash = 0.38 },
	Celestial = { color = Color3.fromRGB(168, 130, 255), deep = Color3.fromRGB(83, 59, 204), flash = 0.42 },
	Godly = { color = Color3.fromRGB(255, 78, 78), deep = Color3.fromRGB(151, 24, 45), flash = 0.48 },
	Secret = { color = Color3.fromRGB(44, 255, 149), deep = Color3.fromRGB(35, 61, 56), flash = 0.52 },
}

local activeGui = nil
local playing = false
local queue = {}
local seenRevealIds = {}

local function getProfile(rarity)
	return RARITY[tostring(rarity or "Common")] or RARITY.Common
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

local function playSound(soundId, volume, pitch)
	if not soundId or tostring(soundId) == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = tostring(soundId)
	sound.Volume = volume or 0.35
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
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

local function addTextStroke(label, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Ink
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0.08
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	return stroke
end

local function constrainText(label, maxSize, minSize)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize or 28
	constraint.MinTextSize = minSize or 9
	constraint.Parent = label
	return constraint
end

local function makeLabel(parent, name, text, size, position, maxSize, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.fromScale(0, 0)
	label.Font = FONT
	label.Text = text or ""
	label.TextColor3 = color or THEME.White
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zIndex or 1
	label.Parent = parent
	addTextStroke(label, 2, 0.08)
	constrainText(label, maxSize or 28, 9)
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
	addStroke(frame, THEME.Ink, 3, 0)
	addGradient(frame, top, bottom or top)
	return frame
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

local function normalizeNPC(entry)
	if type(entry) == "table" then
		local displayName = tostring(entry.displayName or entry.DisplayName or entry.name or entry.Name or entry.id or "Brainrot")
		local rarity = tostring(entry.rarity or entry.Rarity or "Common")
		return {
			id = tostring(entry.id or entry.Id or displayName),
			name = tostring(entry.name or entry.Name or displayName),
			displayName = displayName,
			rarity = rarity,
			zoneName = tostring(entry.zoneName or entry.ZoneName or ""),
			mps = tonumber(entry.mps or entry.MPS or entry.CashPerSecond),
			mutation = tostring(entry.mutation or entry.Mutation or ""),
			mutationDisplayName = tostring(entry.mutationDisplayName or entry.MutationDisplayName or entry.mutation or entry.Mutation or ""),
		}
	end

	local name = tostring(entry or "Brainrot")
	return {
		id = name,
		name = name,
		displayName = name,
		rarity = "Common",
		zoneName = "",
	}
end

local function normalizePayload(payload)
	payload = type(payload) == "table" and payload or {}

	local possible = {}
	if type(payload.possibleNPCs) == "table" then
		for _, entry in ipairs(payload.possibleNPCs) do
			table.insert(possible, normalizeNPC(entry))
		end
	elseif type(payload.RollNames) == "table" then
		for _, name in ipairs(payload.RollNames) do
			table.insert(possible, normalizeNPC({
				name = name,
				rarity = payload.Rarity or payload.selectedRarity or "Common",
				zoneName = payload.ZoneName,
			}))
		end
	end

	if #possible <= 0 then
		table.insert(possible, normalizeNPC("Mystery Brainrot"))
	end

	local selected = normalizeNPC(payload.selectedNPC or {
		name = payload.ResultName or payload.Name or payload.BrainrotName,
		displayName = payload.ResultName or payload.Name or payload.BrainrotName,
		rarity = payload.selectedRarity or payload.Rarity,
		zoneName = payload.ZoneName,
		mps = payload.MPS or payload.CashPerSecond,
		mutation = payload.Mutation,
		mutationDisplayName = payload.MutationDisplayName,
	})

	selected.rarity = tostring(payload.selectedRarity or payload.Rarity or selected.rarity or "Common")
	selected.mps = tonumber(payload.MPS or payload.CashPerSecond or selected.mps)
	selected.mutation = tostring(payload.Mutation or selected.mutation or "")
	selected.mutationDisplayName = tostring(payload.MutationDisplayName or selected.mutationDisplayName or selected.mutation or "")

	return {
		revealId = tostring(payload.revealId or payload.RevealId or payload.EggId or os.clock()),
		zoneName = tostring(payload.ZoneDisplayName or payload.ZoneName or selected.zoneName or "Zone"),
		possibleNPCs = possible,
		selectedNPC = selected,
		source = tostring(payload.revealSource or payload.Source or "Reward"),
	}
end

local function makeShadowCard(parent, name, xScale, sizeScale, transparency)
	local card = makePanel(parent, name, Color3.fromRGB(58, 68, 104), Color3.fromRGB(28, 34, 58), 20, 20)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(xScale, 0.5)
	card.Size = UDim2.fromOffset(180, 210)
	card.BackgroundTransparency = transparency or 0

	local scale = Instance.new("UIScale")
	scale.Scale = sizeScale or 1
	scale.Parent = card

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = THEME.Blue
	glow.BackgroundTransparency = 0.76
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromScale(0.5, 0.44)
	glow.Size = UDim2.fromOffset(112, 136)
	glow.ZIndex = 21
	glow.Parent = card
	addCorner(glow, 70)

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.BackgroundColor3 = Color3.fromRGB(5, 8, 18)
	head.BorderSizePixel = 0
	head.Position = UDim2.fromScale(0.5, 0.26)
	head.Size = UDim2.fromOffset(66, 66)
	head.ZIndex = 23
	head.Parent = card
	addCorner(head, 36)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.BackgroundColor3 = Color3.fromRGB(6, 8, 18)
	body.BorderSizePixel = 0
	body.Position = UDim2.fromScale(0.5, 0.52)
	body.Size = UDim2.fromOffset(82, 92)
	body.ZIndex = 22
	body.Parent = card
	addCorner(body, 42)

	local question = makeLabel(card, "Question", "?", UDim2.fromOffset(54, 50), UDim2.fromScale(0.5, 0.26), 34, THEME.Cream, 26)
	question.AnchorPoint = Vector2.new(0.5, 0.5)

	local label = makeLabel(card, "Name", "???", UDim2.new(1, -18, 0, 38), UDim2.new(0, 9, 1, -48), 18, Color3.fromRGB(223, 232, 255), 26)
	label.TextXAlignment = Enum.TextXAlignment.Center

	local rarity = makeLabel(card, "Rarity", "???", UDim2.new(1, -18, 0, 22), UDim2.new(0, 9, 1, -25), 13, Color3.fromRGB(170, 185, 226), 26)
	rarity.TextXAlignment = Enum.TextXAlignment.Center

	return {
		card = card,
		scale = scale,
		nameLabel = label,
		rarityLabel = rarity,
		question = question,
		glow = glow,
	}
end

local function setShadowCard(entry, npc, revealed)
	local profile = getProfile(npc.rarity)
	entry.nameLabel.Text = revealed and npc.displayName or "???"
	entry.rarityLabel.Text = revealed and ("[" .. string.upper(npc.rarity) .. "]") or string.upper(npc.rarity)
	entry.rarityLabel.TextColor3 = profile.color
	entry.question.Text = revealed and "!" or "?"
	entry.question.TextColor3 = revealed and profile.color or THEME.Cream
	entry.glow.BackgroundColor3 = profile.color
end

local function createSimplePreview(parent, npc, profile)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "SimpleNPCPreview"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundTransparency = 1
	viewport.Position = UDim2.fromScale(0.5, 0.47)
	viewport.Size = UDim2.fromOffset(220, 220)
	viewport.ZIndex = 66
	viewport.Parent = parent

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0, 2, 7), Vector3.new(0, 1.3, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local model = Instance.new("Model")
	model.Name = npc.displayName .. "_Preview"
	model.Parent = world

	local function part(name, size, cf, color, shape, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Shape = shape or Enum.PartType.Block
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.Parent = model
		return p
	end

	local main = profile.color
	local second = profile.color:Lerp(THEME.White, 0.48)
	local accent = profile.deep

	part("Body", Vector3.new(1.55, 1.9, 0.95), CFrame.new(0, 0.32, 0), main, Enum.PartType.Ball)
	part("Head", Vector3.new(1.35, 1.35, 1.35), CFrame.new(0, 1.66, 0), second, Enum.PartType.Ball)
	part("LeftArm", Vector3.new(0.38, 1.08, 0.38), CFrame.new(-0.98, 0.36, 0) * CFrame.Angles(0, 0, math.rad(14)), accent, Enum.PartType.Cylinder)
	part("RightArm", Vector3.new(0.38, 1.08, 0.38), CFrame.new(0.98, 0.36, 0) * CFrame.Angles(0, 0, math.rad(-14)), accent, Enum.PartType.Cylinder)
	part("LeftFoot", Vector3.new(0.58, 0.25, 0.72), CFrame.new(-0.42, -0.78, -0.08), second, Enum.PartType.Ball)
	part("RightFoot", Vector3.new(0.58, 0.25, 0.72), CFrame.new(0.42, -0.78, -0.08), second, Enum.PartType.Ball)
	part("LeftEye", Vector3.new(0.2, 0.2, 0.05), CFrame.new(-0.28, 1.74, -0.62), THEME.White, Enum.PartType.Ball)
	part("RightEye", Vector3.new(0.2, 0.2, 0.05), CFrame.new(0.28, 1.74, -0.62), THEME.White, Enum.PartType.Ball)
	part("Smile", Vector3.new(0.46, 0.07, 0.05), CFrame.new(0, 1.42, -0.66), THEME.Ink, Enum.PartType.Block)

	local light = Instance.new("PointLight")
	light.Color = profile.color
	light.Brightness = 1.8
	light.Range = 10
	light.Parent = model:FindFirstChild("Body")

	local previewScale = Instance.new("UIScale")
	previewScale.Scale = 0.42
	previewScale.Parent = viewport
	tween(previewScale, 0.26, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.spawn(function()
		local started = os.clock()
		while viewport.Parent and os.clock() - started < 2.2 do
			local elapsed = os.clock() - started
			model:PivotTo(CFrame.Angles(0, elapsed * 1.35, 0))
			task.wait(1 / 30)
		end
	end)

	return viewport
end

local function addSoftConfetti(parent, profile)
	local holder = Instance.new("Frame")
	holder.Name = "SoftConfetti"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 80
	holder.Parent = parent

	for i = 1, 20 do
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = i % 3 == 0 and THEME.Cream or profile.color
		dot.BorderSizePixel = 0
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(i % 2 == 0 and 10 or 7, i % 2 == 0 and 10 or 7)
		dot.ZIndex = 81
		dot.Parent = holder
		addCorner(dot, 8)

		local angle = (math.pi * 2 / 20) * i
		local distance = 112 + (i % 5) * 18
		tween(dot, 0.55, {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
			BackgroundTransparency = 1,
			Rotation = i * 24,
		})
	end

	Debris:AddItem(holder, 0.8)
end

local function runReveal(rawPayload)
	local payload = normalizePayload(rawPayload)
	local selected = payload.selectedNPC
	local profile = getProfile(selected.rarity)

	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	local blur = Instance.new("BlurEffect")
	blur.Name = "NPCRevealSoftBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local gui = Instance.new("ScreenGui")
	gui.Name = "NPCRevealRollGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9800
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	activeGui = gui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.fromRGB(12, 15, 28)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 1
	dim.Parent = gui

	local holder = makePanel(gui, "RevealHolder", THEME.Panel, THEME.PanelDeep, 28, 10)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(760, 470)

	local holderScale = Instance.new("UIScale")
	local viewportSize = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local fit = math.clamp(math.min((viewportSize.X - 28) / 760, (viewportSize.Y - 28) / 470), 0.48, 1)
	holderScale.Scale = fit * 0.9
	holderScale.Parent = holder

	tween(dim, 0.18, { BackgroundTransparency = 0.24 })
	tween(blur, 0.2, { Size = 9 })
	tween(holderScale, 0.22, { Scale = fit }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local shine = Instance.new("Frame")
	shine.Name = "TopShine"
	shine.BackgroundColor3 = THEME.White
	shine.BackgroundTransparency = 0.72
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 14, 0, 12)
	shine.Size = UDim2.new(1, -28, 0, 34)
	shine.ZIndex = 12
	shine.Parent = holder
	addCorner(shine, 18)

	makeLabel(holder, "Title", "ROLLING...", UDim2.new(1, -40, 0, 56), UDim2.new(0, 20, 0, 18), 38, THEME.Cream, 15)
	local subtitle = makeLabel(holder, "Subtitle", payload.zoneName .. " Reward", UDim2.new(1, -40, 0, 28), UDim2.new(0, 20, 0, 70), 19, Color3.fromRGB(255, 252, 226), 15)

	local reel = Instance.new("Frame")
	reel.Name = "SimpleReel"
	reel.BackgroundTransparency = 1
	reel.Position = UDim2.new(0, 0, 0, 112)
	reel.Size = UDim2.new(1, 0, 0, 230)
	reel.ZIndex = 18
	reel.Parent = holder

	local left = makeShadowCard(reel, "Left", 0.27, 0.82, 0.18)
	local center = makeShadowCard(reel, "Center", 0.5, 1.12, 0)
	local right = makeShadowCard(reel, "Right", 0.73, 0.82, 0.18)

	local possible = payload.possibleNPCs
	local index = 0

	for tick = 1, ROLL_TICKS do
		index += 1
		local leftNpc = possible[((index - 1) % #possible) + 1]
		local centerNpc = possible[(index % #possible) + 1]
		local rightNpc = possible[((index + 1) % #possible) + 1]

		setShadowCard(left, leftNpc, false)
		setShadowCard(center, centerNpc, false)
		setShadowCard(right, rightNpc, false)

		local ratio = tick / ROLL_TICKS
		local bump = 1.12 + (1 - ratio) * 0.08
		tween(center.scale, 0.055, { Scale = bump }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		tween(center.card, 0.055, { Position = UDim2.fromScale(0.5, 0.48) })
		task.wait(0.035 + (ratio ^ 2) * 0.105)
		tween(center.scale, 0.07, { Scale = 1.12 })
		tween(center.card, 0.07, { Position = UDim2.fromScale(0.5, 0.5) })
		playSound(TICK_SOUND_ID, 0.15, 1 + ratio * 0.35)
	end

	setShadowCard(left, possible[((index - 1) % #possible) + 1], false)
	setShadowCard(center, selected, true)
	setShadowCard(right, possible[((index + 1) % #possible) + 1], false)

	makeLabel(holder, "PopText", "YOU GOT", UDim2.fromOffset(210, 36), UDim2.new(0.5, -105, 0, 106), 28, profile.color, 70)

	tween(left.card, 0.22, { BackgroundTransparency = 0.55, Position = UDim2.fromScale(0.22, 0.52) })
	tween(right.card, 0.22, { BackgroundTransparency = 0.55, Position = UDim2.fromScale(0.78, 0.52) })
	tween(center.scale, 0.28, { Scale = 1.28 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(center.card, 0.28, { Position = UDim2.fromScale(0.5, 0.45) })

	local flash = Instance.new("Frame")
	flash.Name = "SoftFlash"
	flash.BackgroundColor3 = profile.color
	flash.BackgroundTransparency = profile.flash
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 90
	flash.Parent = gui
	tween(flash, 0.32, { BackgroundTransparency = 1 })
	Debris:AddItem(flash, 0.4)

	addSoftConfetti(holder, profile)
	playSound(FINAL_SOUND_ID, 0.45, 1)

	task.wait(0.16)
	createSimplePreview(holder, selected, profile)

	local result = makePanel(holder, "Result", profile.color:Lerp(THEME.White, 0.18), profile.deep, 20, 65)
	result.AnchorPoint = Vector2.new(0.5, 1)
	result.Position = UDim2.new(0.5, 0, 1, -20)
	result.Size = UDim2.fromOffset(540, 104)
	result.BackgroundTransparency = 1

	local resultScale = Instance.new("UIScale")
	resultScale.Scale = 0.82
	resultScale.Parent = result

	makeLabel(result, "Name", selected.displayName, UDim2.new(1, -30, 0, 40), UDim2.new(0, 15, 0, 12), 30, THEME.White, 70)

	local mutationText = selected.mutationDisplayName
	if mutationText == "" or mutationText == "nil" then
		mutationText = "Normal"
	end

	local detail = "[" .. string.upper(selected.rarity) .. "]"
	if selected.mps then
		detail ..= "  |  $" .. formatNumber(selected.mps) .. "/s"
	end
	if mutationText ~= "" then
		detail ..= "  |  " .. mutationText
	end

	makeLabel(result, "Details", detail, UDim2.new(1, -30, 0, 28), UDim2.new(0, 15, 0, 56), 19, THEME.Cream, 70)

	tween(result, 0.14, { BackgroundTransparency = 0 })
	tween(resultScale, 0.24, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	subtitle.Text = "Tap anywhere to continue"

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "TapToClose"
	closeButton.BackgroundTransparency = 1
	closeButton.Size = UDim2.fromScale(1, 1)
	closeButton.Text = ""
	closeButton.ZIndex = 120
	closeButton.Parent = gui

	local closeRequested = false
	closeButton.Activated:Connect(function()
		closeRequested = true
	end)

	local started = os.clock()
	while not closeRequested and os.clock() - started < 2.2 do
		task.wait(0.05)
	end

	tween(dim, 0.18, { BackgroundTransparency = 1 })
	tween(blur, 0.18, { Size = 0 })
	tween(holderScale, 0.18, { Scale = fit * 0.88 })
	task.wait(0.2)

	if gui == activeGui then
		activeGui = nil
	end
	gui:Destroy()
	blur:Destroy()
end

local function processQueue()
	if playing then
		return
	end

	playing = true
	while #queue > 0 do
		local payload = table.remove(queue, 1)
		local ok, err = pcall(runReveal, payload)
		if not ok then
			warn("[NPCRevealRoll] Reveal failed:", err)
			if activeGui then
				activeGui:Destroy()
				activeGui = nil
			end
		end
		task.wait(0.1)
	end
	playing = false
end

local function enqueueReveal(payload)
	local normalized = normalizePayload(payload)
	if seenRevealIds[normalized.revealId] then
		return
	end

	seenRevealIds[normalized.revealId] = true
	table.insert(queue, payload)

	while #queue > QUEUE_LIMIT do
		table.remove(queue, 1)
	end

	task.defer(processQueue)
end

local remotesFolder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME, 15)
if remotesFolder then
	local startRevealRemote = remotesFolder:WaitForChild(START_REVEAL_REMOTE_NAME, 15)
	if startRevealRemote and startRevealRemote:IsA("RemoteEvent") then
		startRevealRemote.OnClientEvent:Connect(enqueueReveal)
	end
end

local legacyRemote = ReplicatedStorage:WaitForChild(LEGACY_REVEAL_REMOTE_NAME, 15)
if legacyRemote and legacyRemote:IsA("RemoteEvent") then
	legacyRemote.OnClientEvent:Connect(enqueueReveal)
end

print("[NPCRevealRoll] Loaded clean cartoony NPC reveal animation.")
