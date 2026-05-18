-- StarterPlayerScripts/HUD_LeftButtons.client.lua
-- Full replacement

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SocialService = game:GetService("SocialService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiFolder = ReplicatedStorage:WaitForChild("GUI")

local CLICK_COOLDOWN = 0.18

local DESKTOP_SIZE = 82
local TABLET_SIZE = 74
local MOBILE_SIZE = 66

local DESKTOP_LEFT_PADDING = 18
local TABLET_LEFT_PADDING = 14
local MOBILE_LEFT_PADDING = 10

local DESKTOP_GAP_X = 92
local TABLET_GAP_X = 82
local MOBILE_GAP_X = 74

local DESKTOP_GAP_Y = 92
local TABLET_GAP_Y = 82
local MOBILE_GAP_Y = 74

local OLD_GUI_NAMES = {
	"LeftMainButtonsGui",
	"ShopButtonGui",
	"IndexButtonGui",
	"InviteButtonGui",
	"RebirthButtonGui",
	"LeftButtonsGui",
	"LeftMenuGui",
	"CartoonGamePanelsGui",
	"RoUIBottomBarGui",
	"BottomBarGui",
}

for _, guiName in ipairs(OLD_GUI_NAMES) do
	local oldGui = playerGui:FindFirstChild(guiName)
	if oldGui then
		oldGui:Destroy()
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LeftMainButtonsGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 95
screenGui.Parent = playerGui

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
		return nil
	end

	if asset:IsA("ImageLabel") or asset:IsA("ImageButton") then
		return asset.Image
	elseif asset:IsA("Decal") or asset:IsA("Texture") then
		return asset.Texture
	elseif asset:IsA("StringValue") then
		return asset.Value
	end

	local success, image = pcall(function()
		return asset.Image
	end)

	if success then
		return image
	end

	return nil
end

local function setupImageLayer(layer, asset)
	local image = extractImage(asset)

	if typeof(image) ~= "string" or image == "" then
		return false
	end

	layer.Image = image
	layer.ImageTransparency = 1
	layer.ImageColor3 = Color3.new(1, 1, 1)
	layer.ScaleType = Enum.ScaleType.Fit
	layer.BackgroundTransparency = 1
	layer.Visible = true

	if asset and (asset:IsA("ImageLabel") or asset:IsA("ImageButton")) then
		pcall(function()
			layer.ImageRectOffset = asset.ImageRectOffset
			layer.ImageRectSize = asset.ImageRectSize
			layer.ResampleMode = asset.ResampleMode
		end)
	end

	return true
end

local function createTween(instance, duration, style, direction, properties)
	local created = TweenService:Create(
		instance,
		TweenInfo.new(duration, style, direction),
		properties
	)

	created:Play()
	return created
end

local popupStates = {}

local function destroyPopup(name)
	local data = popupStates[name]
	if not data then
		return
	end

	if data.gui and data.gui.Parent then
		data.gui:Destroy()
	end

	popupStates[name] = nil
end

local function openTemplatePopup(name, assetNames)
	local existing = popupStates[name]
	if existing and existing.gui and existing.gui.Parent then
		existing.gui.Enabled = not existing.gui.Enabled
		return
	end

	local asset = findChildInsensitive(guiFolder, assetNames)
	local imageId = extractImage(asset)

	if not imageId or imageId == "" then
		warn("[HUD_LeftButtons] Missing template image for", name)
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = name .. "PopupGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 600
	gui.Parent = playerGui

	local blocker = Instance.new("TextButton")
	blocker.Name = "Blocker"
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blocker.BackgroundTransparency = 0.35
	blocker.BorderSizePixel = 0
	blocker.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(620, 700)
	panel.BackgroundTransparency = 1
	panel.Parent = gui

	local panelScale = Instance.new("UIScale")
	panelScale.Scale = 0.82
	panelScale.Parent = panel

	local image = Instance.new("ImageLabel")
	image.Name = "TemplateImage"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = imageId
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = panel

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -8, 0, 8)
	close.Size = UDim2.fromOffset(42, 42)
	close.Text = "X"
	close.TextScaled = true
	close.Font = Enum.Font.FredokaOne
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
	close.BorderSizePixel = 0
	close.AutoButtonColor = true
	close.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = close

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Parent = close

	local function closePopup()
		destroyPopup(name)
	end

	blocker.Activated:Connect(closePopup)
	close.Activated:Connect(closePopup)

	createTween(panelScale, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
		Scale = 1,
	})

	popupStates[name] = {
		gui = gui,
	}
