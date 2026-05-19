--!nonstrict
-- BrainrotCatchReveal.client.lua
-- Put in: StarterPlayer > StarterPlayerScripts
-- Shows FOUND popup ONLY after player finishes holding E and picks up NPC.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remote = ReplicatedStorage:WaitForChild("BrainrotCatchFeedback")

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

local lastPopupAt = 0
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

	addStroke(label, Color3.fromRGB(0, 0, 0), math.max(2, maxSize / 10))

	return label
end

local function getRarityColor(rarity)
	return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

local function playSound()
	local sound = Instance.new("Sound")
	sound.Name = "FoundBrainrotSound"
	sound.SoundId = "rbxassetid://9120386436"
	sound.Volume = 0.4
	sound.PlaybackSpeed = 1.05
	sound.Parent = SoundService
	sound:Play()

	task.delay(3, function()
		if sound then
			sound:Destroy()
		end
	end)
end

local function makeBurst(parent, color)
	for i = 1, 16 do
		local star = Instance.new("TextLabel")
		star.Name = "BurstStar"
		star.BackgroundTransparency = 1
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.new(0.5, 0, 0.5, 0)
		star.Size = UDim2.new(0, 24, 0, 24)
		star.Text = if i % 2 == 0 then "*" else "+"
		star.Font = FONT
		star.TextScaled = true
		star.TextColor3 = color
		star.ZIndex = 300
		star.Parent = parent

		local angle = (math.pi * 2 / 16) * i
		local distance = math.random(85, 150)
		local x = math.cos(angle) * distance
		local y = math.sin(angle) * distance

		TweenService:Create(
			star,
			TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.new(0.5, x, 0.5, y),
				TextTransparency = 1,
				Rotation = math.random(-180, 180),
				Size = UDim2.new(0, 10, 0, 10),
			}
		):Play()

		task.delay(0.75, function()
			if star then
				star:Destroy()
			end
		end)
	end
end

