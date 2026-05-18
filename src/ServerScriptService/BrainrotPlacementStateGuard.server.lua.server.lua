--!nonstrict
-- ServerScriptService/BrainrotPlacementStateGuard.server.lua
-- Fixes:
-- 1. Placed brainrot earns money but is invisible.
-- 2. Same brainrot/tool gets restored after placement.
-- 3. Duplicate placed brainrots with same UID/name/slot.
-- 4. Makes placed NPCs visible and snapped to their exact slot.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local CHECK_EVERY = 0.2
local SNAP_Y_OFFSET = 0.34

local TOOL_BLOCK_ATTRIBUTE = "PlacementGuardRemoved"

local function getNpcFolder()
	local folder = Workspace:FindFirstChild(NPC_FOLDER_NAME)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = NPC_FOLDER_NAME
		folder.Parent = Workspace
	end

	return folder
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

local function getBrainrotName(instance)
	if not instance then
		return ""
	end

	return tostring(
		instance:GetAttribute("BrainrotName")
			or instance:GetAttribute("DisplayName")
			or instance.Name
	)
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

local function getPlotForOwner(ownerId)
	for _, plot in ipairs(getAllPlots()) do
		if tostring(plot:GetAttribute("OwnerUserId")) == tostring(ownerId) then
			return plot
		end
	end

	return nil
end

local function findStandForNpc(npc)
	local ownerId = npc:GetAttribute("PlacedOwnerUserId") or npc:GetAttribute("OwnerUserId")
	if not ownerId then
		return nil
	end

	local plot = getPlotForOwner(ownerId)
	if not plot then
		return nil
	end

	local stands = getBrainrotStands(plot)
	local slotId = tostring(npc:GetAttribute("AssignedSlotId") or "")

	if slotId ~= "" then
		for _, stand in ipairs(stands) do
			if tostring(stand.part:GetAttribute("BrainrotSlotId") or "") == slotId then
				return stand.part
			end
		end
	end

	return nil
end

local function isInvisibleUtilityPart(part)
	local lower = string.lower(part.Name)

	return lower == "humanoidrootpart"
		or string.find(lower, "hitbox")
		or string.find(lower, "hurtbox")
		or string.find(lower, "collision")
		or string.find(lower, "root")
		or string.find(lower, "shadow")
		or string.find(lower, "range")
		or string.find(lower, "trigger")
end

local function forcePlacedNpcVisible(npc)
	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = true
			obj.Massless = true
			obj.AssemblyLinearVelocity = Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero

			if isInvisibleUtilityPart(obj) then
				obj.Transparency = 1
			else
				obj.Transparency = 0
			end
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			obj.Transparency = 0
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

local function isVisualNpcPart(part)
	if not part:IsA("BasePart") then
		return false
	end

	if isInvisibleUtilityPart(part) then
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

local function snapNpcToStand(npc, standPart)
	if not npc or not npc.Parent or not standPart then
		return
	end

	forcePlacedNpcVisible(npc)

	local oldPivot = npc:GetPivot()
	local yaw = math.rad(standPart.Orientation.Y)

	npc:PivotTo(CFrame.new(oldPivot.Position) * CFrame.Angles(0, yaw, 0))

	local bounds = getVisibleBounds(npc)
	if not bounds then
		return
	end

	local standTopY = standPart.Position.Y + standPart.Size.Y / 2

	local move = Vector3.new(
		standPart.Position.X - bounds.center.X,
		(standTopY + SNAP_Y_OFFSET) - bounds.min.Y,
		standPart.Position.Z - bounds.center.Z
	)

	npc:PivotTo(npc:GetPivot() + move)

	npc:SetAttribute("AssignedSlotPath", standPart:GetFullName())
	npc:SetAttribute("AssignedHouseGoal", "Brainrot Stand")
	npc:SetAttribute("GeneratedFloorIndex", standPart:GetAttribute("GeneratedFloorIndex") or getFloorIndex(standPart))
end

