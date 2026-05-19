--!nonstrict
-- StarterPlayerScripts/MoneyPopup.client.lua
-- Clean combined money gain text for HUD feedback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local updateCoinsEvent = ReplicatedStorage:WaitForChild("UpdateCoins")

local GUI_NAME = "MoneyPopupGui"
local MAX_POPUPS_ON_SCREEN = 3
local COMBINE_WINDOW = 0.28

local lastMoney = nil
local activePopups = {}
local pendingGain = 0
local popupQueued = false

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

local function createMoneyPopup(amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then
		return
	end

	removeOldestPopupIfNeeded()

	local popup = Instance.new("Frame")
	popup.Name = "MoneyPopup"
	popup.AnchorPoint = Vector2.new(0, 1)
	popup.BackgroundTransparency = 1
	popup.Position = UDim2.new(0, 154, 1, -92)
	popup.Size = UDim2.fromOffset(150, 34)
	popup.ZIndex = 40
	popup.Parent = popupLayer
	table.insert(activePopups, popup)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.75
	scale.Parent = popup

	local text = Instance.new("TextLabel")
	text.Name = "MoneyText"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.Text = "+$" .. formatMoney(amount)
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(126, 255, 94)
	text.TextStrokeColor3 = Color3.fromRGB(15, 55, 20)
	text.TextStrokeTransparency = 0
	text.ZIndex = 41
	text.Parent = popup

	TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	TweenService:Create(popup, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 154, 1, -126),
	}):Play()

	task.delay(0.55, function()
		if text and text.Parent then
			TweenService:Create(text, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0.82,
			}):Play()
		end
	end)

	task.delay(0.9, function()
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

local function flushPendingGain()
	if popupQueued then
		return
	end

	popupQueued = true
	task.delay(COMBINE_WINDOW, function()
		popupQueued = false
		local amount = pendingGain
		pendingGain = 0
		createMoneyPopup(amount)
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
		pendingGain += gained
		flushPendingGain()
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

print("[MoneyPopup] Loaded clean combined money gain text.")
