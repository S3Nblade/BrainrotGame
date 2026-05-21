--!nonstrict
-- Reusable simulator-style egg NPC reveal GUI.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

local Assets = require(script.Parent:WaitForChild("NPCRevealAssets"))

local RevealNPC = {}

local FONT_BOLD = Enum.Font.GothamBold
local FONT = Enum.Font.GothamMedium
local DISPLAY_ORDER = 1200
local QUEUE_LIMIT = 4

local RARITY_COLORS = {
	Common = Color3.fromRGB(238, 242, 248),
	Rare = Color3.fromRGB(72, 175, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 189, 44),
	Mythic = Color3.fromRGB(255, 76, 148),
	Secret = Color3.fromRGB(72, 255, 176),
	Huge = Color3.fromRGB(255, 224, 82),
	Divine = Color3.fromRGB(106, 240, 255),
	Celestial = Color3.fromRGB(170, 138, 255),
	Godly = Color3.fromRGB(255, 92, 92),
}

local queue = {}
local playing = false
local activeGui = nil
local activeBlur = nil

local function cleanAssetId(id)
	if type(id) ~= "string" then
		return nil
	end
	if id == "" or string.find(id, "PASTE_") or string.find(id, "PASTE") then
		return nil
	end
	return id
end

local function asset(name)
	return cleanAssetId(Assets[name])
end

local function rarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "Common")] or RARITY_COLORS.Common
end

local function tween(instance, duration, props, style, direction)
	local info = TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tw = TweenService:Create(instance, info, props)
	tw:Play()
	return tw
end

local function waitTween(instance, duration, props, style, direction)
	local tw = tween(instance, duration, props, style, direction)
	tw.Completed:Wait()
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function addScale(parent, value)
	local scale = Instance.new("UIScale")
	scale.Scale = value or 1
	scale.Parent = parent
	return scale
end

local function makeText(parent, name, text, position, size, color, maxSize, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = FONT_BOLD
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.TextTransparency = 1
	label.ZIndex = zIndex or 30
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 10
	constraint.MaxTextSize = maxSize or 32
	constraint.Parent = label

	addStroke(label, Color3.fromRGB(21, 24, 34), 2.3, 0.05)
	return label
end

local function fadeText(label, visible, duration)
	tween(label, duration or 0.18, { TextTransparency = visible and 0 or 1 })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		tween(stroke, duration or 0.18, { Transparency = visible and 0.05 or 1 })
	end
end

local function imageOrFallback(parent, name, imageId, color, position, size, zIndex, fallbackShape)
	if imageId then
		local image = Instance.new("ImageLabel")
		image.Name = name
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = imageId
		image.ImageColor3 = color or Color3.new(1, 1, 1)
		image.ImageTransparency = 1
		image.Position = position
		image.Size = size
		image.ZIndex = zIndex or 10
		image.Parent = parent
		return image
	end

	local frame = Instance.new("Frame")
	frame.Name = name .. "Fallback"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = position
	frame.Size = size
	frame.ZIndex = zIndex or 10
	frame.Parent = parent
	addCorner(frame, fallbackShape == "circle" and UDim.new(1, 0) or UDim.new(0, 24))
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.62, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	return frame
end

local function createEgg(parent, rarity)
	local holder = Instance.new("Frame")
	holder.Name = "AnimatedEgg"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.42)
	holder.Size = UDim2.fromOffset(170, 210)
	holder.ZIndex = 24
	holder.Parent = parent

	local scale = addScale(holder, 0.18)

	local egg = Instance.new("Frame")
	egg.Name = "EggBody"
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.BackgroundColor3 = Color3.fromRGB(255, 248, 219)
	egg.BorderSizePixel = 0
	egg.Position = UDim2.fromScale(0.5, 0.5)
	egg.Size = UDim2.fromOffset(132, 172)
	egg.ZIndex = 25
	egg.Parent = holder
	addCorner(egg, UDim.new(1, 0))
	addStroke(egg, Color3.fromRGB(255, 255, 255), 4, 0.12)

	local bodyGradient = Instance.new("UIGradient")
	bodyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 248)),
		ColorSequenceKeypoint.new(1, rarityColor(rarity):Lerp(Color3.fromRGB(255, 244, 204), 0.72)),
	})
	bodyGradient.Rotation = 90
	bodyGradient.Parent = egg

	local shine = Instance.new("Frame")
	shine.Name = "EggHighlight"
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.35
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.35, 0.28)
	shine.Rotation = -22
	shine.Size = UDim2.fromOffset(24, 58)
	shine.ZIndex = 26
	shine.Parent = egg
	addCorner(shine, UDim.new(1, 0))

	local crackA = Instance.new("Frame")
	crackA.Name = "CrackA"
	crackA.AnchorPoint = Vector2.new(0.5, 0.5)
	crackA.BackgroundColor3 = Color3.fromRGB(133, 105, 72)
	crackA.BackgroundTransparency = 1
	crackA.BorderSizePixel = 0
	crackA.Position = UDim2.fromScale(0.5, 0.42)
	crackA.Rotation = 32
	crackA.Size = UDim2.fromOffset(5, 54)
	crackA.ZIndex = 27
	crackA.Parent = egg
	addCorner(crackA, UDim.new(1, 0))

	local crackB = crackA:Clone()
	crackB.Name = "CrackB"
	crackB.Position = UDim2.fromScale(0.57, 0.54)
	crackB.Rotation = -35
	crackB.Size = UDim2.fromOffset(5, 44)
	crackB.Parent = egg

	return holder, scale, { crackA, crackB }
