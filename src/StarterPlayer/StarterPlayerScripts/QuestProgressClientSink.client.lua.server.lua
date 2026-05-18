--!nonstrict
-- StarterPlayerScripts/QuestProgressClientSink.client.lua
-- Prevents UpdateQuestProgress remote queue from filling up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("UpdateQuestProgress", 10)

if remote and remote:IsA("RemoteEvent") then
	remote.OnClientEvent:Connect(function()
		-- For now we just consume the event.
		-- Later we can connect this to a quest UI.
	end)

	print("[QuestProgressClientSink] connected to UpdateQuestProgress.")
else
	warn("[QuestProgressClientSink] UpdateQuestProgress remote not found.")
end