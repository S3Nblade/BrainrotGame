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

local function chooseEgg(zoneConfig)
	local total = 0
	for _, eggDef in ipairs(zoneConfig.Eggs or {}) do
		total += math.max(0, tonumber(eggDef.Weight) or 0)
	end
	if total <= 0 then
		return nil
	end

	local roll = rng:NextNumber(0, total)
	local running = 0
	for _, eggDef in ipairs(zoneConfig.Eggs) do
		running += math.max(0, tonumber(eggDef.Weight) or 0)
		if roll <= running then
			return eggDef
		end
	end
	return zoneConfig.Eggs[1]
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
	gui.Size = UDim2.fromOffset(155, 70)
	gui.StudsOffset = Vector3.new(0, 3.25 * (tonumber(eggDef.Size) or 1), 0)
	gui.MaxDistance = 55
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = root

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = Color3.fromRGB(17, 20, 30)
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Size = UDim2.fromScale(1, 1)
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = getRarityColor(eggDef.Rarity)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.1
	stroke.Parent = card

	local name = Instance.new("TextLabel")
	name.Name = "EggName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.06, 0.04)
	name.Size = UDim2.fromScale(0.88, 0.3)
	name.Font = Enum.Font.GothamBold
	name.Text = tostring(eggDef.DisplayName or "Egg")
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextScaled = true
	name.TextWrapped = true
	name.Parent = card

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HPText"
	hpText.BackgroundTransparency = 1
	hpText.Position = UDim2.fromScale(0.06, 0.34)
	hpText.Size = UDim2.fromScale(0.88, 0.22)
	hpText.Font = Enum.Font.GothamMedium
	hpText.Text = "HP: " .. tostring(eggDef.HP) .. "/" .. tostring(eggDef.HP)
	hpText.TextColor3 = Color3.fromRGB(225, 232, 244)
	hpText.TextScaled = true
	hpText.Parent = card

	local barBack = Instance.new("Frame")
	barBack.Name = "HPBarBack"
	barBack.BackgroundColor3 = Color3.fromRGB(38, 44, 60)
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.fromScale(0.08, 0.59)
	barBack.Size = UDim2.fromScale(0.84, 0.12)
	barBack.Parent = card
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
	luck.Position = UDim2.fromScale(0.06, 0.72)
	luck.Size = UDim2.fromScale(0.88, 0.22)
	luck.Font = Enum.Font.GothamBold
	luck.Text = "Luck +" .. tostring(eggDef.LuckBonus or 0) .. "%"
	luck.TextColor3 = getRarityColor(eggDef.Rarity)
	luck.TextScaled = true
	luck.Parent = card

	local function refresh()
		local maxHP = tonumber(model:GetAttribute("EggMaxHP")) or tonumber(eggDef.HP) or 1
		local hp = math.clamp(tonumber(model:GetAttribute("EggHP")) or maxHP, 0, maxHP)
		hpText.Text = "HP: " .. tostring(math.ceil(hp)) .. "/" .. tostring(math.ceil(maxHP))
		fill.Size = UDim2.fromScale(maxHP > 0 and hp / maxHP or 0, 1)
	end

	model:GetAttributeChangedSignal("EggHP"):Connect(refresh)
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
	activeById[eggId] = { Model = model, Zone = zoneName, ZoneConfig = zoneConfig, EggDef = eggDef }
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
	return chooseWeighted(eggDef.Rewards and eggDef.Rewards.Brainrots) or tostring(eggDef.Rarity or "Common")
end

local function getRewardMutation(eggDef)
	return chooseWeighted(eggDef.Rewards and eggDef.Rewards.Mutations) or "Normal"
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
		LuckText = "Luck Bonus: +" .. tostring(eggDef.LuckBonus or 0) .. "%",
		LuckHint = "Better odds for Rare Brainrots",
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

local function spawnEgg(zoneName, zoneConfig)
	if countEggs(zoneName) >= (tonumber(zoneConfig.MaxEggs) or 6) then
		return false
	end

	local eggDef = chooseEgg(zoneConfig)
	if not eggDef then
		return false
	end

	local position = randomPointInsideZone(zoneName, zoneConfig)
	if not position then
		return false
	end

	createEggModel(zoneName, zoneConfig, eggDef, position)
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
