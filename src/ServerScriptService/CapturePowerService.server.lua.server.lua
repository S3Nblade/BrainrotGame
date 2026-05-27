-- ServerScriptService/CapturePowerService.server.lua
-- Full replacement
-- Timed chase/capture system:
-- First hit starts a capture timer.
-- If NPC HP reaches 0 before timer ends = stunned and can be picked up.
-- If timer ends first = NPC heals, gains shield, panics, and runs away.

--!nonstrict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local NPC_FOLDER = Workspace:WaitForChild("BrainrotNPCs")
local HIDE_SPOTS_FOLDER = Workspace:FindFirstChild("HideSpots")
local ESCAPE_POINTS_FOLDER = Workspace:FindFirstChild("EscapePoints")

local REQUEST_REMOTE_NAME = "CaptureNPCRequest"
local FEEDBACK_REMOTE_NAME = "CaptureHitFeedback"
local UPDATE_REMOTE_NAME = "UpdateCaptureStats"
local NOTIFY_REMOTE_NAME = "NotifyUser"

local HIT_RANGE = 18
local HIT_COOLDOWN = 0.45
local STUN_DURATION = 8

local DEFAULT_CATCH_POWER = 5
local DEFAULT_CATCH_RANGE = HIT_RANGE

local STRENGTH_DAMAGE_MULTIPLIER = 0.08

local SHIELD_DURATION = 5
local PANIC_DURATION = 8.5

local RARITY_CAPTURE_HP = {
	Common = 45,
	Rare = 80,
	Epic = 140,
	Mythic = 230,
	Legendary = 360,
	Divine = 550,
	Celestial = 800,
	Godly = 1150,
}

local RARITY_CAPTURE_TIME = {
	Common = 18,
	Rare = 16,
	Epic = 14,
	Mythic = 12,
	Legendary = 10,
	Divine = 9,
	Celestial = 8,
	Godly = 7,
}

local RARITY_PANIC_SPEED = {
	Common = 28,
	Rare = 34,
	Epic = 42,
	Mythic = 50,
	Legendary = 58,
	Divine = 66,
	Celestial = 74,
	Godly = 84,
}

local RARITY_COLORS = {
	Common = Color3.fromRGB(220, 220, 220),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(200, 80, 255),
	Mythic = Color3.fromRGB(255, 70, 170),
	Legendary = Color3.fromRGB(255, 205, 45),
	Divine = Color3.fromRGB(60, 240, 255),
	Celestial = Color3.fromRGB(165, 125, 255),
	Godly = Color3.fromRGB(255, 75, 75),
}

local hitCooldowns = {}
local chaseTokens = {}
local stunnedAnchoredStates = {}

local function ensureRemote(name)
	local existing = ReplicatedStorage:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteEvent") then
			return existing
		end

		existing:Destroy()
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

local requestRemote = ensureRemote(REQUEST_REMOTE_NAME)
local feedbackRemote = ensureRemote(FEEDBACK_REMOTE_NAME)
local updateRemote = ensureRemote(UPDATE_REMOTE_NAME)
local notifyRemote = ensureRemote(NOTIFY_REMOTE_NAME)

local function notify(player, message, variant)
	if not player or not player.Parent then
		return
	end

	notifyRemote:FireClient(player, {
		message = message,
		variant = variant or "success",
	})
end

local function getServerTime()
	return Workspace:GetServerTimeNow()
end

local function getRarity(npc)
	local rarity = npc:GetAttribute("Rarity") or npc:GetAttribute("rarity") or "Common"
	rarity = tostring(rarity)

	if rarity == "" then
		rarity = "Common"
	end

	return rarity
end

local function getCaptureMaxHP(npc)
	local rarity = getRarity(npc)
	return RARITY_CAPTURE_HP[rarity] or RARITY_CAPTURE_HP.Common
end

local function getCaptureTime(npc)
	local rarity = getRarity(npc)
	return RARITY_CAPTURE_TIME[rarity] or RARITY_CAPTURE_TIME.Common
end

local function getPanicSpeed(npc)
	local rarity = getRarity(npc)
	return RARITY_PANIC_SPEED[rarity] or RARITY_PANIC_SPEED.Common
