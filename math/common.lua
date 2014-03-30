local Lambda = wickerrequire "paradigms.functional"

function ToPoint(x, y, z)
	x = x or 0

	if Pred.IsNumber(x) then
		y = y or 0
		z = z or 0
		if Pred.IsNumber(y) and Pred.IsNumber(z) then
			return Point(x, y, z)
		end
	elseif Pred.IsEntityScript(x) then
		return x:GetPosition()
	end

	if Pred.IsPoint(x) then
		return x
	end

	return error( ("point expected, got %s"):format(type(x)) )
end

--[[
-- log(n) exponentiation for positive integer n.
--]]
function FastExponentiator(op)
	op = op or Lambda.Multiply

	local function pow(x, n)
		if n == 1 then return x end

		local a = pow(x, math.floor(n/2), op)
		if n % 2 == 0 then
			return op(a, a)
		else
			return op(op(a, a), x)
		end
	end

	return pow
end

FastPow = FastExponentiator()
