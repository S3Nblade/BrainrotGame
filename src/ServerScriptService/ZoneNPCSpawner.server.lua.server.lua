--!nonstrict
-- ZoneNPCSpawner.server.lua
-- Put in: ServerScriptService
-- Uses Workspace > SpawnMap > Zones as the spawn-point folder.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local NPC_FOLDER = Workspace:WaitForChild("BrainrotNPCs")
local NPC_POOLS = ServerStorage:WaitForChild("BrainrotNPCPools")

local SpawnMap = Workspace:WaitForChild("SpawnMap")
local ZONE_PARTS_FOLDER = SpawnMap:WaitForChild("Zones")

local GLOBAL_SPAWN_INTERVAL = 3.5

local ZONES = {
	Starter = {
		MaxAlive = 7,
		NameAliases = { "starter", "start", "spawn" },
		Rarities = {
			{ "Common", 70 },
			{ "Rare", 25 },
			{ "Epic", 5 },
		},
		MPS = {
			Common = { 20, 60 },
			Rare = { 60, 130 },
			Epic = { 130, 230 },
		},
	},

	Forest = {
		MaxAlive = 8,
		NameAliases = { "forest", "Forest" },
		Rarities = {
			{ "Rare", 55 },
			{ "Epic", 35 },
			{ "Mythic", 10 },
		},
		MPS = {
			Rare = { 90, 180 },
			Epic = { 180, 350 },
			Mythic = { 350, 650 },
		},
	},

	Crystal = {
		MaxAlive = 8,
		NameAliases = { "crystal", "Crystal" },
		Rarities = {
			{ "Epic", 55 },
			{ "Mythic", 30 },
			{ "Legendary", 15 },
		},
		MPS = {
			Epic = { 250, 450 },
			Mythic = { 450, 800 },
			Legendary = { 800, 1400 },
		},
	},

	Lava = {
		MaxAlive = 8,
		NameAliases = { "lava", "Lava" },
		Rarities = {
			{ "Mythic", 50 },
			{ "Legendary", 35 },
			{ "Divine", 15 },
		},
		MPS = {
			Mythic = { 700, 1200 },
			Legendary = { 1200, 2200 },
			Divine = { 2200, 4000 },
		},
	},

	Galaxy = {
		MaxAlive = 6,
		NameAliases = { "galaxy", "Galaxy" },
		Rarities = {
			{ "Legendary", 35 },
			{ "Divine", 30 },
			{ "Celestial", 25 },
			{ "Godly", 10 },
		},
		MPS = {
			Legendary = { 2500, 4500 },
			Divine = { 4500, 8000 },
			Celestial = { 8000, 15000 },
			Godly = { 15000, 30000 },
		},
	},
}

local function normalizeName(name)
	return string.lower(tostring(name or ""))
end

local function nameMatchesZone(partName, zoneConfig)
	local cleanName = normalizeName(partName)

	for _, alias in ipairs(zoneConfig.NameAliases) do
		if cleanName == normalizeName(alias) then
			return true
		end
	end

	return false
end

local function getZoneSpawnParts(zoneName)
	local zoneConfig = ZONES[zoneName]
	if not zoneConfig then
		return {}
	end

	local result = {}

	for _, obj in ipairs(ZONE_PARTS_FOLDER:GetDescendants()) do
		if obj:IsA("BasePart") and nameMatchesZone(obj.Name, zoneConfig) then
			table.insert(result, obj)
		end
	end

	return result
end

local function chooseWeightedRarity(rarityList)
	local total = 0

	for _, pair in ipairs(rarityList) do
		total += pair[2]
	end

	if total <= 0 then
		return "Common"
	end

	local roll = math.random() * total
	local running = 0

	for _, pair in ipairs(rarityList) do
		running += pair[2]

		if roll <= running then
			return pair[1]
		end
	end

	return rarityList[1][1]
end

local function getTemplatesForRarity(rarity)
	local folder = NPC_POOLS:FindFirstChild(rarity)

	if not folder then
		warn("[ZoneNPCSpawner] Missing rarity folder:", rarity)
		return {}
	end

	local templates = {}

	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Model") then
			table.insert(templates, obj)
		end
	end

	return templates
