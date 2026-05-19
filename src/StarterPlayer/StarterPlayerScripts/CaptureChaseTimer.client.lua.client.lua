-- StarterPlayerScripts/CaptureChaseTimer.client.lua
-- Clock is close to timer text.
-- Last 5 seconds: timer flashes red/white only. Text does NOT grow.
-- Clock jitters in last 5 seconds.
-- Compact non-blocking chase GUI.

--!nonstrict

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local npcFolder = Workspace:WaitForChild("BrainrotNPCs")
local guiFolder = ReplicatedStorage:WaitForChild("GUI")
local clockFolder = guiFolder:WaitForChild("Clock")

local FONT = Enum.Font.FredokaOne
local tracked = {}

local BILLBOARD_SIZE = UDim2.fromOffset(220, 92)
local BILLBOARD_OFFSET = Vector3.new(0, 7.25, 0)

local CLOCK_SIZE = 40
local LOW_TIME_SECONDS = 5

local function getImageFromAsset(asset)
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

	local ok, result = pcall(function()
		return asset.Image
	end)

	if ok and typeof(result) == "string" then
		return result
	end

	return ""
end

local clockImage = getImageFromAsset(clockFolder:WaitForChild("clock"))

local function getServerTime()
	return Workspace:GetServerTimeNow()
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

