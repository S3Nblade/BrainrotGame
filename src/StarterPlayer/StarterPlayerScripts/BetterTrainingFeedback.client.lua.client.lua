--!nonstrict
-- StarterPlayerScripts/BetterTrainingFeedback.client.lua
-- Vertical cartoony kick meter.
-- Removes the old wide "Training Power" UI.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

for _, child in ipairs(playerGui:GetChildren()) do
	if child.Name == "BetterTrainingFeedbackGui" or child.Name == "BetterTrainingMeterGui" then
		child:Destroy()
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "BetterTrainingMeterGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 850
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0, 0.5)
root.Position = UDim2.new(0, 24, 0.5, 30)
root.Size = UDim2.fromOffset(78, 265)
root.BackgroundTransparency = 1
root.Parent = gui

local meterBack = Instance.new("Frame")
meterBack.Name = "MeterBack"
meterBack.AnchorPoint = Vector2.new(0.5, 0.5)
meterBack.Position = UDim2.fromScale(0.5, 0.48)
meterBack.Size = UDim2.fromOffset(34, 215)
meterBack.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
meterBack.BorderSizePixel = 0
meterBack.Parent = root

local meterCorner = Instance.new("UICorner")
meterCorner.CornerRadius = UDim.new(0, 8)
meterCorner.Parent = meterBack

local meterStroke = Instance.new("UIStroke")
meterStroke.Thickness = 4
meterStroke.Color = Color3.fromRGB(0, 0, 0)
meterStroke.Parent = meterBack

local segmentColors = {
	Color3.fromRGB(255, 0, 0),
	Color3.fromRGB(255, 100, 0),
	Color3.fromRGB(255, 220, 30),
	Color3.fromRGB(70, 255, 30),
}

local segments = {}

for i = 1, 4 do
	local seg = Instance.new("Frame")
	seg.Name = "Segment" .. tostring(i)
	seg.AnchorPoint = Vector2.new(0.5, 1)
	seg.Position = UDim2.new(0.5, 0, 1 - ((i - 1) * 0.25), -4)
	seg.Size = UDim2.new(1, -8, 0.25, -7)
	seg.BackgroundColor3 = segmentColors[i]
	seg.BackgroundTransparency = 0.45
	seg.BorderSizePixel = 0
	seg.Parent = meterBack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = seg

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Transparency = 0.2
	stroke.Parent = seg

	segments[i] = seg
end

local pointer = Instance.new("TextLabel")
pointer.Name = "Pointer"
pointer.BackgroundTransparency = 1
pointer.AnchorPoint = Vector2.new(0, 0.5)
pointer.Position = UDim2.new(0.68, 0, 0.88, 0)
pointer.Size = UDim2.fromOffset(44, 44)
pointer.Font = Enum.Font.FredokaOne
pointer.Text = "➤"
pointer.TextScaled = true
pointer.TextColor3 = Color3.fromRGB(255, 255, 255)
pointer.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
pointer.TextStrokeTransparency = 0
pointer.Parent = root

local gainText = Instance.new("TextLabel")
gainText.Name = "GainText"
gainText.BackgroundTransparency = 1
gainText.AnchorPoint = Vector2.new(0.5, 0.5)
gainText.Position = UDim2.new(0.5, 0, 1, 24)
gainText.Size = UDim2.fromOffset(130, 34)
gainText.Font = Enum.Font.FredokaOne
gainText.TextScaled = true
gainText.TextColor3 = Color3.fromRGB(255, 255, 255)
gainText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
gainText.TextStrokeTransparency = 0
gainText.TextTransparency = 1
gainText.Text = ""
gainText.Parent = root

local lastValue = nil
local hideId = 0

local function formatNumber(value)
	value = tonumber(value) or 0

	if value >= 1e12 then
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

local function getTrainingValue()
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats then
		for _, name in ipairs({ "Strength", "KickPower", "Kick Power", "Power" }) do
			local stat = leaderstats:FindFirstChild(name)
			if stat and stat:IsA("ValueBase") then
				return tonumber(stat.Value) or 0
			end
		end
	end

	for _, attr in ipairs({ "Strength", "KickPower", "Kick Power", "Power" }) do
		local value = tonumber(player:GetAttribute(attr))
		if value then
			return value
		end
	end

	return 0
end

local function getProgress(value)
	local goal = 100

	while goal <= value do
		goal *= 1.45
	end

	local previous = goal / 1.45
	local alpha = 0

	if goal > previous then
		alpha = math.clamp((value - previous) / (goal - previous), 0, 1)
	end

	return alpha
end

local function updateMeter(value)
	local alpha = getProgress(value)
	local litSegments = math.clamp(math.ceil(alpha * 4), 1, 4)

	for i, seg in ipairs(segments) do
		local active = i <= litSegments

		TweenService:Create(
			seg,
			TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				BackgroundTransparency = active and 0 or 0.55,
				Size = active and UDim2.new(1, -4, 0.25, -5) or UDim2.new(1, -8, 0.25, -7),
			}
		):Play()
	end

	TweenService:Create(
		pointer,
		TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0.68, 0, 0.93 - (alpha * 0.82), 0),
			Rotation = -8 + math.random(-4, 4),
		}
	):Play()
end

local function pulse(gain)
	gain = tonumber(gain) or 0

	TweenService:Create(
		meterBack,
		TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Size = UDim2.fromOffset(39, 225),
		}
	):Play()

	task.delay(0.08, function()
		if meterBack.Parent then
			TweenService:Create(
				meterBack,
				TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{
					Size = UDim2.fromOffset(34, 215),
				}
			):Play()
		end
	end)

	if gain > 0 then
		gainText.Text = "+" .. formatNumber(gain)
		gainText.TextTransparency = 0
		gainText.Position = UDim2.new(0.5, 0, 1, 24)

		TweenService:Create(
			gainText,
			TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{
				Position = UDim2.new(0.5, 0, 1, 8),
			}
		):Play()

		hideId += 1
		local id = hideId

		task.delay(0.75, function()
			if id ~= hideId then
				return
			end

			TweenService:Create(
				gainText,
				TweenInfo.new(0.2),
				{
					TextTransparency = 1,
				}
			):Play()
		end)
	end
end

local function onValueChanged(newValue)
	newValue = tonumber(newValue) or getTrainingValue()

	if lastValue == nil then
		lastValue = newValue
		updateMeter(newValue)
		return
	end

	local gain = newValue - lastValue
	lastValue = newValue

	updateMeter(newValue)

	if gain > 0 then
		pulse(gain)
	end
end

local function connectLeaderstat()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	for _, name in ipairs({ "Strength", "KickPower", "Kick Power", "Power" }) do
		local stat = leaderstats:FindFirstChild(name)

		if stat and stat:IsA("ValueBase") then
			stat.Changed:Connect(function()
				onValueChanged(tonumber(stat.Value) or 0)
			end)
		end
	end
end

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		task.wait(0.2)
		connectLeaderstat()
		onValueChanged(getTrainingValue())
	end
end)

for _, attr in ipairs({ "Strength", "KickPower", "Power" }) do
	player:GetAttributeChangedSignal(attr):Connect(function()
		onValueChanged(getTrainingValue())
	end)
end

connectLeaderstat()
onValueChanged(getTrainingValue())

task.spawn(function()
	while true do
		onValueChanged(getTrainingValue())
		task.wait(1)
	end
end)

print("[BetterTrainingFeedback] Loaded vertical kick meter.")