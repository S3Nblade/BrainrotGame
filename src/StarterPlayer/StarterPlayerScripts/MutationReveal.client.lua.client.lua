--!nonstrict
-- StarterPlayerScripts/MutationReveal.client.lua
-- Smooth stage-based mutation cinematic.
-- No wall/background panel.
-- Normal = very fast and simple.
-- Rare mutations = slower, stronger particles, more orbs, more dramatic reveal.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local remote = ReplicatedStorage:WaitForChild("BrainrotMutationReveal")

local revealRunning = false
local currentGui = nil
local overheadGui = nil
local stageModel = nil
local localEffects = {}
local orbitConnection = nil

local RETURN_TIME = 0.32
local STAGE_BASE_POSITION = Vector3.new(0, 12000, 0)

local function getStagePosition()
	return STAGE_BASE_POSITION + Vector3.new((player.UserId % 1000) * 55, 0, 0)
end

local function getRoot(model)
	if not model then
		return nil
	end

	return model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getColor(payload)
	local c = payload.MutationColor

	if type(c) == "table" then
		return Color3.fromRGB(c.R or 255, c.G or 255, c.B or 255)
	end

	return Color3.fromRGB(255, 255, 255)
end

local function getOptions(payload)
	local options = {}

	if type(payload.Options) == "table" then
		for _, option in ipairs(payload.Options) do
			if type(option) == "table" then
				table.insert(options, {
					Name = option.Name or "Normal",
					DisplayName = option.DisplayName or option.Name or "Normal",
					Emoji = option.Emoji or "⚪",
				})
			end
		end
	end

	if #options == 0 then
		options = {
			{ Name = "Normal", DisplayName = "Normal", Emoji = "⚪" },
			{ Name = "Golden", DisplayName = "Golden", Emoji = "🟡" },
			{ Name = "Diamond", DisplayName = "Diamond", Emoji = "💎" },
			{ Name = "Shadow", DisplayName = "Shadow", Emoji = "🌑" },
			{ Name = "Corrupted", DisplayName = "Corrupted", Emoji = "🧬" },
			{ Name = "Rainbow", DisplayName = "Rainbow", Emoji = "🌈" },
			{ Name = "Celestial", DisplayName = "Celestial", Emoji = "✨" },
		}
	end

	return options
end