end

local function createPodium(parent)
	local holder = Instance.new("Frame")
	holder.Name = "CodePodiumFallback"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.62)
	holder.Size = UDim2.fromOffset(300, 130)
	holder.ZIndex = 18
	holder.Parent = parent

	local glow = Instance.new("Frame")
	glow.Name = "PodiumGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = Color3.fromRGB(91, 203, 255)
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromScale(0.5, 0.62)
	glow.Size = UDim2.fromOffset(260, 44)
	glow.ZIndex = 18
	glow.Parent = holder
	addCorner(glow, UDim.new(1, 0))

	local top = Instance.new("Frame")
	top.Name = "PodiumTop"
	top.AnchorPoint = Vector2.new(0.5, 0.5)
	top.BackgroundColor3 = Color3.fromRGB(82, 169, 255)
	top.BackgroundTransparency = 1
	top.BorderSizePixel = 0
	top.Position = UDim2.fromScale(0.5, 0.46)
	top.Size = UDim2.fromOffset(260, 58)
	top.ZIndex = 19
	top.Parent = holder
	addCorner(top, UDim.new(0, 28))
	addStroke(top, Color3.fromRGB(255, 255, 255), 3, 0.28)

	local base = Instance.new("Frame")
	base.Name = "PodiumBase"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.BackgroundColor3 = Color3.fromRGB(46, 97, 220)
	base.BackgroundTransparency = 1
	base.BorderSizePixel = 0
	base.Position = UDim2.fromScale(0.5, 0.68)
	base.Size = UDim2.fromOffset(210, 46)
	base.ZIndex = 18
	base.Parent = holder
	addCorner(base, UDim.new(0, 22))

	return holder
end

local function createNpcPreview(parent, data, color)
	local holder = Instance.new("Frame")
	holder.Name = "NpcPreview"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.41)
	holder.Size = UDim2.fromOffset(214, 214)
	holder.ZIndex = 35
	holder.Parent = parent

	local scale = addScale(holder, 0.08)

	local npcImage = cleanAssetId(data.npcImage or data.NPCImage or data.image or data.Image)
	if npcImage then
		local image = Instance.new("ImageLabel")
		image.Name = "NpcImage"
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundTransparency = 1
		image.Image = npcImage
		image.ImageTransparency = 1
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(1, 1)
		image.ZIndex = 36
		image.Parent = holder
		return holder, scale, image
	end

	local body = Instance.new("Frame")
	body.Name = "FallbackBody"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.BackgroundColor3 = color
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromScale(0.5, 0.6)
	body.Size = UDim2.fromOffset(112, 118)
	body.ZIndex = 36
	body.Parent = holder
	addCorner(body, UDim.new(0, 34))
	addStroke(body, Color3.fromRGB(255, 255, 255), 4, 0.18)

	local head = Instance.new("Frame")
	head.Name = "FallbackHead"
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.24)
	head.BackgroundTransparency = 1
	head.BorderSizePixel = 0
	head.Position = UDim2.fromScale(0.5, 0.3)
	head.Size = UDim2.fromOffset(96, 96)
	head.ZIndex = 37
	head.Parent = holder
	addCorner(head, UDim.new(1, 0))
	addStroke(head, Color3.fromRGB(255, 255, 255), 4, 0.15)

	local face = makeText(holder, "FallbackFace", ":)", UDim2.fromScale(0.31, 0.19), UDim2.fromScale(0.38, 0.18), Color3.fromRGB(255, 255, 255), 34, 38)
	face.TextTransparency = 1
	face.Font = FONT

	return holder, scale, nil