end

local function getRarityColor(npc)
	local rarity = getRarity(npc)
	return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

local function getNpcRoot(npc)
	local root = npc:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		return root
	end

	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function getPlayerRoot(player)
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function isNpcHeld(npc)
	local heldBy = npc:GetAttribute("HeldBy")
	return heldBy ~= nil and heldBy ~= 0 and heldBy ~= ""
end

local function isNpcPlaced(npc)
	return npc:GetAttribute("IsPlaced") == true
end

local function isWildNpc(npc)
	if not npc or not npc:IsA("Model") then
		return false
	end

	if not npc.Parent then
		return false
	end

	if isNpcPlaced(npc) then
		return false
	end

	if isNpcHeld(npc) then
		return false
	end

	return true
end

local function isEggNpc(npc)
	if not npc or not npc:IsA("Model") then
		return false
	end

	return npc:GetAttribute("EggBrainrot") == true
		or npc:GetAttribute("IsEgg") == true
		or npc:GetAttribute("EggSpawnerId") ~= nil
end

local function getGrabPrompt(npc)
	local root = getNpcRoot(npc)

	if root then
		local prompt = root:FindFirstChild("GrabNPC")
		if prompt and prompt:IsA("ProximityPrompt") then
			return prompt
		end
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Name == "GrabNPC" then
			return obj
		end
	end

	return nil
end

local function refreshGrabPrompt(npc)
	local prompt = getGrabPrompt(npc)

	if not prompt then
		return
	end

	local canPickUp = npc:GetAttribute("CaptureStunned") == true

	prompt.Enabled = canPickUp
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = npc.Name
end

local function clearChaseAttributes(npc)
	npc:SetAttribute("CaptureChaseActive", false)
	npc:SetAttribute("CaptureChaseStartTime", 0)
	npc:SetAttribute("CaptureChaseEndTime", 0)
	npc:SetAttribute("CaptureChaseDuration", 0)
	npc:SetAttribute("CaptureHunterUserId", 0)
	npc:SetAttribute("CaptureHunterName", "")
end

local function setupCaptureAttributes(npc)
	if not npc:IsA("Model") then
		return
	end

	local maxHP = getCaptureMaxHP(npc)

	if typeof(npc:GetAttribute("CaptureMaxHP")) ~= "number" then
		npc:SetAttribute("CaptureMaxHP", maxHP)
	end

	if typeof(npc:GetAttribute("CaptureHP")) ~= "number" then
		npc:SetAttribute("CaptureHP", maxHP)
	end

	if npc:GetAttribute("CaptureStunned") == nil then
		npc:SetAttribute("CaptureStunned", false)
	end

	if npc:GetAttribute("CaptureChaseActive") == nil then
		clearChaseAttributes(npc)
	end

	if npc:GetAttribute("CapturePanic") == nil then
		npc:SetAttribute("CapturePanic", false)
	end

	if npc:GetAttribute("CaptureShielded") == nil then
		npc:SetAttribute("CaptureShielded", false)
	end

	if typeof(npc:GetAttribute("CaptureShieldEndTime")) ~= "number" then
		npc:SetAttribute("CaptureShieldEndTime", 0)
	end

	if npc:GetAttribute("CaptureStunned") == true then
		npc:SetAttribute("CaptureHP", 0)
	else
		local hp = tonumber(npc:GetAttribute("CaptureHP"))
		if not hp or hp <= 0 then
			npc:SetAttribute("CaptureHP", npc:GetAttribute("CaptureMaxHP") or maxHP)
		end
	end

	refreshGrabPrompt(npc)
end

local function removePanicVisuals(npc)
	local highlight = npc:FindFirstChild("CapturePanicHighlight")
	if highlight then
		highlight:Destroy()
	end

	local shield = npc:FindFirstChild("CaptureShield")
	if shield then
		shield:Destroy()
	end
end

local function addPanicVisuals(npc)
	removePanicVisuals(npc)

	local color = getRarityColor(npc)

	local highlight = Instance.new("Highlight")
	highlight.Name = "CapturePanicHighlight"
	highlight.FillColor = color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = npc

	local shield = Instance.new("ForceField")
	shield.Name = "CaptureShield"
	shield.Visible = true
	shield.Parent = npc
