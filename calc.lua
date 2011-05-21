pcall(require , 'luarocks.require')
local lpeg = require('lpeg')
require('mathx')
--local re = require('re')

-- number parser from http://lua-users.org/wiki/LpegRecipes
-- see also: http://www.gammon.com.au/forum/bbshowpost.php?bbsubject_id=9272

local Space = lpeg.S(" \n\t")^0
local Digit = lpeg.R("09")
local Number_sign = lpeg.S'+-'^-1
local Number_decimal = Digit ^ 1
local Number_hexadecimal = lpeg.P'0' * lpeg.S'xX' * lpeg.R('09', 'AF', 'af') ^ 1
-- (([0-9]+ . [0-9]∗ |. [0-9]+ )([eE][+-]?[0-9]+ )?)|[0-9]+ [eE][+-]?[0-9]+ 
local Number_float = ((Digit^1 * '.' * Digit^0 + '.' * Digit^1) * (lpeg.S'eE' * Number_sign * Digit^1)^-1) + Digit^1 * lpeg.S'eE' * Number_sign * Digit^1
local Number = lpeg.C(Number_hexadecimal + Number_float + Number_decimal + lpeg.P('pi') + lpeg.P('π') + lpeg.P('e') + lpeg.P('inf')) * Space
local Complex = (Number * lpeg.P("i") + lpeg.P("i")) * (Space -#lpeg.P("nf"))
local FactorOp = lpeg.C(lpeg.S("+-")) * Space
local TermOp = lpeg.C(lpeg.S("*/%Cd")+lpeg.P("choose")) * Space
local ExponOp = lpeg.C(lpeg.P("^")) * Space
local UnaryPreOp = lpeg.C(lpeg.S("+-")+lpeg.P('d')*#(lpeg.P(1)-lpeg.R('az','AZ'))) * Space
local UnaryPostOp = lpeg.C(lpeg.P("!")) * Space
local Open = "(" * Space
local Close = ")" * Space

local binops = {
	['+'] = function(a, b) return a + b end,
	['-'] = function(a, b) return a - b end,
	['*'] = function(a, b) return a * b end,
	['/'] = function(a, b) return a / b end,
	['%'] = function(a, b) return a % b end,
	['^'] = function(a, b) return a ^ b end,
	C = function(a, b) return binom(a, b) end,
	choose = function(a, b) return binom(a, b) end,
	d = function(a, b)
		if a > 100 then error("too many dice!", 0) end
		local ret = 0;
		for i = 1, a do
			ret = ret + math.random(b);
		end
		return ret;
	end,
}

local function binop(v1, op, v2)
	if not op or not v2 then return v1
	elseif binops[op] then return binops[op](v1, v2)
	else
		error("No such operator "..op, 0)
		return nil
	end
end

local function gcd(a, b, ...)
	if not a or not b then return nil end
	while b ~= 0 do
		a, b = b, a % b
	end
	if #{...} > 0 then
		return gcd(a, ...)
	else
		return a
	end
end

local function lcm(a, b, ...)
	if not a or not b then return nil end
	if #{...} == 0 then
		return math.abs(a*b) / gcd(a, b)
	else
		return lcm(math.abs(a*b)/gcd(a, b), ...)
	end
end

function binom(n, k)
	return gamma(n+1)/(gamma(k+1)*gamma(n-k+1))
end

local funcs = {gcd = gcd, lcm = lcm, gamma = gamma, binom = binom, choose = binom, C = binom}
for n, f in pairs(math) do
	funcs[n] = f
end
for _, n in ipairs{'fmod', 'frexp', 'ldexp', 'modf', 'randomseed', 'huge', 'pi',
	'infinity', 'isfinite', 'isinf', 'isnan', 'isnormal'} do
	funcs[n] = nil
end
funcs.ln = funcs.log
funcs.log = funcs.log10
funcs.log10 = nil

local function do_function(f, ...)
	local status, ret
	if funcs[f] then status, ret = pcall(funcs[f], ...)
	else
		error("No such function: "..f, 0)
		return nil
	end
	if not status then error("Invalid arguments to function "..f..": "..ret, 0) end
	return status and ret or nil
end

local consts = {pi = math.pi, ['π'] = math.pi, e = math.exp(1), inf = math.huge}

local function to_number(n)
	return consts[string.lower(n)] and consts[string.lower(n)] or tonumber(n)
end

local function to_complex(n)
	error("No complex arithmetic (yet?).", 0)
end

local pres = {
	['-'] = function(n) return -n end,
	['+'] = function(n) return n end,
	d = function(n) return math.random(n) end,
}

local function unary_pre(op, n)
	return pres[op] and pres[op](n) or nil
end

-- from http://web.viu.ca/pughg/phdThesis/phdThesis.pdf page 116
-- using kahan summation
 gamma = math.gamma or function(z)
	if z < 0.5 then return math.pi / (math.sin(math.pi*z) * gamma(1-z)) end
	local p = { 1.05142378581721974210e0,
	           -3.45687097222016235469e0,
	            4.51227709466894823700e0,
	           -2.98285225323576655721e0,
	            1.05639711577126713077e0,
	           -1.95428773191645869583e-1,
	            1.70970543404441224307e-2,
	           -5.71926117404305781283e-4,
	            4.63399473359905636708e-6,
	           -2.71994908488607703910e-9}
	z = z-1
	local sum =  2.48574089138753565546e-5
	local c = 0.0
	for i = 1, #p do
		local y = p[i]/(z+i) - c
		local t = sum + y
		c = (t - sum) - y
		sum = t
	end
	return 1.86038273420526571734 * ( (z + 10.900511 + 0.5) / math.exp(1) ) ^ (z+0.5) * sum
end
local posts = {
	['!'] = function(n) return gamma(n+1) end,
}

local function unary_post(n, op)
	return posts[op] and posts[op](n) or nil
end

local V = lpeg.V
calc = Space * lpeg.P{"Expr",
	Expr = lpeg.Cf(V"Factor" * lpeg.Cg(FactorOp * V"Factor")^0, binop);
	Factor = lpeg.Cf(V"Unary" * lpeg.Cg(TermOp * V"Unary")^0, binop);
	Unary = lpeg.Cf(V"Expon" * UnaryPostOp^1 , unary_post) + (UnaryPreOp * V"Unary") / unary_pre + V"Expon";
	Expon = lpeg.Cf(V"Term" * lpeg.Cg(ExponOp * V"Unary")^0, binop);
	Term = V"Func" / do_function + Open * V"Expr" * Close + Complex / to_complex + Number / to_number;
	Func = lpeg.C(lpeg.R("az","AZ") * lpeg.R("az","AZ","09")^0) * Space * Open * (V"Expr" * (Space * lpeg.P(',') * Space * V"Expr")^0)^-1 * Space * Close;
} * lpeg.Cp()


function calculate(str)
	local status, ret, pos = pcall(calc.match, calc, str)
	if not status then return nil, ret
	elseif pos == #str+1 then return ret
	elseif not pos then return nil, "Syntax error."
	else return nil, "Syntax error after "..string.sub(str, pos) end
end