local function getProfile(effectName, mutationName)
	if mutationName == "Normal" or effectName == "Normal" then
		return {
			ZoomScale = 0.35,
			RollTime = 0.55,
			FinalHold = 0.25,
			Shake = 0,
			ParticlePower = 0.18,
			FinalFov = 68,
			OrbitSpeed = 1.25,
			OrbitDistance = 38,
			OrbitHeight = 11.5,
			Smoothness = 9,
			OrbCount = 0,
			OrbSpeed = 0,
			FinalBurst = 3,
			RollTickStart = 0.018,
			RollTickMax = 0.045,
		}
	elseif mutationName == "Golden" or effectName == "GoldBurst" then
		return {
			ZoomScale = 0.65,
			RollTime = 1.25,
			FinalHold = 0.55,
			Shake = 0.006,
			ParticlePower = 1.05,
			FinalFov = 60,
			OrbitSpeed = 0.78,
			OrbitDistance = 36,
			OrbitHeight = 10.8,
			Smoothness = 7.8,
			OrbCount = 3,
			OrbSpeed = 0.95,
			FinalBurst = 28,
			RollTickStart = 0.025,
			RollTickMax = 0.08,
		}
	elseif mutationName == "Diamond" or effectName == "DiamondSpark" then
		return {
			ZoomScale = 0.9,
			RollTime = 2.05,
			FinalHold = 0.85,
			Shake = 0.012,
			ParticlePower = 1.45,
			FinalFov = 57,
			OrbitSpeed = 0.62,
			OrbitDistance = 37,
			OrbitHeight = 11.2,
			Smoothness = 7.2,
			OrbCount = 5,
			OrbSpeed = 0.82,
			FinalBurst = 45,
			RollTickStart = 0.032,
			RollTickMax = 0.12,
		}
	elseif mutationName == "Shadow" or effectName == "ShadowSmoke" then
		return {
			ZoomScale = 1.18,
			RollTime = 3.0,
			FinalHold = 1.1,
			Shake = 0.02,
			ParticlePower = 1.8,
			FinalFov = 55,
			OrbitSpeed = 0.44,
			OrbitDistance = 39,
			OrbitHeight = 11.8,
			Smoothness = 6.5,
			OrbCount = 7,
			OrbSpeed = 0.58,
			FinalBurst = 60,
			RollTickStart = 0.042,
			RollTickMax = 0.16,
		}
	elseif mutationName == "Corrupted" or effectName == "CorruptedGlitch" then
		return {
			ZoomScale = 1.28,
			RollTime = 3.25,
			FinalHold = 1.15,
			Shake = 0.04,
			ParticlePower = 2.05,
			FinalFov = 54,
			OrbitSpeed = 0.5,
			OrbitDistance = 40,
			OrbitHeight = 12,
			Smoothness = 6.2,
			OrbCount = 8,
			OrbSpeed = 1.15,
			FinalBurst = 80,
			RollTickStart = 0.038,
			RollTickMax = 0.17,
		}
	elseif mutationName == "Rainbow" or effectName == "RainbowSpin" then
		return {
			ZoomScale = 1.55,
			RollTime = 4.0,
			FinalHold = 1.35,
			Shake = 0.024,
			ParticlePower = 2.55,
			FinalFov = 51,
			OrbitSpeed = 0.38,
			OrbitDistance = 41,
			OrbitHeight = 12.4,
			Smoothness = 5.8,
			OrbCount = 11,
			OrbSpeed = 0.88,
			FinalBurst = 110,
			RollTickStart = 0.045,
			RollTickMax = 0.2,
		}
	elseif mutationName == "Celestial" or effectName == "CelestialStars" then
		return {
			ZoomScale = 1.9,
			RollTime = 4.8,
			FinalHold = 1.7,
			Shake = 0.018,
			ParticlePower = 3.2,
			FinalFov = 48,
			OrbitSpeed = 0.26,
			OrbitDistance = 42,
			OrbitHeight = 13,
			Smoothness = 5.5,
			OrbCount = 16,
			OrbSpeed = 0.42,
			FinalBurst = 160,
			RollTickStart = 0.055,
			RollTickMax = 0.24,
		}
	end

	return {
		ZoomScale = 0.9,
		RollTime = 2,
		FinalHold = 0.8,
		Shake = 0.01,
		ParticlePower = 1,
		FinalFov = 58,
		OrbitSpeed = 0.65,
		OrbitDistance = 37,
		OrbitHeight = 11,
		Smoothness = 7,
		OrbCount = 4,
		OrbSpeed = 0.8,
		FinalBurst = 35,
		RollTickStart = 0.032,
		RollTickMax = 0.12,
	}
end

local function disableControls()
	local controls = nil

	pcall(function()
		local playerScripts = player:WaitForChild("PlayerScripts")
		local playerModule = require(playerScripts:WaitForChild("PlayerModule"))
		controls = playerModule:GetControls()
		controls:Disable()
	end)

	return function()
		if controls then
			pcall(function()
				controls:Enable()
			end)
		end
	end
end

local function addEffect(obj)
	table.insert(localEffects, obj)
	return obj
end

local function cleanup()
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end

	if currentGui then
		currentGui:Destroy()
		currentGui = nil
	end

	if overheadGui then
		overheadGui:Destroy()
		overheadGui = nil
	end

	for _, obj in ipairs(localEffects) do
		if obj and obj.Parent then
			obj:Destroy()
		end
	end

	table.clear(localEffects)

	if stageModel then
		stageModel:Destroy()
		stageModel = nil
	end

	local blur = Lighting:FindFirstChild("MutationStageBlur")
	if blur then
		blur:Destroy()
	end

	local color = Lighting:FindFirstChild("MutationStageColor")
	if color then
		color:Destroy()
	end
end

local function easeInOutSine(t)
	return -(math.cos(math.pi * t) - 1) / 2
end

local function smoothAlpha(dt, smoothness)
	return 1 - math.exp(-dt * smoothness)
end

local function cameraCFrame(center, angle, distance, height, side)
	local focus = center + Vector3.new(0, 1.1, 0)

	local forward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local sideVector = Vector3.new(-forward.Z, 0, forward.X)

	local position =
		focus
		+ forward * distance
		+ sideVector * side
		+ Vector3.new(0, height, 0)

	return CFrame.lookAt(position, focus)
end

local function getCameraFromState(center, state)
	return cameraCFrame(
		center,
		state.Angle,
		state.Distance,
		state.Height,
		state.Side
	)
end