end

local function createSparkles(parent, color)
	local sparkles = {}
	for i = 1, 18 do
		local angle = math.rad((i / 18) * 360)
		local distance = 110 + (i % 4) * 22
		local x = math.cos(angle) * distance
		local y = math.sin(angle) * distance * 0.76
		local sparkle = imageOrFallback(
			parent,
			"Sparkle_" .. i,
			asset("SparkleStar"),
			i % 3 == 0 and Color3.fromRGB(255, 255, 255) or color,
			UDim2.new(0.5, x, 0.42, y),
			UDim2.fromOffset(22 + (i % 4) * 8, 22 + (i % 4) * 8),
			45,
			"circle"
		)
		sparkle.Rotation = i * 23
		table.insert(sparkles, sparkle)
	end
	return sparkles
end

local function normalizePayload(payload)
	payload = type(payload) == "table" and payload or {}
	local selected = type(payload.selectedNPC) == "table" and payload.selectedNPC or {}
	local rarity = payload.rarity or payload.Rarity or payload.selectedRarity or selected.rarity or selected.Rarity or "Common"
	local name = payload.npcName or payload.ResultName or selected.displayName or selected.DisplayName or selected.name or selected.Name or "Mystery NPC"

	return {
		revealId = tostring(payload.revealId or payload.RevealId or payload.EggId or name .. "_" .. tostring(os.clock())),
		npcName = tostring(name),
		rarity = tostring(rarity),
		isNew = payload.isNew == true or payload.IsNew == true or payload.New == true or payload.FirstTime == true,
		eggType = tostring(payload.eggType or payload.EggName or payload.eggName or "Egg"),
		npcImage = payload.npcImage or payload.NPCImage or selected.image or selected.Image or selected.icon or selected.Icon,
	}
end

