local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local InputController = {}
local player = Players.LocalPlayer
local context

local function closestBrainrot(requireStunned)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best
	local bestDistance = math.huge
	for _, model in ipairs(CollectionService:GetTagged("Brainrot")) do
		local modelRoot = model.PrimaryPart
		if modelRoot then
			local stunned = model:GetAttribute("Stunned") == true
			if stunned == requireStunned then
				local distance = (root.Position - modelRoot.Position).Magnitude
				if distance < bestDistance then
					best = model
					bestDistance = distance
				end
			end
		end
	end
	return best, bestDistance
end

local function attack(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local model, distance = closestBrainrot(false)
	if model and distance <= context.Config.Economy.AttackRange then
		context.Remotes.AttackRequest:FireServer(model)
	end
	return Enum.ContextActionResult.Sink
end

local function capture(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local model, distance = closestBrainrot(true)
	if model and distance <= context.Config.Economy.CaptureRange then
		context.Remotes.CaptureRequest:FireServer(model)
	end
	return Enum.ContextActionResult.Sink
end

function InputController.Init(newContext)
	context = newContext
end

function InputController.Start()
	ContextActionService:BindAction(
		"PixelAttack",
		attack,
		true,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle("PixelAttack", "ATTACK")
	ContextActionService:SetPosition("PixelAttack", UDim2.new(1, -150, 1, -155))
	ContextActionService:BindAction("PixelCapture", capture, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("PixelCapture", "CAPTURE")
	ContextActionService:SetPosition("PixelCapture", UDim2.new(1, -265, 1, -110))
	if not UserInputService.TouchEnabled then
		ContextActionService:SetImage("PixelAttack", "")
	end
end

return InputController
