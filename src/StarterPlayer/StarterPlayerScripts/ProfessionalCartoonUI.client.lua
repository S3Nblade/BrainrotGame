--!nonstrict
-- ProfessionalCartoonUI.client.lua
-- Unified cartoon UI layer for core game screens, toasts, and broad GUI polish.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FONT = Enum.Font.FredokaOne

local THEME = {
	Ink = Color3.fromRGB(18, 20, 34),
	InkSoft = Color3.fromRGB(46, 53, 80),
	Cream = Color3.fromRGB(255, 247, 218),
	PanelTop = Color3.fromRGB(63, 207, 255),
	PanelBottom = Color3.fromRGB(33, 108, 230),
	PanelDeep = Color3.fromRGB(28, 42, 92),
	Gold = Color3.fromRGB(255, 211, 67),
	GoldDeep = Color3.fromRGB(229, 121, 30),
	Green = Color3.fromRGB(93, 237, 91),
	GreenDeep = Color3.fromRGB(34, 150, 67),
	Pink = Color3.fromRGB(255, 92, 174),
	Purple = Color3.fromRGB(146, 102, 255),
	Red = Color3.fromRGB(255, 85, 85),
	Locked = Color3.fromRGB(114, 126, 148),
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(235, 239, 245),
	Rare = Color3.fromRGB(78, 172, 255),
	Epic = Color3.fromRGB(205, 94, 255),
	Mythic = Color3.fromRGB(255, 77, 171),
	Legendary = Color3.fromRGB(255, 204, 60),
	Divine = Color3.fromRGB(70, 238, 255),
	Celestial = Color3.fromRGB(167, 132, 255),
	Godly = Color3.fromRGB(255, 78, 78),
}

local INDEX_NPCS = {
	{ zone = "Starter", name = "Poppi Plazito", rarity = "Common" },
	{ zone = "Starter", name = "Bello Bouncini", rarity = "Rare" },
	{ zone = "Starter", name = "Jumbo Jellino", rarity = "Epic" },
	{ zone = "Forest", name = "Mossito Bambino", rarity = "Rare" },
	{ zone = "Forest", name = "Vinecap Troppi", rarity = "Epic" },
	{ zone = "Forest", name = "Oakleaf Orbitini", rarity = "Mythic" },
	{ zone = "Desert", name = "Sandy Sahurino", rarity = "Common" },
	{ zone = "Desert", name = "Cactus Calabro", rarity = "Rare" },
	{ zone = "Desert", name = "Dune Dancerino", rarity = "Epic" },
	{ zone = "Desert", name = "Mirage Munchini", rarity = "Mythic" },
	{ zone = "Crystal", name = "Prisma Puffino", rarity = "Epic" },
	{ zone = "Crystal", name = "Quartz Quirkini", rarity = "Mythic" },
	{ zone = "Crystal", name = "Shardino Splendito", rarity = "Legendary" },
	{ zone = "Lava", name = "Magma Munchino", rarity = "Mythic" },
	{ zone = "Lava", name = "Ember Bambino", rarity = "Legendary" },
	{ zone = "Lava", name = "Cinder Crownini", rarity = "Divine" },
	{ zone = "Galaxy", name = "Nebula Nino", rarity = "Legendary" },
	{ zone = "Galaxy", name = "Orbitto Maximo", rarity = "Divine" },
	{ zone = "Galaxy", name = "Cosmo Spaghettini", rarity = "Celestial" },
	{ zone = "Galaxy", name = "Starlord Bambini", rarity = "Godly" },
}

local currentMode = "Shop"
local currentShopTab = "Upgrades"
local isOpen = false
local latestUpgradePayload = nil
local latestRebirthPayload = nil
local seenNpcs = {}
local toastCounter = 0

local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
local notifyRemote = ReplicatedStorage:FindFirstChild("NotifyUser")
local requestUpgradeRemote = ReplicatedStorage:FindFirstChild("RequestUpgrade")
local updateUpgradesRemote = ReplicatedStorage:FindFirstChild("UpdateUpgrades")
local rebirthRequestRemote = remotesFolder and remotesFolder:FindFirstChild("RebirthRequest")
local rebirthUpdateRemote = remotesFolder and remotesFolder:FindFirstChild("RebirthUpdate")
local rebirthGetStateRemote = remotesFolder and remotesFolder:FindFirstChild("RebirthGetState")

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

local function getStat(names)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats then
		for _, name in ipairs(names) do
			local stat = leaderstats:FindFirstChild(name)
			if stat and stat:IsA("ValueBase") then
				return tonumber(stat.Value) or 0
			end
		end
	end

	for _, name in ipairs(names) do
		local attr = player:GetAttribute(name)
		if typeof(attr) == "number" then
			return attr
		end
	end

	return 0
end

local function tween(instance, duration, props, style, direction)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function addCorner(parent, radius)
	local corner = parent:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = color or THEME.Ink
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function addGradient(parent, top, bottom, rotation)
	local gradient = parent:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

local function getLuminance(color)
	return (color.R * 0.299) + (color.G * 0.587) + (color.B * 0.114)
end

