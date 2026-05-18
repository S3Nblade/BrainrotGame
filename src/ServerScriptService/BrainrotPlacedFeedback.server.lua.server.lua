--!nonstrict
-- BrainrotPlacedFeedback.server.lua
-- Put in: ServerScriptService
-- Fires a "PLACED!" moment when a carried brainrot becomes placed/claimed at the player's plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local npcFolder = workspace:WaitForChild("BrainrotNPCs")

local remote = ReplicatedStorage:FindFirstChild("BrainrotPlacedFeedback")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "BrainrotPlacedFeedback"
	remote.Parent = ReplicatedStorage
end

local firedRecently = {}

local function getOwnerUserId(npc)
	local attrs = {
		"PlacedOwnerUserId",
		"ClaimedOwnerUserId",
		"OwnerUserId",
		"ownerUserId",
	}

	for _, attr in ipairs(attrs) do
		local value = npc:GetAttribute(attr)

		if typeof(value) == "number" then
			return value
		end

		local asNumber = tonumber(value)
		if asNumber then
			return asNumber
		end
	end

	return nil
end

local function isPlaced(npc)
	if npc:GetAttribute("IsPlaced") == true then
		return true
	end

	if npc:GetAttribute("Placed") == true then
		return true
	end

	if npc:GetAttribute("Claimed") == true then
		return true
	end

	if npc:GetAttribute("IsClaimed") == true then
		return true
	end

	return false
end

local function getMPS(npc)
	return tonumber(
		npc:GetAttribute("MPS")
			or npc:GetAttribute("CashPerSecond")
			or npc:GetAttribute("cashPerSecond")
			or npc:GetAttribute("Income")
			or 0
	) or 0
end

local function getRarity(npc)
	return tostring(
		npc:GetAttribute("Rarity")
			or npc:GetAttribute("rarity")
			or "Common"
	)
end

local function getNPCId(npc)
	return tostring(
		npc:GetAttribute("NPCId")
			or npc:GetAttribute("Id")
			or npc:GetAttribute("UniqueId")
			or npc.Name
	)
end

local function getPosition(npc)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end

	if npc:IsA("Model") then
		local pivot = npc:GetPivot()
		return pivot.Position
	end

	return Vector3.new(0, 5, 0)
end

local function firePlaced(npc)
	if not npc or not npc:IsA("Model") then
		return
	end

	if not isPlaced(npc) then
		return
	end

	local ownerUserId = getOwnerUserId(npc)
	if not ownerUserId then
		return
	end

	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return
	end

	local npcId = getNPCId(npc)
	local key = tostring(ownerUserId) .. "_" .. npcId

	if firedRecently[key] and os.clock() - firedRecently[key] < 8 then
		return
	end

	firedRecently[key] = os.clock()

	remote:FireClient(player, {
		npcId = npcId,
		npcName = npc:GetAttribute("DisplayName") or npc:GetAttribute("Name") or npc.Name,
		rarity = getRarity(npc),
		mps = getMPS(npc),
		position = getPosition(npc),
	})
end

local function watchNPC(npc)
	if not npc:IsA("Model") then
		return
	end

	local watchedAttrs = {
		"IsPlaced",
		"Placed",
		"Claimed",
		"IsClaimed",
		"PlacedOwnerUserId",
		"ClaimedOwnerUserId",
		"OwnerUserId",
		"ownerUserId",
	}

	for _, attr in ipairs(watchedAttrs) do
		npc:GetAttributeChangedSignal(attr):Connect(function()
			task.delay(0.08, function()
				firePlaced(npc)
			end)
		end)
	end

	task.delay(0.25, function()
		firePlaced(npc)
	end)
end

for _, obj in ipairs(npcFolder:GetDescendants()) do
	if obj:IsA("Model") then
		watchNPC(obj)
	end
end

npcFolder.DescendantAdded:Connect(function(obj)
	if obj:IsA("Model") then
		task.wait(0.15)
		watchNPC(obj)
	end
end)

print("[BrainrotPlacedFeedback] loaded")