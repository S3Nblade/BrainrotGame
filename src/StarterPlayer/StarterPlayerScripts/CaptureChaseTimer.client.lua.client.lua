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
local guiFolder = ReplicatedStorage:WaitForChild("GUI", 5)
local clockFolder = guiFolder and guiFolder:WaitForChild("Clock", 5)

local FONT = Enum.Font.FredokaOne
local tracked = {}

local BILLBOARD_SIZE = UDim2.fromOffset(220, 122)
local BILLBOARD_OFFSET = Vector3.new(0, 6.75, 0)

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

local clockImage = ""
if clockFolder then
	clockImage = getImageFromAsset(clockFolder:FindFirstChild("clock"))
end

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
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.NameDisplayDistance = 0
		humanoid.HealthDisplayDistance = 0
	end)
end

local function isLegacyHealthGui(obj)
	if not obj:IsA("BillboardGui") or obj.Name == "CaptureChaseTimerGui" or obj.Name == "StunnedPopup" then
		return false
	end

	local lowerName = string.lower(obj.Name)
	return obj.Name == "CaptureHealthBar"
		or string.find(lowerName, "health", 1, true) ~= nil
		or string.find(lowerName, "hp", 1, true) ~= nil
		or string.find(lowerName, "capture", 1, true) ~= nil
end

local function forceLegacyOverheadsHidden(npc, hidden)
	npc:SetAttribute("ClientCaptureGuiActive", hidden)

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BillboardGui") and obj.Name ~= "CaptureChaseTimerGui" then
			if isLegacyHealthGui(obj) or (hidden and npc:GetAttribute("EggBrainrot") == true) then
				obj:Destroy()
			else
				obj.Enabled = not hidden
			end
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

	local timerBack = Instance.new("Frame")
	timerBack.Name = "TimerBack"
	timerBack.Position = UDim2.new(0, 54, 0, 39)
	timerBack.Size = UDim2.fromOffset(64, 6)
	timerBack.BackgroundColor3 = Color3.fromRGB(18, 20, 30)
	timerBack.BackgroundTransparency = 0.1
	timerBack.BorderSizePixel = 0
	timerBack.ZIndex = 21
	timerBack.Parent = row
	addCorner(timerBack, 6)

	local timerFill = Instance.new("Frame")
	timerFill.Name = "TimerFill"
	timerFill.Size = UDim2.fromScale(1, 1)
	timerFill.BackgroundColor3 = Color3.fromRGB(255, 220, 72)
	timerFill.BorderSizePixel = 0
	timerFill.ZIndex = 22
	timerFill.Parent = timerBack
	addCorner(timerFill, 6)

	return {
		row = row,
		clockHolder = clockHolder,
		image = clockImageLabel,
		timerText = timerText,
		timerBack = timerBack,
		timerFill = timerFill,
		basePosition = UDim2.new(0, 16, 0.5, 0),
	}
end

local function createHPBar(parent)
	local outer = Instance.new("Frame")
	outer.Name = "HPBar"
	outer.AnchorPoint = Vector2.new(0.5, 0)
	outer.Position = UDim2.new(0.5, 0, 0, 56)
	outer.Size = UDim2.fromOffset(194, 25)
	outer.BackgroundColor3 = Color3.fromRGB(18, 25, 44)
	outer.BackgroundTransparency = 1
	outer.BorderSizePixel = 0
	outer.ZIndex = 10
	outer.Parent = parent

	addCorner(outer, 14)

	local innerClip = Instance.new("Frame")
	innerClip.Name = "InnerClip"
	innerClip.Position = UDim2.fromScale(0, 0)
	innerClip.Size = UDim2.fromScale(1, 1)
	innerClip.BackgroundTransparency = 1
	innerClip.ClipsDescendants = true
	innerClip.ZIndex = 11
	innerClip.Parent = outer

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.new(0, 0, 0.5, 0)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(86, 235, 106)
	fill.BorderSizePixel = 0
	fill.ZIndex = 12
	fill.Parent = innerClip

	addCorner(fill, 12)

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Name = "GreenGradient"
	fillGradient.Rotation = 90
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(126, 255, 124)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(72, 232, 86)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 186, 64)),
	})
	fillGradient.Parent = fill

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromScale(0, 0)
	shine.Size = UDim2.new(1, 0, 0.34, 0)
	shine.BackgroundColor3 = Color3.fromRGB(190, 255, 185)
	shine.BackgroundTransparency = 0.22
	shine.BorderSizePixel = 0
	shine.ZIndex = 13
	shine.Parent = fill

	addCorner(shine, 10)

	local text = createText(
		outer,
		"HPText",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		"100%",
		Color3.fromRGB(255, 255, 255),
		16,
		30
	)
	text.TextStrokeTransparency = 1

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

	barData.fill.Size = UDim2.new(ratio, 0, 1, 0)
