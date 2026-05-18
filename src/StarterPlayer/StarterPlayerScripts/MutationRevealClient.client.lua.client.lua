--!nonstrict
-- StarterPlayerScripts/MutationRevealClient.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MutationReveal")

local gui = Instance.new("ScreenGui")
gui.Name = "MutationRevealGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local activePopup = nil

local function makeColor(payload)
	return Color3.fromRGB(
		tonumber(payload.ColorR) or 255,
		tonumber(payload.ColorG) or 220,
		tonumber(payload.ColorB) or 45
	)
end

local function showMutation(payload)
	if activePopup then
		activePopup:Destroy()
		activePopup = nil
	end

	local color = makeColor(payload)
	local mutation = tostring(payload.Mutation or "Golden")
	local brainrotName = tostring(payload.BrainrotName or "Brainrot")
	local moneyMultiplier = tonumber(payload.MoneyMultiplier) or 1

	local holder = Instance.new("Frame")
	holder.Name = "MutationRevealPopup"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.28)
	holder.Size = UDim2.fromOffset(430, 135)
	holder.BackgroundColor3 = Color3.fromRGB(18, 14, 8)
	holder.BackgroundTransparency = 0.08
	holder.BorderSizePixel = 0
	holder.Parent = gui
	activePopup = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = holder

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Transparency = 0.05
	stroke.Parent = holder

	local scale = Instance.new("UIScale")
	scale.Scale = 0.65
	scale.Parent = holder

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(18, 14)
	title.Size = UDim2.new(1, -36, 0, 42)
	title.Font = Enum.Font.GothamBlack
	title.Text = mutation .. " Mutation!"
	title.TextColor3 = color
	title.TextScaled = true
	title.TextStrokeTransparency = 0.45
	title.Parent = holder

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(20, 58)
	subtitle.Size = UDim2.new(1, -40, 0, 28)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = brainrotName
	subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	subtitle.TextScaled = true
	subtitle.TextTransparency = 0.05
	subtitle.Parent = holder

	local bonus = Instance.new("TextLabel")
	bonus.Name = "Bonus"
	bonus.BackgroundTransparency = 1
	bonus.Position = UDim2.fromOffset(20, 91)
	bonus.Size = UDim2.new(1, -40, 0, 25)
	bonus.Font = Enum.Font.GothamBlack
	bonus.Text = "x" .. tostring(moneyMultiplier) .. " Money"
	bonus.TextColor3 = Color3.fromRGB(255, 240, 180)
	bonus.TextScaled = true
	bonus.Parent = holder

	TweenService:Create(
		scale,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	task.delay(2.1, function()
		if holder and holder.Parent then
			local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

			TweenService:Create(holder, fadeInfo, {
				BackgroundTransparency = 1,
			}):Play()

			TweenService:Create(stroke, fadeInfo, {
				Transparency = 1,
			}):Play()

			for _, obj in ipairs(holder:GetDescendants()) do
				if obj:IsA("TextLabel") then
					TweenService:Create(obj, fadeInfo, {
						TextTransparency = 1,
						TextStrokeTransparency = 1,
					}):Play()
				end
			end

			task.wait(0.35)

			if holder then
				holder:Destroy()
			end
		end
	end)
end

remote.OnClientEvent:Connect(showMutation)

print("[MutationRevealClient] Loaded.")
