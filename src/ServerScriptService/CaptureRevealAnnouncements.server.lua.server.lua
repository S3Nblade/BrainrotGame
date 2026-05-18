--!nonstrict
-- ServerScriptService/CaptureRevealAnnouncements.server.lua
-- Safe rare capture announcement system.
-- Fixes:
-- 1. No startup spam from saved/restored NPCs.
-- 2. Announces only new captures after player loads.
-- 3. Server announcement for Epic+ captures.
-- 4. Optional rarity reveal still fires for new captures.
-- 5. Includes server-side test RemoteFunction.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local RARE_ANNOUNCE_MIN_RARITY = "Epic"

-- Prevent restored save data from being treated as fresh captures.
local PLAYER_CAPTURE_IGNORE_SECONDS = 8

local RARITY_ORDER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Secret = 7,
	Godly = 8,
	Exclusive = 9,
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(220, 220, 220),
	Uncommon = Color3.fromRGB(90, 255, 120),
	Rare = Color3.fromRGB(60, 150, 255),
	Epic = Color3.fromRGB(190, 80, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
	Secret = Color3.fromRGB(40, 40, 40),
	Godly = Color3.fromRGB(255, 255, 90),
	Exclusive = Color3.fromRGB(255, 90, 210),
}

local function getRemotesFolder()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end

	return folder
end

local function ensureRemoteEvent(name)
	local folder = getRemotesFolder()
	local existing = folder:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteEvent") then
			return existing
		end

		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function ensureRemoteFunction(name)
	local folder = getRemotesFolder()
	local existing = folder:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteFunction") then
			return existing
		end

		existing:Destroy()
	end

	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local rarityRevealRemote = ensureRemoteEvent("RarityReveal")
local announcementRemote = ensureRemoteEvent("ServerAnnouncement")
local testAnnouncementFunction = ensureRemoteFunction("TestServerAnnouncement")

local npcFolder = Workspace:FindFirstChild(NPC_FOLDER_NAME)
if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = NPC_FOLDER_NAME
	npcFolder.Parent = Workspace
end

local playerJoinTime = {}
local sentByKey = {}
local ignoredInitialInstances = {}

local function colorToPayload(color)
	return {
		R = math.floor(color.R * 255),
		G = math.floor(color.G * 255),
		B = math.floor(color.B * 255),
	}
end

local function normalizeRarity(rarity)
	rarity = tostring(rarity or "Common")

	for known in pairs(RARITY_ORDER) do
		if string.lower(known) == string.lower(rarity) then
			return known
		end
	end

	return "Common"
end

local function getRarity(instance)
	return normalizeRarity(
		instance:GetAttribute("Rarity")
			or instance:GetAttribute("BrainrotRarity")
			or instance:GetAttribute("BaseRarity")
			or instance:GetAttribute("CurrentRarity")
			or instance:GetAttribute("Tier")
			or "Common"
	)
end

local function getStrongId(instance)
	return instance:GetAttribute("BrainrotUID")
		or instance:GetAttribute("UID")
		or instance:GetAttribute("BrainrotUid")
		or instance:GetAttribute("DirectInventoryUid")
		or instance:GetAttribute("InventoryUid")
		or instance:GetAttribute("ToolUID")
end

local function getBrainrotName(instance)
	return tostring(
		instance:GetAttribute("DisplayName")
			or instance:GetAttribute("BrainrotName")
			or instance:GetAttribute("BaseBrainrotName")
			or instance:GetAttribute("OriginalBrainrotName")
			or instance:GetAttribute("TemplateName")
			or instance.Name
			or "Brainrot"
	)
end

local function getMutation(instance)
	local mutation =
		instance:GetAttribute("Mutation")
		or instance:GetAttribute("MutationName")
		or instance:GetAttribute("ActiveMutation")
		or instance:GetAttribute("MutationType")
		or instance:GetAttribute("CurrentMutation")

	if mutation == nil or tostring(mutation) == "" then
		return "Normal"
	end

	return tostring(mutation)
end

local function getMps(instance)
	return tonumber(instance:GetAttribute("CashPerSecond"))
		or tonumber(instance:GetAttribute("MPS"))
		or tonumber(instance:GetAttribute("MoneyPerSecond"))
		or 1
end

local function shouldAnnounce(rarity)
	return (RARITY_ORDER[rarity] or 1) >= (RARITY_ORDER[RARE_ANNOUNCE_MIN_RARITY] or 4)
end

local function isBrainrotInstance(instance)
	if not instance then
		return false
	end

	if instance:GetAttribute("IsBrainrot") == true
		or instance:GetAttribute("BrainrotTool") == true
		or instance:GetAttribute("BrainrotUID") ~= nil
		or instance:GetAttribute("UID") ~= nil
		or instance:GetAttribute("Rarity") ~= nil
		or instance:GetAttribute("BrainrotRarity") ~= nil
		or instance:GetAttribute("CashPerSecond") ~= nil
		or instance:GetAttribute("MPS") ~= nil then
		return true
	end

	local n = string.lower(instance.Name)
	return string.find(n, "brainrot") ~= nil
end

local function getOwnerPlayerFromInstance(instance)
	local ownerId =
		instance:GetAttribute("OwnerUserId")
		or instance:GetAttribute("HeldOwnerUserId")
		or instance:GetAttribute("CaughtOwnerUserId")
		or instance:GetAttribute("CapturedByUserId")

	ownerId = tonumber(ownerId)

	if ownerId then
		return Players:GetPlayerByUserId(ownerId)
	end

	local ownerName =
		instance:GetAttribute("OwnerName")
		or instance:GetAttribute("PlayerName")

	if ownerName then
		return Players:FindFirstChild(tostring(ownerName))
	end

	return nil
