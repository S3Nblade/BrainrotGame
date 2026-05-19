--!nonstrict
-- StarterPlayerScripts/ZoneEggHatchClient.client.lua
-- Server-authoritative NPC reward reveal roll used by blox/egg rewards.

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

local ROLL_TICKS = 34
local QUEUE_LIMIT = 5

local THEME = {
	Ink = Color3.fromRGB(17, 20, 34),
	Ink2 = Color3.fromRGB(34, 41, 68),
	Cream = Color3.fromRGB(255, 248, 218),
	White = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(255, 210, 66),
	Blue = Color3.fromRGB(62, 184, 255),
	Pink = Color3.fromRGB(255, 87, 174),
	Green = Color3.fromRGB(88, 236, 103),
}

local RARITY = {
	Common = {
		color = Color3.fromRGB(232, 238, 246),
		deep = Color3.fromRGB(112, 124, 146),
		intensity = 1,
		ticks = 0.75,
	},
	Rare = {
		color = Color3.fromRGB(75, 170, 255),
		deep = Color3.fromRGB(24, 82, 198),
		intensity = 1.15,
		ticks = 0.85,
	},
	Epic = {
		color = Color3.fromRGB(203, 84, 255),
		deep = Color3.fromRGB(91, 42, 190),
		intensity = 1.32,
		ticks = 1,
	},
	Mythic = {
		color = Color3.fromRGB(255, 74, 170),
		deep = Color3.fromRGB(173, 35, 104),
		intensity = 1.52,
		ticks = 1.12,
	},
	Legendary = {
		color = Color3.fromRGB(255, 203, 54),
		deep = Color3.fromRGB(222, 112, 26),
		intensity = 1.75,
		ticks = 1.25,
	},
	Divine = {
		color = Color3.fromRGB(67, 238, 255),
		deep = Color3.fromRGB(25, 120, 210),
		intensity = 1.95,
		ticks = 1.4,
	},
	Celestial = {
		color = Color3.fromRGB(166, 126, 255),
		deep = Color3.fromRGB(69, 48, 196),
		intensity = 2.15,
		ticks = 1.55,
	},
	Godly = {
		color = Color3.fromRGB(255, 70, 70),
		deep = Color3.fromRGB(135, 15, 36),
		intensity = 2.35,
		ticks = 1.75,
	},
	Secret = {
		color = Color3.fromRGB(35, 255, 145),
		deep = Color3.fromRGB(35, 44, 56),
		intensity = 2.6,
		ticks = 1.9,
	},
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
	if soundId == nil or tostring(soundId) == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = tostring(soundId)
	sound.Volume = volume or 0.4
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

local function addTextStroke(label, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Ink
	stroke.Thickness = thickness or 2
	stroke.Transparency = 0.03
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
	addTextStroke(label, 2)
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
	addStroke(frame, THEME.Ink, 3)
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

local function makeShadowCard(parent, order)
	local card = makePanel(parent, "ShadowCard_" .. tostring(order), Color3.fromRGB(39, 47, 78), Color3.fromRGB(12, 16, 30), 18, 20)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Size = UDim2.fromOffset(164, 204)
	card.Position = UDim2.fromScale(0.5, 0.5)

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = Color3.fromRGB(76, 154, 255)
	glow.BackgroundTransparency = 0.82
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromScale(0.5, 0.43)
	glow.Size = UDim2.fromOffset(112, 140)
	glow.ZIndex = 21
	glow.Parent = card
	addCorner(glow, 70)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.BackgroundColor3 = Color3.fromRGB(3, 5, 12)
	body.BorderSizePixel = 0
	body.Position = UDim2.fromScale(0.5, 0.48)
	body.Size = UDim2.fromOffset(78, 100)
	body.ZIndex = 23
	body.Parent = card
	addCorner(body, 40)

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.BackgroundColor3 = Color3.fromRGB(2, 4, 10)
	head.BorderSizePixel = 0
	head.Position = UDim2.fromScale(0.5, 0.25)
	head.Size = UDim2.fromOffset(66, 66)
	head.ZIndex = 24
	head.Parent = card
	addCorner(head, 36)

	local leftArm = Instance.new("Frame")
	leftArm.Name = "LeftArm"
	leftArm.AnchorPoint = Vector2.new(0.5, 0.5)
	leftArm.BackgroundColor3 = Color3.fromRGB(2, 4, 10)
	leftArm.BorderSizePixel = 0
	leftArm.Position = UDim2.fromScale(0.25, 0.5)
	leftArm.Size = UDim2.fromOffset(24, 76)
	leftArm.Rotation = 18
	leftArm.ZIndex = 22
	leftArm.Parent = card
	addCorner(leftArm, 18)

	local rightArm = leftArm:Clone()
	rightArm.Name = "RightArm"
	rightArm.Position = UDim2.fromScale(0.75, 0.5)
	rightArm.Rotation = -18
	rightArm.Parent = card

	local question = makeLabel(card, "Question", "?", UDim2.fromOffset(58, 54), UDim2.fromScale(0.5, 0.25), 36, THEME.Cream, 26)
	question.AnchorPoint = Vector2.new(0.5, 0.5)

	local nameLabel = makeLabel(card, "Name", "???", UDim2.new(1, -16, 0, 38), UDim2.new(0, 8, 1, -48), 18, Color3.fromRGB(210, 222, 255), 26)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center

	local rarityLabel = makeLabel(card, "Rarity", "???", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 1, -24), 13, Color3.fromRGB(155, 172, 218), 26)
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center

	return card
end

local function setCardNPC(card, npc, shadowed)
	local profile = getProfile(npc.rarity)
	local nameLabel = card:FindFirstChild("Name")
	local rarityLabel = card:FindFirstChild("Rarity")
	local glow = card:FindFirstChild("Glow")
	local question = card:FindFirstChild("Question")

	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = shadowed and "???" or npc.displayName
	end

	if rarityLabel and rarityLabel:IsA("TextLabel") then
		rarityLabel.Text = shadowed and string.upper(npc.rarity) or ("[" .. string.upper(npc.rarity) .. "]")
		rarityLabel.TextColor3 = profile.color
	end

	if glow and glow:IsA("Frame") then
		glow.BackgroundColor3 = profile.color
	end

	if question and question:IsA("TextLabel") then
		question.Text = shadowed and "?" or "!"
		question.TextColor3 = shadowed and THEME.Cream or profile.color
	end
end

local function createNPCViewport(parent, npc, profile)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "NPCViewport"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundTransparency = 1
	viewport.Position = UDim2.fromScale(0.5, 0.46)
	viewport.Size = UDim2.fromOffset(260, 260)
	viewport.ZIndex = 70
	viewport.Parent = parent

	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.new(Vector3.new(0, 2.2, 8), Vector3.new(0, 1.4, 0))
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
	local second = profile.color:Lerp(THEME.White, 0.5)
	local accent = profile.deep

	part("Body", Vector3.new(1.75, 2.1, 1.05), CFrame.new(0, 0.4, 0), main, Enum.PartType.Ball)
	part("Head", Vector3.new(1.55, 1.55, 1.55), CFrame.new(0, 1.85, 0), second, Enum.PartType.Ball)
	part("LeftArm", Vector3.new(0.44, 1.25, 0.44), CFrame.new(-1.16, 0.45, 0) * CFrame.Angles(0, 0, math.rad(16)), accent, Enum.PartType.Cylinder)
	part("RightArm", Vector3.new(0.44, 1.25, 0.44), CFrame.new(1.16, 0.45, 0) * CFrame.Angles(0, 0, math.rad(-16)), accent, Enum.PartType.Cylinder)
	part("LeftFoot", Vector3.new(0.65, 0.28, 0.82), CFrame.new(-0.48, -0.9, -0.08), second, Enum.PartType.Ball)
	part("RightFoot", Vector3.new(0.65, 0.28, 0.82), CFrame.new(0.48, -0.9, -0.08), second, Enum.PartType.Ball)
	part("LeftEye", Vector3.new(0.22, 0.22, 0.06), CFrame.new(-0.32, 1.95, -0.72), THEME.White, Enum.PartType.Ball)
	part("RightEye", Vector3.new(0.22, 0.22, 0.06), CFrame.new(0.32, 1.95, -0.72), THEME.White, Enum.PartType.Ball)
	part("Smile", Vector3.new(0.54, 0.08, 0.06), CFrame.new(0, 1.55, -0.77), THEME.Ink, Enum.PartType.Block)

	for i = 1, math.max(5, math.floor(profile.intensity * 4)) do
		local angle = (math.pi * 2 / 8) * i
		part(
			"Orbit_" .. tostring(i),
			Vector3.new(0.18, 0.18, 0.18),
			CFrame.new(math.cos(angle) * 1.45, 0.6 + (i % 2) * 0.45, math.sin(angle) * 1.45),
			second,
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
	end

	local light = Instance.new("PointLight")
	light.Color = profile.color
	light.Brightness = 2.4
	light.Range = 12
	light.Parent = model:FindFirstChild("Body")

	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = viewport
	tween(scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.spawn(function()
		local started = os.clock()
		while viewport.Parent and os.clock() - started < 2.8 do
			local rot = (os.clock() - started) * 1.9
			model:PivotTo(CFrame.Angles(0, rot, 0))
			task.wait(1 / 30)
		end
	end)

	return viewport
end

local function addRays(parent, profile)
	local rayHolder = Instance.new("Frame")
	rayHolder.Name = "RarityRays"
	rayHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	rayHolder.BackgroundTransparency = 1
	rayHolder.Position = UDim2.fromScale(0.5, 0.47)
	rayHolder.Size = UDim2.fromOffset(520, 520)
	rayHolder.ZIndex = 55
	rayHolder.Parent = parent

	local count = math.floor(12 + profile.intensity * 6)
	for i = 1, count do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.BackgroundColor3 = i % 2 == 0 and profile.color or THEME.White
		ray.BackgroundTransparency = 0.28
		ray.BorderSizePixel = 0
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(10, 220 + profile.intensity * 28)
		ray.Rotation = (360 / count) * i
		ray.ZIndex = 56
		ray.Parent = rayHolder
		addCorner(ray, 8)
		tween(ray, 0.55, { BackgroundTransparency = 1, Size = UDim2.fromOffset(4, 310) })
	end

	tween(rayHolder, 0.75, { Rotation = 38 })
	Debris:AddItem(rayHolder, 0.9)
end

local function addImpactSlam(holder)
	local stage = Instance.new("Frame")
	stage.Name = "BloxImpactStage"
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.new(0, 0, 0, 98)
	stage.Size = UDim2.new(1, 0, 0, 292)
	stage.ZIndex = 38
	stage.Parent = holder

	local floor = Instance.new("Frame")
	floor.Name = "ImpactFloor"
	floor.AnchorPoint = Vector2.new(0.5, 1)
	floor.BackgroundColor3 = Color3.fromRGB(255, 232, 118)
	floor.BorderSizePixel = 0
	floor.Position = UDim2.new(0.5, 0, 1, -16)
	floor.Size = UDim2.fromOffset(530, 18)
	floor.ZIndex = 40
	floor.Parent = stage
	addCorner(floor, 12)
	addStroke(floor, THEME.Ink, 3)

	local blox = makePanel(stage, "RewardBlox", THEME.Gold, Color3.fromRGB(244, 116, 39), 24, 44)
	blox.AnchorPoint = Vector2.new(0.5, 0.5)
	blox.Position = UDim2.new(0.5, 0, 0, -104)
	blox.Size = UDim2.fromOffset(174, 174)
	blox.Rotation = -10

	local q = makeLabel(blox, "Question", "?", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 94, THEME.Cream, 48)
	q.Rotation = 4

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = blox

	local cracks = {}
	for i = 1, 7 do
		local crack = Instance.new("Frame")
		crack.Name = "Crack"
		crack.AnchorPoint = Vector2.new(0.5, 0.5)
		crack.BackgroundColor3 = THEME.Ink
		crack.BackgroundTransparency = 1
		crack.BorderSizePixel = 0
		crack.Position = UDim2.new(0.5, (i - 4) * 28, 1, -31 - math.abs(i - 4) * 3)
		crack.Size = UDim2.fromOffset(58 + math.abs(i - 4) * 8, 6)
		crack.Rotation = (i - 4) * 14
		crack.ZIndex = 42
		crack.Parent = stage
		addCorner(crack, 8)
		table.insert(cracks, crack)
	end

	task.wait(0.08)
	tween(blox, 0.28, { Position = UDim2.new(0.5, 0, 1, -106), Rotation = 7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.28)
	tween(scale, 0.07, { Scale = 1.18 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(floor, 0.07, { Size = UDim2.fromOffset(630, 16) })

	for _, crack in ipairs(cracks) do
		tween(crack, 0.08, { BackgroundTransparency = 0.03 })
	end

	for i = 1, 14 do
		local shard = Instance.new("Frame")
		shard.Name = "Shard"
		shard.AnchorPoint = Vector2.new(0.5, 0.5)
		shard.BackgroundColor3 = i % 2 == 0 and THEME.Pink or THEME.Blue
		shard.BorderSizePixel = 0
		shard.Position = UDim2.new(0.5, 0, 1, -84)
		shard.Size = UDim2.fromOffset(18, 18)
		shard.Rotation = i * 21
		shard.ZIndex = 48
		shard.Parent = stage
		addCorner(shard, 5)

		local angle = (math.pi * 2 / 14) * i
		tween(shard, 0.34, {
			Position = UDim2.new(0.5, math.cos(angle) * 190, 1, -84 + math.sin(angle) * 92),
			Rotation = shard.Rotation + 130,
			BackgroundTransparency = 1,
		})
	end

	task.wait(0.08)
	tween(scale, 0.14, { Scale = 0.96 })
	tween(blox, 0.14, { Position = UDim2.new(0.5, 0, 1, -128), Rotation = -5 }, Enum.EasingStyle.Back)
	task.wait(0.17)
	tween(blox, 0.13, { Position = UDim2.new(0.5, 0, 1, -110), Rotation = 2 })
	task.wait(0.18)

	for _, child in ipairs(stage:GetDescendants()) do
		if child:IsA("GuiObject") then
			tween(child, 0.18, { BackgroundTransparency = 1 })
		end
	end
	task.wait(0.18)
	stage:Destroy()
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
	blur.Name = "NPCRevealRollBlur"
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
	dim.BackgroundColor3 = Color3.fromRGB(7, 9, 18)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.ZIndex = 1
	dim.Parent = gui

	local holder = Instance.new("Frame")
	holder.Name = "RevealHolder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(900, 560)
	holder.ZIndex = 10
	holder.Parent = gui

	local scale = Instance.new("UIScale")
	local viewportSize = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local fit = math.clamp(math.min((viewportSize.X - 28) / 900, (viewportSize.Y - 28) / 560), 0.46, 1)
	scale.Scale = fit * 0.88
	scale.Parent = holder

	tween(dim, 0.2, { BackgroundTransparency = 0.13 })
	tween(blur, 0.24, { Size = 16 })
	tween(scale, 0.24, { Scale = fit }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	makeLabel(holder, "Title", "NPC REVEAL", UDim2.new(1, 0, 0, 62), UDim2.fromOffset(0, 0), 46, THEME.Cream, 16)
	makeLabel(holder, "Subtitle", payload.zoneName .. " Reward", UDim2.new(1, 0, 0, 32), UDim2.fromOffset(0, 58), 22, Color3.fromRGB(205, 232, 255), 16)

	addImpactSlam(holder)

	local reel = Instance.new("Frame")
	reel.Name = "RollReel"
	reel.BackgroundTransparency = 1
	reel.Position = UDim2.new(0, 0, 0, 118)
	reel.Size = UDim2.new(1, 0, 0, 250)
	reel.ClipsDescendants = false
	reel.ZIndex = 18
	reel.Parent = holder

	local cards = {}
	local slots = {
		{ x = 0.11, y = 0.52, size = 0.76, alpha = 0.55, rot = -8 },
		{ x = 0.27, y = 0.50, size = 0.9, alpha = 0.25, rot = -4 },
		{ x = 0.5, y = 0.5, size = 1.22, alpha = 0, rot = 0 },
		{ x = 0.73, y = 0.50, size = 0.9, alpha = 0.25, rot = 4 },
		{ x = 0.89, y = 0.52, size = 0.76, alpha = 0.55, rot = 8 },
	}

	for i = 1, 5 do
		local card = makeShadowCard(reel, i)
		local cardScale = Instance.new("UIScale")
		cardScale.Scale = slots[i].size
		cardScale.Parent = card
		card.Position = UDim2.fromScale(slots[i].x, slots[i].y)
		card.Rotation = slots[i].rot
		card.BackgroundTransparency = slots[i].alpha
		cards[i] = {
			card = card,
			scale = cardScale,
		}
	end

	local function applySlotVisuals()
		for i, entry in ipairs(cards) do
			local slot = slots[i]
			tween(entry.card, 0.09, {
				Position = UDim2.fromScale(slot.x, slot.y),
				Rotation = slot.rot,
				BackgroundTransparency = slot.alpha,
			})
			tween(entry.scale, 0.09, { Scale = slot.size })
		end
	end

	local possible = payload.possibleNPCs
	local index = 0
	for tick = 1, ROLL_TICKS do
		index += 1
		for i, entry in ipairs(cards) do
			local npc = possible[((index + i - 2) % #possible) + 1]
			setCardNPC(entry.card, npc, true)
		end

		applySlotVisuals()
		local center = cards[3]
		tween(center.scale, 0.045, { Scale = slots[3].size * 1.04 })

		local tickRatio = tick / ROLL_TICKS
		local delayTime = 0.028 + (tickRatio ^ 2.15) * 0.135
		local shakePower = (1 - tickRatio) * 8 + profile.intensity * 1.2
		local shakeX = (math.random() * 2 - 1) * shakePower
		local shakeY = (math.random() * 2 - 1) * shakePower
		holder.Position = UDim2.new(0.5, shakeX, 0.5, shakeY)
		playSound(TICK_SOUND_ID, 0.18, 0.9 + tickRatio * 0.5)
		task.wait(delayTime)
	end

	holder.Position = UDim2.fromScale(0.5, 0.5)
	for i, entry in ipairs(cards) do
		if i == 3 then
			setCardNPC(entry.card, selected, false)
		else
			local npc = possible[((i + 1) % #possible) + 1]
			setCardNPC(entry.card, npc, true)
		end
	end

	tween(cards[3].scale, 0.26, { Scale = 1.42 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(cards[3].card, 0.26, { Rotation = 0, BackgroundTransparency = 0 })
	task.wait(0.18)

	local flash = Instance.new("Frame")
	flash.Name = "RevealFlash"
	flash.BackgroundColor3 = profile.color
	flash.BackgroundTransparency = 0.18
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 80
	flash.Parent = gui
	tween(flash, 0.38, { BackgroundTransparency = 1 })
	Debris:AddItem(flash, 0.45)

	addRays(holder, profile)
	playSound(FINAL_SOUND_ID, 0.55, 1)

	local resultPanel = makePanel(holder, "ResultPanel", profile.color:Lerp(THEME.White, 0.16), profile.deep, 26, 60)
	resultPanel.AnchorPoint = Vector2.new(0.5, 1)
	resultPanel.Position = UDim2.new(0.5, 0, 1, -4)
	resultPanel.Size = UDim2.fromOffset(660, 142)
	resultPanel.BackgroundTransparency = 1

	local resultScale = Instance.new("UIScale")
	resultScale.Scale = 0.75
	resultScale.Parent = resultPanel

	createNPCViewport(holder, selected, profile)

	local got = makeLabel(resultPanel, "Got", "YOU GOT", UDim2.new(1, -30, 0, 28), UDim2.new(0, 15, 0, 10), 18, THEME.Cream, 64)
	got.TextXAlignment = Enum.TextXAlignment.Center

	makeLabel(resultPanel, "Name", selected.displayName, UDim2.new(1, -30, 0, 42), UDim2.new(0, 15, 0, 38), 34, THEME.White, 64)

	local mutationText = selected.mutationDisplayName
	if mutationText == "" or mutationText == "nil" then
		mutationText = "Normal"
	end

	local details = "[" .. string.upper(selected.rarity) .. "]"
	if selected.mps then
		details ..= "  |  $" .. formatNumber(selected.mps) .. "/s"
	end
	if mutationText ~= "" then
		details ..= "  |  " .. mutationText
	end

	makeLabel(resultPanel, "Details", details, UDim2.new(1, -30, 0, 32), UDim2.new(0, 15, 0, 86), 22, THEME.Cream, 64)

	local claimed = makeLabel(holder, "Claimed", "CLAIMED!", UDim2.fromOffset(220, 40), UDim2.new(0.5, -110, 1, -184), 28, profile.color, 70)
	claimed.Rotation = -3

	tween(resultPanel, 0.16, { BackgroundTransparency = 0 })
	tween(resultScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(claimed, 0.24, { Rotation = 3 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

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

	local waitStarted = os.clock()
	while not closeRequested and os.clock() - waitStarted < 2.6 do
		task.wait(0.05)
	end

	tween(dim, 0.2, { BackgroundTransparency = 1 })
	tween(blur, 0.2, { Size = 0 })
	tween(scale, 0.2, { Scale = fit * 0.86 })
	task.wait(0.22)

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
		task.wait(0.12)
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

print("[NPCRevealRoll] Loaded polished server-authoritative NPC reveal animation.")
