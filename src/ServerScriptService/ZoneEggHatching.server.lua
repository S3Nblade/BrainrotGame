--!nonstrict
-- ServerScriptService/ZoneEggHatching.server.lua
-- Clean zone egg spawning, damage, reward rolling, and reveal dispatch.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EggConfig = require(ServerScriptService:WaitForChild("EggConfig"))

local NPC_FOLDER_NAME = "BrainrotNPCs"
local EGG_FOLDER_NAME = "ZoneEggs"
local EGG_SPAWNER_ID = "CleanZoneEggSpawner_v1"
local REVEAL_REMOTE_NAME = "EggRevealResult"
local LEGACY_REVEAL_REMOTE_NAME = "ZoneEggHatchResult"
local START_NPC_REVEAL_REMOTE_NAME = "StartNPCReveal"

local INITIAL_DELAY = 3
local DEFAULT_DAMAGE = 10
local DAMAGE_COOLDOWN = 0.12
local rng = Random.new()

local activeById = {}
local lastDamageAt = {}
local zoneRuntime = {}

local function ensureFolder(parent, name)
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemote(parent, name)
	local remote = parent:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local npcFolder = ensureFolder(Workspace, NPC_FOLDER_NAME)
local eggFolder = ensureFolder(Workspace, EGG_FOLDER_NAME)
local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
local revealRemote = ensureRemote(remotesFolder, REVEAL_REMOTE_NAME)
local legacyRevealRemote = ensureRemote(ReplicatedStorage, LEGACY_REVEAL_REMOTE_NAME)
local startNpcRevealRemote = ensureRemote(remotesFolder, START_NPC_REVEAL_REMOTE_NAME)

local function getZoneApi()
	local started = os.clock()
	while not _G.BrainrotZoneEggApi and os.clock() - started < 20 do
		task.wait(0.1)
	end
	return _G.BrainrotZoneEggApi
end

local function getRoot(model)
	return model
		and (model.PrimaryPart or model:FindFirstChild("EggRoot", true) or model:FindFirstChild("HumanoidRootPart", true) or model:FindFirstChildWhichIsA("BasePart", true))
end

local function getRarityColor(rarity)
	return EggConfig.RarityColors[tostring(rarity or "Common")] or EggConfig.RarityColors.Common
end

local function getMutationInfo(name)
	return EggConfig.MutationInfo[tostring(name or "Normal")] or EggConfig.MutationInfo.Normal
end

local function chooseWeighted(weightMap)
	local total = 0
	for _, weight in pairs(weightMap or {}) do
		total += math.max(0, tonumber(weight) or 0)
	end
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	local running = 0
	for key, weight in pairs(weightMap) do
		running += math.max(0, tonumber(weight) or 0)
		if roll <= running then
			return tostring(key)
		end
	end

	for key, _ in pairs(weightMap) do
		return tostring(key)
	end
	return nil
end

local function chooseWeightedWithLuck(weightMap, luckBonus, baselineRarity, isMutation)
	local total = 0
	local adjusted = {}
	local baseOrder = EggConfig.RarityOrder[tostring(baselineRarity or "Common")] or 1
	local scale = isMutation and (EggConfig.LuckScaling.MutationLuckScale or 0.016) or (EggConfig.LuckScaling.RewardLuckScale or 0.012)

	for key, weight in pairs(weightMap or {}) do
		local order = EggConfig.RarityOrder[tostring(key)] or (isMutation and ({ Normal = 1, Golden = 2, Diamond = 3, Shadow = 4, Rainbow = 5 })[tostring(key)] or 1)
		local lift = math.max(0, order - baseOrder)
		if isMutation then
			lift = math.max(0, order - 1)
		end

		local multiplier = 1 + (tonumber(luckBonus) or 0) * scale * lift
		if lift <= 0 and (tonumber(luckBonus) or 0) > 0 then
			multiplier = math.max(0.35, 1 - (tonumber(luckBonus) or 0) * scale * 0.25)
		end

		local newWeight = math.max(0, (tonumber(weight) or 0) * multiplier)
		adjusted[key] = newWeight
		total += newWeight
	end

	if total <= 0 then
		return chooseWeighted(weightMap)
	end

	local roll = rng:NextNumber(0, total)
	local running = 0
	for key, weight in pairs(adjusted) do
		running += weight
		if roll <= running then
			return tostring(key)
		end
	end

	return chooseWeighted(weightMap)
end

local function chooseEgg(zoneConfig)
	local total = 0
	for _, eggDef in ipairs(zoneConfig.AllowedEggs or zoneConfig.Eggs or {}) do
		total += math.max(0, tonumber(eggDef.SpawnWeight or eggDef.Weight) or 0)
	end
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	local running = 0
	for _, eggDef in ipairs(zoneConfig.AllowedEggs or zoneConfig.Eggs or {}) do
		running += math.max(0, tonumber(eggDef.SpawnWeight or eggDef.Weight) or 0)
		if roll <= running then
			return eggDef
		end
	end
	return (zoneConfig.AllowedEggs or zoneConfig.Eggs or {})[1]
end

local function rangeNumber(range, fallback)
	if type(range) ~= "table" then
		return fallback
	end

	local minValue = tonumber(range.Min) or fallback
	local maxValue = tonumber(range.Max) or minValue
	if maxValue < minValue then
		maxValue = minValue
	end

	return rng:NextNumber(minValue, maxValue)
end

local function rangeInteger(range, fallback)
	return math.floor(rangeNumber(range, fallback) + 0.5)
