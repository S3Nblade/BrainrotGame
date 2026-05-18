--!nonstrict
-- StarterPlayerScripts/MutationNameplate.client.lua
-- Small clean mutation label above mutated Brainrots.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPC_FOLDER_NAME = "BrainrotNPCs"
local BILLBOARD_NAME = "ClientMutationNameplate"

local MutationConfig = require(ReplicatedStorage:WaitForChild("Configs"):WaitForChild("MutationConfig"))

local watched = {}

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function getRoot(npc)
	if npc.PrimaryPart then
		return npc.PrimaryPart
	end

	local hrp = npc:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	for _, obj in ipairs(npc:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function getMutation(npc)
	local mutation =
		npc:GetAttribute("Mutation")
		or npc:GetAttribute("MutationName")
		or npc:GetAttribute("ActiveMutation")
		or npc:GetAttribute("MutationType")
		or npc:GetAttribute("CurrentMutation")

	mutation = tostring(mutation or "")

	if mutation == "" then
		return nil
	end

	local n = normalize(mutation)

	if n == "normal" or n == "none" then
		return nil
	end

	return mutation
end

local function removeNameplate(npc)
	local old = npc:FindFirstChild(BILLBOARD_NAME, true)
	if old then
		old:Destroy()
	end
end

local function createNameplate(npc)
	removeNameplate(npc)

	local mutationName = getMutation(npc)
	if not mutationName then
		return
	end

	local root = getRoot(npc)
	if not root then
		return
	end

	local config = MutationConfig.Get(mutationName)
	local color = config.Color or Color3.fromRGB(255, 220, 45)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = BILLBOARD_NAME
	billboard.Adornee = root
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 130
	billboard.Size = UDim2.fromOffset(135, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	billboard.Parent = npc

	local frame = Instance.new("Frame")
	frame.Name = "Holder"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	frame.BackgroundTransparency = 0.18
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = 0.05
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = mutationName
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.45
	label.Parent = frame
end

local function refresh(npc)
	if not npc:IsA("Model") then
		return
	end

	if not npc:IsDescendantOf(Workspace) then
		removeNameplate(npc)
		return
	end

	if getMutation(npc) then
		createNameplate(npc)
	else
		removeNameplate(npc)
	end
end

local function watchNpc(npc)
	if not npc:IsA("Model") or watched[npc] then
		return
	end

	watched[npc] = true

	for _, attr in ipairs({
		"Mutation",
		"MutationName",
		"ActiveMutation",
		"MutationType",
		"CurrentMutation",
	}) do
		npc:GetAttributeChangedSignal(attr):Connect(function()
			task.defer(function()
				refresh(npc)
			end)
		end)
	end

	npc.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeNameplate(npc)
			watched[npc] = nil
		end
	end)

	task.defer(function()
		refresh(npc)
	end)
end

local function scan()
	local folder = getNpcFolder()
	if not folder then
		return
	end

	for _, npc in ipairs(folder:GetChildren()) do
		watchNpc(npc)
	end
end

local folder = getNpcFolder()
if folder then
	folder.ChildAdded:Connect(function(npc)
		task.wait(0.1)
		watchNpc(npc)
	end)
end

scan()

task.spawn(function()
	while true do
		scan()
		task.wait(1)
	end
end)

print("[MutationNameplate] Loaded.")
