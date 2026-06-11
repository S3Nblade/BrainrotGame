local ShopService = {}
local context

local function applySpeed(player)
	local data = context.DataService.Get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and data then
		humanoid.WalkSpeed = data.Boosts.SpeedUntil > os.time() and 20 or 16
	end
end

function ShopService.Init(newContext)
	context = newContext
end

function ShopService.Start()
	game:GetService("Players").PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait()
			applySpeed(player)
		end)
	end)
	context.Remotes.ShopPurchaseRequest.OnServerEvent:Connect(function(player, productId)
		local product = type(productId) == "string" and context.Config.Shop[productId]
		local data = context.DataService.Get(player)
		if not product or not data or data.Money < product.Cost then
			return
		end
		data.Money -= product.Cost
		if productId == "Storage" then
			data.StorageLevel += 1
		elseif productId == "Luck" then
			data.Boosts.LuckUntil = math.max(os.time(), data.Boosts.LuckUntil) + product.Duration
		elseif productId == "Speed" then
			data.Boosts.SpeedUntil = math.max(os.time(), data.Boosts.SpeedUntil) + product.Duration
			applySpeed(player)
			task.delay(product.Duration + 1, applySpeed, player)
		elseif productId == "Money" then
			data.Boosts.MoneyUntil = math.max(os.time(), data.Boosts.MoneyUntil) + product.Duration
		end
		context.DataService.PushState(player)
		context.Remotes.Notify:FireClient(player, product.DisplayName .. " purchased!", "Success")
	end)
end

return ShopService