end

local function rangeRatio(value, range)
	if type(range) ~= "table" then
		return 0
	end

	local minValue = tonumber(range.Min) or value
	local maxValue = tonumber(range.Max) or minValue
	if maxValue <= minValue then
		return 0
	end

	return math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
end

local function rollEggStats(baseDef)
	local hp = rangeInteger(baseDef.HpRange, tonumber(baseDef.HP) or 100)
	local size = rangeNumber(baseDef.SizeRange, tonumber(baseDef.Size) or 1)
	local baseLuck = rangeInteger(baseDef.LuckRange, tonumber(baseDef.LuckBonus) or 5)
	local hpRatio = rangeRatio(hp, baseDef.HpRange)
	local sizeRatio = rangeRatio(size, baseDef.SizeRange)
	local hpBonus = math.floor(hpRatio * (EggConfig.LuckScaling.HPBonusMax or 10) + 0.5)
	local sizeBonus = math.floor(sizeRatio * (EggConfig.LuckScaling.SizeBonusMax or 12) + 0.5)
	local finalLuck = math.max(0, baseLuck + hpBonus + sizeBonus)

	local rolled = {}
	for key, value in pairs(baseDef) do
		rolled[key] = value
	end

	rolled.BaseDef = baseDef
	rolled.HP = hp
	rolled.Size = size
	rolled.BaseLuck = baseLuck
	rolled.HPBonus = hpBonus
	rolled.SizeBonus = sizeBonus
	rolled.LuckBonus = finalLuck
	rolled.Glow = 0.35 + finalLuck / 55
	rolled.Speed = math.max(7, (tonumber(baseDef.Speed) or 12) - sizeRatio * 1.5 - hpRatio * 0.7)
	rolled.ChaseTime = tonumber(baseDef.ChaseTime) or 16
	rolled.ChaseRadius = tonumber(baseDef.ChaseRadius) or 45

	return rolled
end

local function findWorkspaceDescendant(name)
	local direct = Workspace:FindFirstChild(name)
	if direct then
		return direct
	end
	return Workspace:FindFirstChild(name, true)
end

local function collectParts(root, result)
	if root:IsA("BasePart") then
		table.insert(result, root)
	end
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(result, obj)
		end
	end
end

local function getBounds(root)
	if root:IsA("Model") then
		local ok, cf, size = pcall(function()
			return root:GetBoundingBox()
		end)
		if ok and cf and size then
			return cf, size
		end
	end
	if root:IsA("BasePart") then
		return root.CFrame, root.Size
	end

	local parts = {}
	collectParts(root, parts)
	if #parts <= 0 then
		return nil, nil
	end

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in ipairs(parts) do
		local low = part.Position - part.Size * 0.5
		local high = part.Position + part.Size * 0.5
		minV = Vector3.new(math.min(minV.X, low.X), math.min(minV.Y, low.Y), math.min(minV.Z, low.Z))
		maxV = Vector3.new(math.max(maxV.X, high.X), math.max(maxV.Y, high.Y), math.max(maxV.Z, high.Z))
	end

	return CFrame.new((minV + maxV) * 0.5), maxV - minV
end

local function getSpawnPoints(zoneRoot)
	local points = {}
	local folder = zoneRoot and zoneRoot:FindFirstChild("EggSpawnPoints", true)

	if zoneRoot and not folder then
		folder = Instance.new("Folder")
		folder.Name = "EggSpawnPoints"
		folder.Parent = zoneRoot
	end

	if folder then
		for _, obj in ipairs(folder:GetDescendants()) do
			if obj:IsA("BasePart") then
				table.insert(points, obj)
			end
		end
	end

	for _, obj in ipairs(zoneRoot and zoneRoot:GetDescendants() or {}) do
		if obj:IsA("BasePart") and string.find(string.lower(obj.Name), "eggspawn", 1, true) and not table.find(points, obj) then
			table.insert(points, obj)
		end
	end

	return points
end

local function randomPointOnPart(part, yOffset)
	local x = rng:NextNumber(-part.Size.X * 0.42, part.Size.X * 0.42)
	local z = rng:NextNumber(-part.Size.Z * 0.42, part.Size.Z * 0.42)
	return part.CFrame:PointToWorldSpace(Vector3.new(x, part.Size.Y * 0.5 + (yOffset or 2), z))
end

