-- Compiled with roblox-ts v3.0.0
local TS = require(game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
local React = TS.import(script, game:GetService("ReplicatedStorage"), "node_modules", "@rbxts", "react")
local createRoot = TS.import(script, game:GetService("ReplicatedStorage"), "node_modules", "@rbxts", "react-roblox").createRoot
local HUD = TS.import(script, script, "ui", "components", "HUD").default
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PERFORMANCE_DISABLED_SCRIPTS = {
	AutoCollect = true,
	BetterTrainingFeedback = true,
	BrainrotCoreClient = true,
	BrainrotCtachReveal = true,
	BrainrotPlacedMoment = true,
	BrainrotSlotPromptClient = true,
	CaptureFeedbackClient = true,
	GameJuiceClient = true,
	GoldenAnimatedAura = true,
	HideNpcVisualPatch = true,
	InventoryModelPreviewPatch = true,
	JumpAuthorityFinal = true,
	JumpUnstick = true,
	LocalCollectMoneyText = true,
	MutationAuraAssetDriven = true,
	MutationAuraCinematic = true,
	MutationLuckyBloxAura = true,
	MutationLuckyBloxAura3D = true,
	MutationNameplate = true,
	MutationPictureAura = true,
	MutationReveal = true,
	MutationRevealClient = true,
	NpcAuras = true,
	NPCOverheadGui = true,
	OwnerCollectMoneyText = true,
	PlayerJumpFix = true,
	PlotOwnerText = true,
	PrivateCollectMoneyText = true,
	ProfessionalCartoonUI = true,
	QuestProgressClientSink = true,
	RebirthGui = true,
	ScreenGoalArrow = true,
	TrainingShopUpgrades = true,
	WeightTraining = true,
	ZoneEggHatchClient = true,
	ZoneGateClient = true,
	ZonePortalUI = true,
}

local function performanceBaseName(scriptName)
	local name = tostring(scriptName or "")
	name = string.gsub(name, "%.client%.lua.*$", "")
	name = string.gsub(name, "%.server%.lua.*$", "")
	name = string.gsub(name, "%.lua$", "")
	return name
end

local function disablePerformanceLocalScript(instance)
	if not instance:IsA("LocalScript") or instance == script then
		return
	end

	local key = performanceBaseName(instance.Name)
	if PERFORMANCE_DISABLED_SCRIPTS[key] then
		instance:SetAttribute("PerformanceModeDisabled", true)
		instance.Disabled = true
	end
end

for _, child in ipairs(script.Parent:GetChildren()) do
	disablePerformanceLocalScript(child)
end

script.Parent.ChildAdded:Connect(function(child)
	task.defer(disablePerformanceLocalScript, child)
end)

print("[PerformanceMode] Client cosmetic/duplicate systems disabled for", player.Name)

local function App()
	return React.createElement("screengui", {
		ResetOnSpawn = false,
	}, React.createElement(HUD))
end
local root = createRoot(playerGui)
root:render(React.createElement(App))
