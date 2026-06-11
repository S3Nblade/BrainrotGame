local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local definitions = require(Shared.Remotes)
local folder = ReplicatedStorage:WaitForChild(definitions.FolderName)

local remotes = {}
for _, name in ipairs(definitions.Events) do
	remotes[name] = folder:WaitForChild(name)
end
for _, name in ipairs(definitions.Functions) do
	remotes[name] = folder:WaitForChild(name)
end

local context = {
	Player = player,
	PlayerGui = player:WaitForChild("PlayerGui"),
	Config = require(Shared.Config),
	AssetIds = require(Shared.AssetIds),
	Util = require(Shared.Util),
	Remotes = remotes,
}

local controllerNames = {
	"CameraController",
	"InputController",
	"UIController",
	"RevealController",
	"EffectsController",
}

for _, name in ipairs(controllerNames) do
	local controller = require(script.Parent[name])
	context[name] = controller
	if controller.Init then
		controller.Init(context)
	end
end

for _, name in ipairs(controllerNames) do
	task.spawn(context[name].Start)
end
