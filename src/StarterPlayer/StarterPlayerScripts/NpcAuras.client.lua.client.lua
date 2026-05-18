--!nonstrict
-- StarterPlayerScripts/NpcAuras.client.lua
-- FIXED: attaches fire aura to Brainrot NPCs even when the NPC model has no Humanoid.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local FireAura = require(ReplicatedStorage:WaitForChild("FireAura"))

local NPC_FOLDER_NAME = "BrainrotNPCs"
local TAG = "FireAuraNPC"

local RETRY_SECONDS = 5
local RETRY_STEP = 0.2

local handles = {}
local attaching = {}
local boundFolders = {}

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function isPlayerCharacter(model)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character == model then
			return true
		end
	end

	return false
end

local function getRoot(model)
	if not model or not model:IsA("Model") then
		return nil
	end

	local root = model:FindFirstChild("HumanoidRootPart", true)
		or model:FindFirstChild("Torso", true)
		or model:FindFirstChild("UpperTorso", true)

	if root and root:IsA("BasePart") then
		return root
	end

	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function isBrainrotNpc(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if isPlayerCharacter(model) then
		return false
	end

	if model:GetAttribute("InventoryOnly") == true then
		return false
	end

	local npcFolder = getNpcFolder()
	if npcFolder and model.Parent == npcFolder then
		return true
	end

	if CollectionService:HasTag(model, TAG) then
		return true
	end

	return model:GetAttribute("ForestSpawned") == true
		or model:GetAttribute("IsBrainrot") == true
		or model:GetAttribute("BrainrotUID") ~= nil
		or model:GetAttribute("BrainrotName") ~= nil
		or model:GetAttribute("Rarity") ~= nil
		or model:GetAttribute("MPS") ~= nil
		or model:GetAttribute("CashPerSecond") ~= nil
end

local function getNpcModelFromDescendant(instance)
	local npcFolder = getNpcFolder()
	if not npcFolder then
		return nil
	end

	local current = instance
	while current and current ~= npcFolder do
		if current.Parent == npcFolder and current:IsA("Model") then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function detachFrom(npc)
	attaching[npc] = nil

	local handle = handles[npc]
	if handle then
		pcall(function()
			handle:Destroy()
		end)
		handles[npc] = nil
	end
end

local function attachTo(npc)
	if handles[npc] or attaching[npc] then
		return
	end

	if not isBrainrotNpc(npc) then
		return
	end

	attaching[npc] = true

	task.spawn(function()
		local deadline = os.clock() + RETRY_SECONDS

		while npc.Parent and os.clock() <= deadline do
			if isBrainrotNpc(npc) and getRoot(npc) then
				local ok, handle = pcall(function()
					return FireAura.Attach(npc, {
						Quality = "Ultra",
					})
				end)

				if ok and handle then
					handles[npc] = handle
					attaching[npc] = nil
					return
				end

				if not ok then
					warn("[NpcAuras] FireAura attach failed for", npc:GetFullName(), handle)
				end
			end

			task.wait(RETRY_STEP)
		end

		attaching[npc] = nil
	end)
end

local function scanFolder(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			task.defer(attachTo, child)
		end
	end
end

local function bindFolder(folder)
	if not folder or boundFolders[folder] then
		return
	end

	boundFolders[folder] = true

	scanFolder(folder)

	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.defer(attachTo, child)
		end
	end)

	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			detachFrom(child)
		end
	end)

	folder.AncestryChanged:Connect(function(_, parent)
		if not parent then
			boundFolders[folder] = nil
		end
	end)
end

local npcFolder = getNpcFolder()
if npcFolder then
	bindFolder(npcFolder)
end

Workspace.ChildAdded:Connect(function(child)
	if child.Name == NPC_FOLDER_NAME then
		task.defer(function()
			bindFolder(child)
		end)
	end
end)

for _, tagged in ipairs(CollectionService:GetTagged(TAG)) do
	if tagged:IsA("Model") then
		task.defer(attachTo, tagged)
	end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
	if instance:IsA("Model") then
		task.defer(attachTo, instance)
	end
end)

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
	if instance:IsA("Model") then
		detachFrom(instance)
	end
end)

Workspace.DescendantAdded:Connect(function(instance)
	local npc = getNpcModelFromDescendant(instance)
	if npc then
		task.defer(attachTo, npc)
	end
end)

Workspace.DescendantRemoving:Connect(function(instance)
	if handles[instance] or attaching[instance] then
		detachFrom(instance)
	end
end)

print("[NpcAuras] Fixed fire aura client loaded.")