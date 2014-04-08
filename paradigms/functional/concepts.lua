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

local Lambda = pkgrequire "common"
local Iterator = pkgrequire "iterator"

local Identity = Lambda.Identity
local IsFunctional = Lambda.IsFunctional
local IsNil = Lambda.IsNil
local FirstOf = Lambda.FirstOf
local Compose = Lambda.Compose

local True, False = Lambda.True, Lambda.False

--[[
-- Search and transformation.
-- Iterators are assumed to return 1 or 2 elements in the non-list versions.
--
-- If returning two, they are assumed to work like Lua's ipairs and pairs,
-- where the actual value is the second, and the first has less importance.
-- So they are flipped, for general convenience.
--
-- The list versions preserve everything (at the added overhead of creating
-- temporary tables to store the lists).
--]]

function GenerateConceptsFromIteration(IteratorGenerator, ret)
	ret = ret or {}

	assert( IsFunctional(IteratorGenerator) )

	if not ret.Find then
		local function Find(p, ...)
			for v, k in Iterator.FlipFirstTwo( IteratorGenerator(...) ) do
				if p(v, k) then
					return v, k
				end
			end
		end
		ret.Find = Find

		ret = GenerateConceptsFromSearching(Find, ret)
	end

	if not ret.ListFind then
		local function ListFind(p, ...)
			local f, s, var = IteratorGenerator(...)

			local E = Lambda.EvaluationMap( f(s, var) )

			while not E(IsNil) do
				if E(p) then
					return E()
				end
				E = Lambda.EvaluationMap( f(s, E(FirstOf)) )
			end
		end
		ret.ListFind = ListFind

		assert( Lambda.IsFunctional(Lambda.MapIntoIf) )

		Lambda.MapIntoIf(
			function(v, k) return ret['List' .. k] == nil end,
			function(v, k) return v, ('List' .. k) end,
			ret,
			pairs( GenerateConceptsFromSearching(ListFind) )
		)
	end

	return ret
end

--[[
-- Generates derivative concepts from searching into ret.
-- We require only that the searching function takes the predicate as its
-- first argument.
--]]
function GenerateConceptsFromSearching(Find, ret)
	ret = ret or {}

	assert( IsFunctional(Find) )

	if not ret.Apply then
		local function Apply(f, ...)
			return Find(Compose(False, f), ...)
		end
		ret.Apply = Apply

		ret = GenerateConceptsFromApplying(Apply, ret)
	end

	return ret
end

