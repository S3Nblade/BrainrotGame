-- ServerScriptService/BrainrotToolInventoryRestore.server.lua
-- Restores saved brainrot tools from hidden InventoryOnly NPCs.

--!nonstrict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local npcFolder = Workspace:WaitForChild("BrainrotNPCs")

local function getNpcRoot(npc)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function playerOwnsNpc(player, npc)
	return tostring(npc:GetAttribute("PlacedOwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(npc:GetAttribute("Owner")) == player.Name
end

local function getDisplayName(npc)
	return tostring(
		npc:GetAttribute("DisplayName")
			or npc:GetAttribute("TemplateName")
			or npc:GetAttribute("templateName")
			or npc.Name
	)
end

local function getRarity(npc)
	return tostring(npc:GetAttribute("Rarity") or "Common")
end

local function getMPS(npc)
	return tonumber(npc:GetAttribute("MPS") or npc:GetAttribute("CashPerSecond") or 0) or 0
end

local function normalizeImageId(value)
	if typeof(value) == "number" then
		return "rbxassetid://" .. tostring(value)
	end

	if typeof(value) ~= "string" or value == "" then
		return ""
	end

	if tonumber(value) then
		return "rbxassetid://" .. value
	end

	return value
end

local function getNpcIconId(npc)
	for _, attr in ipairs({ "ToolIcon", "Icon", "IconId", "Image", "ImageId", "TextureId", "Thumbnail", "ThumbnailId" }) do
		local imageId = normalizeImageId(npc:GetAttribute(attr))
		if imageId ~= "" then
			return imageId
		end
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("Decal") or obj:IsA("Texture") then
			local imageId = normalizeImageId(obj.Texture)
			if imageId ~= "" then
				return imageId
			end
		elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			local imageId = normalizeImageId(obj.Image)
			if imageId ~= "" then
				return imageId
			end
		end
	end

	return ""
end

local function cleanToolClone(clone)
	for _, obj in ipairs(clone:GetDescendants()) do
		if obj:IsA("Script")
			or obj:IsA("LocalScript")
			or obj:IsA("ModuleScript")
			or obj:IsA("ProximityPrompt")
			or obj:IsA("BillboardGui")
			or obj:IsA("Humanoid")
			or obj:IsA("Animator")
		then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Anchored = false
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.Massless = true
		end
	end
end

local function createToolVisual(tool, npc)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.35, 0.35, 0.35)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	local clone = npc:Clone()
	clone.Name = "HeldBrainrotModel"
	cleanToolClone(clone)
	clone.Parent = tool

	pcall(function()
		clone:ScaleTo(0.45)
	end)

	local root = getNpcRoot(clone)
	if root then
		clone.PrimaryPart = root
	end

	clone:PivotTo(handle.CFrame * CFrame.new(0, 0.55, -0.9) * CFrame.Angles(0, math.rad(180), 0))

	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
		end
	end

	tool.Grip = CFrame.new(0, -0.45, -0.9) * CFrame.Angles(math.rad(-8), math.rad(180), 0)
end

local function hasTool(player, uid)
	for _, container in ipairs({
		player.Character,
		player:FindFirstChild("Backpack"),
		player:FindFirstChild("StarterGear"),
		}) do
		if container then
			for _, obj in ipairs(container:GetChildren()) do
				if obj:IsA("Tool")
					and obj:GetAttribute("BrainrotInventoryTool") == true
					and tostring(obj:GetAttribute("DirectInventoryUid")) == tostring(uid)
				then
					return true
				end
			end
		end
	end

	return false
end

local function createToolFromNpc(npc)
	local uid = tostring(npc:GetAttribute("DirectInventoryUid") or "")
	if uid == "" then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = getDisplayName(npc)
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = getRarity(npc) .. " Brainrot | $" .. tostring(math.floor(getMPS(npc))) .. "/s"

	local iconId = getNpcIconId(npc)
	if iconId ~= "" then
		tool.TextureId = iconId
	end

	tool:SetAttribute("BrainrotInventoryTool", true)
	tool:SetAttribute("DirectInventoryUid", uid)
	tool:SetAttribute("NPCName", npc.Name)
	tool:SetAttribute("DisplayName", getDisplayName(npc))
	tool:SetAttribute("Rarity", getRarity(npc))
	tool:SetAttribute("MPS", getMPS(npc))

	createToolVisual(tool, npc)

	return tool
end

local function restoreToolsForPlayer(player)
	local backpack = player:FindFirstChild("Backpack") or player:WaitForChild("Backpack", 5)
	local starterGear = player:FindFirstChild("StarterGear")

	if not backpack then
		return
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model")
			and npc:GetAttribute("InventoryOnly") == true
			and playerOwnsNpc(player, npc)
		then
			local uid = tostring(npc:GetAttribute("DirectInventoryUid") or "")

			if uid ~= "" and not hasTool(player, uid) then
				local backpackTool = createToolFromNpc(npc)
				if backpackTool then
					backpackTool.Parent = backpack
				end

				if starterGear then
					local starterTool = createToolFromNpc(npc)
					if starterTool then
						starterTool.Parent = starterGear
					end
				end

				print("[BrainrotToolInventoryRestore] Restored tool:", npc.Name, "for", player.Name)
			end
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		restoreToolsForPlayer(player)
	end)

	task.delay(2, function()
		restoreToolsForPlayer(player)
	end)

	task.delay(6, function()
		restoreToolsForPlayer(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		task.wait(2)
		restoreToolsForPlayer(player)
	end)
end

npcFolder.ChildAdded:Connect(function(npc)
	if not npc:IsA("Model") then
		return
	end

	task.wait(0.5)

	if npc:GetAttribute("InventoryOnly") ~= true then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if playerOwnsNpc(player, npc) then
			restoreToolsForPlayer(player)
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(5)

		for _, player in ipairs(Players:GetPlayers()) do
			restoreToolsForPlayer(player)
		end
	end
end)

print("[BrainrotToolInventoryRestore] loaded")