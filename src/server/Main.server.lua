local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local remoteDefinitions = require(Shared.Remotes)
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = remoteDefinitions.FolderName
remotesFolder.Parent = ReplicatedStorage

local remotes = {}
for _, name in ipairs(remoteDefinitions.Events) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	remotes[name] = remote
end
for _, name in ipairs(remoteDefinitions.Functions) do
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotesFolder
	remotes[name] = remote
end

local context = {
	Config = require(Shared.Config),
	AssetIds = require(Shared.AssetIds),
	Util = require(Shared.Util),
	Remotes = remotes,
}

local serviceNames = {
	"DataService",
	"MapService",
	"PlayerVisualService",
	"BrainrotSpawnService",
	"EconomyService",
	"QuestService",
	"PlotService",
	"CaptureService",
	"RebirthService",
	"ZoneService",
	"ShopService",
}

for _, name in ipairs(serviceNames) do
	context[name] = require(script.Parent[name])
end

for _, name in ipairs(serviceNames) do
	context[name].Init(context)
end

remotes.GetState.OnServerInvoke = function(player)
	return context.DataService.GetPublicState(player)
end

for _, name in ipairs(serviceNames) do
	if context[name].Start then
		context[name].Start()
	end
end