local function hideRobloxHumanoidName(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	pcall(function()
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end)
end

local function forceLegacyOverheadsHidden(npc, hidden)
	npc:SetAttribute("ClientCaptureGuiActive", hidden)

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BillboardGui") and obj.Name ~= "CaptureChaseTimerGui" then
			obj.Enabled = not hidden
		end
	end
end

local function addCorner(obj, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = obj
	return corner
end

local function createText(parent, name, position, size, text, color, maxSize, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Font = FONT
	label.ZIndex = zIndex
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize
	constraint.MinTextSize = 7
	constraint.Parent = label

	return label
end

local function createClockTimerRow(parent)
	local row = Instance.new("Frame")
	row.Name = "ClockTimerRow"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 2)
	row.Size = UDim2.fromOffset(125, 48)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local clockHolder = Instance.new("Frame")
	clockHolder.Name = "ClockHolder"
	clockHolder.AnchorPoint = Vector2.new(0, 0.5)
	clockHolder.Position = UDim2.new(0, 16, 0.5, 0)
	clockHolder.Size = UDim2.fromOffset(CLOCK_SIZE, CLOCK_SIZE)
	clockHolder.BackgroundTransparency = 1
	clockHolder.Parent = row

	local clockImageLabel = Instance.new("ImageLabel")
	clockImageLabel.Name = "ClockImage"
	clockImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	clockImageLabel.Position = UDim2.fromScale(0.5, 0.5)
	clockImageLabel.Size = UDim2.fromOffset(CLOCK_SIZE, CLOCK_SIZE)
	clockImageLabel.BackgroundTransparency = 1
	clockImageLabel.Image = clockImage
	clockImageLabel.ScaleType = Enum.ScaleType.Fit
	clockImageLabel.ZIndex = 20
	clockImageLabel.Parent = clockHolder

	local timerText = createText(
		row,
		"TimerText",
		UDim2.new(0, 54, 0, 10),
		UDim2.fromOffset(66, 28),
		"0.0s",
		Color3.fromRGB(255, 255, 255),
		19,
		35
	)

	timerText.TextXAlignment = Enum.TextXAlignment.Left

	return {
		row = row,
		clockHolder = clockHolder,
		image = clockImageLabel,
		timerText = timerText,
		basePosition = UDim2.new(0, 16, 0.5, 0),
	}
end

local function createHPBar(parent)
	local outer = Instance.new("Frame")
	outer.Name = "HPBar"
	outer.AnchorPoint = Vector2.new(0.5, 0)
	outer.Position = UDim2.new(0.5, 0, 0, 56)
	outer.Size = UDim2.fromOffset(194, 25)
	outer.BackgroundColor3 = Color3.fromRGB(125, 22, 31)
	outer.BorderSizePixel = 0
	outer.ZIndex = 10
	outer.Parent = parent

	addCorner(outer, 14)

	local innerClip = Instance.new("Frame")
	innerClip.Name = "InnerClip"
	innerClip.Position = UDim2.fromOffset(3, 3)
	innerClip.Size = UDim2.new(1, -6, 1, -6)
	innerClip.BackgroundTransparency = 1
	innerClip.ClipsDescendants = true
	innerClip.ZIndex = 11
	innerClip.Parent = outer

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.new(0, 0, 0.5, 0)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 66, 78)
	fill.BorderSizePixel = 0
	fill.ZIndex = 12
	fill.Parent = innerClip

	addCorner(fill, 12)

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromScale(0, 0)
	shine.Size = UDim2.new(1, 0, 0.34, 0)
	shine.BackgroundColor3 = Color3.fromRGB(255, 170, 175)
	shine.BackgroundTransparency = 0.38
	shine.BorderSizePixel = 0
	shine.ZIndex = 13
	shine.Parent = fill

	addCorner(shine, 10)

	local text = createText(
		outer,
		"HPText",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		"NPC 0/0",
		Color3.fromRGB(255, 255, 255),
		13,
		30
	)

	return {
		outer = outer,
		innerClip = innerClip,
		fill = fill,
		shine = shine,
		text = text,
	}
end

local function setBarRatio(barData, ratio)
	ratio = math.clamp(ratio, 0, 1)

	if ratio <= 0 then
		barData.innerClip.Size = UDim2.new(0, 0, 1, -6)
	else
		barData.innerClip.Size = UDim2.new(ratio, -6 * ratio, 1, -6)
	end
end

local function showStunnedPopup(npc)
	local root = getNpcRoot(npc)
	if not root then
		return
	end

	local old = root:FindFirstChild("StunnedPopup")
	if old then
		old:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StunnedPopup"
	billboard.Size = UDim2.fromOffset(185, 55)
	billboard.StudsOffset = Vector3.new(0, 7.25, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 95
	billboard.LightInfluence = 0
	billboard.Adornee = root
	billboard.Parent = root

	local scale = Instance.new("UIScale")
	scale.Scale = 0.25
	scale.Parent = billboard

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = "STUNNED!"
	text.Font = FONT
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(120, 255, 75)
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextStrokeTransparency = 0
	text.ZIndex = 60
	text.Parent = billboard

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 34
	constraint.MinTextSize = 12
	constraint.Parent = text

	TweenService:Create(
		scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	TweenService:Create(
		billboard,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, 8.15, 0) }
	):Play()

	task.delay(0.55, function()
		if not billboard.Parent then
			return
		end

		TweenService:Create(
			text,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}
		):Play()
	end)

	task.delay(0.85, function()
		if billboard then
			billboard:Destroy()
		end
	end)
end

local function createGui(npc)
	local root = getNpcRoot(npc)
	if not root then
		return nil
	end

	hideRobloxHumanoidName(npc)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CaptureChaseTimerGui"
	billboard.Adornee = root
	billboard.Size = BILLBOARD_SIZE
	billboard.StudsOffset = BILLBOARD_OFFSET
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.LightInfluence = 0
	billboard.Enabled = false
	billboard.Parent = root

	local main = Instance.new("Frame")
	main.Name = "Main"
	main.AnchorPoint = Vector2.new(0.5, 0.5)
	main.Position = UDim2.fromScale(0.5, 0.5)
	main.Size = UDim2.fromScale(1, 1)
	main.BackgroundTransparency = 1
	main.Parent = billboard

	local scale = Instance.new("UIScale")
	scale.Name = "PopupScale"
	scale.Scale = 0.8
	scale.Parent = main

	local clock = createClockTimerRow(main)
	local hpBar = createHPBar(main)

	return {
		billboard = billboard,
		main = main,
		scale = scale,
		clock = clock,
		hpBar = hpBar,
		hpTween = nil,
		lastMode = "hidden",
		lastHPRatio = nil,
		stunPopupShown = false,
	}