local function randomPointInsideZone(zoneName, zoneConfig)
	local root = findWorkspaceDescendant(zoneName)
	if not root then
		warn("[ZoneEggHatching] Missing zone in Workspace:", zoneName)
		return nil
	end

	local spawnPoints = getSpawnPoints(root)
	if #spawnPoints > 0 then
		return randomPointOnPart(spawnPoints[rng:NextInteger(1, #spawnPoints)], zoneConfig.SpawnYOffset or 2.25)
	end

	local cf, size = getBounds(root)
	if not cf or not size then
		return nil
	end
	zoneRuntime[zoneName] = zoneRuntime[zoneName] or {}
	zoneRuntime[zoneName].root = root
	zoneRuntime[zoneName].cframe = cf
	zoneRuntime[zoneName].size = size

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { root }

	for _ = 1, 10 do
		local x = rng:NextNumber(-size.X * 0.43, size.X * 0.43)
		local z = rng:NextNumber(-size.Z * 0.43, size.Z * 0.43)
		local origin = cf:PointToWorldSpace(Vector3.new(x, size.Y * 0.5 + 160, z))
		local hit = Workspace:Raycast(origin, Vector3.new(0, -(size.Y + 320), 0), params)
		if hit then
			return hit.Position + Vector3.new(0, zoneConfig.SpawnYOffset or 2.25, 0)
		end
	end

	return cf.Position + Vector3.new(0, (zoneConfig.SpawnYOffset or 2.25) + size.Y * 0.5, 0)
end

local function refreshZoneRuntime(zoneName)
	local root = findWorkspaceDescendant(zoneName)
	if not root then
		return nil
	end

	local cf, size = getBounds(root)
	if not cf or not size then
		return nil
	end

	zoneRuntime[zoneName] = {
		root = root,
		cframe = cf,
		size = size,
	}
	return zoneRuntime[zoneName]
end

local function clampToZone(zoneName, position)
	local runtime = zoneRuntime[zoneName] or refreshZoneRuntime(zoneName)
	if not runtime then
		return position
	end

	local localPos = runtime.cframe:PointToObjectSpace(position)
	local margin = 6
	local xLimit = math.max(8, runtime.size.X * 0.5 - margin)
	local zLimit = math.max(8, runtime.size.Z * 0.5 - margin)
	local clamped = Vector3.new(
		math.clamp(localPos.X, -xLimit, xLimit),
		localPos.Y,
		math.clamp(localPos.Z, -zLimit, zLimit)
	)
	return runtime.cframe:PointToWorldSpace(clamped)
end

local function setPartBase(part, anchored)
	part.Anchored = anchored ~= false
	part.CanCollide = true
	part.CanTouch = true
	part.CanQuery = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function makePart(parent, name, size, cframe, color, shape, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Shape = shape or Enum.PartType.Ball
	part.Material = material or Enum.Material.SmoothPlastic
	part.Color = color
	part.Transparency = transparency or 0
	setPartBase(part, true)
	part.Massless = name ~= "EggRoot"
	part.Parent = parent
	return part
end

local function weld(root, part)
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = root
	weldConstraint.Part1 = part
	weldConstraint.Parent = root
	return weldConstraint
end

local function createBillboard(model, eggDef)
	local root = getRoot(model)
	if not root then
		return nil
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "EggBillboard"
	gui.Size = UDim2.fromOffset(150, 82)
	gui.StudsOffset = Vector3.new(0, 3.25 * (tonumber(eggDef.Size) or 1), 0)
	gui.MaxDistance = 55
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = root

	local name = Instance.new("TextLabel")
	name.Name = "EggName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0)
	name.Size = UDim2.fromScale(1, 0.28)
	name.Font = Enum.Font.GothamBold
	name.Text = tostring(eggDef.DisplayName or "Egg")
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextScaled = true
	name.TextWrapped = true
	name.Parent = gui
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.fromRGB(10, 12, 18)
	nameStroke.Thickness = 2
	nameStroke.Parent = name

	local timerText = Instance.new("TextLabel")
	timerText.Name = "TimerText"
	timerText.BackgroundTransparency = 1
	timerText.Position = UDim2.fromScale(0, 0.25)
	timerText.Size = UDim2.fromScale(1, 0.22)
	timerText.Font = Enum.Font.GothamBold
	timerText.Text = ""
	timerText.TextColor3 = Color3.fromRGB(255, 245, 196)
	timerText.TextScaled = true
	timerText.Visible = false
	timerText.Parent = gui
	local timerStroke = Instance.new("UIStroke")
	timerStroke.Color = Color3.fromRGB(10, 12, 18)
	timerStroke.Thickness = 2
	timerStroke.Parent = timerText

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.BackgroundTransparency = 1
	hpText.Position = UDim2.fromScale(0.08, 0.4)
	hpText.Size = UDim2.fromScale(0.84, 0.16)
	hpText.Font = Enum.Font.GothamMedium
	hpText.Text = "HP: " .. tostring(eggDef.HP) .. "/" .. tostring(eggDef.HP)
	hpText.TextColor3 = Color3.fromRGB(225, 232, 244)
	hpText.TextScaled = true
	hpText.Parent = gui
	local hpStroke = Instance.new("UIStroke")
	hpStroke.Color = Color3.fromRGB(10, 12, 18)
	hpStroke.Thickness = 1.5
	hpStroke.Parent = hpText

	local barBack = Instance.new("Frame")
	barBack.Name = "HPBarBack"
	barBack.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
	barBack.BackgroundTransparency = 0.12
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.fromScale(0.18, 0.59)
	barBack.Size = UDim2.fromScale(0.64, 0.08)
	barBack.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = barBack

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = getRarityColor(eggDef.Rarity)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = barBack
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local luck = Instance.new("TextLabel")
	luck.Name = "LuckText"
	luck.BackgroundTransparency = 1
	luck.Position = UDim2.fromScale(0, 0.69)
	luck.Size = UDim2.fromScale(1, 0.22)
	luck.Font = Enum.Font.GothamBold
	luck.Text = "Luck +" .. tostring(eggDef.LuckBonus or 0) .. "%"
	luck.TextColor3 = getRarityColor(eggDef.Rarity)
	luck.TextScaled = true
	luck.Parent = gui
	local luckStroke = Instance.new("UIStroke")
	luckStroke.Color = Color3.fromRGB(10, 12, 18)
	luckStroke.Thickness = 2
	luckStroke.Parent = luck

	local function refresh()
		local maxHP = tonumber(model:GetAttribute("EggMaxHP")) or tonumber(eggDef.HP) or 1
		local hp = math.clamp(tonumber(model:GetAttribute("EggHP")) or maxHP, 0, maxHP)
		hpText.Text = "HP: " .. tostring(math.ceil(hp)) .. "/" .. tostring(math.ceil(maxHP))
		fill.Size = UDim2.fromScale(maxHP > 0 and hp / maxHP or 0, 1)

		local active = model:GetAttribute("CaptureChaseActive") == true
		timerText.Visible = active
		if active then
			local timeLeft = math.max(0, (tonumber(model:GetAttribute("CaptureChaseEndTime")) or 0) - Workspace:GetServerTimeNow())
			timerText.Text = string.format("%.1fs", timeLeft)
			timerText.TextColor3 = timeLeft <= 5 and Color3.fromRGB(255, 88, 88) or Color3.fromRGB(255, 245, 196)
		end
	end

	model:GetAttributeChangedSignal("EggHP"):Connect(refresh)
	model:GetAttributeChangedSignal("CaptureChaseActive"):Connect(refresh)
	model:GetAttributeChangedSignal("CaptureChaseEndTime"):Connect(refresh)
	task.spawn(function()
		while model.Parent and gui.Parent do
			refresh()
			task.wait(0.08)
		end
	end)
	refresh()
	return gui
end

local function createEggModel(zoneName, zoneConfig, eggDef, position)
	local scale = tonumber(eggDef.Size) or 1
	local rarityColor = getRarityColor(eggDef.Rarity)
	local bodyColor = eggDef.Rarity == "Common" and Color3.fromRGB(240, 235, 214) or rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.28)
	local accentColor = rarityColor
	local base = CFrame.new(position)
	local eggId = HttpService:GenerateGUID(false)

	local model = Instance.new("Model")
	model.Name = tostring(eggDef.DisplayName or "Egg")
	model:SetAttribute("EggId", eggId)
	model:SetAttribute("EggSpawnerId", EGG_SPAWNER_ID)
	model:SetAttribute("EggBrainrot", true)
	model:SetAttribute("IsEgg", true)
	model:SetAttribute("ZoneName", zoneName)
	model:SetAttribute("TemplateZone", tostring(zoneConfig.TemplateZone or zoneName))
	model:SetAttribute("EggConfigId", tostring(eggDef.Id))
	model:SetAttribute("DisplayName", tostring(eggDef.DisplayName or "Egg"))
	model:SetAttribute("BrainrotName", tostring(eggDef.DisplayName or "Egg"))
	model:SetAttribute("Rarity", tostring(eggDef.Rarity or "Common"))
	model:SetAttribute("EggHP", tonumber(eggDef.HP) or 100)
	model:SetAttribute("EggMaxHP", tonumber(eggDef.HP) or 100)
	model:SetAttribute("CaptureHP", tonumber(eggDef.HP) or 100)
	model:SetAttribute("CaptureMaxHP", tonumber(eggDef.HP) or 100)
	model:SetAttribute("LuckBonus", tonumber(eggDef.LuckBonus) or 0)
	model:SetAttribute("EggBaseLuck", tonumber(eggDef.BaseLuck) or tonumber(eggDef.LuckBonus) or 0)
	model:SetAttribute("EggHPLuckBonus", tonumber(eggDef.HPBonus) or 0)
	model:SetAttribute("EggSizeLuckBonus", tonumber(eggDef.SizeBonus) or 0)
	model:SetAttribute("EggSize", tonumber(eggDef.Size) or 1)
	model:SetAttribute("EggSpeed", tonumber(eggDef.Speed) or 12)
	model:SetAttribute("CaptureChaseActive", false)
	model:SetAttribute("CaptureChaseStartTime", 0)
	model:SetAttribute("CaptureChaseEndTime", 0)
	model:SetAttribute("CaptureChaseDuration", 0)
	model:SetAttribute("CaptureHunterUserId", 0)
	model:SetAttribute("CaptureHunterName", "")
	model:SetAttribute("CapturePanic", false)
	model:SetAttribute("CaptureShielded", false)
	model:SetAttribute("CaptureShieldEndTime", 0)
	model:SetAttribute("CaptureStunned", false)
	model:SetAttribute("HatchInProgress", false)
	model:SetAttribute("CanPickup", false)
	model:SetAttribute("PickupReady", false)

	local root = makePart(model, "HumanoidRootPart", Vector3.new(1.7, 2.05, 1.7) * scale, base, Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, Enum.Material.SmoothPlastic, 1)
	root.Massless = false
	model.PrimaryPart = root

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = tonumber(eggDef.HP) or 100
	humanoid.Health = humanoid.MaxHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = 0
	humanoid.Parent = model

	local body = makePart(model, "EggBody", Vector3.new(2.05, 2.75, 2.05) * scale, base, bodyColor, Enum.PartType.Ball, Enum.Material.SmoothPlastic, 0)
	weld(root, body)

	local bandCount = math.clamp(math.floor((tonumber(eggDef.Tier) or 1) + 1), 2, 5)
	for i = 1, bandCount do
		local y = (-0.8 + (i - 1) * (1.55 / math.max(1, bandCount - 1))) * scale
		local band = makePart(
			model,
			"CleanBand_" .. tostring(i),
			Vector3.new(2.14, 0.12, 2.14) * scale,
			base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			accentColor,
			Enum.PartType.Cylinder,
			i == bandCount and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			i == bandCount and 0.08 or 0
		)
		weld(root, band)
	end

	if (tonumber(eggDef.Tier) or 1) >= 2 then
		for i = 1, math.clamp(tonumber(eggDef.Tier) or 2, 2, 6) do
			local angle = (math.pi * 2 / math.clamp(tonumber(eggDef.Tier) or 2, 2, 6)) * i
			local spot = makePart(
				model,
				"SoftSpot_" .. tostring(i),
				Vector3.new(0.28, 0.08, 0.28) * scale,
				base * CFrame.new(math.cos(angle) * 0.88 * scale, rng:NextNumber(-0.45, 0.85) * scale, math.sin(angle) * 0.88 * scale) * CFrame.Angles(math.rad(90), 0, 0),
				accentColor:Lerp(Color3.fromRGB(255, 255, 255), 0.18),
				Enum.PartType.Cylinder,
				Enum.Material.Neon,
				0.12
			)
			weld(root, spot)
		end
	end

	local aura = makePart(model, "RarityAura", Vector3.new(2.45, 0.08, 2.45) * scale, base * CFrame.new(0, -1.18 * scale, 0), rarityColor, Enum.PartType.Cylinder, Enum.Material.Neon, 0.58)
	weld(root, aura)

	local light = Instance.new("PointLight")
	light.Name = "EggSoftGlow"
	light.Color = rarityColor
	light.Brightness = 0.7 + (tonumber(eggDef.Glow) or 0.45)
	light.Range = 9 + scale * 5
	light.Parent = root

	local highlight = Instance.new("Highlight")
	highlight.Name = "EggRarityHighlight"
	highlight.FillColor = rarityColor
	highlight.OutlineColor = rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.35)
	highlight.FillTransparency = eggDef.Rarity == "Common" and 0.86 or 0.72
	highlight.OutlineTransparency = eggDef.Rarity == "Common" and 0.45 or 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model

	createBillboard(model, eggDef)

	model:PivotTo(base * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = eggFolder
	activeById[eggId] = {
		Model = model,
		Zone = zoneName,
		ZoneConfig = zoneConfig,
		EggDef = eggDef,
		SpawnPosition = position,
		BaseY = position.Y,
		MoveSeed = rng:NextNumber(0, math.pi * 2),
	}
	return model
end

local function countEggs(zoneName)
	local count = 0
	for _, child in ipairs(eggFolder:GetChildren()) do
		if child:IsA("Model")
			and child:GetAttribute("EggSpawnerId") == EGG_SPAWNER_ID
			and child:GetAttribute("ZoneName") == zoneName
			and child:GetAttribute("HatchInProgress") ~= true then
			count += 1
		end
	end
	return count
end

local function copyRewardAttributes(fromObj, toObj)
	for key, value in pairs(fromObj:GetAttributes()) do
		local valueType = typeof(value)
		if valueType == "string" or valueType == "number" or valueType == "boolean" then
			toObj:SetAttribute(key, value)
		end
	end
end

local function getDisplayName(obj)
	local name = tostring(obj:GetAttribute("DisplayName") or obj:GetAttribute("BrainrotName") or obj.Name or "Brainrot")
	if name == "" or name == "Model" then
		return "Brainrot"
	end
	return name
end

local function playerAlreadyHasTool(player, uid)
	for _, container in ipairs({ player:FindFirstChild("Backpack"), player.Character, player:FindFirstChild("StarterGear") }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					local itemUid = item:GetAttribute("BrainrotUID") or item:GetAttribute("UID") or item:GetAttribute("InventoryUid")
					if itemUid and tostring(itemUid) == tostring(uid) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function createRewardTool(player, rewardNpc, mutationName, mutationInfo, baseMps)
	local uid = tostring(rewardNpc:GetAttribute("BrainrotUID") or HttpService:GenerateGUID(false))
	if playerAlreadyHasTool(player, uid) then
		return nil
	end

	local finalMps = math.max(1, math.floor((tonumber(baseMps) or 1) * (tonumber(mutationInfo.Multiplier) or 1)))
	local displayName = getDisplayName(rewardNpc)
	local tool = Instance.new("Tool")
	tool.Name = displayName
	tool.RequiresHandle = false
	tool.CanBeDropped = false

	copyRewardAttributes(rewardNpc, tool)
	tool:SetAttribute("IsBrainrot", true)
	tool:SetAttribute("BrainrotTool", true)
	tool:SetAttribute("InventoryOnly", true)
	tool:SetAttribute("OwnerUserId", player.UserId)
	tool:SetAttribute("CapturedByUserId", player.UserId)
	tool:SetAttribute("HatchedFromEgg", true)
	tool:SetAttribute("BrainrotUID", uid)
	tool:SetAttribute("UID", uid)
	tool:SetAttribute("DirectInventoryUid", uid)
	tool:SetAttribute("InventoryUid", uid)
	tool:SetAttribute("BrainrotName", displayName)
	tool:SetAttribute("DisplayName", displayName)
	tool:SetAttribute("Mutation", mutationName)
	tool:SetAttribute("MutationName", mutationName)
	tool:SetAttribute("MutationDisplayName", mutationName)
	tool:SetAttribute("MutationMultiplier", tonumber(mutationInfo.Multiplier) or 1)
	tool:SetAttribute("CashPerSecond", finalMps)
	tool:SetAttribute("MPS", finalMps)
	tool:SetAttribute("MoneyPerSecond", finalMps)
	tool:SetAttribute("CanPickup", false)
	tool:SetAttribute("PickupReady", false)
	tool:SetAttribute("ReadyToPickup", false)
	tool:SetAttribute("IsPlaced", false)
	tool:SetAttribute("Placed", false)

	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 3)
	tool.Parent = backpack or player
	return tool, finalMps
end

local function getRewardRarity(eggDef)
	return chooseWeightedWithLuck(eggDef.Rewards and eggDef.Rewards.Brainrots, eggDef.LuckBonus, eggDef.Rarity, false) or tostring(eggDef.Rarity or "Common")
end

local function getRewardMutation(eggDef)
	return chooseWeightedWithLuck(eggDef.Rewards and eggDef.Rewards.Mutations, eggDef.LuckBonus, eggDef.Rarity, true) or "Normal"
end

local function getRevealPool(api, templateZone)
	local pool = {}
	if api and api.GetTemplateSummaries then
		for index, summary in ipairs(api.GetTemplateSummaries(templateZone) or {}) do
			table.insert(pool, {
				id = tostring(summary.Name or ("Brainrot_" .. index)),
				name = tostring(summary.Name or "Brainrot"),
				displayName = tostring(summary.Name or "Brainrot"),
				rarity = tostring(summary.Rarity or "Common"),
				zoneName = templateZone,
			})
		end
	end
	return pool
end

local function playBreakEffect(egg)
	local root = getRoot(egg)
	if not root then
		return
	end

	local color = getRarityColor(egg:GetAttribute("Rarity"))
	local attachment = Instance.new("Attachment")
	attachment.Name = "EggBreakAttachment"
	attachment.Parent = root

	local particles = Instance.new("ParticleEmitter")
	particles.Name = "SoftShellBurst"
	particles.Color = ColorSequence.new(color:Lerp(Color3.fromRGB(255, 255, 255), 0.35), color)
	particles.LightEmission = 0.35
	particles.Lifetime = NumberRange.new(0.28, 0.55)
	particles.Speed = NumberRange.new(5, 9)
	particles.SpreadAngle = Vector2.new(90, 90)
	particles.Rate = 0
	particles.Texture = "rbxassetid://243098098"
	particles.Parent = attachment
	particles:Emit(18)

	for _, part in ipairs(egg:GetDescendants()) do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
				Size = part.Size * 1.08,
			}):Play()
		end
	end

	Debris:AddItem(attachment, 1.2)
end

local function finishEgg(player, egg, eggData)
	if not egg or not egg.Parent or egg:GetAttribute("HatchInProgress") == true then
		return
	end

	egg:SetAttribute("HatchInProgress", true)
	local api = getZoneApi()
	if not api then
		warn("[ZoneEggHatching] Zone template API unavailable.")
		egg:Destroy()
		return
	end

	local eggDef = eggData.EggDef
	local zoneConfig = eggData.ZoneConfig
	local templateZone = tostring(zoneConfig.TemplateZone or eggData.Zone or "Forest")
	local rewardRarity = getRewardRarity(eggDef)
	local template = api.ChooseTemplate and api.ChooseTemplate(templateZone, rewardRarity)
	if not template then
		warn("[ZoneEggHatching] No reward template for", templateZone, rewardRarity)
		egg:Destroy()
		return
	end

	local baseMps = api.GetRandomMPS and api.GetRandomMPS(api.Zones[templateZone] or {}, rewardRarity) or 25
	local rewardNpc = template:Clone()
	if api.PrepareNPC then
		api.PrepareNPC(rewardNpc, templateZone, rewardRarity, baseMps)
	end

	local mutationName = getRewardMutation(eggDef)
	local mutationInfo = getMutationInfo(mutationName)
	local tool, finalMps = createRewardTool(player, rewardNpc, mutationName, mutationInfo, baseMps)
	rewardNpc:Destroy()

	if not tool then
		egg:Destroy()
		return
	end

	local revealId = HttpService:GenerateGUID(false)
	local payload = {
		RevealId = revealId,
		revealId = revealId,
		EggId = tostring(egg:GetAttribute("EggId") or ""),
		EggName = tostring(eggDef.DisplayName or "Egg"),
		EggRarity = tostring(eggDef.Rarity or "Common"),
		LuckBonus = tonumber(eggDef.LuckBonus) or 0,
		LuckText = "Egg Luck: +" .. tostring(eggDef.LuckBonus or 0) .. "%",
		LuckHint = "Better odds for Rare Brainrots",
		EggHP = tonumber(eggDef.HP) or 100,
		EggSize = tonumber(eggDef.Size) or 1,
		EggBaseLuck = tonumber(eggDef.BaseLuck) or 0,
		EggHPLuckBonus = tonumber(eggDef.HPBonus) or 0,
		EggSizeLuckBonus = tonumber(eggDef.SizeBonus) or 0,
		ZoneName = eggData.Zone,
		ZoneDisplayName = tostring(zoneConfig.DisplayName or eggData.Zone),
		ResultName = tostring(tool:GetAttribute("DisplayName") or tool.Name),
		Rarity = rewardRarity,
		selectedRarity = rewardRarity,
		MPS = finalMps,
		CashPerSecond = finalMps,
		Mutation = mutationName,
		MutationDisplayName = mutationName,
		MutationColor = mutationInfo.Color,
		MutationMultiplier = mutationInfo.Multiplier,
		revealSource = "CleanEgg",
		possibleNPCs = getRevealPool(api, templateZone),
		selectedNPC = {
			id = tostring(tool:GetAttribute("TemplateName") or tool:GetAttribute("DisplayName") or tool.Name),
			name = tostring(tool:GetAttribute("BrainrotName") or tool.Name),
			displayName = tostring(tool:GetAttribute("DisplayName") or tool.Name),
			rarity = rewardRarity,
			zoneName = templateZone,
			mps = finalMps,
			mutation = mutationName,
			mutationDisplayName = mutationName,
		},
	}

	revealRemote:FireClient(player, payload)
	legacyRevealRemote:FireClient(player, payload)
	startNpcRevealRemote:FireClient(player, payload)

	playBreakEffect(egg)
	local eggId = egg:GetAttribute("EggId")
	if eggId then
		activeById[tostring(eggId)] = nil
	end

	task.delay(0.26, function()
		if egg and egg.Parent then
			egg:Destroy()
		end
	end)
end

local function damageEgg(player, egg, amount)
	if typeof(egg) ~= "Instance" then
		return false
	end
	if not egg:IsA("Model") then
		egg = egg:FindFirstAncestorWhichIsA("Model")
	end
	if not egg or egg:GetAttribute("EggSpawnerId") ~= EGG_SPAWNER_ID then
		return false
	end
	if egg:GetAttribute("HatchInProgress") == true then
		return true
	end

	local root = getRoot(egg)
	local character = player and player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not playerRoot or (root.Position - playerRoot.Position).Magnitude > 12 then
		return true
	end

	local key = tostring(player.UserId) .. ":" .. tostring(egg:GetAttribute("EggId") or egg)
	local now = os.clock()
	if lastDamageAt[key] and now - lastDamageAt[key] < DAMAGE_COOLDOWN then
		return true
	end
	lastDamageAt[key] = now

	local eggIdForChase = tostring(egg:GetAttribute("EggId") or "")
	local eggDataForChase = activeById[eggIdForChase]
	if eggDataForChase and egg:GetAttribute("CaptureChaseActive") ~= true then
		local chaseDuration = tonumber(eggDataForChase.EggDef.ChaseTime) or 16
		local serverTime = Workspace:GetServerTimeNow()
		egg:SetAttribute("CaptureChaseActive", true)
		egg:SetAttribute("CaptureChaseStartTime", serverTime)
		egg:SetAttribute("CaptureChaseEndTime", serverTime + chaseDuration)
		egg:SetAttribute("CaptureChaseDuration", chaseDuration)
		egg:SetAttribute("CaptureHunterUserId", player.UserId)
		egg:SetAttribute("CaptureHunterName", player.Name)
		eggDataForChase.ChaseTarget = player
		eggDataForChase.NextWanderAt = 0
	end

	local maxHP = tonumber(egg:GetAttribute("EggMaxHP")) or 100
	local hp = math.clamp(tonumber(egg:GetAttribute("EggHP")) or maxHP, 0, maxHP)
	local damage = math.max(1, tonumber(amount) or DEFAULT_DAMAGE)
	hp = math.max(0, hp - damage)

	egg:SetAttribute("EggHP", hp)
	egg:SetAttribute("CaptureHP", hp)

	local humanoid = egg:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = math.max(1, hp)
	end

	local body = egg:FindFirstChild("EggBody", true)
	if body and body:IsA("BasePart") then
		local oldSize = body.Size
		TweenService:Create(body, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = oldSize * 0.96 }):Play()
		task.delay(0.08, function()
			if body and body.Parent then
				TweenService:Create(body, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = oldSize }):Play()
			end
		end)
	end

	if hp <= 0 then
		local eggId = tostring(egg:GetAttribute("EggId") or "")
		local eggData = activeById[eggId]
		if eggData then
			finishEgg(player, egg, eggData)
		else
			egg:Destroy()
		end
	end

	return true
