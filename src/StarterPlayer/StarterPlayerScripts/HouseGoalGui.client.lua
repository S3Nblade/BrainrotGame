--!strict
-- HouseGoalGui
-- Put in: StarterPlayer > StarterPlayerScripts
-- Cartoon no-background collect-money labels above each CollectMoney part.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local npcFolder = workspace:WaitForChild("BrainrotNPCs")
local plots = workspace:WaitForChild("SpawnMap"):WaitForChild("Plots")

local FONT = Enum.Font.FredokaOne

local function formatMoney(n: number): string
	n = math.floor(tonumber(n) or 0)

	if n >= 1_000_000_000_000 then
		return string.format("$%.1fT", n / 1_000_000_000_000)
	elseif n >= 1_000_000_000 then
		return string.format("$%.1fB", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return string.format("$%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("$%.1fK", n / 1_000)
	end

	local str = tostring(n)
	local out = ""
	local count = 0

	for i = #str, 1, -1 do
		if count > 0 and count % 3 == 0 then
			out = "," .. out
		end

		out = string.sub(str, i, i) .. out
		count += 1
	end

	return "$" .. out
end

local function addStroke(label: TextLabel, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0
	stroke.Parent = label
	return stroke
end

local function addGradient(label: TextLabel, top: Color3, bottom: Color3): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	gradient.Rotation = 90
	gradient.Parent = label
	return gradient
end

local function makeOutlinedText(
	parent: Instance,
	name: string,
	text: string,
	y: number,
	height: number,
	textSize: number,
	mainColor: Color3,
	strokeColor: Color3,
	strokeThickness: number,
	zIndex: number
): {label: TextLabel, shadow: TextLabel}

	local shadow = Instance.new("TextLabel")
	shadow.Name = name .. "_Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Size = UDim2.new(1, 0, 0, height)
	shadow.Position = UDim2.new(0, 3, 0, y + 3)
	shadow.Text = text
	shadow.Font = FONT
	shadow.TextSize = textSize
	shadow.TextColor3 = Color3.fromRGB(0, 0, 0)
	shadow.TextTransparency = 0.2
	shadow.TextXAlignment = Enum.TextXAlignment.Center
	shadow.TextYAlignment = Enum.TextYAlignment.Center
	shadow.ZIndex = zIndex
	shadow.Parent = parent

	addStroke(shadow, Color3.fromRGB(0, 0, 0), strokeThickness + 2).Transparency = 0.2

	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, height)
	label.Position = UDim2.new(0, 0, 0, y)
	label.Text = text
	label.Font = FONT
	label.TextSize = textSize
	label.TextColor3 = mainColor
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zIndex + 2
	label.Parent = parent

	addStroke(label, strokeColor, strokeThickness)

	return {
		label = label,
		shadow = shadow,
	}
end

local function findCollectPart(houseGoal: BasePart): BasePart?
	local direct = houseGoal:FindFirstChild("CollectMoney")
	if direct and direct:IsA("BasePart") then
		return direct
	end

	for _, obj in ipairs(houseGoal:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "CollectMoney" then
			return obj
		end
	end

	return nil
end

local function getNpcForGoal(plot: Model, goalName: string): Model?
	local ownerUserId = plot:GetAttribute("OwnerUserId")

	if type(ownerUserId) ~= "number" or ownerUserId == 0 then
		return nil
	end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model")
			and npc:GetAttribute("IsPlaced") == true
			and npc:GetAttribute("PlacedOwnerUserId") == ownerUserId
			and npc:GetAttribute("AssignedHouseGoal") == goalName
		then
			return npc
		end
	end

	return nil
end

local function buildCollectGui(collectPart: BasePart, goalName: string, plot: Model)
	local old = collectPart:FindFirstChild("CollectGui")
	if old then
		old:Destroy()
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "CollectGui"
	bb.Size = UDim2.new(0, 210, 0, 82)
	bb.StudsOffset = Vector3.new(0, 2.55, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 55
	bb.ResetOnSpawn = false
	bb.LightInfluence = 0
	bb.Adornee = collectPart
	bb.Parent = collectPart

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = bb

	local amountText = makeOutlinedText(
		holder,
		"AmountLabel",
		"$0",
		0,
		48,
		36,
		Color3.fromRGB(90, 255, 75),
		Color3.fromRGB(0, 85, 15),
		5,
		5
	)

	addGradient(
		amountText.label,
		Color3.fromRGB(195, 255, 130),
		Color3.fromRGB(45, 235, 55)
	)

	local collectText = makeOutlinedText(
		holder,
		"CollectLabel",
		"EMPTY",
		42,
		30,
		20,
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(0, 0, 0),
		3,
		5
	)

	task.spawn(function()
		local t = 0

		while collectPart.Parent and bb.Parent do
			t += 0.16

			local npc = getNpcForGoal(plot, goalName)
			local earned = 0

			if npc then
				earned = (npc:GetAttribute("Earned") :: number?) or 0
			end

			local amountString = formatMoney(earned)

			amountText.label.Text = amountString
			amountText.shadow.Text = amountString

			if earned > 0 then
				collectText.label.Text = "COLLECT"
				collectText.shadow.Text = "COLLECT"
				collectText.label.TextColor3 = Color3.fromRGB(255, 255, 255)

				bb.StudsOffset = Vector3.new(0, 2.55 + math.sin(t) * 0.08, 0)
			else
				collectText.label.Text = "EMPTY"
				collectText.shadow.Text = "EMPTY"
				collectText.label.TextColor3 = Color3.fromRGB(195, 215, 200)

				bb.StudsOffset = Vector3.new(0, 2.55, 0)
			end

			task.wait(0.18)
		end
	end)
end

local function bindPlot(plot: Instance)
	if not plot:IsA("Model") then
		return
	end

	for _, child in ipairs(plot:GetChildren()) do
		if child:IsA("BasePart") and string.find(child.Name, "^HouseGoal_") ~= nil then
			local collectPart = findCollectPart(child)
			if collectPart then
				buildCollectGui(collectPart, child.Name, plot)
			end
		end
	end

	plot.ChildAdded:Connect(function(child)
		task.wait(0.15)

		if child:IsA("BasePart") and string.find(child.Name, "^HouseGoal_") ~= nil then
			local collectPart = findCollectPart(child)
			if collectPart then
				buildCollectGui(collectPart, child.Name, plot)
			end
		end
	end)
end

for _, plot in ipairs(plots:GetChildren()) do
	task.spawn(bindPlot, plot)
end

plots.ChildAdded:Connect(function(plot)
	task.wait(0.5)
	bindPlot(plot)
end)