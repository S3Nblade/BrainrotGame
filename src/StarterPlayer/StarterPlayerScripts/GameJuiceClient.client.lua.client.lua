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

dailyRewardRemote.OnClientEvent:Connect(function(data)
	showAnnouncement({
		text = tostring(data.message or "Daily reward claimed!"),
		color = data.success and { R = 80, G = 255, B = 120 } or { R = 255, G = 90, B = 90 },
	})
end)

worldEventRemote.OnClientEvent:Connect(updateWorldEvent)

zoneGateRemote.OnClientEvent:Connect(function(data)
	showAnnouncement({
		text = tostring(data.message or "Zone locked."),
		color = { R = 255, G = 90, B = 90 },
	})
end)

print("[GameJuiceClient] Loaded.")