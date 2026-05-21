--!nonstrict
-- Hooks the server egg-opening remotes into the reusable NPC reveal GUI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RevealNPC = require(script.Parent:WaitForChild("NPCRevealGui"))

local seenRevealIds = {}
local hatchRequestRemote = nil
local lastHatchRequest = 0

local function getRevealId(payload)
	if type(payload) ~= "table" then
		return tostring(os.clock())
	end

	return tostring(payload.revealId or payload.RevealId or payload.EggId or payload.ResultName or os.clock())
end

local function enqueueReveal(payload)
	local revealId = getRevealId(payload)
	if seenRevealIds[revealId] then
		return
	end
	seenRevealIds[revealId] = true

	RevealNPC.show(payload)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if remotes then
	local revealRemote = remotes:WaitForChild("EggRevealResult", 15)
	if revealRemote and revealRemote:IsA("RemoteEvent") then
		revealRemote.OnClientEvent:Connect(enqueueReveal)
	end

	local startRevealRemote = remotes:WaitForChild("StartNPCReveal", 5)
	if startRevealRemote and startRevealRemote:IsA("RemoteEvent") then
		startRevealRemote.OnClientEvent:Connect(enqueueReveal)
	end

	local requestRemote = remotes:WaitForChild("HatchStunnedEggRequest", 5)
	if requestRemote and requestRemote:IsA("RemoteEvent") then
		hatchRequestRemote = requestRemote
	end
end

local legacyRevealRemote = ReplicatedStorage:WaitForChild("ZoneEggHatchResult", 15)
if legacyRevealRemote and legacyRevealRemote:IsA("RemoteEvent") then
	legacyRevealRemote.OnClientEvent:Connect(enqueueReveal)
end

local function getCharacterRoot()
	local player = game:GetService("Players").LocalPlayer
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getEggRoot(egg)
	return egg.PrimaryPart
		or egg:FindFirstChild("EggRoot", true)
		or egg:FindFirstChild("HumanoidRootPart", true)
		or egg:FindFirstChildWhichIsA("BasePart", true)
end

local function getNearestStunnedEgg()
	local root = getCharacterRoot()
	local folder = Workspace:FindFirstChild("BrainrotNPCs")
	if not root or not folder then
		return nil
	end

	local nearestEgg = nil
	local nearestDistance = 14

	for _, obj in ipairs(folder:GetChildren()) do
		if obj:IsA("Model")
			and obj:GetAttribute("EggBrainrot") == true
			and obj:GetAttribute("CaptureStunned") == true
			and obj:GetAttribute("HatchInProgress") ~= true then
			local eggRoot = getEggRoot(obj)
			if eggRoot then
				local distance = (root.Position - eggRoot.Position).Magnitude
				if distance <= nearestDistance then
					nearestDistance = distance
					nearestEgg = obj
				end
			end
		end
	end

	return nearestEgg
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode ~= Enum.KeyCode.E then
		return
	end
	if gameProcessed or UserInputService:GetFocusedTextBox() or not hatchRequestRemote then
		return
	end

	local now = os.clock()
	if now - lastHatchRequest < 0.25 then
		return
	end

	local egg = getNearestStunnedEgg()
	if egg then
		lastHatchRequest = now
		hatchRequestRemote:FireServer(egg)
	end
end)

print("[ZoneEggHatchClient] Loaded polished NPC reveal GUI bridge.")