end

local function callProUI(methodName)
	local api = rawget(_G, "BrainrotProUI")
	if type(api) == "table" and type(api[methodName]) == "function" then
		api[methodName]()
		return true
	end

	return false
end

local function openShop()
	if callProUI("OpenShop") then
		return
	end

	openTemplatePopup("Shop", { "shopT", "shoptemplate", "shop" })
end

local function openRebirth()
	if callProUI("OpenRebirth") then
		return
	end

	openTemplatePopup("Rebirth", { "rebirthT", "rebirthtemplate", "rebirth" })
end

local function toggleGui(guiNames)
	for _, guiName in ipairs(guiNames) do
		local gui = playerGui:FindFirstChild(guiName)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = not gui.Enabled
			return true
		end
	end

	return false
end

local function openInvite()
	local success, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)

	if success and canInvite then
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	else
		warn("[HUD_LeftButtons] Invite prompt unavailable here.")
	end
end

local function openIndex()
	if callProUI("OpenIndex") then
		return
	end

	if toggleGui({
		"InventoryPanelGui",
		"IndexPanelGui",
		"IndexGui",
		}) then
		return
	end

	local hud = playerGui:FindFirstChild("CartoonSimulatorHUD")
	if hud then
		local popup = hud:FindFirstChild("INVENTORYPopup")
		if popup and popup:IsA("GuiObject") then
			popup.Visible = not popup.Visible
			return
		end
	end

	warn("[HUD_LeftButtons] Inventory / Index panel not found.")
end

local buttonConfigs = {
	{
		name = "Shop",
		folderName = "shopButton",
		row = 1,
		col = 1,
		onClick = openShop,
		idleNames = { "idle" },
		hoverNames = { "hover" },
		clickedNames = { "clicked" },
	},
	{
		name = "Invite",
		folderName = "inviteButton",
		row = 1,
		col = 2,
		onClick = openInvite,
		idleNames = { "idle" },
		hoverNames = { "hover" },
		clickedNames = { "clicked" },
	},
	{
		name = "Index",
		folderName = "indexButton",
		row = 2,
		col = 1,
		onClick = openIndex,
		idleNames = { "idle", "f1" },
		hoverNames = { "hover", "f8" },
		clickedNames = { "clicked", "fclicked" },
	},
	{
		name = "Rebirth",
		folderName = "rebirthButton",
		row = 2,
		col = 2,
		onClick = openRebirth,
		idleNames = { "idle" },
		hoverNames = { "hover" },
		clickedNames = { "clicked" },
	},
}