end

local function chooseTemplate(rarity)
	local templates = getTemplatesForRarity(rarity)

	if #templates <= 0 then
		warn("[ZoneNPCSpawner] No templates inside rarity folder:", rarity)
		return nil
	end

	return templates[math.random(1, #templates)]
end

local function countAliveInZone(zoneName)
	local count = 0

	for _, npc in ipairs(NPC_FOLDER:GetChildren()) do
		if npc:IsA("Model") then
			local isPlaced = npc:GetAttribute("IsPlaced") == true
			local heldBy = npc:GetAttribute("HeldBy")

			if not isPlaced and heldBy == nil and npc:GetAttribute("SpawnZone") == zoneName then
				count += 1
			end
		end
	end

	return count
end

local function getRandomMPS(zoneConfig, rarity)
	local range = zoneConfig.MPS[rarity]

	if not range then
		return 50
	end

	return math.random(range[1], range[2])
end

local function getSellPriceFromMPS(mps, rarity)
	local rarityMultiplier = {
		Common = 8,
		Rare = 10,
		Epic = 12,
		Mythic = 15,
		Legendary = 20,
		Divine = 25,
		Celestial = 35,
		Godly = 50,
	}

	local mult = rarityMultiplier[rarity] or 10
	return math.floor(mps * mult)
end

local function prepareNPC(npc, zoneName, rarity, mps)
	npc:SetAttribute("NPCId", HttpService:GenerateGUID(false))
	npc:SetAttribute("SpawnZone", zoneName)
	npc:SetAttribute("Rarity", rarity)
	npc:SetAttribute("MPS", mps)
	npc:SetAttribute("Earned", 0)
	npc:SetAttribute("SellPrice", getSellPriceFromMPS(mps, rarity))

	npc:SetAttribute("IsPlaced", false)
	npc:SetAttribute("HeldBy", nil)
	npc:SetAttribute("PlacedOwnerUserId", nil)
	npc:SetAttribute("AssignedHouseGoal", nil)

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = false
			obj.CanCollide = true
		end
	end

	local root = npc:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = false
		root.CanCollide = true
	end
end

local function spawnNPCInZone(zoneName)
	local zoneConfig = ZONES[zoneName]
	if not zoneConfig then
		return
	end

	local spawnParts = getZoneSpawnParts(zoneName)

	if #spawnParts <= 0 then
		return
	end

	if countAliveInZone(zoneName) >= zoneConfig.MaxAlive then
		return
	end

	local rarity = chooseWeightedRarity(zoneConfig.Rarities)
	local template = chooseTemplate(rarity)

	if not template then
		return
	end

	local spawnPart = spawnParts[math.random(1, #spawnParts)]
	local npc = template:Clone()
	local mps = getRandomMPS(zoneConfig, rarity)

	prepareNPC(npc, zoneName, rarity, mps)

	npc:PivotTo(spawnPart.CFrame + Vector3.new(0, 4, 0))
	npc.Parent = NPC_FOLDER

	print(
		"[ZoneNPCSpawner] Spawned",
		npc.Name,
		"Zone:",
		zoneName,
		"Rarity:",
		rarity,
		"MPS:",
		mps
	)
end

local function spawnInitialBatch()
	for zoneName, config in pairs(ZONES) do
		local spawnParts = getZoneSpawnParts(zoneName)

		if #spawnParts > 0 then
			local amount = math.max(2, math.floor(config.MaxAlive / 2))

			for _ = 1, amount do
				spawnNPCInZone(zoneName)
				task.wait(0.08)
			end
		else
			warn("[ZoneNPCSpawner] No spawn parts found for zone:", zoneName)
		end
	end
end

task.delay(1, function()
	spawnInitialBatch()
end)

task.spawn(function()
	while true do
		for zoneName, _config in pairs(ZONES) do
			spawnNPCInZone(zoneName)
			task.wait(0.15)
		end

		task.wait(GLOBAL_SPAWN_INTERVAL)
	end
end)

print("[ZoneNPCSpawner] loaded using Workspace.SpawnMap.Zones")