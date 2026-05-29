--!strict
-- Central asset ID registry. PipoNuggetini currently uses the Studio model in
-- ServerStorage/BrainrotNPCPools/Common/PipoNuggetini, so no model asset ID is required.

local AssetIds = {
	Models = {
		PipoNuggetini = "",
	},

	Icons = {
		PipoNuggetini = "",
	},

	Animations = {
		Idle = "rbxassetid://115565698981462",
		Run = "rbxassetid://98948126492086",
		Stun = "rbxassetid://119409515712951",
		Showcase = "",
	},

	Sounds = {
		ui_click = "",
		ui_hover = "",
		hit = "",
		stun = "",
		capture_success = "",
		reveal_tick = "",
		reveal_speedup = "",
		reveal_final_pop = "",
		reveal_rare = "",
		reveal_legendary = "",
		money_collect = "",
		purchase_success = "",
		purchase_fail = "",
		quest_complete = "",
		rebirth = "",
		zone_unlock = "",
	},

	VFX = {},
}

return AssetIds