local function preloadButtonImages()
	local preloadFrame = Instance.new("Frame")
	preloadFrame.Name = "PreloadFrame"
	preloadFrame.Size = UDim2.fromOffset(1, 1)
	preloadFrame.Position = UDim2.fromOffset(-5000, -5000)
	preloadFrame.BackgroundTransparency = 1
	preloadFrame.Visible = true
	preloadFrame.Parent = screenGui

	local preloadObjects = {}

	for _, config in ipairs(buttonConfigs) do
		local folder = guiFolder:FindFirstChild(config.folderName)
		if folder then
			local assets = {
				findChildInsensitive(folder, config.idleNames),
				findChildInsensitive(folder, config.hoverNames),
				findChildInsensitive(folder, config.clickedNames),
			}

			for _, asset in ipairs(assets) do
				local image = extractImage(asset)
				if typeof(image) == "string" and image ~= "" then
					local img = Instance.new("ImageLabel")
					img.BackgroundTransparency = 1
					img.Image = image
					img.Size = UDim2.fromOffset(1, 1)
					img.Parent = preloadFrame
					table.insert(preloadObjects, img)
				end
			end
		end
	end

	for _, assetName in ipairs({ "2Xlucky", "2Xpower", "shopT", "rebirthT" }) do
		local asset = findChildInsensitive(guiFolder, { assetName })
		local image = extractImage(asset)

		if image and image ~= "" then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = image
			img.Size = UDim2.fromOffset(1, 1)
			img.Parent = preloadFrame
			table.insert(preloadObjects, img)
		end
	end

	if #preloadObjects > 0 then
		pcall(function()
			ContentProvider:PreloadAsync(preloadObjects)
		end)
	end

	preloadFrame:Destroy()
end

preloadButtonImages()

local createdButtons = {}

local function createHudButton(config)
	local folder = guiFolder:FindFirstChild(config.folderName)
	if not folder then
		warn("[HUD_LeftButtons] Missing folder:", config.folderName)
		return
	end

	local idleAsset = findChildInsensitive(folder, config.idleNames)
	local hoverAsset = findChildInsensitive(folder, config.hoverNames)
	local clickedAsset = findChildInsensitive(folder, config.clickedNames)

	if not idleAsset then
		warn("[HUD_LeftButtons] Missing idle asset for", config.name)
		return
	end

	local holder = Instance.new("Frame")
	holder.Name = config.name .. "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ZIndex = 49
	holder.Parent = screenGui

	local scale = Instance.new("UIScale")
	scale.Name = "ButtonScale"
	scale.Scale = 1
	scale.Parent = holder

	local idleLayer = Instance.new("ImageLabel")
	idleLayer.Name = "IdleLayer"
	idleLayer.AnchorPoint = Vector2.new(0.5, 0.5)
	idleLayer.Position = UDim2.fromScale(0.5, 0.5)
	idleLayer.Size = UDim2.fromScale(1, 1)
	idleLayer.BackgroundTransparency = 1
	idleLayer.ZIndex = 50
	idleLayer.Parent = holder

	local hoverLayer = idleLayer:Clone()
	hoverLayer.Name = "HoverLayer"
	hoverLayer.ZIndex = 51
	hoverLayer.Parent = holder

	local clickedLayer = idleLayer:Clone()
	clickedLayer.Name = "ClickedLayer"
	clickedLayer.ZIndex = 52
	clickedLayer.Parent = holder

	local inputButton = Instance.new("ImageButton")
	inputButton.Name = config.name .. "InputButton"
	inputButton.AnchorPoint = Vector2.new(0.5, 0.5)
	inputButton.Position = UDim2.fromScale(0.5, 0.5)
	inputButton.Size = UDim2.fromScale(1, 1)
	inputButton.BackgroundTransparency = 1
	inputButton.ImageTransparency = 1
	inputButton.AutoButtonColor = false
	inputButton.ZIndex = 60
	inputButton.Parent = holder

	setupImageLayer(idleLayer, idleAsset)
	setupImageLayer(hoverLayer, hoverAsset or idleAsset)
	setupImageLayer(clickedLayer, clickedAsset or idleAsset)

	idleLayer.ImageTransparency = 0
	hoverLayer.ImageTransparency = 1
	clickedLayer.ImageTransparency = 1

	local hovering = false
	local pressing = false
	local lastClick = 0

	local function setLayerState(state)
		if state == "idle" then
			createTween(hoverLayer, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageTransparency = 1,
			})
			createTween(clickedLayer, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageTransparency = 1,
			})
		elseif state == "hover" then
			createTween(hoverLayer, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageTransparency = 0,
			})
			createTween(clickedLayer, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageTransparency = 1,
			})
		elseif state == "clicked" then
			createTween(hoverLayer, 0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageTransparency = 1,
			})
			createTween(clickedLayer, 0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageTransparency = 0,
			})
		end
	end

	local function playIdle()
		setLayerState("idle")
		createTween(scale, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			Scale = 1,
		})
	end

	local function playHover()
		setLayerState("hover")
		createTween(scale, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
			Scale = 1.08,
		})
	end

	local function playClicked()
		pressing = true
		setLayerState("clicked")
		createTween(scale, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			Scale = 0.88,
		})

		task.delay(0.09, function()
			pressing = false

			if hovering then
				playHover()
			else
				playIdle()
			end
		end)
	end

	inputButton.MouseEnter:Connect(function()
		hovering = true
		if not pressing then
			playHover()
		end
	end)

	inputButton.MouseLeave:Connect(function()
		hovering = false
		if not pressing then
			playIdle()
		end
	end)

	inputButton.Activated:Connect(function()
		local now = os.clock()
		if now - lastClick < CLICK_COOLDOWN then
			return
		end

		lastClick = now
		playClicked()
		config.onClick()
	end)

	createdButtons[config.name] = {
		holder = holder,
		row = config.row,
		col = config.col,
	}
