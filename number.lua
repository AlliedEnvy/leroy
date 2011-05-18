local bits = 1
while 2^(bits+1)+1 > 2^(bits+1) do bits = bits + 1 end
local digits = math.floor(math.log10(2^(bits/2)))
local max_limb = math.pow(10, digits)

local longnum_mt = {
__tostring = function(n)
	local ret = {string.format("%d",n[#n])}
	local dp = n.dp
	for i = #n-1, 1, -1 do
		if i == dp then table.insert(ret, '.') end
		table.insert(ret, string.format("%0"..digits.."u", math.abs(n[i])))
	end
	if n.dp < 0 or n.dp >= #n then table.insert(ret, 'e'..digits*(-n.dp)) end
	return table.concat(ret)
end,
__unm = function(ln)
	local ret = longnum(ln)
	for i, n in ipairs(ret) do
		ret[i] = -n
	end
	return ret
end,
__add = function(a, b)
	a = longnum(a)
	b = longnum(b)
--[[
	least significant ----- most significant
	1 2 3 4 .... #n
	aaaaaa.aa
	bbb.bbbb
--]]
	--local a_pre_dp = math.max(a.dp, 0)
	--local a_post_dp = math.max(#a-a.dp, 0)
	--local b_pre_dp = math.max(b.dp, 0)
	--local b_post_dp = math.max(#b-b.dp, 0)
	while a.dp < b.dp do table.insert(a, 1, 0); a.dp = a.dp+1 end
	while b.dp < a.dp do table.insert(b, 1, 0); b.dp = b.dp+1 end
	while (#a-a.dp) < (#b-b.dp) do table.insert(a, 0) end
	while (#a-a.dp) > (#b-b.dp) do table.insert(b, 0) end
	for i = 1, #b do
		a[i] = a[i] + b[i]
	end
	for i = 1, #a do
		local carry
		a[i], carry = a[i] % max_limb, math.floor(a[i] / max_limb)
		a[i+1] = (a[i+1] or 0) + carry
	end
	while a[#a] == 0 do a[#a] = nil end
	while a[1] == 0 do table.remove(a, 1); a.dp = a.dp-1 end
	return a
end,
__sub = function(a, b)
	return a + -b
end,
__mul = function(a, b)
	if type(a) == 'number' or type(a) == 'string' then a = longnum(a) end
	if type(b) == 'number' or type(b) == 'string' then b = longnum(b) end
	local arr = {}
	for i, n in ipairs(a) do
		arr[i] = {}
		for j, m in ipairs(b) do
			arr[i][j] = n*m
		end
	end
	local ret = longnum(0)
	for i = 1, #arr do
		for j = 1, #arr[i] do
			ret[i+j-1] = ret[i+j-1] + arr[i][j]
			local carry
			ret[i+j-1], carry = ret[i+j-1] % max_limb, math.floor(ret[i+j-1] / max_limb)
			ret[i+j] = (ret[i+j] or 0) + carry
		end
	end
	ret.dp = a.dp + b.dp
	while ret[#ret] == 0 do ret[#ret] = nil end
	while ret[1] == 0 do table.remove(ret, 1); ret.dp = ret.dp-1 end
	return ret
end,
}

function truncate(n)
	return n < 0 and math.ceil(n) or math.floor(n)
end

function longnum(n)
	if n == nil then return nil end
	local ret = {}
	if type(n) == 'number' then
		local ipart, fpart = math.modf(n)
		ret.dp = 0
		while fpart ~= 0 do
			local limb
			limb, fpart = math.modf(fpart*max_limb)
			if not(ipart == 0 and limb == 0 and #ret == 0) then
				table.insert(ret, 1,limb)
			end
			ret.dp = ret.dp+1
		end
		while ipart ~=0 or #ret == 0 do
			local limb
			limb, ipart = math.fmod(ipart, max_limb), truncate(ipart / max_limb)
			if ipart ~= 0 and limb == 0 and #ret == 0 then
				ret.dp = ret.dp-1
			else
				table.insert(ret, limb)
			end
		end
	elseif type(n) == 'string' then
		
	elseif type(n) == 'table' and getmetatable(n) == longnum_mt then
		ret.dp = n.dp
		for i, m in ipairs(n) do
			ret[i] = m
		end
	end
	setmetatable(ret, longnum_mt)
	return ret
end
