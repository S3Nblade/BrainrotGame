-- Compiled with roblox-ts v3.0.0
local function formatMoney(amount, isDollars)
	local str = tostring(math.floor(amount))
	local result = ""
	local count = 0
	for i = #str, 1, -1 do
		if count > 0 and count % 3 == 0 then
			result = "," .. result
		end
		local _i = i
		local _i_1 = i
		result = string.sub(str, _i, _i_1) .. result
		count += 1
	end
	return if isDollars then `${result}` else result
end
return {
	formatMoney = formatMoney,
}
