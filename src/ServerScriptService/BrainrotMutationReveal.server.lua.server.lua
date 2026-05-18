--!nonstrict
-- ServerScriptService/BrainrotMutationReveal.server.lua
-- Creates the mutation RemoteEvent, freezes player/NPC, rolls mutation,
-- fires the camera cinematic, waits, then applies mutation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAME = "BrainrotMutationReveal"

local revealRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)

if revealRemote and not revealRemote:IsA("RemoteEvent") then
	revealRemote:Destroy()
	revealRemote = nil
end

if not revealRemote then
	revealRemote = Instance.new("RemoteEvent")
	revealRemote.Name = REMOTE_NAME
	revealRemote.Parent = ReplicatedStorage
end

local activePickups = {}

local MUTATIONS = {
	{
		Name = "Normal",
		DisplayName = "Normal",
		Prefix = "",
		Chance = 7000,
		Multiplier = 1,
		Color = Color3.fromRGB(255, 255, 255),
		Emoji = "⚪",
		Effect = "Normal",
	},

	{
		Name = "Golden",
		DisplayName = "Golden",
		Prefix = "Golden",
		Chance = 1500,
		Multiplier = 1.75,
		Color = Color3.fromRGB(255, 204, 60),
		Emoji = "🟡",
		Effect = "GoldBurst",
	},

	{
		Name = "Diamond",
		DisplayName = "Diamond",
		Prefix = "Diamond",
		Chance = 800,
		Multiplier = 2.5,
		Color = Color3.fromRGB(90, 230, 255),
		Emoji = "💎",
		Effect = "DiamondSpark",
	},

	{
		Name = "Shadow",
		DisplayName = "Shadow",
		Prefix = "Shadow",
		Chance = 400,
		Multiplier = 3.5,
		Color = Color3.fromRGB(115, 70, 255),
		Emoji = "🌑",
		Effect = "ShadowSmoke",
	},

	{
		Name = "Corrupted",
		DisplayName = "Corrupted",
		Prefix = "Corrupted",
		Chance = 200,
		Multiplier = 5,
		Color = Color3.fromRGB(255, 45, 85),
		Emoji = "🧬",
		Effect = "CorruptedGlitch",
	},

	{
		Name = "Rainbow",
		DisplayName = "Rainbow",
		Prefix = "Rainbow",
		Chance = 90,
		Multiplier = 8,
		Color = Color3.fromRGB(255, 80, 240),
		Emoji = "🌈",
		Effect = "RainbowSpin",
	},

	{
		Name = "Celestial",
		DisplayName = "Celestial",
		Prefix = "Celestial",
		Chance = 10,
		Multiplier = 15,
		Color = Color3.fromRGB(170, 120, 255),
		Emoji = "✨",
		Effect = "CelestialStars",
	},
}

local function getRevealDuration(mutationName)
	if mutationName == "Normal" then
		return 1.8
	elseif mutationName == "Golden" then
		return 2.8
	elseif mutationName == "Diamond" then
		return 4.0
	elseif mutationName == "Shadow" then
		return 5.2
	elseif mutationName == "Corrupted" then
		return 5.6
	elseif mutationName == "Rainbow" then
		return 6.8
	elseif mutationName == "Celestial" then
		return 7.8
	end

	return 3.5
end

local function getNpcRoot(npc)
	if not npc then
		return nil
	end

	return npc.PrimaryPart
		or npc:FindFirstChild("HumanoidRootPart", true)
		or npc:FindFirstChildWhichIsA("BasePart", true)
end

