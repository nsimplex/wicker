---
-- @description Implements curve-related classes and functions.
-- @author simplex


local Lambda = wickerrequire 'paradigms.functional'
local Pred = wickerrequire 'lib.predicates'

local Common = pkgrequire "common"
local VVF = Common.VectorValuedFunction

Curve = Class(function(self, fn, length)
	assert( Lambda.IsFunctional(fn) )
	assert( Pred.IsNonNegativeNumber(length) )
	self.fn = fn
	self.length = length
end)
local Curve = Curve
Pred.IsCurve = Pred.IsInstanceOf(Curve)


function Curve:__call(t)
	return self.fn(t)
end

function Singleton(x)
	return Curve(Lambda.Constant(x), 0)
end
local Singleton = Singleton
Constant = Singleton

Origin = Singleton(Point(0, 0, 0))

-- Concatenates two curves.
local function concatenate_two(alpha, beta)
	local a_fn, b_fn = alpha.fn, beta.fn

	local L_a, L_b = alpha.length, beta.length
	local totalL = L_a + L_b

	local l_a, l_b = L_a/totalL, L_b/totalL
	local invl_a, invl_b = 1/l_a, 1/l_b

	return Curve(function(t)
		if t < l_a then
			return a_fn(invl_a*t)
		else
			return b_fn(invl_b*(t - l_a))
		end
	end, totalL)
end

-- Concatenates a list of curves.
local function concatenate_many(t)
	local n = #t

	local fns = {}
	local Ls = {}
	local totalL = 0

	for i, gamma in ipairs(t) do
		fns[i] = gamma.fn
		local L = gamma.length
		Ls[i] = L
		totalL = totalL + L
	end

	local ls = {}
	local invls = {}

	for i, L in ipairs(Ls) do
		local l = L/totalL
		ls[i] = l
		invls[i] = 1/l
	end

	return Curve(function(t)
		for i, l in ipairs(ls) do
			if t < l then
				return fns[i](invls[i]*t)
			else
				t = t - l
			end
		end
		return fns[n](1)
	end, totalL)
end

function Curve.Concatenate(...)
	local t = {...}
	local n = #t

	if n == 1 and type(t[1]) == "table" and not Pred.IsObject(t[1]) then
		t = t[1]
		n = #t[1]
	end

	if n == 2 then
		return concatenate_two(t[1], t[2])
	elseif n == 0 then
		return Origin
	else
		return concatenate_many(t)
	end
end
Curve.__concat = concatenate_two

function Curve:__len()
	return self.length
end

function Curve:Length(t)
	return self.length*(t or 1)
end

function Curve:Invert()
	local fn = self.fn
	return Curve(function(t)
		return fn(1 - t)
	end, self.length)
end


local function private_pow(self, n)
	if n == 1 then return self end

	local sqrt = private_pow(self, math.floor(n/2))
	local sqrt_sq = Curve.Concatenate(sqrt, sqrt)
	if n % 2 == 0 then
		return sqrt_sq
	else
		return Curve.Concatenate(sqrt_sq, self)
	end
end

function Curve:__pow(n)
	if n == 0 then
		return Singleton(self.fn(0))
	else
		assert( n == math.floor(n) )
		if n > 0 then
			return private_pow(self, n)
		else
			return private_pow(self, n):Invert()
		end
	end
end

function Curve.__add(alpha, v)
	local fn
	fn, alpha = VVF.Transpose(alpha, v)
	return Curve(fn, alpha.length)
end

function Curve.__mul(alpha, lambda)
	local fn
	fn, alpha, lambda = VVF.Scale(alpha, lambda)
	return Curve(fn, alpha.length*lambda)
end


-----------------------------------------------


function LineSegment(a, b)
	if type(a) == "number" then
		length = math.abs(b - a)
	else
		length = a:Dist(b)
	end

	return Curve(function(t)
		return a + (b - a)*t
	end, length)
end

function CircularArc(radius, theta, theta0)
	radius = radius or 1
	theta = theta or 2*math.pi
	theta0 = theta0 or 0
	return Curve(function(t)
		local delta = theta*t + theta0
		return Point(radius*math.cos(delta), 0, radius*math.sin(delta))
	end, theta*radius)
end

function Circle(radius, theta0)
	return CircularArc(radius, 2*math.pi, theta0)
end

UnitCircle = Circle(1)

function Triangle(A, B, C)
	return concatenate_many {LineSegment(A, B), LineSegment(B, C), LineSegment(C, A)}
end


return _M
