--!nonstrict
-- TungIdleAnimator.server.lua

local model = script.Parent

local function getAnimator()
	local controller = model:FindFirstChildOfClass("AnimationController")

	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = model
	end

	local animator = controller:FindFirstChildOfClass("Animator")

	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "Animator"
		animator.Parent = controller
	end

	return animator
end

local function anchorModel()
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.Massless = true
		end
	end
end

local function playIdle()
	task.wait(0.25)

	anchorModel()

	local idleId = model:GetAttribute("IdleAnimationId")

	if not idleId or tostring(idleId) == "" then
		warn("[TungIdleAnimator] Missing IdleAnimationId on", model:GetFullName())
		return
	end

	idleId = tostring(idleId):gsub("rbxassetid://", "")

	local animation = Instance.new("Animation")
	animation.Name = "TungTungSahurIdle"
	animation.AnimationId = "rbxassetid://" .. idleId

	local animator = getAnimator()

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok then
		warn("[TungIdleAnimator] Failed to load animation:", track)
		return
	end

	track.Name = "TungIdleTrack"
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.15, 1, 1)

	print("[TungIdleAnimator] Playing idle animation for", model:GetFullName())
end

model.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") then
		obj.Anchored = true
		obj.CanCollide = false
		obj.CanTouch = false
		obj.Massless = true
	end
end)

playIdle()