end

local function isPlayerPastRestoreWindow(player)
	local joined = playerJoinTime[player.UserId] or os.clock()
	return os.clock() - joined >= PLAYER_CAPTURE_IGNORE_SECONDS
end

local function sendCapture(player, instance, force)
	if not player or not player.Parent then
		return
	end

	if not isBrainrotInstance(instance) then
		return
	end

	if ignoredInitialInstances[instance] and not force then
		return
	end

	if not force and not isPlayerPastRestoreWindow(player) then
		return
	end

	local rarity = getRarity(instance)
	local uid = tostring(getStrongId(instance) or instance:GetDebugId())
	local key = tostring(player.UserId) .. ":" .. uid

	if sentByKey[key] and not force then
		return
	end

	sentByKey[key] = true

	local color = RARITY_COLORS[rarity] or RARITY_COLORS.Common

	local payload = {
		uid = uid,
		name = getBrainrotName(instance),
		rarity = rarity,
		mutation = getMutation(instance),
		mps = getMps(instance),
		color = colorToPayload(color),
	}

	rarityRevealRemote:FireClient(player, payload)

	print("[RareCapture] Reveal sent:", player.Name, payload.rarity, payload.name)

	if shouldAnnounce(rarity) then
		local text = player.Name .. " captured a " .. rarity .. " " .. payload.name .. "!"

		announcementRemote:FireAllClients({
			kind = "RareCapture",
			text = text,
			rarity = rarity,
			color = payload.color,
		})

		print("[RareCapture] Server announcement:", text)
	end
end

local function tryNpcCapture(instance)
	if not instance:IsA("Model") then
		return
	end

	local player = getOwnerPlayerFromInstance(instance)
	if not player then
		return
	end

	local inventoryOnly = instance:GetAttribute("InventoryOnly") == true
	local placed = instance:GetAttribute("IsPlaced") == true or instance:GetAttribute("Placed") == true

	if inventoryOnly or not placed then
		sendCapture(player, instance, false)
	end
end

local function watchNpc(instance)
	if not instance:IsA("Model") then
		return
	end

	local attrs = {
		"InventoryOnly",
		"OwnerUserId",
		"HeldOwnerUserId",
		"CaughtOwnerUserId",
		"CapturedByUserId",
		"OwnerName",
		"Rarity",
		"BrainrotRarity",
		"UID",
		"BrainrotUID",
	}

	for _, attr in ipairs(attrs) do
		instance:GetAttributeChangedSignal(attr):Connect(function()
			task.delay(0.1, function()
				if instance.Parent then
					tryNpcCapture(instance)
				end
			end)
		end)
	end

	task.delay(0.2, function()
		if instance.Parent then
			tryNpcCapture(instance)
		end
	end)
end

local function watchTool(player, tool)
	if not tool:IsA("Tool") then
		return
	end

	if ignoredInitialInstances[tool] then
		return
	end

	task.delay(0.15, function()
		if tool.Parent == player.Backpack or tool.Parent == player.Character then
			sendCapture(player, tool, false)
		end
	end)

	tool.AttributeChanged:Connect(function()
		task.delay(0.1, function()
			if tool.Parent == player.Backpack or tool.Parent == player.Character then
				sendCapture(player, tool, false)
			end
		end)
	end)
end

local function markExistingPlayerItemsIgnored(player)
	local backpack = player:FindFirstChild("Backpack")

	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			ignoredInitialInstances[item] = true
		end
	end

	if player.Character then
		for _, item in ipairs(player.Character:GetChildren()) do
			ignoredInitialInstances[item] = true
		end
	end
end

local function watchPlayer(player)
	playerJoinTime[player.UserId] = os.clock()

	task.delay(0.5, function()
		if player.Parent then
			markExistingPlayerItemsIgnored(player)
		end
	end)

	local backpack = player:WaitForChild("Backpack", 20)

	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			ignoredInitialInstances[child] = true
		end

		backpack.ChildAdded:Connect(function(tool)
			watchTool(player, tool)
		end)
	end

	player.CharacterAdded:Connect(function(character)
		for _, child in ipairs(character:GetChildren()) do
			ignoredInitialInstances[child] = true
		end

		character.ChildAdded:Connect(function(tool)
			watchTool(player, tool)
		end)
	end)
end

-- Ignore NPCs that already exist before this system starts.
for _, npc in ipairs(npcFolder:GetChildren()) do
	ignoredInitialInstances[npc] = true
	watchNpc(npc)
end

npcFolder.ChildAdded:Connect(function(npc)
	watchNpc(npc)
end)

Players.PlayerAdded:Connect(watchPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(watchPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	playerJoinTime[player.UserId] = nil

	for key in pairs(sentByKey) do
		if string.sub(key, 1, #tostring(player.UserId)) == tostring(player.UserId) then
			sentByKey[key] = nil
		end
	end
end)

testAnnouncementFunction.OnServerInvoke = function(player)
	announcementRemote:FireAllClients({
		kind = "RareCapture",
		text = "TEST: server announcement works!",
		rarity = "Legendary",
		color = colorToPayload(RARITY_COLORS.Legendary),
	})

	print("[RareCapture] Manual test announcement fired by", player.Name)

	return true
end

print("[CaptureRevealAnnouncements] Loaded safe rare capture announcements. Startup restore spam ignored.")