---[[
-- Generates derivative concepts from applying into ret.
-- We require only that the apply function takes the map as its
-- first argument.
--]]
function GenerateConceptsFromApplying(Apply, ret)
	ret = ret or {}

	assert( IsFunctional(Apply) )

	local function ApplyIf(p, f, ...)
		return Apply(function(...)
			if p(...) then
				f(...)
			end
		end, ...)
	end
	ret.ApplyIf = ApplyIf

	local function MapInto(map, t, ...)
		local push = Lambda.StackPusher(t)
		Apply(function(v, k)
			if k ~= nil then
				local oldk = k
				v, k = map(v, k)
				t[k or oldk] = v
			else
				push(map(v))
			end
		end, ...)
		return t
	end
	ret.MapInto = MapInto

	local function CompactlyMapInto(map, t, ...)
		Apply( Lambda.Compose(Lambda.StackPusher(t), map), ...)
		return t
	end
	ret.CompactlyMapInto = CompactlyMapInto


	for _, output_mode in ipairs {'', 'Compactly'} do
		local regular_mapper_id = output_mode .. 'Map'
		local into_mapper_id = regular_mapper_id .. 'Into'

		local into_mapper = ret[into_mapper_id]
		assert( Lambda.IsFunctional(into_mapper) )

		local function regular_mapper(map, ...)
			return into_mapper(map, {}, ...)
		end
		ret[regular_mapper_id] = regular_mapper


		for _, output_pointer in ipairs {'Into', ''} do
			local mapper_id = regular_mapper_id .. output_pointer
			local conditional_mapper_id = mapper_id .. 'If'
			
			local mapper = ret[mapper_id]
			assert( Lambda.IsFunctional(mapper) )

			local function conditional_mapper(p, map, ...)
				return mapper(function(v, k)
					if p(v, k) then
						return map(v, k)
					end
				end, ...)
			end
			ret[conditional_mapper_id] = conditional_mapper

			local filter_id = output_mode .. 'Filter' .. output_pointer

			local function filter(p, ...)
				return conditional_mapper(p, Lambda.Identity, ...)
			end
			ret[filter_id] = filter
		end


		local into_filter_id = output_mode .. 'FilterInto'

		local into_filter = ret[into_filter_id]
		assert( Lambda.IsFunctional(into_filter) )

		ret[output_mode .. 'InjectIntoIf'] = into_filter
		ret[output_mode .. 'InjectInto'] = Lambda.BindHead( into_filter, Lambda.True )
	end
	local Map = ret.Map
	local CompactlyMap = ret.CompactlyMap

	
	local function Fold(folder, ...)
		local total = nil
		Apply(function(v)
			total = folder(v, total)
		end, ...)
		return total
	end
	local function FoldIf(p, folder, ...)
		local total = nil
		Apply(function(v)
			if p(v, total) then
				total = folder(v, total)
			end
		end, ...)
		return total
	end
	ret.Fold = Fold
	ret.FoldIf = FoldIf

	local function GenericMinimizeIf(cmp, p, f, ...)
		local min, minval
		Apply(function(v)
			if p(v) then
				local fv = f(v)
				if minval == nil or (fv ~= nil and cmp(fv, minval)) then
					min = v
					minval = fv
				end
			end
		end, ...)
		return min, minval
	end
	ret.GenericMinimizeIf = GenericMinimizeIf
	local GenericMinimize = Lambda.BindSecond(GenericMinimizeIf, True)
	ret.GenericMinimize = GenericMinimize
	local GenericMinimumIf = Compose(Lambda.FlipFirstTwo, GenericMinimizeIf)
	ret.GenericMinimumIf = GenericMinimumIf
	local GenericMinimum = Lambda.BindSecond(GenericMinimumIf, True)
	ret.GenericMinimum = GenericMinimum

	local function specialize_comparison(affix, cmp)
		local izeIf = Lambda.BindFirst(GenericMinimizeIf, cmp)
		ret[affix.."izeIf"] = izeIf
		ret[affix.."ize"] = Lambda.BindFirst(izeIf, True)

		local umIf = Lambda.BindFirst(GenericMinimumIf, cmp)
		ret[affix.."umOfIf"] = umIf
		ret[affix.."umOf"] = Lambda.BindFirst(umIf, True)
	end

	specialize_comparison("Minim", Lambda.Less)
	specialize_comparison("Maxim", Lambda.Greater)

	return ret
end


GenerateConceptsFromIteration(Identity, Lambda)


function ConceptualizeSingletonObject(object, ret)
	ret = ret or {}

	local meta = getmetatable(ret)
	if not meta then
		meta = {}
		setmetatable(ret, meta)
	end
	
	local oldindex = meta.__index

	-- Bad name, I know. This refers to the new __index metamethod.
	local newindex = function(t, k)
		if type(k) == "string" then
			local v = object[k]
			if Lambda.IsFunctional(v) then
				-- local w = v

				v = function(...)
					return object[k](object, ...)
				end

				t[k] = v

				--[[

				-- This is just to ensure smooth behaviour with the module loading functions
				-- that deal with environments. It isn't really needed. But it doesn't hurt,
				-- since for each key `k' we run this at most once (unless the entry is erased).

				while type(w) ~= "function" do
					w = getmetatable(w).__call
					assert( Lambda.IsFunctional(w) )
				end

				setfenv(v, getfenv(w))

				]]--
			end
			return v
		end
	end
	
	if oldindex then
		if type(oldindex) ~= "function" then
			local old_oldindex = oldindex
			oldindex = function(_, k)
					return old_oldindex[k]
			end
		end
		meta.__index = function(t, k)
			local v = newindex(t, k)
			if v ~= nil then
				return v
			else
				return oldindex(t, k)
			end
		end
	else
		meta.__index = newindex
	end

	return ret
end
