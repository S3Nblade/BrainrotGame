--!nonstrict
-- AutoCollect.server.lua
-- Put in: ServerScriptService
-- Creates AutoCollectMoney immediately, then handles auto collect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local REMOTE_NAME = "AutoCollectMoney"

-- IMPORTANT: create remote immediately before any WaitForChild.
local requestRemote = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
if not requestRemote then
	requestRemote = Instance.new("RemoteEvent")
	requestRemote.Name = REMOTE_NAME
	requestRemote.Parent = ReplicatedStorage
end

local notifyRemote = ReplicatedStorage:FindFirstChild("NotifyUser")
if not notifyRemote then
	notifyRemote = Instance.new("RemoteEvent")
	notifyRemote.Name = "NotifyUser"
	notifyRemote.Parent = ReplicatedStorage
end

local npcFolder = Workspace:WaitForChild("BrainrotNPCs")

local requestCooldown = {}

local REQUEST_COOLDOWN = 0.95
local TOUCH_TIME = 0.12

local function normalize(text)
	return string.lower(tostring(text or "")):gsub("%s+", ""):gsub("_", ""):gsub("-", "")
end

local function getPlotsFolder()
	local direct = Workspace:FindFirstChild("plots") or Workspace:FindFirstChild("Plots")
	if direct then
		return direct
	end

	local spawnMap = Workspace:FindFirstChild("SpawnMap")
	if spawnMap then
		return spawnMap:FindFirstChild("plots") or spawnMap:FindFirstChild("Plots")
	end

	return nil
end

local function getOwnerPlot(player)
	local plotsFolder = getPlotsFolder()
	if not plotsFolder then
		return nil
	end

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if tostring(plot:GetAttribute("OwnerUserId")) == tostring(player.UserId)
			or tostring(plot:GetAttribute("OwnerName")) == player.Name
			or tostring(plot:GetAttribute("Owner")) == player.Name then
			return plot
		end
	end

	return nil
end

local function isCollectPart(part)
	if not part:IsA("BasePart") then
		return false
	end

	if part:GetAttribute("MoneyCollectPart") == true or part:GetAttribute("PrivateCollectGuiPart") == true then
		return true
	end

	local n = normalize(part.Name)
	return n == "moneycollect"
		or n == "collectmoney"
		or n == "moneycollectpart"
		or n == "collectmoneypart"
		or string.find(n, "moneycollect", 1, true) ~= nil
		or string.find(n, "collectmoney", 1, true) ~= nil
end

local function getCollectPartFromGoal(goalPart)
	local direct = goalPart:FindFirstChild("CollectMoney")

	if direct and direct:IsA("BasePart") then
		return direct
	end

	for _, obj in ipairs(goalPart:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "CollectMoney" then
			return obj
		end
	end

	return nil
end

local function getHouseGoals(plot)
	local goals = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj:IsA("BasePart") and string.find(obj.Name, "^HouseGoal_") ~= nil then
			table.insert(goals, obj)
		end
	end

	table.sort(goals, function(a, b)
		return a.Name < b.Name
	end)

	return goals
end

local function getCollectParts(plot)
	local parts = {}
	local used = {}

	for _, obj in ipairs(plot:GetDescendants()) do
		if obj:IsA("BasePart") and isCollectPart(obj) and not used[obj] then
			used[obj] = true
			table.insert(parts, obj)
		end
	end

	return parts
end

local function hasMoneyForGoal(player, goalName)
	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model")
			and npc:GetAttribute("IsPlaced") == true
			and npc:GetAttribute("PlacedOwnerUserId") == player.UserId
			and npc:GetAttribute("AssignedHouseGoal") == goalName
		then
			local earned = tonumber(npc:GetAttribute("Earned")) or 0

			if earned > 0 then
				return true
			end
		end
	end

	return false
end

local function getOrCreateTouchProxy(player)
	local character = player.Character

	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		return nil
	end

	local old = character:FindFirstChild("AutoCollectTouchProxy")
	if old then
		old:Destroy()
	end

	local proxy = Instance.new("Part")
	proxy.Name = "AutoCollectTouchProxy"
	proxy.Size = Vector3.new(3, 3, 3)
	proxy.Transparency = 1
	proxy.Anchored = false
	proxy.CanCollide = false
	proxy.CanQuery = false
	proxy.CanTouch = true
	proxy.Massless = true
	proxy.Parent = character

	return proxy
end

local function cleanupProxy(player)
	local character = player.Character
	if not character then
		return
	end

	local proxy = character:FindFirstChild("AutoCollectTouchProxy")
	if proxy then
		proxy:Destroy()
	end
end

local function touchCollectPart(player, collectPart)
	if not collectPart or not collectPart:IsA("BasePart") then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid then
		return
	end

	collectPart.CanTouch = true

	local proxy = getOrCreateTouchProxy(player)
	if not proxy then
		return
	end

	proxy.CFrame = collectPart.CFrame + Vector3.new(0, 0.2, 0)
	proxy.AssemblyLinearVelocity = Vector3.new(0, -2, 0)
	proxy.AssemblyAngularVelocity = Vector3.new(1, 1, 1)

	task.wait(TOUCH_TIME)

	if proxy and proxy.Parent then
		proxy.CFrame = root.CFrame + Vector3.new(0, 80, 0)
		proxy.AssemblyLinearVelocity = Vector3.zero
		proxy.AssemblyAngularVelocity = Vector3.zero
	end

	Debris:AddItem(proxy, 0.35)
end

local function autoCollectPlayer(player)
	local now = tick()
	local last = requestCooldown[player.UserId] or 0

	if now - last < REQUEST_COOLDOWN then
		return
	end

	requestCooldown[player.UserId] = now

	local plot = getOwnerPlot(player)

	if not plot then
		warn("[AutoCollect] No plot found for", player.Name)
		return
	end

	local collectParts = {}

	for _, collectPart in ipairs(getCollectParts(plot)) do
		local amount = tonumber(collectPart:GetAttribute("PrivateCollectAmount")) or 0
		if amount > 0 then
			table.insert(collectParts, collectPart)
		end
	end

	if #collectParts <= 0 then
		for _, houseGoal in ipairs(getHouseGoals(plot)) do
			local collectPart = getCollectPartFromGoal(houseGoal)

			if collectPart and hasMoneyForGoal(player, houseGoal.Name) then
				table.insert(collectParts, collectPart)
			end
		end
	end

	if #collectParts <= 0 then
		return
	end

	print("[AutoCollect] collecting", #collectParts, "slots for", player.Name)

	for _, collectPart in ipairs(collectParts) do
		touchCollectPart(player, collectPart)
		task.wait(0.08)
	end

	task.delay(0.4, function()
		cleanupProxy(player)
	end)
end

requestRemote.OnServerEvent:Connect(function(player)
	autoCollectPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	requestCooldown[player.UserId] = nil
end)

print("[AutoCollect] server loaded v3 - remote ready")