end

local function getPlayerRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getNearestPlayer(position, radius)
	local nearestPlayer = nil
	local nearestDistance = radius

	for _, player in ipairs(Players:GetPlayers()) do
		local root = getPlayerRoot(player)
		if root then
			local distance = (root.Position - position).Magnitude
			if distance <= nearestDistance then
				nearestPlayer = player
				nearestDistance = distance
			end
		end
	end

	return nearestPlayer, nearestDistance
end

local function startEggChase(eggData, player)
	local egg = eggData.Model
	if not egg or not egg.Parent or egg:GetAttribute("HatchInProgress") == true then
		return
	end
	if egg:GetAttribute("CaptureChaseActive") == true then
		eggData.ChaseTarget = player or eggData.ChaseTarget
		return
	end

	local now = Workspace:GetServerTimeNow()
	local duration = tonumber(eggData.EggDef.ChaseTime) or 16
	egg:SetAttribute("CaptureChaseActive", true)
	egg:SetAttribute("CaptureChaseStartTime", now)
	egg:SetAttribute("CaptureChaseEndTime", now + duration)
	egg:SetAttribute("CaptureChaseDuration", duration)
	egg:SetAttribute("CaptureHunterUserId", player and player.UserId or 0)
	egg:SetAttribute("CaptureHunterName", player and player.Name or "")
	eggData.ChaseTarget = player
	eggData.NextWanderAt = 0
