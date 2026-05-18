--!nonstrict
-- ServerScriptService/BrainrotToolInventoryRestore.server,lua
-- FULL REPLACEMENT
-- Safe inventory restore.
-- No duplicate Model tools.
-- Never restores a tool for placed NPCs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local CHECK_EVERY = 3

local function getNpcFolder()
	local folder = Workspace:FindFirstChild(NPC_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = NPC_FOLDER_NAME
		folder.Parent = Workspace
	end

	return folder
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

local function ensureId(obj)
	local id = getStrongId(obj)

	if not id then
		id = HttpService:GenerateGUID(false)
	end

	obj:SetAttribute("BrainrotUID", id)
	obj:SetAttribute("UID", id)

	return id
end

local function getDisplayName(obj)
	local name = tostring(
		obj:GetAttribute("BrainrotName")
			or obj:GetAttribute("DisplayName")
			or obj.Name
	)

	if name == "" or name == "Model" then
		name = tostring(obj:GetAttribute("Rarity") or "Brainrot") .. " Brainrot"
	end

	return name
end

local function getOwnerId(obj)
	return obj:GetAttribute("OwnerUserId")
		or obj:GetAttribute("PlacedOwnerUserId")
		or obj:GetAttribute("CapturedByUserId")
		or obj:GetAttribute("UserId")
end

local function playerOwnsNpc(player, npc)
	return tostring(getOwnerId(npc)) == tostring(player.UserId)
		or tostring(npc:GetAttribute("OwnerName")) == player.Name
end

local function isPlacedNpc(npc)
	return npc:IsA("Model")
		and npc:GetAttribute("InventoryOnly") ~= true
		and (npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true)
end

local function isInventoryNpc(npc)
	return npc:IsA("Model")
		and npc:GetAttribute("InventoryOnly") == true
		and npc:GetAttribute("IsPlaced") ~= true
		and npc:GetAttribute("Placed") ~= true
end

local function getContainers(player)
	return {
		player.Character,
		player:FindFirstChildOfClass("Backpack"),
		player:FindFirstChild("StarterGear"),
	}
end

local function toolMatchesNpc(tool, npc)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	local toolId = getStrongId(tool)
	local npcId = getStrongId(npc)

	if toolId and npcId and toolId == npcId then
		return true
	end

	return false
end

local function removeToolsForPlacedNpc(player, npc)
	for _, container in ipairs(getContainers(player)) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and toolMatchesNpc(item, npc) then
					item:Destroy()
				end
			end
		end
	end
end

local function hasToolForNpc(player, npc)
	for _, container in ipairs(getContainers(player)) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and toolMatchesNpc(item, npc) then
					return true
				end
			end
		end
	end

	return false
end

local function getVisualPart(npc)
	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			local lower = string.lower(obj.Name)

			if lower ~= "humanoidrootpart"
				and not string.find(lower, "hitbox")
				and not string.find(lower, "hurtbox")
				and not string.find(lower, "root")
				and obj.Transparency < 0.95 then
				return obj
			end
		end
	end

	return npc:FindFirstChildWhichIsA("BasePart", true)
end

local function copyAttributes(fromObj, toObj)
	for key, value in pairs(fromObj:GetAttributes()) do
		toObj:SetAttribute(key, value)
	end
end

local function createTool(player, npc)
	local uid = ensureId(npc)
	local displayName = getDisplayName(npc)

	local tool = Instance.new("Tool")
	tool.Name = displayName
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	copyAttributes(npc, tool)

	tool:SetAttribute("IsBrainrot", true)
	tool:SetAttribute("BrainrotUID", uid)
	tool:SetAttribute("UID", uid)
	tool:SetAttribute("BrainrotName", displayName)
	tool:SetAttribute("DisplayName", displayName)

	local sourcePart = getVisualPart(npc)
	local handle

	if sourcePart then
		handle = sourcePart:Clone()
		handle.Name = "Handle"
		handle.Anchored = false
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
		handle.Transparency = math.min(handle.Transparency, 0.25)
	else
		handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1.5, 1.5, 1.5)
		handle.Color = Color3.fromRGB(255, 215, 80)
		handle.Anchored = false
		handle.CanCollide = false
		handle.CanTouch = false
		handle.CanQuery = false
		handle.Massless = true
	end

	handle.Parent = tool

	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")
	tool.Parent = backpack

	print("[BrainrotToolInventoryRestore] Restored safe tool:", displayName, uid, "for", player.Name)
end

local function hideInventoryNpc(npc)
	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.Transparency = 1
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 1
		elseif obj:IsA("ProximityPrompt") then
			obj:Destroy()
		end
	end

	pcall(function()
		npc:PivotTo(CFrame.new(0, -10000, 0))
	end)
end

local function cleanDuplicateTools(player)
	local seen = {}

	for _, container in ipairs(getContainers(player)) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					local uid = getStrongId(item)

					if item.Name == "Model" or item.Name == "" then
						item.Name = tostring(item:GetAttribute("Rarity") or "Brainrot") .. " Brainrot"
					end

					if uid then
						if seen[uid] then
							item:Destroy()
						else
							seen[uid] = true
						end
					elseif item.Name == "Model" then
						item:Destroy()
					end
				end
			end
		end
	end
end

local function restorePlayer(player)
	local npcFolder = getNpcFolder()

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) and playerOwnsNpc(player, npc) then
			ensureId(npc)
			removeToolsForPlacedNpc(player, npc)
		end
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isInventoryNpc(npc) and playerOwnsNpc(player, npc) then
			ensureId(npc)
			hideInventoryNpc(npc)

			if not hasToolForNpc(player, npc) then
				createTool(player, npc)
			end
		end
	end

	cleanDuplicateTools(player)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		task.wait(4)

		while player.Parent do
			restorePlayer(player)
			task.wait(CHECK_EVERY)
		end
	end)
end)

task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			restorePlayer(player)
		end

		task.wait(CHECK_EVERY)
	end
end)

print("[BrainrotToolInventoryRestore] SAFE CLEAN version loaded.")