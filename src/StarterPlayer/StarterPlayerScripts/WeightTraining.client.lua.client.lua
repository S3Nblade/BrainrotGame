-- StarterPlayerScripts/WeightTraining.client.lua
-- Full replacement

--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local startRemote = remotesFolder:WaitForChild("StartWeightTraining")
local stopRemote = remotesFolder:WaitForChild("StopWeightTraining")
local meterRemote = remotesFolder:WaitForChild("WeightTrainingMeterHit")
local rewardRemote = remotesFolder:WaitForChild("WeightTrainingReward")
local stateRemote = remotesFolder:WaitForChild("WeightTrainingState")

local guiFolder = ReplicatedStorage:WaitForChild("GUI")
local luckyFolder = guiFolder:WaitForChild("Lucky")

local TRAINING_TOOL_KEYWORDS = {
	"weight",
	"training",
	"dumbbell",
	"barbell",
}

local START_EQUIP_COOLDOWN = 0.28
local METER_MIN_DELAY = 2.2
local METER_MAX_DELAY = 3.35
local MARKER_SPEED = 1.42

local METER_SCREEN_POSITION = UDim2.fromScale(0.27, 0.5)

local BAR_TOP_SCALE = 0.205
local BAR_BOTTOM_SCALE = 0.795
local BAR_X_SCALE = 0.5

local rng = Random.new()

local trainingActive = false
local meterActive = false
local meterAlreadyHit = false
local meterStartedAt = 0
local lastStartRequest = 0
local meterLoopToken = 0
local currentMarkerAlpha = 0

local lastQualityPopupTime = 0
local lastStrengthPopupPosition = UDim2.fromScale(0.36, 0.39)

local markerRenderConnection = nil
local freezeConnection = nil
local controls = nil
local hookedTools = {}

local QUALITY_CONFIG = {
	-- Matched to the lucky bar colors:
	-- bottom red = bad, orange = average, yellow = good, top green = perfect
	{ name = "Bad", minAlpha = 0.00, maxAlpha = 0.23 },
	{ name = "Average", minAlpha = 0.23, maxAlpha = 0.43 },
	{ name = "Good", minAlpha = 0.43, maxAlpha = 0.66 },
	{ name = "Perfect", minAlpha = 0.66, maxAlpha = 1.00 },
}

local QUALITY_TEXT_COLORS = {
	Perfect = Color3.fromRGB(80, 255, 120), -- green
	Good = Color3.fromRGB(255, 225, 65), -- yellow
	Average = Color3.fromRGB(255, 145, 55), -- orange
	Bad = Color3.fromRGB(255, 75, 75), -- red
}

local QUALITY_DISPLAY_TEXT = {
	Perfect = "PERFECT!",
	Good = "GOOD!",
	Average = "AVERAGE",
	Bad = "BAD",
}

local function tween(instance, duration, properties, style, direction)
	local created = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		properties
	)

	created:Play()
	return created
end

local function formatNumber(value)
	value = tonumber(value) or 0

	if value >= 1e30 then
		return string.format("%.1fNO", value / 1e30)
	elseif value >= 1e27 then
		return string.format("%.1fOC", value / 1e27)
	elseif value >= 1e24 then
		return string.format("%.1fSP", value / 1e24)
	elseif value >= 1e21 then
		return string.format("%.1fSX", value / 1e21)
	elseif value >= 1e18 then
		return string.format("%.1fQN", value / 1e18)
	elseif value >= 1e15 then
		return string.format("%.1fQ", value / 1e15)
	elseif value >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end

	return tostring(math.floor(value))
end

local function findChildInsensitive(parent, names)
	for _, wanted in ipairs(names) do
		local direct = parent:FindFirstChild(wanted)
		if direct then
			return direct
		end
	end

	for _, child in ipairs(parent:GetChildren()) do
		local lower = string.lower(child.Name)

		for _, wanted in ipairs(names) do
			if lower == string.lower(wanted) then
				return child
			end
		end
	end

	return nil
end