end

local function rememberAnchoredState(npc)
	local saved = {}

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			saved[obj] = obj.Anchored
		end
	end

	stunnedAnchoredStates[npc] = saved
end

local function restoreAnchoredState(npc)
	local saved = stunnedAnchoredStates[npc]
	stunnedAnchoredStates[npc] = nil

	if not saved then
		return
	end

	for part, wasAnchored in pairs(saved) do
		if part and part.Parent and part:IsDescendantOf(npc) then
			part.Anchored = wasAnchored
		end
	end
end

local function lockNpcWhileStunned(npc)
	local root = getNpcRoot(npc)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")

	rememberAnchoredState(npc)

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj:SetNetworkOwner(nil)
			obj.AssemblyLinearVelocity = Vector3.zero
			obj.AssemblyAngularVelocity = Vector3.zero
			obj.Anchored = true
		end
	end

	if humanoid then
		humanoid:Move(Vector3.zero)
		humanoid.AutoRotate = false
		humanoid.WalkSpeed = 0
		humanoid.Jump = false

		if humanoid.UseJumpPower then
			humanoid.JumpPower = 0
		else
			humanoid.JumpHeight = 0
		end

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

local function releaseNpcFromStun(npc)
	if not npc or not npc.Parent then
		stunnedAnchoredStates[npc] = nil
		return
	end

	if isNpcHeld(npc) or isNpcPlaced(npc) then
		stunnedAnchoredStates[npc] = nil
		return
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local maxHP = tonumber(npc:GetAttribute("CaptureMaxHP")) or getCaptureMaxHP(npc)

	npc:SetAttribute("CaptureHP", maxHP)
	npc:SetAttribute("CaptureStunned", false)
	npc:SetAttribute("CapturePanic", false)
	npc:SetAttribute("CaptureShielded", false)
	npc:SetAttribute("CaptureShieldEndTime", 0)

	clearChaseAttributes(npc)
	removePanicVisuals(npc)
	restoreAnchoredState(npc)

	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.AutoRotate = true
		humanoid.Jump = false

		if humanoid.UseJumpPower then
			humanoid.JumpPower = 50
		else
			humanoid.JumpHeight = 7.2
		end

		pcall(function()
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end

	refreshGrabPrompt(npc)
end

local function stunNpc(npc, player)
	if not isWildNpc(npc) then
		return
	end

	chaseTokens[npc] = (chaseTokens[npc] or 0) + 1

	npc:SetAttribute("CaptureHP", 0)
	npc:SetAttribute("CaptureStunned", true)
	npc:SetAttribute("CapturePanic", false)
	npc:SetAttribute("CaptureShielded", false)
	npc:SetAttribute("CaptureShieldEndTime", 0)

	clearChaseAttributes(npc)
	removePanicVisuals(npc)
	lockNpcWhileStunned(npc)
	refreshGrabPrompt(npc)

	notify(player, npc.Name .. " is stunned! Hold E to pick it up!", "success")

	task.delay(STUN_DURATION, function()
		releaseNpcFromStun(npc)
	end)
end

local function collectTargetParts(folder, result)
	if not folder then
		return
	end

	for _, obj in ipairs(folder:GetDescendants()) do
		if obj:IsA("BasePart") then
			table.insert(result, obj)
		end
	end

	if folder:IsA("BasePart") then
		table.insert(result, folder)
	end
end

local function chooseEscapePosition(npc, player)
	local npcRoot = getNpcRoot(npc)
	local playerRoot = player and getPlayerRoot(player)

	if not npcRoot then
		return nil
	end

	local candidates = {}

	collectTargetParts(ESCAPE_POINTS_FOLDER, candidates)
	collectTargetParts(HIDE_SPOTS_FOLDER, candidates)

	local bestPart = nil
	local bestScore = -math.huge

	if playerRoot then
		for _, part in ipairs(candidates) do
			local score = (part.Position - playerRoot.Position).Magnitude
			if score > bestScore then
				bestScore = score
				bestPart = part
			end
		end
	else
		for _, part in ipairs(candidates) do
			local score = (part.Position - npcRoot.Position).Magnitude
			if score > bestScore then
				bestScore = score
				bestPart = part
			end
		end
	end

	if bestPart then
		return bestPart.Position
	end

	if playerRoot then
		local direction = npcRoot.Position - playerRoot.Position

		if direction.Magnitude < 1 then
			direction = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
		end

		return npcRoot.Position + direction.Unit * 95
	end

	return npcRoot.Position + Vector3.new(math.random(-80, 80), 0, math.random(-80, 80))
end

local function panicRun(npc, player)
	task.spawn(function()
		if not npc or not npc.Parent then
			return
		end

		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		local root = getNpcRoot(npc)

		if not humanoid or not root then
			return
		end

		addPanicVisuals(npc)

		restoreAnchoredState(npc)

		root.Anchored = false
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = getPanicSpeed(npc)

		local panicEndsAt = getServerTime() + PANIC_DURATION

		while npc.Parent
			and isWildNpc(npc)
			and npc:GetAttribute("CapturePanic") == true
			and npc:GetAttribute("CaptureStunned") ~= true
			and getServerTime() < panicEndsAt do

			humanoid = npc:FindFirstChildOfClass("Humanoid")
			root = getNpcRoot(npc)

			if not humanoid or not root then
				break
			end

			local targetPosition = chooseEscapePosition(npc, player)

			if targetPosition then
				humanoid.WalkSpeed = getPanicSpeed(npc)
				humanoid:MoveTo(targetPosition)
			end

			local stepEndsAt = os.clock() + 1.15

			while os.clock() < stepEndsAt do
				if not npc.Parent
					or not isWildNpc(npc)
					or npc:GetAttribute("CapturePanic") ~= true
					or npc:GetAttribute("CaptureStunned") == true then
					break
				end

				task.wait(0.08)
			end
		end

		if npc and npc.Parent and npc:GetAttribute("CaptureStunned") ~= true then
			npc:SetAttribute("CapturePanic", false)
			removePanicVisuals(npc)

			local currentHumanoid = npc:FindFirstChildOfClass("Humanoid")
			if currentHumanoid then
				currentHumanoid.WalkSpeed = 16
			end
		end
	end)
end

local function failChase(npc, player)
	if not npc or not npc.Parent then
		return
	end

	if npc:GetAttribute("CaptureStunned") == true then
		return
	end

	if not isWildNpc(npc) then
		return
	end

	local maxHP = tonumber(npc:GetAttribute("CaptureMaxHP")) or getCaptureMaxHP(npc)
	local shieldEndTime = getServerTime() + SHIELD_DURATION

	npc:SetAttribute("CaptureHP", maxHP)
	npc:SetAttribute("CapturePanic", true)
	npc:SetAttribute("CaptureShielded", true)
	npc:SetAttribute("CaptureShieldEndTime", shieldEndTime)

	clearChaseAttributes(npc)
	refreshGrabPrompt(npc)

	notify(player, npc.Name .. " panicked! It healed, got a shield, and ran away!", "warning")

	panicRun(npc, player)

	task.delay(SHIELD_DURATION, function()
		if npc and npc.Parent and npc:GetAttribute("CaptureStunned") ~= true then
			npc:SetAttribute("CaptureShielded", false)
			npc:SetAttribute("CaptureShieldEndTime", 0)
		end
	end)
end

local function startChase(player, npc)
	if not npc or not npc.Parent then
		return
	end

	if npc:GetAttribute("CaptureChaseActive") == true then
		return
	end

	local now = getServerTime()
	local duration = getCaptureTime(npc)

	chaseTokens[npc] = (chaseTokens[npc] or 0) + 1
	local token = chaseTokens[npc]

	npc:SetAttribute("CaptureChaseActive", true)
	npc:SetAttribute("CaptureChaseStartTime", now)
	npc:SetAttribute("CaptureChaseEndTime", now + duration)
	npc:SetAttribute("CaptureChaseDuration", duration)
	npc:SetAttribute("CaptureHunterUserId", player.UserId)
	npc:SetAttribute("CaptureHunterName", player.Name)

	task.delay(duration + 0.05, function()
		if not npc or not npc.Parent then
			return
		end

		if chaseTokens[npc] ~= token then
			return
		end

		if npc:GetAttribute("CaptureChaseActive") ~= true then
			return
		end

		if npc:GetAttribute("CaptureStunned") == true then
			return
		end

		failChase(npc, player)
	end)
end

local function getPlayerStrength(player)
	local strength = tonumber(player:GetAttribute("Strength"))
		or tonumber(player:GetAttribute("Power"))
		or tonumber(player:GetAttribute("SpeedPower"))
		or tonumber(player:GetAttribute("Speed"))
		or 0

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		for _, statName in ipairs({ "Strength", "Power", "SpeedPower", "Speed" }) do
			local stat = leaderstats:FindFirstChild(statName)
			if stat and (stat:IsA("NumberValue") or stat:IsA("IntValue")) then
				strength = math.max(strength, tonumber(stat.Value) or 0)
			end
		end
	end

	return math.max(0, strength)
end

local function getPlayerCatchPower(player)
	local basePower = tonumber(player:GetAttribute("CatchPower")) or DEFAULT_CATCH_POWER

	local character = player.Character
	if character then
		local tool = character:FindFirstChild("Capture Net")
		if tool and tool:IsA("Tool") then
			local toolDamage = tonumber(tool:GetAttribute("CatchDamage"))
			if toolDamage then
				basePower = math.max(basePower, toolDamage)
			end
		end
	end

	local strength = getPlayerStrength(player)
	local strengthDamage = math.floor(strength * STRENGTH_DAMAGE_MULTIPLIER)

	return math.max(1, math.floor(basePower + strengthDamage))
end

local function getPlayerCatchRange(player)
	return tonumber(player:GetAttribute("CatchRange")) or DEFAULT_CATCH_RANGE
end

local function fireCaptureUpdate(player)
	updateRemote:FireClient(player, {
		catchPower = getPlayerCatchPower(player),
		catchRange = getPlayerCatchRange(player),
		strength = getPlayerStrength(player),
	})
end

local function createCaptureNetTool(player)
	local backpack = player:WaitForChild("Backpack")
	local starterGear = player:WaitForChild("StarterGear")

	local function removeOld(container)
		if not container then
			return
		end

		local old = container:FindFirstChild("Capture Net")
		if old then
			old:Destroy()
		end
	end

	removeOld(backpack)
	removeOld(starterGear)
	removeOld(player.Character)

	local function makeTool()
		local tool = Instance.new("Tool")
		tool.Name = "Capture Net"
		tool.RequiresHandle = true
		tool.CanBeDropped = false
		tool.ToolTip = "Hit brainrots. Defeat them before the timer ends."

		tool:SetAttribute("CatchDamage", DEFAULT_CATCH_POWER)
		tool:SetAttribute("CatchRange", getPlayerCatchRange(player))

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.35, 3.2, 0.35)
		handle.Material = Enum.Material.SmoothPlastic
		handle.Color = Color3.fromRGB(90, 190, 255)
		handle.CanCollide = false
		handle.Massless = true
		handle.Parent = tool

		local grip = Instance.new("Part")
		grip.Name = "GripBall"
		grip.Shape = Enum.PartType.Ball
		grip.Size = Vector3.new(0.65, 0.65, 0.65)
		grip.Material = Enum.Material.SmoothPlastic
		grip.Color = Color3.fromRGB(40, 90, 210)
		grip.CanCollide = false
		grip.Massless = true
		grip.CFrame = handle.CFrame * CFrame.new(0, -1.85, 0)
		grip.Parent = tool

		local ring = Instance.new("Part")
		ring.Name = "NetRing"
		ring.Shape = Enum.PartType.Ball
		ring.Size = Vector3.new(1.7, 1.7, 0.25)
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(120, 255, 255)
		ring.Transparency = 0.15
		ring.CanCollide = false
		ring.Massless = true
		ring.CFrame = handle.CFrame * CFrame.new(0, 1.95, 0)
		ring.Parent = tool

		local weld1 = Instance.new("WeldConstraint")
		weld1.Part0 = handle
		weld1.Part1 = grip
		weld1.Parent = handle

		local weld2 = Instance.new("WeldConstraint")
		weld2.Part0 = handle
		weld2.Part1 = ring
		weld2.Parent = handle

		local light = Instance.new("PointLight")
		light.Name = "NetGlow"
		light.Color = Color3.fromRGB(120, 255, 255)
		light.Brightness = 0.8
		light.Range = 8
		light.Parent = ring

		return tool
	end

	local backpackTool = makeTool()
	backpackTool.Parent = backpack

	local starterTool = makeTool()
	starterTool.Parent = starterGear