end

local function escapeEgg(eggData)
	local egg = eggData.Model
	if not egg or not egg.Parent then
		return
	end

	egg:SetAttribute("HatchInProgress", true)
	egg:SetAttribute("CaptureChaseActive", false)
	egg:SetAttribute("CapturePanic", true)

	for _, part in ipairs(egg:GetDescendants()) do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
				Size = part.Size * 0.82,
			}):Play()
		end
	end

	local eggId = egg:GetAttribute("EggId")
	if eggId then
		activeById[tostring(eggId)] = nil
	end

	task.delay(0.25, function()
		if egg and egg.Parent then
			egg:Destroy()
		end
	end)
end

local function moveEggAway(eggData, dt)
	local egg = eggData.Model
	local root = getRoot(egg)
	if not egg or not egg.Parent or not root then
		return
	end

	local now = Workspace:GetServerTimeNow()
	local chaseActive = egg:GetAttribute("CaptureChaseActive") == true
	if chaseActive and now >= (tonumber(egg:GetAttribute("CaptureChaseEndTime")) or 0) then
		escapeEgg(eggData)
		return
	end

	local targetPlayer = eggData.ChaseTarget
	local targetRoot = targetPlayer and getPlayerRoot(targetPlayer)
	local radius = tonumber(eggData.EggDef.ChaseRadius) or 45
	if not targetRoot then
		targetPlayer, _ = getNearestPlayer(root.Position, radius)
		targetRoot = targetPlayer and getPlayerRoot(targetPlayer)
	end

	if not chaseActive then
		if targetRoot and (targetRoot.Position - root.Position).Magnitude <= radius then
			startEggChase(eggData, targetPlayer)
		else
			return
		end
	end

	if not targetRoot then
		return
	end

	local away = root.Position - targetRoot.Position
	if away.Magnitude < 1 then
		away = Vector3.new(math.cos(now + eggData.MoveSeed), 0, math.sin(now + eggData.MoveSeed))
	end
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.1 then
		away = Vector3.new(1, 0, 0)
	end

	local strafe = Vector3.new(-away.Z, 0, away.X).Unit * math.sin(now * 1.6 + eggData.MoveSeed) * 0.42
	local direction = (away.Unit + strafe).Unit
	local speed = tonumber(eggData.EggDef.Speed) or tonumber(egg:GetAttribute("EggSpeed")) or 12
	local nextPosition = root.Position + direction * speed * dt
	nextPosition = clampToZone(eggData.Zone, nextPosition)
	nextPosition = Vector3.new(nextPosition.X, eggData.BaseY or nextPosition.Y, nextPosition.Z)

	local bounce = math.sin(os.clock() * 10 + eggData.MoveSeed) * 0.16
	local lookAt = nextPosition + direction
	local targetCFrame = CFrame.new(nextPosition + Vector3.new(0, bounce, 0), Vector3.new(lookAt.X, nextPosition.Y + bounce, lookAt.Z))
	egg:PivotTo(targetCFrame)
