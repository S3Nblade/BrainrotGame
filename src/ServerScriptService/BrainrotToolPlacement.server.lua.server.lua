--!nonstrict
-- ServerScriptService/BrainrotToolPlacement.server.lua
-- FULL REPLACEMENT
-- Floor-aware brainrot placement.
-- Fixes: placing on floor 1 also appearing on floor 2.
-- Every floor now gets unique slot IDs:
-- Floor 1: Slot_01, Slot_02...
-- Floor 2: F2_Slot_01, F2_Slot_02...
-- Floor 3: F3_Slot_01, F3_Slot_02...
--
-- Also includes duplicate cleanup for already-broken duplicated NPCs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local PROMPT_NAME = "BrainrotStandPrompt"
local PROMPT_HOLD_DURATION = 0.35
local PROMPT_DISTANCE = 12

local PLACE_Y_OFFSET = 0.28
local REFRESH_EVERY = 0.5
local DUPLICATE_CLEANUP_EVERY = 2

local npcFolder = Workspace:FindFirstChild(NPC_FOLDER_NAME)
if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = NPC_FOLDER_NAME
	npcFolder.Parent = Workspace
end

local notifyRemote = ReplicatedStorage:FindFirstChild("NotifyUser")
if not notifyRemote then
	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = "NotifyUser"
	notifyRemote.Parent = ReplicatedStorage
end

local database = nil
pcall(function()
	local TS = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
	database = TS.import(script, ServerScriptService, "Server", "services", "database.service").default()
end)

local connectedPrompts = {}

local function notify(player, message, variant)
	notifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function emitGameplayEvent(eventName, player, payload)
	local event = ServerStorage:FindFirstChild("BrainrotGameplayEvent")
	if event and event:IsA("BindableEvent") then
		event:Fire(eventName, player, payload or {})
	end
end

local function saveSnapshot(player)
	if database and database.savePlacedNPCSnapshot then
		task.defer(function()
			pcall(function()
				database.savePlacedNPCSnapshot(player, npcFolder)
			end)
		end)
	end
end

local function getPlotsFolder()
	return Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
end

local function getFirstBasePart(container)
	if not container then
		return nil
	end

	if container:IsA("BasePart") then
		return container
	end

	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function getAllPlots()
	local folder = getPlotsFolder()
	local plots = {}

	if not folder then
		return plots
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") then
			if getFirstBasePart(child) then
				table.insert(plots, child)
			end
		end
	end

	return plots
end

local function playerOwnsPlot(player, plot)
	if not player or not plot then
		return false
	end

	return tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
		or tostring(plot:GetAttribute("OwnerName")) == player.Name
end

local function getPlayerPlot(player)
	for _, plot in ipairs(getAllPlots()) do
		if playerOwnsPlot(player, plot) then
			return plot
		end
	end

	return nil
end

local function findPlotFromPart(part)
	for _, plot in ipairs(getAllPlots()) do
		if part == plot or part:IsDescendantOf(plot) then
			return plot
		end
	end

	return nil
end

local function getFloorIndex(obj)
	local current = obj

	while current and current ~= Workspace do
		local attr = current:GetAttribute("GeneratedFloorIndex") or current:GetAttribute("FloorIndex")

		if tonumber(attr) then
			return math.max(1, math.floor(tonumber(attr)))
		end

		current = current.Parent
	end

	return 1
end

local function makeSlotId(floorIndex, index)
	if floorIndex <= 1 then
		return "Slot_" .. string.format("%02d", index)
	end

	return "F" .. tostring(floorIndex) .. "_Slot_" .. string.format("%02d", index)
end

local function isYellow(part)
	local c = part.Color
	return c.R > 0.62 and c.G > 0.38 and c.B < 0.38
end

local function isBadStandPart(part)
	local lower = string.lower(part.Name)

	return string.find(lower, "money")
		or string.find(lower, "collect")
		or string.find(lower, "button")
		or string.find(lower, "level")
		or string.find(lower, "sign")
		or string.find(lower, "name")
		or string.find(lower, "green")
		or string.find(lower, "text")
		or string.find(lower, "surface")
