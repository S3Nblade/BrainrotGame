--!nonstrict
-- StarterPlayerScripts/GameJuiceClient.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local rarityRevealRemote = remotesFolder:WaitForChild("RarityReveal")
local announcementRemote = remotesFolder:WaitForChild("ServerAnnouncement")
local dailyRewardRemote = remotesFolder:WaitForChild("DailyRewardResult")
local worldEventRemote = remotesFolder:WaitForChild("WorldEventUpdate")
local zoneGateRemote = remotesFolder:WaitForChild("ZoneGateFeedback")
local offlineRewardRemote = remotesFolder:WaitForChild("OfflineRewardResult")
local playtimeUpdateRemote = remotesFolder:WaitForChild("PlaytimeRewardUpdate")
local playtimeClaimRemote = remotesFolder:WaitForChild("ClaimPlaytimeReward")
local playtimeResultRemote = remotesFolder:WaitForChild("PlaytimeRewardResult")

local gui = Instance.new("ScreenGui")
gui.Name = "GameJuiceClientGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.Parent = playerGui

local function colorFromPayload(color)
	if typeof(color) == "table" then
		return Color3.fromRGB(color.R or 255, color.G or 255, color.B or 255)
	end

	return Color3.fromRGB(255, 255, 255)
end

local function formatMoney(value)
	value = tonumber(value) or 0

	if value >= 1000000000000000 then
		return string.format("%.1fQ", value / 1000000000000000)
	elseif value >= 1000000000000 then
		return string.format("%.1fT", value / 1000000000000)
	elseif value >= 1000000000 then
		return string.format("%.1fB", value / 1000000000)
	elseif value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end

	return tostring(math.floor(value))
end

local function makeText(parent, name, position, size, text, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = text or ""
	label.Parent = parent
	return label
end

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function formatTimer(seconds)
	seconds = math.max(0, math.floor(tonumber(seconds) or 0))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%d:%02d", minutes, secs)
end

local function showAnnouncement(data)
	local color = colorFromPayload(data.color)

	local frame = Instance.new("Frame")
	frame.Name = "ServerAnnouncementToast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, -80)
	frame.Size = UDim2.fromOffset(620, 58)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = frame

	local label = makeText(
		frame,
		"Text",
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1),
		tostring(data.text or "Announcement"),
		color
	)

	TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 36),
	}):Play()

	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	task.delay(3.2, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, -80),
			}):Play()

			TweenService:Create(label, TweenInfo.new(0.22), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()

			Debris:AddItem(frame, 0.3)
		end
	end)
end

local function showRarityReveal(data)
	local color = colorFromPayload(data.color)

	local frame = Instance.new("Frame")
	frame.Name = "RarityReveal"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.48)
	frame.Size = UDim2.fromOffset(420, 250)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0.35
	scale.Parent = frame

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(230, 230)
	ring.BackgroundTransparency = 0.25
	ring.BackgroundColor3 = color
	ring.BorderSizePixel = 0
	ring.Rotation = 0
	ring.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 8
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = ring

	local rarityLabel = makeText(
		frame,
		"Rarity",
		UDim2.new(0.05, 0, 0.06, 0),
		UDim2.new(0.9, 0, 0.22, 0),
		tostring(data.rarity or "Common"),
		color
	)

	local nameLabel = makeText(
		frame,
		"Name",
		UDim2.new(0.05, 0, 0.32, 0),
		UDim2.new(0.9, 0, 0.28, 0),
		tostring(data.name or "Brainrot"),
		Color3.fromRGB(255, 255, 255)
	)

	local infoLabel = makeText(
		frame,
		"Info",
		UDim2.new(0.05, 0, 0.65, 0),
		UDim2.new(0.9, 0, 0.2, 0),
		"$" .. formatMoney(data.mps or 1) .. "/s  •  " .. tostring(data.mutation or "Normal"),
		Color3.fromRGB(230, 255, 230)
	)

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	TweenService:Create(ring, TweenInfo.new(1.4, Enum.EasingStyle.Linear), {
		Rotation = 360,
		BackgroundTransparency = 0.65,
	}):Play()

	task.delay(2.5, function()
		if frame.Parent then
			for _, obj in ipairs(frame:GetDescendants()) do
				if obj:IsA("TextLabel") then
					TweenService:Create(obj, TweenInfo.new(0.25), {
						TextTransparency = 1,
						TextStrokeTransparency = 1,
					}):Play()
				elseif obj:IsA("Frame") then
					TweenService:Create(obj, TweenInfo.new(0.25), {
						BackgroundTransparency = 1,
					}):Play()
				elseif obj:IsA("UIStroke") then
					TweenService:Create(obj, TweenInfo.new(0.25), {
						Transparency = 1,
					}):Play()
				end
			end

			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0.65,
			}):Play()

			Debris:AddItem(frame, 0.35)
		end
	end)