local function extractImage(asset)
	if not asset then
		return ""
	end

	if asset:IsA("ImageLabel") or asset:IsA("ImageButton") then
		return asset.Image
	elseif asset:IsA("Decal") or asset:IsA("Texture") then
		return asset.Texture
	elseif asset:IsA("StringValue") then
		return asset.Value
	end

	local success, value = pcall(function()
		return asset.Image
	end)

	if success and typeof(value) == "string" then
		return value
	end

	return ""
end

local images = {
	luckyBar = extractImage(findChildInsensitive(luckyFolder, { "luckyBar" })),
	luckyBarMeter = extractImage(findChildInsensitive(luckyFolder, { "luckyBarMeter", "meter", "marker" })),
	strength = extractImage(findChildInsensitive(guiFolder, { "strength", "bolt icon" })),
}

local goodSoundAsset = findChildInsensitive(luckyFolder, { "goodSound" })
local perfectSoundAsset = findChildInsensitive(luckyFolder, { "perfectSound" })

local oldGui = playerGui:FindFirstChild("WeightTrainingGui")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WeightTrainingGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 125
screenGui.Parent = playerGui

local preloadObjects = {}

for _, imageId in pairs(images) do
	if typeof(imageId) == "string" and imageId ~= "" then
		local preload = Instance.new("ImageLabel")
		preload.Size = UDim2.fromOffset(1, 1)
		preload.Position = UDim2.fromOffset(-10000, -10000)
		preload.BackgroundTransparency = 1
		preload.Image = imageId
		preload.Parent = screenGui
		table.insert(preloadObjects, preload)
	end
end

if goodSoundAsset and goodSoundAsset:IsA("Sound") then
	table.insert(preloadObjects, goodSoundAsset)
end

if perfectSoundAsset and perfectSoundAsset:IsA("Sound") then
	table.insert(preloadObjects, perfectSoundAsset)
end

pcall(function()
	ContentProvider:PreloadAsync(preloadObjects)
end)

for _, obj in ipairs(preloadObjects) do
	if obj:IsA("GuiObject") then
		obj:Destroy()
	end
end

local goodSound = nil
local perfectSound = nil

if goodSoundAsset and goodSoundAsset:IsA("Sound") then
	goodSound = goodSoundAsset:Clone()
	goodSound.Name = "LuckyGoodSound"
	goodSound.Volume = 0.45
	goodSound.Parent = screenGui
end

if perfectSoundAsset and perfectSoundAsset:IsA("Sound") then
	perfectSound = perfectSoundAsset:Clone()
	perfectSound.Name = "LuckyPerfectSound"
	perfectSound.Volume = 0.8
	perfectSound.Parent = screenGui
end

local function playSound(soundObject)
	if not soundObject then
		return
	end

	soundObject.TimePosition = 0
	soundObject:Play()
end

local function normalizeQualityName(qualityName)
	qualityName = tostring(qualityName or "")

	if qualityName == "Excellent" then
		return "Perfect"
	elseif qualityName == "Great" then
		return "Good"
	elseif qualityName == "Good" then
		return "Good"
	elseif qualityName == "Average" then
		return "Average"
	elseif qualityName == "Bad" then
		return "Bad"
	elseif qualityName == "Perfect" then
		return "Perfect"
	end

	return "Bad"
end

local function playQualitySound(qualityName)
	qualityName = normalizeQualityName(qualityName)

	if qualityName == "Perfect" then
		playSound(perfectSound)
	elseif qualityName == "Good" or qualityName == "Average" then
		playSound(goodSound)
	end
end

local function getControls()
	if controls then
		return controls
	end

	local playerScripts = player:WaitForChild("PlayerScripts")
	local playerModule = playerScripts:WaitForChild("PlayerModule")

	local success, module = pcall(function()
		return require(playerModule)
	end)

	if success and module and module.GetControls then
		controls = module:GetControls()
	end

	return controls
end

local function getRestoredWalkSpeed()
	local restoredWalkSpeed = player:GetAttribute("WalkSpeed")
	if typeof(restoredWalkSpeed) == "number" and restoredWalkSpeed > 0 then
		return restoredWalkSpeed
	end

	return 16
end