local function addTextStroke(label, thickness)
	local stroke = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = THEME.Ink
	stroke.Thickness = thickness or 2
	stroke.Transparency = getLuminance(label.TextColor3) > 0.55 and 0.05 or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	return stroke
end

local function constrainText(label, maxSize, minSize)
	local constraint = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxSize or 26
	constraint.MinTextSize = minSize or 10
	constraint.Parent = label
	return constraint
end

local function makeLabel(parent, name, text, size, position, maxSize, color, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position or UDim2.fromScale(0, 0)
	label.Font = FONT
	label.Text = text or ""
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zIndex or 1
	label.Parent = parent
	addTextStroke(label, 2)
	constrainText(label, maxSize or 24, 9)
	return label
end

local function makePanel(parent, name, colorTop, colorBottom, radius, zIndex)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = colorTop
	frame.BorderSizePixel = 0
	frame.ZIndex = zIndex or 1
	frame.Parent = parent
	addCorner(frame, radius or 18)
	addStroke(frame, THEME.Ink, 3)
	addGradient(frame, colorTop, colorBottom or colorTop)

	local shine = Instance.new("Frame")
	shine.Name = "TopShine"
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.78
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 8, 0, 7)
	shine.Size = UDim2.new(1, -16, 0, 18)
	shine.ZIndex = (zIndex or 1) + 1
	shine.Parent = frame
	addCorner(shine, radius and math.max(8, radius - 4) or 14)

	return frame
end

local function makeButton(parent, name, text, colorTop, colorBottom, zIndex)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.AutoButtonColor = false
	button.BackgroundColor3 = colorTop
	button.BorderSizePixel = 0
	button.Font = FONT
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.TextWrapped = true
	button.ZIndex = zIndex or 10
	button.Parent = parent
	addCorner(button, 16)
	addStroke(button, THEME.Ink, 3)
	addGradient(button, colorTop, colorBottom)
	addTextStroke(button, 2)
	constrainText(button, 22, 10)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	button.MouseEnter:Connect(function()
		tween(scale, 0.12, { Scale = 1.05 }, Enum.EasingStyle.Back)
	end)

	button.MouseLeave:Connect(function()
		tween(scale, 0.10, { Scale = 1 })
	end)

	button.MouseButton1Down:Connect(function()
		tween(scale, 0.06, { Scale = 0.94 })
	end)

	button.MouseButton1Up:Connect(function()
		tween(scale, 0.10, { Scale = 1 }, Enum.EasingStyle.Back)
	end)

	return button
end

local screenGui = playerGui:FindFirstChild("BrainrotProfessionalUI")
if screenGui then
	screenGui:Destroy()
end

screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotProfessionalUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 950
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Text = ""
dim.AutoButtonColor = false
dim.BackgroundColor3 = Color3.fromRGB(5, 9, 18)
dim.BackgroundTransparency = 1
dim.BorderSizePixel = 0
dim.Size = UDim2.fromScale(1, 1)
dim.Visible = false
dim.ZIndex = 1
dim.Parent = screenGui

local modal = makePanel(screenGui, "Modal", THEME.PanelTop, THEME.PanelBottom, 26, 20)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(840, 560)
modal.Visible = false
modal.ClipsDescendants = true

local modalScale = Instance.new("UIScale")
modalScale.Scale = 0.82
modalScale.Parent = modal

local function getModalFitScale()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local fitX = (viewport.X - 32) / 840
	local fitY = (viewport.Y - 32) / 560
	return math.clamp(math.min(fitX, fitY), 0.34, 1)
end

local function setModalScale(multiplier)
	modalScale.Scale = getModalFitScale() * (multiplier or 1)
end

local title = makeLabel(
	modal,
	"Title",
	"SHOP",
	UDim2.new(1, -170, 0, 58),
	UDim2.new(0, 24, 0, 18),
	42,
	THEME.Cream,
	24
)
title.TextXAlignment = Enum.TextXAlignment.Left

local subtitle = makeLabel(
	modal,
	"Subtitle",
	"Upgrade your run.",
	UDim2.new(1, -190, 0, 28),
	UDim2.new(0, 28, 0, 70),
	18,
	Color3.fromRGB(214, 246, 255),
	24
)
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local closeButton = makeButton(modal, "Close", "X", THEME.Red, Color3.fromRGB(196, 35, 58), 30)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -20, 0, 20)
closeButton.Size = UDim2.fromOffset(50, 50)

local tabRail = Instance.new("Frame")
tabRail.Name = "TabRail"
tabRail.BackgroundTransparency = 1
tabRail.Position = UDim2.new(0, 22, 0, 112)
tabRail.Size = UDim2.new(0, 162, 1, -132)
tabRail.ZIndex = 23
tabRail.Parent = modal

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Vertical
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Padding = UDim.new(0, 12)
tabLayout.Parent = tabRail

local body = makePanel(modal, "Body", Color3.fromRGB(255, 249, 224), Color3.fromRGB(255, 224, 156), 22, 23)
body.Position = UDim2.new(0, 202, 0, 112)
body.Size = UDim2.new(1, -226, 1, -134)
body.ClipsDescendants = true

