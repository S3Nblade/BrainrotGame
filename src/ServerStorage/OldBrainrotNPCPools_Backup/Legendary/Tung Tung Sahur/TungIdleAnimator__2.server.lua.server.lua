--!nonstrict
-- TungIdleAnimator.server.lua
-- Plays imported idle animation when this NPC spawns.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

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

local function makeAnimationFromId(id)
	if typeof(id) == "number" then
		id = tostring(id)
	end

	if typeof(id) ~= "string" or id == "" or id == "0" then
		return nil
	end

	if not id:match("^rbxassetid://") then
		id = "rbxassetid://" .. id
	end

	local animation = Instance.new("Animation")
	animation.Name = "TungUploadedIdle"
	animation.AnimationId = id

	return animation
end

local function findAnimationObject()
	local uploadedIdleId = model:GetAttribute("IdleAnimationId")
	local uploadedAnimation = makeAnimationFromId(uploadedIdleId)

	if uploadedAnimation then
		return uploadedAnimation
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("Animation") and obj.AnimationId ~= "" then
			return obj
		end
	end

	local animSaves = model:FindFirstChild("AnimSaves", true)

	if animSaves and animSaves:IsA("KeyframeSequence") then
		local ok, temporaryId = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(animSaves)
		end)

		if ok and temporaryId then
			local animation = Instance.new("Animation")
			animation.Name = "TungTemporaryIdle"
			animation.AnimationId = temporaryId
			return animation
		end
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("KeyframeSequence") then
			local ok, temporaryId = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(obj)
			end)

			if ok and temporaryId then
				local animation = Instance.new("Animation")
				animation.Name = "TungTemporaryIdle"
				animation.AnimationId = temporaryId
				return animation
			end
		end
	end

	return nil
end

local function playIdle()
	task.wait(0.2)

	local animator = getAnimator()
	local animation = findAnimationObject()

	if not animation then
		warn("[TungIdleAnimator] No playable animation found. Upload the idle animation and set the model attribute IdleAnimationId.")
		return
	end

	local ok, trackOrError = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not ok then
		warn("[TungIdleAnimator] Failed to load idle animation:", trackOrError)
		return
	end

	local track = trackOrError
	track.Name = "TungIdleTrack"
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Idle
	track:Play(0.15, 1, 1)

	print("[TungIdleAnimator] Playing idle animation for", model:GetFullName())
end

playIdle()
