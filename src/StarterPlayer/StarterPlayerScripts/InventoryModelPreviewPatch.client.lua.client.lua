-- StarterPlayerScripts/InventoryModelPreviewPatch.client.lua
-- Adds actual model previews to inventory cards.

--!nonstrict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local npcFolder = workspace:WaitForChild("BrainrotNPCs")

local patchedCards = {}

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

local function ownedByPlayer(npc)
	if not npc:IsA("Model") then
		return false
	end

	if npc:GetAttribute("PlacedOwnerUserId") == player.UserId then
		return true
	end

	if npc:GetAttribute("OwnerUserId") == player.UserId then
		return true
	end

	if tostring(npc:GetAttribute("PlacedOwnerUserId")) == tostring(player.UserId) then
		return true
	end

	if tostring(npc:GetAttribute("OwnerUserId")) == tostring(player.UserId) then
		return true
	end

	if tostring(npc:GetAttribute("Owner")) == player.Name then
		return true
	end

	return false
end

local function getDisplayName(npc)
	return tostring(
		npc:GetAttribute("TemplateName")
			or npc:GetAttribute("templateName")
			or npc:GetAttribute("DisplayName")
			or npc.Name
	)
end

local function findNpcForCard(card)
	local cardNpcName = tostring(card:GetAttribute("NpcName") or card.Name)
	local cardDisplayName = tostring(card:GetAttribute("DisplayName") or "")

	for _, npc in ipairs(npcFolder:GetDescendants()) do
		if npc:IsA("Model") and ownedByPlayer(npc) then
			local displayName = getDisplayName(npc)

			if npc.Name == cardNpcName or displayName == cardNpcName or displayName == cardDisplayName then
				return npc
			end
		end
	end

	return nil
end

local function cleanClone(model)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("Script") or obj:IsA("LocalScript") then
			obj:Destroy()
		elseif obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
		elseif obj:IsA("ProximityPrompt") or obj:IsA("BillboardGui") then
			obj:Destroy()
		end
	end
end

local function patchCard(card)
	if patchedCards[card] then
		return
	end

	if not card:IsA("Frame") then
		return
	end

	if not card:GetAttribute("NpcName") then
		return
	end

	local npc = findNpcForCard(card)
	if not npc then
		return
	end

	patchedCards[card] = true

	local emoji = card:FindFirstChild("Emoji")
	if emoji then
		emoji:Destroy()
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "BrainrotPreview"
	viewport.Position = UDim2.new(0.5, -56, 0, 5)
	viewport.Size = UDim2.fromOffset(112, 86)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Ambient = Color3.fromRGB(190, 190, 210)
	viewport.ZIndex = 25
	viewport.Parent = card

	local world = Instance.new("WorldModel")
	world.Name = "World"
	world.Parent = viewport

	local clone = npc:Clone()
	cleanClone(clone)
	clone.Parent = world

	local root = getNpcRoot(clone)
	if root then
		clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0))
	end

	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local cf, size = clone:GetBoundingBox()
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = math.max(7, maxSize * 1.8)

	camera.CFrame = CFrame.new(
		cf.Position + Vector3.new(0, maxSize * 0.25, distance),
		cf.Position + Vector3.new(0, maxSize * 0.15, 0)
	)

	local angle = 0
	local connection

	connection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent or not clone.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		angle += dt * 0.85
		clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, angle, 0))
	end)
end

local function patchInventory()
	local hud = playerGui:FindFirstChild("CartoonSimulatorHUD")
	if not hud then
		return
	end

	local popup = hud:FindFirstChild("INVENTORYPopup")
	if not popup then
		return
	end

	local panel = popup:FindFirstChild("Panel")
	if not panel then
		return
	end

	for _, obj in ipairs(panel:GetDescendants()) do
		if obj:IsA("Frame") and obj:GetAttribute("NpcName") then
			patchCard(obj)
		end
	end
end

task.spawn(function()
	while true do
		patchInventory()
		task.wait(0.35)
	end
end)

print("[InventoryModelPreviewPatch] loaded")