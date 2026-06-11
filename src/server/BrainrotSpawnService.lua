local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PixelVisuals = require(script.Parent.PixelVisuals)

local BrainrotSpawnService = {}
local context
local random = Random.new()
local active = {}

local function makeBar(root, record)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Status"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(120, 42)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.Parent = root
	local name = Instance.new("TextLabel")
	name.Name = "NameLabel"
	name.Size = UDim2.new(1, 0, 0.52, 0)
	name.BackgroundTransparency = 1
	name.Text = record.Definition.Name
	name.TextColor3 = context.Config.Rarities[record.Definition.Rarity].Color
	name.TextStrokeTransparency = 0
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "HPBack"
	back.Position = UDim2.new(0.05, 0, 0.62, 0)
	back.Size = UDim2.new(0.9, 0, 0.25, 0)
	back.BackgroundColor3 = Color3.fromRGB(40, 42, 55)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(71, 235, 116)
	fill.BorderSizePixel = 0
	fill.Parent = back
end

local function chooseForZone(zoneId)
	local choices = {}
	for id, definition in pairs(context.Config.Brainrots) do
		if definition.Zone == zoneId then
			table.insert(choices, {
				Value = id,
				Weight = context.Config.Rarities[definition.Rarity].Weight,
			})
		end
	end
	return #choices > 0 and context.Util.WeightedChoice(choices, random) or nil
end

local function randomPoint(zone)
	return zone.Center
		+ Vector3.new(
			random:NextNumber(-zone.Size.X / 2 + 12, zone.Size.X / 2 - 12),
			2.5,
			random:NextNumber(-zone.Size.Y / 2 + 16, zone.Size.Y / 2 - 10)
		)
end

local function recover(record)
	record.Attacker = nil
	record.Stunned = false
	record.StunnedUntil = 0
	record.HP = record.MaxHP
	record.Root.Color = record.Definition.Color
	record.Model:SetAttribute("Stunned", false)
	record.Root.Status.HPBack.Fill.Size = UDim2.fromScale(1, 1)
	record.Root.Status.NameLabel.Text = record.Definition.Name
	record.Target = randomPoint(context.Config.Zones[record.Model:GetAttribute("ZoneId")])
end

function BrainrotSpawnService.Spawn(zoneId, forcedPosition)
	local id = chooseForZone(zoneId)
	if not id then
		return
	end
	local definition = context.Config.Brainrots[id]
	local rarity = context.Config.Rarities[definition.Rarity]
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("BrainrotId", id)
	model:SetAttribute("ZoneId", zoneId)
	model:SetAttribute("Stunned", false)
	model.Parent = context.MapService.GetWorld().Brainrots
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.Size = Vector3.new(6, 1, 6)
	root.Color = definition.Color
	root.Material = Enum.Material.Neon
	root.Position = forcedPosition or randomPoint(context.Config.Zones[zoneId])
	root.Parent = model
	model.PrimaryPart = root
	PixelVisuals.Build(model, root, id, definition.Color, rarity.Color, 0.82)
	local spriteId = context.AssetIds.Brainrots[id]
	if spriteId and spriteId ~= "rbxassetid://0" then
		local spriteGui = Instance.new("BillboardGui")
		spriteGui.Name = "Sprite"
		spriteGui.AlwaysOnTop = false
		spriteGui.Size = UDim2.fromOffset(96, 96)
		spriteGui.Parent = root
		local image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.Image = spriteId
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		image.Parent = spriteGui
		model.PixelArt:Destroy()
	end
	local outline = Instance.new("SelectionBox")
	outline.Adornee = root
	outline.Color3 = rarity.Color
	outline.LineThickness = 0.08
	outline.Parent = root
	local record = {
		Model = model,
		Root = root,
		Id = id,
		Definition = definition,
		MaxHP = math.floor(definition.BaseHP * rarity.HP),
		HP = math.floor(definition.BaseHP * rarity.HP),
		Target = randomPoint(context.Config.Zones[zoneId]),
		Attacker = nil,
		ChaseEnds = 0,
		Stunned = false,
		StunnedUntil = 0,
		IdleUntil = forcedPosition and os.clock() + 25 or 0,
	}
	active[model] = record
	makeBar(root, record)
	CollectionService:AddTag(model, "Brainrot")
	return record