local function enforceLocalFreeze()
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
		humanoid.Sit = false
		humanoid.WalkSpeed = 0
		humanoid.AutoRotate = false
		humanoid.Jump = false

		if humanoid.UseJumpPower then
			humanoid.JumpPower = 0
		else
			humanoid.JumpHeight = 0
		end
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.AssemblyLinearVelocity = Vector3.zero
		rootPart.AssemblyAngularVelocity = Vector3.zero
	end
end

local function hardLocalUnfreeze()
	if freezeConnection then
		freezeConnection:Disconnect()
		freezeConnection = nil
	end

	local currentControls = getControls()
	if currentControls then
		currentControls:Enable()
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true
	humanoid.WalkSpeed = getRestoredWalkSpeed()
	humanoid.Jump = false

	if humanoid.UseJumpPower then
		humanoid.JumpPower = 50
	else
		humanoid.JumpHeight = 7.2
	end
end

local function freezeLocalControls()
	local currentControls = getControls()
	if currentControls then
		currentControls:Disable()
	end

	enforceLocalFreeze()

	if freezeConnection then
		freezeConnection:Disconnect()
	end

	freezeConnection = RunService.RenderStepped:Connect(function()
		if trainingActive then
			enforceLocalFreeze()
		end
	end)
end

local function unfreezeLocalControls()
	trainingActive = false
	hardLocalUnfreeze()

	task.delay(0.12, function()
		if not trainingActive then
			hardLocalUnfreeze()
		end
	end)

	task.delay(0.35, function()
		if not trainingActive then
			hardLocalUnfreeze()
		end
	end)
end

local function isTrainingTool(tool)
	if not tool or not tool:IsA("Tool") then
		return false
	end

	if tool:GetAttribute("TrainingTool") == true then
		return true
	end

	if tool:GetAttribute("ToolType") == "Weight" then
		return true
	end

	if tool:GetAttribute("ItemType") == "Weight" then
		return true
	end

	local lowerName = string.lower(tool.Name)

	for _, keyword in ipairs(TRAINING_TOOL_KEYWORDS) do
		if string.find(lowerName, keyword) then
			return true
		end
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		local lowerDescendantName = string.lower(descendant.Name)

		if string.find(lowerDescendantName, "weight")
			or string.find(lowerDescendantName, "dumbbell")
			or string.find(lowerDescendantName, "barbell") then
			return true
		end
	end

	return false
end

local function getEquippedTrainingTool()
	local character = player.Character
	if not character then
		return nil
	end

	for _, child in ipairs(character:GetChildren()) do
		if isTrainingTool(child) then
			return child
		end
	end

	return nil
end

local meterRoot = Instance.new("Frame")
meterRoot.Name = "MeterRoot"
meterRoot.AnchorPoint = Vector2.new(0.5, 0.5)
meterRoot.Position = METER_SCREEN_POSITION
meterRoot.Size = UDim2.fromOffset(300, 475)
meterRoot.BackgroundTransparency = 1
meterRoot.Visible = false
meterRoot.ZIndex = 160
meterRoot.Parent = screenGui

local meterScale = Instance.new("UIScale")
meterScale.Scale = 0.36
meterScale.Parent = meterRoot

local luckyBarImage = Instance.new("ImageLabel")
luckyBarImage.Name = "LuckyBarImage"
luckyBarImage.AnchorPoint = Vector2.new(0.5, 0.5)
luckyBarImage.Position = UDim2.fromScale(0.5, 0.5)
luckyBarImage.Size = UDim2.fromScale(1, 1)
luckyBarImage.BackgroundTransparency = 1
luckyBarImage.Image = images.luckyBar
luckyBarImage.ScaleType = Enum.ScaleType.Fit
luckyBarImage.ImageTransparency = 1
luckyBarImage.Rotation = 90
luckyBarImage.ZIndex = 161
luckyBarImage.Parent = meterRoot

