local Players = game:GetService("Players")

local QuestService = {}
local context

local function rewardText(quest)
	local rewards = {}
	if quest.RewardMoney then
		table.insert(rewards, "$" .. context.Util.FormatNumber(quest.RewardMoney))
	end
	if quest.RewardGems then
		table.insert(rewards, quest.RewardGems .. " Gems")
	end
	return table.concat(rewards, " + ")
end

local function existingProgress(data, quest)
	if quest.Id == "FirstCapture" or quest.Id == "CaptureFive" then
		return #data.Inventory
	end
	if quest.Id == "FirstPlace" then
		return next(data.Placed) and 1 or 0
	end
	if quest.Id == "FirstUpgrade" then
		for _, item in ipairs(data.Inventory) do
			if (item.Level or 1) > 1 then
				return 1
			end
		end
		return 0
	end
	if quest.Id == "UnlockDesert" then
		return data.UnlockedZones.Desert and 1 or 0
	end
	if quest.Id == "FirstRebirth" then
		return math.min(1, data.Rebirths)
	end
	return 0
end

function QuestService.Init(newContext)
	context = newContext
end

function QuestService.Sync(player, notify)
	local data = context.DataService.Get(player)
	if not data then
		return
	end
	while true do
		local quest = context.Config.Quests[data.QuestStage]
		if not quest then
			break
		end
		data.QuestProgress = math.max(data.QuestProgress, math.min(quest.Target, existingProgress(data, quest)))
		if data.QuestProgress < quest.Target then
			break
		end
		data.Money += quest.RewardMoney or 0
		data.Gems += quest.RewardGems or 0
		data.QuestStage += 1
		data.QuestProgress = 0
		if notify then
			context.Remotes.Notify:FireClient(player, "Quest complete! +" .. rewardText(quest), "Success")
		end
	end
	context.DataService.PushState(player)
end

function QuestService.Progress(player, eventName, value, amount)
	local data = context.DataService.Get(player)
	local quest = data and context.Config.Quests[data.QuestStage]
	if not quest or quest.Event ~= eventName then
		return false
	end
	if quest.Value and quest.Value ~= value then
		return false
	end
	data.QuestProgress = math.min(quest.Target, data.QuestProgress + (amount or 1))
	if data.QuestProgress < quest.Target then
		context.DataService.PushState(player)
		return false
	end
	data.Money += quest.RewardMoney or 0
	data.Gems += quest.RewardGems or 0
	data.QuestStage += 1
	data.QuestProgress = 0
	context.Remotes.Notify:FireClient(player, "Quest complete! +" .. rewardText(quest), "Success")
	QuestService.Sync(player, true)
	return true
end

function QuestService.Start()
	local function setup(player)
		task.spawn(function()
			for _ = 1, 40 do
				if context.DataService.Get(player) then
					QuestService.Sync(player, false)
					return
				end
				task.wait(0.25)
			end
		end)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end
end

return QuestService
