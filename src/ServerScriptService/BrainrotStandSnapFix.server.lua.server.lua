--!nonstrict
-- ServerScriptService/BrainrotStandSnapFix.server.lua
-- FULL REPLACEMENT
-- Floor-aware slot IDs.
-- Prevents first-floor NPCs from snapping/jumping to new generated floors.

local Workspace = game:GetService("Workspace")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local SNAP_EVERY = 0.12
local STAND_Y_OFFSET = 0.28

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

local function getPlotForOwner(ownerUserId)
	for _, plot in ipairs(getAllPlots()) do
		if tostring(plot:GetAttribute("OwnerUserId")) == tostring(ownerUserId) then
			return plot
		end
	end

	return nil
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

local function freezeNpc(npc)
	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = true
			obj.Massless = true
			obj.AssemblyLinearVelocity = Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero
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

	if #stands == 0 then
		return nil
	end

	local slotId = tostring(npc:GetAttribute("AssignedSlotId") or "")

	if slotId ~= "" then
		for _, stand in ipairs(stands) do
			if tostring(stand.part:GetAttribute("BrainrotSlotId") or "") == slotId then
				return stand.part
			end
		end
	end

	local currentPosition = npc:GetPivot().Position
	local nearestStand = nil
	local nearestDistance = math.huge

	for _, stand in ipairs(stands) do
		local distance = (stand.part.Position - currentPosition).Magnitude

		if distance < nearestDistance then
			nearestDistance = distance
			nearestStand = stand
		end
	end

	if nearestStand then
		local newSlotId = tostring(nearestStand.part:GetAttribute("BrainrotSlotId") or "")

		npc:SetAttribute("AssignedSlotId", newSlotId)
		npc:SetAttribute("AssignedSlotPath", nearestStand.part:GetFullName())
		npc:SetAttribute("AssignedHouseGoal", "Brainrot Stand")

		return nearestStand.part
	end

	return nil
end

local function snapNpcToStand(npc, standPart)
	if not npc or not npc.Parent or not standPart then
		return
	end

	freezeNpc(npc)

	local yaw = math.rad(standPart.Orientation.Y)
	local oldPivot = npc:GetPivot()

	npc:PivotTo(CFrame.new(oldPivot.Position) * CFrame.Angles(0, yaw, 0))

	local bounds = getVisibleBounds(npc)
	if not bounds then
		return
	end

	local standTopY = standPart.Position.Y + standPart.Size.Y / 2

	local move = Vector3.new(
		standPart.Position.X - bounds.center.X,
		(standTopY + STAND_Y_OFFSET) - bounds.min.Y,
		standPart.Position.Z - bounds.center.Z
	)

	npc:PivotTo(npc:GetPivot() + move)

	npc:SetAttribute("AssignedHouseGoal", "Brainrot Stand")
	npc:SetAttribute("AssignedSlotPath", standPart:GetFullName())
end

local function isPlacedNpc(npc)
	return npc:IsA("Model")
		and npc:GetAttribute("InventoryOnly") ~= true
		and (npc:GetAttribute("IsPlaced") == true or npc:GetAttribute("Placed") == true)
end

task.spawn(function()
	while true do
		for _, npc in ipairs(getNpcFolder():GetChildren()) do
			if isPlacedNpc(npc) then
				local standPart = findStandForNpc(npc)

				if standPart then
					snapNpcToStand(npc, standPart)
				end
			end
		end

		task.wait(SNAP_EVERY)
	end
end)

print("[BrainrotStandSnapFix] Loaded. Floor-aware NPC snapping enabled.")