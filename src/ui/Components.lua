local Theme = require(script.Parent.Theme)

local Components = {}

local function addPixelCorners(parent, color)
	for _, position in ipairs({
		UDim2.fromOffset(-3, -3),
		UDim2.new(1, -3, 0, -3),
		UDim2.new(0, -3, 1, -3),
		UDim2.new(1, -3, 1, -3),
	}) do
		local pixel = Instance.new("Frame")
		pixel.Name = "CornerPixel"
		pixel.Size = UDim2.fromOffset(6, 6)
		pixel.Position = position
		pixel.BackgroundColor3 = color or Color3.fromRGB(15, 17, 27)
		pixel.BorderSizePixel = 0
		pixel.ZIndex = parent.ZIndex + 1
		pixel.Parent = parent
	end
end

local function addHighlight(parent)
	local highlight = Instance.new("Frame")
	highlight.Name = "TopHighlight"
	highlight.Size = UDim2.new(1, -8, 0, 3)
	highlight.Position = UDim2.fromOffset(4, 4)
	highlight.BackgroundColor3 = Color3.new(1, 1, 1)
	highlight.BackgroundTransparency = 0.68
	highlight.BorderSizePixel = 0
	highlight.ZIndex = parent.ZIndex + 1
	highlight.Parent = parent
end

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius = radius or Theme.Corner
	item.Parent = parent
	return item
end

local function stroke(parent, color, thickness)
	local item = Instance.new("UIStroke")
	item.Color = color or Color3.fromRGB(15, 17, 27)
	item.Thickness = thickness or Theme.Stroke
	item.Parent = parent
	return item
end

function Components.Label(parent, text, size, position)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size or UDim2.fromScale(1, 1)
	label.Position = position or UDim2.fromScale(0, 0)
	label.Text = text
	label.TextColor3 = Theme.Colors.Ink
	label.TextStrokeTransparency = 0.65
	label.Font = Theme.Font
	label.TextScaled = true
	label.Parent = parent
	return label
end

function Components.Button(parent, text, color)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.BackgroundColor3 = color or Theme.Colors.Blue
	button.Text = text
	button.TextColor3 = Theme.Colors.Ink
	button.TextStrokeTransparency = 0.55
	button.Font = Theme.FontHeavy
	button.TextScaled = true
	button.BorderSizePixel = 0
	button.Parent = parent
	local textSize = Instance.new("UITextSizeConstraint")
	textSize.MaxTextSize = 24
	textSize.MinTextSize = 10
	textSize.Parent = button
	corner(button)
	stroke(button)
	addPixelCorners(button)
	addHighlight(button)
	return button
end

function Components.Panel(parent, name, size, position)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Size = size
	panel.Position = position
	panel.BackgroundColor3 = Theme.Colors.Panel
	panel.BorderSizePixel = 0
	panel.Parent = parent
	corner(panel)
	stroke(panel)
	addPixelCorners(panel)
	addHighlight(panel)
	return panel
end

function Components.Window(parent, name, title)
	local window = Components.Panel(parent, name, UDim2.fromScale(0.54, 0.6), UDim2.fromScale(0.5, 0.5))
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 58)
	header.BackgroundColor3 = Theme.Colors.PanelLight
	header.BorderSizePixel = 0
	header.Parent = window
	corner(header)
	local titleLabel = Components.Label(header, title, UDim2.new(1, -76, 1, -12), UDim2.fromOffset(18, 6))
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MaxTextSize = 30
	titleSize.MinTextSize = 16
	titleSize.Parent = titleLabel
	local close = Components.Button(header, "X", Theme.Colors.Red)
	close.Name = "Close"
	close.Size = UDim2.fromOffset(44, 40)
	close.Position = UDim2.new(1, -52, 0, 9)
	local closeSize = Instance.new("UITextSizeConstraint")
	closeSize.MaxTextSize = 22
	closeSize.Parent = close
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -24, 1, -82)
	body.Position = UDim2.fromOffset(12, 70)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 7
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Parent = window
	close.Activated:Connect(function()
		window.Visible = false
	end)
	return window, body
end

function Components.Grid(parent, cellSize)
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.CellSize = cellSize or UDim2.fromOffset(180, 210)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = parent
	return grid
end

function Components.Card(parent, color)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.Colors.PanelLight
	card.BorderSizePixel = 0
	card.Parent = parent
	corner(card)
	stroke(card, color or Color3.fromRGB(20, 22, 34), 3)
	addPixelCorners(card, color)
	addHighlight(card)
	return card
end

return Components
