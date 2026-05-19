--!nonstrict
-- StarterPlayerScripts/ZoneEggHatchClient.client.lua
-- Premium Kick Blox NPC reveal GUI. The server chooses and grants rewards;
-- this client only displays the server result.

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

local QUEUE_LIMIT = 5
local ROLL_STEPS = 30

local THEME = {
	Ink = Color3.fromRGB(19, 22, 38),
	InkSoft = Color3.fromRGB(45, 54, 84),
	Cream = Color3.fromRGB(255, 247, 216),
	White = Color3.fromRGB(255, 255, 255),
	PanelTop = Color3.fromRGB(255, 235, 120),
	PanelBottom = Color3.fromRGB(255, 142, 68),
	Blue = Color3.fromRGB(66, 183, 255),
	Pink = Color3.fromRGB(255, 96, 178),
	Green = Color3.fromRGB(92, 235, 108),
}

local RARITY_PROFILES = {
	Common = {
		color = Color3.fromRGB(232, 238, 246),
		deep = Color3.fromRGB(122, 137, 158),
		glow = Color3.fromRGB(255, 255, 255),
		intensity = 1,
		confetti = 0,
	},
	Uncommon = {
		color = Color3.fromRGB(93, 232, 108),
		deep = Color3.fromRGB(33, 143, 67),
		glow = Color3.fromRGB(164, 255, 161),
		intensity = 1.08,
		confetti = 0,
	},
	Rare = {
		color = Color3.fromRGB(75, 170, 255),
		deep = Color3.fromRGB(31, 89, 214),
		glow = Color3.fromRGB(153, 218, 255),
		intensity = 1.18,
		confetti = 0,
	},
	Epic = {
		color = Color3.fromRGB(203, 91, 255),
		deep = Color3.fromRGB(104, 47, 197),
		glow = Color3.fromRGB(229, 168, 255),
		intensity = 1.35,
		confetti = 10,
	},
	Mythic = {
		color = Color3.fromRGB(255, 78, 164),
		deep = Color3.fromRGB(181, 38, 105),
		glow = Color3.fromRGB(255, 158, 208),
		intensity = 1.55,
		confetti = 16,
	},
	Legendary = {
		color = Color3.fromRGB(255, 205, 54),
		deep = Color3.fromRGB(223, 111, 30),
		glow = Color3.fromRGB(255, 236, 128),
		intensity = 1.8,
		confetti = 22,
	},
	Divine = {
		color = Color3.fromRGB(72, 238, 255),
		deep = Color3.fromRGB(31, 130, 212),
		glow = Color3.fromRGB(184, 250, 255),
		intensity = 2,
		confetti = 28,
	},
	Celestial = {
		color = Color3.fromRGB(170, 128, 255),
		deep = Color3.fromRGB(78, 58, 205),
		glow = Color3.fromRGB(218, 196, 255),
		intensity = 2.15,
		confetti = 32,
	},
	Godly = {
		color = Color3.fromRGB(255, 72, 78),
		deep = Color3.fromRGB(139, 22, 42),
		glow = Color3.fromRGB(255, 162, 140),
		intensity = 2.35,
		confetti = 38,
		cosmic = true,
	},
	Secret = {
		color = Color3.fromRGB(56, 255, 151),
		deep = Color3.fromRGB(32, 48, 60),
		glow = Color3.fromRGB(185, 255, 218),
		intensity = 2.55,
		confetti = 44,
		cosmic = true,
	},
}

local activeGui = nil
local playing = false
local queue = {}
local seenRevealIds = {}
local AssetIds = {}

local function loadAssetIds()
	local guiFolder = ReplicatedStorage:FindFirstChild("GUI")
	local revealAssets = guiFolder and guiFolder:FindFirstChild("NPCRevealAssets")
	local assetModule = revealAssets and revealAssets:FindFirstChild("AssetIds")

	if not assetModule or not assetModule:IsA("ModuleScript") then
		return {}
	end

	local ok, result = pcall(require, assetModule)
	if ok and type(result) == "table" then
		return result
	end

	warn("[NPCRevealRoll] Could not load NPCRevealAssets.AssetIds:", result)
	return {}
end

AssetIds = loadAssetIds()

local function getAssetId(key)
	local value = AssetIds[key]
	if type(value) ~= "string" then
		return nil
	end

	if value == "" or string.find(value, "PASTE_ID_HERE", 1, true) then
		return nil
	end

	if not string.find(value, "rbxassetid://", 1, true) then
		return nil
	end

	return value
end

local function createImageLayer(parent, name, assetKey, zIndex, transparency, color)
	local assetId = getAssetId(assetKey)
	if not assetId then
		return nil
	end

	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = assetId
	image.ImageTransparency = transparency or 0
	image.ImageColor3 = color or THEME.White
	image.ScaleType = Enum.ScaleType.Stretch
	image.Size = UDim2.fromScale(1, 1)
	image.Position = UDim2.fromScale(0, 0)
	image.ZIndex = zIndex or 1
	image.Parent = parent
	return image