end

function BrainrotSpawnService.Get(model)
	return active[model]
end

function BrainrotSpawnService.Remove(model)
	active[model] = nil
	if model and model.Parent then
		model:Destroy()
	end
end

function BrainrotSpawnService.CountZone(zoneId)
	local count = 0
	for _, record in pairs(active) do
		if record.Model:GetAttribute("ZoneId") == zoneId then
			count += 1
		end
	end
	return count
end

function BrainrotSpawnService.Init(newContext)
	context = newContext
end

function BrainrotSpawnService.Start()
	local grass = context.Config.Zones.Grass
	for _, offset in ipairs({
		Vector3.new(0, 2.5, -20),
		Vector3.new(14, 2.5, -24),
		Vector3.new(-14, 2.5, -24),
	}) do
		BrainrotSpawnService.Spawn("Grass", grass.Center + offset)
	end
	RunService.Heartbeat:Connect(function(delta)
		for model, record in pairs(active) do
			if not model.Parent then
				active[model] = nil
				continue
			end
			if record.Stunned then
				if os.clock() >= record.StunnedUntil then
					recover(record)
				end
				continue
			end
			if os.clock() < record.IdleUntil then
				continue
			end
			if record.Attacker and os.clock() > record.ChaseEnds then
				record.Attacker = nil
				record.HP = record.MaxHP
				record.Root.Status.HPBack.Fill.Size = UDim2.fromScale(1, 1)
				record.Root.Status.NameLabel.Text = record.Definition.Name
			end
			local zone = context.Config.Zones[model:GetAttribute("ZoneId")]
			if (record.Root.Position - record.Target).Magnitude < 3 then
				record.Target = randomPoint(zone)
			end
			if record.Attacker and record.Attacker.Character and record.Attacker.Character.PrimaryPart then
				record.Root.Status.NameLabel.Text =
					string.format("%s  %.1fs", record.Definition.Name, math.max(0, record.ChaseEnds - os.clock()))
				local away = record.Root.Position - record.Attacker.Character.PrimaryPart.Position
				if away.Magnitude > 0.1 then
					record.Target = record.Root.Position + away.Unit * 25
				end
			end
			local flat = Vector3.new(record.Target.X, record.Root.Position.Y, record.Target.Z) - record.Root.Position
			if flat.Magnitude > 0.1 then
				local rarity = context.Config.Rarities[record.Definition.Rarity]
				local speed = record.Definition.BaseSpeed * rarity.Speed
				local nextPosition = record.Root.Position + flat.Unit * math.min(flat.Magnitude, speed * delta)
				nextPosition = Vector3.new(
					math.clamp(nextPosition.X, zone.Center.X - zone.Size.X / 2 + 6, zone.Center.X + zone.Size.X / 2 - 6),
					record.Root.Position.Y,
					math.clamp(nextPosition.Z, zone.Center.Z - zone.Size.Y / 2 + 6, zone.Center.Z + zone.Size.Y / 2 - 6)
				)
				record.Model:PivotTo(CFrame.new(nextPosition))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, record in pairs(active) do
			if record.Attacker == player then
				recover(record)
			end
		end
	end)
	task.spawn(function()
		while task.wait(context.Config.Economy.SpawnTickSeconds) do
			for _, zoneId in ipairs(context.Config.Zones.Order) do
				if BrainrotSpawnService.CountZone(zoneId) < context.Config.Economy.MaxBrainrotsPerZone then
					BrainrotSpawnService.Spawn(zoneId)
				end
			end
		end
	end)
end

return BrainrotSpawnService