local function showFound(data)
	if typeof(data) ~= "table" then
		return
	end

	-- IMPORTANT:
	-- Ignore old CAUGHT / touch / claim events.
	-- Only pickup after holding E should show this popup.
	if data.eventType ~= "FOUND_PICKUP" and data.pickedUp ~= true then
		return
	end

	local now = os.clock()
	if now - lastPopupAt < 0.6 then
		return
	end

	local npcName = tostring(data.npcName or data.name or "Brainrot")
	local rarity = tostring(data.rarity or "Common")
	local mps = tonumber(data.mps or data.MPS or data.cashPerSecond or data.income or 0) or 0
	local npcId = tostring(data.npcId or data.id or npcName)

	local dedupeKey = npcId .. "_" .. rarity
	if shownRecently[dedupeKey] and now - shownRecently[dedupeKey] < 4 then
		return
	end

	lastPopupAt = now
	shownRecently[dedupeKey] = now

	local rarityColor = getRarityColor(rarity)

	local old = playerGui:FindFirstChild("BrainrotCatchRevealGui")
	if old then
		old:Destroy()
	end

	playSound()

	local gui = Instance.new("ScreenGui")
	gui.Name = "BrainrotCatchRevealGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 250
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.ZIndex = 240
	dim.Parent = gui

	local shadow = Instance.new("Frame")
	shadow.Name = "CardShadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 32)
	shadow.Size = UDim2.new(0, 462, 0, 260)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.62
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 248
	shadow.Parent = gui
	addCorner(shadow, 30)

	local card = Instance.new("Frame")
	card.Name = "RevealCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, 0.5, 20)
	card.Size = UDim2.new(0, 460, 0, 260)
	card.BackgroundColor3 = Color3.fromRGB(70, 205, 255)
	card.BorderSizePixel = 0
	card.ZIndex = 250
	card.Parent = gui

	addCorner(card, 28)
	addStroke(card, Color3.fromRGB(18, 20, 34), 5)
	addGradient(card, Color3.fromRGB(72, 215, 255), Color3.fromRGB(43, 100, 230))

	local inner = Instance.new("Frame")
	inner.Name = "CreamInset"
	inner.Position = UDim2.new(0, 18, 0, 78)
	inner.Size = UDim2.new(1, -36, 1, -96)
	inner.BackgroundColor3 = Color3.fromRGB(255, 247, 218)
	inner.BorderSizePixel = 0
	inner.ZIndex = 251
	inner.Parent = card
	addCorner(inner, 22)
	addStroke(inner, Color3.fromRGB(18, 20, 34), 3)

	local shine = Instance.new("Frame")
	shine.Name = "TopShine"
	shine.Position = UDim2.new(0, 18, 0, 12)
	shine.Size = UDim2.new(1, -36, 0, 22)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.78
	shine.BorderSizePixel = 0
	shine.ZIndex = 251
	shine.Parent = card
	addCorner(shine, 14)

	local scale = Instance.new("UIScale")
	scale.Scale = 0.55
	scale.Parent = card

	makeText(
		card,
		"Found",
		"NPC FOUND!",
		UDim2.new(0, 20, 0, 16),
		UDim2.new(1, -40, 0, 58),
		46,
		Color3.fromRGB(255, 235, 84),
		252
	)

	makeText(
		card,
		"NPCName",
		npcName,
		UDim2.new(0, 28, 0, 92),
		UDim2.new(1, -40, 0, 42),
		30,
		Color3.fromRGB(46, 53, 80),
		252
	)

	local pill = Instance.new("Frame")
	pill.Name = "RarityPill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 142)
	pill.Size = UDim2.new(0, 214, 0, 42)
	pill.BackgroundColor3 = rarityColor
	pill.BorderSizePixel = 0
	pill.ZIndex = 252
	pill.Parent = card

	addCorner(pill, 18)
	addStroke(pill, Color3.fromRGB(0, 0, 0), 3)
	addGradient(pill, rarityColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25), rarityColor)

	makeText(
		pill,
		"Rarity",
		rarity,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		24,
		Color3.fromRGB(255, 255, 255),
		253
	)

	makeText(
		card,
		"Income",
		"+ $" .. formatMoney(mps) .. "/s",
		UDim2.new(0, 20, 0, 192),
		UDim2.new(1, -40, 0, 34),
		24,
		Color3.fromRGB(255, 230, 70),
		252
	)

	makeText(
		card,
		"Hint",
		"Carry it to your plot to start earning.",
		UDim2.new(0, 30, 0, 226),
		UDim2.new(1, -60, 0, 24),
		16,
		Color3.fromRGB(255, 252, 223),
		252
	)

	TweenService:Create(dim, TweenInfo.new(0.15), {
		BackgroundTransparency = 0.45,
	}):Play()

	TweenService:Create(scale, TweenInfo.new(0.23, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	makeBurst(gui, rarityColor)

	task.delay(1.55, function()
		if not gui.Parent then
			return
		end

		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.75,
		}):Play()

		TweenService:Create(card, TweenInfo.new(0.18), {
			Position = UDim2.new(0.5, 0, 0.5, -30),
			BackgroundTransparency = 1,
		}):Play()

		TweenService:Create(shadow, TweenInfo.new(0.18), {
			BackgroundTransparency = 1,
		}):Play()

		TweenService:Create(dim, TweenInfo.new(0.18), {
			BackgroundTransparency = 1,
		}):Play()

		for _, obj in ipairs(card:GetDescendants()) do
			if obj:IsA("TextLabel") then
				TweenService:Create(obj, TweenInfo.new(0.18), {
					TextTransparency = 1,
				}):Play()
			elseif obj:IsA("Frame") then
				TweenService:Create(obj, TweenInfo.new(0.18), {
					BackgroundTransparency = 1,
				}):Play()
			elseif obj:IsA("UIStroke") then
				TweenService:Create(obj, TweenInfo.new(0.18), {
					Transparency = 1,
				}):Play()
			end
		end

		task.delay(0.22, function()
			if gui then
				gui:Destroy()
			end
		end)
	end)
end

remote.OnClientEvent:Connect(showFound)

print("[BrainrotCatchReveal] loaded - FOUND on pickup only")
