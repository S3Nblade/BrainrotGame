--!nonstrict
-- Lightweight 3D part-based egg reward roll.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local RevealAssets = require(script.Parent:WaitForChild("NPCRevealAssets"))
local BrainrotConfig = nil

do
	local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = sharedFolder and sharedFolder:FindFirstChild("BrainrotConfig")
	if configModule and configModule:IsA("ModuleScript") then
		local ok, result = pcall(require, configModule)
		if ok and type(result) == "table" then
			BrainrotConfig = result
		end
	end
end

local RevealNPC = {}

local DISPLAY_ORDER = 1400
local QUEUE_LIMIT = 4
local MAX_ROLL_CANDIDATES = 8
local FONT_BOLD = Enum.Font.GothamBold
local FONT_BLACK = Enum.Font.GothamBlack

local queue = {}
local playing = false
local activeGui = nil
local activeBlur = nil
local activeColor = nil
local soundLastPlayed = {}

local RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
	Huge = 7,
	Divine = 7,
	Celestial = 8,
	Godly = 9,
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(234, 240, 248),
	Uncommon = Color3.fromRGB(111, 236, 135),
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

local SYNTHETIC_ROLL_NAMES = {
	"Blocky Brainrot",
	"Tiny Brainrot",
	"Round Brainrot",
	"Tall Brainrot",
	"Spark Brainrot",
	"Chunky Brainrot",
	"Glow Brainrot",
	"Zippy Brainrot",
}

local STARTER_STYLES = {
	WobbleNugget = "nugget",
	GoofyCone = "cone",
	TinyBloop = "blob",
	SneakyPickle = "pickle",
	DizzyDonut = "donut",
	BananaGoblin = "banana",
	ShyToaster = "toaster",
	TurboMeatball = "meatball",
	GlitchyCapybara = "capybara",
	BubbleLizard = "lizard",
	GoldenSpaghettiKing = "spaghetti",
	CosmicBrainFrog = "frog",
}

local function rarityColor(rarity)
	return RARITY_COLORS[tostring(rarity or "Common")] or RARITY_COLORS.Common
end

local function getConfigEntry(configId, modelName)
	if type(BrainrotConfig) ~= "table" then
		return nil
	end

	if configId and BrainrotConfig.GetById then
		local entry = BrainrotConfig.GetById(tostring(configId))
		if entry then
			return entry
		end
	end

	if modelName and BrainrotConfig.GetByModelName then
		local entry = BrainrotConfig.GetByModelName(tostring(modelName))
		if entry then
			return entry
		end
	end

	return nil
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

local function getSoundId(name)
	local sounds = type(RevealAssets) == "table" and RevealAssets.Sounds or nil
	return cleanAssetId(sounds and sounds[name])
end

local function getSoundVolume(name)
	local volumes = type(RevealAssets) == "table" and RevealAssets.Volumes or nil
	local value = volumes and tonumber(volumes[name])
	return value or 0.45
end

local function playSound(name, minInterval)
	local soundId = getSoundId(name)
	if not soundId then
		return
	end

	local now = os.clock()
	local last = soundLastPlayed[name] or 0
	if now - last < (minInterval or 0.04) then
		return
	end
	soundLastPlayed[name] = now

	local sound = Instance.new("Sound")
	sound.Name = "NPCReveal_" .. tostring(name)
	sound.SoundId = soundId
	sound.Volume = getSoundVolume(name)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = SoundService
	sound:Play()

	sound.Ended:Connect(function()
		sound:Destroy()
	end)

	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function rarityOrder(rarity)
	return RARITY_ORDER[tostring(rarity or "Common")] or 1
end

