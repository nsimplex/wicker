local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"

-- Coerces a value to a Point object, returning nil if that is not possible.
function CoerceToPoint(x)
	if Pred.IsPoint(x) then
		return x
	elseif Pred.IsEntityScript(x) then
		return x:GetPosition()
	elseif x == nil then
		return Point()
	end
end
local CoerceToPoint = CoerceToPoint

-- Hardened version of the above which also works for triples of numbers.
function ToPoint(x, y, z)
	if x == nil then
		if y == nil and z == nil then
			TheMod:Warn("coercing nil to Point(0, 0, 0)")
			return Point(0, 0, 0)
		end
		x = 0
	end

	if Pred.IsNumber(x) then
		y = y or 0
		z = z or 0
		if Pred.IsNumber(y) and Pred.IsNumber(z) then
			return Point(x, y, z)
		end
	else
		local pt = CoerceToPoint(x)
		if pt ~= nil then
			return pt
		end
	end

	return error( ("point expected, got %s"):format(type(x)), 1 )
end

--[[
-- log(n) exponentiation for positive integer n.
--]]
function FastExponentiator(op)
	op = op or Lambda.Multiply

	local function pow(x, n)
		if n == 1 then return x end

		local a = pow(x, math.floor(n/2))
		if n % 2 == 0 then
			return op(a, a)
		else
			return op(op(a, a), x)
		end
	end

	return pow
end

FastPow = FastExponentiator()