local markerHolder = Instance.new("Frame")
markerHolder.Name = "MarkerHolder"
markerHolder.AnchorPoint = Vector2.new(0.5, 0.5)
markerHolder.Position = UDim2.fromScale(BAR_X_SCALE, BAR_BOTTOM_SCALE)
markerHolder.Size = UDim2.fromOffset(118, 20)
markerHolder.BackgroundTransparency = 1
markerHolder.Visible = false
markerHolder.ZIndex = 170
markerHolder.Parent = meterRoot

local markerImage = Instance.new("ImageLabel")
markerImage.Name = "MarkerImage"
markerImage.AnchorPoint = Vector2.new(0.5, 0.5)
markerImage.Position = UDim2.fromScale(0.5, 0.5)
markerImage.Size = UDim2.fromScale(1, 1)
markerImage.BackgroundTransparency = 1
markerImage.Image = images.luckyBarMeter
markerImage.ScaleType = Enum.ScaleType.Fit
markerImage.ImageTransparency = 1
markerImage.ZIndex = 171
markerImage.Parent = markerHolder

local qualityGroup = Instance.new("Frame")
qualityGroup.Name = "QualityGroup"
qualityGroup.AnchorPoint = Vector2.new(0.5, 0.5)
qualityGroup.Position = UDim2.fromScale(0.36, 0.31)
qualityGroup.Size = UDim2.fromOffset(430, 170)
qualityGroup.BackgroundTransparency = 1
qualityGroup.Visible = false
qualityGroup.ZIndex = 250
qualityGroup.Parent = screenGui

local qualityScale = Instance.new("UIScale")
qualityScale.Scale = 0.01
qualityScale.Parent = qualityGroup

local qualityText = Instance.new("TextLabel")
qualityText.Name = "QualityText"
qualityText.AnchorPoint = Vector2.new(0.5, 0)
qualityText.Position = UDim2.new(0.5, 0, 0, 0)
qualityText.Size = UDim2.new(1, 0, 0, 58)
qualityText.BackgroundTransparency = 1
qualityText.Text = "PERFECT!"
qualityText.TextScaled = true
qualityText.Font = Enum.Font.FredokaOne
qualityText.TextColor3 = Color3.fromRGB(80, 255, 120)
qualityText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
qualityText.TextStrokeTransparency = 0
qualityText.ZIndex = 255
qualityText.Parent = qualityGroup

local qualityTextConstraint = Instance.new("UITextSizeConstraint")
qualityTextConstraint.MaxTextSize = 48
qualityTextConstraint.MinTextSize = 18
qualityTextConstraint.Parent = qualityText

local accuracyText = Instance.new("TextLabel")
accuracyText.Name = "AccuracyText"
accuracyText.AnchorPoint = Vector2.new(0.5, 0)
accuracyText.Position = UDim2.new(0.5, 0, 0, 55)
accuracyText.Size = UDim2.new(1, -110, 0, 28)
accuracyText.BackgroundTransparency = 1
accuracyText.BorderSizePixel = 0
accuracyText.Text = "Accuracy: 100%"
accuracyText.TextScaled = true
accuracyText.Font = Enum.Font.FredokaOne
accuracyText.TextColor3 = Color3.fromRGB(255, 255, 255)
accuracyText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
accuracyText.TextStrokeTransparency = 0
accuracyText.ZIndex = 260
accuracyText.Parent = qualityGroup

local accuracyConstraint = Instance.new("UITextSizeConstraint")
accuracyConstraint.MaxTextSize = 22
accuracyConstraint.MinTextSize = 8
accuracyConstraint.Parent = accuracyText

local function createStrengthIcon(parent, size, zIndex)
	if images.strength ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "StrengthIcon"
		img.Size = UDim2.fromOffset(size, size)
		img.BackgroundTransparency = 1
		img.Image = images.strength
		img.ScaleType = Enum.ScaleType.Fit
		img.ImageTransparency = 0
		img.ZIndex = zIndex
		img.Parent = parent
		return img
	end

	local txt = Instance.new("TextLabel")
	txt.Name = "StrengthIcon"
	txt.Size = UDim2.fromOffset(size, size)
	txt.BackgroundTransparency = 1
	txt.Text = "⚡"
	txt.TextScaled = true
	txt.Font = Enum.Font.FredokaOne
	txt.TextColor3 = Color3.fromRGB(255, 210, 70)
	txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	txt.TextStrokeTransparency = 0.15
	txt.TextTransparency = 0
	txt.ZIndex = zIndex
	txt.Parent = parent
	return txt
