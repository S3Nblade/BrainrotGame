--!nonstrict
-- StarterPlayerScripts/CaptureFeedbackClient.client.lua
-- Guaranteed visible capture VFX.
-- Listens to your existing BrainrotCatchFeedback remote AND the new CaptureFeedback remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local GOLD = Color3.fromRGB(255, 220, 45)
local GOLD_LIGHT = Color3.fromRGB(255, 255, 190)
local GOLD_DARK = Color3.fromRGB(255, 145, 25)

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getModelRoot(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function modelMatchesPayload(model, payload)
	local npcId = tostring(payload.npcId or payload.NPCId or payload.Id or "")
	local npcName = tostring(payload.npcName or payload.BrainrotName or payload.Name or "")

	if npcId ~= "" then
		local modelId = tostring(
			model:GetAttribute("NPCId")
			or model:GetAttribute("Id")
			or model:GetAttribute("UniqueId")
			or model:GetAttribute("UID")
			or model.Name
		)

		if modelId == npcId then
			return true
		end
	end

	if npcName ~= "" then
		local displayName = tostring(
			model:GetAttribute("DisplayName")
			or model:GetAttribute("BrainrotName")
			or model:GetAttribute("Name")
			or model.Name
		)

		if normalize(displayName) == normalize(npcName) then
			return true
		end
	end

	local heldBy = tonumber(model:GetAttribute("HeldBy"))
	if heldBy == player.UserId then
		return true
	end

	return false
end

local function findCapturedNpcPosition(payload)
	local folder = Workspace:FindFirstChild(NPC_FOLDER_NAME)

	if folder then
		for _, obj in ipairs(folder:GetDescendants()) do
			if obj:IsA("Model") and modelMatchesPayload(obj, payload or {}) then
				local root = getModelRoot(obj)
				if root then
					return root.Position
				end
			end
		end
	end

	local root = getCharacterRoot()
	if root then
		return root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 1.5, 0)
	end

	return Vector3.new(0, 5, 0)
end

local function cameraShake()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local original = humanoid.CameraOffset
	local duration = 0.18
	local strength = 0.16
	local start = os.clock()

	local connection
	connection = RunService.RenderStepped:Connect(function()
		local alpha = (os.clock() - start) / duration

		if alpha >= 1 then
			connection:Disconnect()
			humanoid.CameraOffset = original
			return
		end

		local fade = 1 - alpha

		humanoid.CameraOffset = original + Vector3.new(
			(math.random() - 0.5) * strength * fade,
			(math.random() - 0.5) * strength * fade,
			0
		)
	end)
end

local function createAnchor(position)
	local part = Instance.new("Part")
	part.Name = "ClientCaptureVFX_Anchor"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Parent = Workspace

	Debris:AddItem(part, 2.5)

	return part
end

local function createFlashSphere(position)
	local sphere = Instance.new("Part")
	sphere.Name = "ClientCaptureVFX_FlashSphere"
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = GOLD
	sphere.Transparency = 0.15
	sphere.Size = Vector3.new(0.5, 0.5, 0.5)
	sphere.Position = position
	sphere.Parent = Workspace

	TweenService:Create(
		sphere,
		TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(5.2, 5.2, 5.2),
			Transparency = 1,
		}
	):Play()

	Debris:AddItem(sphere, 0.35)
end

local function createRing(position)
	local ringFolder = Instance.new("Folder")
	ringFolder.Name = "ClientCaptureVFX_Ring"
	ringFolder.Parent = Workspace

	local count = 22
	local startRadius = 0.8
	local endRadius = 4.2
	local y = position.Y - 2.1

	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local startPos = Vector3.new(
			position.X + math.cos(angle) * startRadius,
			y,
			position.Z + math.sin(angle) * startRadius
		)

		local endPos = Vector3.new(
			position.X + math.cos(angle) * endRadius,
			y + 0.12,
			position.Z + math.sin(angle) * endRadius
		)

		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))

		local segment = Instance.new("Part")
		segment.Name = "RingSegment"
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanTouch = false
		segment.CanQuery = false
		segment.Material = Enum.Material.Neon
		segment.Color = i % 2 == 0 and GOLD or GOLD_DARK
		segment.Transparency = 0.05
		segment.Size = Vector3.new(0.55, 0.07, 0.11)
		segment.CFrame = CFrame.lookAt(startPos, startPos + tangent)
		segment.Parent = ringFolder

		TweenService:Create(
			segment,
			TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = endPos,
				Transparency = 1,
			}
		):Play()
	end

	Debris:AddItem(ringFolder, 0.55)
