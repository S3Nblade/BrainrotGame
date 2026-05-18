--!nonstrict
-- StarterPlayerScripts/GoldenAnimatedAura.client.lua
-- Animated Golden mutation aura using a 4x4 flipbook particle texture.
-- This is real VFX-style movement, not a static BillboardGui image.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local AURA_FOLDER_NAME = "ClientGoldenAnimatedAura"
local PREFIX = "GoldenAnimatedAura_"

local FULL_DISTANCE = 150
local LOW_DISTANCE = 260
local UPDATE_EVERY = 0.25

local config = require(ReplicatedStorage:WaitForChild("VFX"):WaitForChild("AnimatedGoldenAuraConfig"))

local GOLDEN_FLIPBOOK = config.GoldenFlipbook
local AURA_RING = config.AuraRing
local SHARP_SPARK = config.SharpSpark

local GOLD = Color3.fromRGB(255, 220, 45)
local GOLD_DARK = Color3.fromRGB(255, 145, 25)
local GOLD_LIGHT = Color3.fromRGB(255, 255, 190)

local active = {}
local watched = {}
local lastUpdate = 0

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function isGoldenMutation(npc)
	local mutation =
		npc:GetAttribute("Mutation")
		or npc:GetAttribute("MutationName")
		or npc:GetAttribute("ActiveMutation")
		or npc:GetAttribute("MutationType")
		or npc:GetAttribute("CurrentMutation")

	if mutation and normalize(mutation) == "golden" then
		return true
	end

	local display = tostring(npc:GetAttribute("DisplayName") or npc:GetAttribute("BrainrotName") or npc.Name or "")
	return string.find(normalize(display), "golden") ~= nil
end

local function getParts(model)
	local parts = {}

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(parts, obj)
		end
	end

	return parts
end

local function getRoot(npc)
	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	local hrp = npc:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	local best = nil
	local bestScore = -math.huge

	for _, part in ipairs(getParts(npc)) do
		local n = normalize(part.Name)
		local score = part.Size.X * part.Size.Y * part.Size.Z

		if n ~= "hitbox" and n ~= "collision" and n ~= "range" then
			score += 1000
		end

		if score > bestScore then
			bestScore = score
			best = part
		end
	end

	return best
end

local function getSize(npc)
	local ok, _, size = pcall(function()
		return npc:GetBoundingBox()
	end)

	if ok and size then
		return size
	end

	return Vector3.new(4, 4, 4)
end

local function clearAura(npc)
	local data = active[npc]

	if data and data.folder then
		data.folder:Destroy()
	end

	active[npc] = nil

	if npc then
		local old = npc:FindFirstChild(AURA_FOLDER_NAME)
		if old then
			old:Destroy()
		end

		for _, obj in ipairs(npc:GetDescendants()) do
			if string.sub(obj.Name, 1, #PREFIX) == PREFIX then
				obj:Destroy()
			end
		end
	end
end

local function makeAttachment(root, name, position)
	local attachment = Instance.new("Attachment")
	attachment.Name = PREFIX .. name
	attachment.Position = position
	attachment.Parent = root
	return attachment
end

local function applyFlipbook(emitter)
	local okLayout, layout = pcall(function()
		return Enum.ParticleFlipbookLayout.Grid4x4
	end)

	if okLayout then
		pcall(function()
			emitter.FlipbookLayout = layout
		end)
	end

	local okMode, mode = pcall(function()
		return Enum.ParticleFlipbookMode.Loop
	end)

	if okMode then
		pcall(function()
			emitter.FlipbookMode = mode
		end)
	end

	pcall(function()
		emitter.FlipbookFramerate = NumberRange.new(14, 18)
	end)
end

local function makeAnimatedFlameEmitter(parent, radius)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = PREFIX .. "AnimatedGoldenFlame"
	emitter.Texture = GOLDEN_FLIPBOOK

	applyFlipbook(emitter)

	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD_LIGHT),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DARK),
	})

	emitter.Rate = 7
	emitter.Lifetime = NumberRange.new(0.75, 1.05)
	emitter.Speed = NumberRange.new(0.15, 0.45)
	emitter.SpreadAngle = Vector2.new(18, 18)
	emitter.Rotation = NumberRange.new(-4, 4)
	emitter.RotSpeed = NumberRange.new(-10, 10)
	emitter.Drag = 2.5
	emitter.LightEmission = 1
	emitter.LockedToPart = false

	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 1.8),
		NumberSequenceKeypoint.new(0.45, radius * 2.15),
		NumberSequenceKeypoint.new(1, radius * 1.65),
	})

	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(0.55, 0.28),
		NumberSequenceKeypoint.new(1, 1),
	})

	emitter.Parent = parent

	return emitter
