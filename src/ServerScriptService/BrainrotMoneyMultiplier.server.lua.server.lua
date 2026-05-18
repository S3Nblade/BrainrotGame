--!nonstrict
-- ServerScriptService/BrainrotMoneyMultiplier.server.lua
-- Multiplies Brainrot Earned money by player MoneyMultiplier/Rebirths.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local tracked = {}

local function getPlayerByUserId(userId)
	userId = tonumber(userId)
	if not userId then
		return nil
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end

	return nil
end

local function getNpcOwnerPlayer(npc)
	local owner =
		npc:GetAttribute("PlacedOwnerUserId")
		or npc:GetAttribute("OwnerUserId")
		or npc:GetAttribute("ClaimedOwnerUserId")
		or npc:GetAttribute("CaughtOwnerUserId")
		or npc:GetAttribute("ownerUserId")

	return getPlayerByUserId(owner)
end

local function getMoneyMultiplier(player)
	local multiplier =
		tonumber(player:GetAttribute("MoneyMultiplier"))
		or tonumber(player:GetAttribute("MoneyRegenMultiplier"))
		or 1

	if multiplier < 1 then
		multiplier = 1
	end

	return multiplier
end

local function isPlacedBrainrot(npc)
	return npc:IsA("Model")
		and (
			npc:GetAttribute("IsPlaced") == true
			or npc:GetAttribute("Placed") == true
		)
end

local function trackNpc(npc)
	if tracked[npc] or not npc:IsA("Model") then
		return
	end

	tracked[npc] = {
		lastEarned = tonumber(npc:GetAttribute("Earned")) or 0,
		patching = false,
	}

	npc:GetAttributeChangedSignal("Earned"):Connect(function()
		local state = tracked[npc]
		if not state then
			return
		end

		local newEarned = tonumber(npc:GetAttribute("Earned")) or 0

		if state.patching then
			state.lastEarned = newEarned
			state.patching = false
			return
		end

		local oldEarned = state.lastEarned or 0
		state.lastEarned = newEarned

		local delta = newEarned - oldEarned

		if delta <= 0 then
			return
		end

		if not isPlacedBrainrot(npc) then
			return
		end

		local owner = getNpcOwnerPlayer(npc)
		if not owner then
			return
		end

		local multiplier = getMoneyMultiplier(owner)
		if multiplier <= 1 then
			return
		end

		local extra = delta * (multiplier - 1)
		local finalEarned = newEarned + extra

		state.patching = true
		state.lastEarned = finalEarned
		npc:SetAttribute("Earned", finalEarned)
	end)

	npc.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			tracked[npc] = nil
		end
	end)
end

local function scanFolder(folder)
	for _, descendant in ipairs(folder:GetDescendants()) do
		if descendant:IsA("Model") then
			trackNpc(descendant)
		end
	end
end

local function start()
	local folder = Workspace:FindFirstChild(NPC_FOLDER_NAME)
	if not folder then
		folder = Workspace:WaitForChild(NPC_FOLDER_NAME)
	end

	scanFolder(folder)

	folder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") then
			task.wait(0.05)
			trackNpc(descendant)
		end
	end)
end

task.spawn(start)

print("[BrainrotMoneyMultiplier] Loaded. Earned money is multiplied by rebirth MoneyMultiplier.")