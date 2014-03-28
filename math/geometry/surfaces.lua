---
-- @description Implements surface-related classes and functions.
-- @author simplex


local Lambda = wickerrequire 'paradigms.functional'
local Pred = wickerrequire 'lib.predicates'

local Common = pkgrequire "common"
local VVF = Common.VVF

Surface = Class(function(self, fn)
	assert( Lambda.IsFunctional(fn) )
	self.fn = fn
end)
local Surface = Surface
Pred.IsSurface = Pred.IsInstanceOf(Surface)

function Surface:__call(u, v)
	return self.fn(u, v)
end

function Singleton(x)
	return Surface(Lambda.Constant(x))
end
Constant = Singleton

function Surface.__add(sigma, v)
	return Surface(VVF.Transpose(sigma, v))
end

function Surface.__mul(sigma, lambda)
	return Surface(VVF.Scale(sigma, lambda))
end

---------------------------


function Rectangle(w, h)
	return Surface(function(u, v)
		return w*u, h*v
	end)
end

UnitSquare = Rectangle(1, 1)

function DiskSector(radius, theta, theta0)
	radius = radius or 1
	theta = theta or 2*math.pi
	theta0 = theta0 or 0

	local theta_frac = theta/8

	return function(u, v)
		local r, delta

		local a, b = 2*u - 1, 2*v - 1
		local phi

		if a > -b then
			if a > b then
				r = a
				phi = theta_frac*(b/a)
			else
				r = b
				phi = theta_frac*(2 - a/b)
			end
		else
			if a < b then
				r = -a
				phi = theta_frac*(4 + b/a)
			else
				r = -b
				if b ~= 0 then
					phi = theta_frac*(6 - a/b)
				else
					phi = 0
				end
			end
		end

		r = r*radius
		delta = phi + theta_frac + theta0

		return Point(r*math.cos(delta), 0, r*math.sin(delta))
	end
end

function Disk(radius, theta0)
	return DiskSector(radius, 2*math.pi, theta0)
end

UnitDisk = Disk(1)

-- This doesn't really preserve fractional area like the above.
function AnnularSector(outer_radius, inner_radius, theta, theta0)
	outer_radius = outer_radius or 1
	inner_radius = inner_radius or 0
	theta = theta or 2*math.pi
	theta0 = theta0 or 0

	local radius_diff = outer_radius - inner_radius
	local theta_frac = theta/8

	return function(u, v)
		local r, delta

		local a, b = 2*u - 1, 2*v - 1
		local phi

		if a > -b then
			if a > b then
				r = a
				phi = theta_frac*(b/a)
			else
				r = b
				phi = theta_frac*(2 - a/b)
			end
		else
			if a < b then
				r = -a
				phi = theta_frac*(4 + b/a)
			else
				r = -b
				if b ~= 0 then
					phi = theta_frac*(6 - a/b)
				else
					phi = 0
				end
			end
		end

		r = inner_radius + r*radius_diff
		delta = phi + theta_frac + theta0

		return Point(r*math.cos(delta), 0, r*math.sin(delta))
	end
end

function Annulus(outer_radius, inner_radius, theta0)
	return AnnularSector(outer_radius, inner_radius, 2*math.pi, theta0)
end

return _M