end

local function getBestStandPart(standObject)
	if not standObject then
		return nil
	end

	if standObject:IsA("BasePart") then
		return standObject
	end

	local bestPart = nil
	local bestScore = -math.huge

	for _, obj in ipairs(standObject:GetDescendants()) do
		if obj:IsA("BasePart") and not isBadStandPart(obj) then
			local area = obj.Size.X * obj.Size.Z
			local topY = obj.Position.Y + obj.Size.Y / 2
			local score = topY * 100000 + area * 100

			if isYellow(obj) then
				score += 10000000
			end

			local lower = string.lower(obj.Name)

			if string.find(lower, "stand")
				or string.find(lower, "platform")
				or string.find(lower, "pad")
				or string.find(lower, "slot") then
				score += 2000000
			end

			if obj.Transparency >= 0.95 then
				score -= 3000000
			end

			if score > bestScore then
				bestScore = score
				bestPart = obj
			end
		end
	end

	return bestPart or getFirstBasePart(standObject)
end

local function getBrainrotStands(plot)
	local stands = {}
	local seenParts = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj.Name == "Brainrot Stand" or obj:GetAttribute("BrainrotStand") == true then
			local part = getBestStandPart(obj)

			if part and not seenParts[part] then
				seenParts[part] = true

				table.insert(stands, {
					container = obj,
					part = part,
					floorIndex = getFloorIndex(obj),
				})
			end
		end
	end

	table.sort(stands, function(a, b)
		if a.floorIndex ~= b.floorIndex then
			return a.floorIndex < b.floorIndex
		end

		if math.abs(a.part.Position.X - b.part.Position.X) > 0.1 then
			return a.part.Position.X < b.part.Position.X
		end

		return a.part.Position.Z < b.part.Position.Z
	end)

	local counters = {}

	for _, stand in ipairs(stands) do
		local floorIndex = stand.floorIndex
		counters[floorIndex] = (counters[floorIndex] or 0) + 1

		local slotId = makeSlotId(floorIndex, counters[floorIndex])

		stand.container:SetAttribute("BrainrotSlotId", slotId)
		stand.container:SetAttribute("GeneratedFloorIndex", floorIndex)

		stand.part:SetAttribute("BrainrotSlotId", slotId)
		stand.part:SetAttribute("GeneratedFloorIndex", floorIndex)

		for _, obj in ipairs(stand.container:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj:SetAttribute("BrainrotSlotId", slotId)
				obj:SetAttribute("GeneratedFloorIndex", floorIndex)
			end
		end
	end

	return stands
end

local function getAllBrainrotStands()
	local result = {}

	for _, plot in ipairs(getAllPlots()) do
		for _, stand in ipairs(getBrainrotStands(plot)) do
			table.insert(result, stand)
		end
	end

	return result
end

local function getStrongId(instance)
	if not instance then
		return nil
	end

	local keys = {
		"UID",
		"Uuid",
		"UUID",
		"BrainrotId",
		"BrainrotUID",
		"NpcId",
		"NPCId",
		"UniqueId",
		"UniqueID",
		"InventoryId",
	}

	for _, key in ipairs(keys) do
		local value = instance:GetAttribute(key)
		if value ~= nil and tostring(value) ~= "" then
			return tostring(value)
		end
	end

	return nil
end

local function copyIdentityAttributes(fromInstance, toInstance)
	local keys = {
		"UID",
		"Uuid",
		"UUID",
		"BrainrotId",
		"BrainrotUID",
		"NpcId",
		"NPCId",
		"UniqueId",
		"UniqueID",
		"InventoryId",
		"Rarity",
		"Mutation",
		"BrainrotName",
		"DisplayName",
		"BaseMPS",
		"MPS",
		"CashPerSecond",
		"MoneyPerSecond",
		"Level",
	}

	for _, key in ipairs(keys) do
		local value = fromInstance:GetAttribute(key)
		if value ~= nil then
			toInstance:SetAttribute(key, value)
		end
	end
end

local function playerOwnsNpc(player, npc)
	if not player or not npc then
		return false
	end

	local ownerUserId = npc:GetAttribute("OwnerUserId")
		or npc:GetAttribute("PlacedOwnerUserId")
		or npc:GetAttribute("CapturedByUserId")
		or npc:GetAttribute("UserId")

	local ownerName = npc:GetAttribute("OwnerName")
		or npc:GetAttribute("CapturedBy")
		or npc:GetAttribute("PlayerName")

	if ownerUserId ~= nil and tostring(ownerUserId) == tostring(player.UserId) then
		return true
	end

	if ownerName ~= nil and tostring(ownerName) == player.Name then
		return true
	end

	return false
end

local function npcIsInventoryNpc(npc, player)
	if not npc or not npc:IsA("Model") then
		return false
	end

	if not playerOwnsNpc(player, npc) then
		return false
	end

	if npc:GetAttribute("InventoryOnly") ~= true then
		return false
	end

	if npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true then
		return false
	end

	return true
end

local function getHeldTool(player)
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end

	return nil
end

local function isPlayerAlive(player)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function playerCloseEnoughToStand(player, standPart)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if not root or not standPart or not standPart:IsA("BasePart") then
		return false
	end

	return (root.Position - standPart.Position).Magnitude <= (PROMPT_DISTANCE + 4)
end

local function validateStandInteraction(player, standPart)
	if not isPlayerAlive(player) then
		notify(player, "You need to be alive to use your stand.", "error")
		return false
	end

	if not playerCloseEnoughToStand(player, standPart) then
		notify(player, "Move closer to your Brainrot stand.", "warning")
		return false
	end

	return true
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

	npc:PivotTo(CFrame.new(0, -10000, 0))
end

local function showPlacedNpc(npc)
	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = true
			obj.AssemblyLinearVelocity = Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero

			local originalTransparency = obj:GetAttribute("OriginalTransparency")
			if originalTransparency ~= nil then
				obj.Transparency = tonumber(originalTransparency) or 0
			else
				if obj.Name ~= "HumanoidRootPart" then
					obj.Transparency = 0
				end
			end
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			local originalTransparency = obj:GetAttribute("OriginalTransparency")
			if originalTransparency ~= nil then
				obj.Transparency = tonumber(originalTransparency) or 0
			else
				obj.Transparency = 0
			end
		elseif obj:IsA("ProximityPrompt") then
			obj:Destroy()
		end
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = true
		humanoid.AutoRotate = false
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
end

local function rememberOriginalTransparency(npc)
	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
			if obj:GetAttribute("OriginalTransparency") == nil then
				obj:SetAttribute("OriginalTransparency", obj.Transparency)
			end
		end
	end
end

local function isVisualNpcPart(part)
	if not part:IsA("BasePart") then
		return false
	end

	local lower = string.lower(part.Name)

	if lower == "humanoidrootpart" then
		return false
	end

	if string.find(lower, "hitbox")
		or string.find(lower, "hurtbox")
		or string.find(lower, "collision")
		or string.find(lower, "root")
		or string.find(lower, "shadow")
		or string.find(lower, "range")
		or string.find(lower, "trigger") then
		return false
	end

	if part.Transparency >= 0.85 then
		return false
	end

	if part.Size.X <= 0.03 or part.Size.Y <= 0.03 or part.Size.Z <= 0.03 then
		return false
	end

	return true
end

local function getVisibleBounds(model)
	local parts = {}

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") and isVisualNpcPart(obj) then
			table.insert(parts, obj)
		end
	end

	if #parts == 0 then
		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name ~= "HumanoidRootPart" then
				table.insert(parts, obj)
			end
		end
	end

	if #parts == 0 then
		for _, obj in ipairs(model:GetDescendants()) do
			if obj:IsA("BasePart") then
				table.insert(parts, obj)
			end
		end
	end

	if #parts == 0 then
		return nil
	end

	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(parts) do
		local cf = part.CFrame
		local size = part.Size

		for _, x in ipairs({ -0.5, 0.5 }) do
			for _, y in ipairs({ -0.5, 0.5 }) do
				for _, z in ipairs({ -0.5, 0.5 }) do
					local p = cf * Vector3.new(size.X * x, size.Y * y, size.Z * z)

					minV = Vector3.new(
						math.min(minV.X, p.X),
						math.min(minV.Y, p.Y),
						math.min(minV.Z, p.Z)
					)

					maxV = Vector3.new(
						math.max(maxV.X, p.X),
						math.max(maxV.Y, p.Y),
						math.max(maxV.Z, p.Z)
					)
				end
			end
		end
	end

	return {
		min = minV,
		max = maxV,
		center = (minV + maxV) * 0.5,
		size = maxV - minV,
	}
end

local function pivotNpcOnStand(npc, standPart)
	showPlacedNpc(npc)

	local oldPivot = npc:GetPivot()
	local yaw = math.rad(standPart.Orientation.Y)

	npc:PivotTo(CFrame.new(oldPivot.Position) * CFrame.Angles(0, yaw, 0))

	local bounds = getVisibleBounds(npc)

	if not bounds then
		npc:PivotTo(standPart.CFrame + Vector3.new(0, standPart.Size.Y / 2 + 4, 0))
		return
	end

	local standTopY = standPart.Position.Y + standPart.Size.Y / 2

	local move = Vector3.new(
		standPart.Position.X - bounds.center.X,
		(standTopY + PLACE_Y_OFFSET) - bounds.min.Y,
		standPart.Position.Z - bounds.center.Z
	)

	npc:PivotTo(npc:GetPivot() + move)
end

local function findInventoryNpcForTool(player, tool)
	local toolId = getStrongId(tool)

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npcIsInventoryNpc(npc, player) then
			local npcId = getStrongId(npc)

			if toolId and npcId and toolId == npcId then
				return npc
			end
		end
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npcIsInventoryNpc(npc, player) then
			local npcName = tostring(npc:GetAttribute("BrainrotName") or npc:GetAttribute("DisplayName") or npc.Name)
			local toolName = tostring(tool:GetAttribute("BrainrotName") or tool:GetAttribute("DisplayName") or tool.Name)

			if npcName == toolName or npc.Name == tool.Name then
				return npc
			end
		end
	end

	return nil
end

local function createFallbackNpcFromTool(player, tool)
	local npc = Instance.new("Model")
	npc.Name = tool:GetAttribute("BrainrotName") or tool:GetAttribute("DisplayName") or tool.Name
	npc.Parent = npcFolder

	copyIdentityAttributes(tool, npc)

	npc:SetAttribute("OwnerUserId", player.UserId)
	npc:SetAttribute("OwnerName", player.Name)

	local handle = tool:FindFirstChild("Handle")

	if handle and handle:IsA("BasePart") then
		local clonedHandle = handle:Clone()
		clonedHandle.Name = "Body"
		clonedHandle.Anchored = true
		clonedHandle.CanCollide = false
		clonedHandle.Parent = npc
		npc.PrimaryPart = clonedHandle
	else
		local part = Instance.new("Part")
		part.Name = "Body"
		part.Size = Vector3.new(2, 3, 2)
		part.Color = Color3.fromRGB(255, 214, 80)
		part.Anchored = true
		part.CanCollide = false
		part.Parent = npc
		npc.PrimaryPart = part
	end

	return npc
end

local function removeMatchingTools(player, tool)
	local strongId = getStrongId(tool)
	local toolName = tool.Name

	local containers = {
		player.Character,
		player:FindFirstChildOfClass("Backpack"),
		player:FindFirstChild("StarterGear"),
	}

	for _, container in ipairs(containers) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					local itemId = getStrongId(item)

					if item == tool
						or (strongId and itemId and strongId == itemId)
						or item.Name == toolName then
						item:Destroy()
					end
				end
			end
		end
	end
end

local function createToolFromNpc(player, npc)
	local tool = Instance.new("Tool")
	tool.Name = tostring(npc:GetAttribute("BrainrotName") or npc:GetAttribute("DisplayName") or npc.Name)
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	copyIdentityAttributes(npc, tool)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	tool.Parent = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack")

	return tool
end

local function getStandByOwnerAndSlot(ownerUserId, slotId)
	for _, plot in ipairs(getAllPlots()) do
		if tostring(plot:GetAttribute("OwnerUserId")) == tostring(ownerUserId) then
			for _, stand in ipairs(getBrainrotStands(plot)) do
				if tostring(stand.part:GetAttribute("BrainrotSlotId") or "") == tostring(slotId) then
					return stand.part
				end
			end
		end
	end

	return nil
end

local function findOccupiedNpc(player, standPart)
	local slotId = tostring(standPart:GetAttribute("BrainrotSlotId") or "")
	local plot = findPlotFromPart(standPart)

	if slotId == "" or not plot then
		return nil
	end

	local ownerId = tostring(plot:GetAttribute("OwnerUserId") or player.UserId)

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model")
			and npc:GetAttribute("InventoryOnly") ~= true
			and (npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true)
			and tostring(npc:GetAttribute("PlacedOwnerUserId")) == ownerId
			and tostring(npc:GetAttribute("AssignedSlotId")) == slotId then
			return npc
		end
	end

	return nil
end

local function cleanupDuplicatePlacedNpcs()
	local byOwnerSlot = {}
	local byStrongId = {}

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model")
			and npc:GetAttribute("InventoryOnly") ~= true
			and (npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true) then

			local ownerId = tostring(npc:GetAttribute("PlacedOwnerUserId") or npc:GetAttribute("OwnerUserId") or "")
			local slotId = tostring(npc:GetAttribute("AssignedSlotId") or "")

			if ownerId ~= "" and slotId ~= "" then
				local key = ownerId .. "::" .. slotId
				byOwnerSlot[key] = byOwnerSlot[key] or {}
				table.insert(byOwnerSlot[key], npc)
			end

			local strongId = getStrongId(npc)
			if ownerId ~= "" and strongId then
				local key = ownerId .. "::ID::" .. strongId
				byStrongId[key] = byStrongId[key] or {}
				table.insert(byStrongId[key], npc)
			end
		end
	end

	for key, list in pairs(byOwnerSlot) do
		if #list > 1 then
			table.sort(list, function(a, b)
				local ownerId = a:GetAttribute("PlacedOwnerUserId") or a:GetAttribute("OwnerUserId")
				local slotId = a:GetAttribute("AssignedSlotId")
				local stand = getStandByOwnerAndSlot(ownerId, slotId)

				if stand then
					local da = (a:GetPivot().Position - stand.Position).Magnitude
					local db = (b:GetPivot().Position - stand.Position).Magnitude
					return da < db
				end

				return a:GetDebugId() < b:GetDebugId()
			end)

			for i = 2, #list do
				if list[i] and list[i].Parent then
					warn("[BrainrotToolPlacement] Removed duplicate NPC in same slot:", list[i]:GetFullName())
					list[i]:Destroy()
				end
			end
		end
	end

	for key, list in pairs(byStrongId) do
		if #list > 1 then
			table.sort(list, function(a, b)
				local aSlot = tostring(a:GetAttribute("AssignedSlotId") or "")
				local bSlot = tostring(b:GetAttribute("AssignedSlotId") or "")

				if aSlot ~= "" and bSlot == "" then
					return true
				end

				if aSlot == "" and bSlot ~= "" then
					return false
				end

				return a:GetDebugId() < b:GetDebugId()
			end)

			for i = 2, #list do
				if list[i] and list[i].Parent then
					warn("[BrainrotToolPlacement] Removed duplicate NPC with same ID:", list[i]:GetFullName())
					list[i]:Destroy()
				end
			end
		end
	end
end

local function removeDuplicateCopiesForNpc(player, npcToKeep)
	local keepId = getStrongId(npcToKeep)
	if not keepId then
		return
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model")
			and npc ~= npcToKeep
			and playerOwnsNpc(player, npc)
			and getStrongId(npc) == keepId
			and npc:GetAttribute("InventoryOnly") ~= true
			and (npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true) then
			warn("[BrainrotToolPlacement] Removed extra placed copy before placing:", npc:GetFullName())
			npc:Destroy()
		end
	end
end

local function placeNpc(player, standPart)
	if not validateStandInteraction(player, standPart) then
		return
	end

	local plot = findPlotFromPart(standPart)

	if not playerOwnsPlot(player, plot) then
		notify(player, "This is not your plot.", "error")
		return
	end

	local slotId = tostring(standPart:GetAttribute("BrainrotSlotId") or "")
	local floorIndex = tonumber(standPart:GetAttribute("GeneratedFloorIndex")) or getFloorIndex(standPart)

	if slotId == "" then
		notify(player, "This stand is not ready yet.", "error")
		return
	end

	local occupied = findOccupiedNpc(player, standPart)
	if occupied then
		return
	end

	local tool = getHeldTool(player)

	if not tool then
		notify(player, "Hold a brainrot to place it.", "warning")
		return
	end

	local npc = findInventoryNpcForTool(player, tool)

	if not npc then
		npc = createFallbackNpcFromTool(player, tool)
	end

	rememberOriginalTransparency(npc)

	npc.Parent = npcFolder

	copyIdentityAttributes(tool, npc)

	local mps = tonumber(npc:GetAttribute("CashPerSecond"))
		or tonumber(npc:GetAttribute("MPS"))
		or tonumber(npc:GetAttribute("MoneyPerSecond"))
		or tonumber(tool:GetAttribute("CashPerSecond"))
		or tonumber(tool:GetAttribute("MPS"))
		or tonumber(tool:GetAttribute("MoneyPerSecond"))
		or 1

	local level = tonumber(npc:GetAttribute("Level")) or tonumber(tool:GetAttribute("Level")) or 1

	npc:SetAttribute("InventoryOnly", false)
	npc:SetAttribute("IsPlaced", true)
	npc:SetAttribute("Placed", true)

	npc:SetAttribute("OwnerUserId", player.UserId)
	npc:SetAttribute("OwnerName", player.Name)
	npc:SetAttribute("PlacedOwnerUserId", player.UserId)

	npc:SetAttribute("AssignedSlotId", slotId)
	npc:SetAttribute("AssignedSlotPath", standPart:GetFullName())
	npc:SetAttribute("AssignedHouseGoal", "Brainrot Stand")
	npc:SetAttribute("GeneratedFloorIndex", floorIndex)

	npc:SetAttribute("CashPerSecond", mps)
	npc:SetAttribute("MPS", mps)
	npc:SetAttribute("Level", level)

	if npc:GetAttribute("Earned") == nil then
		npc:SetAttribute("Earned", 0)
	end

	removeDuplicateCopiesForNpc(player, npc)

	pivotNpcOnStand(npc, standPart)
	removeMatchingTools(player, tool)

	cleanupDuplicatePlacedNpcs()
	saveSnapshot(player)
	emitGameplayEvent("BrainrotPlaced", player, {
		source = "BrainrotToolPlacement",
		brainrotId = npc:GetAttribute("BrainrotConfigId"),
		displayName = npc:GetAttribute("DisplayName") or npc.Name,
		rarity = npc:GetAttribute("Rarity"),
		slotId = slotId,
		floorIndex = floorIndex,
	})

	print("[BrainrotToolPlacement] Placed", npc.Name, "on", slotId, "floor", floorIndex, "for", player.Name)
end

local function returnNpc(player, standPart)
	if not validateStandInteraction(player, standPart) then
		return
	end

	local plot = findPlotFromPart(standPart)

	if not playerOwnsPlot(player, plot) then
		notify(player, "This is not your plot.", "error")
		return
	end

	local npc = findOccupiedNpc(player, standPart)

	if not npc then
		return
	end

	createToolFromNpc(player, npc)

	npc:SetAttribute("InventoryOnly", true)
	npc:SetAttribute("IsPlaced", false)
	npc:SetAttribute("Placed", false)
	npc:SetAttribute("AssignedSlotId", nil)
	npc:SetAttribute("AssignedSlotPath", nil)
	npc:SetAttribute("AssignedHouseGoal", nil)
	npc:SetAttribute("PlacedOwnerUserId", nil)
	npc:SetAttribute("Earned", 0)

	hideInventoryNpc(npc)

	saveSnapshot(player)

	print("[BrainrotToolPlacement] Returned", npc.Name, "for", player.Name)
end

local function cleanupPromptsInStand(standContainer, keepPrompt)
	for _, obj in ipairs(standContainer:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj ~= keepPrompt then
			obj:Destroy()
		end
	end
end

local function setupStand(stand)
	local standPart = stand.part
	local standContainer = stand.container

	if not standPart or not standPart.Parent then
		return
	end

	local prompt = standPart:FindFirstChild(PROMPT_NAME)

	if not prompt or not prompt:IsA("ProximityPrompt") then
		if prompt then
			prompt:Destroy()
		end

		prompt = Instance.new("ProximityPrompt")
		prompt.Name = PROMPT_NAME
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.RequiresLineOfSight = false
		prompt.HoldDuration = PROMPT_HOLD_DURATION
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.Parent = standPart
	end

	cleanupPromptsInStand(standContainer, prompt)

	prompt.ObjectText = "Brainrot Stand"
	prompt.ActionText = "Place Brainrot"
	prompt.Enabled = true

	if not connectedPrompts[prompt] then
		connectedPrompts[prompt] = true

		prompt.Triggered:Connect(function(player)
			local plot = findPlotFromPart(standPart)

			if not playerOwnsPlot(player, plot) then
				notify(player, "This is not your plot.", "error")
				return
			end

			local occupied = findOccupiedNpc(player, standPart)

			if occupied then
				returnNpc(player, standPart)
			else
				placeNpc(player, standPart)
			end
		end)
	end
end

local function refreshPrompts()
	for _, stand in ipairs(getAllBrainrotStands()) do
		setupStand(stand)

		local prompt = stand.part:FindFirstChild(PROMPT_NAME)

		if prompt and prompt:IsA("ProximityPrompt") then
			local plot = findPlotFromPart(stand.part)
			local ownerId = plot and plot:GetAttribute("OwnerUserId")

			local occupied = nil
			if ownerId then
				for _, npc in ipairs(npcFolder:GetChildren()) do
					if npc:IsA("Model")
						and npc:GetAttribute("InventoryOnly") ~= true
						and (npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true)
						and tostring(npc:GetAttribute("PlacedOwnerUserId")) == tostring(ownerId)
						and tostring(npc:GetAttribute("AssignedSlotId")) == tostring(stand.part:GetAttribute("BrainrotSlotId")) then
						occupied = npc
						break
					end
				end
			end

			if occupied then
				prompt.ActionText = "Return Brainrot"
			else
				prompt.ActionText = "Place Brainrot"
			end
		end
	end
end

task.spawn(function()
	task.wait(1)

	while true do
		refreshPrompts()
		task.wait(REFRESH_EVERY)
	end
end)

task.spawn(function()
	task.wait(3)

	while true do
		cleanupDuplicatePlacedNpcs()
		task.wait(DUPLICATE_CLEANUP_EVERY)
	end
end)

print("[BrainrotToolPlacement] Loaded FLOOR-AWARE placement. Duplicate floor spawning fixed.")
