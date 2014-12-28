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


return function()
	local assert, error = assert( _G.assert ), assert( _G.error )
	local type = assert( _G.type )
	local rawget = assert( _G.rawget )
	local rawset = assert( _G.rawset )
	local getmetatable = assert( _G.getmetatable )
	local setmetatable = assert( _G.setmetatable )
	local table = assert( _G.table )

	function memoize_0ary(f, dont_retry)
		local cached
		if not dont_retry then
			return function()
				if cached == nil then
					cached = f()
					if cached ~= nil then
						f = nil
					end
				end
				return cached
			end
		else
			local tried = false
			return function()
				if not tried then
					cached = f()
					f = nil
					tried = true
				end
				return cached
			end
		end
	end
	local memoize_0ary = memoize_0ary
	memoise_0ary = memoize_0ary

	local function lambdaif(p)
		return function(a, b)
			if p() then
				return a
			else
				return b
			end
		end
	end
	local function immutable_lambdaif(p)
		if p() then
			return function(a, b)
				return a
			end
		else
			return function(a, b)
				return b
			end
		end
	end

	local unique_string = _G.tostring({})


	---


	IsWorldgen = memoize_0ary(function()
		return rawget(_G, "SEED") ~= nil
	end)
	local IsWorldgen = IsWorldgen
	IsWorldGen = IsWorldgen
	AtWorldgen = IsWorldgen
	AtWorldGen = IsWorldgen

	IfWorldgen = immutable_lambdaif(IsWorldgen)
	IfWorldGen = IfWorldgen

	IsDST = memoize_0ary(function()
		return _G.kleifileexists("scripts/networking.lua") and true or false
	end)
	local IsDST = IsDST
	IsMultiplayer = IsDST

	IfDST = immutable_lambdaif(IsDST)
	IfMultiplayer = IfDST

	function IsSingleplayer()
		return not IsDST()
	end
	local IsSingleplayer = IsSingleplayer

	IfSingleplayer = immutable_lambdaif(IsSingleplayer)

	local function is_vacuously_host()
		return IsWorldgen() or not IsMultiplayer()
	end

	IsHost = memoize_0ary(function()
		if is_vacuously_host() then
			return true
		else
			return _G.TheNet:GetIsServer() and true or false
		end
	end)
	local IsHost = IsHost
	IsServer = IsHost

	IsMasterSimulation = memoize_0ary(function()
		if is_vacuously_host() then
			return true
		else
			return _G.TheNet:GetIsMasterSimulation() and true or false
		end
	end)
	IsMasterSim = IsMasterSimulation

	IfHost = immutable_lambdaif(IsHost)
	IfServer = IfHost

	IfMasterSimulation = immutable_lambdaif(IsMasterSimulation)
	IfMasterSim = IfMasterSimulation

	IsClient = memoize_0ary(function()
		if is_vacuously_host() then
			return false
		else
			return _G.TheNet:GetIsClient() and true or false
		end
	end)

	IfClient = immutable_lambdaif(IsClient)

	IsDedicated = (function()
		if IsWorldgen() then
			return true
		elseif IsSingleplayer() then
			return false
		else
			return _G.TheNet:IsDedicated() and true or false
		end
	end)
	local IsDedicated = IsDedicated
	IsDedicatedHost = IsDedicated
	IsDedicatedServer = IsDedicated

	IfDedicated = immutable_lambdaif(IsDedicated)

	-- Returns an __index metamethod.
	function LazyCopier(source, filter)
		if not filter then
			return function(t, k)
				local v = source[k]
				if v ~= nil then
					rawset(t, k, v)
				end
				return v
			end
		elseif type(filter) == "table" then
			return function(t, k)
				if filter[k] then
					local v = source[k]
					if v ~= nil then
						rawset(t, k, v)
					end
					return v
				end
			end
		elseif type(filter) == "function" then
			return function(t, k)
				if filter(k) then
					local v = source[k]
					if v ~= nil then
						rawset(t, k, v)
					end
					return v
				end
			end
		else
			return error("Invalid filter given to LazyCopier.", 2)
		end
	end

	local function require_metatable(object)
		local meta = getmetatable( object )
		if meta == nil then
			meta = {}
			setmetatable( object, meta )
		end
		return meta
	end

	local function NewMetamethodChainer(name, tablehandler)
		assert(type(name) == "string")
		assert(tablehandler == nil or type(tablehandler) == "function")

		local metakey = "__"..name
		local metachainkey = {}

		local function accessor(t, ...)
			local chain = rawget(getmetatable(t), metachainkey)
			if not chain then return end

			for i = #chain, 1, -1 do
				local metamethod = chain[i]
				local v
				if type(metamethod) == "function" then
					v = metamethod(t, ...)
				elseif tablehandler ~= nil then
					v = tablehandler(metamethod, ...)
				end
				if v ~= nil then
					return v
				end
			end
		end

		-- If last, it is put in front, because we are using a stack.
		local function include(chain, newv, last)
			if last then
				table.insert(chain, 1, newv)
			else
				table.insert(chain, newv)
			end
			return chain
		end

		local function attach(t, fn, last)
			local meta = require_metatable(t)

			local chain = rawget(meta, metachainkey)
			if chain then
				include(chain, fn, last)
			else
				local oldfn = rawget(meta, metakey)
				if oldfn then
					rawset(meta, metachainkey, include({oldfn, nil}, fn, last))
					rawset(meta, metakey, accessor)
				else
					rawset(meta, metakey, fn)
				end
			end

			return t
		end

		local function count(t)
			local meta = getmetatable(t)
			if meta == nil then return 0 end

			local chain = rawget(meta, metachainkey)
			if chain then
				return #chain
			else
				if rawget(meta, metakey) then
					return 1
				else
					return 0
				end
			end
		end

		return attach, count
	end

	local function table_get(t, k)
		return t[k]
	end

	local function table_set(t, k, v)
		t[k] = v
	end

	AttachMetaIndexTo, CountMetaIndexes = NewMetamethodChainer("index", table_get)
	local AttachMetaIndexTo, CountMetaIndexes = AttachMetaIndexTo, CountMetaIndexes

	function AttachMetaIndex(fn, t, last)
		return AttachMetaIndexTo(t, fn, last)
	end

	AttachMetaNewIndexTo, CountMetaNewIndexes = NewMetamethodChainer("newindex", table_set)
	local AttachMetaNewIndexTo, CountMetaNewIndexes = AttachMetaNewIndexTo, CountMetaNewIndexes

	function AttachMetaNewIndex(fn, t, last)
		return AttachMetaNewIndexTo(t, fn, last)
	end

	local props_getters_metakey = {}
	local props_setters_metakey = {}

	local function property_index(object, k)
		local props = rawget(getmetatable(object), props_getters_metakey)
		if props == nil then return end

		local fn = props[k]
		if fn ~= nil then
			return fn(object, k, props)
		end
	end

	local function property_newindex(object, k, v)
		local props = rawget(getmetatable(object), props_setters_metakey)
		if props == nil then return end

		local fn = props[k]
		if fn ~= nil then
			fn(object, k, v, props)
			return true
		end
	end

	function AddPropertyTo(object, k, getter, setter)
		local meta = require_metatable(object)
		if getter ~= nil then
			local getters = rawget(meta, props_getters_metakey)
			if not getters then
				getters = {}
				rawset(meta, props_getters_metakey, getters)
				AttachMetaIndexTo(object, property_index)
			end
			getters[k] = getter
		end
		if setter ~= nil then
			local setters = rawget(meta, props_setters_metakey)
			if not setters then
				setters = {}
				rawset(meta, props_setters_metakey, setters)
				if CountMetaNewIndexes(object) == 0 then
					AttachMetaNewIndexTo(object, rawset, true)
				end
				AttachMetaNewIndexTo(object, property_newindex)
			end
			setters[k] = setter
		end
	end
	local AddPropertyTo = AddPropertyTo

	function AddLazyVariableTo(object, k, fn)
		local function getter(object, k, props)
			local v = fn(k, object)
			if v ~= nil then
				props[k] = nil
				rawset(object, k, v)
			end
			return v
		end

		return AddPropertyTo(object, k, getter)
	end
	local AddLazyVariableTo = AddLazyVariableTo


	function InjectNonPrivatesIntoTableIf(p, t, f, s, var)
		for k, v in f, s, var do
			if type(k) == "string" and not k:match('^_') then
				if p(k, v) then
					t[k] = v
				end
			end
		end
		return t
	end
	
	function InjectNonPrivatesIntoTable(t, f, s, var)
		t = InjectNonPrivatesIntoTableIf(function() return true end, t, f, s, var)
		return t
	end
end
