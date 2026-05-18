--!nonstrict
-- ServerScriptService/GameJuiceRemotes.server.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemoteEvent(name)
	local existing = remotesFolder:FindFirstChild(name) or ReplicatedStorage:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteEvent") then
			existing.Parent = remotesFolder
			return existing
		end

		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

ensureRemoteEvent("RarityReveal")
ensureRemoteEvent("ServerAnnouncement")
ensureRemoteEvent("DailyRewardResult")
ensureRemoteEvent("WorldEventUpdate")
ensureRemoteEvent("ZoneGateFeedback")
ensureRemoteEvent("TrainingFeedback")

print("[GameJuiceRemotes] Loaded.")