end

for _, config in ipairs(buttonConfigs) do
	createHudButton(config)
end

local offerContainer = Instance.new("Frame")
offerContainer.Name = "RightOffers"
offerContainer.AnchorPoint = Vector2.new(1, 0.5)
offerContainer.Position = UDim2.new(1, -4, 0.53, 0)
offerContainer.Size = UDim2.fromOffset(160, 260)
offerContainer.BackgroundTransparency = 1
offerContainer.Parent = screenGui

local offerLayout = Instance.new("UIListLayout")
offerLayout.FillDirection = Enum.FillDirection.Vertical
offerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
offerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
offerLayout.Padding = UDim.new(0, 10)
offerLayout.Parent = offerContainer

local function startSparkles(parent)
	task.spawn(function()
		while parent and parent.Parent do
			local sparkle = Instance.new("TextLabel")
			sparkle.Name = "Sparkle"
			sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
			sparkle.Position = UDim2.fromScale(
				math.random(10, 90) / 100,
				math.random(8, 82) / 100
			)
			sparkle.Size = UDim2.fromOffset(math.random(14, 24), math.random(14, 24))
			sparkle.BackgroundTransparency = 1
			sparkle.Text = math.random(1, 2) == 1 and "✦" or "✧"
			sparkle.TextScaled = true
			sparkle.Font = Enum.Font.FredokaOne
			sparkle.TextColor3 = Color3.fromRGB(255, 245, 130)
			sparkle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			sparkle.TextStrokeTransparency = 0.25
			sparkle.TextTransparency = 0.05
			sparkle.Rotation = math.random(-25, 25)
			sparkle.ZIndex = 40
			sparkle.Parent = parent

			local goalPosition = UDim2.new(
				sparkle.Position.X.Scale,
				sparkle.Position.X.Offset + math.random(-10, 10),
				sparkle.Position.Y.Scale,
				sparkle.Position.Y.Offset - math.random(12, 26)
			)

			TweenService:Create(
				sparkle,
				TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Position = goalPosition,
					TextTransparency = 1,
					TextStrokeTransparency = 1,
					Rotation = sparkle.Rotation + math.random(-35, 35),
				}
			):Play()

			task.delay(0.75, function()
				if sparkle then
					sparkle:Destroy()
				end
			end)

			task.wait(math.random(35, 75) / 100)
		end
	end)
end

