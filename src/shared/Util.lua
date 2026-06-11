local HttpService = game:GetService("HttpService")

local Util = {}

function Util.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[Util.DeepCopy(key)] = Util.DeepCopy(child)
	end
	return copy
end

function Util.WeightedChoice(entries, random)
	local total = 0
	for _, entry in ipairs(entries) do
		total += entry.Weight
	end
	local roll = (random or Random.new()):NextNumber(0, total)
	local cursor = 0
	for _, entry in ipairs(entries) do
		cursor += entry.Weight
		if roll <= cursor then
			return entry.Value
		end
	end
	return entries[#entries].Value
end

function Util.NewId()
	return HttpService:GenerateGUID(false)
end

function Util.FormatNumber(value)
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local index = 1
	local number = math.max(0, value)
	while number >= 1000 and index < #suffixes do
		number /= 1000
		index += 1
	end
	if index == 1 then
		return tostring(math.floor(number))
	end
	return string.format("%.1f%s", number, suffixes[index])
end

return Util
