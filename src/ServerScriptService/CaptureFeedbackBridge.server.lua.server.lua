--!nonstrict
-- ServerScriptService/CaptureFeedbackBridge.server.lua
-- Fires capture feedback only when a Brainrot becomes owned/captured.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CaptureFeedback")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local watched = {}
local fired = {}

local OWNER_ATTRIBUTES = {
	"OwnerUserId",
	"HeldOwnerUserId",
	"CaughtOwnerUserId",
	"CapturedByUserId",
	"PlacedOwnerUserId",
}

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function getNpcFolder()
	return Workspace:FindFirstChild(NPC_FOLDER_NAME)
end

local function isBrainrotModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if model:GetAttribute("IsBrainrot") == true
		or model:GetAttribute("BrainrotUID") ~= nil
		or model:GetAttribute("UID") ~= nil
		or model:GetAttribute("BrainrotName") ~= nil
		or model:GetAttribute("CashPerSecond") ~= nil
		or model:GetAttribute("MPS") ~= nil then
		return true
	end

	return string.find(normalize(model.Name), "brainrot") ~= nil
end

local function getRoot(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	local hrp = model:FindFirstChild("HumanoidRootPart", true)
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") then
			return obj
		end
	end

	return nil
end

local function getOwnerPlayer(model)
	for _, attr in ipairs(OWNER_ATTRIBUTES) do
		local value = tonumber(model:GetAttribute(attr))

		if value and value > 0 then
			local player = Players:GetPlayerByUserId(value)
			if player then
				return player
			end
		end
	end

	local ownerName =
		model:GetAttribute("OwnerName")
		or model:GetAttribute("PlayerName")

	if ownerName then
		return Players:FindFirstChild(tostring(ownerName))
	end

	return nil
end

local function getBrainrotName(model)
	return tostring(
		model:GetAttribute("BrainrotName")
		or model:GetAttribute("DisplayName")
		or model.Name
	)
end

local function fireCapture(model)
	if not model or not model.Parent then
		return
	end

	if not isBrainrotModel(model) then
		return
	end

	if fired[model] then
		return
	end

	local player = getOwnerPlayer(model)
	if not player then
		return
	end

	local root = getRoot(model)
	if not root then
		return
	end

	fired[model] = true

	remote:FireClient(player, {
		Result = "Success",
		Position = root.Position,
		BrainrotName = getBrainrotName(model),
	})

	print("[CaptureFeedback] Success feedback sent to", player.Name, "for", model.Name)
end

local function watchModel(model)
	if watched[model] then
		return
	end

	if not model:IsA("Model") then
		return
	end

	watched[model] = true

	for _, attr in ipairs(OWNER_ATTRIBUTES) do
		model:GetAttributeChangedSignal(attr):Connect(function()
			task.delay(0.05, function()
				fireCapture(model)
			end)
		end)
	end

	for _, attr in ipairs({
		"OwnerName",
		"PlayerName",
		"HeldBy",
		"InventoryOnly",
		"IsPlaced",
		"Placed",
	}) do
		model:GetAttributeChangedSignal(attr):Connect(function()
			task.delay(0.05, function()
				fireCapture(model)
			end)
		end)
	end

	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			watched[model] = nil
			fired[model] = nil
		end
	end)
end

local function scan()
	local folder = getNpcFolder()
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			watchModel(child)
		end
	end
end

local folder = getNpcFolder()

if folder then
	folder.ChildAdded:Connect(function(child)
		task.wait(0.1)

		if child:IsA("Model") then
			watchModel(child)
		end
	end)
end

scan()

task.spawn(function()
	while true do
		scan()
		task.wait(1)
	end
end)

print("[CaptureFeedbackBridge] Loaded.")
