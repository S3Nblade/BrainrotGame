--!strict

local ZoneConfig = {}

ZoneConfig.List = {
	{
		Id = "Starter",
		DisplayName = "Starter Zone",
		RequiredSpeed = 0,
		Color = Color3.fromRGB(120, 255, 90),
		PortalPosition = Vector3.new(0, 5, 0),
		DestinationPosition = Vector3.new(0, 6, 0),
	},
	{
		Id = "Forest",
		DisplayName = "Forest Zone",
		RequiredSpeed = 500,
		Color = Color3.fromRGB(75, 255, 80),
		PortalPosition = Vector3.new(0, 5, -90),
		DestinationPosition = Vector3.new(0, 6, -165),
	},
	{
		Id = "Crystal",
		DisplayName = "Crystal Zone",
		RequiredSpeed = 2500,
		Color = Color3.fromRGB(60, 220, 255),
		PortalPosition = Vector3.new(80, 5, -90),
		DestinationPosition = Vector3.new(80, 6, -165),
	},
	{
		Id = "Lava",
		DisplayName = "Lava Zone",
		RequiredSpeed = 10000,
		Color = Color3.fromRGB(255, 95, 45),
		PortalPosition = Vector3.new(-80, 5, -90),
		DestinationPosition = Vector3.new(-80, 6, -165),
	},
	{
		Id = "Galaxy",
		DisplayName = "Galaxy Zone",
		RequiredSpeed = 50000,
		Color = Color3.fromRGB(175, 80, 255),
		PortalPosition = Vector3.new(0, 5, -230),
		DestinationPosition = Vector3.new(0, 6, -320),
	},
}

ZoneConfig.ById = {}

for _, zone in ipairs(ZoneConfig.List) do
	ZoneConfig.ById[zone.Id] = zone
end

function ZoneConfig.Get(zoneId: string)
	return ZoneConfig.ById[zoneId]
end

return ZoneConfig