end

local function styleHPBarShell(data, isEgg)
	data.hpBar.outer.BackgroundTransparency = 1
	data.hpBar.innerClip.Position = UDim2.fromScale(0, 0)
	data.hpBar.innerClip.Size = UDim2.fromScale(1, 1)
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

	local eggName = createText(
		main,
		"EggName",
		UDim2.new(0.5, -92, 0, 0),
		UDim2.fromOffset(184, 22),
		"",
		Color3.fromRGB(255, 255, 255),
		18,
		36
	)
	eggName.Visible = false

	local luckText = createText(
		main,
		"LuckText",
		UDim2.new(0.5, -82, 0, 84),
		UDim2.fromOffset(164, 24),
		"",
		Color3.fromRGB(255, 224, 90),
		17,
		36
	)
	luckText.Visible = false

	return {
		billboard = billboard,
		main = main,
		scale = scale,
		clock = clock,
		hpBar = hpBar,
		eggName = eggName,
		luckText = luckText,
		hpVisualRatio = nil,
		hpTargetRatio = nil,
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
	local duration = math.max(tonumber(data.currentDuration) or timeLeft, 0.1)
	local ratio = math.clamp(timeLeft / duration, 0, 1)
	data.clock.timerFill.Size = UDim2.fromScale(ratio, 1)

	if timeLeft <= LOW_TIME_SECONDS then
		local t = os.clock()
		local flashRed = math.floor(t * 8) % 2 == 0

		if flashRed then
			data.clock.timerText.TextColor3 = Color3.fromRGB(255, 55, 55)
			data.clock.timerFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		else
			data.clock.timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
			data.clock.timerFill.BackgroundColor3 = Color3.fromRGB(255, 220, 72)
		end

		local jitterX = math.sin(t * 58) * 2.3 + math.sin(t * 111) * 1.2
		local jitterY = math.cos(t * 67) * 1.4
		local jitterRotation = math.sin(t * 76) * 7 + math.cos(t * 143) * 4

		data.clock.clockHolder.Position = UDim2.new(0, 16 + jitterX, 0.5, jitterY)
		data.clock.image.Rotation = jitterRotation
	else
		data.clock.timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
		data.clock.timerFill.BackgroundColor3 = Color3.fromRGB(255, 220, 72)
		data.clock.clockHolder.Position = data.clock.basePosition
		data.clock.image.Rotation = 0
	end
end

local function updateHPBar(data, npc)
	local isEgg = npc:GetAttribute("EggBrainrot") == true
	local eggHP = tonumber(npc:GetAttribute("EggHP"))
	local captureHP = tonumber(npc:GetAttribute("CaptureHP"))
	local eggMaxHP = tonumber(npc:GetAttribute("EggMaxHP"))
	local captureMaxHP = tonumber(npc:GetAttribute("CaptureMaxHP"))
	local hp = captureHP
	local maxHP = captureMaxHP

	if isEgg then
		if eggHP and captureHP then
			hp = math.min(eggHP, captureHP)
		else
			hp = eggHP or captureHP
		end

		maxHP = eggMaxHP or captureMaxHP
	end

	hp = hp or 0
	maxHP = maxHP or 1
	local ratio = math.clamp(hp / math.max(maxHP, 1), 0, 1)
	local shownPercent = math.floor((ratio * 100) + 0.5)

	data.hpBar.text.Text = tostring(shownPercent) .. "%"
	data.hpBar.text.Visible = true
	styleHPBarShell(data, isEgg)

	if data.lastHPRatio and math.abs(data.lastHPRatio - ratio) < 0.01 then
		return
	end

	data.lastHPRatio = ratio
	stopTween(data.hpPulseTween)
	data.hpBar.fill.BackgroundTransparency = 0
	data.hpTargetRatio = ratio
	data.hpVisualRatio = data.hpVisualRatio or data.hpBar.fill.Size.X.Scale
end

local function animateHPBar(data, dt)
	if not data.hpTargetRatio then
		return
	end

	local visual = data.hpVisualRatio
	if visual == nil then
		visual = data.hpBar.fill.Size.X.Scale
	end

	local target = math.clamp(data.hpTargetRatio, 0, 1)
	local alpha = 1 - math.exp(-math.max(dt or 0, 0) * 12)
	visual += (target - visual) * alpha

	if math.abs(visual - target) < 0.003 then
		visual = target
	end

	data.hpVisualRatio = visual
	data.hpBar.fill.Size = UDim2.new(visual, 0, 1, 0)
end

local function setCaptureMode(data, npc)
	data.lastMode = "capture"
	data.stunPopupShown = false

	local endTime = tonumber(npc:GetAttribute("CaptureChaseEndTime")) or 0
	local timeLeft = math.max(0, endTime - getServerTime())
	local duration = tonumber(npc:GetAttribute("CaptureChaseDuration")) or timeLeft
	data.currentDuration = math.max(duration, timeLeft, 0.1)

	local isEgg = npc:GetAttribute("EggBrainrot") == true
	data.clock.row.Visible = true
	data.eggName.Visible = isEgg
	data.luckText.Visible = isEgg

	if isEgg then
		data.eggName.Text = tostring(npc:GetAttribute("EggOverheadName") or npc:GetAttribute("Rarity") or npc.Name)
		data.luckText.Text = "Luck +" .. tostring(math.floor(tonumber(npc:GetAttribute("LuckBonus")) or 0)) .. "%"
	end

	data.clock.row.Position = isEgg and UDim2.new(0.5, 0, 0, 22) or UDim2.new(0.5, 0, 0, 2)
	data.clock.timerBack.Visible = false
	data.hpBar.outer.Position = isEgg and UDim2.new(0.5, 0, 0, 62) or UDim2.new(0.5, 0, 0, 56)
	data.hpBar.outer.Size = isEgg and UDim2.fromOffset(170, 20) or UDim2.fromOffset(194, 25)
	styleHPBarShell(data, isEgg)
	data.hpBar.fill.BackgroundColor3 = Color3.fromRGB(86, 235, 106)
	data.hpBar.shine.BackgroundColor3 = Color3.fromRGB(190, 255, 185)
	data.hpBar.text.TextColor3 = Color3.fromRGB(255, 255, 255)
	data.hpBar.text.Visible = true

	updateClock(data, timeLeft)
	updateHPBar(data, npc)
end

local function setStunnedMode(data, npc)
	local firstFrame = data.lastMode ~= "stunned"

	if firstFrame then
		popIn(data)

		if not data.stunPopupShown then
			data.stunPopupShown = true
			showStunnedPopup(npc)
		end
	end

	data.lastMode = "stunned"

	data.clock.row.Visible = false
	data.clock.timerBack.Visible = false
	local isEgg = npc:GetAttribute("EggBrainrot") == true
	data.eggName.Visible = isEgg
	data.luckText.Visible = isEgg

	if isEgg then
		data.eggName.Text = tostring(npc:GetAttribute("EggOverheadName") or npc:GetAttribute("Rarity") or npc.Name)
		data.luckText.Text = "Hatch Egg"
	end

	data.hpBar.outer.Position = isEgg and UDim2.new(0.5, 0, 0, 34) or UDim2.new(0.5, 0, 0, 28)
	data.hpBar.outer.Size = isEgg and UDim2.fromOffset(150, 22) or UDim2.fromOffset(165, 23)
	styleHPBarShell(data, isEgg)
	data.hpBar.fill.BackgroundColor3 = Color3.fromRGB(86, 235, 106)
	data.hpBar.shine.BackgroundColor3 = Color3.fromRGB(190, 255, 185)
	updateHPBar(data, npc)
	data.hpBar.text.Visible = true
end

local function setPanicMode(data)
	if data.lastMode ~= "panic" then
		setBarRatio(data.hpBar, 1)
		popIn(data)
	end

	data.lastMode = "panic"
	data.stunPopupShown = false

	data.clock.row.Visible = false
	data.clock.timerBack.Visible = false
	data.eggName.Visible = false
	data.luckText.Visible = false

	data.hpBar.outer.Position = UDim2.new(0.5, 0, 0, 28)
	data.hpBar.outer.Size = UDim2.fromOffset(145, 23)
	styleHPBarShell(data, false)
	data.hpBar.fill.BackgroundColor3 = Color3.fromRGB(255, 146, 42)
	data.hpBar.shine.BackgroundColor3 = Color3.fromRGB(255, 212, 112)
	data.hpBar.text.Text = "EVADING"
	data.hpBar.text.TextColor3 = Color3.fromRGB(255, 255, 255)
	data.hpBar.text.Visible = true
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
	local isEgg = npc:GetAttribute("EggBrainrot") == true
	local eggHP = tonumber(npc:GetAttribute("EggHP")) or tonumber(npc:GetAttribute("CaptureHP"))
	local eggMaxHP = tonumber(npc:GetAttribute("EggMaxHP")) or tonumber(npc:GetAttribute("CaptureMaxHP"))
	local eggDamaged = isEgg and eggHP ~= nil and eggMaxHP ~= nil and eggHP < eggMaxHP

	local shouldShow = active or stunned or panic or shielded or eggDamaged

	if not shouldShow then
		forceLegacyOverheadsHidden(npc, false)

		local data = tracked[npc]
		if data then
			setVisible(data, false)

			data.lastMode = "hidden"
			data.lastHPRatio = nil
			data.hpVisualRatio = nil
			data.hpTargetRatio = nil
			setBarRatio(data.hpBar, 1)
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
	elseif active or eggDamaged then
		setCaptureMode(data, npc)
	end
end

local function watchNpc(npc)
	if not npc:IsA("Model") then
		return
	end

	hideRobloxHumanoidName(npc)
	ensureGui(npc)

	local function refreshHP()
		if not npc.Parent then
			return
		end

		local data = ensureGui(npc)
		if data and data.billboard and data.billboard.Enabled then
			updateHPBar(data, npc)
		elseif data then
			data.lastHPRatio = nil
			data.hpTargetRatio = nil
		end
	end

	npc:GetAttributeChangedSignal("CaptureHP"):Connect(refreshHP)
	npc:GetAttributeChangedSignal("EggHP"):Connect(refreshHP)
	npc:GetAttributeChangedSignal("CaptureMaxHP"):Connect(refreshHP)
	npc:GetAttributeChangedSignal("EggMaxHP"):Connect(refreshHP)

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

RunService.RenderStepped:Connect(function(dt)
	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model") then
			updateNpc(npc)
			local data = tracked[npc]
			if data and data.billboard and data.billboard.Enabled then
				animateHPBar(data, dt)
			end
		end
	end
end)

print("[CaptureChaseTimer] loaded with close clock + no text size change")
