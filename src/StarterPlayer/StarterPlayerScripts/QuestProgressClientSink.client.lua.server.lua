--!nonstrict
-- StarterPlayerScripts/QuestProgressClientSink.client.lua
-- Simulator-style quest tracker for the core brainrot collection loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne

local updateQuestRemote = ReplicatedStorage:WaitForChild("UpdateQuestProgress", 20)
local claimQuestRemote = ReplicatedStorage:WaitForChild("ClaimQuestReward", 20)

if not updateQuestRemote or not updateQuestRemote:IsA("RemoteEvent") then
	warn("[QuestProgressClientSink] UpdateQuestProgress remote not found.")
	return
end

if not claimQuestRemote or not claimQuestRemote:IsA("RemoteEvent") then
	warn("[QuestProgressClientSink] ClaimQuestReward remote not found.")
	return
end

local old = playerGui:FindFirstChild("StarterQuestTrackerGui")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "StarterQuestTrackerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 105
gui.Parent = playerGui

local scale = Instance.new("UIScale")
scale.Scale = 1
scale.Parent = gui

local root = Instance.new("Frame")
root.Name = "QuestCard"
root.AnchorPoint = Vector2.new(1, 0)
root.Position = UDim2.new(1, -18, 0, 88)
root.Size = UDim2.fromOffset(316, 126)
root.BackgroundColor3 = Color3.fromRGB(255, 216, 74)
root.BorderSizePixel = 0
root.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 18)
corner.Parent = root

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(27, 29, 50)
stroke.Thickness = 3
stroke.Parent = root

local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 234, 107)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 145, 49)),
})
gradient.Parent = root

local shine = Instance.new("Frame")
shine.Name = "Shine"
shine.Position = UDim2.new(0, 10, 0, 8)
shine.Size = UDim2.new(1, -20, 0, 24)
shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
shine.BackgroundTransparency = 0.78
shine.BorderSizePixel = 0
shine.Parent = root

local shineCorner = Instance.new("UICorner")
shineCorner.CornerRadius = UDim.new(0, 14)
shineCorner.Parent = shine

local function addTextStroke(label, thickness)
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(20, 22, 38)
	textStroke.Thickness = thickness or 2
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Parent = label
	return textStroke
end

local function makeLabel(name, text, position, size, maxSize, color, align)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = FONT
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = root
	addTextStroke(label, 2)

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.MinTextSize = 9
	constraint.Parent = label

	return label
end

makeLabel(
	"Eyebrow",
	"NEXT GOAL",
	UDim2.fromOffset(16, 7),
	UDim2.fromOffset(116, 22),
	14,
	Color3.fromRGB(255, 255, 255)
)

local title = makeLabel(
	"Title",
	"Build Your Squad",
	UDim2.fromOffset(16, 27),
	UDim2.fromOffset(198, 30),
	22,
	Color3.fromRGB(255, 255, 255)
)

local action = makeLabel(
	"Action",
	"Collect Brainrots",
	UDim2.fromOffset(16, 58),
	UDim2.fromOffset(190, 24),
	16,
	Color3.fromRGB(255, 252, 220)
)

local reward = makeLabel(
	"Reward",
	"+500 Coins",
	UDim2.fromOffset(212, 18),
	UDim2.fromOffset(86, 42),
	18,
	Color3.fromRGB(255, 255, 255),
	Enum.TextXAlignment.Center
)

local progressBack = Instance.new("Frame")
progressBack.Name = "ProgressBack"
progressBack.Position = UDim2.fromOffset(16, 88)
progressBack.Size = UDim2.fromOffset(184, 18)
progressBack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
progressBack.BackgroundTransparency = 0.2
progressBack.BorderSizePixel = 0
progressBack.Parent = root

local progressBackCorner = Instance.new("UICorner")
progressBackCorner.CornerRadius = UDim.new(1, 0)
progressBackCorner.Parent = progressBack

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Color3.fromRGB(74, 244, 88)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBack

local progressFillCorner = Instance.new("UICorner")
progressFillCorner.CornerRadius = UDim.new(1, 0)
progressFillCorner.Parent = progressFill

