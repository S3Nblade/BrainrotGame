--!nonstrict
-- ServerScriptService/BrainrotCinematicPickup.server.lua
-- SAFE VERSION:
-- Defeat NPC -> E prompt appears -> press E -> mutation cinematic -> mutated tool goes to Backpack.
--
-- Important:
-- This script does NOT clone the visual NPC into the tool.
-- The tool is attribute-only, so it will not spawn the NPC at the old capture location.
-- BrainrotCore should handle placing the real visual on your plot.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local PROMPT_NAME = "BrainrotCinematicCapturePrompt"
local PROMPT_ACTION_TEXT = "Capture"
local PROMPT_DISTANCE = 13
local SCAN_EVERY = 2
local DISCOVERY_STORE_NAME = "BrainrotDiscoveries_v1"
local START_NPC_REVEAL_REMOTE_NAME = "StartNPCReveal"

local npcFolder = Workspace:FindFirstChild(NPC_FOLDER_NAME)
if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = NPC_FOLDER_NAME
	npcFolder.Parent = Workspace
end

local activePickups = {}
local connectedPrompts = {}
local watchedNpcs = {}
local discoveryStore = DataStoreService:GetDataStore(DISCOVERY_STORE_NAME)
local BrainrotConfig = nil

do
	local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
	local configModule = sharedFolder and sharedFolder:FindFirstChild("BrainrotConfig")
	if configModule and configModule:IsA("ModuleScript") then
		local ok, result = pcall(require, configModule)
		if ok and type(result) == "table" then
			BrainrotConfig = result
		else
			warn("[BrainrotCinematicPickup] BrainrotConfig failed to load:", result)
		end
	end
end

local function log(...)
	print("[BrainrotCinematicPickup]", ...)
end

local function warnLog(...)
	warn("[BrainrotCinematicPickup]", ...)
end

