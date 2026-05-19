--!nonstrict
-- ServerScriptService/ZoneEggHatching.server.lua
-- Replaces free-roaming wild NPC spawns with zone eggs that hatch into inventory tools.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local EGG_FOLDER_NAME = "ZoneBrainrotEggs"
local HATCH_RESULT_REMOTE = "ZoneEggHatchResult"
local HATCH_REQUEST_REMOTE = "ZoneEggHatchRequest"
local EGG_SPAWNER_ID = "ZoneEggHatching_v1"

local INITIAL_DELAY = 4
local SPAWN_INTERVAL = 5
local HATCH_DISTANCE = 18
local PLAYER_HATCH_COOLDOWN = 1.25
local RESPAWN_DELAY = 7

local rng = Random.new()
local activeByEggId = {}
local lastHatchByPlayer = {}

local STYLE_COLORS = {
	Starter = {
		Body = Color3.fromRGB(86, 207, 255),
		Band = Color3.fromRGB(255, 220, 72),
		Glow = Color3.fromRGB(255, 95, 170),
		Material = Enum.Material.SmoothPlastic,
	},
	Forest = {
		Body = Color3.fromRGB(76, 184, 86),
		Band = Color3.fromRGB(154, 238, 92),
		Glow = Color3.fromRGB(95, 67, 35),
		Material = Enum.Material.Grass,
	},
	Desert = {
		Body = Color3.fromRGB(226, 174, 88),
		Band = Color3.fromRGB(255, 226, 142),
		Glow = Color3.fromRGB(77, 198, 216),
		Material = Enum.Material.Sand,
	},
	Crystal = {
		Body = Color3.fromRGB(113, 226, 255),
		Band = Color3.fromRGB(184, 112, 255),
		Glow = Color3.fromRGB(245, 255, 255),
		Material = Enum.Material.Glass,
	},
	Lava = {
		Body = Color3.fromRGB(255, 79, 36),
		Band = Color3.fromRGB(74, 45, 42),
		Glow = Color3.fromRGB(255, 221, 84),
		Material = Enum.Material.Neon,
	},
	Galaxy = {
		Body = Color3.fromRGB(84, 72, 205),
		Band = Color3.fromRGB(255, 95, 218),
		Glow = Color3.fromRGB(112, 242, 255),
		Material = Enum.Material.Neon,
	},
}

local BLOCKED_TOOL_ATTRIBUTES = {
	CanPickup = true,
	CanPickUp = true,
	PickupReady = true,
	ReadyToPick = true,
	ReadyToPickup = true,
	ReadyToPickUp = true,
	CaptureStunned = true,
	Defeated = true,
	IsDefeated = true,
	Stunned = true,
	IsStunned = true,
	MutationRevealRunning = true,
	IsPlaced = true,
	Placed = true,
	PlacedOwnerUserId = true,
	AssignedSlotId = true,
	AssignedSlotFloor = true,
	AssignedSlotPath = true,
}

local eggFolder = Workspace:FindFirstChild(EGG_FOLDER_NAME)
if not eggFolder then
	eggFolder = Instance.new("Folder")
	eggFolder.Name = EGG_FOLDER_NAME
	eggFolder.Parent = Workspace
end

local hatchResultRemote = ReplicatedStorage:FindFirstChild(HATCH_RESULT_REMOTE)
if not hatchResultRemote then
	hatchResultRemote = Instance.new("RemoteEvent")
	hatchResultRemote.Name = HATCH_RESULT_REMOTE
	hatchResultRemote.Parent = ReplicatedStorage
end

local hatchRequestRemote = ReplicatedStorage:FindFirstChild(HATCH_REQUEST_REMOTE)
if not hatchRequestRemote then
	hatchRequestRemote = Instance.new("RemoteEvent")
	hatchRequestRemote.Name = HATCH_REQUEST_REMOTE
	hatchRequestRemote.Parent = ReplicatedStorage
end

local function getApi()
	local started = os.clock()

	while not _G.BrainrotZoneEggApi and os.clock() - started < 20 do
		task.wait(0.1)
	end

	return _G.BrainrotZoneEggApi
end

local function getMutationConfig()
	local configs = ReplicatedStorage:FindFirstChild("Configs") or ReplicatedStorage:WaitForChild("Configs", 5)
	local module = configs and (configs:FindFirstChild("MutationConfig") or configs:WaitForChild("MutationConfig", 5))

	if not module then
		return nil
	end

	local ok, result = pcall(require, module)
	if ok then
		return result
	end

	warn("[ZoneEggHatching] Could not require MutationConfig:", result)
	return nil
