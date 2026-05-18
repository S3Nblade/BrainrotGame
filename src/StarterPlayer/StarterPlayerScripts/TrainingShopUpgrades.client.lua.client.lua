--!nonstrict
-- TrainingShopUpgrades.client.lua
-- Put in: StarterPlayer > StarterPlayerScripts
-- Replaces the Training tab cards inside CartoonSimulatorHUD with real working weight upgrades.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local buyRemote = ReplicatedStorage:WaitForChild("BuyTrainingWeight")
local updateSpeed = ReplicatedStorage:WaitForChild("UpdateSpeedStats")

local FONT = Enum.Font.FredokaOne

local currentSpeed = 0
local currentTier = "Stone Weight"

local TIERS = {
	{
		name = "Stone Weight",
		icon = "🏋️",
		speedPerTrain = 2,
		requiredSpeed = 0,
		top = Color3.fromRGB(160, 170, 185),
		bottom = Color3.fromRGB(75, 85, 105),
	},
	{
		name = "Iron Weight",
		icon = "💪",
		speedPerTrain = 5,
		requiredSpeed = 250,
		top = Color3.fromRGB(100, 170, 255),
		bottom = Color3.fromRGB(35, 80, 190),
	},
	{
		name = "Golden Weight",
		icon = "👑",
		speedPerTrain = 12,
		requiredSpeed = 1500,
		top = Color3.fromRGB(255, 215, 55),
		bottom = Color3.fromRGB(240, 120, 20),
	},
	{
		name = "Galaxy Weight",
		icon = "⚡",
		speedPerTrain = 30,
		requiredSpeed = 5000,
		top = Color3.fromRGB(190, 80, 255),
		bottom = Color3.fromRGB(75, 30, 170),
	},
}

local function formatNumber(n)
	n = math.floor(tonumber(n) or 0)

	if n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	end

	return tostring(n)
end

