-- StarterPlayerScripts/CaptureNetClient.client.lua
-- Full replacement
-- Sends Capture Net hits to the server.
-- Old hit HP billboard removed.
-- If player hits a stunned NPC, shows ALREADY STUNNED.

--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local npcFolder = workspace:WaitForChild("BrainrotNPCs")

local requestRemote = ReplicatedStorage:WaitForChild("CaptureNPCRequest")
local feedbackRemote = ReplicatedStorage:WaitForChild("CaptureHitFeedback")
local updateRemote = ReplicatedStorage:WaitForChild("UpdateCaptureStats")

local FONT = Enum.Font.FredokaOne

local currentCatchPower = 5
local currentCatchRange = 18
local localCooldown = false

local gui = playerGui:FindFirstChild("CaptureNetFeedbackGui")
if gui then
	gui:Destroy()
end

gui = Instance.new("ScreenGui")
gui.Name = "CaptureNetFeedbackGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 300
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function addStroke(label, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(0, 0, 0)
	stroke.Thickness = thickness or 2
	stroke.Parent = label
	return stroke
end

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

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

local function isTargetableNpc(npc)
	if not npc:IsA("Model") then
		return false
	end

	if npc:GetAttribute("IsPlaced") == true then
		return false
	end

	local heldBy = npc:GetAttribute("HeldBy")
	if heldBy ~= nil and heldBy ~= 0 and heldBy ~= "" then
		return false
	end

	return true
end

local function getNearestNpc()
	local root = getCharacterRoot()
	if not root then
		return nil
	end

	local bestNpc = nil
	local bestDistance = currentCatchRange

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model") and isTargetableNpc(npc) then
			local npcRoot = getNpcRoot(npc)

			if npcRoot then
				local distance = (root.Position - npcRoot.Position).Magnitude

				if distance <= bestDistance then
					bestDistance = distance
					bestNpc = npc
				end
			end
		end
	end

	return bestNpc
end

local function playSwingSound()
	local sound = Instance.new("Sound")
	sound.Name = "CaptureNetSwing"
	sound.SoundId = "rbxassetid://9118828563"
	sound.Volume = 0.18
	sound.PlaybackSpeed = 1.35
	sound.Parent = SoundService
	sound:Play()

	Debris:AddItem(sound, 2)
end

local function animateTool(tool)
	if not tool or not tool:IsA("Tool") then
		return
	end

	local originalGrip = tool.Grip

	local swingGrip =
		originalGrip
		* CFrame.new(0, -0.1, -0.35)
		* CFrame.Angles(math.rad(-45), math.rad(0), math.rad(18))

	local swing = TweenService:Create(
		tool,
		TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Grip = swingGrip,
		}
	)

	local back = TweenService:Create(
		tool,
		TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Grip = originalGrip,
		}
	)

	swing:Play()

	swing.Completed:Connect(function()
		if tool.Parent then
			back:Play()
		end
	end)
end

local function showBillboardText(adorneePart, textValue, color, yOffset)
	if not adorneePart then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CaptureFloatingText"
	billboard.Size = UDim2.new(0, 230, 0, 60)
	billboard.StudsOffset = Vector3.new(0, yOffset or 4.8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.LightInfluence = 0
	billboard.Adornee = adorneePart
	billboard.Parent = adorneePart

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = FONT
	label.Text = textValue
	label.TextColor3 = color
	label.TextSize = 30
	label.ZIndex = 10
	label.Parent = billboard

	addStroke(label, Color3.fromRGB(0, 0, 0), 5)

	TweenService:Create(
		billboard,
		TweenInfo.new(0.52, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			StudsOffset = Vector3.new(0, (yOffset or 4.8) + 1.35, 0),
		}
	):Play()

	task.delay(0.3, function()
		if not billboard.Parent then
			return
		end

		TweenService:Create(label, TweenInfo.new(0.25), {
			TextTransparency = 1,
		}):Play()

		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.25), {
				Transparency = 1,
			}):Play()
		end
	end)

	Debris:AddItem(billboard, 0.75)
end

local function showMissText()
	local root = getCharacterRoot()
	if not root then
		return
	end

	showBillboardText(root, "TOO FAR!", Color3.fromRGB(255, 90, 90), 4.3)
end

local function showAlreadyStunned(npc)
	local root = getNpcRoot(npc)
	if not root then
		return
	end

	showBillboardText(root, "ALREADY STUNNED!", Color3.fromRGB(120, 255, 70), 5.2)
end

local function createDamageBillboard(npc, damage, color, stunned)
	local root = getNpcRoot(npc)
	if not root then
		return
	end

	local textValue
	if stunned then
		textValue = "STUNNED!"
	else
		textValue = "-" .. tostring(damage)
	end

	local textColor
	if stunned then
		textColor = Color3.fromRGB(120, 255, 60)
	else
		textColor = color
	end

	showBillboardText(root, textValue, textColor, 4.75)
end

local function createHitEffect(npc, color)
	local root = getNpcRoot(npc)
	if not root then
		return
	end

	local burst = Instance.new("Part")
	burst.Name = "CaptureHitBurst"
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(1, 1, 1)
	burst.Material = Enum.Material.Neon
	burst.Color = color
	burst.Transparency = 0.25
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanTouch = false
	burst.CanQuery = false
	burst.CFrame = root.CFrame
	burst.Parent = workspace

	TweenService:Create(
		burst,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(5, 5, 5),
			Transparency = 1,
		}
	):Play()

	Debris:AddItem(burst, 0.3)
end

local function bindTool(tool)
	if not tool:IsA("Tool") then
		return
	end

	if tool.Name ~= "Capture Net" then
		return
	end

	if tool:GetAttribute("CaptureNetClientBound") == true then
		return
	end

	tool:SetAttribute("CaptureNetClientBound", true)

	tool.Activated:Connect(function()
		if localCooldown then
			return
		end

		localCooldown = true

		animateTool(tool)
		playSwingSound()

		local npc = getNearestNpc()

		if npc then
			if npc:GetAttribute("CaptureStunned") == true then
				showAlreadyStunned(npc)
			else
				requestRemote:FireServer(npc)
			end
		else
			showMissText()
		end

		task.delay(0.18, function()
			localCooldown = false
		end)
	end)

	print("[CaptureNetClient] Bound:", tool.Name)
end

local function scanContainer(container)
	for _, child in ipairs(container:GetChildren()) do
		bindTool(child)
	end

	container.ChildAdded:Connect(function(child)
		task.wait()
		bindTool(child)
	end)
end

feedbackRemote.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	local npc = data.npc
	if typeof(npc) ~= "Instance" or not npc:IsA("Model") then
		return
	end

	local damage = tonumber(data.damage) or 0
	local color = data.color or Color3.fromRGB(120, 255, 255)
	local stunned = data.stunned == true

	createDamageBillboard(npc, damage, color, stunned)
	createHitEffect(npc, color)
end)

updateRemote.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	currentCatchPower = tonumber(data.catchPower) or currentCatchPower
	currentCatchRange = tonumber(data.catchRange) or currentCatchRange
end)

local backpack = player:WaitForChild("Backpack")
scanContainer(backpack)

if player.Character then
	scanContainer(player.Character)
end

player.CharacterAdded:Connect(function(character)
	task.wait(0.25)
	scanContainer(character)
end)

print("[CaptureNetClient] loaded with already-stunned feedback")