local function lerpState(a, b, t)
	return {
		Angle = a.Angle + (b.Angle - a.Angle) * t,
		Distance = a.Distance + (b.Distance - a.Distance) * t,
		Height = a.Height + (b.Height - a.Height) * t,
		Side = a.Side + (b.Side - a.Side) * t,
		Fov = a.Fov + (b.Fov - a.Fov) * t,
	}
end

local function playCameraMove(center, fromState, toState, duration, smoothness)
	local start = os.clock()
	duration = math.max(duration, 0.03)

	while os.clock() - start < duration do
		local dt = RunService.RenderStepped:Wait()
		local raw = math.clamp((os.clock() - start) / duration, 0, 1)
		local eased = easeInOutSine(raw)

		local state = lerpState(fromState, toState, eased)
		local target = getCameraFromState(center, state)

		local alpha = smoothAlpha(dt, smoothness or 9)
		camera.CFrame = camera.CFrame:Lerp(target, alpha)
		camera.FieldOfView = camera.FieldOfView + (state.Fov - camera.FieldOfView) * alpha
	end

	local finalTarget = getCameraFromState(center, toState)
	camera.CFrame = camera.CFrame:Lerp(finalTarget, 0.35)
	camera.FieldOfView = camera.FieldOfView + (toState.Fov - camera.FieldOfView) * 0.35
end

local function createLetterbox()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MutationStageCinematicGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 9999
	gui.Parent = playerGui

	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.BackgroundColor3 = Color3.fromRGB(63, 112, 230)
	top.BackgroundTransparency = 0.12
	top.BorderSizePixel = 0
	top.Position = UDim2.fromScale(0, -0.13)
	top.Size = UDim2.new(1, 0, 0.13, 0)
	top.Parent = gui
	local topGradient = Instance.new("UIGradient")
	topGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 168, 224)),
	})
	topGradient.Rotation = 0
	topGradient.Parent = top

	local bottom = Instance.new("Frame")
	bottom.Name = "BottomBar"
	bottom.BackgroundColor3 = Color3.fromRGB(255, 168, 224)
	bottom.BackgroundTransparency = 0.12
	bottom.BorderSizePixel = 0
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.new(1, 0, 0.13, 0)
	bottom.Parent = gui
	local bottomGradient = Instance.new("UIGradient")
	bottomGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 238, 132)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 220, 255)),
	})
	bottomGradient.Rotation = 0
	bottomGradient.Parent = bottom

	TweenService:Create(top, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0, 0),
	}):Play()

	TweenService:Create(bottom, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0, 0.87),
	}):Play()

	currentGui = gui
	return gui
end

local function createLighting(finalColor, effectName, profile)
	local blur = Instance.new("BlurEffect")
	blur.Name = "MutationStageBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "MutationStageColor"
	color.TintColor = Color3.fromRGB(255, 255, 255)
	color.Brightness = 0
	color.Contrast = 0
	color.Saturation = 0
	color.Parent = Lighting

	local blurSize = 1.5 + ((profile.ParticlePower or 1) * 0.9)
	local saturation = 0.08 + ((profile.ParticlePower or 1) * 0.07)
	local contrast = 0.04 + ((profile.ParticlePower or 1) * 0.03)
	local brightness = 0.01

	if effectName == "Normal" then
		blurSize = 0
		saturation = 0
		contrast = 0
		brightness = 0
	elseif effectName == "ShadowSmoke" then
		blurSize += 4
		saturation = -0.12
		contrast += 0.1
		brightness = -0.08
	elseif effectName == "CorruptedGlitch" then
		blurSize += 1.5
		saturation += 0.32
		contrast += 0.18
		brightness = -0.03
	elseif effectName == "RainbowSpin" then
		saturation += 0.5
		contrast += 0.1
		brightness = 0.06
	elseif effectName == "CelestialStars" then
		blurSize += 2
		saturation += 0.25
		contrast += 0.08
		brightness = 0.14
	end

	TweenService:Create(blur, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = blurSize,
	}):Play()

	TweenService:Create(color, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		TintColor = finalColor,
		Saturation = saturation,
		Contrast = contrast,
		Brightness = brightness,
	}):Play()
end

