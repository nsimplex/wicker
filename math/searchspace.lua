local Geometry = wickerrequire "math.geometry"

local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"


local bidimensional_rng = Lambda.CartesianProduct(math.random, math.random)

local SearchSpace = Class(function(self, object, maxtries)
	self.object = object

	if Pred.IsCurve(object) then
		self.rng = math.random
	elseif Pred.IsSurface(object) then
		self.rng = bidimensional_rng
	else
		return error("Curve or Surface expected as 'object' parameter, got "..tostring(object)..".", 2)
	end

	self.maxtries = maxtries or 16
end)
Pred.IsSearchSpace = Pred.IsInstanceOf(SearchSpace)


function SearchSpace:GetObject()
	return self.object
end

function SearchSpace:GetPoint(u, v)
	if u then
		return self.object(u, v)
	else
		return self.object(self.rng())
	end
end

---
-- Finds a point in the associated object satisfying p.
function SearchSpace:Find(p, maxtries)
	maxtries = maxtries or self.maxtries

	for _ = 1, maxtries do
		local pt = self.object(self.rng())
		if p(pt) then
			return pt
		end
	end
end
SearchSpace.Search = SearchSpace.Find

---
-- Searches deterministically.
--
-- @param p The predicate to be satisfied by a point.
-- @param n The number of horizontal subdivisions (columns).
-- @param m The number of vertical subdivisions (rows); ignored when self.object is a curve.
function SearchSpace:FindByLattice(p, n, m)
	if self.rng == bidimensional_rng then
		if n == nil and m == nil then
			local root = self.max_square_tries
			if root == nil then
				root = math.max(1, math.floor(math.sqrt(self.maxtries)) - 1)
				self.max_square_tries = root
			end
			n, m = root, root
		elseif n == nil then
			n = math.max(1, self.maxtries/(1 + m) - 1)
		elseif m == nil then
			m = math.max(1, self.maxtries/(1 + n) - 1)
		end

		local hor_step = 1/n
		local vert_step = 1/m
		local j0 = math.random(0, n)
		local i0 = math.random(0, m)
		for dj = 0, n do
			for di = 0, m do
				local j, i = j0 + dj, i0 + di
				if j > n then
					j0 = j0 - n
					j = j - n
				end
				if i > m then
					i0 = i0 - m
					i = i - m
				end
				local pt = self.object( j*hor_step, i*vert_step )
				if p(pt) then
					return pt
				end
			end
		end
	else
		n = n or math.max(1, self.maxtries - 1)

		local hor_step = 1/n
		local j0 = math.random(0, n)
		for dj = 0, n do
			local j = j0 + dj
			if j > n then
				j0 = j0 - n
				j = j - n
			end
			local pt = self.object( j*hor_step )
			if p(pt) then
				return pt
			end
		end
	end
end
SearchSpace.SearchByLattice = SearchSpace.FindByLattice

function SearchSpace:__call(p, maxtries)
	if p then
		return self:Find(p, maxtries)
	else
		return self:GetPoint()
	end
end


return SearchSpace