end

local function createParticles(position)
	local anchor = createAnchor(position)

	local attachment = Instance.new("Attachment")
	attachment.Name = "CaptureVFXAttachment"
	attachment.Parent = anchor

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "GoldSparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GOLD_LIGHT),
		ColorSequenceKeypoint.new(0.5, GOLD),
		ColorSequenceKeypoint.new(1, GOLD_DARK),
	})
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.28, 0.55)
	sparks.Speed = NumberRange.new(7, 14)
	sparks.SpreadAngle = Vector2.new(360, 360)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-180, 180)
	sparks.Drag = 1.1
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.75, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Parent = attachment

	local glow = Instance.new("ParticleEmitter")
	glow.Name = "GoldGlow"
	glow.Texture = "rbxasset://textures/particles/smoke_main.dds"
	glow.Color = ColorSequence.new(GOLD)
	glow.Rate = 0
	glow.Lifetime = NumberRange.new(0.35, 0.7)
	glow.Speed = NumberRange.new(1, 3)
	glow.SpreadAngle = Vector2.new(360, 360)
	glow.Drag = 2
	glow.LightEmission = 0.8
	glow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(0.5, 2.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	glow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	glow.Parent = attachment

	sparks:Emit(38)
	glow:Emit(10)
end

local function createLight(position)
	local anchor = createAnchor(position)

	local light = Instance.new("PointLight")
	light.Name = "CaptureVFXLight"
	light.Color = GOLD
	light.Brightness = 3
	light.Range = 16
	light.Shadows = false
	light.Parent = anchor

	TweenService:Create(
		light,
		TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	):Play()
end

local function playSound(position)
	local soundPart = createAnchor(position)

	local sound = Instance.new("Sound")
	sound.Name = "CapturePopSound"
	sound.SoundId = "rbxassetid://9118828563"
	sound.Volume = 0.25
	sound.PlaybackSpeed = 1.45
	sound.RollOffMaxDistance = 80
	sound.Parent = soundPart

	sound:Play()
end

local function playCaptureVFX(payload)
	payload = payload or {}

	local position = payload.Position

	if typeof(position) ~= "Vector3" then
		position = findCapturedNpcPosition(payload)
	end

	createFlashSphere(position)
	createRing(position)
	createParticles(position)
	createLight(position)
	playSound(position)
	cameraShake()

	print("[CaptureFeedbackClient] Played capture VFX at", position)
end

-- Local test event for Command Bar.
local oldTest = playerGui:FindFirstChild("TestCaptureFeedbackLocal")
if oldTest then
	oldTest:Destroy()
end

local testEvent = Instance.new("BindableEvent")
testEvent.Name = "TestCaptureFeedbackLocal"
testEvent.Parent = playerGui

testEvent.Event:Connect(function()
	local root = getCharacterRoot()
	local position = root and (root.Position + root.CFrame.LookVector * 5 + Vector3.new(0, 1.5, 0)) or Vector3.new(0, 5, 0)
	playCaptureVFX({ Position = position })
end)

-- New remote from the system we created.
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		local captureFeedback = remotes:FindFirstChild("CaptureFeedback")
		if captureFeedback and captureFeedback:IsA("RemoteEvent") then
			captureFeedback.OnClientEvent:Connect(function(payload)
				if typeof(payload) == "table" then
					playCaptureVFX(payload)
				end
			end)

			print("[CaptureFeedbackClient] Listening to ReplicatedStorage.Remotes.CaptureFeedback")
		end
	end
end)

-- Your existing game capture pickup remote.
task.spawn(function()
	local existingRemote = ReplicatedStorage:WaitForChild("BrainrotCatchFeedback", 10)
	if existingRemote and existingRemote:IsA("RemoteEvent") then
		existingRemote.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" then
				playCaptureVFX(payload)
			else
				playCaptureVFX({})
			end
		end)

		print("[CaptureFeedbackClient] Listening to ReplicatedStorage.BrainrotCatchFeedback")
	else
		warn("[CaptureFeedbackClient] BrainrotCatchFeedback remote not found.")
	end
end)

print("[CaptureFeedbackClient] Loaded guaranteed capture VFX v2.")
