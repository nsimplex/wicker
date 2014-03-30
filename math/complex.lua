--[[
-- Complex number implementation as a subclass of Vector3 (with zero y coordinate).
--]]

local Pred = wickerrequire "lib.predicates"

local MathCommon = wickerrequire "math.common"

local math = math

------------------------------------------------------------------------

local C = Class(Vector3, function(self, re, im)
	if Pred.IsVector3(re) then
		Vector3._ctor(self, re.x, re.y, re.z)
	else
		Vector3._ctor(self, re, 0, im)
	end
end)
local Complex = C
Pred.IsComplex = Pred.IsInstanceOf(C)
Pred.IsComplexNumber = Pred.IsComplex


-- The y coordinate is just stored along for easier use alongside Vector3's.
local function ugly_C(re, im, y)
	local a = C(re, im)
	a.y = y or 0
	return a
end

function C.ToComplex(x, y, z)
	local a = MathCommon.ToPoint(x, y, z)

	if Pred.IsComplex(x) then
		return x
	else
		return C(x)
	end
end
MathCommon.ToComplex = C.ToComplex

function C:Copy()
	return C(self)
end

function C.Polar(r, theta)
	return C(r*math.cos(theta), r*math.sin(theta))
end

function C.RootOfUnity(n, k)
	return C.Polar(1, 2*(k or 1)*math.pi/n)
end

------------------------------------------------------------------------

C[0] = C(0)
C.Zero = C[0]

C[1] = C(1)
C.One = C[1]

C.i = C(0, 1)

------------------------------------------------------------------------

function C:Re()
	return self.x
end
function C:Im()
	return self.z
end

function C:GetPair()
	return self.x, self.z
end
C.GetTriple = C.Get

function C.Conjugate(a)
	if Pred.IsNumber(a) then
		return a
	end
	return ugly_C( a.x, -a.z, a.y )
end
C.Bar = C.Conjugate

------------------------------------------------------------------------

local function raw_abs_sq(a)
	return a.x*a.x + a.z*a.z
end

function C.AbsSq(a)
	if Pred.IsNumber(a) then
		return a*a
	end
	return raw_abs_sq(a)
end

function C.Abs(a)
	if Pred.IsNumber(a) then
		return math.abs(a)
	end
	return math.sqrt( raw_abs_sq(a) )
end

function C.Arg(a)
	if Pred.IsNumber(a) then
		if a >= 0 then
			return 0
		else
			return math.pi
		end
	end
	return math.atan2(a.z, a.x)
end

-- principal sqrt.
function Complex.sqrt(a)
	return C.Polar( math.sqrt(C.Abs(a)), C.Arg(a)/2 )
end
Complex.SquareRoot = Complex.sqrt

-- principal nth root.
function Complex.root(a, n)
	return C.Polar( C.Abs(a)^(1/n), C.Arg(a)/n )
end
Complex.Root = Complex.root

------------------------------------------------------------------------

function Complex.Add(a, b)
	if not Pred.IsComplex(a) then
		a, b = b, a
	end
	if Pred.IsNumber(b) then
		if Pred.IsNumber(a) then
			return a + b
		end
		return ugly_C( a.x + b, a.z, a.y )
	end
	return ugly_C( a.x + b.x, a.z + b.z, a.y + b.y )
end
Complex.__add = Complex.Add

function Complex.Negate(a)
	if Pred.IsNumber(a) then
		return -a
	end
	return ugly_C( -a.x, -a.z, -a.y )
end
Complex.__unm = Complex.Negate


local function complex_multiply(a, b)
	return ugly_C( a.x*b.x - a.z*b.z, a.x*b.z + a.z*b.x, b.y )
end

function Complex.Multiply(a, b)
	if not Pred.IsComplex(a) then
		a, b = b, a
	end
	if Pred.IsNumber(b) then
		return ugly_C(b*a.x, b*a.z, b*a.y)
	end
	return complex_multiply(a, b)
end
Complex.__mul = Complex.Multiply


function Complex.Invert(a)
	if Pred.IsNumber(a) then
		return 1/a
	end
	local c = 1/self:AbsSq()
	return ugly_C( c*a.x, -c*a.z, a.y )
end

function Complex.Divide(a, b)
	return Complex.Multiply(a, Complex.Invert(b))
end
Complex.__div = Complex.Divide


function Complex.exp(a)
	if Pred.IsNumber(a) then
		return C(math.exp(a))
	end

	return Complex.Polar(math.exp(a.x), a.z)
end
Complex.Exp = Complex.exp

-- principal value
function Complex.Log(a)
	if Pred.IsNumber(a) then
		return C(math.log(a))
	end
	return C(math.log(a:Abs()), a:Arg())
end
Complex.log = Complex.Log

-- For positive integer exponents.
local fast_pow = MathCommon.FastExponentiator(complex_multiply)

function Complex.pow(a, b)
	if Pred.IsNumber(b) and b == math.floor(b) then
		if b == 0 then
			return C(1)
		elseif b < 0 then
			a = C.Invert(a)
			b = -b
		end

		if Pred.IsNumber(a) then
			return MathCommon.FastPow(a, b)
		else
			return fast_pow(a, b)
		end
	end

	return Complex.exp(Complex.Log(a)*b)
end
Complex.Pow = Complex.pow

------------------------------------------------------------------------

function Complex:__tostring()
	if self.y ~= 0 then
		return Vector3.__tostring(self)
	end
	return ("%2.2f + i%2.2f"):format(self.x, self.z)
end

------------------------------------------------------------------------


return C
