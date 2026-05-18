--!nonstrict
-- StarterPlayerScripts/ToolInventoryRefreshPatch.client.lua
-- Event-only refresh. No constant loop.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")

local function pokeToolInventory()
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	local gui = playerGui:FindFirstChild("ToolInventorySkinGui")
	if gui then
		gui:SetAttribute("RefreshTick", os.clock())
	end

	backpack:SetAttribute("ToolInventoryRefreshTick", os.clock())

	if player.Character then
		player.Character:SetAttribute("ToolInventoryRefreshTick", os.clock())
	end
end

local function watchTool(tool)
	if not tool:IsA("Tool") then
		return
	end

	tool:GetPropertyChangedSignal("Name"):Connect(pokeToolInventory)
	tool:GetPropertyChangedSignal("TextureId"):Connect(pokeToolInventory)
	tool.AttributeChanged:Connect(pokeToolInventory)
	tool.AncestryChanged:Connect(pokeToolInventory)
end

local function watchContainer(container)
	if not container then
		return
	end

	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			watchTool(child)
			task.defer(pokeToolInventory)
			task.delay(0.2, pokeToolInventory)
		end
	end)

	container.ChildRemoved:Connect(function()
		task.defer(pokeToolInventory)
	end)

	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Tool") then
			watchTool(child)
		end
	end
end

watchContainer(backpack)

player.CharacterAdded:Connect(function(character)
	watchContainer(character)
	task.delay(0.2, pokeToolInventory)
	task.delay(1, pokeToolInventory)
end)

if player.Character then
	watchContainer(player.Character)
end

task.delay(0.2, pokeToolInventory)
task.delay(1, pokeToolInventory)

print("[ToolInventoryRefreshPatch] loaded event-only refresh.")