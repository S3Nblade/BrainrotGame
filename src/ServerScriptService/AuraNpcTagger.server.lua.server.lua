local CollectionService = game:GetService("CollectionService")

local TAG = "FireAuraNPC"

local function tryTag(model)
	if model:IsA("Model") and model:FindFirstChildWhichIsA("Humanoid") then
		-- add your own rules here if you want (only certain NPC names, etc.)
		CollectionService:AddTag(model, TAG)
	end
end

-- tag existing NPCs
for _, d in ipairs(workspace:GetDescendants()) do
	tryTag(d)
end

-- tag future NPCs
workspace.DescendantAdded:Connect(function(d)
	tryTag(d)
end)