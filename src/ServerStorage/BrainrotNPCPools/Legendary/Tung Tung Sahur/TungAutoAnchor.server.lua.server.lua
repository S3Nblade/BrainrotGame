--!nonstrict
-- Keeps Tung NPC anchored after it spawns.

local model = script.Parent

local function anchorPart(obj)
	if obj:IsA("BasePart") then
		obj.Anchored = true
		obj.CanCollide = false
		obj.CanTouch = false
		obj.Massless = true
	end
end

for _, obj in ipairs(model:GetDescendants()) do
	anchorPart(obj)
end

model.DescendantAdded:Connect(anchorPart)
