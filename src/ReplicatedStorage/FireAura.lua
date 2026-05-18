--!nonstrict
-- FireAura.lua
-- ReplicatedStorage/FireAura
-- FIXED: supports NPC models with or without Humanoid.

local TweenService = game:GetService("TweenService")

local FireAura = {}

local TEX_FLAME = "rbxassetid://128200066542648"
local TEX_RING  = "rbxassetid://84861113235353"
local TEX_WIDE  = "rbxassetid://111011193684058"
local TEX_SPARK = "rbxassetid://92949940207009"

local QUALITY = {
	Low   = { wispsRate = 10, embersRate = 6,  useBeam = false, pulseEvery = {3.5, 5.0} },
	Med   = { wispsRate = 16, embersRate = 9,  useBeam = true,  pulseEvery = {3.0, 4.5} },
	High  = { wispsRate = 22, embersRate = 12, useBeam = true,  pulseEvery = {2.6, 4.0} },
	Ultra = { wispsRate = 28, embersRate = 14, useBeam = true,  pulseEvery = {2.4, 3.8} },
}

local function pick(minv, maxv)
	return minv + math.random() * (maxv - minv)
end

local function findRoot(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local root = model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChild("Torso", true)
		or model:FindFirstChild("UpperTorso", true)

	if root and root:IsA("BasePart") then
		return root
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function destroyOldAura(model)
	local oldRig = model:FindFirstChild("FireAuraRig")
	if oldRig then
		oldRig:Destroy()
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj.Name == "AuraRoot"
			or obj.Name == "AuraTop"
			or obj.Name == "FireAuraLight" then
			obj:Destroy()
		end
	end
end

local function newAttachment(parent, name, pos)
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = pos or Vector3.zero
	attachment.Parent = parent
	return attachment
end

local function newEmitter(parent, name)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Enabled = true
	emitter.LockedToPart = false
	emitter.Parent = parent
	return emitter
end

local function newBeam(parent, name, a0, a1)
	local beam = Instance.new("Beam")
	beam.Name = name
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Parent = parent
	return beam
end

function FireAura.Attach(character, opts)
	opts = opts or {}

	if not character or not character:IsA("Model") then
		return nil
	end

	local qualityName = opts.Quality or "Ultra"
	local q = QUALITY[qualityName] or QUALITY.Ultra

	local root = findRoot(character)
	if not root then
		warn("[FireAura] No root part found for:", character:GetFullName())
		return nil
	end

	if character:FindFirstChild("FireAuraRig") then
		local handle = {}

		function handle:Destroy()
			destroyOldAura(character)
		end

		return handle
	end

	local rigFolder = Instance.new("Folder")
	rigFolder.Name = "FireAuraRig"
	rigFolder.Parent = character

	local cleanup = {}

	local function track(obj)
		table.insert(cleanup, obj)
		return obj
	end

	local auraRoot = track(newAttachment(root, "AuraRoot", Vector3.new(0, -1.0, 0)))
	local auraTop = track(newAttachment(root, "AuraTop", Vector3.new(0, 1.8, 0)))

	local light = track(Instance.new("PointLight"))
	light.Name = "FireAuraLight"
	light.Color = Color3.fromRGB(255, 100, 25)
	light.Brightness = 2.4
	light.Range = 13
	light.Shadows = false
	light.Parent = root

	local highlight = Instance.new("Highlight")
	highlight.Name = "FireAuraHighlight"
	highlight.Adornee = character
	highlight.FillColor = Color3.fromRGB(255, 80, 20)
	highlight.OutlineColor = Color3.fromRGB(255, 170, 45)
	highlight.FillTransparency = 0.82
	highlight.OutlineTransparency = 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = rigFolder

	local glow = newEmitter(auraRoot, "GlowRing")
	glow.Texture = TEX_RING
	glow.EmissionDirection = Enum.NormalId.Top
	glow.Rate = 4
	glow.Lifetime = NumberRange.new(0.9, 1.2)
	glow.Speed = NumberRange.new(0.0, 0.15)
	glow.RotSpeed = NumberRange.new(-25, 25)
	glow.SpreadAngle = Vector2.new(0, 0)
	glow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 4.5),
		NumberSequenceKeypoint.new(1.0, 7.5),
	})
	glow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.65),
		NumberSequenceKeypoint.new(0.4, 0.82),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	glow.Color = ColorSequence.new(
		Color3.fromRGB(180, 35, 20),
		Color3.fromRGB(255, 120, 30)
	)
	glow.LightEmission = 0.85
	glow.LightInfluence = 0.0

	local wisps = newEmitter(auraRoot, "FlameWisps")
	wisps.Texture = TEX_FLAME
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.Rate = q.wispsRate
	wisps.Lifetime = NumberRange.new(0.75, 1.2)
	wisps.Speed = NumberRange.new(1.2, 2.5)
	wisps.Acceleration = Vector3.new(0, 2.4, 0)
	wisps.Drag = 3
	wisps.SpreadAngle = Vector2.new(18, 28)
	wisps.Rotation = NumberRange.new(0, 360)
	wisps.RotSpeed = NumberRange.new(-90, 90)
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.85),
		NumberSequenceKeypoint.new(0.25, 1.65),
		NumberSequenceKeypoint.new(1.0, 0.25),
	})
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.25),
		NumberSequenceKeypoint.new(0.35, 0.48),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	wisps.Color = ColorSequence.new(
		Color3.fromRGB(210, 45, 18),
		Color3.fromRGB(255, 145, 40)
	)
	wisps.LightEmission = 1
	wisps.LightInfluence = 0.0

	local embers = newEmitter(auraRoot, "Embers")
	embers.Texture = TEX_SPARK
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Rate = q.embersRate
	embers.Lifetime = NumberRange.new(0.45, 0.85)
	embers.Speed = NumberRange.new(2.6, 4.4)
	embers.Acceleration = Vector3.new(0, 4.0, 0)
	embers.Drag = 2
	embers.SpreadAngle = Vector2.new(12, 20)
	embers.Rotation = NumberRange.new(0, 360)
	embers.RotSpeed = NumberRange.new(-180, 180)
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.16),
		NumberSequenceKeypoint.new(1.0, 0.03),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.02),
		NumberSequenceKeypoint.new(0.2, 0.12),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	embers.Color = ColorSequence.new(
		Color3.fromRGB(255, 90, 25),
		Color3.fromRGB(255, 205, 90)
	)
	embers.LightEmission = 1
	embers.LightInfluence = 0.0

	local pulse = newEmitter(auraRoot, "PulseRing")
	pulse.Texture = TEX_RING
	pulse.Enabled = false
	pulse.EmissionDirection = Enum.NormalId.Top
	pulse.Rate = 0
	pulse.Lifetime = NumberRange.new(0.35, 0.45)
	pulse.Speed = NumberRange.new(0.0, 0.0)
	pulse.SpreadAngle = Vector2.new(0, 0)
	pulse.Rotation = NumberRange.new(0, 360)
	pulse.RotSpeed = NumberRange.new(-40, 40)
	pulse.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 2.5),
		NumberSequenceKeypoint.new(1.0, 8.5),
	})
	pulse.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.75),
		NumberSequenceKeypoint.new(0.25, 0.9),
		NumberSequenceKeypoint.new(1.0, 1.0),
	})
	pulse.Color = ColorSequence.new(
		Color3.fromRGB(255, 85, 25),
		Color3.fromRGB(255, 165, 55)
	)
	pulse.LightEmission = 0.9
	pulse.LightInfluence = 0.0

	if q.useBeam then
		local beam = newBeam(rigFolder, "FlameRibbon", auraRoot, auraTop)
		beam.Texture = TEX_WIDE
		beam.Width0 = 0.45
		beam.Width1 = 0.15
		beam.FaceCamera = true
		beam.Segments = 8
		beam.LightEmission = 0.95
		beam.LightInfluence = 0.0
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.45),
			NumberSequenceKeypoint.new(1.0, 0.95),
		})
		beam.Color = ColorSequence.new(
			Color3.fromRGB(255, 70, 20),
			Color3.fromRGB(255, 160, 45)
		)
		beam.TextureSpeed = 0.9
		beam.TextureLength = 1.8
	end

	local pulseTweenInfo = TweenInfo.new(1.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local wispTween = TweenService:Create(wisps, pulseTweenInfo, { Rate = q.wispsRate * 0.75 })
	local emberTween = TweenService:Create(embers, pulseTweenInfo, { Rate = q.embersRate * 0.85 })
	local lightTween = TweenService:Create(light, pulseTweenInfo, { Brightness = 1.45 })

	wispTween:Play()
	emberTween:Play()
	lightTween:Play()

	local alive = true

	task.spawn(function()
		while alive and rigFolder.Parent do
			task.wait(pick(q.pulseEvery[1], q.pulseEvery[2]))

			if not alive or not rigFolder.Parent then
				break
			end

			pulse:Emit(1)
			embers:Emit(math.random(3, 6))
		end
	end)

	local handle = {}

	function handle:Destroy()
		alive = false

		pcall(function()
			wispTween:Cancel()
			emberTween:Cancel()
			lightTween:Cancel()
		end)

		for _, obj in ipairs(cleanup) do
			if obj and obj.Parent then
				obj:Destroy()
			end
		end

		if rigFolder and rigFolder.Parent then
			rigFolder:Destroy()
		end
	end

	return handle
end

return FireAura