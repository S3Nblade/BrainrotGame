-- Compiled with roblox-ts v3.0.0
local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
local React = TS.import(script, game:GetService("ReplicatedStorage"), "node_modules", "@rbxts", "react")
local createRoot = TS.import(script, game:GetService("ReplicatedStorage"), "node_modules", "@rbxts", "react-roblox").createRoot
local HUD = TS.import(script, script, "ui", "components", "HUD").default
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local function App()
	return React.createElement("screengui", {
		ResetOnSpawn = false,
	}, React.createElement(HUD))
end
local root = createRoot(playerGui)
root:render(React.createElement(App))
