--!strict
-- SpeedRemotes.server.lua
-- Put in ServerScriptService

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function ensureRemote(name: string): RemoteEvent
	local existing = ReplicatedStorage:FindFirstChild(name)

	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage

	return remote
end

ensureRemote("TrainSpeed")
ensureRemote("UpdateSpeedStats")

print("[SpeedRemotes] TrainSpeed and UpdateSpeedStats ready")