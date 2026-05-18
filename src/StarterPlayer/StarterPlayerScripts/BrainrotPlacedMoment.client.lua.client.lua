--!nonstrict
-- BrainrotPlacedMoment.client.lua
-- Put in: StarterPlayer > StarterPlayerScripts
-- Shows a polished "PLACED!" moment when a brainrot reaches the player's plot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local npcFolder = workspace:WaitForChild("BrainrotNPCs")
local remote = ReplicatedStorage:WaitForChild("BrainrotPlacedFeedback")

local FONT = Enum.Font.FredokaOne

local RARITY_COLORS = {
	Common = Color3.fromRGB(220, 220, 220),
	Rare = Color3.fromRGB(70, 150, 255),
	Epic = Color3.fromRGB(190, 80, 255),
	Mythic = Color3.fromRGB(255, 60, 160),
	Legendary = Color3.fromRGB(255, 190, 35),
	Divine = Color3.fromRGB(40, 230, 255),
	Celestial = Color3.fromRGB(150, 120, 255),
	Godly = Color3.fromRGB(255, 70, 70),
}

local lastAt = 0
local shownRecently = {}

local function formatMoney(n)
	n = math.floor(tonumber(n) or 0)

	if n >= 1_000_000_000 then
		return string.format("%.1fB", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return string.format("%.1fM", n / 1_000_000)
	elseif n >= 1_000 then
		return string.format("%.1fK", n / 1_000)
	end

	return tostring(n)
end

local function addCorner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = obj
	return c
end

local function addStroke(obj, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(0, 0, 0)
	s.Thickness = thickness or 2
	s.Parent = obj
	return s
end

local function addGradient(obj, top, bottom)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	g.Parent = obj
	return g
end

local function makeText(parent, name, text, pos, size, maxSize, color, z)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Text = text
	label.Font = FONT
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = z or 1
	label.Parent = parent

	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 8
	limit.MaxTextSize = maxSize
	limit.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = math.max(2, maxSize / 10)
	stroke.Parent = label

	return label
end

local function getRarityColor(rarity)
	return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

local function playSound()
	local sound = Instance.new("Sound")
	sound.Name = "BrainrotPlacedSound"
	sound.SoundId = "rbxassetid://9120386436"
	sound.Volume = 0.36
	sound.PlaybackSpeed = 1.22
	sound.Parent = SoundService
	sound:Play()

	task.delay(3, function()
		if sound then
			sound:Destroy()
		end
	end)
end

local function findNPC(npcId, npcName)
	for _, obj in ipairs(npcFolder:GetDescendants()) do
		if obj:IsA("Model") then
			local id =
				obj:GetAttribute("NPCId")
				or obj:GetAttribute("Id")
				or obj:GetAttribute("UniqueId")
				or obj.Name

			if tostring(id) == tostring(npcId) or obj.Name == npcName then
				return obj
			end
		end
	end

	return nil
end

local function glowNPC(npc, color)
	if not npc then
		return
	end

	local old = npc:FindFirstChild("PlacedHighlight")
	if old then
		old:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlacedHighlight"
	highlight.FillColor = color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = npc

	task.delay(1.5, function()
		if highlight then
			TweenService:Create(
				highlight,
				TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					FillTransparency = 1,
					OutlineTransparency = 1,
				}
			):Play()

			task.delay(0.4, function()
				if highlight then
					highlight:Destroy()
				end
			end)
		end
	end)
end

local function worldBurst(position, color)
	local anchor = Instance.new("Part")
	anchor.Name = "PlacedBurstAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position + Vector3.new(0, 3, 0)
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlacedBillboard"
	billboard.Size = UDim2.new(0, 220, 0, 70)
	billboard.StudsOffset = Vector3.new(0, 1.8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 150
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundColor3 = color
	holder.BackgroundTransparency = 0.04
	holder.BorderSizePixel = 0
	holder.Parent = billboard

	addCorner(holder, 18)
	addStroke(holder, Color3.fromRGB(0, 0, 0), 4)
	addGradient(holder, color:Lerp(Color3.fromRGB(255, 255, 255), 0.25), color)

	makeText(
		holder,
		"Text",
		"PLACED!",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		32,
		Color3.fromRGB(255, 255, 255),
		2
	)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = holder

	TweenService:Create(
		scale,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Scale = 1,
		}
	):Play()

	task.delay(0.9, function()
		if holder then
			TweenService:Create(
				holder,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					BackgroundTransparency = 1,
				}
			):Play()

			for _, obj in ipairs(holder:GetDescendants()) do
				if obj:IsA("TextLabel") then
					TweenService:Create(obj, TweenInfo.new(0.25), {
						TextTransparency = 1,
					}):Play()
				elseif obj:IsA("UIStroke") then
					TweenService:Create(obj, TweenInfo.new(0.25), {
						Transparency = 1,
					}):Play()
				end
			end
		end

		task.delay(0.3, function()
			if anchor then
				anchor:Destroy()
			end
		end)
	end)
