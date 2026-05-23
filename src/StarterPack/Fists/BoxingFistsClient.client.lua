
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local player = Players.LocalPlayer
local tool = script.Parent
local hitRemote = ReplicatedStorage:WaitForChild("BoxingFistsSystem"):WaitForChild("Hit")

local tracks = nil
local currentHumanoid = nil
local busy = false
local combo = 0

local COMBO = {"Jab", "Cross", "Hook"}

local PUNCH_INFO = {
	Jab = {
		length = 0.32,
		hitTime = 0.13,
	},
	Cross = {
		length = 0.46,
		hitTime = 0.20,
	},
	Hook = {
		length = 0.44,
		hitTime = 0.17,
	},
}

local function priority()
	local ok, p = pcall(function()
		return Enum.AnimationPriority.Action4
	end)

	if ok and p then
		return p
	end

	return Enum.AnimationPriority.Action
end

local function C(rx, ry, rz, x, y, z)
	return CFrame.new(x or 0, y or 0, z or 0)
		* CFrame.Angles(
			math.rad(rx or 0),
			math.rad(ry or 0),
			math.rad(rz or 0)
		)
end

local function makePose(name, cf)
	local pose = Instance.new("Pose")
	pose.Name = name
	pose.Weight = 1
	pose.CFrame = cf or CFrame.new()

	pcall(function()
		pose.EasingStyle = Enum.PoseEasingStyle.Cubic
	end)

	pcall(function()
		pose.EasingDirection = Enum.PoseEasingDirection.InOut
	end)

	return pose
end

local function makeSequence(name, looped)
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "BoxingFists_" .. name

	pcall(function()
		seq.Loop = looped
	end)

	pcall(function()
		seq.Priority = priority()
	end)

	return seq
end

local function addR15Key(seq, t, p)
	local key = Instance.new("Keyframe")
	key.Time = t
	key.Name = "Key_" .. tostring(t)

	local root = makePose("HumanoidRootPart", p.HumanoidRootPart)
	local lower = makePose("LowerTorso", p.LowerTorso)
	local upper = makePose("UpperTorso", p.UpperTorso)
	local head = makePose("Head", p.Head)

	local rua = makePose("RightUpperArm", p.RightUpperArm)
	local rla = makePose("RightLowerArm", p.RightLowerArm)
	local rh = makePose("RightHand", p.RightHand)

	local lua = makePose("LeftUpperArm", p.LeftUpperArm)
	local lla = makePose("LeftLowerArm", p.LeftLowerArm)
	local lh = makePose("LeftHand", p.LeftHand)

	root.Parent = key
	lower.Parent = root
	upper.Parent = lower
	head.Parent = upper

	rua.Parent = upper
	rla.Parent = rua
	rh.Parent = rla

	lua.Parent = upper
	lla.Parent = lua
	lh.Parent = lla

	key.Parent = seq
end

local function addR6Key(seq, t, p)
	local key = Instance.new("Keyframe")
	key.Time = t
	key.Name = "Key_" .. tostring(t)

	local root = makePose("HumanoidRootPart", p.HumanoidRootPart)
	local torso = makePose("Torso", p.Torso)
	local head = makePose("Head", p.Head)
	local rightArm = makePose("Right Arm", p.RightArm)
	local leftArm = makePose("Left Arm", p.LeftArm)

	root.Parent = key
	torso.Parent = root
	head.Parent = torso
	rightArm.Parent = torso
	leftArm.Parent = torso

	key.Parent = seq
end

local R15_GUARD = {
	UpperTorso = C(0, 0, 0),

	RightUpperArm = C(-42, -4, 22),
	RightLowerArm = C(-62, 0, -8),
	RightHand = C(0, 0, 0),

	LeftUpperArm = C(-42, 4, -22),
	LeftLowerArm = C(-62, 0, 8),
	LeftHand = C(0, 0, 0),
}

local R6_GUARD = {
	Torso = C(0, 0, 0),
	RightArm = C(-85, 0, 25),
	LeftArm = C(-85, 0, -25),
}