end

local function stopTween(tweenObject)
	if tweenObject then
		tweenObject:Cancel()
	end
end

local function destroyGui(npc)
	local data = tracked[npc]

	if data then
		stopTween(data.hpTween)

		if data.billboard then
			data.billboard:Destroy()
		end
	end

	tracked[npc] = nil
end

local function ensureGui(npc)
	local data = tracked[npc]

	if data and data.billboard and data.billboard.Parent then
		local root = getNpcRoot(npc)
		if root and data.billboard.Adornee ~= root then
			data.billboard.Adornee = root
			data.billboard.Parent = root
		end

		return data
	end

	data = createGui(npc)

	if data then
		tracked[npc] = data
	end

	return data
end

local function popIn(data)
	data.scale.Scale = 0.65

	TweenService:Create(
		data.scale,
		TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

local function setVisible(data, visible)
	if data.billboard.Enabled == visible then
		return
	end

	data.billboard.Enabled = visible

	if visible then
		popIn(data)
	end
end

local function updateClock(data, timeLeft)
	data.clock.timerText.Text = string.format("%.1fs", math.max(0, timeLeft))

	if timeLeft <= LOW_TIME_SECONDS then
		local t = os.clock()
		local flashRed = math.floor(t * 8) % 2 == 0

		if flashRed then
			data.clock.timerText.TextColor3 = Color3.fromRGB(255, 55, 55)
		else
			data.clock.timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
		end

		local jitterX = math.sin(t * 58) * 2.3 + math.sin(t * 111) * 1.2
		local jitterY = math.cos(t * 67) * 1.4
		local jitterRotation = math.sin(t * 76) * 7 + math.cos(t * 143) * 4

		data.clock.clockHolder.Position = UDim2.new(0, 16 + jitterX, 0.5, jitterY)
		data.clock.image.Rotation = jitterRotation
	else
		data.clock.timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
		data.clock.clockHolder.Position = data.clock.basePosition
		data.clock.image.Rotation = 0
	end
end

local function updateHPBar(data, npc)
	local hp = tonumber(npc:GetAttribute("CaptureHP")) or 0
	local maxHP = tonumber(npc:GetAttribute("CaptureMaxHP")) or 1
	local ratio = math.clamp(hp / math.max(maxHP, 1), 0, 1)

	local targetLabel = npc:GetAttribute("EggBrainrot") == true and "EGG" or npc.Name
	data.hpBar.text.Text = targetLabel .. " " .. tostring(math.floor(hp)) .. "/" .. tostring(math.floor(maxHP))

	if data.lastHPRatio and math.abs(data.lastHPRatio - ratio) < 0.01 then
		return
	end

	data.lastHPRatio = ratio
	stopTween(data.hpTween)

	local newSize
	if ratio <= 0 then
		newSize = UDim2.new(0, 0, 1, -6)
	else
		newSize = UDim2.new(ratio, -6 * ratio, 1, -6)
	end

	data.hpTween = TweenService:Create(
		data.hpBar.innerClip,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = newSize }
	)

	data.hpTween:Play()
end

local function setCaptureMode(data, npc)
	data.lastMode = "capture"
	data.stunPopupShown = false

	local endTime = tonumber(npc:GetAttribute("CaptureChaseEndTime")) or 0
	local timeLeft = math.max(0, endTime - getServerTime())

	data.clock.row.Visible = true

	data.hpBar.outer.Position = UDim2.new(0.5, 0, 0, 56)
	data.hpBar.outer.Size = UDim2.fromOffset(194, 25)
	data.hpBar.outer.BackgroundColor3 = Color3.fromRGB(125, 22, 31)
	data.hpBar.fill.BackgroundColor3 = Color3.fromRGB(255, 66, 78)
	data.hpBar.shine.BackgroundColor3 = Color3.fromRGB(255, 170, 175)

	updateClock(data, timeLeft)
	updateHPBar(data, npc)