local bodyPad = Instance.new("UIPadding")
bodyPad.PaddingTop = UDim.new(0, 18)
bodyPad.PaddingBottom = UDim.new(0, 18)
bodyPad.PaddingLeft = UDim.new(0, 18)
bodyPad.PaddingRight = UDim.new(0, 18)
bodyPad.Parent = body

local toastHolder = Instance.new("Frame")
toastHolder.Name = "ToastHolder"
toastHolder.AnchorPoint = Vector2.new(1, 0)
toastHolder.Position = UDim2.new(1, -18, 0, 18)
toastHolder.Size = UDim2.fromOffset(360, 420)
toastHolder.BackgroundTransparency = 1
toastHolder.ZIndex = 1000
toastHolder.Parent = screenGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.FillDirection = Enum.FillDirection.Vertical
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Top
toastLayout.Padding = UDim.new(0, 10)
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Parent = toastHolder

local tabButtons = {}

local function clearBody()
	for _, child in ipairs(body:GetChildren()) do
		if not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke") and not child:IsA("UIGradient") then
			child:Destroy()
		end
	end
end

local function requestUpgradeRefresh()
	if requestUpgradeRemote and requestUpgradeRemote:IsA("RemoteEvent") then
		requestUpgradeRemote:FireServer("_Refresh")
	end
end

local function requestRebirthState()
	if rebirthGetStateRemote and rebirthGetStateRemote:IsA("RemoteFunction") then
		local ok, result = pcall(function()
			return rebirthGetStateRemote:InvokeServer()
		end)

		if ok and type(result) == "table" then
			latestRebirthPayload = result
		end
	end
end

local function getUpgradeCards()
	if latestUpgradePayload and type(latestUpgradePayload.upgrades) == "table" then
		return latestUpgradePayload.upgrades
	end

	return {
		{
			key = "TrainingPower",
			title = "Training Power",
			desc = "More strength every training hit.",
			level = 0,
			maxLevel = 5,
			nextRequirement = 250,
			canUpgrade = getStat({ "Strength", "Power", "SpeedPower", "Speed" }) >= 250,
			maxed = false,
		},
		{
			key = "AutoTrainRate",
			title = "Auto Train Rate",
			desc = "Auto training ticks faster.",
			level = 0,
			maxLevel = 5,
			nextRequirement = 500,
			canUpgrade = getStat({ "Strength", "Power", "SpeedPower", "Speed" }) >= 500,
			maxed = false,
		},
	}
end

local function makeStatPill(parent, labelText, valueText, color, order)
	local pill = makePanel(parent, "StatPill", color, color:Lerp(THEME.Ink, 0.25), 16, 30)
	pill.LayoutOrder = order
	pill.Size = UDim2.new(0, 174, 0, 58)

	local label = makeLabel(
		pill,
		"Label",
		string.upper(labelText),
		UDim2.new(1, -20, 0, 18),
		UDim2.new(0, 10, 0, 8),
		13,
		Color3.fromRGB(255, 250, 215),
		32
	)
	label.TextXAlignment = Enum.TextXAlignment.Center

	local value = makeLabel(
		pill,
		"Value",
		valueText,
		UDim2.new(1, -20, 0, 28),
		UDim2.new(0, 10, 0, 24),
		22,
		Color3.fromRGB(255, 255, 255),
		32
	)
	value.TextXAlignment = Enum.TextXAlignment.Center

	return pill
end