local function getBaseBrainrotName(npc)
	local name =
		npc:GetAttribute("BaseBrainrotName")
		or npc:GetAttribute("OriginalBrainrotName")
		or npc:GetAttribute("BrainrotName")
		or npc:GetAttribute("DisplayName")
		or npc.Name

	name = tostring(name)

	for _, mutation in ipairs(MUTATIONS) do
		if mutation.Prefix ~= "" then
			local prefix = mutation.Prefix .. " "
			if string.sub(name, 1, #prefix) == prefix then
				name = string.sub(name, #prefix + 1)
			end
		end
	end

	if name == "" or name == "Model" then
		name = npc.Name
	end

	if name == "" or name == "Model" then
		name = "Brainrot"
	end

	return name
end

local function getBaseCashPerSecond(npc)
	local base =
		tonumber(npc:GetAttribute("BaseCashPerSecond"))
		or tonumber(npc:GetAttribute("OriginalCashPerSecond"))
		or tonumber(npc:GetAttribute("CashPerSecond"))
		or tonumber(npc:GetAttribute("MPS"))
		or 1

	return math.max(base, 1)
end

local function getPlayerLuck(player)
	local luck =
		tonumber(player:GetAttribute("Luck"))
		or tonumber(player:GetAttribute("TotalLuck"))
		or tonumber(player:GetAttribute("MutationLuck"))
		or 0

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local luckValue =
			leaderstats:FindFirstChild("Luck")
			or leaderstats:FindFirstChild("Lucky")
			or leaderstats:FindFirstChild("MutationLuck")

		if luckValue and luckValue:IsA("ValueBase") then
			luck += tonumber(luckValue.Value) or 0
		end
	end

	return math.clamp(1 + (luck / 100), 1, 8)
end

local function rollMutation(player)
	local luckMultiplier = getPlayerLuck(player)
	local total = 0

	for _, mutation in ipairs(MUTATIONS) do
		local chance = mutation.Chance

		if mutation.Name ~= "Normal" then
			chance *= luckMultiplier
		end

		total += chance
	end

	local roll = math.random() * total
	local current = 0

	for _, mutation in ipairs(MUTATIONS) do
		local chance = mutation.Chance

		if mutation.Name ~= "Normal" then
			chance *= luckMultiplier
		end

		current += chance

		if roll <= current then
			return mutation
		end
	end

	return MUTATIONS[1]
end

local function freezePlayer(player)
	local character = player.Character
	if not character then
		return function() end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return function() end
	end

	local oldWalkSpeed = humanoid.WalkSpeed
	local oldJumpPower = humanoid.JumpPower
	local oldJumpHeight = humanoid.JumpHeight
	local oldAutoRotate = humanoid.AutoRotate
	local frozenCFrame = root.CFrame

	player:SetAttribute("MutationCinematicLocked", true)

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not character.Parent or not root.Parent or humanoid.Health <= 0 then
			return
		end

		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = frozenCFrame

		humanoid:Move(Vector3.zero, false)
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
		humanoid.AutoRotate = false
	end)

	return function()
		if connection then
			connection:Disconnect()
		end

		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = oldWalkSpeed > 0 and oldWalkSpeed or 16
			humanoid.JumpPower = oldJumpPower > 0 and oldJumpPower or 50
			humanoid.JumpHeight = oldJumpHeight > 0 and oldJumpHeight or 7.2
			humanoid.AutoRotate = oldAutoRotate
		end

		player:SetAttribute("MutationCinematicLocked", false)
	end
end

local function freezeNpc(npc)
	local root = getNpcRoot(npc)
	local rootCFrame = root and root.CFrame

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not npc or not npc.Parent then
			return
		end

		for _, obj in ipairs(npc:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.AssemblyLinearVelocity = Vector3.zero
				obj.AssemblyAngularVelocity = Vector3.zero
			end
		end

		if root and root.Parent and rootCFrame then
			root.CFrame = rootCFrame
		end

		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:Move(Vector3.zero, false)
			humanoid.AutoRotate = false
			humanoid.PlatformStand = true
		end
	end)

	return function()
		if connection then
			connection:Disconnect()
		end

		local humanoid = npc and npc:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = false
			humanoid.AutoRotate = true
		end
	end
end

local function clearMutationEffects(npc)
	local oldHighlight = npc:FindFirstChild("MutationHighlight")
	if oldHighlight then
		oldHighlight:Destroy()
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj.Name == "MutationAttachment" or obj.Name == "MutationFinalOverhead" then
			obj:Destroy()
		end
	end
end

local function applyPermanentMutationVisual(npc, mutation)
	clearMutationEffects(npc)

	local highlight = Instance.new("Highlight")
	highlight.Name = "MutationHighlight"
	highlight.FillColor = mutation.Color
	highlight.OutlineColor = mutation.Color
	highlight.FillTransparency = mutation.Name == "Normal" and 1 or 0.45
	highlight.OutlineTransparency = mutation.Name == "Normal" and 1 or 0.05
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = npc

	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			if mutation.Name == "Golden" then
				part.Color = Color3.fromRGB(255, 205, 60)
				part.Material = Enum.Material.SmoothPlastic
			elseif mutation.Name == "Diamond" then
				part.Color = Color3.fromRGB(105, 235, 255)
				part.Material = Enum.Material.Neon
			elseif mutation.Name == "Shadow" then
				part.Color = Color3.fromRGB(45, 30, 85)
				part.Material = Enum.Material.SmoothPlastic
			elseif mutation.Name == "Corrupted" then
				part.Color = Color3.fromRGB(255, 55, 90)
				part.Material = Enum.Material.Neon
			elseif mutation.Name == "Rainbow" then
				part.Material = Enum.Material.Neon
			elseif mutation.Name == "Celestial" then
				part.Color = Color3.fromRGB(170, 120, 255)
				part.Material = Enum.Material.Neon
			end
		end
	end
end

local function applyMutation(npc, mutation)
	local baseName = getBaseBrainrotName(npc)
	local baseMps = getBaseCashPerSecond(npc)

	local finalName = baseName
	if mutation.Prefix ~= "" then
		finalName = mutation.Prefix .. " " .. baseName
	end

	local finalMps = math.floor(baseMps * mutation.Multiplier * 100) / 100

	npc:SetAttribute("BaseBrainrotName", baseName)
	npc:SetAttribute("OriginalBrainrotName", baseName)
	npc:SetAttribute("BaseCashPerSecond", baseMps)
	npc:SetAttribute("OriginalCashPerSecond", baseMps)

	npc:SetAttribute("Mutation", mutation.Name)
	npc:SetAttribute("MutationDisplayName", mutation.DisplayName)
	npc:SetAttribute("MutationMultiplier", mutation.Multiplier)
	npc:SetAttribute("MutationEmoji", mutation.Emoji)

	npc:SetAttribute("BrainrotName", finalName)
	npc:SetAttribute("DisplayName", finalName)

	-- Important:
	-- TemplateName must stay the original template name.
	-- Do NOT set TemplateName to "Golden BrainrotNPC_01".
	if npc:GetAttribute("TemplateName") == nil then
		npc:SetAttribute("TemplateName", npc.Name)
	end

	npc:SetAttribute("CashPerSecond", finalMps)
	npc:SetAttribute("MPS", finalMps)

	npc:SetAttribute("MutationRevealDone", true)
	npc:SetAttribute("MutationRevealRunning", false)

	applyPermanentMutationVisual(npc, mutation)
end

function _G.BrainrotMutationReveal_BeginPickup(player, npc)
	if not player or not player.Parent then
		return false
	end

	if not npc or not npc.Parent then
		return false
	end

	if activePickups[npc] then
		return false
	end

	activePickups[npc] = true

	local mutation = rollMutation(player)
	local revealDuration = getRevealDuration(mutation.Name)
	local baseName = getBaseBrainrotName(npc)
	local baseMps = getBaseCashPerSecond(npc)
	local root = getNpcRoot(npc)

	npc:SetAttribute("MutationRevealRunning", true)
	npc:SetAttribute("CanPickup", false)
	npc:SetAttribute("CanPickUp", false)
	npc:SetAttribute("PickupReady", false)
	npc:SetAttribute("ReadyToPick", false)
	npc:SetAttribute("ReadyToPickup", false)
	npc:SetAttribute("ReadyToPickUp", false)

	local unfreezePlayer = freezePlayer(player)
	local unfreezeNpc = freezeNpc(npc)

	print("[BrainrotMutationReveal] Pickup cinematic started:", player.Name, npc.Name, mutation.Name)

	revealRemote:FireClient(player, {
		Npc = npc,
		Root = root,

		BrainrotName = baseName,
		Rarity = tostring(npc:GetAttribute("Rarity") or "Common"),

		Mutation = mutation.Name,
		MutationDisplayName = mutation.DisplayName,
		MutationEmoji = mutation.Emoji,
		MutationMultiplier = mutation.Multiplier,
		MutationEffect = mutation.Effect,

		MutationColor = {
			R = math.floor(mutation.Color.R * 255),
			G = math.floor(mutation.Color.G * 255),
			B = math.floor(mutation.Color.B * 255),
		},

		BaseMPS = baseMps,
		FinalMPS = math.floor(baseMps * mutation.Multiplier * 100) / 100,

		Duration = revealDuration,
		Options = MUTATIONS,
	})

	task.wait(revealDuration)

	if npc and npc.Parent then
		applyMutation(npc, mutation)

		npc:SetAttribute("CanPickup", true)
		npc:SetAttribute("CanPickUp", true)
		npc:SetAttribute("PickupReady", true)
		npc:SetAttribute("ReadyToPick", true)
		npc:SetAttribute("ReadyToPickup", true)
		npc:SetAttribute("ReadyToPickUp", true)
		npc:SetAttribute("CaptureStunned", true)
		npc:SetAttribute("Defeated", true)
		npc:SetAttribute("IsDefeated", true)
	end

	unfreezeNpc()
	unfreezePlayer()

	activePickups[npc] = nil

	print("[BrainrotMutationReveal] Pickup cinematic finished:", player.Name, npc.Name, mutation.Name)

	return true
end

print("[BrainrotMutationReveal] Loaded pickup-based cinematic mutation system.")