local function buildR15(name)
	local seq = makeSequence("R15_" .. name, name == "Guard")

	if name == "Guard" then
		addR15Key(seq, 0.00, R15_GUARD)
		addR15Key(seq, 0.30, {
			UpperTorso = C(0, 0, 1),
			RightUpperArm = C(-43, -4, 23),
			RightLowerArm = C(-63, 0, -8),
			LeftUpperArm = C(-41, 4, -21),
			LeftLowerArm = C(-63, 0, 8),
		})
		addR15Key(seq, 0.60, R15_GUARD)

	elseif name == "Jab" then
		addR15Key(seq, 0.00, R15_GUARD)
		addR15Key(seq, 0.07, {
			UpperTorso = C(0, 0, -4),
			LeftUpperArm = C(-36, 12, -32),
			LeftLowerArm = C(-78, 0, 10),

			RightUpperArm = C(-46, -4, 24),
			RightLowerArm = C(-70, 0, -8),
		})
		addR15Key(seq, 0.13, {
			UpperTorso = C(0, 0, 7),
			LeftUpperArm = C(-94, 0, -5),
			LeftLowerArm = C(-4, 0, -4),
			LeftHand = C(0, 0, 4),

			RightUpperArm = C(-48, -4, 25),
			RightLowerArm = C(-72, 0, -8),
		})
		addR15Key(seq, 0.21, {
			UpperTorso = C(0, 0, 3),
			LeftUpperArm = C(-70, 6, -16),
			LeftLowerArm = C(-30, 0, 0),
		})
		addR15Key(seq, 0.32, R15_GUARD)

	elseif name == "Cross" then
		addR15Key(seq, 0.00, R15_GUARD)
		addR15Key(seq, 0.10, {
			LowerTorso = C(0, 0, -4),
			UpperTorso = C(0, 0, -12),

			RightUpperArm = C(-34, -18, 36),
			RightLowerArm = C(-88, 0, -12),
			RightHand = C(0, 0, -5),

			LeftUpperArm = C(-50, 4, -25),
			LeftLowerArm = C(-72, 0, 8),
		})
		addR15Key(seq, 0.20, {
			LowerTorso = C(0, 0, 6),
			UpperTorso = C(0, 0, 18),

			RightUpperArm = C(-103, -2, 8),
			RightLowerArm = C(-3, 0, -5),
			RightHand = C(0, 0, 5),

			LeftUpperArm = C(-52, 4, -27),
			LeftLowerArm = C(-78, 0, 8),
		})
		addR15Key(seq, 0.29, {
			LowerTorso = C(0, 0, 7),
			UpperTorso = C(0, 0, 16),
			RightUpperArm = C(-100, -2, 8),
			RightLowerArm = C(-3, 0, -5),
		})
		addR15Key(seq, 0.38, {
			UpperTorso = C(0, 0, -4),
			RightUpperArm = C(-50, -12, 28),
			RightLowerArm = C(-68, 0, -10),
		})
		addR15Key(seq, 0.46, R15_GUARD)

	elseif name == "Hook" then
		addR15Key(seq, 0.00, R15_GUARD)
		addR15Key(seq, 0.08, {
			LowerTorso = C(0, 0, -7),
			UpperTorso = C(0, 0, -17),

			RightUpperArm = C(-48, -28, 48),
			RightLowerArm = C(-78, 0, -16),
			RightHand = C(0, 0, -8),

			LeftUpperArm = C(-50, 4, -25),
			LeftLowerArm = C(-76, 0, 8),
		})
		addR15Key(seq, 0.17, {
			LowerTorso = C(0, 0, 10),
			UpperTorso = C(0, 0, 26),

			RightUpperArm = C(-62, 28, 62),
			RightLowerArm = C(-76, 0, -18),
			RightHand = C(0, 0, 12),

			LeftUpperArm = C(-52, 4, -28),
			LeftLowerArm = C(-80, 0, 8),
		})
		addR15Key(seq, 0.28, {
			UpperTorso = C(0, 0, 9),
			RightUpperArm = C(-55, 12, 38),
			RightLowerArm = C(-72, 0, -8),
		})
		addR15Key(seq, 0.44, R15_GUARD)
	end

	return seq
end