end

local function spawnEgg(zoneName, zoneConfig)
	if countEggs(zoneName) >= (tonumber(zoneConfig.MaxEggs) or 6) then
		return false
	end

	local baseEggDef = chooseEgg(zoneConfig)
	if not baseEggDef then
		return false
	end

	local position = randomPointInsideZone(zoneName, zoneConfig)
	if not position then
		return false
	end

	createEggModel(zoneName, zoneConfig, rollEggStats(baseEggDef), position)
	return true
end

local function spawnInitial(zoneName, zoneConfig)
	for _ = 1, tonumber(zoneConfig.MaxEggs) or 6 do
		spawnEgg(zoneName, zoneConfig)
		task.wait(0.08)
	end
end

_G.CleanEggDamageApi = {
	DamageEgg = damageEgg,
	IsEgg = function(target)
		if typeof(target) ~= "Instance" then
			return false
		end
		local model = target:IsA("Model") and target or target:FindFirstAncestorWhichIsA("Model")
		return model and model:GetAttribute("EggSpawnerId") == EGG_SPAWNER_ID
	end,
}

eggFolder.ChildRemoved:Connect(function(child)
	local eggId = child:GetAttribute("EggId")
	if eggId then
		activeById[tostring(eggId)] = nil
	end

	local zoneName = child:GetAttribute("ZoneName")
	local zoneConfig = zoneName and EggConfig.Zones[tostring(zoneName)]
	if zoneConfig then
		task.delay(tonumber(zoneConfig.RespawnDelay) or 6, function()
			spawnEgg(tostring(zoneName), zoneConfig)
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for key, _ in pairs(lastDamageAt) do
		if string.sub(key, 1, #tostring(player.UserId)) == tostring(player.UserId) then
			lastDamageAt[key] = nil
		end
	end
end)

RunService.Heartbeat:Connect(function(dt)
	for eggId, eggData in pairs(activeById) do
		if not eggData.Model or not eggData.Model.Parent then
			activeById[eggId] = nil
		elseif eggData.Model:GetAttribute("HatchInProgress") ~= true then
			moveEggAway(eggData, math.min(dt, 0.08))
		end
	end
end)

task.spawn(function()
	local api = getZoneApi()
	if api and api.RefreshAreas then
		api.RefreshAreas(true)
	end

	task.wait(INITIAL_DELAY)

	for zoneName, zoneConfig in pairs(EggConfig.Zones) do
		if findWorkspaceDescendant(zoneName) then
			spawnInitial(zoneName, zoneConfig)
		elseif zoneName == "ForestMap1" then
			warn("[ZoneEggHatching] ForestMap1 was not found in Workspace. Eggs will wait until it exists.")
		end

		task.spawn(function()
			while true do
				if findWorkspaceDescendant(zoneName) then
					spawnEgg(zoneName, zoneConfig)
				end

				task.wait(tonumber(zoneConfig.SpawnInterval) or 8)
			end
		end)
	end
end)

print("[ZoneEggHatching] Loaded clean egg spawning, damage, rewards, and reveal dispatch.")