local function makePart(parent, name, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function createStage(stagePosition, finalColor, profile)
	local model = Instance.new("Model")
	model.Name = "LocalMutationRevealStage"
	model.Parent = Workspace
	stageModel = model

	makePart(
		model,
		"StageFloor",
		Vector3.new(54, 0.35, 54),
		CFrame.new(stagePosition + Vector3.new(0, -0.2, 0)),
		Color3.fromRGB(24, 24, 36),
		Enum.Material.SmoothPlastic,
		0
	)

	makePart(
		model,
		"StageGlow",
		Vector3.new(42, 0.08, 42),
		CFrame.new(stagePosition + Vector3.new(0, 0.05, 0)),
		finalColor,
		Enum.Material.Neon,
		0.5
	)

	-- No wall/background panel.
	-- StageBackGlow was removed on purpose.

	local lightPart = makePart(
		model,
		"StageLightPart",
		Vector3.new(1, 1, 1),
		CFrame.new(stagePosition + Vector3.new(0, 15, -9)),
		finalColor,
		Enum.Material.Neon,
		1
	)

	local light = Instance.new("PointLight")
	light.Name = "StagePointLight"
	light.Color = finalColor
	light.Brightness = 1.5 + ((profile.ParticlePower or 1) * 1.5)
	light.Range = 72 + ((profile.ParticlePower or 1) * 8)
	light.Parent = lightPart

	local topLightPart = makePart(
		model,
		"TopLightPart",
		Vector3.new(1, 1, 1),
		CFrame.new(stagePosition + Vector3.new(0, 30, 0)),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.Neon,
		1
	)

	local topLight = Instance.new("SpotLight")
	topLight.Name = "StageSpotLight"
	topLight.Color = finalColor
	topLight.Brightness = 2 + ((profile.ParticlePower or 1) * 1.6)
	topLight.Range = 100
	topLight.Angle = 95
	topLight.Face = Enum.NormalId.Bottom
	topLight.Parent = topLightPart

	return model
end

local function cloneNpcToStage(npc, stagePosition)
	if not npc then
		return nil
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		pcall(function()
			obj.Archivable = true
		end)
	end

	pcall(function()
		npc.Archivable = true
	end)

	local clone
	local ok = pcall(function()
		clone = npc:Clone()
	end)

	if not ok or not clone then
		return nil
	end

	clone.Name = "MutationStageNPC_Copy"
	clone.Parent = stageModel or Workspace

	for _, obj in ipairs(clone:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
			obj:Destroy()
		elseif obj:IsA("ProximityPrompt") then
			obj:Destroy()
		elseif obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = true
			obj.AssemblyLinearVelocity = Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero

			if obj.Name ~= "HumanoidRootPart" and obj.Transparency >= 1 then
				obj.Transparency = 0
			end
		elseif obj:IsA("Humanoid") then
			obj.PlatformStand = true
			obj.AutoRotate = false
			obj.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end

	local _, sizeBefore = clone:GetBoundingBox()
	local maxDim = math.max(sizeBefore.X, sizeBefore.Y, sizeBefore.Z, 4)

	if maxDim < 4 then
		pcall(function()
			clone:ScaleTo(4 / maxDim)
		end)
	elseif maxDim > 12 then
		pcall(function()
			clone:ScaleTo(12 / maxDim)
		end)
	end

	local bboxCFrame, size = clone:GetBoundingBox()
	local desiredCenter = stagePosition + Vector3.new(0, math.max(size.Y * 0.55, 2.5), 0)
	local offset = desiredCenter - bboxCFrame.Position

	clone:PivotTo(clone:GetPivot() + offset)

	return clone
end

local function createOverhead(root, payload)
	local gui = Instance.new("BillboardGui")
	gui.Name = "MutationStageOverhead"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.MaxDistance = 500
	gui.Size = UDim2.fromOffset(560, 190)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7.8, 0)
	gui.Parent = playerGui

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0, 0)
	title.Size = UDim2.new(1, 0, 0.28, 0)
	title.Font = Enum.Font.FredokaOne
	title.Text = tostring(payload.Rarity or "Common") .. " " .. tostring(payload.BrainrotName or "Brainrot")
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.Parent = holder

	local mutation = Instance.new("TextLabel")
	mutation.Name = "Mutation"
	mutation.BackgroundTransparency = 1
	mutation.Position = UDim2.fromScale(0, 0.25)
	mutation.Size = UDim2.new(1, 0, 0.54, 0)
	mutation.Font = Enum.Font.FredokaOne
	mutation.Text = "Rolling..."
	mutation.TextScaled = true
	mutation.TextColor3 = Color3.fromRGB(255, 255, 255)
	mutation.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	mutation.TextStrokeTransparency = 0
	mutation.Parent = holder

	local stats = Instance.new("TextLabel")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.fromScale(0, 0.76)
	stats.Size = UDim2.new(1, 0, 0.22, 0)
	stats.Font = Enum.Font.FredokaOne
	stats.Text = "Capturing mutation..."
	stats.TextScaled = true
	stats.TextColor3 = Color3.fromRGB(120, 255, 130)
	stats.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	stats.TextStrokeTransparency = 0.15
	stats.Parent = holder

	local scale = Instance.new("UIScale")
	scale.Name = "Scale"
	scale.Scale = 0.2
	scale.Parent = holder

	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	overheadGui = gui

	return title, mutation, stats, scale
