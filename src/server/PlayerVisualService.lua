local Players = game:GetService("Players")

local PlayerVisualService = {}

local function cleanCharacter(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if
			descendant:IsA("Accessory")
			or descendant:IsA("ParticleEmitter")
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