local function shakeCamera(strength, duration)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	strength = tonumber(strength) or 0.06
	duration = tonumber(duration) or 0.28

	local started = os.clock()
	local seed = math.floor(started * 1000) % 10000
	local connection = nil
	connection = RunService.RenderStepped:Connect(function()
		if not camera or not camera.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local elapsed = os.clock() - started
		if elapsed >= duration then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local fade = 1 - (elapsed / duration)
		local x = math.noise(seed, elapsed * 28, 0) * strength * fade
		local y = math.noise(seed, 0, elapsed * 28) * strength * fade
		camera.CFrame = camera.CFrame * CFrame.new(x, y, 0)
	end)
end

local function hashText(text)
	text = tostring(text or "")
	local hash = 0
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 100000
	end
	return hash
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
	if not label then
		return
	end

	tween(label, duration or 0.18, { TextTransparency = visible and 0 or 1 })
	local textStroke = label:FindFirstChildOfClass("UIStroke")
	if textStroke then
		tween(textStroke, duration or 0.18, { Transparency = visible and 0.08 or 1 })
	end
end

local function glow(parent, name, color, position, size, zIndex)
	local g = makeFrame(parent, name, position, size, color, zIndex, UDim.new(1, 0))
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(0.5, 0.42),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = g
	return g
end

local function normalizeCandidate(entry, index, fallbackRarity)
	local name = "Mystery NPC"
	local rarity = fallbackRarity or "Common"
	local id = nil
	local mps = nil
	local mutation = nil
	local configId = nil
	local modelName = nil
	local showcaseScale = nil

	if type(entry) == "table" then
		configId = entry.configId or entry.ConfigId or entry.BrainrotConfigId or entry.brainrotConfigId
		modelName = entry.modelName or entry.ModelName or entry.BrainrotModelName or entry.brainrotModelName
		name = entry.displayName
			or entry.DisplayName
			or entry.name
			or entry.Name
			or entry.ResultName
			or configId
			or entry.id
			or entry.Id
			or name
		rarity = entry.rarity or entry.Rarity or entry.selectedRarity or fallbackRarity or rarity
		id = entry.id or entry.Id or configId or modelName or entry.TemplateName or entry.templateName or name
		mps = tonumber(entry.mps or entry.MPS or entry.CashPerSecond)
		mutation = entry.mutation or entry.Mutation or entry.mutationDisplayName or entry.MutationDisplayName
		showcaseScale = tonumber(entry.showcaseScale or entry.ShowcaseScale)
	elseif entry ~= nil then
		name = tostring(entry)
		id = name
	end

	local configEntry = getConfigEntry(configId or id, modelName)
	if configEntry then
		configId = configId or configEntry.Id
		modelName = modelName or configEntry.ModelName
		name = tostring(configEntry.DisplayName or name)
		rarity = tostring(configEntry.Rarity or rarity)
		mps = mps or tonumber(configEntry.CashPerSecond)
		showcaseScale = showcaseScale or tonumber(configEntry.ShowcaseScale)
	end

	name = tostring(name or ("Mystery NPC " .. tostring(index or 1)))
	rarity = tostring(rarity or "Common")

	return {
		id = tostring(id or name .. "_" .. tostring(index or 1)),
		configId = configId and tostring(configId) or nil,
		modelName = modelName and tostring(modelName) or nil,
		name = name,
		displayName = name,
		rarity = rarity,
		mps = mps,
		mutation = mutation and tostring(mutation) or nil,
		showcaseScale = showcaseScale or 1,
	}
end

local function appendCandidateList(target, source, fallbackRarity)
	if type(source) ~= "table" then
		return
	end

	if #source > 0 then
		for index, entry in ipairs(source) do
			if #target >= MAX_ROLL_CANDIDATES then
				return
			end
			table.insert(target, normalizeCandidate(entry, index, fallbackRarity))
		end
	else
		local index = 0
		for _, entry in pairs(source) do
			if #target >= MAX_ROLL_CANDIDATES then
				return
			end
			index += 1
			table.insert(target, normalizeCandidate(entry, index, fallbackRarity))
		end
	end
end

local function sameCandidate(a, b)
	if not a or not b then
		return false
	end
	return tostring(a.id) == tostring(b.id) or tostring(a.displayName) == tostring(b.displayName)
