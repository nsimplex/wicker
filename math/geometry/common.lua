local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"

VectorValuedFunction = {}

local VVF = VectorValuedFunction


local function fn_first(f, x)
	if Lambda.IsFunctional(f) then
		return f, x
	else
		assert( Lambda.IsFunctional(x) )
		return x, f
	end
end

local function get_raw_fn(f)
	if type(f) == "table" and type(f.fn) == "function" then
		return f.fn
	else
		return f
	end
end

local function VVF_rawTranspose(f, v)
	assert( Pred.IsPoint(v) )
	local f_prime = get_raw_fn(f)
	return function(...)
		return f_prime(...) + v
	end, f, v
end

VVF.Transpose = Lambda.Compose(VVF_rawTranspose, fn_first)

function VVF.Add(f, g)
	f, g = fn_first(f, g)
	if not Lambda.IsFunctional(g) then
		return VVF_rawTranspose(f, g)
	else
		local f_prime, g_prime = get_raw_fn(f), get_raw_fn(g)
		return function(...)
			return f_prime(...) + g_prime(...)
		end, f, g
	end
end

local function VVF_rawScale(f, lambda)
	assert( Pred.IsNumber(lambda) )
	local f_prime = get_raw_fn(f)
	return function(...)
		return f_prime(...)*lambda
	end, f, lambda
end

VVF.Scale = Lambda.Compose(VVF_rawScale, fn_first)
VVF.Mul = VVF.Scale