local function getRoot(model)
	if not model then
		return nil
	end

	return model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function isPlayerAlive(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function playerCloseEnough(player, npc)
	local character = player and player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local npcRoot = getRoot(npc)

	if not playerRoot or not npcRoot then
		return false
	end

	return (playerRoot.Position - npcRoot.Position).Magnitude <= (PROMPT_DISTANCE + 4)
end

local function getUid(instance)
	return instance:GetAttribute("BrainrotUID")
		or instance:GetAttribute("UID")
		or instance:GetAttribute("BrainrotUid")
		or instance:GetAttribute("DirectInventoryUid")
		or instance:GetAttribute("InventoryUid")
end

local function ensureUid(instance)
	local uid = getUid(instance)

	if uid == nil or tostring(uid) == "" then
		uid = HttpService:GenerateGUID(false)
	end

	uid = tostring(uid)

	instance:SetAttribute("BrainrotUID", uid)
	instance:SetAttribute("UID", uid)
	instance:SetAttribute("BrainrotUid", uid)
	instance:SetAttribute("DirectInventoryUid", uid)
	instance:SetAttribute("InventoryUid", uid)

	return uid
end

local function normalizeDiscoveryMap(raw)
	local map = {}
	if type(raw) == "string" and raw ~= "" then
		local decoded = nil
		local ok = pcall(function()
			decoded = HttpService:JSONDecode(raw)
		end)
		if ok then
			raw = decoded
		end
	end

	if type(raw) ~= "table" then
		return map
	end

	if type(raw.discovered) == "table" then
		raw = raw.discovered
	end

	for key, value in pairs(raw) do
		if value == true then
			map[tostring(key)] = true
		elseif type(value) == "string" and value ~= "" then
			map[tostring(value)] = true
		elseif type(value) == "table" then
			local id = value.id or value.Id or value.configId or value.BrainrotConfigId
			if id then
				map[tostring(id)] = true
			end
		end
	end

	return map
end

local function countDiscoveries(map)
	local count = 0
	for _, value in pairs(map or {}) do
		if value == true then
			count += 1
		end
	end
	return count
end

local function setDiscoveryAttributes(player, map)
	local encoded = "{}"
	pcall(function()
		encoded = HttpService:JSONEncode(map or {})
	end)

	player:SetAttribute("BrainrotDiscoveredCount", countDiscoveries(map))
	player:SetAttribute("BrainrotDiscoveredJson", encoded)
end

local function getDiscoveryId(instance)
	local ids = {
		instance:GetAttribute("BrainrotConfigId"),
		instance:GetAttribute("BrainrotDiscoveryId"),
		instance:GetAttribute("ModelName"),
		instance:GetAttribute("BrainrotModelName"),
		instance:GetAttribute("TemplateName"),
		instance:GetAttribute("DisplayName"),
		instance:GetAttribute("BrainrotName"),
		instance.Name,
	}

	for _, id in ipairs(ids) do
		if id ~= nil and tostring(id) ~= "" then
			return tostring(id)
		end
	end

	return "Brainrot"
end

local function markDiscovery(player, instance)
	local discoveryId = getDiscoveryId(instance)
	local current = normalizeDiscoveryMap(player:GetAttribute("BrainrotDiscoveredJson"))
	local wasSeen = current[discoveryId] == true
	current[discoveryId] = true
	setDiscoveryAttributes(player, current)

	task.spawn(function()
		local key = "player_" .. tostring(player.UserId)
		local ok, err = pcall(function()
			discoveryStore:UpdateAsync(key, function(old)
				local merged = normalizeDiscoveryMap(old)
				merged[discoveryId] = true
				return merged
			end)
		end)

		if not ok then
			warnLog("Failed to save discovery for", player.Name, discoveryId, err)
		end
	end)

	return not wasSeen, discoveryId, countDiscoveries(current)
end

local function emitGameplayEvent(eventName, player, payload)
	local event = ServerStorage:FindFirstChild("BrainrotGameplayEvent")
	if event and event:IsA("BindableEvent") then
		event:Fire(eventName, player, payload or {})
	end
end

local function getStartNpcRevealRemote()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = ReplicatedStorage
	end

	local remote = remotes:FindFirstChild(START_NPC_REVEAL_REMOTE_NAME)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if remote then
		remote:Destroy()
	end

	remote = Instance.new("RemoteEvent")
	remote.Name = START_NPC_REVEAL_REMOTE_NAME
	remote.Parent = remotes
	return remote
end

local function getRevealPool(selectedConfigId)
	local pool = {}
	if type(BrainrotConfig) ~= "table" or type(BrainrotConfig.List) ~= "table" then
		return pool
	end

	for _, entry in ipairs(BrainrotConfig.List) do
		if #pool >= 8 then
			break
		end

		local id = tostring(entry.Id or "")
		if id ~= "" and id ~= tostring(selectedConfigId or "") then
			table.insert(pool, {
				id = id,
				configId = id,
				BrainrotConfigId = id,
				modelName = tostring(entry.ModelName or ""),
				ModelName = tostring(entry.ModelName or ""),
				name = tostring(entry.DisplayName or id),
				displayName = tostring(entry.DisplayName or id),
				rarity = tostring(entry.Rarity or "Common"),
				CashPerSecond = tonumber(entry.CashPerSecond) or 0,
				showcaseScale = tonumber(entry.ShowcaseScale) or 1,
				ShowcaseScale = tonumber(entry.ShowcaseScale) or 1,
			})
		end
	end

	return pool
end

local function getBrainrotName(npc)
	local name =
		npc:GetAttribute("DisplayName")
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

local function isPlacedOrInventory(npc)
	if npc:GetAttribute("InventoryOnly") == true then
		return true
	end

	if npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true then
		return true
	end

	if npc:GetAttribute("PlacedOwnerUserId") ~= nil then
		return true
	end

	if npc:GetAttribute("AssignedSlotId") ~= nil then
		return true
	end

	if npc:GetAttribute("AssignedSlotPath") ~= nil then
		return true
	end

	return false
end

local function isWildNpc(npc)
	if not npc or not npc:IsA("Model") then
		return false
	end

	if not npc:IsDescendantOf(npcFolder) then
		return false
	end

	if npc:GetAttribute("EggBrainrot") == true then
		return false
	end

	if isPlacedOrInventory(npc) then
		return false
	end

	return true
end

local function isDefeated(npc)
	if not isWildNpc(npc) then
		return false
	end

	if npc:GetAttribute("MutationRevealRunning") == true then
		return false
	end

	if npc:GetAttribute("CaptureStunned") == true then
		return true
	end

	if npc:GetAttribute("CanPickup") == true
		or npc:GetAttribute("CanPickUp") == true
		or npc:GetAttribute("PickupReady") == true
		or npc:GetAttribute("ReadyToPick") == true
		or npc:GetAttribute("ReadyToPickup") == true
		or npc:GetAttribute("ReadyToPickUp") == true
		or npc:GetAttribute("Defeated") == true
		or npc:GetAttribute("IsDefeated") == true
		or npc:GetAttribute("Stunned") == true
		or npc:GetAttribute("IsStunned") == true then
		return true
	end

	local captureHp = tonumber(npc:GetAttribute("CaptureHP"))
	if captureHp ~= nil and captureHp <= 0 then
		return true
	end

	local hp =
		tonumber(npc:GetAttribute("HP"))
		or tonumber(npc:GetAttribute("Health"))
		or tonumber(npc:GetAttribute("CurrentHP"))
		or tonumber(npc:GetAttribute("CurrentHealth"))

	if hp ~= nil and hp <= 0 then
		return true
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return true
	end

	return false
end

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

local function copyAttributes(fromInstance, toInstance)
	for key, value in pairs(fromInstance:GetAttributes()) do
		local valueType = typeof(value)

		if not BLOCKED_TOOL_ATTRIBUTES[key] then
			if valueType == "string" or valueType == "number" or valueType == "boolean" then
				pcall(function()
					toInstance:SetAttribute(key, value)
				end)
			end
		end
	end
end

local function playerAlreadyHasTool(player, uid)
	if not uid then
		return false
	end

	local containers = {
		player:FindFirstChild("Backpack"),
		player.Character,
		player:FindFirstChild("StarterGear"),
	}

	for _, container in ipairs(containers) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") then
					local childUid = getUid(child)
					if childUid and tostring(childUid) == tostring(uid) then
						return true
					end
				end
			end
		end
	end

	return false
end

local function createBrainrotTool(player, npc)
	local uid = ensureUid(npc)

	if playerAlreadyHasTool(player, uid) then
		warnLog("Player already has tool for UID:", uid)
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
	tool:SetAttribute("PlacedOwnerUserId", nil)
	tool:SetAttribute("AssignedSlotId", nil)
	tool:SetAttribute("AssignedSlotFloor", nil)
	tool:SetAttribute("AssignedSlotPath", nil)

	tool:SetAttribute("OwnerUserId", player.UserId)
	tool:SetAttribute("OwnerName", player.Name)
	tool:SetAttribute("HeldOwnerUserId", player.UserId)

	tool:SetAttribute("BrainrotUID", uid)
	tool:SetAttribute("UID", uid)
	tool:SetAttribute("BrainrotUid", uid)
	tool:SetAttribute("DirectInventoryUid", uid)
	tool:SetAttribute("InventoryUid", uid)

	local finalName = getBrainrotName(npc)
	tool.Name = finalName
	tool:SetAttribute("BrainrotName", finalName)
	tool:SetAttribute("DisplayName", finalName)

	local mps =
		tonumber(npc:GetAttribute("CashPerSecond"))
		or tonumber(npc:GetAttribute("MPS"))
		or 1

	tool:SetAttribute("CashPerSecond", mps)
	tool:SetAttribute("MPS", mps)

	-- Keep template name stable for BrainrotCore/database restore.
	if tool:GetAttribute("TemplateName") == nil then
		tool:SetAttribute("TemplateName", npc:GetAttribute("TemplateName") or npc.Name)
	end

	-- CRITICAL:
	-- Do NOT put a cloned model/visual inside this tool.
	-- That caused the NPC to appear at its original capture position.
	-- Clean capture/defeated state from inventory tool.
	-- These attrs are only for wild defeated NPCs, never tools.
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

	tool:SetAttribute("InventoryOnly", true)
	tool:SetAttribute("IsPlaced", false)
	tool:SetAttribute("Placed", false)
	tool:SetAttribute("PlacedOwnerUserId", nil)
	tool:SetAttribute("AssignedSlotId", nil)
	tool:SetAttribute("AssignedSlotFloor", nil)
	tool:SetAttribute("AssignedSlotPath", nil)
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		tool.Parent = backpack
	else
		tool.Parent = player
	end

	return tool
end

local function buildRevealPayload(npc, tool, isNewDiscovery, discoveryId, discoveredCount)
	local name = getBrainrotName(npc)
	local rarity = tostring(tool:GetAttribute("Rarity") or npc:GetAttribute("Rarity") or "Common")
	local mutation = tostring(tool:GetAttribute("Mutation") or npc:GetAttribute("Mutation") or "Normal")
	local mps = tonumber(tool:GetAttribute("CashPerSecond")) or tonumber(tool:GetAttribute("MPS")) or 1
	local configId = tool:GetAttribute("BrainrotConfigId")
	local modelName = tool:GetAttribute("ModelName") or tool:GetAttribute("BrainrotModelName")
	local revealId = HttpService:GenerateGUID(false)

	return {
		RevealId = revealId,
		revealId = revealId,
		EggName = "Captured Brainrot",
		ResultName = name,
		BrainrotConfigId = configId,
		BrainrotDiscoveryId = discoveryId,
		ModelName = modelName,
		ShowcaseScale = tool:GetAttribute("ShowcaseScale"),
		Rarity = rarity,
		selectedRarity = rarity,
		MPS = mps,
		CashPerSecond = mps,
		Mutation = mutation,
		MutationDisplayName = tostring(tool:GetAttribute("MutationDisplayName") or mutation),
		MutationMultiplier = tonumber(tool:GetAttribute("MutationMultiplier")) or 1,
		isNew = isNewDiscovery,
		IsNew = isNewDiscovery,
		FirstTime = isNewDiscovery,
		DiscoveredCount = discoveredCount,
		revealSource = "OriginalChase",
		possibleNPCs = getRevealPool(configId),
		selectedNPC = {
			id = tostring(configId or discoveryId or name),
			configId = configId,
			BrainrotConfigId = configId,
			modelName = modelName,
			ModelName = modelName,
			name = name,
			displayName = name,
			rarity = rarity,
			mps = mps,
			CashPerSecond = mps,
			showcaseScale = tool:GetAttribute("ShowcaseScale"),
			ShowcaseScale = tool:GetAttribute("ShowcaseScale"),
			mutation = mutation,
			mutationDisplayName = tostring(tool:GetAttribute("MutationDisplayName") or mutation),
		},
	}
end

local function fireNpcReveal(player, payload)
	local remote = getStartNpcRevealRemote()
	remote:FireClient(player, payload)
end

local function fireCatchFeedback(player, npc, tool, isNewDiscovery, discoveryId, discoveredCount)
	local remote = ReplicatedStorage:FindFirstChild("BrainrotCatchFeedback")
	if remote and remote:IsA("RemoteEvent") then
		pcall(function()
			remote:FireClient(player, {
				Name = getBrainrotName(npc),
				BrainrotName = getBrainrotName(npc),
				Rarity = tostring(npc:GetAttribute("Rarity") or "Common"),
				Mutation = tostring(npc:GetAttribute("Mutation") or "Normal"),
				MutationDisplayName = tostring(npc:GetAttribute("MutationDisplayName") or npc:GetAttribute("Mutation") or "Normal"),
				MutationMultiplier = tonumber(npc:GetAttribute("MutationMultiplier")) or 1,
				CashPerSecond = tonumber(npc:GetAttribute("CashPerSecond")) or tonumber(npc:GetAttribute("MPS")) or 1,
				BrainrotConfigId = tool:GetAttribute("BrainrotConfigId"),
				BrainrotDiscoveryId = discoveryId,
				FirstDiscovery = isNewDiscovery,
				IsNew = isNewDiscovery,
				DiscoveredCount = discoveredCount,
				Tool = tool,
			})
		end)
	end
end

local function safelyDestroyWildNpc(npc)
	if not npc or not npc.Parent then
		return
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			obj.Enabled = false
		elseif obj:IsA("BasePart") then
			obj.CanTouch = false
			obj.CanCollide = false
			obj.CanQuery = false
		end
	end

	npc:Destroy()
end

local function captureNpc(player, npc, prompt)
	if activePickups[npc] then
		return
	end

	if not player or not player.Parent then
		return
	end

	if not isPlayerAlive(player) then
		warnLog("Tried to capture while not alive:", player.Name)
		return
	end

	if not npc or not npc.Parent then
		return
	end

	if not playerCloseEnough(player, npc) then
		warnLog("Tried to capture from too far away:", player.Name, npc.Name)
		return
	end

	if not isDefeated(npc) then
		warnLog("Tried to capture but NPC is not defeated:", npc:GetFullName())
		return
	end

	activePickups[npc] = true

	if prompt then
		prompt.Enabled = false
	end

	local okReveal = true

	if _G.BrainrotMutationReveal_BeginPickup then
		okReveal = _G.BrainrotMutationReveal_BeginPickup(player, npc)
	else
		warnLog("_G.BrainrotMutationReveal_BeginPickup missing. Capturing without cinematic.")
	end

	if okReveal == false then
		activePickups[npc] = nil

		if prompt and prompt.Parent then
			prompt.Enabled = true
		end

		return
	end

	if not npc or not npc.Parent then
		activePickups[npc] = nil
		return
	end

	local tool = createBrainrotTool(player, npc)

	if tool then
		local isNewDiscovery, discoveryId, discoveredCount = markDiscovery(player, tool)
		tool:SetAttribute("BrainrotDiscoveryId", discoveryId)
		tool:SetAttribute("FirstDiscovery", isNewDiscovery)
		tool:SetAttribute("DiscoveredByUserId", player.UserId)

		local revealPayload = buildRevealPayload(npc, tool, isNewDiscovery, discoveryId, discoveredCount)
		fireCatchFeedback(player, npc, tool, isNewDiscovery, discoveryId, discoveredCount)
		fireNpcReveal(player, revealPayload)
		emitGameplayEvent("CaptureCompleted", player, {
			source = "OriginalChase",
			brainrotId = tool:GetAttribute("BrainrotConfigId"),
			discoveryId = discoveryId,
			displayName = tool:GetAttribute("DisplayName") or tool.Name,
			rarity = tostring(tool:GetAttribute("Rarity") or "Common"),
			mutation = tostring(tool:GetAttribute("Mutation") or "Normal"),
			cashPerSecond = tonumber(tool:GetAttribute("CashPerSecond")) or tonumber(tool:GetAttribute("MPS")) or 1,
			isNew = isNewDiscovery,
			discoveredCount = discoveredCount,
		})

		log("Captured:", player.Name, tool.Name, "Mutation:", tostring(tool:GetAttribute("Mutation") or "Normal"))

		safelyDestroyWildNpc(npc)
	else
		warnLog("Failed to create tool for:", player.Name, npc.Name)

		if prompt and prompt.Parent then
			prompt.Enabled = true
		end
	end

	activePickups[npc] = nil
end

local function ensurePrompt(npc)
	if not isDefeated(npc) then
		local oldPrompt = npc:FindFirstChild(PROMPT_NAME, true)
		if oldPrompt and oldPrompt:IsA("ProximityPrompt") then
			oldPrompt.Enabled = false
		end

		return
	end

	local root = getRoot(npc)
	if not root then
		return
	end

	local prompt = root:FindFirstChild(PROMPT_NAME)

	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.ActionText = PROMPT_ACTION_TEXT
		prompt.ObjectText = getBrainrotName(npc)
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
	end

	prompt.ActionText = PROMPT_ACTION_TEXT
	prompt.ObjectText = getBrainrotName(npc)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true

	if connectedPrompts[prompt] then
		return
	end

	connectedPrompts[prompt] = true

	prompt.Triggered:Connect(function(triggeringPlayer)
		captureNpc(triggeringPlayer, npc, prompt)
	end)
end

local function watchNpc(npc)
	if not npc:IsA("Model") then
		return
	end
	if watchedNpcs[npc] then
		return
	end

	watchedNpcs[npc] = true

	npc.AttributeChanged:Connect(function()
		task.defer(function()
			if npc and npc.Parent then
				ensurePrompt(npc)
			end
		end)
	end)

	task.defer(function()
		ensurePrompt(npc)
	end)
end

npcFolder.ChildAdded:Connect(function(child)
	watchNpc(child)
end)

npcFolder.ChildRemoved:Connect(function(child)
	watchedNpcs[child] = nil
	activePickups[child] = nil
end)

for _, child in ipairs(npcFolder:GetChildren()) do
	watchNpc(child)
end

task.spawn(function()
	while true do
		for _, npc in ipairs(npcFolder:GetChildren()) do
			if npc:IsA("Model") then
				ensurePrompt(npc)
			end
		end

		task.wait(SCAN_EVERY)
	end
end)

print("[BrainrotCinematicPickup] Loaded SAFE attribute-only version. No tool visual clone.")
