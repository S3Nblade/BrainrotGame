--!nonstrict
-- HideNpcVisualPatch.client.lua
-- Hides overhead labels while NPC is hiding.

local npcFolder = workspace:WaitForChild("BrainrotNPCs")

local function getRoot(npc)
	local root = npc:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		return root
	end

	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	return nil
end

local function updateNpc(npc)
	if not npc:IsA("Model") then
		return
	end

	local root = getRoot(npc)
	if not root then
		return
	end

	local isHiding = npc:GetAttribute("IsHiding") == true
	local stunned = npc:GetAttribute("CaptureStunned") == true
	local placed = npc:GetAttribute("IsPlaced") == true
	local heldBy = npc:GetAttribute("HeldBy")
	local held = heldBy ~= nil and heldBy ~= 0 and heldBy ~= ""

	local shouldHideOverhead = isHiding and not stunned and not placed and not held

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("BillboardGui") then
			if obj.Name == "NPCOverheadGui" or obj.Name == "CaptureHealthBar" then
				obj.Enabled = not shouldHideOverhead
			end
		end
	end
end

local function bindNpc(npc)
	if not npc:IsA("Model") then
		return
	end

	npc:GetAttributeChangedSignal("IsHiding"):Connect(function()
		updateNpc(npc)
	end)

	npc:GetAttributeChangedSignal("CaptureStunned"):Connect(function()
		updateNpc(npc)
	end)

	npc:GetAttributeChangedSignal("IsPlaced"):Connect(function()
		updateNpc(npc)
	end)

	npc:GetAttributeChangedSignal("HeldBy"):Connect(function()
		updateNpc(npc)
	end)

	task.spawn(function()
		while npc.Parent do
			updateNpc(npc)
			task.wait(0.25)
		end
	end)
end

for _, npc in ipairs(npcFolder:GetChildren()) do
	bindNpc(npc)
end

npcFolder.ChildAdded:Connect(function(npc)
	task.wait(0.25)
	bindNpc(npc)
end)

print("[HideNpcVisualPatch] loaded")