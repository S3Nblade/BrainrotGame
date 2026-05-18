-- StarterPlayerScripts/HUD_StatsBars.client.lua
-- Full replacement
-- Uses GUI.strength and GUI.money icons if available

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiFolder = ReplicatedStorage:WaitForChild("GUI")

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

	local ok, value = pcall(function()
		return asset.Image
	end)

	if ok and typeof(value) == "string" then
		return value
	end

	return ""
end

local strengthImage = extractImage(findChildInsensitive(guiFolder, { "strength", "bolt icon" }))
local moneyImage = extractImage(findChildInsensitive(guiFolder, { "money", "coin icon" }))

local oldGui = playerGui:FindFirstChild("HUD_StatsBarsGui")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD_StatsBarsGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 92
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0, 1)
root.Position = UDim2.new(0, 18, 1, -18)
root.Size = UDim2.fromOffset(470, 120)
root.BackgroundTransparency = 1
root.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.Padding = UDim.new(0, 6)
layout.Parent = root

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

local function createIcon(parent, imageId, fallbackText, size)
	if imageId ~= "" then
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.AnchorPoint = Vector2.new(0, 0.5)
		img.Position = UDim2.new(0, 0, 0.5, 0)
		img.Size = UDim2.fromOffset(size, size)
		img.BackgroundTransparency = 1
		img.Image = imageId
		img.ScaleType = Enum.ScaleType.Fit
		img.ZIndex = 3
		img.Parent = parent
		return img, size
	end

	local txt = Instance.new("TextLabel")
	txt.Name = "Icon"
	txt.AnchorPoint = Vector2.new(0, 0.5)
	txt.Position = UDim2.new(0, 0, 0.5, 0)
	txt.Size = UDim2.fromOffset(size, size)
	txt.BackgroundTransparency = 1
	txt.Text = fallbackText
	txt.TextScaled = true
	txt.Font = Enum.Font.FredokaOne
	txt.TextColor3 = Color3.fromRGB(255, 255, 255)
	txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	txt.TextStrokeTransparency = 0
	txt.ZIndex = 3
	txt.Parent = parent
	return txt, size
end

local function createRow(rowName, imageId, fallbackText, iconSize, maxTextSize, textColor)
	local row = Instance.new("Frame")
	row.Name = rowName
	row.Size = UDim2.fromOffset(470, 52)
	row.BackgroundTransparency = 1
	row.Parent = root

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = row

	local _icon, iconWidth = createIcon(row, imageId, fallbackText, iconSize)

	local text = Instance.new("TextLabel")
	text.Name = "Value"
	text.AnchorPoint = Vector2.new(0, 0.5)
	text.Position = UDim2.new(0, iconWidth + 10, 0.5, 0)
	text.Size = UDim2.new(1, -(iconWidth + 10), 1, 0)
	text.BackgroundTransparency = 1
	text.Text = "0"
	text.TextColor3 = textColor
	text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 5
	text.Parent = row

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxTextSize
	constraint.MinTextSize = 14
	constraint.Parent = text

	return text, scale
end

local strengthLabel, strengthScale = createRow(
	"StrengthRow",
	strengthImage,
	"💪",
	46,
	35,
	Color3.fromRGB(255, 191, 45)
)

local moneyLabel, moneyScale = createRow(
	"MoneyRow",
	moneyImage,
	"$",
	46,
	44,
	Color3.fromRGB(70, 255, 90)
)

local function pop(scaleObject)
	scaleObject.Scale = 1.12
	TweenService:Create(
		scaleObject,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

local function getLeaderstatValue(names)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	for _, name in ipairs(names) do
		local stat = leaderstats:FindFirstChild(name)
		if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue")) then
			return stat.Value
		end
	end

	return nil
end

local function getAttributeValue(names)
	for _, name in ipairs(names) do
		local value = player:GetAttribute(name)
		if typeof(value) == "number" then
			return value
		end
	end

	return nil
end

local function getMoney()
	return getLeaderstatValue({ "Coins", "Money", "Cash" })
		or getAttributeValue({ "Coins", "Money", "Cash" })
		or 0
end

local function getStrength()
	return getLeaderstatValue({ "Strength", "Power", "SpeedPower", "Speed" })
		or getAttributeValue({ "Strength", "Power", "SpeedPower", "Speed" })
		or 0
end

local lastMoneyText = nil
local lastStrengthText = nil

local function updateMoney()
	local text = "$" .. formatNumber(getMoney())
	moneyLabel.Text = text

	if lastMoneyText and lastMoneyText ~= text then
		pop(moneyScale)
	end

	lastMoneyText = text
end

local function updateStrength()
	local text = formatNumber(getStrength()) .. " Strength"
	strengthLabel.Text = text

	if lastStrengthText and lastStrengthText ~= text then
		pop(strengthScale)
	end

	lastStrengthText = text
end

local function updateAll()
	updateMoney()
	updateStrength()
end

local function hookLeaderstats()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local function hookStat(stat)
		if stat:IsA("IntValue") or stat:IsA("NumberValue") then
			stat:GetPropertyChangedSignal("Value"):Connect(updateAll)
			updateAll()
		end
	end

	for _, child in ipairs(leaderstats:GetChildren()) do
		hookStat(child)
	end

	leaderstats.ChildAdded:Connect(hookStat)
end

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		task.wait()
		hookLeaderstats()
		updateAll()
	end
end)

for _, attributeName in ipairs({
	"Coins",
	"Money",
	"Cash",
	"Strength",
	"Power",
	"Speed",
	"SpeedPower",
	}) do
	player:GetAttributeChangedSignal(attributeName):Connect(updateAll)
end

local updateCoinsRemote = ReplicatedStorage:FindFirstChild("UpdateCoins")
if updateCoinsRemote and updateCoinsRemote:IsA("RemoteEvent") then
	updateCoinsRemote.OnClientEvent:Connect(function(newCoins)
		if typeof(newCoins) == "number" then
			moneyLabel.Text = "$" .. formatNumber(newCoins)
			pop(moneyScale)
			lastMoneyText = moneyLabel.Text
		else
			updateMoney()
		end
	end)
end

local updateSpeedStatsRemote = ReplicatedStorage:FindFirstChild("UpdateSpeedStats")
if updateSpeedStatsRemote and updateSpeedStatsRemote:IsA("RemoteEvent") then
	updateSpeedStatsRemote.OnClientEvent:Connect(function(data)
		if type(data) == "table" then
			local value = tonumber(data.strength) or tonumber(data.speedPower)
			if value then
				strengthLabel.Text = formatNumber(value) .. " Strength"
				pop(strengthScale)
				lastStrengthText = strengthLabel.Text
			else
				updateStrength()
			end
		else
			updateStrength()
		end
	end)
end

hookLeaderstats()
updateAll()

print("[HUD_StatsBars] Loaded new strength + money icons")