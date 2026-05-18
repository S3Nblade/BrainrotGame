--!nonstrict
-- StarterPlayerScripts/MoneyPopup.client.lua
-- Cool money gain popup:
-- random position, tweening text, small dollar bills dropping + fade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local updateCoinsEvent = ReplicatedStorage:WaitForChild("UpdateCoins")

local GUI_NAME = "MoneyPopupGui"

local MAX_POPUPS_ON_SCREEN = 6
local BILL_COUNT_MIN = 5
local BILL_COUNT_MAX = 9

local lastMoney = nil
local activePopups = {}

local function formatMoney(value)
	value = tonumber(value) or 0

	if value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(math.floor(value))
end

local oldGui = playerGui:FindFirstChild(GUI_NAME)
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.Parent = playerGui

local popupLayer = Instance.new("Frame")
popupLayer.Name = "PopupLayer"
popupLayer.BackgroundTransparency = 1
popupLayer.Size = UDim2.fromScale(1, 1)
popupLayer.Parent = screenGui

local function removeOldestPopupIfNeeded()
	while #activePopups >= MAX_POPUPS_ON_SCREEN do
		local oldest = table.remove(activePopups, 1)

		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
end

local function makeDollarBill(parent, startX, startY)
	local bill = Instance.new("Frame")
	bill.Name = "DollarBill"
	bill.AnchorPoint = Vector2.new(0.5, 0.5)
	bill.Position = UDim2.fromScale(startX, startY)
	bill.Size = UDim2.fromOffset(math.random(24, 34), math.random(13, 18))
	bill.Rotation = math.random(-22, 22)
	bill.BackgroundColor3 = Color3.fromRGB(77, 220, 95)
	bill.BorderSizePixel = 0
	bill.ZIndex = 30
	bill.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = bill

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(22, 110, 35)
	stroke.Transparency = 0.15
	stroke.Parent = bill

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.78, 0.58)
	inner.BackgroundTransparency = 1
	inner.BorderSizePixel = 0
	inner.Parent = bill

	local innerStroke = Instance.new("UIStroke")
	innerStroke.Thickness = 1
	innerStroke.Color = Color3.fromRGB(25, 130, 45)
	innerStroke.Transparency = 0.35
	innerStroke.Parent = inner

	local dollar = Instance.new("TextLabel")
	dollar.Name = "Dollar"
	dollar.BackgroundTransparency = 1
	dollar.Size = UDim2.fromScale(1, 1)
	dollar.Font = Enum.Font.FredokaOne
	dollar.Text = "$"
	dollar.TextScaled = true
	dollar.TextColor3 = Color3.fromRGB(240, 255, 235)
	dollar.TextStrokeTransparency = 1
	dollar.ZIndex = 31
	dollar.Parent = bill

	local fallX = startX + math.random(-8, 8) / 100
	local fallY = startY + math.random(8, 16) / 100

	local tween = TweenService:Create(
		bill,
		TweenInfo.new(
			math.random(70, 105) / 100,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),
		{
			Position = UDim2.fromScale(fallX, fallY),
			Rotation = bill.Rotation + math.random(-55, 55),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(8, 5),
		}
	)

	local strokeTween = TweenService:Create(
		stroke,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Transparency = 1,
		}
	)

	local textTween = TweenService:Create(
		dollar,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			TextTransparency = 1,
		}
	)

	tween:Play()
	strokeTween:Play()
	textTween:Play()

	Debris:AddItem(bill, 1.2)
end