end

local function pulse(label, amount)
	local scale = label:FindFirstChild("PulseScale")

	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PulseScale"
		scale.Scale = 1
		scale.Parent = label
	end

	scale.Scale = 0.95

	TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Scale = amount or 1.025,
	}):Play()

	task.delay(0.06, function()
		if scale and scale.Parent then
			TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
end

local function createHighlight(npc, color, mutationName, profile)
	local highlight = Instance.new("Highlight")
	highlight.Name = "StageMutationHighlight"
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = mutationName == "Normal" and 1 or math.clamp(0.5 - ((profile.ParticlePower or 1) * 0.06), 0.16, 0.5)
	highlight.OutlineTransparency = mutationName == "Normal" and 1 or 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = npc

	addEffect(highlight)
end

local function createParticles(root, color, effectName, profile)
	local attachment = Instance.new("Attachment")
	attachment.Name = "StageMutationParticlesAttachment"
	attachment.Parent = root
	addEffect(attachment)

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "StageMutationParticles"
	particles.LightEmission = 0.9
	particles.LockedToPart = false
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Parent = attachment
	addEffect(particles)

	local power = profile.ParticlePower or 1

	if effectName == "GoldBurst" then
		particles.Color = ColorSequence.new(Color3.fromRGB(255, 210, 55))
		particles.Rate = 80 * power
		particles.Lifetime = NumberRange.new(0.35, 0.9)
		particles.Speed = NumberRange.new(6, 12)
	elseif effectName == "DiamondSpark" then
		particles.Color = ColorSequence.new(Color3.fromRGB(105, 235, 255))
		particles.Rate = 95 * power
		particles.Lifetime = NumberRange.new(0.3, 0.9)
		particles.Speed = NumberRange.new(5, 11)
	elseif effectName == "ShadowSmoke" then
		particles.Color = ColorSequence.new(Color3.fromRGB(80, 45, 150))
		particles.Rate = 60 * power
		particles.Lifetime = NumberRange.new(0.9, 1.8)
		particles.Speed = NumberRange.new(1.5, 5)
	elseif effectName == "CorruptedGlitch" then
		particles.Color = ColorSequence.new(Color3.fromRGB(255, 35, 75))
		particles.Rate = 120 * power
		particles.Lifetime = NumberRange.new(0.18, 0.5)
		particles.Speed = NumberRange.new(7, 15)
	elseif effectName == "RainbowSpin" then
		particles.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 40)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 35)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 50)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(55, 255, 95)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 60, 255)),
		})
		particles.Rate = 110 * power
		particles.Lifetime = NumberRange.new(0.4, 1.2)
		particles.Speed = NumberRange.new(5, 12)
	elseif effectName == "CelestialStars" then
		particles.Color = ColorSequence.new(Color3.fromRGB(190, 145, 255))
		particles.Rate = 90 * power
		particles.Lifetime = NumberRange.new(0.8, 1.8)
		particles.Speed = NumberRange.new(3.5, 8)
	else
		particles.Color = ColorSequence.new(color)
		particles.Rate = 12 * power
		particles.Lifetime = NumberRange.new(0.18, 0.45)
		particles.Speed = NumberRange.new(1.5, 4)
	end

	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(0.45, 0.38),
		NumberSequenceKeypoint.new(1, 0),
	})

	return particles
end

