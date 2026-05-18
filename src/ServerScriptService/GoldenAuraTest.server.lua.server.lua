local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local auraTemplate = ReplicatedStorage:WaitForChild("GoldenBrainrotAura")

local AURA_SCALE = 0.05
local HEIGHT_OFFSET = -2.8
local ROTATION_SPEED = 1.5

local activeAuras = {}

local function prepareAura(aura)
	for _, obj in ipairs(aura:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
			obj.Massless = true
			obj.Transparency = 0
			obj.Material = Enum.Material.Neon
			obj.Color = Color3.fromRGB(255, 200, 35)
		end
	end

	if aura:IsA("Model") then
		pcall(function()
			aura:ScaleTo(AURA_SCALE)
		end)
	end
end

local function attachAura(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		warn("No HumanoidRootPart found")
		return
	end

	if activeAuras[character] then
		activeAuras[character]:Destroy()
	end

	local aura = auraTemplate:Clone()
	aura.Name = "GoldenAura_ACTIVE"
	aura.Parent = workspace

	prepareAura(aura)

	activeAuras[character] = aura

	print("Golden aura attached to", character.Name)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(1)
		attachAura(character)
	end)
end)

RunService.Heartbeat:Connect(function()
	local timeNow = os.clock()

	for character, aura in pairs(activeAuras) do
		local root = character:FindFirstChild("HumanoidRootPart")

		if not root or not character.Parent then
			aura:Destroy()
			activeAuras[character] = nil
			continue
		end

		local auraCFrame =
			root.CFrame
			* CFrame.new(0, HEIGHT_OFFSET, 0)
			* CFrame.Angles(0, timeNow * ROTATION_SPEED, 0)

		aura:PivotTo(auraCFrame)
	end
end)