local function createMoneyPopup(amount)
	amount = math.floor(tonumber(amount) or 0)

	if amount <= 0 then
		return
	end

	removeOldestPopupIfNeeded()

	local popup = Instance.new("Frame")
	popup.Name = "MoneyPopup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundTransparency = 1
	popup.Size = UDim2.fromOffset(220, 82)
	popup.ZIndex = 20
	popup.Parent = popupLayer

	table.insert(activePopups, popup)

	local randomX = math.random(34, 66) / 100
	local randomY = math.random(30, 58) / 100

	popup.Position = UDim2.fromScale(randomX, randomY)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.55
	scale.Parent = popup

	local glow = Instance.new("TextLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.52)
	glow.Size = UDim2.fromScale(1.05, 0.8)
	glow.Font = Enum.Font.FredokaOne
	glow.Text = "+$" .. formatMoney(amount)
	glow.TextScaled = true
	glow.TextColor3 = Color3.fromRGB(80, 255, 100)
	glow.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	glow.TextStrokeTransparency = 0.25
	glow.TextTransparency = 0.35
	glow.ZIndex = 19
	glow.Parent = popup

	local mainText = Instance.new("TextLabel")
	mainText.Name = "MainText"
	mainText.BackgroundTransparency = 1
	mainText.AnchorPoint = Vector2.new(0.5, 0.5)
	mainText.Position = UDim2.fromScale(0.5, 0.5)
	mainText.Size = UDim2.fromScale(1, 0.75)
	mainText.Font = Enum.Font.FredokaOne
	mainText.Text = "+$" .. formatMoney(amount)
	mainText.TextScaled = true
	mainText.TextColor3 = Color3.fromRGB(120, 255, 100)
	mainText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	mainText.TextStrokeTransparency = 0
	mainText.ZIndex = 21
	mainText.Parent = popup

	local subText = Instance.new("TextLabel")
	subText.Name = "SubText"
	subText.BackgroundTransparency = 1
	subText.AnchorPoint = Vector2.new(0.5, 0.5)
	subText.Position = UDim2.fromScale(0.5, 0.9)
	subText.Size = UDim2.fromScale(0.8, 0.25)
	subText.Font = Enum.Font.FredokaOne
	subText.Text = ""
	subText.Visible = false
	subText.TextScaled = true
	subText.TextColor3 = Color3.fromRGB(255, 245, 150)
	subText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	subText.TextStrokeTransparency = 0.15
	subText.ZIndex = 21
	subText.Parent = popup

	local popIn = TweenService:Create(
		scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Scale = 1,
		}
	)

	local floatUp = TweenService:Create(
		popup,
		TweenInfo.new(1.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.fromScale(randomX + math.random(-3, 3) / 100, randomY - 0.09),
		}
	)

	local textFade = TweenService:Create(
		mainText,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)

	local glowFade = TweenService:Create(
		glow,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)

	local subFade = TweenService:Create(
		subText,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)

	popIn:Play()
	floatUp:Play()

	local billCount = math.random(BILL_COUNT_MIN, BILL_COUNT_MAX)

	for i = 1, billCount do
		task.delay(math.random(0, 16) / 100, function()
			if popup and popup.Parent then
				makeDollarBill(
					popupLayer,
					randomX + math.random(-8, 8) / 100,
					randomY + math.random(-4, 3) / 100
				)
			end
		end)
	end

	task.delay(0.82, function()
		if popup and popup.Parent then
			textFade:Play()
			glowFade:Play()
			subFade:Play()
		end
	end)

	task.delay(1.25, function()
		for index, item in ipairs(activePopups) do
			if item == popup then
				table.remove(activePopups, index)
				break
			end
		end

		if popup and popup.Parent then
			popup:Destroy()
		end
	end)
end

local function onMoneyUpdated(newMoney)
	newMoney = tonumber(newMoney) or 0

	if lastMoney == nil then
		lastMoney = newMoney
		return
	end

	local gained = newMoney - lastMoney
	lastMoney = newMoney

	if gained > 0 then
		createMoneyPopup(gained)
	end
end

updateCoinsEvent.OnClientEvent:Connect(onMoneyUpdated)

local function hookLeaderstats()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local moneyValue =
		leaderstats:FindFirstChild("Money")
		or leaderstats:FindFirstChild("Coins")
		or leaderstats:FindFirstChild("Cash")

	if moneyValue and moneyValue:IsA("ValueBase") then
		if lastMoney == nil then
			lastMoney = tonumber(moneyValue.Value) or 0
		end

		moneyValue:GetPropertyChangedSignal("Value"):Connect(function()
			onMoneyUpdated(moneyValue.Value)
		end)
	end
end

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		task.wait(0.2)
		hookLeaderstats()
	end
end)

task.defer(function()
	task.wait(1)
	hookLeaderstats()
end)

print("[MoneyPopup] Loaded.")