local function createOrbitOrbs(parent, center, finalColor, effectName, profile)
	local orbs = {}
	local count = profile.OrbCount or 0

	if count <= 0 then
		return orbs
	end

	for i = 1, count do
		local orb = Instance.new("Part")
		orb.Name = "MutationOrbitOrb"
		orb.Shape = Enum.PartType.Ball
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanTouch = false
		orb.CanQuery = false
		orb.Material = Enum.Material.Neon
		orb.Transparency = 0.15
		orb.Size = Vector3.new(0.55, 0.55, 0.55)
		orb.Color = finalColor
		orb.Parent = parent

		if effectName == "RainbowSpin" then
			orb.Color = Color3.fromHSV(i / count, 0.9, 1)
		elseif effectName == "CelestialStars" then
			orb.Color = Color3.fromRGB(210, 185, 255)
			orb.Size = Vector3.new(0.75, 0.75, 0.75)
		elseif effectName == "CorruptedGlitch" then
			orb.Color = Color3.fromRGB(255, 35, 75)
			orb.Size = Vector3.new(0.45, 0.45, 0.45)
		end

		local light = Instance.new("PointLight")
		light.Color = orb.Color
		light.Brightness = 0.7 + ((profile.ParticlePower or 1) * 0.25)
		light.Range = 8
		light.Parent = orb

		addEffect(orb)

		table.insert(orbs, {
			Part = orb,
			Phase = (math.pi * 2) * (i / count),
			HeightOffset = ((i % 3) - 1) * 1.4,
			Radius = 6 + (i % 3) * 1.2,
		})
	end

	return orbs
end

