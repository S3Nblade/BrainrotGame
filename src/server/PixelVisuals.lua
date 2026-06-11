local PixelVisuals = {}

local PATTERNS = {
	ByteBunny = {
		"  O O  ",
		"  O O  ",
		" OBBBO ",
		"OBWBWBO",
		"OBBBBBO",
		" OMMMO ",
		" O O O ",
	},
	ToastGhost = {
		" OOOOO ",
		"OBBBBBO",
		"OBWBWBO",
		"OBBBBBO",
		"OBMMMBO",
		"OBBOBBO",
		"O O O O",
	},
	PuddlePup = {
		" OO OO ",
		"OBBOBBO",
		"OBBBBBO",
		"OBWBWBO",
		"OBBBBBO",
		" OMMMO ",
		" OO OO ",
	},
	CactusCat = {
		" OO OO ",
		"OBBOBBO",
		"OBBBBBO",
		"OBWBWBO",
		"OBMMMBO",
		"OBBBBBO",
		" O O O ",
	},
	DuneDuck = {
		" OOOOO ",
		"OBBBBBO",
		"OBWBWBO",
		"OBBBBBM",
		"OBBBBBM",
		" OBBBO ",
		" O O O ",
	},
	FrostFrog = {
		" OO OO ",
		"OBWOBWO",
		"OBBBBBO",
		"OBMMMBO",
		"OBBBBBO",
		"OOBBBOO",
		"O O O O",
	},
	ChillChinchilla = {
		"O O O O",
		" OOOOO ",
		"OBBBBBO",
		"OBWBWBO",
		"OBBBBBO",
		" OMMMO ",
		" OO OO ",
	},
	MagmaMoth = {
		"O  O  O",
		"OO O OO",
		" OBBB O",
		"OBWBWBO",
		" OBBB O",
		"OO M OO",
		"O  O  O",
	},
	EmberEel = {
		"       ",
		" OOOOO ",
		"OBBBBBO",
		"OOWBWBO",
		"   OBBO",
		" OOOOB ",
		"OO     ",
	},
	GlitchGloop = {
		"  OOO  ",
		" OBBBO ",
		"OBWBWBO",
		"OBBBBBO",
		"OBMMMBO",
		"OBOBOBO",
		"O O O O",
	},
	NullNarwhal = {
		"   M   ",
		"  MMO  ",
		" OBBBO ",
		"OBWBWBO",
		"OBBBBBO",
		" OMMMO ",
		" OO OO ",
	},
	PixelPrime = {
		"M M M M",
		"OMMMMOO",
		"OBBBBBO",
		"OBWBWBO",
		"OBMMMBO",
		" OBBBO ",
		" OO OO ",
	},
}

local function shade(color, amount)
	return Color3.new(
		math.clamp(color.R + amount, 0, 1),
		math.clamp(color.G + amount, 0, 1),
		math.clamp(color.B + amount, 0, 1)
	)
end

local function pixel(parent, name, position, size, color, height)
	local item = Instance.new("Part")
	item.Name = name
	item.Anchored = true
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.CastShadow = false
	item.Material = Enum.Material.SmoothPlastic
	item.Size = Vector3.new(size, height or 0.32, size)
	item.Position = position
	item.Color = color
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.Parent = parent
	return item
end

function PixelVisuals.Build(model, root, brainrotId, baseColor, rarityColor, scale, mutationColor)
	scale = scale or 0.82
	local pattern = PATTERNS[brainrotId] or PATTERNS.ByteBunny
	local art = Instance.new("Folder")
	art.Name = "PixelArt"
	art.Parent = model
	local outline = Color3.fromRGB(25, 27, 39)
	local highlight = shade(baseColor, 0.18)
	local mouth = mutationColor or shade(baseColor, -0.18)
	local origin = root.Position + Vector3.new(0, 0.5, 0)

	for row, line in ipairs(pattern) do
		for column = 1, #line do
			local symbol = string.sub(line, column, column)
			if symbol ~= " " then
				local color = baseColor
				if symbol == "O" then
					color = outline
				elseif symbol == "W" then
					color = Color3.fromRGB(248, 250, 255)
				elseif symbol == "M" then
					color = mouth
				elseif (row + column) % 4 == 0 then
					color = highlight
				end
				local offsetX = (column - 4) * scale
				local offsetZ = (row - 4) * scale
				pixel(art, "Pixel", origin + Vector3.new(offsetX, 0, offsetZ), scale * 0.94, color)
			end
		end
	end

	local shadow =
		pixel(art, "Shadow", root.Position + Vector3.new(0, 0.24, 0.25), scale * 5.4, Color3.fromRGB(18, 20, 31), 0.12)
	shadow.Transparency = 0.42

	for index = 1, 4 do
		local angle = math.pi * 2 * index / 4
		local sparkle = pixel(
			art,
			"RaritySpark",
			origin + Vector3.new(math.cos(angle) * scale * 4.3, 0.08, math.sin(angle) * scale * 4.3),
			scale * 0.42,
			rarityColor,
			0.18
		)
		sparkle.Material = Enum.Material.Neon
	end

	root.Transparency = 1
	return art
end

return PixelVisuals
