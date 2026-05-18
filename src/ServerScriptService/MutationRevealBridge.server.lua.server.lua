--!nonstrict
-- ServerScriptService/MutationRevealBridge.server.lua

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MutationConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("MutationConfig"))
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MutationReveal")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local IGNORE_AFTER_JOIN_SECONDS = 8

local playerJoinTime = {}
local announced = {}

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function getOwnerPlayer(obj)
	local ownerId =
		obj:GetAttribute("OwnerUserId")
		or obj:GetAttribute("HeldOwnerUserId")
		or obj:GetAttribute("CaughtOwnerUserId")
		or obj:GetAttribute("CapturedByUserId")

	ownerId = tonumber(ownerId)

	if ownerId then
		return Players:GetPlayerByUserId(ownerId)
	end

	local ownerName =
		obj:GetAttribute("OwnerName")
		or obj:GetAttribute("PlayerName")

	if ownerName then
		return Players:FindFirstChild(tostring(ownerName))
	end

	return nil
end

local function getMutationName(obj)
	local mutation =
		obj:GetAttribute("Mutation")
		or obj:GetAttribute("MutationName")
		or obj:GetAttribute("ActiveMutation")
		or obj:GetAttribute("MutationType")
		or obj:GetAttribute("CurrentMutation")

	mutation = tostring(mutation or "")

	if mutation == "" then
		return nil
	end

	local n = normalize(mutation)

	if n == "normal" or n == "none" then
		return nil
	end

	return mutation
end

local function recentlyJoined(player)
	local joined = playerJoinTime[player.UserId]

	if not joined then
		return false
	end

	return os.clock() - joined < IGNORE_AFTER_JOIN_SECONDS
end

local function fireReveal(obj)
	if not obj or not obj.Parent then
		return
	end

	local mutationName = getMutationName(obj)

	if not mutationName then
		return
	end

	local player = getOwnerPlayer(obj)

	if not player then
		return
	end

	if recentlyJoined(player) then
		return
	end

	local key = tostring(obj) .. ":" .. mutationName

	if announced[key] then
		return
	end

	announced[key] = true

	local config = MutationConfig.Get(mutationName)
	local color = config.Color or Color3.fromRGB(255, 220, 45)

	remote:FireClient(player, {
		Mutation = config.Name or mutationName,
		MoneyMultiplier = config.MoneyMultiplier or 1,
		StrengthMultiplier = config.StrengthMultiplier or 1,
		ColorR = math.floor(color.R * 255),
		ColorG = math.floor(color.G * 255),
		ColorB = math.floor(color.B * 255),
		BrainrotName = tostring(obj:GetAttribute("BrainrotName") or obj:GetAttribute("DisplayName") or obj.Name),
	})

	print("[MutationReveal] Sent", mutationName, "popup to", player.Name)
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
		"OwnerUserId",
		"HeldOwnerUserId",
		"CaughtOwnerUserId",
		"CapturedByUserId",
		"OwnerName",
		"PlayerName",
	}) do
		npc:GetAttributeChangedSignal(attr):Connect(function()
			task.delay(0.15, function()
				fireReveal(npc)
			end)
		end)
	end

	task.delay(0.25, function()
		fireReveal(npc)
	end)
end

local folder = getNpcFolder()

if folder then
	folder.ChildAdded:Connect(function(child)
		task.wait(0.15)
		watchNpc(child)
	end)

	for _, child in ipairs(folder:GetChildren()) do
		watchNpc(child)
	end
end

Players.PlayerAdded:Connect(function(player)
	playerJoinTime[player.UserId] = os.clock()
end)

Players.PlayerRemoving:Connect(function(player)
	playerJoinTime[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	playerJoinTime[player.UserId] = os.clock()
end

print("[MutationRevealBridge] Loaded.")
