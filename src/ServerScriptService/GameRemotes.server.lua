--!strict
-- GameRemotes.server.lua
-- Put in: ServerScriptService
-- Creates all RemoteEvents your game needs before LocalScripts wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemoteEvent(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteEvent") then
			return existing
		else
			warn("[GameRemotes] Removing wrong instance named:", name)
			existing:Destroy()
		end
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage

	print("[GameRemotes] Created RemoteEvent:", name)

	return remote
end

-- Speed system
ensureRemoteEvent("TrainSpeed")
ensureRemoteEvent("UpdateSpeedStats")

-- Catch feedback system
ensureRemoteEvent("BrainrotCatchFeedback")

-- Existing game remotes
ensureRemoteEvent("NotifyUser")
ensureRemoteEvent("UpdateCoins")
ensureRemoteEvent("ReleaseNPC")
ensureRemoteEvent("ReleaseButton")