local function buildR6(name)
	local seq = makeSequence("R6_" .. name, name == "Guard")

	if name == "Guard" then
		addR6Key(seq, 0.00, R6_GUARD)
		addR6Key(seq, 0.30, {
			Torso = C(0, 0, 1),
			RightArm = C(-86, 0, 26),
			LeftArm = C(-86, 0, -26),
		})
		addR6Key(seq, 0.60, R6_GUARD)

	elseif name == "Jab" then
		addR6Key(seq, 0.00, R6_GUARD)
		addR6Key(seq, 0.07, {
			Torso = C(0, 0, -4),
			LeftArm = C(-65, 10, -36),
			RightArm = C(-90, 0, 25),
		})
		addR6Key(seq, 0.13, {
			Torso = C(0, 0, 8),
			LeftArm = C(-130, 0, -6),
			RightArm = C(-92, 0, 26),
		})
		addR6Key(seq, 0.22, {
			Torso = C(0, 0, 3),
			LeftArm = C(-90, 4, -20),
		})
		addR6Key(seq, 0.32, R6_GUARD)

	elseif name == "Cross" then
		addR6Key(seq, 0.00, R6_GUARD)
		addR6Key(seq, 0.10, {
			Torso = C(0, 0, -13),
			RightArm = C(-62, -18, 40),
			LeftArm = C(-92, 0, -28),
		})
		addR6Key(seq, 0.20, {
			Torso = C(0, 0, 20),
			RightArm = C(-138, 0, 6),
			LeftArm = C(-96, 0, -30),
		})
		addR6Key(seq, 0.35, {
			Torso = C(0, 0, 4),
			RightArm = C(-90, -8, 24),
		})
		addR6Key(seq, 0.46, R6_GUARD)

	elseif name == "Hook" then
		addR6Key(seq, 0.00, R6_GUARD)
		addR6Key(seq, 0.08, {
			Torso = C(0, 0, -18),
			RightArm = C(-75, -25, 55),
			LeftArm = C(-92, 0, -28),
		})
		addR6Key(seq, 0.17, {
			Torso = C(0, 0, 28),
			RightArm = C(-95, 28, 65),
			LeftArm = C(-96, 0, -30),
		})
		addR6Key(seq, 0.30, {
			Torso = C(0, 0, 8),
			RightArm = C(-85, 8, 36),
		})
		addR6Key(seq, 0.44, R6_GUARD)
	end

	return seq
end

local function registerTrack(humanoid, seq)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(seq)
	end)

	if not ok then
		warn("[BoxingFists] Failed to register animation:", id)
		return nil
	end

	local anim = Instance.new("Animation")
	anim.Name = seq.Name
	anim.AnimationId = id

	local track
	local loaded, err = pcall(function()
		track = animator:LoadAnimation(anim)
	end)

	if not loaded then
		warn("[BoxingFists] Failed to load animation:", err)
		return nil
	end

	pcall(function()
		track.Priority = priority()
	end)

	return track
end

local function stopAll()
	if not tracks then
		return
	end

	for _, track in pairs(tracks) do
		pcall(function()
			track:Stop(0.05)
		end)
	end
end

local function getHumanoid()
	local character = tool.Parent

	if not character or not character:IsA("Model") then
		character = player.Character
	end

	if not character then
		return nil, nil
	end

	return character:FindFirstChildOfClass("Humanoid"), character
end

local function loadTracks(humanoid)
	if tracks and currentHumanoid == humanoid then
		return tracks
	end

	stopAll()

	currentHumanoid = humanoid
	tracks = {}

	local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local builder = isR15 and buildR15 or buildR6

	for _, name in ipairs({"Guard", "Jab", "Cross", "Hook"}) do
		local seq = builder(name)
		local track = registerTrack(humanoid, seq)

		if track then
			pcall(function()
				track.Looped = name == "Guard"
			end)

			tracks[name] = track
		end
	end

	print("[BoxingFists] Loaded boxing animations for", isR15 and "R15" or "R6")
	return tracks
end

tool.Equipped:Connect(function()
	local humanoid = getHumanoid()

	if not humanoid then
		warn("[BoxingFists] No humanoid found.")
		return
	end

	local loadedTracks = loadTracks(humanoid)

	if loadedTracks.Guard then
		loadedTracks.Guard:Play(0.12, 1, 1)
	end
end)

tool.Unequipped:Connect(function()
	stopAll()
end)

tool.Activated:Connect(function()
	if busy then
		return
	end

	local humanoid, character = getHumanoid()

	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local loadedTracks = loadTracks(humanoid)

	combo = combo % #COMBO + 1

	local punchName = COMBO[combo]
	local punchTrack = loadedTracks[punchName]
	local info = PUNCH_INFO[punchName]

	if not punchTrack then
		warn("[BoxingFists] Missing punch track:", punchName)
		return
	end

	busy = true

	if loadedTracks.Guard then
		loadedTracks.Guard:Stop(0.05)
	end

	print("[BoxingFists] Punch:", punchName)
	punchTrack:Play(0.04, 1, 1)

	task.delay(info.hitTime, function()
		if tool.Parent == character then
			hitRemote:FireServer(punchName)
		end
	end)

	task.wait(info.length)

	if tool.Parent == character and loadedTracks.Guard then
		loadedTracks.Guard:Play(0.08, 1, 1)
	end

	task.wait(0.04)
	busy = false
end)