end

local function validateHit(player, npc)
	if not isWildNpc(npc) then
		return false, "Invalid NPC"
	end

	if npc:GetAttribute("CaptureStunned") == true then
		return false, "Already stunned"
	end

	if npc:GetAttribute("CaptureShielded") == true then
		return false, "Shielded"
	end

	if npc:GetAttribute("CapturePanic") == true then
		return false, "Panicking"
	end

	local playerRoot = getPlayerRoot(player)
	local npcRoot = getNpcRoot(npc)

	if not playerRoot or not npcRoot then
		return false, "Missing root"
	end

	local range = getPlayerCatchRange(player)
	local distance = (playerRoot.Position - npcRoot.Position).Magnitude

	if distance > range then
		return false, "Too far"
	end

	return true
end

local function damageNpc(player, npc)
	local key = tostring(player.UserId)
	local now = os.clock()

	if hitCooldowns[key] and now - hitCooldowns[key] < HIT_COOLDOWN then
		return
	end

	hitCooldowns[key] = now

	if isEggNpc(npc) then
		local eggApi = _G.CleanEggDamageApi
		if eggApi and eggApi.DamageEgg then
			local damage = getPlayerCatchPower(player)
			local beforeHP = tonumber(npc:GetAttribute("EggHP")) or tonumber(npc:GetAttribute("CaptureHP"))
			local handled = eggApi.DamageEgg(player, npc, damage, getPlayerCatchRange(player))
			if handled ~= false then
				local maxHP = tonumber(npc:GetAttribute("EggMaxHP")) or tonumber(npc:GetAttribute("CaptureMaxHP")) or getCaptureMaxHP(npc)
				local hp = tonumber(npc:GetAttribute("EggHP")) or tonumber(npc:GetAttribute("CaptureHP")) or maxHP
				if beforeHP ~= hp or npc:GetAttribute("CaptureChaseActive") == true or npc:GetAttribute("CaptureStunned") == true then
					local color = getRarityColor(npc)
					feedbackRemote:FireClient(player, {
						npc = npc,
						npcName = npc.Name,
						damage = damage,
						hp = hp,
						maxHP = maxHP,
						rarity = getRarity(npc),
						color = color,
						stunned = hp <= 0 or npc:GetAttribute("CaptureStunned") == true,
						chaseActive = npc:GetAttribute("CaptureChaseActive") == true,
						timeLeft = math.max(0, (tonumber(npc:GetAttribute("CaptureChaseEndTime")) or 0) - getServerTime()),
					})
				end
				return
			end
		end
	end

	local valid, reason = validateHit(player, npc)
	if not valid then
		if reason == "Too far" then
			notify(player, "Get closer to catch it!", "warning")
		elseif reason == "Shielded" then
			notify(player, "It has a shield! Wait a moment.", "warning")
		elseif reason == "Panicking" then
			notify(player, "It is panicking and running away!", "warning")
		end

		return
	end

	setupCaptureAttributes(npc)
	startChase(player, npc)

	local damage = getPlayerCatchPower(player)
	local isEgg = isEggNpc(npc)
	local maxHP = if isEgg
		then tonumber(npc:GetAttribute("EggMaxHP")) or tonumber(npc:GetAttribute("CaptureMaxHP")) or getCaptureMaxHP(npc)
		else tonumber(npc:GetAttribute("CaptureMaxHP")) or getCaptureMaxHP(npc)
	local hp = if isEgg
		then tonumber(npc:GetAttribute("EggHP")) or tonumber(npc:GetAttribute("CaptureHP")) or maxHP
		else tonumber(npc:GetAttribute("CaptureHP")) or maxHP

	hp = math.max(0, hp - damage)
	if isEgg then
		npc:SetAttribute("EggMaxHP", maxHP)
		npc:SetAttribute("EggHP", hp)
		npc:SetAttribute("CaptureMaxHP", maxHP)
	end
	npc:SetAttribute("CaptureHP", hp)

	local rarity = getRarity(npc)
	local color = getRarityColor(npc)

	feedbackRemote:FireClient(player, {
		npc = npc,
		npcName = npc.Name,
		damage = damage,
		hp = hp,
		maxHP = maxHP,
		rarity = rarity,
		color = color,
		stunned = hp <= 0,
		chaseActive = npc:GetAttribute("CaptureChaseActive") == true,
		timeLeft = math.max(0, (tonumber(npc:GetAttribute("CaptureChaseEndTime")) or 0) - getServerTime()),
	})

	if hp <= 0 then
		stunNpc(npc, player)
	end
