--!nonstrict
-- Professional code-created 2D egg hatch reveal.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local RevealNPC = {}

local DISPLAY_ORDER = 1400
local QUEUE_LIMIT = 4
local FONT = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_BLACK = Enum.Font.GothamBlack

local queue = {}
local playing = false
local activeGui = nil
local activeBlur = nil
local activeColor = nil

local RARITY_COLORS = {
	Common = Color3.fromRGB(234, 240, 248),
	Rare = Color3.fromRGB(69, 174, 255),
	Epic = Color3.fromRGB(185, 91, 255),
	Legendary = Color3.fromRGB(255, 190, 49),
	Mythic = Color3.fromRGB(255, 75, 147),
	Secret = Color3.fromRGB(68, 255, 184),
	Huge = Color3.fromRGB(255, 226, 82),
	Divine = Color3.fromRGB(106, 240, 255),
	Celestial = Color3.fromRGB(171, 140, 255),
	Godly = Color3.fromRGB(255, 90, 90),
}

local function rarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "Common")] or RARITY_COLORS.Common
end

local function cleanAssetId(id)
	if type(id) ~= "string" then
		return nil
	end
	if id == "" or string.find(id, "PASTE", 1, true) then
		return nil
	end
	return id
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

local function waitTween(instance, duration, props, style, direction)
	local tw = tween(instance, duration, props, style, direction)
	tw.Completed:Wait()
end

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
	return c
end

local function stroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function scale(parent, value)
	local s = Instance.new("UIScale")
	s.Scale = value or 1
	s.Parent = parent
	return s
end

local function makeFrame(parent, name, position, size, color, zIndex, radius)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.ZIndex = zIndex or 10
	frame.Parent = parent
	if radius then
		corner(frame, radius)
	end
	return frame
end

local function makeText(parent, name, text, position, size, color, maxSize, zIndex, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font or FONT_BOLD
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.TextTransparency = 1
	label.ZIndex = zIndex or 30
	label.Parent = parent

	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 8
	limit.MaxTextSize = maxSize or 32
	limit.Parent = label

	stroke(label, Color3.fromRGB(8, 10, 18), 2.2, 1)
	return label
end

local function fadeText(label, visible, duration)
	tween(label, duration or 0.18, { TextTransparency = visible and 0 or 1 })
	local s = label:FindFirstChildOfClass("UIStroke")
	if s then
		tween(s, duration or 0.18, { Transparency = visible and 0.06 or 1 })
	end
end

local function glow(parent, name, color, position, size, zIndex)
	local g = makeFrame(parent, name, position, size, color, zIndex, UDim.new(1, 0))
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.48, 0.38),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = g
	return g
end

local function normalizePayload(payload)
	payload = type(payload) == "table" and payload or {}
	local selected = type(payload.selectedNPC) == "table" and payload.selectedNPC or {}
	local rarity = payload.rarity or payload.Rarity or payload.selectedRarity or selected.rarity or selected.Rarity or "Common"
	local name = payload.npcName
		or payload.ResultName
		or selected.displayName
		or selected.DisplayName
		or selected.name
		or selected.Name
		or "Mystery NPC"
	local mutation = payload.mutation
		or payload.Mutation
		or payload.mutationName
		or payload.MutationName
		or payload.MutationDisplayName
		or selected.mutation
		or selected.Mutation
		or selected.mutationDisplayName
		or "Normal"

	return {
		revealId = tostring(payload.revealId or payload.RevealId or payload.EggId or name .. "_" .. tostring(os.clock())),
		npcName = tostring(name),
		rarity = tostring(rarity),
		mutation = tostring(mutation),
		eggType = tostring(payload.eggType or payload.EggName or payload.eggName or "Egg"),
		npcImage = cleanAssetId(payload.npcImage or payload.NPCImage or selected.image or selected.Image or selected.icon or selected.Icon),
		mps = tonumber(payload.MPS or payload.CashPerSecond or selected.mps or selected.MPS),
		isNew = payload.isNew == true or payload.IsNew == true or payload.New == true or payload.FirstTime == true,
	}
end

local function destroyActive()
	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end
	if activeBlur then
		activeBlur:Destroy()
		activeBlur = nil
	end
	if activeColor then
		activeColor:Destroy()
		activeColor = nil
	end
end

