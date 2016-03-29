--[[
Copyright (C) 2013  simplex

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]--


BecomePackage "common"


local EntityScript = EntityScript
local Point = Point

local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'lib.logic'

local Pred = wickerrequire 'lib.predicates'

local Math = wickerrequire "math"

local Algo = wickerrequire "utils.algo"


local ToPoint = Math.ToPoint
local CoerceToPoint = Math.CoerceToPoint

local ToComplex = Math.ToComplex


---

--[[
-- General purpose, always valid finders which only rely on essential
-- properties of EntityScript with no setup.
--]]
local raw_basic_finders
raw_basic_finders = {
	all = function(ent_gen, fn, ...)
		return Lambda.CompactlyFilter(
			function(v)
				return Pred.IsOk(v) and fn(v)
			end,
			ent_gen(...)
		)
	end,
	any = function(ent_gen, fn, ...)
		return Lambda.Find(
			function(v)
				return Pred.IsOk(v) and fn(v)
			end,
			ent_gen(...)
		)
	end,
	random = function(ent_gen, fn, ...)
		local E = raw_basic_finders.all(ent_gen, fn, ...)
		local l = #E
		if l > 0 then
			return E[math.random(l)]
		end
	end,
}

local basic_finders = {}
for k, v in pairs(raw_basic_finders) do
	basic_finders[k] = function(ent_gen, fn, ...)
		fn = Pred.ToPredicate(fn)
		return v(ent_gen, fn, ...)
	end
end

--[[
-- Finders relying on a metric. The entities involved must have a Transform
-- component, and extra data related to positioning is passed.
--]]
local raw_metric_finders
raw_metric_finders = {
	closest = function(ent_gen, fn, center, radius, ...)
		local weight = Lambda.BindSecond(EntityScript.GetDistanceSqToPoint, center)
		return (Lambda.Minimize(weight, ipairs(basic_finders.all(ent_gen, fn, center, radius, ...))))
	end,
	closests = function(ent_gen, fn, center, radius, max_count, ...)
		local E = basic_finders.all(ent_gen, fn, center, radius, ...)

		local distSqTo = EntityScript.GetDistanceSqToPoint
		
		local function cmp(instA, instB)
			return distSqTo(instA, center) < distSqTo(instB, center)
		end

		return Algo.LeastElementsOf(E, max_count, cmp)
	end,
}

local metric_finders = {}
for k, v in pairs(raw_metric_finders) do
	metric_finders[k] = function(ent_gen, fn, center, radius, ...)
		center = ToPoint(center)
		if radius < 0 then
			return error("Negative radius given to entity finder", 2)
		end
		return v(ent_gen, fn, center, radius, ...)
	end
end

-- Extends a table of generators with default values built from those present.
local function MakeGenDefaults(gens)
	local basic_gen = gens.basic
	local metric_gen = gens.metric

	if not metric_gen and basic_gen then
		gens.metric = function(center, radius, ...)
			local radiussq = radius*radius

			local function p(inst)
				return inst:GetDistanceSqToPoint(center) < radiussq
			end

			return Lambda.iterator.Filter(p, basic_gen(...))
		end
	end

	return gens
end

-- Takes a basic_finders prototype and returns a wrapped version of it not
-- using any metric property.
local function MakeNonMetricFinder(basic_prototype, gens)
	local basic_gen = assert( gens.basic )
	return Lambda.BindFirst(basic_prototype, basic_gen)
end

-- Takes a finder prototype and returns a wrapped version of it which
-- necessarily uses metric properties.
local function MakeMetricFinder(basic_prototype, gens)
	local metric_gen = assert( gens.metric )
	return Lambda.BindFirst(basic_prototype, metric_gen)
end

-- Takes a basic_finders prototype and returns a wrapped version of it which
-- may or may not use the metric entity generator depending on argument
-- inspection.
local function MakeOptionallyMetricFinder(basic_prototype, gens)
	local type = assert( type )

	local basic_gen = assert( gens.basic )
	local metric_gen = assert( gens.metric )

	return function(center, radius, fn, ...)
		local gen
		if type(radius) ~= "number" or CoerceToPoint(center) == nil then
			-- Then center is the fn.
			gen = basic_gen
		else
			gen = metric_gen
		end
		return basic_prototype(gen, center, radius, fn, ...)
	end
end


-- Generates the wrapped finders table for the gens available.
local function MakeFinders(gens)
	local ret = {}

	gens = MakeGenDefaults(gens)

	local basic_gen = gens.basic
	local metric_gen = gens.metric

	local MakeBasicFinder

	if basic_gen and metric_gen then
		MakeBasicFinder = MakeOptionallyMetricFinder
	elseif basic_gen then
		MakeBasicFinder = MakeNonMetricFinder
	elseif metric_gen then
		MakeBasicFinder = MakeMetricFinder
	end

	assert(MakeBasicFinder)

	ret.basic = {}
	ret.metric = {}

	for k, v in pairs(basic_finders) do
		ret[k] = MakeBasicFinder(v, gens)
		if basic_gen then
			ret.basic[k] = MakeNonMetricFinder(v, gens)
		end
		if metric_gen then
			ret.metric[k] = MakeMetricFinder(v, gens)
		end
	end

	if metric_gen then
		for k, v in pairs(metric_finders) do
			ret[k] = MakeMetricFinder(v, gens)
			ret.metric[k] = ret[k]
		end
	end

	return ret
end

-----

local ent_gens = {}

function ent_gens.metric(center, radius, and_tags, not_tags, or_tags)
	return ipairs(TheSim:FindEntities(center.x, center.y, center.z, radius, and_tags, not_tags, or_tags))
end

function ent_gens.basic()
	return ipairs(_G.Ents)
end

local ent_finders = MakeFinders(ent_gens)

---

local player_gens = {}

if not IsDST() then
	player_gens.basic = function()
		return Lambda.iterator.SingletonList(1, GetLocalPlayer())
	end
else
	player_gens.basic = function()
		return ipairs(_G.AllPlayers)
	end
end

local player_finders = MakeFinders(player_gens)

-----

FindAllEntities = ent_finders.all
GetAllEntities = FindAllEntities

FindSomeEntity = ent_finders.any
GetSomeEntity = FindSomeEntity

FindRandomEntity = ent_finders.random
GetRandomEntity = FindRandomEntity

FindClosestEntity = ent_finders.closest
GetClosestEntity = FindClosestEntity

FindClosestEntities = ent_finders.closests
GetClosestEntities = FindClosestEntities

---

FindAllPlayers = player_finders.all
GetAllPlayers = FindAllPlayers

FindSomePlayer = player_finders.any
GetSomePlayer = FindSomePlayer
FindAnyPlayer = FindSomePlayer
GetAnyPlayer = FindSomePlayer

FindRandomPlayer = player_finders.random
GetRandomPlayer = FindRandomPlayer

FindClosestPlayer = player_finders.closest
GetClosestPlayer = FindClosestPlayer

FindClosestPlayers = player_finders.closests
GetClosestPlayers = FindClosestPlayers


FindAllPlayersInRange = player_finders.metric.all
GetAllPlayersInRange = FindAllPlayersInRange

FindSomePlayerInRange = player_finders.metric.any
GetSomePlayerInRange = FindSomePlayerInRange

FindRandomPlayerInRange = player_finders.metric.random
GetRandomPlayerInRange = FindRandomPlayerInRange

FindClosestPlayerInRange = player_finders.metric.closest
GetClosestPlayerInRange = FindClosestPlayerInRange

FindClosestPlayersInRange = player_finders.metric.closests
GetClosestPlayersInRange = FindClosestPlayersInRange

---

return _M