local function createOffer(offerName)
	local asset = findChildInsensitive(guiFolder, { offerName })
	local imageId = extractImage(asset)

	if not imageId or imageId == "" then
		return
	end

	local holder = Instance.new("Frame")
	holder.Name = offerName .. "Holder"
	holder.Size = UDim2.fromOffset(150, 118)
	holder.BackgroundTransparency = 1
	holder.Parent = offerContainer

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = holder

	local imageWrap = Instance.new("Frame")
	imageWrap.Name = "ImageWrap"
	imageWrap.AnchorPoint = Vector2.new(0.5, 0)
	imageWrap.Position = UDim2.new(0.5, 0, 0, 0)
	imageWrap.Size = UDim2.fromOffset(150, 92)
	imageWrap.BackgroundTransparency = 1
	imageWrap.ClipsDescendants = false
	imageWrap.Parent = holder

	local image = Instance.new("ImageLabel")
	image.Name = "OfferImage"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(1, 1)
	image.BackgroundTransparency = 1
	image.Image = imageId
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = 20
	image.Parent = imageWrap

	startSparkles(imageWrap)

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.AnchorPoint = Vector2.new(0.5, 1)
	price.Position = UDim2.new(0.5, 0, 1, -38)
	price.Size = UDim2.new(1, 0, 0, 22)
	price.BackgroundTransparency = 1
	price.Text = "10 Robux"
	price.TextScaled = true
	price.Font = Enum.Font.FredokaOne
	price.TextColor3 = Color3.fromRGB(45, 255, 90)
	price.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	price.TextStrokeTransparency = 0
	price.Parent = holder

	local btn = Instance.new("ImageButton")
	btn.Name = "OfferButton"
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = UDim2.fromScale(0.5, 0.5)
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.ImageTransparency = 1
	btn.AutoButtonColor = false
	btn.Parent = holder

	btn.MouseEnter:Connect(function()
		createTween(scale, 0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
			Scale = 1.04,
		})
	end)

	btn.MouseLeave:Connect(function()
		createTween(scale, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			Scale = 1,
		})
	end)

	btn.Activated:Connect(function()
		openShop()
	end)
end

createOffer("2Xlucky")
createOffer("2Xpower")

local function updateLayout()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local viewport = camera.ViewportSize
	local width = viewport.X
	local height = viewport.Y

	local buttonSize
	local leftPadding
	local gapX
	local gapY

	if width <= 500 then
		buttonSize = MOBILE_SIZE
		leftPadding = MOBILE_LEFT_PADDING
		gapX = MOBILE_GAP_X
		gapY = MOBILE_GAP_Y
	elseif width <= 900 then
		buttonSize = TABLET_SIZE
		leftPadding = TABLET_LEFT_PADDING
		gapX = TABLET_GAP_X
		gapY = TABLET_GAP_Y
	else
		buttonSize = DESKTOP_SIZE
		leftPadding = DESKTOP_LEFT_PADDING
		gapX = DESKTOP_GAP_X
		gapY = DESKTOP_GAP_Y
	end

	local clusterHeight = buttonSize + gapY
	local leftCenterX = leftPadding + (buttonSize / 2)
	local topCenterY = (height / 2) - (clusterHeight / 2) + (buttonSize / 2)

	for _, data in pairs(createdButtons) do
		local colIndex = data.col - 1
		local rowIndex = data.row - 1

		local centerX = leftCenterX + (colIndex * gapX)
		local centerY = topCenterY + (rowIndex * gapY)

		data.holder.Size = UDim2.fromOffset(buttonSize, buttonSize)
		data.holder.Position = UDim2.fromOffset(centerX, centerY)
	end

	if width <= 500 then
		offerContainer.Position = UDim2.new(1, -3, 0.55, 0)
		offerContainer.Size = UDim2.fromOffset(130, 220)
	else
		offerContainer.Position = UDim2.new(1, -4, 0.53, 0)
		offerContainer.Size = UDim2.fromOffset(160, 260)
	end
end

updateLayout()

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	task.wait()
	updateLayout()

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
	end
end)

print("[HUD_LeftButtons] Loaded buttons + closer Robux text.")