local function makeUpgradeCard(parent, data, order)
	local maxed = data.maxed == true
	local canUpgrade = data.canUpgrade == true
	local level = tonumber(data.level) or 0
	local maxLevel = tonumber(data.maxLevel) or 5
	local levelRatio = math.clamp(level / math.max(maxLevel, 1), 0, 1)
	local accentTop = maxed and Color3.fromRGB(130, 225, 255) or (canUpgrade and THEME.Green or THEME.Gold)
	local accentBottom = maxed and Color3.fromRGB(56, 122, 222) or (canUpgrade and THEME.GreenDeep or THEME.GoldDeep)

	local card = makePanel(parent, tostring(data.key or data.title), Color3.fromRGB(255, 248, 219), Color3.fromRGB(255, 223, 150), 20, 30)
	card.LayoutOrder = order
	card.Size = UDim2.new(0, 255, 0, 190)

	local accent = Instance.new("Frame")
	accent.Name = "StatusAccent"
	accent.BackgroundColor3 = accentTop
	accent.BorderSizePixel = 0
	accent.Position = UDim2.new(0, 0, 0, 0)
	accent.Size = UDim2.new(1, 0, 0, 12)
	accent.ZIndex = 34
	accent.Parent = card
	addGradient(accent, accentTop, accentBottom, 0)

	local statusText = maxed and "MAX" or (canUpgrade and "READY" or "LOCKED")
	local status = makePanel(card, "Status", accentTop, accentBottom, 12, 34)
	status.Position = UDim2.new(1, -82, 0, 20)
	status.Size = UDim2.fromOffset(70, 26)
	makeLabel(status, "Text", statusText, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 13, Color3.fromRGB(255, 255, 255), 36)

	local name = makeLabel(card, "Name", tostring(data.title or "Upgrade"), UDim2.new(1, -100, 0, 36), UDim2.new(0, 12, 0, 20), 23, THEME.InkSoft, 34)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local desc = makeLabel(card, "Description", tostring(data.desc or ""), UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 0, 58), 16, Color3.fromRGB(82, 74, 70), 34)
	desc.TextXAlignment = Enum.TextXAlignment.Left

	local levelText = makeLabel(
		card,
		"Level",
		"Level " .. tostring(level) .. " / " .. tostring(maxLevel),
		UDim2.new(1, -24, 0, 24),
		UDim2.new(0, 12, 0, 104),
		17,
		THEME.InkSoft,
		34
	)
	levelText.TextXAlignment = Enum.TextXAlignment.Left

	local track = Instance.new("Frame")
	track.Name = "LevelTrack"
	track.BackgroundColor3 = Color3.fromRGB(55, 62, 82)
	track.BorderSizePixel = 0
	track.Position = UDim2.new(0, 12, 0, 132)
	track.Size = UDim2.new(1, -24, 0, 12)
	track.ZIndex = 34
	track.Parent = card
	addCorner(track, 8)

	local fill = Instance.new("Frame")
	fill.Name = "LevelFill"
	fill.BackgroundColor3 = accentTop
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(levelRatio, 1)
	fill.ZIndex = 35
	fill.Parent = track
	addCorner(fill, 8)
	addGradient(fill, accentTop, accentBottom, 0)

	local buttonText
	local buttonTop
	local buttonBottom

	if maxed then
		buttonText = "MAXED"
		buttonTop = Color3.fromRGB(95, 205, 255)
		buttonBottom = Color3.fromRGB(25, 112, 205)
	elseif canUpgrade then
		buttonText = "UPGRADE"
		buttonTop = THEME.Green
		buttonBottom = THEME.GreenDeep
	else
		buttonText = "NEED " .. formatNumber(data.nextRequirement or 0)
		buttonTop = Color3.fromRGB(255, 225, 94)
		buttonBottom = Color3.fromRGB(232, 125, 37)
	end

	local button = makeButton(card, "UpgradeButton", buttonText, buttonTop, buttonBottom, 36)
	button.Position = UDim2.new(0, 16, 1, -48)
	button.Size = UDim2.new(1, -32, 0, 38)
	button.Active = not maxed

	button.Activated:Connect(function()
		if maxed then
			return
		end

		if requestUpgradeRemote and requestUpgradeRemote:IsA("RemoteEvent") then
			requestUpgradeRemote:FireServer(tostring(data.key or ""))
			task.delay(0.2, requestUpgradeRefresh)
		else
			_G.BrainrotProUI.Notify("Upgrade service is not ready yet.", "warning")
		end
	end)
end

local function renderShop()
	clearBody()
	title.Text = "SHOP"
	subtitle.Text = "Upgrade training, speed, and earning power."

	local statRow = Instance.new("Frame")
	statRow.Name = "StatRow"
	statRow.BackgroundTransparency = 1
	statRow.Size = UDim2.new(1, 0, 0, 62)
	statRow.ZIndex = 28
	statRow.Parent = body

	local statLayout = Instance.new("UIListLayout")
	statLayout.FillDirection = Enum.FillDirection.Horizontal
	statLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	statLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statLayout.Padding = UDim.new(0, 10)
	statLayout.Parent = statRow

	makeStatPill(statRow, "Money", "$" .. formatNumber(getStat({ "Money", "Coins", "Cash" })), THEME.Green, 1)
	makeStatPill(statRow, "Strength", formatNumber(getStat({ "Strength", "Power", "SpeedPower", "Speed" })) .. " STR", THEME.Gold, 2)
	makeStatPill(statRow, "Multiplier", "x" .. tostring(player:GetAttribute("MoneyMultiplier") or 1), THEME.Purple, 3)

	local tabRow = Instance.new("Frame")
	tabRow.Name = "ShopTabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Position = UDim2.new(0, 0, 0, 72)
	tabRow.Size = UDim2.new(1, 0, 0, 42)
	tabRow.ZIndex = 28
	tabRow.Parent = body

	local shopTabLayout = Instance.new("UIListLayout")
	shopTabLayout.FillDirection = Enum.FillDirection.Horizontal
	shopTabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	shopTabLayout.Padding = UDim.new(0, 10)
	shopTabLayout.Parent = tabRow

	for _, tabName in ipairs({ "Upgrades", "Boosts" }) do
		local active = currentShopTab == tabName
		local tab = makeButton(
			tabRow,
			tabName .. "Tab",
			tabName,
			active and THEME.Pink or Color3.fromRGB(96, 149, 235),
			active and Color3.fromRGB(202, 53, 132) or Color3.fromRGB(38, 82, 175),
			30
		)
		tab.Size = UDim2.fromOffset(136, 38)
		tab.Activated:Connect(function()
			currentShopTab = tabName
			renderShop()
		end)
	end

	local content = Instance.new("ScrollingFrame")
	content.Name = "ShopContent"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.new(0, 0, 0, 126)
	content.Size = UDim2.new(1, 0, 1, -126)
	content.CanvasSize = UDim2.fromOffset(0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollBarThickness = 6
	content.ZIndex = 28
	content.Parent = body

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(255, 190)
	grid.CellPadding = UDim2.fromOffset(14, 14)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = content

	if currentShopTab == "Upgrades" then
		for index, upgradeData in ipairs(getUpgradeCards()) do
			makeUpgradeCard(content, upgradeData, index)
		end
	else
		local boostData = {
			{
				title = "Lucky Finds",
				desc = "Higher rarity Brainrots during events.",
				button = "COMING SOON",
				top = THEME.Purple,
				bottom = Color3.fromRGB(75, 50, 180),
			},
			{
				title = "Money Surge",
				desc = "Stack with rebirths for bigger plot income.",
				button = "EVENT BOOST",
				top = THEME.Green,
				bottom = THEME.GreenDeep,
			},
			{
				title = "Auto Collect",
				desc = "Use the auto collect button when your plot starts earning.",
				button = "UTILITY",
				top = THEME.Gold,
				bottom = THEME.GoldDeep,
			},
		}

		for index, item in ipairs(boostData) do
			local card = makePanel(content, item.title, item.top, item.bottom, 20, 30)
			card.LayoutOrder = index
			card.Size = UDim2.fromOffset(255, 175)
			local name = makeLabel(card, "Name", item.title, UDim2.new(1, -20, 0, 38), UDim2.new(0, 10, 0, 18), 24, Color3.fromRGB(255, 255, 255), 34)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local desc = makeLabel(card, "Desc", item.desc, UDim2.new(1, -20, 0, 66), UDim2.new(0, 10, 0, 61), 17, Color3.fromRGB(255, 252, 225), 34)
			desc.TextXAlignment = Enum.TextXAlignment.Left
			local pill = makeButton(card, "State", item.button, Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 235, 255), 36)
			pill.TextColor3 = THEME.Ink
			pill.Position = UDim2.new(0, 16, 1, -52)
			pill.Size = UDim2.new(1, -32, 0, 38)
		end
	end
