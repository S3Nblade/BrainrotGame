--!nonstrict
-- ServerScriptService/BrainrotToolSanitizer.server.lua
-- Removes duplicate/empty brainrot tools.
-- Prevents 3 empty "Model" tools from entering inventory.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local CHECK_EVERY = 0.5

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function getStrongId(obj)
	if not obj then
		return nil
	end

	for _, key in ipairs({
		"BrainrotUID",
		"UID",
		"Uuid",
		"UUID",
		"BrainrotId",
		"NpcId",
		"NPCId",
		"UniqueId",
		"InventoryId",
		}) do
		local value = obj:GetAttribute(key)

		if value ~= nil and tostring(value) ~= "" then
			return tostring(value)
		end
	end

	return nil
end

local function getDisplayName(obj)
	local name = tostring(obj:GetAttribute("BrainrotName") or obj:GetAttribute("DisplayName") or obj.Name)

	if name == "" or name == "Model" then
		name = tostring(obj:GetAttribute("Rarity") or "Brainrot") .. " Brainrot"
	end

	return name
end

local function getContainers(player)
	return {
		player.Character,
		player:FindFirstChildOfClass("Backpack"),
		player:FindFirstChild("StarterGear"),
	}
end

local function isPlacedNpc(npc)
	return npc:IsA("Model")
		and npc:GetAttribute("InventoryOnly") ~= true
		and (npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true)
end

local function playerOwnsNpc(player, npc)
	return tostring(npc:GetAttribute("PlacedOwnerUserId") or npc:GetAttribute("OwnerUserId")) == tostring(player.UserId)
end

local function removeToolIfPlaced(player, tool)
	local npcFolder = getNpcFolder()
	if not npcFolder then
		return false
	end

	local toolId = getStrongId(tool)

	if not toolId then
		return false
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) and playerOwnsNpc(player, npc) then
			if getStrongId(npc) == toolId then
				tool:Destroy()
				return true
			end
		end
	end

	return false
end

local function fixTool(tool)
	if not tool:FindFirstChild("Handle") then
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1, 1, 1)
		handle.Transparency = 1
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
		handle.Parent = tool
	end

	if tool.Name == "" or tool.Name == "Model" then
		tool.Name = getDisplayName(tool)
	end
end

local function sanitizePlayer(player)
	local seen = {}

	for _, container in ipairs(getContainers(player)) do
		if container then
			for _, tool in ipairs(container:GetChildren()) do
				if tool:IsA("Tool") then
					if removeToolIfPlaced(player, tool) then
						continue
					end

					fixTool(tool)

					local uid = getStrongId(tool)
					local key = uid or ("NOID::" .. tool.Name)

					if seen[key] then
						tool:Destroy()
					else
						seen[key] = true
					end
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			sanitizePlayer(player)
		end

		task.wait(CHECK_EVERY)
	end
end)

print("[BrainrotToolSanitizer] Loaded. Duplicate/empty tools are cleaned.")