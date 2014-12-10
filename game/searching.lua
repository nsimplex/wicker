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

local ToComplex = Math.ToComplex


---


local basic_finders
basic_finders = {
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
		local E = basic_finders.all(ent_gen, fn, ...)
		local l = #E
		if l > 0 then
			return E[math.random(l)]
		end
	end,
	closest = function(ent_gen, fn, center, ...)
		local weight = Lambda.BindSecond(EntityScript.GetDistanceSqToPoint, center)
		return (Lambda.Minimize(weight, ipairs(basic_finders.all(ent_gen, fn, center, ...))))
	end,
	closests = function(ent_gen, fn, center, max_count, ...)
		local E = basic_finders.all(ent_gen, fn, center, ...)

		local distSqTo = EntityScript.GetDistanceSqToPoint
		
		local function cmp(instA, instB)
			return distSqTo(instA, center) < distSqTo(instB, center)
		end

		return Algo.LeastElementsOf(E, max_count, cmp)
	end,
}

local function general_ent_gen(center, radius, and_tags, not_tags, or_tags)
	return ipairs(TheSim:FindEntities(center.x, center.y, center.z, radius, and_tags, not_tags, or_tags))
end

local player_ent_gen
if not IsDST() then
	player_ent_gen = function()
		return Lambda.iterator.Singleton(GetLocalPlayer())
	end
else
	player_ent_gen = function()
		return ipairs(_G.AllPlayers)
	end
end

local function MakeEntSearcher(basic_prototype)
	return function(center, radius, fn, and_tags, not_tags, or_tags)
		center = ToPoint(center)
		fn = Pred.ToPredicate(fn)
		return basic_prototype(general_ent_gen, fn, center, radius, and_tags, not_tags, or_tags)
	end
end

local function MakeClosestEntsSearcher()
	local basic_prototype = basic_finders.closests
	return function(center, radius, fn, max_count, and_tags, not_tags, or_tags)
		center = ToPoint(center)
		fn = Pred.ToPredicate(fn)
		return basic_prototype(general_ent_gen, fn, center, max_count, radius, and_tags, not_tags, or_tags)
	end
end

-- Center is only required for the "closest" search.
local function MakePlayerSearcher(basic_prototype)
	return function(fn)
		fn = Pred.ToPredicate(fn)
		return basic_prototype(player_ent_gen, fn)
	end
end

local function MakeCenteredPlayerSearcher(basic_prototype)
	return function(center, fn, ...)
		center = ToPoint(center)
		fn = Pred.ToPredicate(fn)
		return basic_prototype(player_ent_gen, fn, center, ...)
	end
end

local function MakeBoundedPlayerSearcher(basic_prototype)
	return function(center, radius, fn, ...)
		local center = ToPoint(center)
		local radiussq = radius*radius

		local function cond(inst)
			return inst:GetDistanceSqToPoint(center) < radiussq
		end

		if fn then
			fn = Lambda.And(Pred.ToPredicate(fn), cond)
		else
			fn = cond
		end

		return basic_prototype(player_ent_gen, fn, center, ...)
	end
end


---


FindAllEntities = MakeEntSearcher(basic_finders.all)
GetAllEntities = FindAllEntities

FindSomeEntity = MakeEntSearcher(basic_finders.any)
GetSomeEntity = FindSomeEntity

FindRandomEntity = MakeEntSearcher(basic_finders.random)
GetRandomEntity = FindRandomEntity

FindClosestEntity = MakeEntSearcher(basic_finders.closest)
GetClosestEntity = FindClosestEntity

FindClosestEntities = MakeClosestEntsSearcher()
GetClosestEntities = FindClosestEntities


FindAllPlayers = MakePlayerSearcher(basic_finders.all)
GetAllPlayers = FindAllPlayers

FindSomePlayer = MakePlayerSearcher(basic_finders.any)
GetSomePlayer = FindSomePlayer

FindRandomPlayer = MakePlayerSearcher(basic_finders.random)
GetRandomPlayer = FindRandomPlayer

FindClosestPlayer = MakeCenteredPlayerSearcher(basic_finders.closest)
GetClosestPlayer = FindClosestPlayer

FindClosestPlayers = MakeCenteredPlayerSearcher(basic_finders.closests)
GetClosestPlayers = FindClosestPlayers


FindAllPlayersInRange = MakeBoundedPlayerSearcher(basic_finders.all)
GetAllPlayersInRange = FindAllPlayersInRange

FindSomePlayerInRange = MakeBoundedPlayerSearcher(basic_finders.any)
GetSomePlayerInRange = FindSomePlayerInRange

FindRandomPlayerInRange = MakeBoundedPlayerSearcher(basic_finders.random)
GetRandomPlayerInRange = FindRandomPlayerInRange

FindClosestPlayerInRange = MakeBoundedPlayerSearcher(basic_finders.closest)
GetClosestPlayerInRange = FindClosestPlayerInRange

FindClosestPlayersInRange = MakeBoundedPlayerSearcher(basic_finders.closests)
GetClosestPlayersInRange = FindClosestPlayersInRange