local function updateOrbitOrbs(orbs, center, t, effectName, profile)
	for i, orbInfo in ipairs(orbs) do
		local part = orbInfo.Part
		if part and part.Parent then
			local speed = profile.OrbSpeed or 1
			local angle = orbInfo.Phase + t * speed
			local radius = orbInfo.Radius + math.sin(t * 1.1 + orbInfo.Phase) * 0.35
			local height = 3.2 + orbInfo.HeightOffset + math.sin(t * 1.4 + orbInfo.Phase) * 0.5

			part.Position = center + Vector3.new(
				math.cos(angle) * radius,
				height,
				math.sin(angle) * radius
			)

			if effectName == "RainbowSpin" then
				part.Color = Color3.fromHSV((t * 0.15 + i / math.max(#orbs, 1)) % 1, 0.9, 1)
			end
		end
	end
end

local function applyCloneMutationVisual(clone, finalColor, effectName)
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			if effectName == "GoldBurst" then
				part.Color = Color3.fromRGB(255, 205, 60)
				part.Material = Enum.Material.SmoothPlastic
			elseif effectName == "DiamondSpark" then
				part.Color = Color3.fromRGB(105, 235, 255)
				part.Material = Enum.Material.Neon
			elseif effectName == "ShadowSmoke" then
				part.Color = Color3.fromRGB(45, 30, 85)
				part.Material = Enum.Material.SmoothPlastic
			elseif effectName == "CorruptedGlitch" then
				part.Color = Color3.fromRGB(255, 55, 90)
				part.Material = Enum.Material.Neon
			elseif effectName == "RainbowSpin" then
				part.Material = Enum.Material.Neon
			elseif effectName == "CelestialStars" then
				part.Color = Color3.fromRGB(170, 120, 255)
				part.Material = Enum.Material.Neon
			elseif effectName ~= "Normal" then
				part.Color = finalColor
			end
		end
	end
end

local function startSmoothOrbit(center, baseAngle, effectName, profile, orbs)
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end

	local startTime = os.clock()
	local current = camera.CFrame

	orbitConnection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - startTime

		local angle = baseAngle + t * (profile.OrbitSpeed or 0.65)
		local distance = (profile.OrbitDistance or 36) + math.sin(t * 0.8) * 0.8
		local height = (profile.OrbitHeight or 11) + math.sin(t * 0.75) * 0.35
		local side = math.sin(t * 0.55) * 1.8

		local target = cameraCFrame(center, angle, distance, height, side)

		local shake = 0
		if effectName == "CorruptedGlitch" then
			shake = profile.Shake or 0.03
		elseif effectName == "ShadowSmoke" or effectName == "RainbowSpin" then
			shake = (profile.Shake or 0.02) * 0.25
		end

		if shake > 0 then
			local offset = Vector3.new(
				math.sin(t * 12) * shake,
				math.cos(t * 14) * shake,
				math.sin(t * 10) * shake
			)

			target += offset
		end

		local alpha = smoothAlpha(dt, profile.Smoothness or 7)
		current = current:Lerp(target, alpha)
		camera.CFrame = current

		updateOrbitOrbs(orbs, center, t, effectName, profile)
	end)
end

local function stopOrbit()
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end
end

local function smoothFinalShake(center, angle, duration, intensity)
	local start = os.clock()
	local current = camera.CFrame

	while os.clock() - start < duration do
		local dt = RunService.RenderStepped:Wait()
		local t = os.clock() - start

		local target = cameraCFrame(center, angle, 25, 8.2, 0)

		if intensity > 0 then
			target += Vector3.new(
				math.sin(t * 22) * intensity,
				math.cos(t * 18) * intensity,
				math.sin(t * 15) * intensity
			)
		end

		current = current:Lerp(target, smoothAlpha(dt, 8))
		camera.CFrame = current
	end
end

local function restoreCamera(oldCamera)
	stopOrbit()

	pcall(function()
		TweenService:Create(camera, TweenInfo.new(RETURN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			CFrame = oldCamera.CFrame,
			FieldOfView = oldCamera.FieldOfView,
		}):Play()
	end)

	task.wait(RETURN_TIME)

	camera.CameraType = oldCamera.CameraType
	camera.CameraSubject = oldCamera.CameraSubject
	camera.FieldOfView = oldCamera.FieldOfView
end

local function runReveal(payload)
	if revealRunning then
		return
	end

	revealRunning = true

	local realNpc = payload.Npc

	if not realNpc or not realNpc.Parent then
		warn("[MutationRevealClient] Missing real NPC.")
		revealRunning = false
		return
	end

	local finalColor = getColor(payload)
	local effectName = tostring(payload.MutationEffect or "Normal")
	local finalMutation = tostring(payload.Mutation or "Normal")
	local finalMutationDisplay = tostring(payload.MutationDisplayName or finalMutation)
	local finalEmoji = tostring(payload.MutationEmoji or "")
	local profile = getProfile(effectName, finalMutation)
	local options = getOptions(payload)

	local enableControls = disableControls()

	local oldCamera = {
		CameraType = camera.CameraType,
		CameraSubject = camera.CameraSubject,
		CFrame = camera.CFrame,
		FieldOfView = camera.FieldOfView,
	}

	local ok, err = pcall(function()
		local stagePosition = getStagePosition()

		createStage(stagePosition, finalColor, profile)

		local clone = cloneNpcToStage(realNpc, stagePosition)
		if not clone then
			warn("[MutationRevealClient] Could not clone NPC for stage.")
			return
		end

		local cloneRoot = getRoot(clone)
		if not cloneRoot then
			warn("[MutationRevealClient] Clone has no root.")
			return
		end

		local bboxCFrame, bboxSize = clone:GetBoundingBox()
		local center = bboxCFrame.Position
		local maxSize = math.max(bboxSize.X, bboxSize.Y, bboxSize.Z, 4)

		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 92

		createLetterbox()
		createLighting(finalColor, effectName, profile)
		createHighlight(clone, finalColor, finalMutation, profile)

		local mainParticles = createParticles(cloneRoot, finalColor, effectName, profile)
		local orbs = createOrbitOrbs(stageModel or Workspace, center, finalColor, effectName, profile)

		local _, mutationLabel, statsLabel, holderScale = createOverhead(cloneRoot, payload)

		local baseAngle = math.rad(235)

		local farDistance = math.max(maxSize * 10.5, 62)
		local midDistance = math.max(maxSize * 8.5, 50)
		local closeDistance = math.max(maxSize * 6.8, 37)
		local finalDistance = math.max(maxSize * 5.0, 27)

		local zoomScale = profile.ZoomScale or 1

		local farState = {
			Angle = baseAngle,
			Distance = farDistance,
			Height = 14.5,
			Side = 8,
			Fov = 92,
		}

		local midState = {
			Angle = baseAngle + 0.22,
			Distance = midDistance,
			Height = 11.8,
			Side = -5,
			Fov = 82,
		}

		local closeState = {
			Angle = baseAngle + 0.55,
			Distance = closeDistance,
			Height = 9.2,
			Side = 2.5,
			Fov = 72,
		}

		local orbitState = {
			Angle = baseAngle + 0.75,
			Distance = profile.OrbitDistance or 36,
			Height = profile.OrbitHeight or 11,
			Side = 1.2,
			Fov = 68,
		}

		camera.CFrame = getCameraFromState(center, farState)
		camera.FieldOfView = farState.Fov

		playCameraMove(center, farState, midState, 0.22 * zoomScale, 9)
		playCameraMove(center, midState, closeState, 0.3 * zoomScale, 8)
		playCameraMove(center, closeState, orbitState, 0.32 * zoomScale, 7)

		startSmoothOrbit(center, orbitState.Angle, effectName, profile, orbs)

		local rollStart = os.clock()
		local index = 1
		local waitTime = profile.RollTickStart or 0.035
		local waitMax = profile.RollTickMax or 0.13

		while os.clock() - rollStart < profile.RollTime do
			if not cloneRoot.Parent then
				break
			end

			local option = options[index]

			mutationLabel.Text = tostring(option.Emoji or "") .. " " .. tostring(option.DisplayName or option.Name)

			if effectName == "RainbowSpin" then
				mutationLabel.TextColor3 = Color3.fromHSV((os.clock() * 0.35) % 1, 0.9, 1)
			elseif effectName == "CorruptedGlitch" then
				mutationLabel.TextColor3 = Color3.fromRGB(255, math.random(35, 115), math.random(65, 135))
				mutationLabel.Rotation = math.random(-2, 2)
			elseif effectName == "ShadowSmoke" then
				mutationLabel.TextColor3 = Color3.fromRGB(math.random(120, 180), math.random(80, 130), 255)
				mutationLabel.Rotation = 0
			elseif effectName == "CelestialStars" then
				mutationLabel.TextColor3 = Color3.fromRGB(220, 195, 255)
				mutationLabel.Rotation = 0
			else
				mutationLabel.TextColor3 = Color3.fromRGB(
					math.random(155, 255),
					math.random(155, 255),
					math.random(155, 255)
				)
				mutationLabel.Rotation = 0
			end

			statsLabel.Text = "Rolling mutation..."
			pulse(mutationLabel, 1.035)

			index += 1
			if index > #options then
				index = 1
			end

			waitTime = math.min(waitTime + 0.006, waitMax)
			task.wait(waitTime)
		end

		stopOrbit()

		applyCloneMutationVisual(clone, finalColor, effectName)

		if mainParticles then
			pcall(function()
				mainParticles:Emit(profile.FinalBurst or 35)
			end)
		end

		for _, orbInfo in ipairs(orbs) do
			if orbInfo.Part and orbInfo.Part.Parent then
				TweenService:Create(orbInfo.Part, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Size = orbInfo.Part.Size * 1.7,
					Transparency = 0.5,
				}):Play()
			end
		end

		mutationLabel.Rotation = 0
		mutationLabel.Text = finalEmoji .. " " .. string.upper(finalMutationDisplay)
		mutationLabel.TextColor3 = finalColor

		statsLabel.Text = "Money/sec: " .. tostring(payload.BaseMPS or "?") .. " → " .. tostring(payload.FinalMPS or "?")

		holderScale.Scale = 0.82
		TweenService:Create(holderScale, TweenInfo.new(0.24, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Scale = 1.18,
		}):Play()

		local finalAngle = baseAngle + 1.45

		local finalState = {
			Angle = finalAngle,
			Distance = finalDistance,
			Height = 8.3,
			Side = 0,
			Fov = profile.FinalFov or 56,
		}

		local currentState = {
			Angle = orbitState.Angle + (profile.OrbitSpeed or 0.65) * profile.RollTime,
			Distance = profile.OrbitDistance or 36,
			Height = profile.OrbitHeight or 11,
			Side = 1.2,
			Fov = camera.FieldOfView,
		}

		playCameraMove(center, currentState, finalState, 0.28 * zoomScale, 7)
		smoothFinalShake(center, finalAngle, 0.18, profile.Shake or 0)

		statsLabel.Text = "Captured!"

		task.wait(profile.FinalHold or 0.8)

		local blur = Lighting:FindFirstChild("MutationStageBlur")
		if blur then
			TweenService:Create(blur, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = 0,
			}):Play()
		end

		local color = Lighting:FindFirstChild("MutationStageColor")
		if color then
			TweenService:Create(color, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				TintColor = Color3.fromRGB(255, 255, 255),
				Brightness = 0,
				Contrast = 0,
				Saturation = 0,
			}):Play()
		end

		if currentGui then
			local top = currentGui:FindFirstChild("TopBar")
			local bottom = currentGui:FindFirstChild("BottomBar")

			if top then
				TweenService:Create(top, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Position = UDim2.fromScale(0, -0.13),
				}):Play()
			end

			if bottom then
				TweenService:Create(bottom, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Position = UDim2.fromScale(0, 1),
				}):Play()
			end
		end

		if holderScale then
			TweenService:Create(holderScale, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Scale = 0.7,
			}):Play()
		end

		task.wait(0.12)
	end)

	if not ok then
		warn("[MutationRevealClient] Cinematic error:", err)
	end

	cleanup()
	restoreCamera(oldCamera)
	enableControls()

	revealRunning = false
end

remote.OnClientEvent:Connect(runReveal)

print("[MutationRevealClient] Loaded FAST normal + strong rare no-wall mutation cinematic.")