end

local function makeSoftGlowEmitter(parent, radius)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = PREFIX .. "SoftGoldenGlow"
	emitter.Texture = GOLDEN_FLIPBOOK

	applyFlipbook(emitter)

	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_LIGHT),
	})

	emitter.Rate = 3
	emitter.Lifetime = NumberRange.new(1.1, 1.5)
	emitter.Speed = NumberRange.new(0.05, 0.15)
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.Rotation = NumberRange.new(-3, 3)
	emitter.RotSpeed = NumberRange.new(-5, 5)
	emitter.Drag = 3
	emitter.LightEmission = 0.9
	emitter.LockedToPart = false

	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 2.0),
		NumberSequenceKeypoint.new(0.6, radius * 2.45),
		NumberSequenceKeypoint.new(1, radius * 2.1),
	})

	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})

	emitter.Parent = parent

	return emitter
end

local function makeSparkEmitter(parent, radius)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = PREFIX .. "GoldSparks"
	emitter.Texture = SHARP_SPARK

	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD_LIGHT),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DARK),
	})

	emitter.Rate = 18
	emitter.Lifetime = NumberRange.new(0.18, 0.4)
	emitter.Speed = NumberRange.new(2.5, 6)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-140, 140)
	emitter.Drag = 0.8
	emitter.LightEmission = 1
	emitter.LockedToPart = false

	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, radius * 0.035),
		NumberSequenceKeypoint.new(1, 0),
	})

	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})

	emitter.Parent = parent

	return emitter
end

local function makeGroundRing(folder, radius)
	local ring = Instance.new("Part")
	ring.Name = PREFIX .. "GroundRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.Transparency = 1
	ring.Size = Vector3.new(radius * 2.15, 0.03, radius * 2.15)
	ring.Parent = folder

	local top = Instance.new("Decal")
	top.Name = "TopRing"
	top.Texture = AURA_RING
	top.Face = Enum.NormalId.Top
	top.Color3 = GOLD
	top.Transparency = 0.22
	top.Parent = ring

	local bottom = Instance.new("Decal")
	bottom.Name = "BottomRing"
	bottom.Texture = AURA_RING
	bottom.Face = Enum.NormalId.Bottom
	bottom.Color3 = GOLD_DARK
	bottom.Transparency = 0.22
	bottom.Parent = ring

	return ring, top, bottom
end

local function makeHighlight(folder, npc)
	local highlight = Instance.new("Highlight")
	highlight.Name = PREFIX .. "Highlight"
	highlight.Adornee = npc
	highlight.FillColor = GOLD
	highlight.OutlineColor = GOLD_DARK
	highlight.FillTransparency = 0.9
	highlight.OutlineTransparency = 0.22
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder
	return highlight
end

local function makeLight(root, radius)
	local light = Instance.new("PointLight")
	light.Name = PREFIX .. "Light"
	light.Color = GOLD
	light.Brightness = 1.2
	light.Range = math.clamp(10 + radius, 10, 18)
	light.Shadows = false
	light.Parent = root
	return light
end

local function createAura(npc)
	clearAura(npc)

	local root = getRoot(npc)
	if not root then
		return
	end

	local size = getSize(npc)
	local radius = math.max(size.X, size.Z, 3.5) * 0.55
	local height = math.max(size.Y, 3.5)

	local folder = Instance.new("Folder")
	folder.Name = AURA_FOLDER_NAME
	folder.Parent = npc

	local center = makeAttachment(root, "CenterAttachment", Vector3.new(0, height * 0.05, 0))
	local top = makeAttachment(root, "TopAttachment", Vector3.new(0, height * 0.42, 0))

	local flame = makeAnimatedFlameEmitter(center, radius)
	local glow = makeSoftGlowEmitter(center, radius)
	local sparks = makeSparkEmitter(top, radius)
	local ring, ringTop, ringBottom = makeGroundRing(folder, radius)
	local highlight = makeHighlight(folder, npc)
	local light = makeLight(root, radius)

	active[npc] = {
		npc = npc,
		root = root,
		folder = folder,
		radius = radius,
		height = height,
		flame = flame,
		glow = glow,
		sparks = sparks,
		ring = ring,
		ringTop = ringTop,
		ringBottom = ringBottom,
		highlight = highlight,
		light = light,
		start = os.clock(),
		enabled = true,
		lowQuality = false,
	}
