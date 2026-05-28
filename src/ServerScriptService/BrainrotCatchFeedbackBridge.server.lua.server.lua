--!nonstrict
-- BrainrotCatchFeedbackBridge.server.lua
-- Put in: ServerScriptService
-- Shows FOUND popup when player FINISHES holding E and picks up the NPC.
-- Does NOT wait until plot placement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local npcFolder = workspace:WaitForChild("BrainrotNPCs")

local remote = ReplicatedStorage:FindFirstChild("BrainrotCatchFeedback")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "BrainrotCatchFeedback"
	remote.Parent = ReplicatedStorage
end

local firedRecently = {}

local function getOwnerFromHeldBy(npc)
	local heldBy = npc:GetAttribute("HeldBy")

	if typeof(heldBy) == "number" then
		return heldBy
	end

	local asNumber = tonumber(heldBy)
	if asNumber then
		return asNumber
	end

	return nil
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

local function fireFoundOnPickup(npc)
	if not npc or not npc:IsA("Model") then
		return
	end

	local ownerUserId = getOwnerFromHeldBy(npc)
	if not ownerUserId then
		return
	end

	local player = Players:GetPlayerByUserId(ownerUserId)
	if not player then
		return
	end

	local npcId = getNPCId(npc)
	local key = tostring(ownerUserId) .. "_" .. npcId

	-- Prevent same pickup from spamming.
	if firedRecently[key] and os.clock() - firedRecently[key] < 4 then
		return
	end

	firedRecently[key] = os.clock()

	remote:FireClient(player, {
		eventType = "FOUND_PICKUP",
		pickedUp = true,
		showFoundPopup = false,
		use3DReveal = true,
		npcName = npc:GetAttribute("DisplayName") or npc:GetAttribute("Name") or npc.Name,
		rarity = getRarity(npc),
		mps = getMPS(npc),
		npcId = npcId,
	})
end

local function watchNPC(npc)
	if not npc:IsA("Model") then
		return
	end

	npc:GetAttributeChangedSignal("HeldBy"):Connect(function()
		task.delay(0.05, function()
			fireFoundOnPickup(npc)
		end)
	end)

	task.delay(0.2, function()
		fireFoundOnPickup(npc)
	end)
end

for _, obj in ipairs(npcFolder:GetDescendants()) do
	if obj:IsA("Model") then
		watchNPC(obj)
	end
end

npcFolder.DescendantAdded:Connect(function(obj)
	if obj:IsA("Model") then
		task.wait(0.1)
		watchNPC(obj)
	end
end)

print("[BrainrotCatchFeedbackBridge] loaded - FOUND on pickup")
