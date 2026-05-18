--!nonstrict
-- BrainrotMainHUD.client.lua
-- This removes the bigger/new left panel created by BrainrotMainHUD.
-- It does NOT touch your original left icon panel from your other GUI script.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local badHud = playerGui:FindFirstChild("CartoonSimulatorHUD")
if badHud then
	badHud:Destroy()
end

print("[BrainrotMainHUD] removed bigger duplicate HUD panel")