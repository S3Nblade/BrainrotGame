-- Compiled with roblox-ts v3.0.0
-- SAFE SERVER STARTUP VERSION

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TS = require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))

local PERFORMANCE_DISABLED_SCRIPTS = {
	AuraNpcTagger = true,
	BrainrotMutationReveal = true,
	BrainrotPlacedCoreRepair = true,
	BrainrotPlacedFeedback = true,
	BrainrotStandSnapFix = true,
	CaptureFeedbackBridge = true,
	CaptureRevealAnnouncements = true,
	ForceNPCSpawnBase = true,
	ForestNPCSpawner = true,
	GoldenAuraOnNPC = true,
	GoldenAuraOnPlayer = true,
	GoldenAuraPlayerSpeedTest = true,
	GoldenAuraTest = true,
	GoldenBrainrotAura_Installer = true,
	HideSpotCoverBuilder = true,
	MutationRevealBridge = true,
	MutationRollService = true,
	PlacedBrainrotVisualRepair = true,
	SimulatorWorldPolish = true,
	SpeedAuraTest = true,
	tmp = true,
	ZoneEggHatching = true,
}

local function performanceBaseName(scriptName)
	local name = tostring(scriptName or "")
	name = string.gsub(name, "%.server%.lua.*$", "")
	name = string.gsub(name, "%.client%.lua.*$", "")
	name = string.gsub(name, "%.lua$", "")
	return name
end

local function disablePerformanceScript(instance)
	if not instance:IsA("Script") or instance == script then
		return
	end

	local key = performanceBaseName(instance.Name)
	if PERFORMANCE_DISABLED_SCRIPTS[key] then
		instance:SetAttribute("PerformanceModeDisabled", true)
		instance.Disabled = true
	end
end

for _, child in ipairs(ServerScriptService:GetChildren()) do
	disablePerformanceScript(child)
end

ServerScriptService.ChildAdded:Connect(function(child)
	task.defer(disablePerformanceScript, child)
end)

print("[PerformanceMode] Server cosmetic/test systems disabled for smooth Pipo build.")

local function ensureRemoteEvent(name)
	local existing = ReplicatedStorage:FindFirstChild(name)

	if existing then
		if existing:IsA("RemoteEvent") then
			return existing
		else
			existing:Destroy()
		end
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

-- Always create remotes before client scripts wait for them
ensureRemoteEvent("TrainSpeed")
ensureRemoteEvent("UpdateSpeedStats")
ensureRemoteEvent("BrainrotCatchFeedback")
ensureRemoteEvent("NotifyUser")
ensureRemoteEvent("UpdateCoins")
ensureRemoteEvent("ReleaseNPC")
ensureRemoteEvent("ReleaseButton")

local function safeRun(name, callback)
	local ok, result = pcall(callback)

	if not ok then
		warn("[SERVER STARTUP ERROR] " .. name .. " failed:")
		warn(result)
		return nil
	end

	print("[SERVER STARTUP OK] " .. name)
	return result
end

local playersSpeedOnConnect = safeRun("import speed.service", function()
	return TS.import(script, ServerScriptService, "Server", "services", "speed.service").playersSpeedOnConnect
end)

safeRun("import brainrots.service", function()
	TS.import(script, ServerScriptService, "Server", "services", "brainrots.service")
end)

safeRun("import rebirth.service", function()
	TS.import(script, ServerScriptService, "Server", "services", "rebirth.service")
end)

local startHideAndSeek = safeRun("import hideandseek.service", function()
	return TS.import(script, ServerScriptService, "Server", "services", "hideandseek.service").startHideAndSeek
end)

local CoinsService = safeRun("import coins.service", function()
	return TS.import(script, ServerScriptService, "Server", "services", "coins.service").default
end)

safeRun("CoinsService()", function()
	if CoinsService then
		CoinsService()
	end
end)

safeRun("startHideAndSeek()", function()
	if startHideAndSeek then
		startHideAndSeek()
	end
end)

safeRun("playersSpeedOnConnect()", function()
	if playersSpeedOnConnect then
		playersSpeedOnConnect()
	end
end)