end

local function refreshNpc(npc)
	if not npc:IsA("Model") or not npc:IsDescendantOf(Workspace) then
		clearAura(npc)
		return
	end

	if not isGoldenMutation(npc) then
		clearAura(npc)
		return
	end

	local data = active[npc]

	if data and data.root and data.root.Parent then
		return
	end

	createAura(npc)
end

local function setEnabled(data, enabled, lowQuality)
	if data.enabled == enabled and data.lowQuality == lowQuality then
		return
	end

	data.enabled = enabled
	data.lowQuality = lowQuality

	data.flame.Enabled = enabled and not lowQuality
	data.glow.Enabled = enabled
	data.sparks.Enabled = enabled and not lowQuality
	data.light.Enabled = enabled and not lowQuality
	data.highlight.Enabled = enabled

	local ringTransparency = enabled and (lowQuality and 0.55 or 0.22) or 1
	data.ringTop.Transparency = ringTransparency
	data.ringBottom.Transparency = ringTransparency
end

local function updateDistance()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local camPos = camera.CFrame.Position

	for npc, data in pairs(active) do
		if not npc.Parent or not data.root or not data.root.Parent then
			clearAura(npc)
		else
			local distance = (data.root.Position - camPos).Magnitude

			if distance > LOW_DISTANCE then
				setEnabled(data, false, true)
			elseif distance > FULL_DISTANCE then
				setEnabled(data, true, true)
			else
				setEnabled(data, true, false)
			end
		end
	end
end

local function updateAura(data)
	if not data.enabled or not data.root or not data.root.Parent then
		return
	end

	local elapsed = os.clock() - data.start
	local pulse = 1 + math.sin(elapsed * 2.1) * 0.055

	if data.ring and data.ring.Parent then
		local ringSize = data.radius * (2.15 + math.sin(elapsed * 2) * 0.07)

		data.ring.Size = Vector3.new(ringSize, 0.03, ringSize)
		data.ring.CFrame =
			CFrame.new(data.root.Position + Vector3.new(0, -data.height * 0.48, 0))
			* CFrame.Angles(0, elapsed * 1.1, 0)
	end

	data.light.Brightness = 1.2 * pulse
	data.highlight.FillTransparency = 0.9 + math.sin(elapsed * 2) * 0.025
end

local function watchNpc(npc)
	if not npc:IsA("Model") then
		return
	end

	for _, attr in ipairs({
		"Mutation",
		"MutationName",
		"ActiveMutation",
		"MutationType",
		"CurrentMutation",
		"DisplayName",
		"BrainrotName",
	}) do
		npc:GetAttributeChangedSignal(attr):Connect(function()
			task.defer(function()
				refreshNpc(npc)
			end)
		end)
	end

	npc.AncestryChanged:Connect(function(_, parent)
		if not parent then
			clearAura(npc)
		end
	end)

	task.defer(function()
		refreshNpc(npc)
	end)
end

local function scan()
	local folder = getNpcFolder()
	if not folder then
		return
	end

	for _, npc in ipairs(folder:GetChildren()) do
		if npc:IsA("Model") and not watched[npc] then
			watched[npc] = true
			watchNpc(npc)
		end
	end
end

local folder = getNpcFolder()
if folder then
	folder.ChildAdded:Connect(function(npc)
		task.wait(0.1)

		if npc:IsA("Model") and not watched[npc] then
			watched[npc] = true
			watchNpc(npc)
		end
	end)
end

scan()

RunService.RenderStepped:Connect(function()
	if os.clock() - lastUpdate >= UPDATE_EVERY then
		lastUpdate = os.clock()

		scan()

		local npcFolder = getNpcFolder()
		if npcFolder then
			for _, npc in ipairs(npcFolder:GetChildren()) do
				refreshNpc(npc)
			end
		end

		updateDistance()
	end

	for _, data in pairs(active) do
		updateAura(data)
	end
end)

print("[GoldenAnimatedAura] Loaded animated Golden flipbook aura.")
