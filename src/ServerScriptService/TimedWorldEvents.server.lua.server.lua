--!nonstrict
-- ServerScriptService/TimedWorldEvents.server.lua

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPC_FOLDER_NAME = "BrainrotNPCs"

local BREAK_SECONDS = 240
local EVENT_SECONDS = 150
local MONEY_BRIDGE_TICK = 1

local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local worldEventRemote = remotesFolder:WaitForChild("WorldEventUpdate")
local announcementRemote = remotesFolder:WaitForChild("ServerAnnouncement")

local npcFolder = Workspace:FindFirstChild(NPC_FOLDER_NAME)
if not npcFolder then
	npcFolder = Instance.new("Folder")
	npcFolder.Name = NPC_FOLDER_NAME
	npcFolder.Parent = Workspace
end

local EVENTS = {
	{
		name = "DoubleMoney",
		displayName = "2x Money Event",
		moneyMultiplier = 2,
		strengthMultiplier = 1,
		luckMultiplier = 1,
		color = { R = 120, G = 255, B = 90 },
	},
	{
		name = "PowerTraining",
		displayName = "2x Training Event",
		moneyMultiplier = 1,
		strengthMultiplier = 2,
		luckMultiplier = 1,
		color = { R = 80, G = 170, B = 255 },
	},
	{
		name = "LuckyCapture",
		displayName = "2x Luck Event",
		moneyMultiplier = 1,
		strengthMultiplier = 1,
		luckMultiplier = 2,
		color = { R = 255, G = 110, B = 230 },
	},
}

local currentEvent = nil
local currentEventEndsAt = 0

local function setGlobalMultipliers(event)
	if event then
		ReplicatedStorage:SetAttribute("WorldEventActive", true)
		ReplicatedStorage:SetAttribute("WorldEventName", event.name)
		ReplicatedStorage:SetAttribute("WorldEventDisplayName", event.displayName)
		ReplicatedStorage:SetAttribute("GlobalMoneyMultiplier", event.moneyMultiplier)
		ReplicatedStorage:SetAttribute("GlobalStrengthMultiplier", event.strengthMultiplier)
		ReplicatedStorage:SetAttribute("GlobalLuckMultiplier", event.luckMultiplier)

		Workspace:SetAttribute("GlobalMoneyMultiplier", event.moneyMultiplier)
		Workspace:SetAttribute("GlobalStrengthMultiplier", event.strengthMultiplier)
		Workspace:SetAttribute("GlobalLuckMultiplier", event.luckMultiplier)
	else
		ReplicatedStorage:SetAttribute("WorldEventActive", false)
		ReplicatedStorage:SetAttribute("WorldEventName", "")
		ReplicatedStorage:SetAttribute("WorldEventDisplayName", "")
		ReplicatedStorage:SetAttribute("GlobalMoneyMultiplier", 1)
		ReplicatedStorage:SetAttribute("GlobalStrengthMultiplier", 1)
		ReplicatedStorage:SetAttribute("GlobalLuckMultiplier", 1)

		Workspace:SetAttribute("GlobalMoneyMultiplier", 1)
		Workspace:SetAttribute("GlobalStrengthMultiplier", 1)
		Workspace:SetAttribute("GlobalLuckMultiplier", 1)
	end
end

local function broadcastEventState()
	if not currentEvent then
		worldEventRemote:FireAllClients({
			active = false,
		})
		return
	end

	worldEventRemote:FireAllClients({
		active = true,
		name = currentEvent.name,
		displayName = currentEvent.displayName,
		color = currentEvent.color,
		timeLeft = math.max(0, math.floor(currentEventEndsAt - os.time())),
		moneyMultiplier = currentEvent.moneyMultiplier,
		strengthMultiplier = currentEvent.strengthMultiplier,
		luckMultiplier = currentEvent.luckMultiplier,
	})
end

local function isPlacedNpc(npc)
	return npc
		and npc:IsA("Model")
		and npc:GetAttribute("InventoryOnly") ~= true
		and (
			npc:GetAttribute("IsPlaced") == true
			or npc:GetAttribute("Placed") == true
			or npc:GetAttribute("AssignedSlotId") ~= nil
		)
end

local function moneyBoostBridge()
	while true do
		task.wait(MONEY_BRIDGE_TICK)

		local moneyMultiplier = tonumber(ReplicatedStorage:GetAttribute("GlobalMoneyMultiplier")) or 1
		if moneyMultiplier > 1 then
			for _, npc in ipairs(npcFolder:GetChildren()) do
				if isPlacedNpc(npc) then
					local mps = tonumber(npc:GetAttribute("CashPerSecond")) or tonumber(npc:GetAttribute("MPS")) or 1
					local current = tonumber(npc:GetAttribute("Earned")) or 0
					local extra = mps * (moneyMultiplier - 1) * MONEY_BRIDGE_TICK

					npc:SetAttribute("Earned", current + extra)
				end
			end
		end
	end
end

task.spawn(moneyBoostBridge)

task.spawn(function()
	while true do
		setGlobalMultipliers(nil)
		currentEvent = nil
		currentEventEndsAt = 0
		broadcastEventState()

		for remaining = BREAK_SECONDS, 1, -1 do
			task.wait(1)
		end

		currentEvent = EVENTS[math.random(1, #EVENTS)]
		currentEventEndsAt = os.time() + EVENT_SECONDS

		setGlobalMultipliers(currentEvent)
		broadcastEventState()

		announcementRemote:FireAllClients({
			kind = "WorldEvent",
			text = currentEvent.displayName .. " started!",
			color = currentEvent.color,
		})

		while os.time() < currentEventEndsAt do
			broadcastEventState()
			task.wait(1)
		end

		announcementRemote:FireAllClients({
			kind = "WorldEvent",
			text = currentEvent.displayName .. " ended.",
			color = { R = 255, G = 255, B = 255 },
		})
	end
end)

print("[TimedWorldEvents] Loaded.")