local progressText = Instance.new("TextLabel")
progressText.Name = "ProgressText"
progressText.BackgroundTransparency = 1
progressText.Size = UDim2.fromScale(1, 1)
progressText.Text = "0/3"
progressText.TextColor3 = Color3.fromRGB(31, 36, 54)
progressText.TextScaled = true
progressText.Font = FONT
progressText.Parent = progressBack

local progressTextConstraint = Instance.new("UITextSizeConstraint")
progressTextConstraint.MaxTextSize = 13
progressTextConstraint.MinTextSize = 8
progressTextConstraint.Parent = progressText

local claimButton = Instance.new("TextButton")
claimButton.Name = "ClaimButton"
claimButton.Position = UDim2.fromOffset(212, 78)
claimButton.Size = UDim2.fromOffset(86, 34)
claimButton.BackgroundColor3 = Color3.fromRGB(80, 185, 255)
claimButton.BorderSizePixel = 0
claimButton.AutoButtonColor = false
claimButton.Text = "GO"
claimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
claimButton.TextScaled = true
claimButton.Font = FONT
claimButton.Parent = root
addTextStroke(claimButton, 2)

local claimCorner = Instance.new("UICorner")
claimCorner.CornerRadius = UDim.new(0, 13)
claimCorner.Parent = claimButton

local claimStroke = Instance.new("UIStroke")
claimStroke.Color = Color3.fromRGB(28, 74, 140)
claimStroke.Thickness = 2
claimStroke.Parent = claimButton

local claimConstraint = Instance.new("UITextSizeConstraint")
claimConstraint.MaxTextSize = 17
claimConstraint.MinTextSize = 9
claimConstraint.Parent = claimButton

local latestPayload = nil
local claimReady = false
local burstRunning = false

