--!nonstrict
-- StarterPlayerScripts/CleanPrompt.client.lua
-- Clean cartoony custom prompt for plot stands.
-- No Roblox default prompt background.
-- Small E key, simple text, tween pop/hold animation.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TARGET_PROMPT_NAMES = {
	["BrainrotCoreStandPrompt"] = true,
}

local activePrompts = {}

local function shouldStylePrompt(prompt)
	if TARGET_PROMPT_NAMES[prompt.Name] then
		return true
	end

	local action = string.lower(tostring(prompt.ActionText or ""))
	local object = string.lower(tostring(prompt.ObjectText or ""))

	return string.find(action, "pickup")
		or string.find(action, "place")
		or string.find(action, "return")
		or string.find(object, "brainrot")
end

local function makePromptCustom(prompt)
	if shouldStylePrompt(prompt) then
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.ObjectText = ""
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 10)
	end
end

local function getAdornee(prompt)
	local parent = prompt.Parent

	if parent and parent:IsA("BasePart") then
		return parent
	end

	if parent and parent:IsA("Attachment") and parent.Parent and parent.Parent:IsA("BasePart") then
		return parent.Parent
	end

	return nil
end

local function makeActionText(prompt)
	local action = tostring(prompt.ActionText or "")

	if action == "" then
		return "Pickup"
	end

	action = action:gsub("Return Brainrot", "Pickup")
	action = action:gsub("Place Brainrot", "Place")

	return action
end

local function createGui(prompt)
	local adornee = getAdornee(prompt)
	if not adornee then
		return nil
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CleanCartoonPrompt"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(170, 56)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	billboard.MaxDistance = prompt.MaxActivationDistance + 8
	billboard.Parent = playerGui

	local rootScale = Instance.new("UIScale")
	rootScale.Name = "RootScale"
	rootScale.Scale = 0.65
	rootScale.Parent = billboard

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = billboard

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.BackgroundTransparency = 1
	key.Position = UDim2.fromOffset(8, 4)
	key.Size = UDim2.fromOffset(48, 48)
	key.Font = Enum.Font.FredokaOne
	key.Text = prompt.KeyboardKeyCode.Name
	key.TextScaled = true
	key.TextColor3 = Color3.fromRGB(255, 255, 255)
	key.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	key.TextStrokeTransparency = 0
	key.Parent = holder

	local keyScale = Instance.new("UIScale")
	keyScale.Name = "KeyScale"
	keyScale.Scale = 1
	keyScale.Parent = key

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.BackgroundTransparency = 1
	action.Position = UDim2.fromOffset(58, 9)
	action.Size = UDim2.fromOffset(104, 38)
	action.Font = Enum.Font.FredokaOne
	action.Text = makeActionText(prompt)
	action.TextScaled = true
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextColor3 = Color3.fromRGB(255, 255, 255)
	action.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	action.TextStrokeTransparency = 0.05
	action.Parent = holder

	local progress = Instance.new("Frame")
	progress.Name = "HoldProgress"
	progress.AnchorPoint = Vector2.new(0.5, 1)
	progress.Position = UDim2.new(0, 32, 1, -1)
	progress.Size = UDim2.fromOffset(0, 4)
	progress.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progress.BorderSizePixel = 0
	progress.Parent = holder

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(1, 0)
	progressCorner.Parent = progress

	local progressStroke = Instance.new("UIStroke")
	progressStroke.Thickness = 2
	progressStroke.Color = Color3.fromRGB(0, 0, 0)
	progressStroke.Transparency = 0.15
	progressStroke.Parent = progress

	TweenService:Create(
		rootScale,
		TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	return {
		gui = billboard,
		rootScale = rootScale,
		keyScale = keyScale,
		key = key,
		action = action,
		progress = progress,
		holdTween = nil,
	}
end

local function destroyPromptUi(prompt)
	local data = activePrompts[prompt]
	if not data then
		return
	end

	activePrompts[prompt] = nil

	if data.holdTween then
		data.holdTween:Cancel()
	end

	if data.gui and data.gui.Parent then
		local scale = data.rootScale

		local tween = TweenService:Create(
			scale,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.65 }
		)

		tween:Play()

		tween.Completed:Connect(function()
			if data.gui then
				data.gui:Destroy()
			end
		end)
	end
end

local function showPrompt(prompt)
	makePromptCustom(prompt)

	if activePrompts[prompt] then
		return
	end

	local data = createGui(prompt)
	if not data then
		return
	end

	activePrompts[prompt] = data
end

local function beginHold(prompt)
	local data = activePrompts[prompt]
	if not data then
		return
	end

	if data.holdTween then
		data.holdTween:Cancel()
	end

	data.progress.Size = UDim2.fromOffset(0, 4)

	TweenService:Create(
		data.keyScale,
		TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.18 }
	):Play()

	data.holdTween = TweenService:Create(
		data.progress,
		TweenInfo.new(math.max(prompt.HoldDuration, 0.08), Enum.EasingStyle.Linear),
		{ Size = UDim2.fromOffset(48, 4) }
	)

	data.holdTween:Play()
end

local function endHold(prompt)
	local data = activePrompts[prompt]
	if not data then
		return
	end

	if data.holdTween then
		data.holdTween:Cancel()
	end

	TweenService:Create(
		data.keyScale,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	TweenService:Create(
		data.progress,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(0, 4) }
	):Play()
end

local function triggered(prompt)
	local data = activePrompts[prompt]
	if not data then
		return
	end

	if data.holdTween then
		data.holdTween:Cancel()
	end

	data.progress.Size = UDim2.fromOffset(0, 4)

	TweenService:Create(
		data.keyScale,
		TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.35 }
	):Play()

	task.delay(0.08, function()
		if data.keyScale and data.keyScale.Parent then
			TweenService:Create(
				data.keyScale,
				TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end)
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	if shouldStylePrompt(prompt) then
		showPrompt(prompt)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	destroyPromptUi(prompt)
end)

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	if shouldStylePrompt(prompt) then
		beginHold(prompt)
	end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if shouldStylePrompt(prompt) then
		endHold(prompt)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if shouldStylePrompt(prompt) then
		triggered(prompt)
	end
end)

task.spawn(function()
	while true do
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("ProximityPrompt") then
				makePromptCustom(obj)
			end
		end

		task.wait(0.5)
	end
end)

print("[CleanPrompt] Loaded clean cartoony custom Hold E prompt.")