local function createEgg(parent, color)
	local holder = Instance.new("Frame")
	holder.Name = "PremiumEgg"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.43)
	holder.Size = UDim2.fromOffset(190, 232)
	holder.ZIndex = 40
	holder.Parent = parent
	local eggScale = scale(holder, 0.08)

	local shadow = glow(holder, "EggShadow", Color3.fromRGB(8, 10, 18), UDim2.fromScale(0.5, 0.88), UDim2.fromOffset(150, 34), 39)

	local egg = makeFrame(holder, "EggBody", UDim2.fromScale(0.5, 0.48), UDim2.fromOffset(134, 174), Color3.fromRGB(255, 248, 222), 42, UDim.new(1, 0))
	egg.BackgroundTransparency = 0
	stroke(egg, Color3.fromRGB(255, 255, 255), 5, 0.08)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 252)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 239, 190)),
		ColorSequenceKeypoint.new(1, color:Lerp(Color3.fromRGB(255, 237, 192), 0.68)),
	})
	gradient.Rotation = 90
	gradient.Parent = egg

	local highlight = makeFrame(holder, "EggHighlight", UDim2.fromScale(0.36, 0.31), UDim2.fromOffset(26, 66), Color3.fromRGB(255, 255, 255), 46, UDim.new(1, 0))
	highlight.BackgroundTransparency = 0.34
	highlight.Rotation = -24

	local cracks = {}
	local crackData = {
		{ UDim2.fromScale(0.5, 0.39), 5, 58, 26 },
		{ UDim2.fromScale(0.57, 0.49), 5, 46, -34 },
		{ UDim2.fromScale(0.43, 0.5), 5, 42, 38 },
		{ UDim2.fromScale(0.51, 0.28), 4, 36, -12 },
	}
	for i, data in ipairs(crackData) do
		local crack = makeFrame(holder, "Crack_" .. i, data[1], UDim2.fromOffset(data[2], data[3]), Color3.fromRGB(116, 86, 57), 50, UDim.new(1, 0))
		crack.Rotation = data[4]
		table.insert(cracks, crack)
	end

	return {
		holder = holder,
		scale = eggScale,
		shadow = shadow,
		cracks = cracks,
	}
end

local function createRings(parent, color)
	local rings = {}
	for i = 1, 4 do
		local ring = makeFrame(parent, "EnergyRing_" .. i, UDim2.fromScale(0.5, 0.43), UDim2.fromOffset(160 + i * 56, 160 + i * 56), color, 12 + i, UDim.new(1, 0))
		local ringStroke = stroke(ring, i % 2 == 0 and Color3.fromRGB(255, 255, 255) or color, i == 1 and 3 or 2, 1)
		table.insert(rings, { ring = ring, stroke = ringStroke })
	end
	return rings
end

local function createParticles(parent, color)
	local particles = {}
	for i = 1, 28 do
		local size = 6 + (i % 5) * 3
		local part = makeFrame(parent, "BurstParticle_" .. i, UDim2.fromScale(0.5, 0.43), UDim2.fromOffset(size, size), i % 4 == 0 and Color3.fromRGB(255, 255, 255) or color, 80, UDim.new(1, 0))
		table.insert(particles, part)
	end
	return particles
end