local function addCorner(obj, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = obj
	return corner
end

local function addStroke(obj, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0
	stroke.Parent = obj
	return stroke
end

local function addGradient(obj, top, bottom)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	gradient.Rotation = 90
	gradient.Parent = obj
	return gradient
end

local function makeText(parent, name, text, size, pos, textSize, color, z)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = pos
	label.Text = text
	label.Font = FONT
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = z or 1
	label.Parent = parent

	addStroke(label, Color3.fromRGB(0, 0, 0), math.max(2, textSize / 10))

	return label
end

local function makeButton(parent, name, text, pos, size, top, bottom, textSize)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Position = pos
	btn.Size = size
	btn.BackgroundColor3 = top
	btn.BorderSizePixel = 0
	btn.ZIndex = 20
	btn.Parent = parent

	addCorner(btn, 16)
	addStroke(btn, Color3.fromRGB(0, 0, 0), 3)
	addGradient(btn, top, bottom)

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(1, -10, 0.35, 0)
	shine.Position = UDim2.new(0, 5, 0, 5)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.75
	shine.BorderSizePixel = 0
	shine.ZIndex = 21
	shine.Parent = btn
	addCorner(shine, 12)

	makeText(btn, "Label", text, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), textSize or 20, Color3.fromRGB(255, 255, 255), 22)

	return btn
end

local function findTrainingContent()
	local hud = playerGui:FindFirstChild("CartoonSimulatorHUD")
	if not hud then
		return nil
	end

	local shopPopup = hud:FindFirstChild("SHOPPopup")
	if not shopPopup then
		return nil
	end

	local panel = shopPopup:FindFirstChild("Panel")
	if not panel then
		return nil
	end

	local body = panel:FindFirstChild("Body")
	if not body then
		return nil
	end

	local content = body:FindFirstChild("Content")
	if not content then
		return nil
	end

	local hasTrainingCards = false

	for _, child in ipairs(content:GetChildren()) do
		if child.Name == "Stone Weight"
			or child.Name == "Iron Weight"
			or child.Name == "Galaxy Weight"
			or child.Name == "Golden Weight"
		then
			hasTrainingCards = true
			break
		end
	end

	if not hasTrainingCards then
		return nil
	end

	return body, content
end

local function clearContent(content)
	for _, child in ipairs(content:GetChildren()) do
		child:Destroy()
	end
end

local function makeTierCard(parent, tier, order)
	local unlocked = currentSpeed >= tier.requiredSpeed
	local equipped = currentTier == tier.name

	local card = Instance.new("Frame")
	card.Name = tier.name
	card.Size = UDim2.new(0, 158, 0, 160)
	card.BackgroundColor3 = tier.top
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	card.ZIndex = 15
	card.Parent = parent

	addCorner(card, 20)
	addStroke(card, if equipped then Color3.fromRGB(120, 255, 70) else Color3.fromRGB(0, 0, 0), if equipped then 5 else 3)
	addGradient(card, tier.top, tier.bottom)

	local shine = Instance.new("Frame")
	shine.Size = UDim2.new(1, -12, 0, 44)
	shine.Position = UDim2.new(0, 6, 0, 6)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.75
	shine.BorderSizePixel = 0
	shine.ZIndex = 16
	shine.Parent = card
	addCorner(shine, 16)

	makeText(card, "Icon", tier.icon, UDim2.new(1, 0, 0, 45), UDim2.new(0, 0, 0, 8), 34, Color3.fromRGB(255, 255, 255), 17)

	makeText(card, "Name", tier.name, UDim2.new(1, -10, 0, 34), UDim2.new(0, 5, 0, 48), 16, Color3.fromRGB(255, 255, 255), 17)

	makeText(
		card,
		"Power",
		"+" .. tostring(tier.speedPerTrain) .. " SPEED",
		UDim2.new(1, -10, 0, 24),
		UDim2.new(0, 5, 0, 84),
		15,
		Color3.fromRGB(160, 255, 120),
		17
	)

	local buttonText = ""
	local buttonTop = Color3.fromRGB(105, 245, 45)
	local buttonBottom = Color3.fromRGB(35, 165, 20)

	if equipped then
		buttonText = "EQUIPPED"
		buttonTop = Color3.fromRGB(80, 210, 255)
		buttonBottom = Color3.fromRGB(20, 105, 210)
	elseif unlocked then
		buttonText = "EQUIP"
	else
		buttonText = "NEED " .. formatNumber(tier.requiredSpeed)
		buttonTop = Color3.fromRGB(255, 190, 45)
		buttonBottom = Color3.fromRGB(220, 90, 20)
	end

	local btn = makeButton(
		card,
		"Buy",
		buttonText,
		UDim2.new(0.5, -60, 1, -42),
		UDim2.new(0, 120, 0, 34),
		buttonTop,
		buttonBottom,
		15
	)

	btn.Activated:Connect(function()
		buyRemote:FireServer(tier.name)
	end)
end

local lastPatchedBody = nil

local function patchTrainingShop()
	local body, content = findTrainingContent()

	if not body or not content then
		return
	end

	if body:GetAttribute("RealTrainingShopPatched") == true then
		return
	end

	body:SetAttribute("RealTrainingShopPatched", true)
	lastPatchedBody = body

	clearContent(content)

	content.Size = UDim2.new(1, 0, 1, -68)
	content.Position = UDim2.new(0, 0, 0, 68)
	content.BackgroundTransparency = 1

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 158, 0, 160)
	grid.CellPadding = UDim2.new(0, 12, 0, 12)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content

	for i, tier in ipairs(TIERS) do
		makeTierCard(content, tier, i)
	end
end

updateSpeed.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end

	currentSpeed = tonumber(data.speedPower) or currentSpeed
	currentTier = tostring(data.trainingTier or currentTier)

	if lastPatchedBody and lastPatchedBody.Parent then
		lastPatchedBody:SetAttribute("RealTrainingShopPatched", false)
	end

	task.delay(0.05, patchTrainingShop)
end)

player:GetAttributeChangedSignal("SpeedPower"):Connect(function()
	currentSpeed = tonumber(player:GetAttribute("SpeedPower")) or currentSpeed

	if lastPatchedBody and lastPatchedBody.Parent then
		lastPatchedBody:SetAttribute("RealTrainingShopPatched", false)
	end

	task.delay(0.05, patchTrainingShop)
end)

player:GetAttributeChangedSignal("TrainingTier"):Connect(function()
	currentTier = tostring(player:GetAttribute("TrainingTier") or currentTier)

	if lastPatchedBody and lastPatchedBody.Parent then
		lastPatchedBody:SetAttribute("RealTrainingShopPatched", false)
	end

	task.delay(0.05, patchTrainingShop)
end)

task.spawn(function()
	while true do
		patchTrainingShop()
		task.wait(0.25)
	end
end)

print("[TrainingShopUpgrades] loaded")