end

local eventFrame = Instance.new("Frame")
eventFrame.Name = "WorldEventBanner"
eventFrame.AnchorPoint = Vector2.new(0.5, 0)
eventFrame.Position = UDim2.new(0.5, 0, 0, 95)
eventFrame.Size = UDim2.fromOffset(480, 42)
eventFrame.BackgroundTransparency = 1
eventFrame.Visible = false
eventFrame.Parent = gui

local eventLabel = makeText(
	eventFrame,
	"Text",
	UDim2.fromScale(0, 0),
	UDim2.fromScale(1, 1),
	"",
	Color3.fromRGB(255, 255, 255)
)

local giftFrame = Instance.new("Frame")
giftFrame.Name = "PlaytimeGift"
giftFrame.AnchorPoint = Vector2.new(1, 0)
giftFrame.Position = UDim2.new(1, -18, 0, 226)
giftFrame.Size = UDim2.fromOffset(218, 74)
giftFrame.BackgroundColor3 = Color3.fromRGB(72, 192, 255)
giftFrame.BorderSizePixel = 0
giftFrame.Visible = false
giftFrame.Parent = gui
addCorner(giftFrame, 16)
addStroke(giftFrame, Color3.fromRGB(25, 35, 66), 3, 0)

local giftGradient = Instance.new("UIGradient")
giftGradient.Rotation = 90
giftGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(111, 225, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(41, 105, 236)),
})
giftGradient.Parent = giftFrame

local giftScale = Instance.new("UIScale")
giftScale.Scale = 1
giftScale.Parent = giftFrame

local giftTitle = makeText(
	giftFrame,
	"Title",
	UDim2.fromOffset(12, 5),
	UDim2.fromOffset(120, 24),
	"FREE GIFT",
	Color3.fromRGB(255, 255, 255)
)
giftTitle.TextXAlignment = Enum.TextXAlignment.Left

local giftReward = makeText(
	giftFrame,
	"Reward",
	UDim2.fromOffset(12, 31),
	UDim2.fromOffset(102, 28),
	"$750",
	Color3.fromRGB(255, 246, 122)
)
giftReward.TextXAlignment = Enum.TextXAlignment.Left

local giftButton = Instance.new("TextButton")
giftButton.Name = "GiftButton"
giftButton.Position = UDim2.fromOffset(127, 18)
giftButton.Size = UDim2.fromOffset(78, 38)
giftButton.BackgroundColor3 = Color3.fromRGB(86, 239, 92)
giftButton.BorderSizePixel = 0
giftButton.AutoButtonColor = false
giftButton.Text = "CLAIM"
giftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
giftButton.TextScaled = true
giftButton.Font = Enum.Font.FredokaOne
giftButton.Parent = giftFrame
addCorner(giftButton, 12)
addStroke(giftButton, Color3.fromRGB(24, 98, 36), 2, 0)

local giftButtonConstraint = Instance.new("UITextSizeConstraint")
giftButtonConstraint.MaxTextSize = 16
giftButtonConstraint.MinTextSize = 8
giftButtonConstraint.Parent = giftButton

local giftReady = false

local function setGiftReady(ready)
	giftReady = ready
	giftButton.Text = ready and "CLAIM" or "WAIT"
	giftButton.BackgroundColor3 = ready and Color3.fromRGB(86, 239, 92) or Color3.fromRGB(120, 142, 179)
end