end

local function setStunnedMode(data, npc)
	local firstFrame = data.lastMode ~= "stunned"

	if firstFrame then
		setBarRatio(data.hpBar, 1)
		popIn(data)

		if not data.stunPopupShown then
			data.stunPopupShown = true
			showStunnedPopup(npc)
		end
	end

	data.lastMode = "stunned"

	data.clock.row.Visible = false

	data.hpBar.outer.Position = UDim2.new(0.5, 0, 0, 28)
	data.hpBar.outer.Size = UDim2.fromOffset(165, 23)
	data.hpBar.outer.BackgroundColor3 = Color3.fromRGB(38, 110, 26)
	data.hpBar.fill.BackgroundColor3 = Color3.fromRGB(120, 255, 70)
	data.hpBar.shine.BackgroundColor3 = Color3.fromRGB(220, 255, 185)
	data.hpBar.text.Text = npc:GetAttribute("EggBrainrot") == true and "READY TO HATCH" or "READY TO PICKUP"
end

local function setPanicMode(data)
	if data.lastMode ~= "panic" then
		setBarRatio(data.hpBar, 1)
		popIn(data)
	end

	data.lastMode = "panic"
	data.stunPopupShown = false

	data.clock.row.Visible = false

	data.hpBar.outer.Position = UDim2.new(0.5, 0, 0, 28)
	data.hpBar.outer.Size = UDim2.fromOffset(145, 23)
	data.hpBar.outer.BackgroundColor3 = Color3.fromRGB(120, 56, 0)
	data.hpBar.fill.BackgroundColor3 = Color3.fromRGB(255, 130, 35)
	data.hpBar.shine.BackgroundColor3 = Color3.fromRGB(255, 210, 120)
	data.hpBar.text.Text = "EVADING..."
end

local function updateNpc(npc)
	if not npc or not npc.Parent then
		destroyGui(npc)
		return
	end

	hideRobloxHumanoidName(npc)

	local active = npc:GetAttribute("CaptureChaseActive") == true
	local stunned = npc:GetAttribute("CaptureStunned") == true
	local panic = npc:GetAttribute("CapturePanic") == true
	local shielded = npc:GetAttribute("CaptureShielded") == true

	local shouldShow = active or stunned or panic or shielded

	if not shouldShow then
		forceLegacyOverheadsHidden(npc, false)

		local data = tracked[npc]
		if data then
			setVisible(data, false)
			stopTween(data.hpTween)

			data.lastMode = "hidden"
			data.lastHPRatio = nil
			data.stunPopupShown = false

			if data.clock then
				data.clock.timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
				data.clock.clockHolder.Position = data.clock.basePosition
				data.clock.image.Rotation = 0
			end
		end

		return
	end

	forceLegacyOverheadsHidden(npc, true)

	local data = ensureGui(npc)
	if not data then
		return
	end

	setVisible(data, true)

	if stunned then
		setStunnedMode(data, npc)
	elseif panic or shielded then
		setPanicMode(data)
	elseif active then
		setCaptureMode(data, npc)
	end
end

local function watchNpc(npc)
	if not npc:IsA("Model") then
		return
	end

	hideRobloxHumanoidName(npc)
	ensureGui(npc)

	npc.AncestryChanged:Connect(function(_, parent)
		if not parent then
			destroyGui(npc)
		end
	end)
end

for _, npc in ipairs(npcFolder:GetChildren()) do
	if npc:IsA("Model") then
		watchNpc(npc)
	end
end

npcFolder.ChildAdded:Connect(function(npc)
	if npc:IsA("Model") then
		task.wait(0.2)
		watchNpc(npc)
	end
end)

RunService.RenderStepped:Connect(function()
	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model") then
			updateNpc(npc)
		end
	end
end)

print("[CaptureChaseTimer] loaded with close clock + no text size change")