end

requestRemote.OnServerEvent:Connect(function(player, npc)
	if typeof(npc) ~= "Instance" then
		return
	end

	if not npc:IsDescendantOf(NPC_FOLDER) then
		return
	end

	if not npc:IsA("Model") then
		local model = npc:FindFirstAncestorWhichIsA("Model")
		if model then
			npc = model
		end
	end

	if not npc or not npc:IsA("Model") then
		return
	end

	damageNpc(player, npc)
end)

local function watchNpc(npc)
	if not npc:IsA("Model") then
		return
	end

	setupCaptureAttributes(npc)

	local attrs = {
		"Rarity",
		"rarity",
		"CaptureStunned",
		"HeldBy",
		"IsPlaced",
		"PlacedOwnerUserId",
	}

	for _, attr in ipairs(attrs) do
		npc:GetAttributeChangedSignal(attr):Connect(function()
			if attr == "Rarity" or attr == "rarity" then
				local maxHP = getCaptureMaxHP(npc)
				npc:SetAttribute("CaptureMaxHP", maxHP)

				if npc:GetAttribute("CaptureStunned") ~= true
					and npc:GetAttribute("CaptureChaseActive") ~= true
					and npc:GetAttribute("CapturePanic") ~= true then
					npc:SetAttribute("CaptureHP", maxHP)
				end
			end

			refreshGrabPrompt(npc)
		end)
	end

	local root = getNpcRoot(npc)
	if root then
		root.ChildAdded:Connect(function(child)
			if child:IsA("ProximityPrompt") and child.Name == "GrabNPC" then
				task.wait()
				refreshGrabPrompt(npc)
			end
		end)
	end

	task.spawn(function()
		while npc.Parent do
			refreshGrabPrompt(npc)
			task.wait(0.2)
		end
	end)