local function getPlayerByUserId(userId)
	for _, player in ipairs(Players:GetPlayers()) do
		if tostring(player.UserId) == tostring(userId) then
			return player
		end
	end

	return nil
end

local function getToolContainers(player)
	local containers = {}

	if player.Character then
		table.insert(containers, player.Character)
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end

	local starterGear = player:FindFirstChild("StarterGear")
	if starterGear then
		table.insert(containers, starterGear)
	end

	return containers
end

local function removeToolCopiesForPlacedNpc(npc)
	local ownerId = npc:GetAttribute("PlacedOwnerUserId") or npc:GetAttribute("OwnerUserId")
	if not ownerId then
		return
	end

	local player = getPlayerByUserId(ownerId)
	if not player then
		return
	end

	local npcId = getStrongId(npc)
	local npcName = getBrainrotName(npc)

	for _, container in ipairs(getToolContainers(player)) do
		for _, item in ipairs(container:GetChildren()) do
			if item:IsA("Tool") then
				local itemId = getStrongId(item)
				local itemName = getBrainrotName(item)

				local sameId = npcId and itemId and npcId == itemId
				local sameName = npcId == nil and itemName == npcName

				if sameId or sameName then
					item:SetAttribute(TOOL_BLOCK_ATTRIBUTE, true)
					item:Destroy()
				end
			end
		end
	end
end

local function cleanupDuplicatePlacedNpcs()
	local npcFolder = getNpcFolder()
	local byOwnerSlot = {}
	local byOwnerId = {}

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isPlacedNpc(npc) then
			local ownerId = tostring(npc:GetAttribute("PlacedOwnerUserId") or npc:GetAttribute("OwnerUserId") or "")
			local slotId = tostring(npc:GetAttribute("AssignedSlotId") or "")
			local strongId = getStrongId(npc)

			if ownerId ~= "" and slotId ~= "" then
				local key = ownerId .. "::slot::" .. slotId
				byOwnerSlot[key] = byOwnerSlot[key] or {}
				table.insert(byOwnerSlot[key], npc)
			end

			if ownerId ~= "" and strongId then
				local key = ownerId .. "::id::" .. strongId
				byOwnerId[key] = byOwnerId[key] or {}
				table.insert(byOwnerId[key], npc)
			end
		end
	end

	local function keepBest(list)
		table.sort(list, function(a, b)
			local aEarned = tonumber(a:GetAttribute("Earned")) or 0
			local bEarned = tonumber(b:GetAttribute("Earned")) or 0

			if aEarned ~= bEarned then
				return aEarned > bEarned
			end

			return a:GetDebugId() < b:GetDebugId()
		end)

		for i = 2, #list do
			if list[i] and list[i].Parent then
				warn("[BrainrotPlacementStateGuard] Removed duplicate placed NPC:", list[i]:GetFullName())
				list[i]:Destroy()
			end
		end
	end

	for _, list in pairs(byOwnerSlot) do
		if #list > 1 then
			keepBest(list)
		end
	end

	for _, list in pairs(byOwnerId) do
		if #list > 1 then
			keepBest(list)
		end
	end
end

local function repairPlacedBrainrots()
	local npcFolder = getNpcFolder()

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if isInventoryNpc(npc) then
			hideInventoryNpc(npc)
		elseif isPlacedNpc(npc) then
			npc:SetAttribute("InventoryOnly", false)
			npc:SetAttribute("IsPlaced", true)
			npc:SetAttribute("Placed", true)

			local standPart = findStandForNpc(npc)

			if standPart then
				snapNpcToStand(npc, standPart)
			else
				forcePlacedNpcVisible(npc)
			end

			removeToolCopiesForPlacedNpc(npc)
		end
	end

	cleanupDuplicatePlacedNpcs()
end

task.spawn(function()
	task.wait(2)

	while true do
		repairPlacedBrainrots()
		task.wait(CHECK_EVERY)
	end
end)

print("[BrainrotPlacementStateGuard] Loaded. Placement visibility + duplicate tool guard enabled.")