end

local function screenToast(npcName, rarity, mps, color)
	local old = playerGui:FindFirstChild("BrainrotPlacedMomentGui")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotPlacedMomentGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 245
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, -90)
	card.Size = UDim2.new(0, 410, 0, 82)
	card.BackgroundColor3 = Color3.fromRGB(14, 45, 70)
	card.BorderSizePixel = 0
	card.ZIndex = 250
	card.Parent = gui

	addCorner(card, 20)
	addStroke(card, Color3.fromRGB(0, 0, 0), 4)
	addGradient(card, Color3.fromRGB(28, 88, 130), Color3.fromRGB(5, 18, 35))

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Position = UDim2.new(0, 10, 0, 10)
	pill.Size = UDim2.new(0, 90, 0, 62)
	pill.BackgroundColor3 = color
	pill.BorderSizePixel = 0
	pill.ZIndex = 251
	pill.Parent = card

	addCorner(pill, 16)
	addStroke(pill, Color3.fromRGB(0, 0, 0), 3)
	addGradient(pill, color:Lerp(Color3.fromRGB(255, 255, 255), 0.25), color)

	makeText(
		pill,
		"Placed",
		"PLACED",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		20,
		Color3.fromRGB(255, 255, 255),
		252
	)

	local title = makeText(
		card,
		"Title",
		npcName,
		UDim2.new(0, 108, 0, 8),
		UDim2.new(1, -118, 0, 34),
		24,
		Color3.fromRGB(255, 255, 255),
		252
	)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local subtitle = makeText(
		card,
		"Subtitle",
		rarity .. " • income started: $" .. formatMoney(mps) .. "/s",
		UDim2.new(0, 108, 0, 42),
		UDim2.new(1, -118, 0, 28),
		17,
		Color3.fromRGB(255, 230, 80),
		252
	)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left

	TweenService:Create(
		card,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0.5, 0, 0, 92),
		}
	):Play()

	task.delay(1.8, function()
		if not gui.Parent then
			return
		end

		TweenService:Create(
			card,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.new(0.5, 0, 0, -100),
			}
		):Play()

		task.delay(0.3, function()
			if gui then
				gui:Destroy()
			end
		end)
	end)
end

local function showPlaced(data)
	if typeof(data) ~= "table" then
		return
	end

	local now = os.clock()
	if now - lastAt < 0.45 then
		return
	end

	local npcId = tostring(data.npcId or data.id or "")
	local npcName = tostring(data.npcName or data.name or "Brainrot")
	local rarity = tostring(data.rarity or "Common")
	local mps = tonumber(data.mps or data.MPS or data.cashPerSecond or 0) or 0
	local position = data.position

	local key = npcId .. "_" .. npcName
	if shownRecently[key] and now - shownRecently[key] < 6 then
		return
	end

	lastAt = now
	shownRecently[key] = now

	local color = getRarityColor(rarity)
	local npc = findNPC(npcId, npcName)

	playSound()
	glowNPC(npc, color)
	screenToast(npcName, rarity, mps, color)

	if typeof(position) == "Vector3" then
		worldBurst(position, color)
	elseif npc and npc:IsA("Model") then
		local pivot = npc:GetPivot()
		worldBurst(pivot.Position, color)
	end
end

remote.OnClientEvent:Connect(showPlaced)

print("[BrainrotPlacedMoment] loaded")