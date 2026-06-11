local Theme = require(script.Parent.Theme)

local Components = {}

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
	corner(button)
	stroke(button)
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
	return panel
end

function Components.Window(parent, name, title)
	local window = Components.Panel(parent, name, UDim2.fromScale(0.72, 0.76), UDim2.fromScale(0.14, 0.12))
	window.Visible = false
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(820, 620)
	sizeConstraint.MinSize = Vector2.new(320, 340)
	sizeConstraint.Parent = window
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 58)
	header.BackgroundColor3 = Theme.Colors.PanelLight
	header.BorderSizePixel = 0
	header.Parent = window
	corner(header)
	local titleLabel = Components.Label(header, title, UDim2.new(1, -76, 1, -12), UDim2.fromOffset(18, 6))
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	local close = Components.Button(header, "X", Theme.Colors.Red)
	close.Name = "Close"
	close.Size = UDim2.fromOffset(44, 40)
	close.Position = UDim2.new(1, -52, 0, 9)
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
	return card
end

return Components
