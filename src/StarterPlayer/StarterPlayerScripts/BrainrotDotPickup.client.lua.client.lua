--!nonstrict
-- StarterPlayerScripts/BrainrotDotPickup.client.lua
-- Press "." to pick up nearest stunned brainrot.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("BrainrotRequestPickup")

local cooldown = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Period then
		if cooldown then
			return
		end

		cooldown = true
		remote:FireServer()

		task.delay(0.35, function()
			cooldown = false
		end)
	end
end)

print("[BrainrotDotPickup] Loaded. Press . to pick up brainrots.")