end

local function stopMarkerRender()
	if markerRenderConnection then
		markerRenderConnection:Disconnect()
		markerRenderConnection = nil
	end
end

local function showStatus()
end

local function hideStatus()
end

local function getLiveMarkerAlpha()
	local elapsed = os.clock() - meterStartedAt
	local phase = (elapsed * MARKER_SPEED) % 2

	if phase <= 1 then
		return phase
	end

	return 2 - phase
end

local function getSafeTopBottom()
	local top = BAR_TOP_SCALE
	local bottom = BAR_BOTTOM_SCALE

	if meterRoot.AbsoluteSize.Y > 0 and markerHolder.AbsoluteSize.Y > 0 then
		local halfMarkerScale = (markerHolder.AbsoluteSize.Y * 0.5) / meterRoot.AbsoluteSize.Y
		top += halfMarkerScale
		bottom -= halfMarkerScale
	end

	if top >= bottom then
		top = 0.3
		bottom = 0.7
	end

	return top, bottom
end

local function setMarkerAlpha(alpha)
	alpha = math.clamp(alpha, 0, 1)

	local safeTop, safeBottom = getSafeTopBottom()
	local yScale = safeBottom - (alpha * (safeBottom - safeTop))

	markerHolder.Position = UDim2.fromScale(BAR_X_SCALE, yScale)
end

local function getQualityFromAlpha(alpha)
	alpha = math.clamp(alpha, 0, 1)

	for _, quality in ipairs(QUALITY_CONFIG) do
		if alpha >= quality.minAlpha and alpha <= quality.maxAlpha then
			return quality
		end
	end

	return { name = "Bad" }
end

