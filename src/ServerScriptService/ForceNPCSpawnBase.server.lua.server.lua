-- ServerScriptService/ForceNPCSpawnBase.server.lua
-- Temporary script:
-- makes wild NPCs spawn / appear on the spawn base for now.

local Workspace = game:GetService("Workspace")

local NPC_FOLDER = Workspace:WaitForChild("BrainrotNPCs")
local SpawnMap = Workspace:WaitForChild("SpawnMap")

local SPAWN_BASE_NAMES = {
	"SpawnBase_MainPlatform",
	"CentralSpawnPlaza",
	"PlayerSpawn_NewBase",
	"SpawnLocation",
}

local rng = Random.new()

local function findSpawnBasePart()
	for _, wantedName in ipairs(SPAWN_BASE_NAMES) do
		local found = SpawnMap:FindFirstChild(wantedName, true)
			or Workspace:FindFirstChild(wantedName, true)

		if found and found:IsA("BasePart") then
			return found
		end
	end

	for _, obj in ipairs(SpawnMap:GetDescendants()) do
		if obj:IsA("BasePart") then
			local lower = string.lower(obj.Name)
			if string.find(lower, "spawn") and string.find(lower, "base") then
				return obj
			end
		end
	end

	warn("[ForceNPCSpawnBase] Could not find spawn base part.")
	return nil
end

local function isWildNPC(npc)
	if not npc:IsA("Model") then
		return false
	end

	if npc:GetAttribute("IsPlaced") == true then
		return false
	end

	if npc:GetAttribute("HeldBy") ~= nil then
		return false
	end

	return true
end

local function moveNPCToSpawnBase(npc)
	if not isWildNPC(npc) then
		return
	end

	local spawnBase = findSpawnBasePart()
	if not spawnBase then
		return
	end

	task.wait(0.15)

	if not npc.Parent or not isWildNPC(npc) then
		return
	end

	local size = spawnBase.Size
	local x = rng:NextNumber(-size.X * 0.35, size.X * 0.35)
	local z = rng:NextNumber(-size.Z * 0.35, size.Z * 0.35)

	local targetCFrame = spawnBase.CFrame * CFrame.new(x, 5, z)

	pcall(function()
		npc:PivotTo(targetCFrame)
	end)

	npc:SetAttribute("ForcedSpawnBase", true)
end

for _, npc in ipairs(NPC_FOLDER:GetChildren()) do
	if npc:IsA("Model") then
		task.spawn(moveNPCToSpawnBase, npc)
	end
end

NPC_FOLDER.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		task.spawn(moveNPCToSpawnBase, child)
	end
end)

print("[ForceNPCSpawnBase] Loaded. Wild NPCs will appear on the spawn base.")