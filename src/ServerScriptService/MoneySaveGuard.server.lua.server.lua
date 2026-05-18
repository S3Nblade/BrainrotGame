--!nonstrict
-- ServerScriptService/MoneySaveGuard.server.lua
-- Extra safety script.
-- Saves the current visible Money/Coins/Cash value when player leaves.
-- This prevents older coin systems from overwriting newly collected money.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local coinStore = DataStoreService:GetDataStore("PlayerCoins")

local function getCurrentMoney(player)
	local leaderstats = player:FindFirstChild("leaderstats")

	if leaderstats then
		for _, name in ipairs({ "Money", "Coins", "Cash" }) do
			local value = leaderstats:FindFirstChild(name)
			if value and value:IsA("ValueBase") then
				return math.floor(tonumber(value.Value) or 0)
			end
		end
	end

	return math.floor(
		tonumber(player:GetAttribute("Money"))
			or tonumber(player:GetAttribute("Coins"))
			or tonumber(player:GetAttribute("Cash"))
			or 0
	)
end

local function savePlayerMoney(player)
	local amount = getCurrentMoney(player)

	pcall(function()
		coinStore:SetAsync("player_" .. tostring(player.UserId), amount)
	end)

	print("[MoneySaveGuard] Saved money for", player.Name, amount)
end

Players.PlayerRemoving:Connect(function(player)
	task.wait(0.35)
	savePlayerMoney(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayerMoney(player)
	end

	task.wait(1)
end)

print("[MoneySaveGuard] Loaded")