end

local function buildRollPool(payload, selected)
	local pool = {}
	payload = type(payload) == "table" and payload or {}

	appendCandidateList(pool, payload.possibleNPCs or payload.PossibleNPCs or payload.rollPool or payload.RollPool, selected.rarity)
	appendCandidateList(pool, payload.candidates or payload.Candidates, selected.rarity)

	for index, name in ipairs(SYNTHETIC_ROLL_NAMES) do
		if #pool >= 6 then
			break
		end
		table.insert(pool, {
			id = "synthetic_" .. tostring(index),
			name = name,
			displayName = name,
			rarity = selected.rarity,
			mps = nil,
			mutation = nil,
		})
	end

	local filtered = {}
	for _, candidate in ipairs(pool) do
		if not sameCandidate(candidate, selected) then
			table.insert(filtered, candidate)
		end
	end

	if #filtered == 0 then
		table.insert(filtered, {
			id = "synthetic_backup",
			name = "Mystery Brainrot",
			displayName = "Mystery Brainrot",
			rarity = selected.rarity,
		})
	end

	return filtered
end

local function normalizePayload(payload)
	payload = type(payload) == "table" and payload or {}
	local selectedPayload = type(payload.selectedNPC) == "table" and payload.selectedNPC or {}
	local rarity = payload.rarity or payload.Rarity or payload.selectedRarity or selectedPayload.rarity or selectedPayload.Rarity or "Common"
	local name = payload.npcName
		or payload.ResultName
		or selectedPayload.displayName
		or selectedPayload.DisplayName
		or selectedPayload.name
		or selectedPayload.Name
		or "Mystery NPC"
	local mutation = payload.mutation
		or payload.Mutation
		or payload.mutationName
		or payload.MutationName
		or payload.MutationDisplayName
		or selectedPayload.mutation
		or selectedPayload.Mutation
		or selectedPayload.mutationDisplayName
		or "Normal"

	local selected = normalizeCandidate({
		id = selectedPayload.id or selectedPayload.Id or payload.BrainrotConfigId or selectedPayload.BrainrotConfigId or payload.ResultName or name,
		configId = selectedPayload.configId or selectedPayload.ConfigId or selectedPayload.BrainrotConfigId or payload.BrainrotConfigId,
		modelName = selectedPayload.modelName or selectedPayload.ModelName or payload.ModelName or payload.BrainrotModelName,
		displayName = name,
		rarity = rarity,
		mps = payload.MPS or payload.CashPerSecond or selectedPayload.mps or selectedPayload.MPS,
		mutation = mutation,
		showcaseScale = payload.ShowcaseScale or selectedPayload.showcaseScale or selectedPayload.ShowcaseScale,
	}, 0, rarity)

	local data = {
		revealId = tostring(payload.revealId or payload.RevealId or payload.EggId or name .. "_" .. tostring(os.clock())),
		npcName = tostring(name),
		rarity = tostring(rarity),
		mutation = tostring(mutation),
		eggType = tostring(payload.eggType or payload.EggName or payload.eggName or "Egg"),
		npcImage = cleanAssetId(payload.npcImage or payload.NPCImage or selectedPayload.image or selectedPayload.Image or selectedPayload.icon or selectedPayload.Icon),
		mps = tonumber(payload.MPS or payload.CashPerSecond or selectedPayload.mps or selectedPayload.MPS),
		isNew = payload.isNew == true or payload.IsNew == true or payload.New == true or payload.FirstTime == true,
		selected = selected,
	}

	data.rollPool = buildRollPool(payload, selected)
	return data
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

local function candidateColor(candidate, index)
	local base = rarityColor(candidate and candidate.rarity)
	local hash = hashText((candidate and candidate.id or "") .. ":" .. tostring(index or 0))
	local hue = ((hash % 360) / 360)
	local variant = Color3.fromHSV(hue, 0.68, 1)
	return variant:Lerp(base, 0.42)