end

local MutationConfig = getMutationConfig()

local function getRoot(model)
	if not model then
		return nil
	end

	return model.PrimaryPart or model:FindFirstChild("EggRoot", true) or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getCharacterRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getEggMax(zoneConfig)
	local configured = tonumber(zoneConfig.EggMaxAlive)
	if configured then
		return configured
	end

	local initial = tonumber(zoneConfig.InitialAlive) or 4
	return math.clamp(math.ceil(initial * 0.85), 3, 7)
end

local function getStyle(zoneConfig)
	return STYLE_COLORS[zoneConfig.Style] or STYLE_COLORS.Starter
end

local function setCommonPartProps(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
end

local function addWeld(root, part)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = root
end

local function makeEggPart(model, name, size, cframe, color, shape, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Shape = shape or Enum.PartType.Ball
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	setCommonPartProps(part)
	part.Parent = model
	return part
end

local function addEggBillboard(model, zoneConfig)
	local root = getRoot(model)
	if not root then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EggLabel"
	billboard.Size = UDim2.fromOffset(170, 58)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = tostring(zoneConfig.DisplayName or zoneConfig.Style or "Zone") .. " Egg"
	label.TextColor3 = Color3.fromRGB(255, 247, 214)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(24, 26, 44)
	stroke.Thickness = 3
	stroke.Parent = label
end

local function createEggModel(zoneName, zoneConfig, position)
	local style = getStyle(zoneConfig)
	local eggId = HttpService:GenerateGUID(false)
	local model = Instance.new("Model")
	model.Name = zoneName .. " Egg"
	model:SetAttribute("EggId", eggId)
	model:SetAttribute("ZoneName", zoneName)
	model:SetAttribute("ZoneDisplayName", zoneConfig.DisplayName or zoneName)
	model:SetAttribute("ZoneStyle", zoneConfig.Style or zoneName)
	model:SetAttribute("EggSpawnerId", EGG_SPAWNER_ID)
	model:SetAttribute("HatchInProgress", false)

	local baseCFrame = CFrame.new(position)
	local root = makeEggPart(model, "EggRoot", Vector3.new(2.35, 2.9, 2.35), baseCFrame, style.Body, Enum.PartType.Ball, style.Material)
	root.Transparency = 1
	model.PrimaryPart = root

	local body = makeEggPart(model, "EggBody", Vector3.new(2.28, 2.9, 2.28), baseCFrame, style.Body, Enum.PartType.Ball, style.Material)
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	addWeld(root, body)

	for i = 1, 3 do
		local y = -0.62 + (i - 1) * 0.62
		local band = makeEggPart(
			model,
			"PaintBand_" .. tostring(i),
			Vector3.new(2.42, 0.18, 2.42),
			baseCFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			i == 2 and style.Glow or style.Band,
			Enum.PartType.Cylinder,
			Enum.Material.SmoothPlastic
		)
		addWeld(root, band)
	end

	for i = 1, 5 do
		local angle = (math.pi * 2 / 5) * i
		local spot = makeEggPart(
			model,
			"StyleSpot_" .. tostring(i),
			Vector3.new(0.38, 0.14, 0.38),
			baseCFrame
				* CFrame.new(math.cos(angle) * 1.02, rng:NextNumber(-0.45, 0.86), math.sin(angle) * 1.02)
				* CFrame.Angles(math.rad(90), 0, 0),
			style.Glow,
			Enum.PartType.Cylinder,
			Enum.Material.Neon
		)
		addWeld(root, spot)
	end

	local light = Instance.new("PointLight")
	light.Name = "EggGlow"
	light.Color = style.Glow
	light.Brightness = 1.4
	light.Range = 12
	light.Parent = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = "Hatch"
	prompt.ObjectText = tostring(zoneConfig.DisplayName or zoneName) .. " Egg"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = HATCH_DISTANCE
	prompt.HoldDuration = 1.15
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	addEggBillboard(model, zoneConfig)

	model:PivotTo(baseCFrame * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = eggFolder
	activeByEggId[eggId] = model

	return model, prompt
end

local function countEggsInZone(zoneName)
	local count = 0

	for _, egg in ipairs(eggFolder:GetChildren()) do
		if egg:IsA("Model")
			and egg:GetAttribute("EggSpawnerId") == EGG_SPAWNER_ID
			and egg:GetAttribute("ZoneName") == zoneName
			and egg:GetAttribute("HatchInProgress") ~= true then
			count += 1
		end
	end

	return count
end

local function playerAlreadyHasTool(player, uid)
	if not uid then
		return false
	end

	for _, container in ipairs({
		player:FindFirstChild("Backpack"),
		player.Character,
		player:FindFirstChild("StarterGear"),
	}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") then
					local childUid = child:GetAttribute("BrainrotUID") or child:GetAttribute("UID") or child:GetAttribute("InventoryUid")
					if childUid and tostring(childUid) == tostring(uid) then
						return true
					end
				end
			end
		end
	end

	return false
end

local function copyAttributes(fromInstance, toInstance)
	for key, value in pairs(fromInstance:GetAttributes()) do
		local valueType = typeof(value)
		if not BLOCKED_TOOL_ATTRIBUTES[key] and (valueType == "string" or valueType == "number" or valueType == "boolean") then
			pcall(function()
				toInstance:SetAttribute(key, value)
			end)
		end
	end
end

local function getBrainrotName(npc)
	local name = npc:GetAttribute("DisplayName")
		or npc:GetAttribute("BrainrotName")
		or npc:GetAttribute("BaseBrainrotName")
		or npc:GetAttribute("OriginalBrainrotName")
		or npc:GetAttribute("TemplateName")
		or npc.Name

	name = tostring(name)
	if name == "" or name == "Model" then
		name = "Brainrot"
	end

	return name
end

local function applyMutationAndEconomy(instance, baseMps)
	local mutation = MutationConfig and MutationConfig.Roll and MutationConfig.Roll() or {
		Name = "Normal",
		MoneyMultiplier = 1,
		StrengthMultiplier = 1,
		Color = Color3.fromRGB(255, 255, 255),
	}

	if MutationConfig and MutationConfig.ApplyAttributes then
		MutationConfig.ApplyAttributes(instance, mutation)
	end

	local mutationName = tostring(mutation.Name or "Normal")
	local multiplier = tonumber(mutation.MoneyMultiplier or mutation.Multiplier) or 1
	local finalMps = math.max(1, math.floor((tonumber(baseMps) or 1) * multiplier))

	instance:SetAttribute("Mutation", mutationName)
	instance:SetAttribute("MutationName", mutationName)
	instance:SetAttribute("MutationDisplayName", tostring(mutation.DisplayName or mutationName))
	instance:SetAttribute("MutationMultiplier", multiplier)
	instance:SetAttribute("ActiveMutation", mutationName)
	instance:SetAttribute("MutationType", mutationName)
	instance:SetAttribute("CurrentMutation", mutationName)
	instance:SetAttribute("BaseCashPerSecondBeforeMutation", tonumber(baseMps) or 1)
	instance:SetAttribute("MutationEconomyApplied", true)
	instance:SetAttribute("CashPerSecond", finalMps)
	instance:SetAttribute("MPS", finalMps)
	instance:SetAttribute("MoneyPerSecond", finalMps)

	return mutation, finalMps
end

local function createBrainrotTool(player, npc)
	local uid = npc:GetAttribute("BrainrotUID") or HttpService:GenerateGUID(false)
	uid = tostring(uid)

	if playerAlreadyHasTool(player, uid) then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = getBrainrotName(npc)
	tool.RequiresHandle = false
	tool.CanBeDropped = false

	copyAttributes(npc, tool)

	tool:SetAttribute("IsBrainrot", true)
	tool:SetAttribute("BrainrotTool", true)
	tool:SetAttribute("InventoryOnly", true)
	tool:SetAttribute("IsPlaced", false)
	tool:SetAttribute("Placed", false)
	tool:SetAttribute("OwnerUserId", player.UserId)
	tool:SetAttribute("OwnerName", player.Name)
	tool:SetAttribute("HeldOwnerUserId", player.UserId)
	tool:SetAttribute("CapturedByUserId", player.UserId)
	tool:SetAttribute("HatchedFromEgg", true)

	tool:SetAttribute("BrainrotUID", uid)
	tool:SetAttribute("UID", uid)
	tool:SetAttribute("BrainrotUid", uid)
	tool:SetAttribute("DirectInventoryUid", uid)
	tool:SetAttribute("InventoryUid", uid)

	local finalName = getBrainrotName(npc)
	tool.Name = finalName
	tool:SetAttribute("BrainrotName", finalName)
	tool:SetAttribute("DisplayName", finalName)

	tool:SetAttribute("CanPickup", false)
	tool:SetAttribute("CanPickUp", false)
	tool:SetAttribute("PickupReady", false)
	tool:SetAttribute("ReadyToPick", false)
	tool:SetAttribute("ReadyToPickup", false)
	tool:SetAttribute("ReadyToPickUp", false)
	tool:SetAttribute("CaptureStunned", false)
	tool:SetAttribute("Defeated", false)
	tool:SetAttribute("IsDefeated", false)
	tool:SetAttribute("Stunned", false)
	tool:SetAttribute("IsStunned", false)
	tool:SetAttribute("MutationRevealRunning", false)
	tool:SetAttribute("AssignedSlotId", nil)
	tool:SetAttribute("AssignedSlotFloor", nil)
	tool:SetAttribute("AssignedSlotPath", nil)
	tool:SetAttribute("PlacedOwnerUserId", nil)

	local backpack = player:FindFirstChild("Backpack")
	tool.Parent = backpack or player

	return tool
end

local function playEggBurst(egg)
	local root = getRoot(egg)
	if not root then
		return
	end

	local style = STYLE_COLORS[tostring(egg:GetAttribute("ZoneStyle") or "Starter")] or STYLE_COLORS.Starter

	local attachment = Instance.new("Attachment")
	attachment.Name = "EggBurstAttachment"
	attachment.Parent = root

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "EggBurst"
	particles.Color = ColorSequence.new(style.Glow, style.Band)
	particles.LightEmission = 0.55
	particles.Lifetime = NumberRange.new(0.45, 0.85)
	particles.Speed = NumberRange.new(9, 16)
	particles.SpreadAngle = Vector2.new(360, 360)
	particles.Rate = 0
	particles.Texture = "rbxassetid://243098098"
	particles.Parent = attachment
	particles:Emit(44)

	for _, part in ipairs(egg:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				TweenService:Create(part, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Size = part.Size * 1.18,
					Transparency = 1,
				}):Play()
			end)
		end
	end

	Debris:AddItem(attachment, 1.5)
end

local function fireCatchFeedback(player, tool)
	local remote = ReplicatedStorage:FindFirstChild("BrainrotCatchFeedback")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, {
			Name = tostring(tool:GetAttribute("DisplayName") or tool.Name),
			BrainrotName = tostring(tool:GetAttribute("BrainrotName") or tool.Name),
			Rarity = tostring(tool:GetAttribute("Rarity") or "Common"),
			Mutation = tostring(tool:GetAttribute("Mutation") or "Normal"),
			MutationDisplayName = tostring(tool:GetAttribute("MutationDisplayName") or tool:GetAttribute("Mutation") or "Normal"),
			MutationMultiplier = tonumber(tool:GetAttribute("MutationMultiplier")) or 1,
			CashPerSecond = tonumber(tool:GetAttribute("CashPerSecond")) or tonumber(tool:GetAttribute("MPS")) or 1,
			Tool = tool,
		})
	end
end

local function getRollNames(api, zoneName)
	local summaries = api.GetTemplateSummaries and api.GetTemplateSummaries(zoneName) or {}
	local names = {}

	for _, summary in ipairs(summaries) do
		table.insert(names, tostring(summary.Name or "Brainrot"))
	end

	if #names <= 0 then
		table.insert(names, "Mystery Brainrot")
	end

	return names
end

local function hatchEgg(player, egg)
	local api = _G.BrainrotZoneEggApi
	if not api or not egg or not egg.Parent then
		return
	end

	if egg:GetAttribute("HatchInProgress") == true then
		return
	end

	local now = os.clock()
	if lastHatchByPlayer[player.UserId] and now - lastHatchByPlayer[player.UserId] < PLAYER_HATCH_COOLDOWN then
		return
	end

	local characterRoot = getCharacterRoot(player)
	local eggRoot = getRoot(egg)
	if not characterRoot or not eggRoot or (characterRoot.Position - eggRoot.Position).Magnitude > HATCH_DISTANCE + 4 then
		return
	end

	lastHatchByPlayer[player.UserId] = now
	egg:SetAttribute("HatchInProgress", true)

	local prompt = eggRoot:FindFirstChild("HatchPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end

	local zoneName = tostring(egg:GetAttribute("ZoneName") or "Starter")
	local zoneConfig = api.Zones and api.Zones[zoneName]
	if not zoneConfig then
		egg:Destroy()
		return
	end

	local rarity = api.ChooseWeightedRarity(zoneConfig)
	local template = api.ChooseTemplate(zoneName, rarity)
	if not template then
		warn("[ZoneEggHatching] No reward template for zone:", zoneName, "rarity:", rarity)
		egg:SetAttribute("HatchInProgress", false)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = true
		end
		return
	end

	local rewardNpc = template:Clone()
	local baseMps = api.GetRandomMPS(zoneConfig, rarity)
	api.PrepareNPC(rewardNpc, zoneName, rarity, baseMps)
	rewardNpc:SetAttribute("HatchedFromEgg", true)
	rewardNpc:SetAttribute("EggZone", zoneName)

	local mutation, finalMps = applyMutationAndEconomy(rewardNpc, baseMps)
	local tool = createBrainrotTool(player, rewardNpc)
	rewardNpc:Destroy()

	if not tool then
		egg:SetAttribute("HatchInProgress", false)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = true
		end
		return
	end

	local mutationColor = mutation.Color or Color3.fromRGB(255, 255, 255)
	local payload = {
		EggId = tostring(egg:GetAttribute("EggId") or ""),
		ZoneName = zoneName,
		ZoneDisplayName = tostring(zoneConfig.DisplayName or zoneName),
		ResultName = tostring(tool:GetAttribute("DisplayName") or tool.Name),
		Rarity = rarity,
		BaseMPS = baseMps,
		MPS = finalMps,
		Mutation = tostring(tool:GetAttribute("Mutation") or "Normal"),
		MutationDisplayName = tostring(tool:GetAttribute("MutationDisplayName") or tool:GetAttribute("Mutation") or "Normal"),
		MutationMultiplier = tonumber(tool:GetAttribute("MutationMultiplier")) or 1,
		MutationColor = mutationColor,
		RollNames = getRollNames(api, zoneName),
		Tool = tool,
	}

	hatchResultRemote:FireClient(player, payload)
	fireCatchFeedback(player, tool)
	playEggBurst(egg)

	local eggId = egg:GetAttribute("EggId")
	if eggId then
		activeByEggId[tostring(eggId)] = nil
	end

	task.delay(0.32, function()
		if egg and egg.Parent then
			egg:Destroy()
		end
	end)
end

local function spawnEggInZone(api, zoneName)
	local zoneConfig = api.Zones[zoneName]
	if not zoneConfig then
		return false
	end

	if countEggsInZone(zoneName) >= getEggMax(zoneConfig) then
		return false
	end

	local position = api.ChooseSpawnPosition(zoneName)
	if not position then
		return false
	end

	local egg, prompt = createEggModel(zoneName, zoneConfig, position)
	prompt.Triggered:Connect(function(player)
		hatchEgg(player, egg)
	end)

	return true
end

hatchRequestRemote.OnServerEvent:Connect(function(player, eggId)
	local egg = activeByEggId[tostring(eggId or "")]
	if egg then
		hatchEgg(player, egg)
	end
end)

task.spawn(function()
	local api = getApi()
	if not api then
		warn("[ZoneEggHatching] Zone API was not available. Eggs cannot spawn.")
		return
	end

	task.wait(INITIAL_DELAY)
	if api.RefreshAreas then
		api.RefreshAreas(true)
	end

	for zoneName, zoneConfig in pairs(api.Zones) do
		for _ = 1, getEggMax(zoneConfig) do
			spawnEggInZone(api, zoneName)
			task.wait(0.05)
		end
	end

	while true do
		for zoneName, _zoneConfig in pairs(api.Zones) do
			spawnEggInZone(api, zoneName)
			task.wait(0.12)
		end

		task.wait(SPAWN_INTERVAL)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastHatchByPlayer[player.UserId] = nil
end)

eggFolder.ChildRemoved:Connect(function(child)
	local eggId = child:GetAttribute("EggId")
	if eggId then
		activeByEggId[tostring(eggId)] = nil
	end

	task.delay(RESPAWN_DELAY, function()
		local api = _G.BrainrotZoneEggApi
		local zoneName = child:GetAttribute("ZoneName")
		if api and zoneName and api.Zones and api.Zones[zoneName] then
			spawnEggInZone(api, zoneName)
		end
	end)
end)

print("[ZoneEggHatching] Loaded. Zone eggs now hatch into random mutated Brainrots.")