end

local function scanSeenNpcs()
	local function markSeenFromInstance(instance)
		local name = tostring(instance:GetAttribute("DisplayName") or instance:GetAttribute("BrainrotName") or instance.Name)
		if name ~= "" then
			seenNpcs[name] = true
		end
	end

	local npcFolder = Workspace:FindFirstChild("BrainrotNPCs")

	if npcFolder then
		for _, npc in ipairs(npcFolder:GetChildren()) do
			if npc:IsA("Model") then
				markSeenFromInstance(npc)
			end
		end
	end

	for _, container in ipairs({
		player:FindFirstChild("Backpack"),
		player.Character,
		player:FindFirstChild("StarterGear"),
	}) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and (child:GetAttribute("BrainrotTool") == true or child:GetAttribute("InventoryOnly") == true) then
					markSeenFromInstance(child)
				end
			end
		end
	end
end

local function renderIndex()
	clearBody()
	scanSeenNpcs()
	title.Text = "INDEX"
	subtitle.Text = "Track the Brainrots you have discovered by zone."

	local discovered = 0
	for _, item in ipairs(INDEX_NPCS) do
		if seenNpcs[item.name] then
			discovered += 1
		end
	end

	local progress = makePanel(body, "IndexProgress", THEME.Purple, Color3.fromRGB(74, 54, 190), 18, 28)
	progress.Size = UDim2.new(1, 0, 0, 64)

	local progressText = makeLabel(
		progress,
		"Text",
		tostring(discovered) .. " / " .. tostring(#INDEX_NPCS) .. " DISCOVERED",
		UDim2.new(1, -24, 1, 0),
		UDim2.new(0, 12, 0, 0),
		26,
		Color3.fromRGB(255, 255, 255),
		32
	)
	progressText.TextXAlignment = Enum.TextXAlignment.Left

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "IndexGrid"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, 0, 0, 78)
	scroll.Size = UDim2.new(1, 0, 1, -78)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.ZIndex = 28
	scroll.Parent = body

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(178, 132)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	for index, item in ipairs(INDEX_NPCS) do
		local found = seenNpcs[item.name] == true
		local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
		local card = makePanel(
			scroll,
			item.name,
			found and rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.2) or THEME.Locked,
			found and rarityColor:Lerp(THEME.Ink, 0.32) or Color3.fromRGB(72, 82, 105),
			18,
			30
		)
		card.LayoutOrder = index
		card.Size = UDim2.fromOffset(178, 132)

		local silhouette = makePanel(card, "Silhouette", found and THEME.Cream or Color3.fromRGB(45, 51, 67), found and Color3.fromRGB(255, 230, 160) or Color3.fromRGB(26, 31, 45), 16, 32)
		silhouette.Position = UDim2.new(0, 12, 0, 12)
		silhouette.Size = UDim2.fromOffset(52, 52)

		local icon = makeLabel(silhouette, "Icon", found and "NPC" or "?", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 18, found and rarityColor or Color3.fromRGB(180, 190, 210), 34)
		icon.TextStrokeTransparency = 0.15

		local name = makeLabel(card, "Name", found and item.name or "Unknown", UDim2.new(1, -78, 0, 40), UDim2.new(0, 72, 0, 15), 18, Color3.fromRGB(255, 255, 255), 34)
		name.TextXAlignment = Enum.TextXAlignment.Left

		local zone = makeLabel(card, "Zone", item.zone, UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 72), 15, Color3.fromRGB(255, 250, 210), 34)
		zone.TextXAlignment = Enum.TextXAlignment.Left

		local rarity = makeLabel(card, "Rarity", found and item.rarity or "Locked", UDim2.new(1, -24, 0, 24), UDim2.new(0, 12, 0, 98), 15, found and rarityColor or Color3.fromRGB(210, 218, 232), 34)
		rarity.TextXAlignment = Enum.TextXAlignment.Left
	end
