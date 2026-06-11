local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local EffectsController = {}
local context

local function worldPopup(position, text, color)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace
	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(100, 55)
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = gui
	TweenService
		:Create(anchor, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Position = position + Vector3.new(0, 6, 0) })
		:Play()
	TweenService:Create(label, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(anchor, 0.8)
	return anchor
end

function EffectsController.Init(newContext)
	context = newContext
end

function EffectsController.Start()
	context.Remotes.DamagePopup.OnClientEvent:Connect(function(position, amount, critical)
		worldPopup(
			position,
			critical and ("CRIT! -" .. amount) or ("-" .. amount),
			critical and Color3.fromRGB(255, 226, 74) or Color3.fromRGB(255, 92, 92)
		)
	end)
	context.Remotes.CaptureEffect.OnClientEvent:Connect(function(position, color)
		for index = 1, 10 do
			task.delay(index * 0.025, function()
				local angle = math.pi * 2 * index / 10
				local anchor = worldPopup(position, "+", color:Lerp(Color3.new(1, 1, 1), 0.35))
				anchor.Position += Vector3.new(math.cos(angle) * 2, 0, math.sin(angle) * 2)
			end)
		end
	end)
end

return EffectsController