local function createReward(parent, data, color)
	local holder = Instance.new("Frame")
	holder.Name = "RewardStage"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.46)
	holder.Size = UDim2.fromOffset(330, 350)
	holder.ZIndex = 90
	holder.Parent = parent
	local rewardScale = scale(holder, 0.18)

	local aura = glow(holder, "RewardAura", color, UDim2.fromScale(0.5, 0.35), UDim2.fromOffset(280, 280), 90)
	local plate = makeFrame(holder, "RewardPlate", UDim2.fromScale(0.5, 0.72), UDim2.fromOffset(260, 68), color:Lerp(Color3.fromRGB(26, 31, 48), 0.42), 93, UDim.new(0, 30))
	stroke(plate, Color3.fromRGB(255, 255, 255), 2.5, 1)

	local preview = Instance.new("Frame")
	preview.Name = "RewardPreview"
	preview.AnchorPoint = Vector2.new(0.5, 0.5)
	preview.BackgroundTransparency = 1
	preview.Position = UDim2.fromScale(0.5, 0.35)
	preview.Size = UDim2.fromOffset(210, 210)
	preview.ZIndex = 96
	preview.Parent = holder

	local npcImage
	if data.npcImage then
		npcImage = Instance.new("ImageLabel")
		npcImage.Name = "NpcImage"
		npcImage.AnchorPoint = Vector2.new(0.5, 0.5)
		npcImage.BackgroundTransparency = 1
		npcImage.Image = data.npcImage
		npcImage.ImageTransparency = 1
		npcImage.Position = UDim2.fromScale(0.5, 0.5)
		npcImage.Size = UDim2.fromScale(1, 1)
		npcImage.ZIndex = 98
		npcImage.Parent = preview
	else
		local body = makeFrame(preview, "NpcBody", UDim2.fromScale(0.5, 0.61), UDim2.fromOffset(120, 118), color, 98, UDim.new(0, 34))
		stroke(body, Color3.fromRGB(255, 255, 255), 4, 1)
		local head = makeFrame(preview, "NpcHead", UDim2.fromScale(0.5, 0.3), UDim2.fromOffset(104, 104), color:Lerp(Color3.fromRGB(255, 255, 255), 0.22), 99, UDim.new(1, 0))
		stroke(head, Color3.fromRGB(255, 255, 255), 4, 1)
		local face = makeText(preview, "NpcFace", ":)", UDim2.fromScale(0.33, 0.18), UDim2.fromScale(0.34, 0.18), Color3.fromRGB(255, 255, 255), 32, 100, FONT_BLACK)
		npcImage = { body = body, head = head, face = face }
	end

	local rewardName = data.mutation == "Normal" and data.npcName or (data.mutation .. " " .. data.npcName)
	local title = makeText(holder, "UnlockedLabel", "UNLOCKED", UDim2.fromScale(0.2, 0.02), UDim2.fromScale(0.6, 0.08), Color3.fromRGB(255, 255, 255), 25, 102, FONT_BLACK)
	local name = makeText(holder, "RewardName", rewardName, UDim2.fromScale(0.04, 0.76), UDim2.fromScale(0.92, 0.13), Color3.fromRGB(255, 255, 255), 36, 102, FONT_BLACK)
	local pill = makeFrame(holder, "RarityPill", UDim2.fromScale(0.5, 0.91), UDim2.fromOffset(174, 36), color, 102, UDim.new(1, 0))
	stroke(pill, Color3.fromRGB(255, 255, 255), 2, 1)
	local rarity = makeText(pill, "Rarity", string.upper(data.rarity), UDim2.fromScale(0.08, 0.14), UDim2.fromScale(0.84, 0.68), Color3.fromRGB(255, 255, 255), 18, 103, FONT_BOLD)

	local value = nil
	if data.mps then
		value = makeText(holder, "Value", "+" .. tostring(math.floor(data.mps)) .. "/s", UDim2.fromScale(0.62, 0.64), UDim2.fromScale(0.27, 0.08), Color3.fromRGB(255, 246, 182), 20, 102, FONT_BOLD)
	end

	return {
		holder = holder,
		scale = rewardScale,
		aura = aura,
		plate = plate,
		image = npcImage,
		title = title,
		name = name,
		pill = pill,
		rarity = rarity,
		value = value,
	}
end