end

local function makeProgressBar(parent, ratio)
	local bar = makePanel(parent, "ProgressBar", Color3.fromRGB(45, 57, 91), Color3.fromRGB(22, 28, 47), 16, 30)
	bar.Size = UDim2.new(1, 0, 0, 36)
	bar.ClipsDescendants = true

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = THEME.Green
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
	fill.ZIndex = 34
	fill.Parent = bar
	addCorner(fill, 14)
	addGradient(fill, Color3.fromRGB(136, 255, 92), Color3.fromRGB(38, 192, 86))

	return bar, fill
end

local function renderRebirth()
	clearBody()
	requestRebirthState()

	local state = latestRebirthPayload or {
		rebirths = tonumber(player:GetAttribute("Rebirths")) or 0,
		strength = getStat({ "Strength", "Power", "SpeedPower", "Speed" }),
		requirement = tonumber(player:GetAttribute("NextRebirthStrengthRequirement")) or 1000,
		progress = 0,
		moneyMultiplier = tonumber(player:GetAttribute("MoneyMultiplier")) or 1,
		nextMoneyMultiplier = (tonumber(player:GetAttribute("MoneyMultiplier")) or 1) * 2,
		canRebirth = false,
	}

	local strength = tonumber(state.strength) or 0
	local requirement = tonumber(state.requirement) or 1000
	local progressRatio = math.clamp(tonumber(state.progress) or (strength / math.max(requirement, 1)), 0, 1)
	local canRebirth = state.canRebirth == true

	title.Text = "REBIRTH"
	subtitle.Text = "Reset strength for a permanent money multiplier."

	local hero = makePanel(body, "RebirthHero", THEME.Pink, Color3.fromRGB(190, 42, 119), 22, 30)
	hero.Size = UDim2.new(1, 0, 0, 152)

	local count = makeLabel(
		hero,
		"Count",
		tostring(state.rebirths or 0),
		UDim2.fromOffset(120, 94),
		UDim2.new(0, 18, 0, 30),
		64,
		THEME.Cream,
		34
	)

	local countLabel = makeLabel(hero, "CountLabel", "REBIRTHS", UDim2.fromOffset(120, 28), UDim2.new(0, 18, 0, 102), 18, Color3.fromRGB(255, 232, 245), 34)

	local benefit = makeLabel(
		hero,
		"Benefit",
		"x" .. tostring(state.moneyMultiplier or 1) .. " -> x" .. tostring(state.nextMoneyMultiplier or 2) .. " MONEY",
		UDim2.new(1, -170, 0, 50),
		UDim2.new(0, 152, 0, 38),
		34,
		Color3.fromRGB(255, 255, 255),
		34
	)
	benefit.TextXAlignment = Enum.TextXAlignment.Left

	local desc = makeLabel(
		hero,
		"Desc",
		"Every rebirth doubles Brainrot plot income.",
		UDim2.new(1, -170, 0, 34),
		UDim2.new(0, 154, 0, 92),
		20,
		Color3.fromRGB(255, 236, 245),
		34
	)
	desc.TextXAlignment = Enum.TextXAlignment.Left

	local progressPanel = makePanel(body, "ProgressPanel", Color3.fromRGB(91, 175, 255), Color3.fromRGB(37, 93, 210), 22, 30)
	progressPanel.Position = UDim2.new(0, 0, 0, 168)
	progressPanel.Size = UDim2.new(1, 0, 0, 120)

	local progressText = makeLabel(
		progressPanel,
		"ProgressText",
		formatNumber(strength) .. " / " .. formatNumber(requirement) .. " STRENGTH",
		UDim2.new(1, -28, 0, 34),
		UDim2.new(0, 14, 0, 16),
		24,
		Color3.fromRGB(255, 255, 255),
		34
	)
	progressText.TextXAlignment = Enum.TextXAlignment.Left

	local barHolder = Instance.new("Frame")
	barHolder.Name = "BarHolder"
	barHolder.BackgroundTransparency = 1
	barHolder.Position = UDim2.new(0, 14, 0, 66)
	barHolder.Size = UDim2.new(1, -28, 0, 36)
	barHolder.ZIndex = 34
	barHolder.Parent = progressPanel
	makeProgressBar(barHolder, progressRatio)

	local action = makeButton(
		body,
		"RebirthAction",
		canRebirth and "REBIRTH NOW" or "LOCKED",
		canRebirth and THEME.Green or THEME.Locked,
		canRebirth and THEME.GreenDeep or Color3.fromRGB(71, 82, 105),
		34
	)
	action.AnchorPoint = Vector2.new(0.5, 1)
	action.Position = UDim2.new(0.5, 0, 1, 0)
	action.Size = UDim2.new(0, 270, 0, 58)
	action.Activated:Connect(function()
		if rebirthRequestRemote and rebirthRequestRemote:IsA("RemoteEvent") then
			rebirthRequestRemote:FireServer()
			task.delay(0.25, function()
				requestRebirthState()
				renderRebirth()
			end)
		else
			_G.BrainrotProUI.Notify("Rebirth service is not ready yet.", "warning")
		end
	end)
