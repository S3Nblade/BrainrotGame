--!nonstrict
-- StarterPlayerScripts/QuestProgressClientSink.client.lua
-- Simulator-style quest tracker for the core brainrot collection loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
root.Size = UDim2.fromOffset(316, 252)
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

local dailyPanel = Instance.new("Frame")
dailyPanel.Name = "DailyQuestPanel"
dailyPanel.Position = UDim2.fromOffset(12, 124)
dailyPanel.Size = UDim2.new(1, -24, 0, 116)
dailyPanel.BackgroundColor3 = Color3.fromRGB(255, 250, 214)
dailyPanel.BackgroundTransparency = 0.08
dailyPanel.BorderSizePixel = 0
dailyPanel.Parent = root

local dailyCorner = Instance.new("UICorner")
dailyCorner.CornerRadius = UDim.new(0, 14)
dailyCorner.Parent = dailyPanel

local dailyStroke = Instance.new("UIStroke")
dailyStroke.Color = Color3.fromRGB(117, 74, 31)
dailyStroke.Thickness = 2
dailyStroke.Transparency = 0.08
dailyStroke.Parent = dailyPanel

local dailyHeader = Instance.new("TextLabel")
dailyHeader.Name = "DailyHeader"
dailyHeader.BackgroundTransparency = 1
dailyHeader.Position = UDim2.fromOffset(10, 3)
dailyHeader.Size = UDim2.new(1, -20, 0, 20)
dailyHeader.Text = "DAILY QUESTS"
dailyHeader.TextColor3 = Color3.fromRGB(85, 48, 24)
dailyHeader.TextScaled = true
dailyHeader.Font = FONT
dailyHeader.TextXAlignment = Enum.TextXAlignment.Left
dailyHeader.Parent = dailyPanel

local dailyHeaderConstraint = Instance.new("UITextSizeConstraint")
dailyHeaderConstraint.MaxTextSize = 14
dailyHeaderConstraint.MinTextSize = 9
dailyHeaderConstraint.Parent = dailyHeader

local dailyList = Instance.new("Frame")
dailyList.Name = "DailyList"
dailyList.BackgroundTransparency = 1
dailyList.Position = UDim2.fromOffset(8, 27)
dailyList.Size = UDim2.new(1, -16, 0, 82)
dailyList.Parent = dailyPanel

local latestPayload = nil
local claimReady = false
local burstRunning = false
local dailyRowLimit = 3
local renderDailyQuests = nil
local viewportConnection = nil

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
	local targetScale = scale:GetAttribute("TargetScale") or 1
	scale.Scale = targetScale + 0.04
	TweenService:Create(
		scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = targetScale }
	):Play()
end

local function applyResponsiveLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local compact = viewport.X < 760 or viewport.Y < 560
	local tiny = viewport.X < 520 or viewport.Y < 460
	local targetScale = 1

	if tiny then
		targetScale = 0.74
		dailyRowLimit = 1
		root.Position = UDim2.new(1, -8, 0, 64)
	elseif compact then
		targetScale = 0.86
		dailyRowLimit = 2
		root.Position = UDim2.new(1, -10, 0, 72)
	else
		targetScale = 1
		dailyRowLimit = 3
		root.Position = UDim2.new(1, -18, 0, 88)
	end

	scale:SetAttribute("TargetScale", targetScale)
	TweenService:Create(
		scale,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = targetScale }
	):Play()

	if latestPayload then
		renderDailyQuests(latestPayload.dailyQuests)
	end
end

local function clearDailyRows()
	for _, child in ipairs(dailyList:GetChildren()) do
		child:Destroy()
	end
end

local function makeDailyText(parent, name, text, position, size, color, maxSize, align)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = FONT
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.MinTextSize = 8
	constraint.Parent = label

	return label
end

function renderDailyQuests(dailyQuests)
	clearDailyRows()

	if type(dailyQuests) ~= "table" or #dailyQuests <= 0 then
		local empty = makeDailyText(
			dailyList,
			"Empty",
			"Daily quests appear after the server loads.",
			UDim2.fromOffset(6, 18),
			UDim2.new(1, -12, 0, 28),
			Color3.fromRGB(112, 73, 46),
			13
		)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		return
	end

	for index = 1, math.min(dailyRowLimit, #dailyQuests) do
		local data = dailyQuests[index]
		local goal = math.max(tonumber(data.goal) or 1, 1)
		local progress = math.clamp(tonumber(data.progress) or 0, 0, goal)
		local ratio = progress / goal
		local claimed = data.claimed == true
		local complete = data.complete == true

		local row = Instance.new("Frame")
		row.Name = "DailyQuestRow"
		row.Position = UDim2.fromOffset(0, (index - 1) * 27)
		row.Size = UDim2.new(1, 0, 0, 24)
		row.BackgroundColor3 = claimed and Color3.fromRGB(195, 255, 177) or Color3.fromRGB(255, 232, 133)
		row.BackgroundTransparency = 0.04
		row.BorderSizePixel = 0
		row.Parent = dailyList

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 9)
		rowCorner.Parent = row

		local name = makeDailyText(
			row,
			"Name",
			tostring(data.action or data.title or "Daily Quest"),
			UDim2.fromOffset(8, 1),
			UDim2.new(1, -94, 0, 22),
			Color3.fromRGB(69, 43, 28),
			12
		)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextWrapped = false

		local barBack = Instance.new("Frame")
		barBack.Name = "BarBack"
		barBack.Position = UDim2.new(1, -82, 0, 7)
		barBack.Size = UDim2.fromOffset(42, 10)
		barBack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		barBack.BackgroundTransparency = 0.12
		barBack.BorderSizePixel = 0
		barBack.Parent = row

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = barBack

		local barFill = Instance.new("Frame")
		barFill.Name = "BarFill"
		barFill.Size = UDim2.fromScale(ratio, 1)
		barFill.BackgroundColor3 = claimed and Color3.fromRGB(69, 220, 88) or Color3.fromRGB(255, 142, 46)
		barFill.BorderSizePixel = 0
		barFill.Parent = barBack

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = barFill

		local statusText = claimed and "CLAIMED" or (complete and "DONE" or (tostring(math.floor(progress)) .. "/" .. tostring(math.floor(goal))))
		makeDailyText(
			row,
			"Status",
			statusText,
			UDim2.new(1, -38, 1, -21),
			UDim2.fromOffset(34, 18),
			claimed and Color3.fromRGB(32, 123, 46) or Color3.fromRGB(90, 53, 25),
			10,
			Enum.TextXAlignment.Center
		)
	end
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
	renderDailyQuests(payload.dailyQuests)

	TweenService:Create(
		progressFill,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(ratio, 1) }
	):Play()

	pop()
end

local function hookViewport()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
	end

	applyResponsiveLayout()
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
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookViewport)
hookViewport()

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
			dailyQuests = {},
		})
	end
end)

print("[QuestProgressClientSink] Loaded simulator quest tracker.")