local function showQualityPopup(qualityName, alpha)
	local normalizedQuality = normalizeQualityName(qualityName)
	alpha = math.clamp(tonumber(alpha) or 0, 0, 1)

	playQualitySound(normalizedQuality)

	local accuracyPercent = math.floor((alpha * 100) + 0.5)

	qualityText.Text = QUALITY_DISPLAY_TEXT[normalizedQuality] or string.upper(normalizedQuality)
	qualityText.TextColor3 = QUALITY_TEXT_COLORS[normalizedQuality] or Color3.fromRGB(255, 255, 255)

	accuracyText.Text = "Accuracy: " .. tostring(accuracyPercent) .. "%"
	accuracyText.TextColor3 = QUALITY_TEXT_COLORS[normalizedQuality] or Color3.fromRGB(255, 255, 255)

	qualityGroup.Position = UDim2.new(
		METER_SCREEN_POSITION.X.Scale + 0.1,
		METER_SCREEN_POSITION.X.Offset,
		METER_SCREEN_POSITION.Y.Scale - 0.19,
		METER_SCREEN_POSITION.Y.Offset
	)

	lastStrengthPopupPosition = UDim2.new(
		qualityGroup.Position.X.Scale,
		qualityGroup.Position.X.Offset,
		qualityGroup.Position.Y.Scale + 0.025,
		qualityGroup.Position.Y.Offset
	)

	lastQualityPopupTime = os.clock()

	qualityGroup.Visible = true
	qualityScale.Scale = 0.05
	qualityGroup.Rotation = 0

	qualityText.TextTransparency = 0
	qualityText.TextStrokeTransparency = 0
	accuracyText.TextTransparency = 0
	accuracyText.TextStrokeTransparency = 0

	tween(qualityScale, 0.13, { Scale = 1.22 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.delay(0.13, function()
		if qualityGroup.Visible then
			tween(qualityScale, 0.08, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
	end)

	task.delay(0.78, function()
		if qualityGroup.Visible then
			tween(qualityScale, 0.18, { Scale = 0.78 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(qualityText, 0.18, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(accuracyText, 0.18, {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end)

	task.delay(1.02, function()
		qualityGroup.Visible = false
	end)
end

local function hideMeter()
	meterActive = false
	meterAlreadyHit = false
	stopMarkerRender()

	tween(meterScale, 0.1, { Scale = 0.36 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(luckyBarImage, 0.08, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(markerImage, 0.08, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	task.delay(0.12, function()
		if not meterActive then
			meterRoot.Visible = false
			markerHolder.Visible = false
		end
	end)
end

local function showMeter()
	if not trainingActive or meterActive then
		return
	end

	meterActive = true
	meterAlreadyHit = false
	meterStartedAt = os.clock()
	currentMarkerAlpha = 0

	meterRoot.Position = METER_SCREEN_POSITION
	meterRoot.Visible = true
	markerHolder.Visible = true
	meterScale.Scale = 0.38
	luckyBarImage.ImageTransparency = 0.1
	markerImage.ImageTransparency = 0
	setMarkerAlpha(0)

	tween(meterScale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(luckyBarImage, 0.12, { ImageTransparency = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	stopMarkerRender()

	markerRenderConnection = RunService.RenderStepped:Connect(function()
		if not meterActive then
			return
		end

		currentMarkerAlpha = getLiveMarkerAlpha()
		setMarkerAlpha(currentMarkerAlpha)
	end)
end

local function hitMeter()
	if not trainingActive or not meterActive or meterAlreadyHit then
		return
	end

	meterAlreadyHit = true
	currentMarkerAlpha = getLiveMarkerAlpha()

	local quality = getQualityFromAlpha(currentMarkerAlpha)
	showQualityPopup(quality.name, currentMarkerAlpha)
	meterRemote:FireServer(quality.name, currentMarkerAlpha)

	task.delay(0.06, function()
		hideMeter()
	end)
end

local function startMeterLoop()
	meterLoopToken += 1
	local token = meterLoopToken

	task.spawn(function()
		while trainingActive and token == meterLoopToken do
			local waitTime = math.random(
				math.floor(METER_MIN_DELAY * 10),
				math.floor(METER_MAX_DELAY * 10)
			) / 10

			task.wait(waitTime)

			if trainingActive and token == meterLoopToken and not meterActive then
				showMeter()
			end

			while meterActive and trainingActive and token == meterLoopToken do
				task.wait(0.08)
			end
		end
	end)
end

local function requestStartTraining()
	if trainingActive then
		return
	end

	if not getEquippedTrainingTool() then
		return
	end

	local now = os.clock()
	if now - lastStartRequest < START_EQUIP_COOLDOWN then
		return
	end

	lastStartRequest = now
	startRemote:FireServer()
end

local function requestStopTraining()
	if trainingActive then
		trainingActive = false
	end

	meterLoopToken += 1
	unfreezeLocalControls()
	hideStatus()
	hideMeter()
	stopRemote:FireServer()
end

local function isLuckyMeterQuality(quality)
	quality = tostring(quality or "")

	return quality == "Perfect"
		or quality == "Good"
		or quality == "Average"
		or quality == "Bad"
		or quality == "Great"
		or quality == "Excellent"
end

local function getTrainingPopupPosition()
	local randomX = rng:NextNumber(-75, 75)
	local randomAbove = rng:NextNumber(0, 18)

	return UDim2.new(
		0.5,
		randomX,
		0.78,
		-randomAbove
	)
end

local function fadeIcon(icon, duration)
	if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
		tween(icon, duration, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	else
		tween(icon, duration, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
end

local function showStrengthGainPopup(gain, quality)
	gain = math.floor(tonumber(gain) or 0)
	if gain <= 0 then
		return
	end

	local isLuckyBonus = isLuckyMeterQuality(quality) and os.clock() - lastQualityPopupTime <= 1.45
	local popupPosition = isLuckyBonus and lastStrengthPopupPosition or getTrainingPopupPosition()

	local popup = Instance.new("Frame")
	popup.Name = "StrengthGainPopup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = popupPosition
	popup.Size = UDim2.fromOffset(isLuckyBonus and 215 or 190, isLuckyBonus and 30 or 34)
	popup.BackgroundTransparency = 1
	popup.BorderSizePixel = 0
	popup.ZIndex = 310
	popup.Parent = screenGui

	local popupScale = Instance.new("UIScale")
	popupScale.Scale = 0.05
	popupScale.Parent = popup

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.ZIndex = 311
	content.Parent = popup

	local icon = createStrengthIcon(content, isLuckyBonus and 22 or 23, 312)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0.29, 0, 0.5, 0)

	local text = Instance.new("TextLabel")
	text.Name = "GainText"
	text.AnchorPoint = Vector2.new(0, 0.5)
	text.Position = UDim2.new(0.335, 0, 0.5, 0)
	text.Size = UDim2.new(0.62, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "+" .. formatNumber(gain) .. " Strength"
	text.TextColor3 = isLuckyBonus and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 222, 75)
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextStrokeTransparency = 0
	text.TextTransparency = 0
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 313
	text.Parent = content

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = isLuckyBonus and 16 or 18
	constraint.MinTextSize = 8
	constraint.Parent = text

	-- Real popup tween for BOTH lucky bonus and normal strength.
	tween(popupScale, 0.12, { Scale = 1.2 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	task.delay(0.12, function()
		if popup.Parent then
			tween(popupScale, 0.07, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end
	end)

	task.delay(0.18, function()
		if popup.Parent then
			tween(
				popup,
				0.55,
				{
					Position = UDim2.new(
						popupPosition.X.Scale,
						popupPosition.X.Offset,
						popupPosition.Y.Scale - (isLuckyBonus and 0.004 or 0.018),
						popupPosition.Y.Offset - (isLuckyBonus and 2 or 10)
					),
				},
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
		end
	end)

	task.delay(0.62, function()
		if not popup.Parent then
			return
		end

		fadeIcon(icon, 0.25)
		tween(text, 0.25, {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(popupScale, 0.25, { Scale = 0.72 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)

	task.delay(0.92, function()
		if popup then
			popup:Destroy()
		end
	end)
end

local function hookTool(tool)
	if hookedTools[tool] then
		return
	end

	if not tool:IsA("Tool") then
		return
	end

	hookedTools[tool] = true

	tool.Equipped:Connect(function()
		if isTrainingTool(tool) then
			task.defer(requestStartTraining)
		end
	end)

	tool.Unequipped:Connect(function()
		if isTrainingTool(tool) then
			requestStopTraining()
		end
	end)
end

local function hookCharacter(character)
	for _, child in ipairs(character:GetChildren()) do
		hookTool(child)
	end

	character.ChildAdded:Connect(function(child)
		hookTool(child)

		if isTrainingTool(child) then
			task.defer(requestStartTraining)
		end
	end)
end

local function hookBackpack()
	local backpack = player:WaitForChild("Backpack")

	for _, child in ipairs(backpack:GetChildren()) do
		hookTool(child)
	end

	backpack.ChildAdded:Connect(function(child)
		hookTool(child)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.UserInputType ~= Enum.UserInputType.Touch
		and input.KeyCode ~= Enum.KeyCode.ButtonR2
		and input.KeyCode ~= Enum.KeyCode.Space then
		return
	end

	if meterActive then
		hitMeter()
	end
end)

stateRemote.OnClientEvent:Connect(function(isActive)
	if isActive == true then
		if trainingActive then
			return
		end

		trainingActive = true
		freezeLocalControls()
		showStatus()
		startMeterLoop()
	else
		trainingActive = false
		meterLoopToken += 1

		unfreezeLocalControls()
		hideStatus()
		hideMeter()
	end
end)

rewardRemote.OnClientEvent:Connect(function(_rewardType, quality, gain, _newTotal)
	showStrengthGainPopup(gain, quality)
end)

if player.Character then
	hookCharacter(player.Character)
end

player.CharacterAdded:Connect(function(character)
	trainingActive = false
	meterLoopToken += 1

	unfreezeLocalControls()
	hideStatus()
	hideMeter()
	hookCharacter(character)
end)

hookBackpack()

task.defer(function()
	if getEquippedTrainingTool() then
		requestStartTraining()
	end
end)

print("[WeightTraining] Loaded popup fade animation for all strength gains.")