end

local function renderTabs()
	for _, tab in pairs(tabButtons) do
		if tab and tab.Parent then
			tab:Destroy()
		end
	end

	table.clear(tabButtons)

	for order, mode in ipairs({ "Shop", "Index", "Rebirth" }) do
		local active = currentMode == mode
		local button = makeButton(
			tabRail,
			mode .. "Tab",
			mode,
			active and THEME.Gold or Color3.fromRGB(76, 137, 230),
			active and THEME.GoldDeep or Color3.fromRGB(32, 75, 178),
			26
		)
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(148, 56)
		button.Activated:Connect(function()
			currentMode = mode
			if mode == "Shop" then
				requestUpgradeRefresh()
				renderShop()
			elseif mode == "Index" then
				renderIndex()
			else
				renderRebirth()
			end
			renderTabs()
		end)
		tabButtons[mode] = button
	end
end

local function renderCurrent()
	renderTabs()

	if currentMode == "Shop" then
		requestUpgradeRefresh()
		renderShop()
	elseif currentMode == "Index" then
		renderIndex()
	else
		renderRebirth()
	end
end

local function openModal(mode)
	currentMode = mode or currentMode or "Shop"
	isOpen = true
	renderCurrent()

	dim.Visible = true
	modal.Visible = true
	dim.BackgroundTransparency = 1
	setModalScale(0.78)

	tween(dim, 0.14, { BackgroundTransparency = 0.38 })
	tween(modalScale, 0.2, { Scale = getModalFitScale() }, Enum.EasingStyle.Back)

	local rebirthGui = playerGui:FindFirstChild("RebirthGui")
	local oldOpen = rebirthGui and rebirthGui:FindFirstChild("OpenRebirthButton", true)
	if oldOpen and oldOpen:IsA("GuiObject") then
		oldOpen.Visible = false
	end
end

