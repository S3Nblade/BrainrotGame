local Players = game:GetService("Players")

local PlayerVisualService = {}

local function makePixelPlayer(root)
	local old = root:FindFirstChild("PixelPlayer")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PixelPlayer"
	gui.AlwaysOnTop = false
	gui.Size = UDim2.fromOffset(78, 78)
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.Parent = root

	local body = Instance.new("Frame")
	body.Size = UDim2.fromOffset(62, 62)
	body.Position = UDim2.fromOffset(8, 8)
	body.BackgroundColor3 = Color3.fromRGB(255, 205, 82)
	body.BorderSizePixel = 0
	body.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(26, 29, 43)
	outline.Thickness = 5
	outline.Parent = body

	for _, x in ipairs({ 13, 39 }) do
		local eye = Instance.new("Frame")
		eye.Size = UDim2.fromOffset(10, 13)
		eye.Position = UDim2.fromOffset(x, 16)
		eye.BackgroundColor3 = Color3.fromRGB(27, 30, 44)
		eye.BorderSizePixel = 0
		eye.Parent = body
	end
	local shirt = Instance.new("Frame")
	shirt.Size = UDim2.new(1, 0, 0, 20)
	shirt.Position = UDim2.new(0, 0, 1, -20)
	shirt.BackgroundColor3 = Color3.fromRGB(74, 142, 255)
	shirt.BorderSizePixel = 0
	shirt.Parent = body
end

local function cleanCharacter(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Accessory") or descendant:IsA("ForceField") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CastShadow = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		elseif
			descendant:IsA("ParticleEmitter")
			or descendant:IsA("Trail")
			or descendant:IsA("Beam")
			or descendant:IsA("Smoke")
			or descendant:IsA("Fire")
			or descendant:IsA("Sparkles")
		then
			descendant:Destroy()
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		makePixelPlayer(root)
	end
end

function PlayerVisualService.Init() end

function PlayerVisualService.Start()
	local function setup(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.5)
			cleanCharacter(character)
		end)
		if player.Character then
			task.defer(cleanCharacter, player.Character)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end
end

return PlayerVisualService