local function setFrameTransparency(root, value, duration)
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("Frame") then
			tween(inst, duration, { BackgroundTransparency = math.max(inst.BackgroundTransparency, value) })
		elseif inst:IsA("ImageLabel") then
			tween(inst, duration, { ImageTransparency = value })
		elseif inst:IsA("TextLabel") then
			tween(inst, duration, { TextTransparency = value })
			local stroke = inst:FindFirstChildOfClass("UIStroke")
			if stroke then
				tween(stroke, duration, { Transparency = value })
			end
		elseif inst:IsA("UIStroke") then
			tween(inst, duration, { Transparency = value })
		end
	end
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
	blur.Name = "NPCRevealSoftBlur"
	blur.Size = 0
	blur.Parent = Lighting
	activeBlur = blur

	local overlay = Instance.new("Frame")
	overlay.Name = "SoftWorldOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(255, 246, 196)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 1
	overlay.Parent = gui

	local overlayGradient = Instance.new("UIGradient")
	overlayGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 214)),
		ColorSequenceKeypoint.new(0.52, color:Lerp(Color3.fromRGB(130, 230, 255), 0.38)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 188, 230)),
	})
	overlayGradient.Rotation = 28
	overlayGradient.Parent = overlay

	local stage = Instance.new("Frame")
	stage.Name = "RevealStage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.BackgroundTransparency = 1
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromScale(0.92, 0.86)
	stage.ZIndex = 10
	stage.Parent = gui
	local stageScale = addScale(stage, 0.82)

	local stageSize = Instance.new("UISizeConstraint")
	stageSize.MinSize = Vector2.new(310, 420)
	stageSize.MaxSize = Vector2.new(470, 560)
	stageSize.Parent = stage

	local cardGlow = imageOrFallback(stage, "RevealCardGlow", asset("CardGlow"), color, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.08, 1), 11)

	local card = Instance.new("Frame")
	card.Name = "RevealCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(255, 248, 224)
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.Position = UDim2.fromScale(0.5, 0.51)
	card.Size = UDim2.fromScale(0.88, 0.86)
	card.ZIndex = 12
	card.Parent = stage
	addCorner(card, UDim.new(0, 26))
	addStroke(card, Color3.fromRGB(255, 255, 255), 4, 0.18)

	local cardGradient = Instance.new("UIGradient")
	cardGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 248)),
		ColorSequenceKeypoint.new(0.72, Color3.fromRGB(255, 234, 173)),
		ColorSequenceKeypoint.new(1, color:Lerp(Color3.fromRGB(255, 255, 255), 0.7)),
	})
	cardGradient.Rotation = 90
	cardGradient.Parent = card

	local softGlow = imageOrFallback(stage, "SoftGlow", asset("SoftGlow"), color, UDim2.fromScale(0.5, 0.42), UDim2.fromOffset(360, 360), 14, "circle")
	local burstRing = imageOrFallback(stage, "RarityBurstRing", asset("BurstRing"), color, UDim2.fromScale(0.5, 0.42), UDim2.fromOffset(80, 80), 15, "circle")
	local crackFlash = imageOrFallback(stage, "CodeCrackFlash", nil, Color3.fromRGB(255, 248, 184), UDim2.fromScale(0.5, 0.42), UDim2.fromOffset(100, 100), 46, "circle")
	local podium = createPodium(stage)

	local egg, eggScale, cracks = createEgg(stage, data.eggType)
	local sparkles = createSparkles(stage, color)

	local rarityLabel = makeText(stage, "RarityLabel", data.rarity, UDim2.fromScale(0.16, 0.105), UDim2.fromScale(0.68, 0.07), color, 28, 42)
	local nameLabel = makeText(stage, "NpcName", data.npcName, UDim2.fromScale(0.07, 0.7), UDim2.fromScale(0.86, 0.1), Color3.fromRGB(255, 255, 255), 36, 42)

	local newBadge
	if data.isNew then
		newBadge = imageOrFallback(stage, "NewBadge", asset("NewBadge"), Color3.fromRGB(255, 74, 96), UDim2.fromScale(0.78, 0.16), UDim2.fromOffset(108, 52), 50)
		newBadge.Rotation = -8
		local newText = makeText(newBadge, "NewText", "NEW!", UDim2.fromScale(0.12, 0.16), UDim2.fromScale(0.76, 0.66), Color3.fromRGB(255, 255, 255), 26, 51)
		newText.TextTransparency = 1
	end

	local shine = imageOrFallback(stage, "ShineSweep", asset("ShineStreak"), Color3.fromRGB(255, 255, 255), UDim2.fromScale(-0.1, 0.46), UDim2.fromOffset(90, 360), 55)
	shine.Rotation = -20

	local tapPanel = imageOrFallback(stage, "TapPanel", asset("TapPanel"), Color3.fromRGB(16, 20, 30), UDim2.fromScale(0.5, 0.91), UDim2.fromOffset(256, 58), 58)
	local tapText = makeText(tapPanel, "TapText", "Tap to continue", UDim2.fromScale(0.08, 0.18), UDim2.fromScale(0.84, 0.62), Color3.fromRGB(255, 255, 255), 21, 59)
	tapText.Font = FONT

	local npcHolder, npcScale, npcImage = createNpcPreview(stage, data, color)
	npcHolder.Visible = false

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseHitbox"
	closeButton.BackgroundTransparency = 1
	closeButton.Text = ""
	closeButton.Size = UDim2.fromScale(1, 1)
	closeButton.Visible = false
	closeButton.ZIndex = 100
	closeButton.Parent = gui

	tween(overlay, 0.24, { BackgroundTransparency = 0.18 })
	tween(blur, 0.24, { Size = 7 })
	tween(stageScale, 0.36, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(card, 0.28, { BackgroundTransparency = 0.04 })
	tween(cardGlow, 0.28, cardGlow:IsA("ImageLabel") and { ImageTransparency = 0.16 } or { BackgroundTransparency = 0.22 })
	tween(softGlow, 0.26, softGlow:IsA("ImageLabel") and { ImageTransparency = 0.2 } or { BackgroundTransparency = 0.38 })
	for _, inst in ipairs(podium:GetDescendants()) do
		if inst:IsA("Frame") then
			tween(inst, 0.28, { BackgroundTransparency = inst.Name == "PodiumGlow" and 0.42 or 0.05 })
		end
	end
	waitTween(eggScale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	for _ = 1, 3 do
		tween(eggScale, 0.12, { Scale = 1.08 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		task.wait(0.12)
		tween(eggScale, 0.12, { Scale = 0.98 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(0.12)
	end

	for i = 1, 8 do
		local amount = i % 2 == 0 and -11 or 11
		tween(egg, 0.055, { Rotation = amount, Position = UDim2.new(0.5, amount * 0.7, 0.42, 0) })
		task.wait(0.055)
	end
	tween(egg, 0.08, { Rotation = 0, Position = UDim2.fromScale(0.5, 0.42) })

	for _, crack in ipairs(cracks) do
		tween(crack, 0.1, { BackgroundTransparency = 0.05 })
	end
	tween(softGlow, 0.18, softGlow:IsA("ImageLabel") and { ImageTransparency = 0.02, Size = UDim2.fromOffset(430, 430) } or { BackgroundTransparency = 0.18, Size = UDim2.fromOffset(430, 430) })
	task.wait(0.16)

	tween(crackFlash, 0.12, crackFlash:IsA("ImageLabel") and { ImageTransparency = 0, Size = UDim2.fromOffset(310, 310) } or { BackgroundTransparency = 0.08, Size = UDim2.fromOffset(310, 310) })
	tween(burstRing, 0.34, burstRing:IsA("ImageLabel") and { ImageTransparency = 0.03, Size = UDim2.fromOffset(390, 390), Rotation = 90 } or { BackgroundTransparency = 0.25, Size = UDim2.fromOffset(390, 390), Rotation = 90 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(eggScale, 0.15, { Scale = 1.32 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.wait(0.08)
	tween(eggScale, 0.14, { Scale = 0.02 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	for _, sparkle in ipairs(sparkles) do
		local goal = sparkle:IsA("ImageLabel") and { ImageTransparency = 0, Rotation = sparkle.Rotation + 80 } or { BackgroundTransparency = 0.2, Rotation = sparkle.Rotation + 80 }
		tween(sparkle, 0.22 + math.random() * 0.1, goal, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	task.wait(0.16)
	egg.Visible = false
	tween(crackFlash, 0.22, crackFlash:IsA("ImageLabel") and { ImageTransparency = 1, Size = UDim2.fromOffset(460, 460) } or { BackgroundTransparency = 1, Size = UDim2.fromOffset(460, 460) })

	npcHolder.Visible = true
	if npcImage then
		tween(npcImage, 0.2, { ImageTransparency = 0 })
	else
		for _, inst in ipairs(npcHolder:GetDescendants()) do
			if inst:IsA("Frame") then
				tween(inst, 0.2, { BackgroundTransparency = 0.04 })
			elseif inst:IsA("TextLabel") then
				fadeText(inst, true, 0.18)
			end
		end
	end
	tween(npcScale, 0.42, { Scale = data.rarity == "Huge" and 1.18 or 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(burstRing, 1.4, { Rotation = 330 }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	task.wait(0.08)
	fadeText(rarityLabel, true, 0.18)
	task.wait(0.08)
	fadeText(nameLabel, true, 0.2)

	if newBadge then
		tween(newBadge, 0.22, newBadge:IsA("ImageLabel") and { ImageTransparency = 0 } or { BackgroundTransparency = 0.04 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for _, child in ipairs(newBadge:GetChildren()) do
			if child:IsA("TextLabel") then
				fadeText(child, true, 0.16)
			end
		end
	end

	tween(shine, 0.58, shine:IsA("ImageLabel") and { ImageTransparency = 0.2, Position = UDim2.fromScale(1.12, 0.46) } or { BackgroundTransparency = 0.2, Position = UDim2.fromScale(1.12, 0.46) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	task.wait(0.48)
	tween(shine, 0.14, shine:IsA("ImageLabel") and { ImageTransparency = 1 } or { BackgroundTransparency = 1 })

	tween(tapPanel, 0.22, tapPanel:IsA("ImageLabel") and { ImageTransparency = 0 } or { BackgroundTransparency = 0.05 })
	fadeText(tapText, true, 0.18)
	closeButton.Visible = true

	local closeRequested = false
	local conn = closeButton.Activated:Connect(function()
		closeRequested = true
	end)

	local started = os.clock()
	while not closeRequested and os.clock() - started < 3 do
		task.wait(0.05)
	end
	conn:Disconnect()

	tween(overlay, 0.18, { BackgroundTransparency = 1 })
	tween(blur, 0.18, { Size = 0 })
	tween(stageScale, 0.2, { Scale = 0.88 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	setFrameTransparency(stage, 1, 0.16)
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
