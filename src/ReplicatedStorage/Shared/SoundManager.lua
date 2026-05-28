--!nonstrict
-- Client-side sound helper. Asset IDs come from Shared.AssetIds; placeholders are ignored.

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local AssetIds = nil
pcall(function()
	AssetIds = require(script.Parent:WaitForChild("AssetIds"))
end)

local SoundManager = {}

local DEFAULT_VOLUMES = {
	ui_click = 0.35,
	ui_hover = 0.22,
	hit = 0.38,
	stun = 0.45,
	capture_success = 0.55,
	reveal_tick = 0.28,
	reveal_speedup = 0.32,
	reveal_final_pop = 0.68,
	reveal_rare = 0.72,
	reveal_legendary = 0.82,
	money_collect = 0.45,
	purchase_success = 0.45,
	purchase_fail = 0.35,
	quest_complete = 0.5,
	rebirth = 0.65,
	zone_unlock = 0.58,
}

local DEFAULT_MIN_INTERVALS = {
	ui_hover = 0.06,
	reveal_tick = 0.05,
	money_collect = 0.15,
	hit = 0.06,
}

local lastPlayed = {}

local function cleanAssetId(id)
	if type(id) ~= "string" then
		return nil
	end

	if id == "" or string.find(id, "PASTE", 1, true) then
		return nil
	end

	return id
end

function SoundManager.GetSoundId(name)
	local sounds = type(AssetIds) == "table" and AssetIds.Sounds or nil
	return cleanAssetId(sounds and sounds[name])
end

function SoundManager.Play2D(name, options)
	options = type(options) == "table" and options or {}

	local soundId = cleanAssetId(options.soundId) or SoundManager.GetSoundId(name)
	if not soundId then
		return nil
	end

	local minInterval = tonumber(options.minInterval) or DEFAULT_MIN_INTERVALS[name] or 0.04
	local now = os.clock()
	local last = lastPlayed[name] or 0
	if now - last < minInterval then
		return nil
	end
	lastPlayed[name] = now

	local sound = Instance.new("Sound")
	sound.Name = "BrainrotSound_" .. tostring(name)
	sound.SoundId = soundId
	sound.Volume = tonumber(options.volume) or DEFAULT_VOLUMES[name] or 0.45
	sound.PlaybackSpeed = tonumber(options.playbackSpeed) or 1
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.Parent = options.parent or SoundService

	sound:Play()
	Debris:AddItem(sound, tonumber(options.lifetime) or 5)

	return sound
end

function SoundManager.PlayWorld(name, parent, options)
	options = type(options) == "table" and options or {}
	options.parent = parent
	return SoundManager.Play2D(name, options)
end

return SoundManager
