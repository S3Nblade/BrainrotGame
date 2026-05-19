-- StarterPlayerScripts/NPCOverheadGui
-- Full replacement
-- Normal overhead money/name GUI.
-- It hides completely during capture / stunned / evading so it cannot collide with the chase HP bar.

--!nonstrict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local npcFolder = Workspace:WaitForChild("BrainrotNPCs")

local FONT = Enum.Font.FredokaOne

local NORMAL_SHOW_DISTANCE = 12
local HIDING_SHOW_DISTANCE = 7

local RARITY_COLORS = {
	Common = Color3.fromRGB(255, 255, 255),
	Rare = Color3.fromRGB(85, 180, 255),
	Epic = Color3.fromRGB(205, 85, 255),
	Mythic = Color3.fromRGB(255, 70, 170),
	Legendary = Color3.fromRGB(255, 215, 45),
	Divine = Color3.fromRGB(80, 245, 255),
	Celestial = Color3.fromRGB(170, 130, 255),
	Godly = Color3.fromRGB(255, 80, 80),
}

local function formatMPS(n)
	n = math.floor(tonumber(n) or 0)

	if n >= 1_000_000_000 then
		return string.format("$%.1fB/s", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return string.format("$%.1fM/s", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("$%.1fK/s", n / 1_000)
	end

	return "$" .. tostring(n) .. "/s"
end

local function getRoot(npc)
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

local function getPlayerRoot()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function hideRobloxHumanoidName(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	pcall(function()
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end)
end

local function addStroke(label, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 1
	stroke.Transparency = 0
	stroke.Parent = label
	return stroke
end

local function makeText(parent, name, text, y, h, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 0, 0, y)
	label.Size = UDim2.new(1, 0, 0, h)
	label.Text = text
	label.Font = FONT
	label.TextSize = textSize
	label.TextScaled = false
	label.TextWrapped = true
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 5
	label.Parent = parent

	addStroke(label, Color3.fromRGB(0, 0, 0), math.max(1, textSize / 8))

	return label
end

local function hasLineOfSight(npc, root)
	local playerRoot = getPlayerRoot()
	local character = player.Character

	if not playerRoot or not character then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		character,
		npc,
	}

	local direction = root.Position - playerRoot.Position
	local result = Workspace:Raycast(playerRoot.Position, direction, params)

	return result == nil
end

local function captureGuiOwnsNpc(npc)
	return npc:GetAttribute("ClientCaptureGuiActive") == true
		or npc:GetAttribute("CaptureChaseActive") == true
		or npc:GetAttribute("CaptureStunned") == true
		or npc:GetAttribute("CapturePanic") == true
		or npc:GetAttribute("CaptureShielded") == true
end

local function shouldShow(npc, root)
	if captureGuiOwnsNpc(npc) then
		return false
	end

	local playerRoot = getPlayerRoot()
	if not playerRoot then
		return false
	end

	local distance = (playerRoot.Position - root.Position).Magnitude

	local isPlaced = npc:GetAttribute("IsPlaced") == true
	local isHiding = npc:GetAttribute("IsHiding") == true

	local heldBy = npc:GetAttribute("HeldBy")
	local isHeld = heldBy ~= nil and heldBy ~= 0 and heldBy ~= ""

	if isPlaced or isHeld then
		return false
	end

	if isHiding then
		return distance <= HIDING_SHOW_DISTANCE
	end

	if distance > NORMAL_SHOW_DISTANCE then
		return false
	end

	if distance <= 7 then
		return true
	end

	return hasLineOfSight(npc, root)
end

local function updateTexts(npc, gui)
	local rarity = tostring(npc:GetAttribute("Rarity") or "Common")
	local rarityColor = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	local mps = tonumber(npc:GetAttribute("MPS")) or 0

	local amount = gui:FindFirstChild("Amount", true)
	local npcName = gui:FindFirstChild("NpcName", true)
	local rarityLabel = gui:FindFirstChild("Rarity", true)

	if amount and amount:IsA("TextLabel") then
		amount.Text = formatMPS(mps)
	end

	if npcName and npcName:IsA("TextLabel") then
		npcName.Text = npc.Name
	end

	if rarityLabel and rarityLabel:IsA("TextLabel") then
		rarityLabel.Text = rarity
		rarityLabel.TextColor3 = rarityColor
	end
end

local function buildOverhead(npc)
	if not npc:IsA("Model") then
		return
	end
	if npc:GetAttribute("EggBrainrot") == true then
		return
	end

	local root = getRoot(npc)
	if not root then
		return
	end

	hideRobloxHumanoidName(npc)

	local old = root:FindFirstChild("NPCOverheadGui")
	if old then
		old:Destroy()
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "NPCOverheadGui"
	bb.Size = UDim2.new(0, 160, 0, 68)
	bb.StudsOffset = Vector3.new(0, 4.25, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 18
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Enabled = false
	bb.Adornee = root
	bb.Parent = root

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = bb

	makeText(holder, "Amount", "$0/s", 0, 22, 15, Color3.fromRGB(105, 255, 85))
	makeText(holder, "NpcName", npc.Name, 22, 24, 16, Color3.fromRGB(255, 255, 255))
	makeText(holder, "Rarity", "Common", 46, 19, 13, Color3.fromRGB(255, 255, 255))

	task.spawn(function()
		while npc.Parent and bb.Parent do
			local currentRoot = getRoot(npc)

			if currentRoot then
				hideRobloxHumanoidName(npc)
				bb.Enabled = shouldShow(npc, currentRoot)
				updateTexts(npc, bb)
			else
				bb.Enabled = false
			end

			task.wait(0.05)
		end
	end)
end

local function bindNpc(npc)
	if not npc:IsA("Model") then
		return
	end
	if npc:GetAttribute("EggBrainrot") == true then
		return
	end

	task.spawn(function()
		local root = npc:WaitForChild("HumanoidRootPart", 8)

		if root and npc.Parent then
			buildOverhead(npc)
		end
	end)
end

for _, npc in ipairs(npcFolder:GetChildren()) do
	bindNpc(npc)
end

npcFolder.ChildAdded:Connect(function(npc)
	task.wait(0.2)
	bindNpc(npc)
end)

print("[NPCOverheadGui] loaded capture-safe version")