local function formatNumber(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(math.floor(value))
end

local function setClaimReady(ready)
	claimReady = ready
	claimButton.Text = ready and "CLAIM" or "GO"
	claimButton.BackgroundColor3 = ready and Color3.fromRGB(89, 239, 93) or Color3.fromRGB(80, 185, 255)
	claimStroke.Color = ready and Color3.fromRGB(26, 93, 39) or Color3.fromRGB(28, 74, 140)
end

local function pop()
	scale.Scale = 1.04
	TweenService:Create(
		scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

local function makeBurstLabel(parent, name, text, position, size, color, maxSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = FONT
	label.ZIndex = 210
	label.Parent = parent
	addTextStroke(label, 3)

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.MinTextSize = 12
	constraint.Parent = label

	return label
end

local function showRewardBurst(payload)
	if burstRunning or type(payload) ~= "table" then
		return
	end

	burstRunning = true

	local amountText = "+" .. formatNumber(payload.rewardAmount)
	local rewardType = tostring(payload.rewardType or "Coins")

	local burstGui = Instance.new("Frame")
	burstGui.Name = "QuestRewardBurst"
	burstGui.AnchorPoint = Vector2.new(0.5, 0.5)
	burstGui.Position = UDim2.fromScale(0.5, 0.42)
	burstGui.Size = UDim2.fromOffset(390, 178)
	burstGui.BackgroundTransparency = 1
	burstGui.ZIndex = 200
	burstGui.Parent = gui

	local burstScale = Instance.new("UIScale")
	burstScale.Scale = 0.58
	burstScale.Parent = burstGui

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.52)
	glow.Size = UDim2.fromOffset(270, 120)
	glow.BackgroundColor3 = Color3.fromRGB(255, 232, 96)
	glow.BackgroundTransparency = 0.34
	glow.BorderSizePixel = 0
	glow.ZIndex = 201
	glow.Parent = burstGui

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	local headline = makeBurstLabel(
		burstGui,
		"Headline",
		"QUEST COMPLETE!",
		UDim2.fromScale(0.5, 0.24),
		UDim2.fromOffset(340, 44),
		Color3.fromRGB(255, 255, 255),
		32
	)

	local amount = makeBurstLabel(
		burstGui,
		"Amount",
		amountText .. " " .. string.upper(rewardType),
		UDim2.fromScale(0.5, 0.58),
		UDim2.fromOffset(360, 66),
		rewardType == "Gems" and Color3.fromRGB(95, 235, 255) or Color3.fromRGB(255, 239, 91),
		42
	)

	for i = 1, 14 do
		local dot = Instance.new("TextLabel")
		dot.Name = "RewardSpark"
		dot.BackgroundTransparency = 1
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.55)
		dot.Size = UDim2.fromOffset(30, 30)
		dot.Text = rewardType == "Gems" and "◆" or "$"
		dot.TextColor3 = rewardType == "Gems" and Color3.fromRGB(124, 241, 255) or Color3.fromRGB(255, 232, 89)
		dot.TextScaled = true
		dot.Font = FONT
		dot.ZIndex = 209
		dot.Parent = burstGui
		addTextStroke(dot, 2)

		local angle = (math.pi * 2 * i) / 14
		local distance = 80 + ((i % 4) * 15)
		local target = UDim2.new(0.5, math.cos(angle) * distance, 0.55, math.sin(angle) * distance)

		TweenService:Create(
			dot,
			TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = target, Rotation = (i % 2 == 0 and 35 or -35) }
		):Play()

		task.delay(0.45, function()
			if dot.Parent then
				TweenService:Create(
					dot,
					TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ TextTransparency = 1 }
				):Play()
			end
		end)
	end

	TweenService:Create(
		burstScale,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	TweenService:Create(
		glow,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(360, 150), BackgroundTransparency = 0.58 }
	):Play()

	task.delay(0.85, function()
		if not burstGui.Parent then
			burstRunning = false
			return
		end

		TweenService:Create(
			burstScale,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.72 }
		):Play()

		for _, obj in ipairs(burstGui:GetDescendants()) do
			if obj:IsA("TextLabel") then
				TweenService:Create(
					obj,
					TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ TextTransparency = 1 }
				):Play()
			elseif obj:IsA("Frame") then
				TweenService:Create(
					obj,
					TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ BackgroundTransparency = 1 }
				):Play()
			end
		end

		task.delay(0.18, function()
			if burstGui then
				burstGui:Destroy()
			end
			burstRunning = false
		end)
	end)
end

local function applyQuest(payload)
	if type(payload) ~= "table" then
		return
	end

	latestPayload = payload
	local goal = math.max(tonumber(payload.goal) or 1, 1)
	local progress = math.clamp(tonumber(payload.progress) or 0, 0, goal)
	local ratio = progress / goal
	local complete = payload.complete == true

	title.Text = tostring(payload.title or "Next Goal")
	action.Text = tostring(payload.action or ("Collect " .. tostring(goal) .. " Brainrots"))
	reward.Text = "+" .. formatNumber(payload.rewardAmount) .. "\n" .. tostring(payload.rewardType or "Coins")
	progressText.Text = tostring(math.floor(progress)) .. "/" .. tostring(math.floor(goal))
	setClaimReady(complete)

	TweenService:Create(
		progressFill,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(ratio, 1) }
	):Play()

	pop()
end

claimButton.MouseEnter:Connect(function()
	TweenService:Create(claimButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(90, 36) }):Play()
end)

claimButton.MouseLeave:Connect(function()
	TweenService:Create(claimButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(86, 34) }):Play()
end)

claimButton.MouseButton1Click:Connect(function()
	if claimReady then
		showRewardBurst(latestPayload)
		claimQuestRemote:FireServer()
		setClaimReady(false)
		pop()
	end
end)

updateQuestRemote.OnClientEvent:Connect(applyQuest)

task.delay(1, function()
	if not latestPayload then
		applyQuest({
			title = "Build Your Squad",
			action = "Collect 3 Brainrots",
			goal = 3,
			progress = 0,
			complete = false,
			rewardType = "Coins",
			rewardAmount = 500,
		})
	end
end)

print("[QuestProgressClientSink] Loaded simulator quest tracker.")