end

local function getRarityProfile(rarity)
	return RARITY_PROFILES[tostring(rarity or "Common")] or RARITY_PROFILES.Common
end

local function playTween(instance, duration, props, style, direction)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
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

local function createStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or THEME.Ink
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function createGradient(parent, top, bottom, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom or top),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

local function createShadow(parent, radius, zIndex)
	local shadow = Instance.new("Frame")
	shadow.Name = "SoftShadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.72
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.new(0.5, 0, 0.5, 12)
	shadow.Size = UDim2.new(1, 18, 1, 18)
	shadow.ZIndex = zIndex or ((parent.ZIndex or 1) - 1)
	shadow.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 24)
	corner.Parent = shadow

	return shadow
end

local function createRoundedPanel(parent, name, top, bottom, radius, zIndex)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = top
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex or 1
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 22)
	corner.Parent = frame

	createStroke(frame, THEME.Ink, 3, 0)
	createGradient(frame, top, bottom or top, 90)

	return frame
end

local function createTextLabel(parent, name, text, size, position, maxTextSize, color, zIndex)
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

	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Ink
	stroke.Thickness = 2
	stroke.Transparency = 0.04
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxTextSize or 30
	constraint.MinTextSize = 9
	constraint.Parent = label

	return label
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
		return {
			id = tostring(entry.id or entry.Id or displayName),
			name = tostring(entry.name or entry.Name or displayName),
			displayName = displayName,
			rarity = tostring(entry.rarity or entry.Rarity or "Common"),
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

local function normalizeKey(value)
	return string.lower(tostring(value or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function selectedExistsInPool(selected, pool)
	local selectedId = normalizeKey(selected.id)
	local selectedName = normalizeKey(selected.displayName)

	for _, npc in ipairs(pool) do
		if normalizeKey(npc.id) == selectedId or normalizeKey(npc.displayName) == selectedName then
			return true
		end
	end

	return false
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
		id = payload.ResultName or payload.Name or payload.BrainrotName,
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

	if not selectedExistsInPool(selected, possible) then
		warn("[NPCRevealRoll] Selected NPC was not in possibleNPCs payload. Displaying server result anyway.")
		table.insert(possible, selected)
	end

	return {
		revealId = tostring(payload.revealId or payload.RevealId or payload.EggId or os.clock()),
		zoneName = tostring(payload.ZoneDisplayName or payload.ZoneName or selected.zoneName or "Zone"),
		possibleNPCs = possible,
		selectedNPC = selected,
		source = tostring(payload.revealSource or payload.Source or "Reward"),
	}
end

local function createPart(parent, name, size, cframe, color, shape, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = parent
	return part
end

local function createPreviewModel(npc, profile, shadowMode)
	local model = Instance.new("Model")
	model.Name = tostring(npc.displayName or "NPC") .. "_RevealPreview"

	local main = shadowMode and Color3.fromRGB(4, 6, 14) or profile.color
	local second = shadowMode and Color3.fromRGB(7, 9, 18) or profile.color:Lerp(THEME.White, 0.46)
	local accent = shadowMode and Color3.fromRGB(2, 3, 8) or profile.deep
	local material = shadowMode and Enum.Material.SmoothPlastic or Enum.Material.SmoothPlastic

	createPart(model, "Body", Vector3.new(1.55, 1.9, 0.95), CFrame.new(0, 0.25, 0), main, Enum.PartType.Ball, material)
	createPart(model, "Head", Vector3.new(1.35, 1.35, 1.35), CFrame.new(0, 1.58, 0), second, Enum.PartType.Ball, material)
	createPart(model, "LeftArm", Vector3.new(0.38, 1.08, 0.38), CFrame.new(-0.98, 0.3, 0) * CFrame.Angles(0, 0, math.rad(14)), accent, Enum.PartType.Cylinder, material)
	createPart(model, "RightArm", Vector3.new(0.38, 1.08, 0.38), CFrame.new(0.98, 0.3, 0) * CFrame.Angles(0, 0, math.rad(-14)), accent, Enum.PartType.Cylinder, material)
	createPart(model, "LeftFoot", Vector3.new(0.58, 0.25, 0.72), CFrame.new(-0.42, -0.86, -0.08), second, Enum.PartType.Ball, material)
	createPart(model, "RightFoot", Vector3.new(0.58, 0.25, 0.72), CFrame.new(0.42, -0.86, -0.08), second, Enum.PartType.Ball, material)

	if not shadowMode then
		createPart(model, "LeftEye", Vector3.new(0.2, 0.2, 0.05), CFrame.new(-0.28, 1.66, -0.62), THEME.White, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
		createPart(model, "RightEye", Vector3.new(0.2, 0.2, 0.05), CFrame.new(0.28, 1.66, -0.62), THEME.White, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
		createPart(model, "Smile", Vector3.new(0.46, 0.07, 0.05), CFrame.new(0, 1.34, -0.66), THEME.Ink, Enum.PartType.Block, Enum.Material.SmoothPlastic)

		local light = Instance.new("PointLight")
		light.Name = "RevealLight"
		light.Color = profile.glow
		light.Brightness = 1.6 + profile.intensity * 0.35
		light.Range = 10
		light.Parent = model:FindFirstChild("Body")
	end

	return model
end

local function clearWorldModel(worldModel)
	for _, child in ipairs(worldModel:GetChildren()) do
		child:Destroy()
	end
end

local function fitCameraToModel(camera, model)
	local cf, size = model:GetBoundingBox()
	local largest = math.max(size.X, size.Y, size.Z)
	local distance = math.max(5.5, largest * 2.65)
	local focus = cf.Position + Vector3.new(0, size.Y * 0.1, 0)
	camera.CFrame = CFrame.new(focus + Vector3.new(0, size.Y * 0.14, distance), focus)
end

local function createViewportNPC(parent, npc, profile, shadowMode, zIndex)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = shadowMode and "ShadowNPCViewport" or "NPCViewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = zIndex or 1
	viewport.LightColor = shadowMode and Color3.fromRGB(50, 56, 80) or THEME.White
	viewport.Ambient = shadowMode and Color3.fromRGB(0, 0, 0) or profile.glow
	viewport.Parent = parent

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "WorldModel"
	worldModel.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Name = "RevealCamera"
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model = createPreviewModel(npc, profile, shadowMode)
	model.Parent = worldModel
	fitCameraToModel(camera, model)

	return {
		viewport = viewport,
		world = worldModel,
		camera = camera,
		model = model,
	}
end

local function setViewportNPC(viewData, npc, profile, shadowMode)
	clearWorldModel(viewData.world)
	local model = createPreviewModel(npc, profile, shadowMode)
	model.Parent = viewData.world
	viewData.model = model
	viewData.viewport.Ambient = shadowMode and Color3.fromRGB(0, 0, 0) or profile.glow
	viewData.viewport.LightColor = shadowMode and Color3.fromRGB(50, 56, 80) or THEME.White
	fitCameraToModel(viewData.camera, model)
end

local function createShadowCard(parent, name, xScale, scaleValue, transparency)
	local wrapper = Instance.new("Frame")
	wrapper.Name = name
	wrapper.AnchorPoint = Vector2.new(0.5, 0.5)
	wrapper.BackgroundTransparency = 1
	wrapper.Position = UDim2.fromScale(xScale, 0.5)
	wrapper.Size = UDim2.fromScale(0.18, 0.88)
	wrapper.ZIndex = 30
	wrapper.Parent = parent

	local scaler = Instance.new("UIScale")
	scaler.Scale = scaleValue or 1
	scaler.Parent = wrapper

	local card = createRoundedPanel(wrapper, "Card", Color3.fromRGB(56, 66, 104), Color3.fromRGB(24, 30, 58), 22, 31)
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundTransparency = transparency or 0
	createShadow(card, 24, 30)

	local cardShadow = createImageLayer(wrapper, "AssetCardShadow", "NPCCardShadow", 29, 0, Color3.fromRGB(0, 0, 0))
	if cardShadow then
		cardShadow.AnchorPoint = Vector2.new(0.5, 0.5)
		cardShadow.Position = UDim2.fromScale(0.5, 0.54)
		cardShadow.Size = UDim2.fromScale(1.14, 1.12)
	end

	local cardBg = createImageLayer(card, "AssetCardBg", "NPCCardBg", 31, 0)
	if cardBg then
		card.BackgroundTransparency = 1
	end

	local cardOutline = createImageLayer(card, "AssetCardOutline", "NPCCardOutline", 39, 0)
	if cardOutline then
		cardOutline.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.Parent = card

	local glow = Instance.new("Frame")
	glow.Name = "CardGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.BackgroundColor3 = THEME.Blue
	glow.BackgroundTransparency = 0.73
	glow.BorderSizePixel = 0
	glow.Position = UDim2.fromScale(0.5, 0.43)
	glow.Size = UDim2.fromScale(0.72, 0.58)
	glow.ZIndex = 32
	glow.Parent = card
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	local viewportHolder = Instance.new("Frame")
	viewportHolder.Name = "ViewportHolder"
	viewportHolder.BackgroundTransparency = 1
	viewportHolder.Position = UDim2.fromScale(0.08, 0.08)
	viewportHolder.Size = UDim2.fromScale(0.84, 0.65)
	viewportHolder.ZIndex = 33
	viewportHolder.Parent = card

	local silhouetteOverlay = createImageLayer(card, "AssetSilhouetteOverlay", "SilhouetteOverlay", 40, 0)
	if silhouetteOverlay then
		silhouetteOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
		silhouetteOverlay.Position = UDim2.fromScale(0.5, 0.43)
		silhouetteOverlay.Size = UDim2.fromScale(0.72, 0.6)
		silhouetteOverlay.ImageColor3 = Color3.fromRGB(0, 0, 0)
		silhouetteOverlay.ImageTransparency = 0.08
	end

	local question = createTextLabel(card, "Question", "?", UDim2.fromScale(0.44, 0.32), UDim2.fromScale(0.28, 0.2), 42, THEME.Cream, 42)
	question.AnchorPoint = Vector2.new(0, 0)

	local questionImage = createImageLayer(card, "AssetQuestionMarkGlow", "QuestionMarkGlow", 43, 0)
	if questionImage then
		questionImage.AnchorPoint = Vector2.new(0.5, 0.5)
		questionImage.Position = UDim2.fromScale(0.5, 0.35)
		questionImage.Size = UDim2.fromScale(0.46, 0.32)
		question.TextTransparency = 1
		local stroke = question:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 1
		end
	end

	local nameLabel = createTextLabel(card, "Name", "???", UDim2.fromScale(0.92, 0.16), UDim2.fromScale(0.04, 0.76), 18, Color3.fromRGB(225, 233, 255), 36)
	local rarityLabel = createTextLabel(card, "Rarity", "???", UDim2.fromScale(0.92, 0.1), UDim2.fromScale(0.04, 0.9), 13, Color3.fromRGB(177, 194, 232), 36)

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 0.8
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = wrapper

	return {
		wrapper = wrapper,
		card = card,
		scale = scaler,
		glow = glow,
		viewportHolder = viewportHolder,
		question = question,
		questionImage = questionImage,
		silhouetteOverlay = silhouetteOverlay,
		cardOutline = cardOutline,
		nameLabel = nameLabel,
		rarityLabel = rarityLabel,
		viewData = nil,
	}
end

local function updateShadowCard(cardData, npc, revealed)
	local profile = getRarityProfile(npc.rarity)
	cardData.glow.BackgroundColor3 = profile.glow
	if cardData.cardOutline then
		cardData.cardOutline.ImageColor3 = profile.color
	end
	if cardData.silhouetteOverlay then
		cardData.silhouetteOverlay.Visible = not revealed
	end
	cardData.rarityLabel.TextColor3 = profile.color
	cardData.question.Text = revealed and "!" or "?"
	cardData.question.TextColor3 = revealed and profile.color or THEME.Cream
	if cardData.questionImage then
		cardData.questionImage.Visible = not revealed
		cardData.question.TextTransparency = not revealed and 1 or 0
		local stroke = cardData.question:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = not revealed and 1 or 0.04
		end
	end
	cardData.nameLabel.Text = revealed and npc.displayName or "???"
	cardData.rarityLabel.Text = revealed and ("[" .. string.upper(npc.rarity) .. "]") or string.upper(npc.rarity)

	if cardData.viewData then
		setViewportNPC(cardData.viewData, npc, profile, not revealed)
	else
		cardData.viewData = createViewportNPC(cardData.viewportHolder, npc, profile, not revealed, 34)
	end
end

local function createRarityRays(parent, profile)
	local rays = Instance.new("Frame")
	rays.Name = "RarityRays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.BackgroundTransparency = 1
	rays.Position = UDim2.fromScale(0.5, 0.54)
	rays.Size = UDim2.fromScale(1.25, 1.25)
	rays.ZIndex = 20
	rays.Parent = parent

	local burst = createImageLayer(rays, "AssetRevealBurst", "RevealBurst", 20, 0, profile.color)
	if burst then
		burst.AnchorPoint = Vector2.new(0.5, 0.5)
		burst.Position = UDim2.fromScale(0.5, 0.5)
		burst.Size = UDim2.fromScale(1.35, 1.35)
		burst.ImageTransparency = 0.04
		playTween(burst, 0.9, { Rotation = 42, ImageTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end

	local rayCount = math.floor(10 + profile.intensity * 5)
	for i = 1, rayCount do
		local ray = Instance.new("Frame")
		ray.Name = "Ray"
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.BackgroundColor3 = i % 2 == 0 and profile.color or profile.glow
		ray.BackgroundTransparency = 0.55
		ray.BorderSizePixel = 0
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(0.011, 0.58 + profile.intensity * 0.08)
		ray.Rotation = (360 / rayCount) * i
		ray.ZIndex = 21
		ray.Parent = rays
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ray
		playTween(ray, 0.72, { BackgroundTransparency = 1, Size = UDim2.fromScale(0.004, 0.72) })
	end

	playTween(rays, 0.9, { Rotation = 34 }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Debris:AddItem(rays, 1.1)
end

local function createSparkles(parent, profile, amount)
	local holder = Instance.new("Frame")
	holder.Name = "RevealSparkles"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 80
	holder.Parent = parent

	for i = 1, amount do
		local sparkleAssetKey = "Sparkle" .. tostring(((i - 1) % 3) + 1)
		local sparkle = createImageLayer(holder, "Sparkle", sparkleAssetKey, 81, 0, i % 3 == 0 and THEME.Cream or profile.color)
		local useImage = sparkle ~= nil

		if not sparkle then
			sparkle = Instance.new("Frame")
			sparkle.Name = "Sparkle"
			sparkle.BackgroundColor3 = i % 3 == 0 and THEME.Cream or profile.color
			sparkle.BorderSizePixel = 0
			sparkle.ZIndex = 81
			sparkle.Parent = holder

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = sparkle
		end

		sparkle.Name = "Sparkle"
		sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
		sparkle.Position = UDim2.fromScale(0.5, 0.49)
		sparkle.Size = UDim2.fromOffset(i % 2 == 0 and 11 or 8, i % 2 == 0 and 11 or 8)
		sparkle.Rotation = i * 19

		local angle = (math.pi * 2 / amount) * i
		local distance = 190 + (i % 6) * 26 + profile.intensity * 26
		local props = {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.49, math.sin(angle) * distance),
			Rotation = sparkle.Rotation + 180,
		}
		if useImage then
			props.ImageTransparency = 1
		else
			props.BackgroundTransparency = 1
		end
		playTween(sparkle, 0.78, props, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end

	Debris:AddItem(holder, 1.05)
end

local function createFinalViewport(parent, npc, profile)
	local holder = Instance.new("Frame")
	holder.Name = "FinalViewportHolder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.57)
	holder.Size = UDim2.fromScale(0.34, 0.44)
	holder.ZIndex = 70
	holder.Parent = parent

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = holder

	local data = createViewportNPC(holder, npc, profile, false, 72)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.35
	scale.Parent = holder
	playTween(scale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local rotating = true
	task.spawn(function()
		local started = os.clock()
		while rotating and holder.Parent and data.model and data.model.Parent do
			local elapsed = os.clock() - started
			data.model:PivotTo(CFrame.Angles(0, elapsed * 1.35, 0))
			task.wait(1 / 30)
		end
	end)

	return function()
		rotating = false
	end
end

local function cleanupReveal(state)
	if not state then
		return
	end

	if state.rotateCleanup then
		state.rotateCleanup()
	end

	for _, connection in ipairs(state.connections or {}) do
		if connection then
			connection:Disconnect()
		end
	end

	if state.gui and state.gui.Parent then
		state.gui:Destroy()
	end

	if state.blur and state.blur.Parent then
		state.blur:Destroy()
	end

	if activeGui == state.gui then
		activeGui = nil
	end
end

local function playRevealSequence(rawPayload)
	local payload = normalizePayload(rawPayload)
	local selected = payload.selectedNPC
	local profile = getRarityProfile(selected.rarity)
	local state = {
		connections = {},
	}

	if activeGui then
		activeGui:Destroy()
		activeGui = nil
	end

	local blur = Instance.new("BlurEffect")
	blur.Name = "KickBloxNPCRevealBlur"
	blur.Size = 0
	blur.Parent = Lighting
	state.blur = blur

	local gui = Instance.new("ScreenGui")
	gui.Name = "KickBloxNPCRevealGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9900
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	state.gui = gui
	activeGui = gui

	local overlay = Instance.new("Frame")
	overlay.Name = "DarkOverlay"
	overlay.BackgroundColor3 = Color3.fromRGB(7, 9, 18)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 1
	overlay.Parent = gui

	local vignette = createImageLayer(gui, "AssetDarkVignette", "DarkVignette", 2, 1, Color3.fromRGB(255, 255, 255))
	if vignette then
		vignette.Size = UDim2.fromScale(1, 1)
		playTween(vignette, 0.26, { ImageTransparency = 0.08 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	local ambientBurst = createImageLayer(gui, "AmbientRarityBurst", "RevealBurst", 3, 1, profile.color)
	if ambientBurst then
		ambientBurst.AnchorPoint = Vector2.new(0.5, 0.5)
		ambientBurst.Position = UDim2.fromScale(0.5, 0.56)
		ambientBurst.Size = UDim2.fromScale(1.18, 1.18)
		ambientBurst.ImageTransparency = 1
		playTween(ambientBurst, 0.42, { ImageTransparency = 0.36, Rotation = 8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	local stage = Instance.new("Frame")
	stage.Name = "RevealStage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromScale(1, 1)
	stage.BackgroundTransparency = 1
	stage.BorderSizePixel = 0
	stage.ZIndex = 10
	stage.Parent = gui
	stage.ClipsDescendants = false

	local panelShadow = createImageLayer(stage, "AssetPanelShadow", "RevealPanelShadow", 9, 0, Color3.fromRGB(0, 0, 0))
	if panelShadow then
		panelShadow.AnchorPoint = Vector2.new(0.5, 0.5)
		panelShadow.Position = UDim2.fromScale(0.5, 0.59)
		panelShadow.Size = UDim2.fromScale(0.95, 0.62)
		panelShadow.ImageTransparency = 0.18
	end

	local panelBg = createImageLayer(stage, "AssetPanelBg", "RevealPanelBg", 10, 0)
	if panelBg then
		panelBg.AnchorPoint = Vector2.new(0.5, 0.5)
		panelBg.Position = UDim2.fromScale(0.5, 0.58)
		panelBg.Size = UDim2.fromScale(0.78, 0.46)
		panelBg.ImageTransparency = 0.34
	end

	local stageScale = Instance.new("UIScale")
	stageScale.Scale = 0.92
	stageScale.Parent = stage

	local titleBanner = createImageLayer(stage, "AssetTitleBanner", "TitleBannerBg", 16, 0)
	if titleBanner then
		titleBanner.AnchorPoint = Vector2.new(0.5, 0.5)
		titleBanner.Position = UDim2.fromScale(0.5, 0.13)
		titleBanner.Size = UDim2.fromScale(0.5, 0.12)
	end

	local title = createTextLabel(stage, "Title", "WHO DID YOU GET?", UDim2.fromScale(0.86, 0.09), UDim2.fromScale(0.07, 0.075), 42, THEME.Cream, 18)
	local subtitle = createTextLabel(stage, "Subtitle", payload.zoneName .. " Reward", UDim2.fromScale(0.7, 0.045), UDim2.fromScale(0.15, 0.165), 20, Color3.fromRGB(232, 223, 255), 18)
	local bigRarity = createTextLabel(stage, "BigRarity", string.upper(selected.rarity), UDim2.fromScale(0.82, 0.17), UDim2.fromScale(0.09, 0.17), 72, profile.color, 76)
	bigRarity.TextTransparency = 1
	local bigStroke = bigRarity:FindFirstChildOfClass("UIStroke")
	if bigStroke then
		bigStroke.Transparency = 1
		bigStroke.Thickness = 5
	end

	local reel = Instance.new("Frame")
	reel.Name = "ShadowCarousel"
	reel.BackgroundTransparency = 1
	reel.Position = UDim2.fromScale(0.055, 0.39)
	reel.Size = UDim2.fromScale(0.89, 0.28)
	reel.ZIndex = 20
	reel.Parent = stage

	local cards = {
		createShadowCard(reel, "Card_1", 0.06, 0.82, 0.62),
		createShadowCard(reel, "Card_2", 0.22, 0.96, 0.38),
		createShadowCard(reel, "Card_3", 0.5, 1.26, 0.1),
		createShadowCard(reel, "Card_4", 0.78, 0.96, 0.38),
		createShadowCard(reel, "Card_5", 0.94, 0.82, 0.62),
	}

	local slots = {
		{ x = 0.06, scale = 0.82, alpha = 0.62, rot = -8 },
		{ x = 0.22, scale = 0.96, alpha = 0.38, rot = -4 },
		{ x = 0.5, scale = 1.26, alpha = 0.1, rot = 0 },
		{ x = 0.78, scale = 0.96, alpha = 0.38, rot = 4 },
		{ x = 0.94, scale = 0.82, alpha = 0.62, rot = 8 },
	}

	playTween(overlay, 0.26, { BackgroundTransparency = 0.18 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	playTween(blur, 0.28, { Size = 12 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	playTween(stageScale, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	playTween(stage, 0.32, { Rotation = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local possible = payload.possibleNPCs
	local rollIndex = 0

	for step = 1, ROLL_STEPS do
		rollIndex += 1
		local ratio = step / ROLL_STEPS

		for i, card in ipairs(cards) do
			local npc = possible[((rollIndex + i - 2) % #possible) + 1]
			updateShadowCard(card, npc, false)
			local slot = slots[i]
			playTween(card.wrapper, 0.08, {
				Position = UDim2.fromScale(slot.x, 0.5),
				Rotation = slot.rot,
			}, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
			playTween(card.scale, 0.08, { Scale = slot.scale }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			playTween(card.card, 0.08, { BackgroundTransparency = slot.alpha }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end

		local pulseScale = 1.14 + (1 - ratio) * 0.08
		playTween(cards[3].scale, 0.05, { Scale = pulseScale }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

		local shakePower = math.max(0, (1 - ratio) * 6 + profile.intensity * 0.9)
		stage.Position = UDim2.new(
			0.5,
			(math.random() * 2 - 1) * shakePower,
			0.5,
			(math.random() * 2 - 1) * shakePower
		)

		playSound(TICK_SOUND_ID, 0.16, 0.92 + ratio * 0.45)
		task.wait(0.027 + (ratio ^ 2.15) * 0.13)
	end

	stage.Position = UDim2.fromScale(0.5, 0.5)
	title.Text = "REVEALING..."

	for i, card in ipairs(cards) do
		if i == 3 then
			updateShadowCard(card, selected, false)
			playTween(card.scale, 0.2, { Scale = 1.28 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			playTween(card.glow, 0.2, { BackgroundTransparency = 0.48 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		else
			playTween(card.wrapper, 0.24, {
				Position = UDim2.fromScale(i < 3 and -0.08 or 1.08, 0.5),
				Rotation = i < 3 and -14 or 14,
			}, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
			playTween(card.card, 0.2, { BackgroundTransparency = 1 })
		end
	end

	task.wait(0.24)

	local spotlight = createImageLayer(stage, "AssetCenterSpotlight", "CenterSpotlight", 19, 1, profile.glow)
	if spotlight then
		spotlight.AnchorPoint = Vector2.new(0.5, 0.5)
		spotlight.Position = UDim2.fromScale(0.5, 0.56)
		spotlight.Size = UDim2.fromScale(0.12, 0.16)
		playTween(spotlight, 0.38, {
			Size = UDim2.fromScale(0.92, 0.92),
			ImageTransparency = 0.1,
		}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	for shake = 1, 8 do
		cards[3].wrapper.Position = UDim2.new(0.5, (math.random() * 2 - 1) * 5, 0.5, (math.random() * 2 - 1) * 3)
		task.wait(0.035)
	end
	cards[3].wrapper.Position = UDim2.fromScale(0.5, 0.5)

	createRarityRays(stage, profile)

	local rarityKey = "RarityGlowCommon"
	local rarity = tostring(selected.rarity or "Common")
	if rarity == "Rare" then
		rarityKey = "RarityGlowRare"
	elseif rarity == "Epic" then
		rarityKey = "RarityGlowEpic"
	elseif rarity == "Legendary" or rarity == "Divine" or rarity == "Celestial" then
		rarityKey = "RarityGlowLegendary"
	elseif rarity == "Mythic" then
		rarityKey = "RarityGlowMythic"
	elseif rarity == "Godly" or rarity == "Secret" then
		rarityKey = "RarityGlowSecret"
	end

	local rarityGlow = createImageLayer(stage, "AssetRarityGlow", rarityKey, 18, 1, Color3.fromRGB(255, 255, 255))
	if rarityGlow then
		rarityGlow.AnchorPoint = Vector2.new(0.5, 0.5)
		rarityGlow.Position = UDim2.fromScale(0.5, 0.56)
		rarityGlow.Size = UDim2.fromScale(0.2, 0.24)
		playTween(rarityGlow, 0.36, {
			Size = UDim2.fromScale(0.92, 0.92),
			ImageTransparency = 0.04,
		}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	local flash = Instance.new("Frame")
	flash.Name = "RevealFlash"
	flash.BackgroundColor3 = profile.color
	flash.BackgroundTransparency = 0.22
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 100
	flash.Parent = gui
	playTween(flash, 0.36, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Debris:AddItem(flash, 0.44)

	local flashImage = createImageLayer(gui, "AssetWhiteFlash", "WhiteFlash", 101, 0.12, profile.color)
	if flashImage then
		playTween(flashImage, 0.34, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Debris:AddItem(flashImage, 0.42)
	end

	playSound(FINAL_SOUND_ID, 0.55, 1)
	if profile.confetti > 0 then
		createSparkles(stage, profile, profile.confetti)
	else
		createSparkles(stage, profile, 10)
	end

	cards[3].wrapper.Visible = false
	state.rotateCleanup = createFinalViewport(stage, selected, profile)

	title.Text = "YOU GOT!"
	title.TextColor3 = THEME.White
	title.Position = UDim2.fromScale(0.07, 0.08)
	title.Size = UDim2.fromScale(0.86, 0.08)
	subtitle.TextTransparency = 1
	local subtitleStroke = subtitle:FindFirstChildOfClass("UIStroke")
	if subtitleStroke then
		subtitleStroke.Transparency = 1
	end
	playTween(bigRarity, 0.28, { TextTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	if bigStroke then
		playTween(bigStroke, 0.28, { Transparency = 0.02 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end

	local resultPanel = Instance.new("Frame")
	resultPanel.Name = "ResultTextStack"
	resultPanel.AnchorPoint = Vector2.new(0.5, 1)
	resultPanel.BackgroundTransparency = 1
	resultPanel.Position = UDim2.fromScale(0.5, 0.845)
	resultPanel.Size = UDim2.fromScale(0.82, 0.16)
	resultPanel.ZIndex = 70
	resultPanel.Parent = stage

	local resultScale = Instance.new("UIScale")
	resultScale.Scale = 0.76
	resultScale.Parent = resultPanel

	local npcNameLabel = createTextLabel(resultPanel, "NPCName", selected.displayName, UDim2.fromScale(0.96, 0.48), UDim2.fromScale(0.02, 0.02), 42, THEME.White, 73)

	local mutationText = selected.mutationDisplayName
	if mutationText == "" or mutationText == "nil" then
		mutationText = "Normal"
	end

	local detail = selected.rarity
	if selected.mps then
		detail ..= "  - $" .. formatNumber(selected.mps) .. "/s"
	end
	if mutationText ~= "" then
		detail ..= " - " .. mutationText
	end

	local detailLabel = createTextLabel(resultPanel, "Details", detail, UDim2.fromScale(0.96, 0.34), UDim2.fromScale(0.02, 0.56), 26, profile.color, 73)

	playTween(resultScale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	playTween(npcNameLabel, 0.28, { TextTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	playTween(detailLabel, 0.32, { TextTransparency = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local continue = Instance.new("TextButton")
	continue.Name = "Continue"
	continue.AnchorPoint = Vector2.new(0.5, 1)
	continue.BackgroundColor3 = THEME.Green
	continue.BackgroundTransparency = getAssetId("ContinueButtonBg") and 1 or 0
	continue.BorderSizePixel = 0
	continue.Position = UDim2.fromScale(0.5, 1.09)
	continue.Size = UDim2.fromScale(0.28, 0.085)
	continue.Font = FONT
	continue.Text = "CONTINUE"
	continue.TextColor3 = THEME.White
	continue.TextStrokeColor3 = THEME.Ink
	continue.TextStrokeTransparency = 0.05
	continue.TextScaled = true
	continue.ZIndex = 90
	continue.Parent = stage
	local continueCorner = Instance.new("UICorner")
	continueCorner.CornerRadius = UDim.new(1, 0)
	continueCorner.Parent = continue
	createStroke(continue, THEME.Ink, 3, 0)
	createGradient(continue, THEME.Green, Color3.fromRGB(32, 163, 71), 90)

	local buttonBg = createImageLayer(continue, "AssetContinueButtonBg", "ContinueButtonBg", 90, 0)
	if buttonBg then
		buttonBg.ZIndex = 89
		buttonBg.Size = UDim2.fromScale(1, 1)
	end

	local hoverGlow = createImageLayer(continue, "AssetContinueHoverGlow", "ContinueButtonHoverGlow", 89, 1, THEME.Green)
	if hoverGlow then
		hoverGlow.AnchorPoint = Vector2.new(0.5, 0.5)
		hoverGlow.Position = UDim2.fromScale(0.5, 0.5)
		hoverGlow.Size = UDim2.fromScale(1.2, 1.55)
	end

	local continueTextSize = Instance.new("UITextSizeConstraint")
	continueTextSize.MaxTextSize = 24
	continueTextSize.MinTextSize = 10
	continueTextSize.Parent = continue

	local closeRequested = false
	table.insert(state.connections, continue.Activated:Connect(function()
		closeRequested = true
	end))

	if hoverGlow then
		table.insert(state.connections, continue.MouseEnter:Connect(function()
			playTween(hoverGlow, 0.12, { ImageTransparency = 0.15 })
		end))
		table.insert(state.connections, continue.MouseLeave:Connect(function()
			playTween(hoverGlow, 0.16, { ImageTransparency = 1 })
		end))
		table.insert(state.connections, continue.MouseButton1Down:Connect(function()
			playTween(hoverGlow, 0.08, { ImageTransparency = 0.02 })
		end))
	end

	task.delay(0.2, function()
		if continue.Parent then
			playTween(continue, 0.22, { Position = UDim2.fromScale(0.5, 0.965) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end
	end)

	local waitStarted = os.clock()
	while not closeRequested and os.clock() - waitStarted < 2.8 do
		task.wait(0.05)
	end

	playTween(overlay, 0.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	playTween(blur, 0.2, { Size = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	playTween(stageScale, 0.2, { Scale = 0.86 }, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
	playTween(stage, 0.2, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.wait(0.22)

	cleanupReveal(state)
end

local function processQueue()
	if playing then
		return
	end

	playing = true
	while #queue > 0 do
		local payload = table.remove(queue, 1)
		local ok, err = pcall(playRevealSequence, payload)
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

print("[NPCRevealRoll] Loaded premium Kick Blox NPC reveal animation.")