end

local function addNpcPart(model, name, size, cframe, color, shape, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Size = size
	if shape then
		part.Shape = shape
	end
	part.CFrame = cframe
	part.Parent = model
	return part
end

local function sanitizeModelName(name)
	name = tostring(name or "RolledNPC")
	return string.gsub(name, "[^%w_]", "_")
end

local function candidateStyle(candidate)
	local configId = candidate and candidate.configId
	if configId and STARTER_STYLES[tostring(configId)] then
		return STARTER_STYLES[tostring(configId)]
	end

	local modelName = tostring(candidate and candidate.modelName or "")
	for id, style in pairs(STARTER_STYLES) do
		if string.find(modelName, id, 1, true) then
			return style
		end
	end

	return nil
end

local function createPartNpc(world, candidate, index, isFinal)
	local model = Instance.new("Model")
	model.Name = sanitizeModelName(candidate.displayName or candidate.name)
	model.Parent = world

	local base = candidateColor(candidate, index)
	local accent = rarityColor(candidate.rarity):Lerp(Color3.fromRGB(255, 255, 255), isFinal and 0.2 or 0.42)
	local dark = base:Lerp(Color3.fromRGB(8, 10, 18), 0.42)
	local hash = hashText(candidate.id .. ":" .. candidate.displayName)
	local style = candidateStyle(candidate)
	local heightBoost = ((hash % 4) - 1) * 0.08
	local widthBoost = (((math.floor(hash / 7)) % 4) - 1) * 0.06
	local rootScale = math.clamp(tonumber(candidate.showcaseScale) or 1, 0.75, 1.45)
	local bodyShape = (style == "nugget" or style == "blob" or style == "meatball" or style == "frog" or style == "capybara" or style == "lizard") and Enum.PartType.Ball or Enum.PartType.Block

	local body = addNpcPart(
		model,
		"Body",
		Vector3.new(1.16 + widthBoost, 1.34 + heightBoost, style == "pickle" and 0.78 or 0.66),
		CFrame.new(0, 1.45 + heightBoost * 0.4, 0),
		base,
		bodyShape,
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = body

	if style == "cone" or style == "banana" then
		local top = addNpcPart(model, "PointTop", Vector3.new(0.62, 0.95, 0.62), CFrame.new(0, 2.42 + heightBoost, 0), base:Lerp(Color3.fromRGB(255, 255, 255), 0.2), Enum.PartType.Ball)
		top.Size = Vector3.new(style == "banana" and 0.48 or 0.68, 0.96, style == "banana" and 0.48 or 0.68)
	elseif style == "donut" then
		addNpcPart(model, "DonutCore", Vector3.new(0.72, 0.72, 0.18), CFrame.new(0, 2.42 + heightBoost, -0.08), accent, Enum.PartType.Cylinder, Enum.Material.Neon)
	else
		addNpcPart(
			model,
			"Head",
			Vector3.new(style == "toaster" and 1.1 or 0.94, style == "toaster" and 0.72 or 0.94, 0.94),
			CFrame.new(0, 2.47 + heightBoost, 0),
			base:Lerp(Color3.fromRGB(255, 255, 255), 0.18),
			style == "toaster" and Enum.PartType.Block or Enum.PartType.Ball,
			Enum.Material.SmoothPlastic
		)
	end
	addNpcPart(model, "LeftArm", Vector3.new(0.34, 1.02, 0.34), CFrame.new(-0.84 - widthBoost, 1.48, 0), accent, Enum.PartType.Block)
	addNpcPart(model, "RightArm", Vector3.new(0.34, 1.02, 0.34), CFrame.new(0.84 + widthBoost, 1.48, 0), accent, Enum.PartType.Block)
	addNpcPart(model, "LeftLeg", Vector3.new(0.42, 0.92, 0.42), CFrame.new(-0.32, 0.38, 0), dark, Enum.PartType.Block)
	addNpcPart(model, "RightLeg", Vector3.new(0.42, 0.92, 0.42), CFrame.new(0.32, 0.38, 0), dark, Enum.PartType.Block)
	addNpcPart(model, "LeftEye", Vector3.new(0.12, 0.12, 0.04), CFrame.new(-0.18, 2.55 + heightBoost, -0.44), Color3.fromRGB(8, 10, 18), Enum.PartType.Ball)
	addNpcPart(model, "RightEye", Vector3.new(0.12, 0.12, 0.04), CFrame.new(0.18, 2.55 + heightBoost, -0.44), Color3.fromRGB(8, 10, 18), Enum.PartType.Ball)

	if style == "spaghetti" then
		for i = 1, 5 do
			addNpcPart(model, "Noodle_" .. i, Vector3.new(0.12, 0.58, 0.12), CFrame.new((i - 3) * 0.16, 2.96 + heightBoost, -0.02), Color3.fromRGB(255, 222, 88), Enum.PartType.Cylinder, Enum.Material.Neon)
		end
		addNpcPart(model, "Crown", Vector3.new(0.86, 0.18, 0.76), CFrame.new(0, 3.05 + heightBoost, 0), accent, Enum.PartType.Block, Enum.Material.Neon)
	elseif style == "lizard" then
		addNpcPart(model, "Tail", Vector3.new(0.28, 0.34, 0.96), CFrame.new(0, 1.0, 0.82), accent, Enum.PartType.Block)
	elseif style == "capybara" then
		addNpcPart(model, "Snout", Vector3.new(0.46, 0.28, 0.22), CFrame.new(0, 2.33 + heightBoost, -0.52), accent, Enum.PartType.Block)
	elseif style == "frog" then
		addNpcPart(model, "BrainDome", Vector3.new(0.72, 0.32, 0.62), CFrame.new(0, 2.96 + heightBoost, 0), accent, Enum.PartType.Ball, Enum.Material.Neon)
	elseif style == "toaster" then
		addNpcPart(model, "Toast", Vector3.new(0.76, 0.18, 0.42), CFrame.new(0, 3.02 + heightBoost, 0), accent, Enum.PartType.Block)
	else
		local variant = hash % 4
		if variant == 0 then
			addNpcPart(model, "Crown", Vector3.new(0.86, 0.18, 0.76), CFrame.new(0, 3.05 + heightBoost, 0), accent, Enum.PartType.Block, Enum.Material.Neon)
		elseif variant == 1 then
			addNpcPart(model, "TopOrb", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 3.08 + heightBoost, 0), accent, Enum.PartType.Ball, Enum.Material.Neon)
		elseif variant == 2 then
			addNpcPart(model, "BellyCore", Vector3.new(0.42, 0.42, 0.1), CFrame.new(0, 1.56, -0.36), accent, Enum.PartType.Ball, Enum.Material.Neon)
		else
			addNpcPart(model, "Backpack", Vector3.new(0.86, 0.98, 0.24), CFrame.new(0, 1.45, 0.48), accent:Lerp(Color3.fromRGB(8, 10, 18), 0.25), Enum.PartType.Block)
		end
	end

	if style == "banana" then
		model:PivotTo(CFrame.new(0, -0.55, 0) * CFrame.Angles(0, 0, math.rad(-8)))
	else
		model:PivotTo(CFrame.new(0, -0.55, 0))
	end
	model:ScaleTo(rootScale)
	return model
end

local function setModelTransparency(model, transparency)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = transparency
		elseif descendant:IsA("Decal") then
			descendant.Transparency = transparency
		end
	end
end

local function tweenModelTransparency(model, duration, transparency)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			tween(descendant, duration, { Transparency = transparency })
		elseif descendant:IsA("Decal") then
			tween(descendant, duration, { Transparency = transparency })
		end
	end
end

local function tweenModelYaw(model, duration, startYaw, endYaw)
	local yawValue = Instance.new("NumberValue")
	yawValue.Value = startYaw
	local basePivot = CFrame.new(0, -0.55, 0)
	local connection = yawValue:GetPropertyChangedSignal("Value"):Connect(function()
		if model and model.Parent then
			model:PivotTo(basePivot * CFrame.Angles(0, yawValue.Value, 0))
		end
	end)

	local tw = tween(yawValue, duration, { Value = endYaw }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	tw.Completed:Connect(function()
		connection:Disconnect()
		yawValue:Destroy()
	end)
	return tw
end

local function createRollViewport(parent, color)
	local holder = Instance.new("Frame")
	holder.Name = "PartNpcRollStage"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromScale(0.5, 0.47)
	holder.Size = UDim2.fromScale(0.9, 0.64)
	holder.ZIndex = 70
	holder.Parent = parent

	local holderScale = scale(holder, 0.1)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "NpcViewport"
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Position = UDim2.fromScale(0.5, 0.5)
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = color:Lerp(Color3.fromRGB(255, 255, 255), 0.5)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.LightDirection = Vector3.new(-0.25, -1, -0.35)
	viewport.ZIndex = 72
	viewport.Parent = holder

	local camera = Instance.new("Camera")
	camera.Name = "NpcRollCamera"
	camera.CFrame = CFrame.new(Vector3.new(0, 2.0, 7.6), Vector3.new(0, 1.55, 0))
	camera.FieldOfView = 39
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local world = Instance.new("WorldModel")
	world.Name = "NpcRollWorld"
	world.Parent = viewport

	return {
		holder = holder,
		scale = holderScale,
		viewport = viewport,
		world = world,
		camera = camera,
	}
end

local function createRings(parent, color)
	local rings = {}
	for i = 1, 3 do
		local ring = makeFrame(parent, "EnergyRing_" .. i, UDim2.fromScale(0.5, 0.48), UDim2.fromOffset(170 + i * 66, 170 + i * 66), color, 12 + i, UDim.new(1, 0))
		local ringStroke = stroke(ring, i % 2 == 0 and Color3.fromRGB(255, 255, 255) or color, i == 1 and 3 or 2, 1)
		table.insert(rings, { ring = ring, stroke = ringStroke })
	end
	return rings
end

local function createParticles(parent, color)
	local particles = {}
	for i = 1, 18 do
		local size = 6 + (i % 4) * 3
		local part = makeFrame(parent, "RollSpark_" .. i, UDim2.fromScale(0.5, 0.48), UDim2.fromOffset(size, size), i % 4 == 0 and Color3.fromRGB(255, 255, 255) or color, 82, UDim.new(1, 0))
		table.insert(particles, part)
	end
	return particles
end

local function burstParticles(particles)
	for i, part in ipairs(particles) do
		local angle = math.rad((i / #particles) * 360)
		local distance = 116 + (i % 5) * 22
		local x = math.cos(angle) * distance
		local y = math.sin(angle) * distance * 0.72
		local partSize = part.AbsoluteSize
		part.BackgroundTransparency = 0.08
		tween(part, 0.4 + (i % 4) * 0.035, {
			Position = UDim2.new(0.5, x, 0.48, y),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(partSize.X + 12, partSize.Y + 12),
		}, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end
end

local function playCandidate(stage, candidate, index, holdTime, isFinal)
	stage.world:ClearAllChildren()

	if isFinal then
		playSound("reveal_final_pop", 0.2)
	else
		playSound("reveal_tick", 0.055)
	end

	local model = createPartNpc(stage.world, candidate, index, isFinal)
	setModelTransparency(model, 1)
	stage.scale.Scale = 0.08
	stage.holder.Rotation = isFinal and 0 or ((index % 2 == 0) and -3 or 3)

	tweenModelTransparency(model, 0.11, 0)
	tween(stage.holder, 0.11, { Rotation = 0 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	tweenModelYaw(model, isFinal and 0.5 or 0.22, math.rad(-22), isFinal and math.rad(360) or math.rad(36))
	waitTween(stage.scale, isFinal and 0.3 or 0.14, { Scale = isFinal and 1 or 0.92 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.wait(holdTime or 0.05)

	if isFinal then
		waitTween(stage.scale, 0.18, { Scale = 0.96 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		waitTween(stage.scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		return model
	end

	tweenModelTransparency(model, 0.1, 1)
	waitTween(stage.scale, 0.1, { Scale = 0.08 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	model:Destroy()
	return nil
end

local function chooseRollCandidate(data, index)
	local pool = data.rollPool
	local seed = hashText(data.revealId)
	local candidate = pool[((seed + index - 1) % #pool) + 1]

	if sameCandidate(candidate, data.selected) and #pool > 1 then
		candidate = pool[((seed + index) % #pool) + 1]
	end

	return candidate
end

local function rewardText(data)
	if data.mutation == "Normal" then
		return data.npcName
	end
	return data.mutation .. " " .. data.npcName
end

local function playRollSequence(stage, data)
	local rollCount = math.clamp(#data.rollPool + 2, 6, 9)

	for index = 1, rollCount do
		if index == math.ceil(rollCount * 0.62) then
			playSound("reveal_speedup", 0.25)
		end

		local candidate = chooseRollCandidate(data, index)
		local hold = math.max(0.035, 0.11 - index * 0.008)
		playCandidate(stage, candidate, index, hold, false)
		task.wait(math.max(0.015, 0.055 - index * 0.004))
	end

	return playCandidate(stage, data.selected, rollCount + 1, 0.12, true)
end

local function playReveal(rawPayload)
	local data = normalizePayload(rawPayload)
	local color = rarityColor(data.rarity)
	local playerGui = player:WaitForChild("PlayerGui")

	destroyActive()
	playSound("capture_success", 0.25)

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
		ColorSequenceKeypoint.new(0.48, color:Lerp(Color3.fromRGB(20, 25, 40), 0.58)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 20)),
	})
	overlayGradient.Rotation = 24
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
	stageConstraint.MinSize = Vector2.new(320, 420)
	stageConstraint.MaxSize = Vector2.new(560, 660)
	stageConstraint.Parent = stage

	local floorGlow = glow(stage, "FloorGlow", color, UDim2.fromScale(0.5, 0.74), UDim2.fromOffset(380, 92), 11)
	local coreGlow = glow(stage, "CoreGlow", color, UDim2.fromScale(0.5, 0.45), UDim2.fromOffset(300, 300), 11)
	local rings = createRings(stage, color)
	local particles = createParticles(stage, color)
	local rollStage = createRollViewport(stage, color)

	local eggName = makeText(stage, "EggName", data.eggType, UDim2.fromScale(0.2, 0.1), UDim2.fromScale(0.6, 0.055), color:Lerp(Color3.fromRGB(255, 255, 255), 0.18), 18, 95, FONT_BOLD)
	local rewardName = makeText(stage, "RewardName", rewardText(data), UDim2.fromScale(0.06, 0.78), UDim2.fromScale(0.88, 0.1), Color3.fromRGB(255, 255, 255), 34, 102, FONT_BLACK)
	local rarityLabel = makeText(stage, "RewardRarity", string.upper(data.rarity), UDim2.fromScale(0.28, 0.875), UDim2.fromScale(0.44, 0.052), color, 18, 102, FONT_BLACK)
	local newLabel = nil
	if data.isNew then
		newLabel = makeText(stage, "NewDiscovery", "NEW!", UDim2.fromScale(0.36, 0.69), UDim2.fromScale(0.28, 0.065), Color3.fromRGB(255, 239, 80), 24, 104, FONT_BLACK)
	end
	local valueLabel = nil
	if data.mps then
		valueLabel = makeText(stage, "RewardValue", "+" .. tostring(math.floor(data.mps)) .. "/s", UDim2.fromScale(0.34, 0.925), UDim2.fromScale(0.32, 0.04), Color3.fromRGB(255, 246, 182), 16, 102, FONT_BOLD)
	end
	local continueLabel = makeText(stage, "ContinueHint", "Tap to continue", UDim2.fromScale(0.32, 0.955), UDim2.fromScale(0.36, 0.035), Color3.fromRGB(255, 255, 255), 14, 102, FONT_BOLD)

	local flash = Instance.new("Frame")
	flash.Name = "WhiteFlash"
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 200
	flash.Parent = gui

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseHitbox"
	closeButton.BackgroundTransparency = 1
	closeButton.Text = ""
	closeButton.Size = UDim2.fromScale(1, 1)
	closeButton.Visible = false
	closeButton.ZIndex = 250
	closeButton.Parent = gui

	tween(overlay, 0.22, { BackgroundTransparency = 0.1 })
	tween(blur, 0.22, { Size = 13 })
	tween(colorFx, 0.22, { Contrast = 0.11, Saturation = 0.08, TintColor = color:Lerp(Color3.fromRGB(255, 255, 255), 0.74) })
	tween(stageScale, 0.26, { Scale = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	tween(floorGlow, 0.22, { BackgroundTransparency = 0.48 })
	tween(coreGlow, 0.22, { BackgroundTransparency = 0.34, Size = UDim2.fromOffset(360, 360) })
	fadeText(eggName, true, 0.16)

	for _, item in ipairs(rings) do
		tween(item.stroke, 0.16, { Transparency = 0.28 })
		tween(item.ring, 1.4, { Rotation = item.ring.Rotation + 180 }, Enum.EasingStyle.Linear)
	end

	playRollSequence(rollStage, data)

	local order = rarityOrder(data.rarity)
	if order >= rarityOrder("Rare") then
		playSound("reveal_rare", 0.35)
		shakeCamera(order >= rarityOrder("Legendary") and 0.11 or 0.055, order >= rarityOrder("Legendary") and 0.42 or 0.24)
	end
	if order >= rarityOrder("Legendary") then
		playSound("reveal_legendary", 0.35)
	end

	waitTween(flash, 0.06, { BackgroundTransparency = 0.12 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(flash, 0.2, { BackgroundTransparency = 1 })
	burstParticles(particles)
	tween(coreGlow, 0.28, { BackgroundTransparency = 0.2, Size = UDim2.fromOffset(420, 420) })
	tween(floorGlow, 0.28, { BackgroundTransparency = 0.34, Size = UDim2.fromOffset(430, 112) })
	fadeText(eggName, false, 0.12)
	fadeText(rewardName, true, 0.16)
	fadeText(rarityLabel, true, 0.16)
	fadeText(newLabel, true, 0.16)
	fadeText(valueLabel, true, 0.16)

	for _, item in ipairs(rings) do
		tween(item.ring, 1.35, { Rotation = item.ring.Rotation + 220 }, Enum.EasingStyle.Linear)
	end

	task.wait(0.35)
	fadeText(continueLabel, true, 0.16)
	closeButton.Visible = true

	local closeRequested = false
	local clickConn = closeButton.Activated:Connect(function()
		playSound("ui_click", 0.08)
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

	tween(overlay, 0.18, { BackgroundTransparency = 1 })
	tween(blur, 0.18, { Size = 0 })
	tween(colorFx, 0.18, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255, 255, 255) })
	tween(stageScale, 0.16, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(rollStage.scale, 0.14, { Scale = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, inst in ipairs(stage:GetDescendants()) do
		if inst:IsA("Frame") then
			tween(inst, 0.14, { BackgroundTransparency = 1 })
		elseif inst:IsA("TextLabel") then
			fadeText(inst, false, 0.12)
		elseif inst:IsA("UIStroke") then
			tween(inst, 0.12, { Transparency = 1 })
		elseif inst:IsA("BasePart") then
			tween(inst, 0.12, { Transparency = 1 })
		end
	end
	task.wait(0.2)
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