end

for _, npc in ipairs(NPC_FOLDER:GetChildren()) do
	if npc:IsA("Model") then
		task.spawn(watchNpc, npc)
	end
end

NPC_FOLDER.ChildAdded:Connect(function(npc)
	if npc:IsA("Model") then
		task.wait(0.2)
		watchNpc(npc)
	end
end)

local function setupPlayer(player)
	player:SetAttribute("CatchPower", tonumber(player:GetAttribute("CatchPower")) or DEFAULT_CATCH_POWER)
	player:SetAttribute("CatchRange", tonumber(player:GetAttribute("CatchRange")) or DEFAULT_CATCH_RANGE)

	local function refresh()
		task.wait(0.05)
		fireCaptureUpdate(player)
	end

	for _, attrName in ipairs({
		"Strength",
		"Power",
		"SpeedPower",
		"Speed",
		"CatchPower",
		"CatchRange",
		}) do
		player:GetAttributeChangedSignal(attrName):Connect(refresh)
	end

	player.CharacterAdded:Connect(function()
		task.wait(0.35)
		createCaptureNetTool(player)
		fireCaptureUpdate(player)
	end)

	task.delay(0.6, function()
		if player.Parent then
			createCaptureNetTool(player)
			fireCaptureUpdate(player)
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	hitCooldowns[tostring(player.UserId)] = nil
end)

print("[CapturePowerService] loaded timed chase capture system")
