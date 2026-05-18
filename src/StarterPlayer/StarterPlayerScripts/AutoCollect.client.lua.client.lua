--!nonstrict
-- AutoCollect.client.lua
-- Put in: StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local autoCollectRemote = ReplicatedStorage:WaitForChild("AutoCollectMoney", 30)

if not autoCollectRemote then
	warn("[AutoCollect] AutoCollectMoney remote was not found after 30 seconds")
	return
end

local autoCollectEnabled = false
local loopRunning = false

local COLLECT_DELAY = 1.05

local ON_TOP = Color3.fromRGB(105, 255, 45)
local ON_BOTTOM = Color3.fromRGB(35, 170, 22)

local OFF_TOP = Color3.fromRGB(190, 90, 255)
local OFF_BOTTOM = Color3.fromRGB(90, 35, 205)

local function setGradient(button, top, bottom)
	button.BackgroundColor3 = top

	local gradient = button:FindFirstChildOfClass("UIGradient")

	if gradient then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, top),
			ColorSequenceKeypoint.new(1, bottom),
		})
	end
end

local function getAutoCollectButton()
	local hud = playerGui:FindFirstChild("CartoonSimulatorHUD")
	if not hud then
		return nil
	end

	local main = hud:FindFirstChild("Main")
	if not main then
		return nil
	end

	local bottomTrain = main:FindFirstChild("BottomTrain")
	if not bottomTrain then
		return nil
	end

	local autoCollect = bottomTrain:FindFirstChild("AutoCollect")

	if autoCollect and autoCollect:IsA("TextButton") then
		return autoCollect
	end

	return nil
end

local function getLabel(button)
	local label = button:FindFirstChild("Label")

	if label and label:IsA("TextLabel") then
		return label
	end

	return nil
end

local function updateButtonVisual()
	local button = getAutoCollectButton()

	if not button then
		return
	end

	local label = getLabel(button)

	if autoCollectEnabled then
		setGradient(button, ON_TOP, ON_BOTTOM)

		if label then
			label.Text = "AUTO\nCOLLECT\nON"
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	else
		setGradient(button, OFF_TOP, OFF_BOTTOM)

		if label then
			label.Text = "AUTO\nCOLLECT\nOFF"
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end

local function popButton()
	local button = getAutoCollectButton()

	if not button then
		return
	end

	local originalSize = button.Size

	local grow = TweenService:Create(
		button,
		TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(
				originalSize.X.Scale,
				originalSize.X.Offset + 10,
				originalSize.Y.Scale,
				originalSize.Y.Offset + 6
			),
			Rotation = if autoCollectEnabled then -2 else 2,
		}
	)

	local shrink = TweenService:Create(
		button,
		TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = originalSize,
			Rotation = 0,
		}
	)

	grow:Play()

	grow.Completed:Connect(function()
		if button.Parent then
			shrink:Play()
		end
	end)
end

local function startAutoCollectLoop()
	if loopRunning then
		return
	end

	loopRunning = true

	task.spawn(function()
		while autoCollectEnabled do
			autoCollectRemote:FireServer()
			task.wait(COLLECT_DELAY)
		end

		loopRunning = false
	end)
end

local function toggleAutoCollect()
	autoCollectEnabled = not autoCollectEnabled

	updateButtonVisual()
	popButton()

	print("[AutoCollect] toggled:", autoCollectEnabled)

	if autoCollectEnabled then
		autoCollectRemote:FireServer()
		startAutoCollectLoop()
	end
end

local function bindButton()
	local button = getAutoCollectButton()

	if not button then
		return
	end

	if button:GetAttribute("RealAutoCollectBound") == true then
		updateButtonVisual()
		return
	end

	button:SetAttribute("RealAutoCollectBound", true)

	local blocker = Instance.new("TextButton")
	blocker.Name = "AutoCollectClickLayer"
	blocker.Text = ""
	blocker.BackgroundTransparency = 1
	blocker.BorderSizePixel = 0
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.Position = UDim2.fromScale(0, 0)
	blocker.ZIndex = 999
	blocker.AutoButtonColor = false
	blocker.Parent = button

	blocker.Activated:Connect(function()
		toggleAutoCollect()
	end)

	updateButtonVisual()
end

player.CharacterAdded:Connect(function()
	if autoCollectEnabled then
		task.wait(0.5)
		autoCollectRemote:FireServer()
		startAutoCollectLoop()
	end
end)

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "CartoonSimulatorHUD" then
		task.wait(0.3)
		bindButton()
	end
end)

task.spawn(function()
	while true do
		bindButton()
		task.wait(0.5)
	end
end)

print("[AutoCollect] client loaded v3")