local function revealReward(reward)
	tween(reward.aura, 0.2, { BackgroundTransparency = 0.24, Size = UDim2.fromOffset(350, 350) })
	tween(reward.plate, 0.2, { BackgroundTransparency = 0.04 })
	local plateStroke = reward.plate:FindFirstChildOfClass("UIStroke")
	if plateStroke then
		tween(plateStroke, 0.2, { Transparency = 0.18 })
	end

	if typeof(reward.image) == "Instance" then
		tween(reward.image, 0.2, { ImageTransparency = 0 })
	else
		tween(reward.image.body, 0.18, { BackgroundTransparency = 0.04 })
		tween(reward.image.head, 0.18, { BackgroundTransparency = 0.04 })
		for _, part in ipairs({ reward.image.body, reward.image.head }) do
			local partStroke = part:FindFirstChildOfClass("UIStroke")
			if partStroke then
				tween(partStroke, 0.18, { Transparency = 0.12 })
			end
		end
		fadeText(reward.image.face, true, 0.16)
	end

	waitTween(reward.scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	fadeText(reward.title, true, 0.14)
	fadeText(reward.name, true, 0.18)
	tween(reward.pill, 0.18, { BackgroundTransparency = 0.05 })
	local pillStroke = reward.pill:FindFirstChildOfClass("UIStroke")
	if pillStroke then
		tween(pillStroke, 0.18, { Transparency = 0.18 })
	end
	fadeText(reward.rarity, true, 0.14)
	if reward.value then
		fadeText(reward.value, true, 0.18)
	end
	tween(reward.aura, 1.6, { Rotation = 180 }, Enum.EasingStyle.Linear)
end

local function playReveal(rawPayload)
	local data = normalizePayload(rawPayload)
	local color = rarityColor(data.rarity)
	local playerGui = player:WaitForChild("PlayerGui")

	destroyActive()

	local gui = Instance.new("ScreenGui")
	gui.Name = "NPCRevealGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = DISPLAY_ORDER
	gui.Parent = playerGui
	activeGui = gui

	local blur = Instance.new("BlurEffect")
	blur.Name = "NPCRevealBlur"
	blur.Size = 0
	blur.Parent = Lighting
	activeBlur = blur

	local colorFx = Instance.new("ColorCorrectionEffect")
	colorFx.Name = "NPCRevealColor"
	colorFx.Brightness = 0
	colorFx.Contrast = 0
	colorFx.Saturation = 0
	colorFx.TintColor = Color3.fromRGB(255, 255, 255)
	colorFx.Parent = Lighting
	activeColor = colorFx

	local overlay = Instance.new("Frame")
	overlay.Name = "CinematicOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(8, 11, 20)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 1
	overlay.Parent = gui

	local overlayGradient = Instance.new("UIGradient")
	overlayGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 11, 20)),
		ColorSequenceKeypoint.new(0.48, color:Lerp(Color3.fromRGB(20, 25, 40), 0.62)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 20)),
	})
	overlayGradient.Rotation = 22
	overlayGradient.Parent = overlay

	local stage = Instance.new("Frame")
	stage.Name = "RevealStage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromScale(0.92, 0.88)
	stage.ZIndex = 10
	stage.Parent = gui
	local stageScale = scale(stage, 0.92)

	local stageConstraint = Instance.new("UISizeConstraint")
	stageConstraint.MinSize = Vector2.new(320, 440)
	stageConstraint.MaxSize = Vector2.new(520, 620)
	stageConstraint.Parent = stage

	local floorGlow = glow(stage, "FloorGlow", color, UDim2.fromScale(0.5, 0.76), UDim2.fromOffset(360, 86), 11)
	local coreGlow = glow(stage, "CoreGlow", color, UDim2.fromScale(0.5, 0.43), UDim2.fromOffset(260, 260), 11)
	local rings = createRings(stage, color)
	local particles = createParticles(stage, color)
	local egg = createEgg(stage, color)
	local reward = createReward(stage, data, color)
	reward.holder.Visible = false

	local title = makeText(stage, "HatchTitle", "HATCHING", UDim2.fromScale(0.22, 0.08), UDim2.fromScale(0.56, 0.07), Color3.fromRGB(255, 255, 255), 26, 95, FONT_BLACK)
	local subtitle = makeText(stage, "EggName", data.eggType, UDim2.fromScale(0.18, 0.15), UDim2.fromScale(0.64, 0.055), color:Lerp(Color3.fromRGB(255, 255, 255), 0.24), 18, 95, FONT_BOLD)

	local flash = Instance.new("Frame")
	flash.Name = "WhiteFlash"
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 200
	flash.Parent = gui

	local continue = makeFrame(stage, "ContinueButton", UDim2.fromScale(0.5, 0.94), UDim2.fromOffset(230, 48), Color3.fromRGB(15, 18, 30), 110, UDim.new(1, 0))
	stroke(continue, color, 2, 1)
	local continueText = makeText(continue, "Text", "Tap to continue", UDim2.fromScale(0.08, 0.2), UDim2.fromScale(0.84, 0.58), Color3.fromRGB(255, 255, 255), 18, 111, FONT_BOLD)

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseHitbox"
	closeButton.BackgroundTransparency = 1
	closeButton.Text = ""
	closeButton.Size = UDim2.fromScale(1, 1)
	closeButton.Visible = false
	closeButton.ZIndex = 250
	closeButton.Parent = gui

	tween(overlay, 0.28, { BackgroundTransparency = 0.1 })
	tween(blur, 0.28, { Size = 16 })
	tween(colorFx, 0.28, { Contrast = 0.12, Saturation = 0.1, TintColor = color:Lerp(Color3.fromRGB(255, 255, 255), 0.72) })
	tween(stageScale, 0.32, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	tween(floorGlow, 0.28, { BackgroundTransparency = 0.48 })
	tween(coreGlow, 0.28, { BackgroundTransparency = 0.36, Size = UDim2.fromOffset(330, 330) })
	fadeText(title, true, 0.18)
	fadeText(subtitle, true, 0.18)
	waitTween(egg.scale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(egg.shadow, 0.22, { BackgroundTransparency = 0.42 })

	for _, item in ipairs(rings) do
		tween(item.stroke, 0.18, { Transparency = 0.2 })
		local ringSize = item.ring.AbsoluteSize
		tween(item.ring, 0.72, {
			Rotation = item.ring.Rotation + 160,
			Size = UDim2.fromOffset(ringSize.X + 44, ringSize.Y + 44),
		}, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end

	for i = 1, 4 do
		tween(egg.scale, 0.09, { Scale = 1.05 + i * 0.025 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		tween(egg.holder, 0.09, { Rotation = i % 2 == 0 and -8 or 8 })
		task.wait(0.09)
		tween(egg.scale, 0.1, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(0.08)
	end

	for _, crack in ipairs(egg.cracks) do
		tween(crack, 0.08, { BackgroundTransparency = 0.02 })
		task.wait(0.035)
	end

	waitTween(flash, 0.08, { BackgroundTransparency = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(flash, 0.24, { BackgroundTransparency = 1 })
	tween(coreGlow, 0.16, { BackgroundTransparency = 0.08, Size = UDim2.fromOffset(470, 470) })
	tween(egg.scale, 0.16, { Scale = 1.28 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(0.07)
	tween(egg.scale, 0.13, { Scale = 0.02 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	for i, part in ipairs(particles) do
		local angle = math.rad((i / #particles) * 360)
		local distance = 112 + (i % 6) * 22
		local x = math.cos(angle) * distance
		local y = math.sin(angle) * distance * 0.72
		local partSize = part.AbsoluteSize
		part.BackgroundTransparency = 0
		tween(part, 0.38 + (i % 4) * 0.035, {
			Position = UDim2.new(0.5, x, 0.43, y),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(partSize.X + 12, partSize.Y + 12),
		}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end

	fadeText(title, false, 0.12)
	fadeText(subtitle, false, 0.12)
	task.wait(0.14)
	egg.holder.Visible = false

	reward.holder.Visible = true
	revealReward(reward)
	tween(coreGlow, 0.42, { BackgroundTransparency = 0.28, Size = UDim2.fromOffset(360, 360) })
	for _, item in ipairs(rings) do
		tween(item.ring, 1.2, { Rotation = item.ring.Rotation + 220 }, Enum.EasingStyle.Linear)
	end

	task.wait(0.3)
	tween(continue, 0.2, { BackgroundTransparency = 0.08 })
	local continueStroke = continue:FindFirstChildOfClass("UIStroke")
	if continueStroke then
		tween(continueStroke, 0.2, { Transparency = 0.22 })
	end
	fadeText(continueText, true, 0.16)
	closeButton.Visible = true

	local closeRequested = false
	local clickConn = closeButton.Activated:Connect(function()
		closeRequested = true
	end)
	local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA then
			closeRequested = true
		end
	end)

	local started = os.clock()
	while not closeRequested and os.clock() - started < 5 do
		task.wait(0.05)
	end
	clickConn:Disconnect()
	inputConn:Disconnect()

	tween(overlay, 0.2, { BackgroundTransparency = 1 })
	tween(blur, 0.2, { Size = 0 })
	tween(colorFx, 0.2, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255, 255, 255) })
	tween(stageScale, 0.18, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, inst in ipairs(stage:GetDescendants()) do
		if inst:IsA("Frame") then
			tween(inst, 0.16, { BackgroundTransparency = 1 })
		elseif inst:IsA("TextLabel") then
			fadeText(inst, false, 0.14)
		elseif inst:IsA("ImageLabel") then
			tween(inst, 0.16, { ImageTransparency = 1 })
		elseif inst:IsA("UIStroke") then
			tween(inst, 0.16, { Transparency = 1 })
		end
	end
	task.wait(0.22)
	destroyActive()
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
			warn("[NPCRevealGui] Reveal failed:", err)
			destroyActive()
		end
		task.wait(0.08)
	end
	playing = false
end

function RevealNPC.show(payload)
	table.insert(queue, payload)
	while #queue > QUEUE_LIMIT do
		table.remove(queue, 1)
	end
	task.defer(processQueue)
end

function RevealNPC.clear()
	table.clear(queue)
	destroyActive()
	playing = false
end

return RevealNPC