local function closeModal()
	if not isOpen then
		return
	end

	isOpen = false
	tween(dim, 0.14, { BackgroundTransparency = 1 })
	tween(modalScale, 0.14, { Scale = getModalFitScale() * 0.78 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	task.delay(0.16, function()
		if not isOpen then
			dim.Visible = false
			modal.Visible = false
		end
	end)
end

local function pushToast(message, variant)
	toastCounter += 1

	local colors = {
		success = { THEME.Green, THEME.GreenDeep },
		warning = { THEME.Gold, THEME.GoldDeep },
		error = { THEME.Red, Color3.fromRGB(176, 35, 54) },
		info = { THEME.PanelTop, THEME.PanelBottom },
	}

	local pair = colors[tostring(variant or "info")] or colors.info
	local toast = makePanel(toastHolder, "Toast_" .. tostring(toastCounter), pair[1], pair[2], 18, 1001)
	toast.Size = UDim2.fromOffset(330, 78)
	toast.BackgroundTransparency = 0
	toast.LayoutOrder = -toastCounter

	local label = makeLabel(
		toast,
		"Message",
		tostring(message or ""),
		UDim2.new(1, -28, 1, -16),
		UDim2.new(0, 14, 0, 8),
		20,
		Color3.fromRGB(255, 255, 255),
		1004
	)
	label.TextXAlignment = Enum.TextXAlignment.Left

	local scale = Instance.new("UIScale")
	scale.Scale = 0.88
	scale.Parent = toast
	tween(scale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)

	task.delay(3, function()
		if not toast.Parent then
			return
		end

		tween(scale, 0.12, { Scale = 0.88 })
		tween(toast, 0.16, { BackgroundTransparency = 1 })

		for _, obj in ipairs(toast:GetDescendants()) do
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				tween(obj, 0.16, { TextTransparency = 1 })
				local s = obj:FindFirstChildOfClass("UIStroke")
				if s then
					tween(s, 0.16, { Transparency = 1 })
				end
			elseif obj:IsA("UIStroke") then
				tween(obj, 0.16, { Transparency = 1 })
			elseif obj:IsA("Frame") then
				tween(obj, 0.16, { BackgroundTransparency = 1 })
			end
		end

		task.delay(0.18, function()
			if toast then
				toast:Destroy()
			end
		end)
	end)
end

local styledObjects = {}

local function shouldStyleGuiObject(obj)
	if styledObjects[obj] then
		return false
	end

	if not obj:IsA("GuiObject") then
		return false
	end

	if obj:IsDescendantOf(screenGui) then
		return false
	end

	if obj:GetAttribute("ProUISkip") == true then
		return false
	end

	return true
end

local function polishGuiObject(obj)
	if not shouldStyleGuiObject(obj) then
		return
	end

	styledObjects[obj] = true

	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		obj.Font = FONT
		obj.TextWrapped = true

		if obj.TextScaled then
			constrainText(obj, obj.AbsoluteSize.Y > 60 and 34 or 22, 8)
		end

		if obj.TextStrokeTransparency > 0.35 then
			obj.TextStrokeTransparency = 0.2
			obj.TextStrokeColor3 = THEME.Ink
		end
	end

	if obj:IsA("TextButton") then
		obj.AutoButtonColor = false

		if obj.BackgroundTransparency < 0.9 then
			addCorner(obj, math.clamp(math.floor(obj.AbsoluteSize.Y / 3), 10, 18))
			addStroke(obj, THEME.Ink, 2)
		end
	end

	if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
		if obj.BackgroundTransparency < 0.85 and obj.AbsoluteSize.X < 1000 and obj.AbsoluteSize.Y < 800 then
			addCorner(obj, math.clamp(math.floor(obj.AbsoluteSize.Y / 7), 8, 20))
			if not obj:FindFirstChildOfClass("UIStroke") then
				addStroke(obj, THEME.Ink, 2, 0.1)
			end
		end
	end
end

local function polishGuiTree(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("GuiObject") then
			polishGuiObject(obj)
		end
	end
end

local function bindNpcIndexTracking()
	local function markSeenFromInstance(instance)
		local name = tostring(instance:GetAttribute("DisplayName") or instance:GetAttribute("BrainrotName") or instance.Name)
		if name ~= "" then
			seenNpcs[name] = true
		end
	end

	local function bindToolContainer(container)
		if not container then
			return
		end

		container.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and (child:GetAttribute("BrainrotTool") == true or child:GetAttribute("InventoryOnly") == true) then
				markSeenFromInstance(child)
			end
		end)
	end

	local npcFolder = Workspace:FindFirstChild("BrainrotNPCs")

	scanSeenNpcs()

	if npcFolder then
		npcFolder.ChildAdded:Connect(function(npc)
			if npc:IsA("Model") then
				markSeenFromInstance(npc)
			end
		end
	end

	bindToolContainer(player:FindFirstChild("Backpack"))
	bindToolContainer(player:FindFirstChild("StarterGear"))

	player.CharacterAdded:Connect(function(character)
		bindToolContainer(character)
		task.defer(scanSeenNpcs)
	end)
end

_G.BrainrotProUI = {
	OpenShop = function()
		openModal("Shop")
	end,
	OpenIndex = function()
		openModal("Index")
	end,
	OpenRebirth = function()
		openModal("Rebirth")
	end,
	Notify = pushToast,
	ApplySkin = function()
		polishGuiTree(playerGui)
		polishGuiTree(Workspace)
	end,
}

closeButton.Activated:Connect(closeModal)
dim.Activated:Connect(closeModal)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closeModal()
	end
end)

local function bindCameraScale()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			setModalScale(isOpen and 1 or 0.82)
		end)
	end
end

bindCameraScale()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCameraScale)
setModalScale(0.82)

if notifyRemote and notifyRemote:IsA("RemoteEvent") then
	notifyRemote.OnClientEvent:Connect(function(payload, maybeVariant)
		if type(payload) == "table" then
			pushToast(payload.message or payload.text or payload.title or "Done", payload.variant or payload.type or "info")
		else
			pushToast(payload, maybeVariant or "info")
		end
	end)
end

if updateUpgradesRemote and updateUpgradesRemote:IsA("RemoteEvent") then
	updateUpgradesRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			latestUpgradePayload = payload
			if isOpen and currentMode == "Shop" then
				renderShop()
			end
		end
	end)
end

if rebirthUpdateRemote and rebirthUpdateRemote:IsA("RemoteEvent") then
	rebirthUpdateRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			latestRebirthPayload = payload
			if isOpen and currentMode == "Rebirth" then
				renderRebirth()
			end
		end
	end)
end

playerGui.DescendantAdded:Connect(function(obj)
	task.defer(function()
		if obj:IsA("GuiObject") then
			polishGuiObject(obj)
		end
	end)
end)

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("GuiObject") then
		task.defer(function()
			polishGuiObject(obj)
		end)
	end
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "BrainrotNPCs" then
		task.defer(bindNpcIndexTracking)
	end
end)

task.defer(function()
	bindNpcIndexTracking()
	polishGuiTree(playerGui)
	polishGuiTree(Workspace)
	requestUpgradeRefresh()
	requestRebirthState()

	while true do
		task.wait(2)
		local rebirthGui = playerGui:FindFirstChild("RebirthGui")
		local oldOpen = rebirthGui and rebirthGui:FindFirstChild("OpenRebirthButton", true)
		if oldOpen and oldOpen:IsA("GuiObject") then
			oldOpen.Visible = false
		end
	end
end)

print("[ProfessionalCartoonUI] loaded unified pro UI layer.")