local function showOfflineReward(data)
	if type(data) ~= "table" or data.success ~= true then
		return
	end

	local frame = Instance.new("Frame")
	frame.Name = "OfflineReward"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.46)
	frame.Size = UDim2.fromOffset(440, 230)
	frame.BackgroundColor3 = Color3.fromRGB(94, 214, 255)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	addCorner(frame, 24)
	addStroke(frame, Color3.fromRGB(25, 35, 66), 4, 0)

	local frameGradient = Instance.new("UIGradient")
	frameGradient.Rotation = 90
	frameGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 236, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(63, 120, 255)),
	})
	frameGradient.Parent = frame

	local frameScale = Instance.new("UIScale")
	frameScale.Scale = 0.58
	frameScale.Parent = frame

	local title = makeText(
		frame,
		"Title",
		UDim2.new(0.07, 0, 0.08, 0),
		UDim2.new(0.86, 0, 0.22, 0),
		"WELCOME BACK!",
		Color3.fromRGB(255, 255, 255)
	)

	local away = makeText(
		frame,
		"Away",
		UDim2.new(0.08, 0, 0.31, 0),
		UDim2.new(0.84, 0, 0.14, 0),
		"Away for " .. tostring(data.awayText or "a while"),
		Color3.fromRGB(225, 255, 255)
	)

	local earned = makeText(
		frame,
		"Earned",
		UDim2.new(0.05, 0, 0.48, 0),
		UDim2.new(0.9, 0, 0.28, 0),
		"+" .. tostring(data.moneyText or "$0"),
		Color3.fromRGB(255, 244, 95)
	)

	local note = makeText(
		frame,
		"Note",
		UDim2.new(0.1, 0, 0.78, 0),
		UDim2.new(0.8, 0, 0.12, 0),
		"Your Brainrots kept earning offline",
		Color3.fromRGB(255, 255, 255)
	)

	TweenService:Create(
		frameScale,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	for i = 1, 16 do
		local coin = makeText(
			frame,
			"OfflineCoin" .. tostring(i),
			UDim2.fromScale(0.5, 0.56),
			UDim2.fromOffset(32, 32),
			"$",
			Color3.fromRGB(255, 233, 80)
		)
		coin.AnchorPoint = Vector2.new(0.5, 0.5)

		local angle = (math.pi * 2 * i) / 16
		local distance = 88 + ((i % 5) * 10)
		TweenService:Create(
			coin,
			TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{
				Position = UDim2.new(0.5, math.cos(angle) * distance, 0.56, math.sin(angle) * distance),
				Rotation = (i % 2 == 0 and 35 or -35),
			}
		):Play()
	end

	task.delay(3.2, function()
		if not frame.Parent then
			return
		end

		TweenService:Create(
			frameScale,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.72 }
		):Play()

		for _, obj in ipairs(frame:GetDescendants()) do
			if obj:IsA("TextLabel") then
				TweenService:Create(obj, TweenInfo.new(0.2), {
					TextTransparency = 1,
					TextStrokeTransparency = 1,
				}):Play()
			elseif obj:IsA("Frame") then
				TweenService:Create(obj, TweenInfo.new(0.2), {
					BackgroundTransparency = 1,
				}):Play()
			elseif obj:IsA("UIStroke") then
				TweenService:Create(obj, TweenInfo.new(0.2), {
					Transparency = 1,
				}):Play()
			end
		end

		Debris:AddItem(frame, 0.3)
	end)
end

local function popGift()
	giftScale.Scale = 1.08
	TweenService:Create(
		giftScale,
		TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

local function updatePlaytimeGift(data)
	if type(data) ~= "table" then
		return
	end

	if data.done == true then
		giftFrame.Visible = false
		return
	end

	giftFrame.Visible = true
	giftTitle.Text = "FREE GIFT " .. tostring(data.index or 1) .. "/" .. tostring(data.total or 1)
	giftReward.Text = tostring(data.moneyText or "$0")

	if data.ready == true then
		setGiftReady(true)
	else
		setGiftReady(false)
		giftButton.Text = formatTimer(data.remaining)
	end
end

giftButton.MouseEnter:Connect(function()
	TweenService:Create(giftButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(82, 40) }):Play()
end)

giftButton.MouseLeave:Connect(function()
	TweenService:Create(giftButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(78, 38) }):Play()
end)

giftButton.MouseButton1Click:Connect(function()
	if giftReady then
		playtimeClaimRemote:FireServer()
		setGiftReady(false)
		popGift()
	end
end)

local function updateWorldEvent(data)
	if not data.active then
		eventFrame.Visible = false
		return
	end

	eventFrame.Visible = true
	eventLabel.Text = tostring(data.displayName or data.name or "World Event") .. "  •  " .. tostring(data.timeLeft or 0) .. "s"
	eventLabel.TextColor3 = colorFromPayload(data.color)
end

rarityRevealRemote.OnClientEvent:Connect(showRarityReveal)
announcementRemote.OnClientEvent:Connect(showAnnouncement)
offlineRewardRemote.OnClientEvent:Connect(showOfflineReward)

dailyRewardRemote.OnClientEvent:Connect(function(data)
	showAnnouncement({
		text = tostring(data.message or "Daily reward claimed!"),
		color = data.success and { R = 80, G = 255, B = 120 } or { R = 255, G = 90, B = 90 },
	})
end)

worldEventRemote.OnClientEvent:Connect(updateWorldEvent)
playtimeUpdateRemote.OnClientEvent:Connect(updatePlaytimeGift)

playtimeResultRemote.OnClientEvent:Connect(function(data)
	showAnnouncement({
		text = tostring(data.message or "Free gift claimed!"),
		color = { R = 90, G = 255, B = 130 },
	})
	popGift()
end)

zoneGateRemote.OnClientEvent:Connect(function(data)
	showAnnouncement({
		text = tostring(data.message or "Zone locked."),
		color = { R = 255, G = 90, B = 90 },
	})
end)

print("[GameJuiceClient] Loaded.")
