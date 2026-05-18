-- StarterPlayerScripts/DropBrainrotButton.client.lua
-- Disabled. Brainrots now go directly to inventory.

local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("DropBrainrotGui")
if old then
	old:Destroy()
end

print("[DropBrainrotButton] disabled")