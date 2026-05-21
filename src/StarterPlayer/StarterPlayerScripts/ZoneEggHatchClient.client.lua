--!nonstrict
-- Hooks the server egg-opening remotes into the reusable NPC reveal GUI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RevealNPC = require(script.Parent:WaitForChild("NPCRevealGui"))

local seenRevealIds = {}

local function getRevealId(payload)
	if type(payload) ~= "table" then
		return tostring(os.clock())
	end

	return tostring(payload.revealId or payload.RevealId or payload.EggId or payload.ResultName or os.clock())
end

local function enqueueReveal(payload)
	local revealId = getRevealId(payload)
	if seenRevealIds[revealId] then
		return
	end
	seenRevealIds[revealId] = true

	RevealNPC.show(payload)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if remotes then
	local revealRemote = remotes:WaitForChild("EggRevealResult", 15)
	if revealRemote and revealRemote:IsA("RemoteEvent") then
		revealRemote.OnClientEvent:Connect(enqueueReveal)
	end

	local startRevealRemote = remotes:WaitForChild("StartNPCReveal", 5)
	if startRevealRemote and startRevealRemote:IsA("RemoteEvent") then
		startRevealRemote.OnClientEvent:Connect(enqueueReveal)
	end
end

local legacyRevealRemote = ReplicatedStorage:WaitForChild("ZoneEggHatchResult", 15)
if legacyRevealRemote and legacyRevealRemote:IsA("RemoteEvent") then
	legacyRevealRemote.OnClientEvent:Connect(enqueueReveal)
end

print("[ZoneEggHatchClient] Loaded polished NPC reveal GUI bridge.")
