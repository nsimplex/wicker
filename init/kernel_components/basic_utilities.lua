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
				else
					f = nil
				end
				return cached
			end
		else
			local tried = false
			return function()
				if not tried then
					cached = f()
				else
					f = nil
				end
				return cached
			end
		end
	end
	local memoize_0ary = memoize_0ary
	memoise_0ary = memoize_0ary

	IsWorldgen = memoize_0ary(function()
		return rawget(_G, "SEED") ~= nil
	end)
	local IsWorldgen = IsWorldgen
	IsWorldGen = IsWorldgen
	AtWorldgen = IsWorldgen
	AtWorldGen = IsWorldgen

	IsDST = memoize_0ary(function()
		return _G.kleifileexists("networking.lua") and true or false
	end)
	local IsDST = IsDST
	IsMultiplayer = IsDST

	function IsSingleplayer()
		return not IsDST()
	end
	local IsSingleplayer = IsSingleplayer

	IsHost = memoize_0ary(function()
		if IsWorldgen() or not IsMultiplayer() then
			return true
		else
			return _G.TheNet:GetIsMasterSimulation()
		end
	end)
	local IsHost = IsHost
	IsMasterSimulation = IsHost

	local _inner_IsDedicated
	_inner_IsDedicated = memoize_0ary(function()
		if not IsHost() or IsSingleplayer() then
			return false
		elseif IsWorldgen() then
			return true
		else
			_inner_IsDedicated = function()
				return _G.TheNet:IsDedicated()
			end
			return _inner_IsDedicated()
		end
	end)
	function IsDedicated()
		return _inner_IsDedicated()
	end
	local IsDedicated = IsDedicated

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


	function NormalizeMetaIndex(index_method)
		if type(index_method) == "table" then
				return function(_, k)
						return index_method[k]
				end
		else
				assert( type(index_method) == "function", "An index metamethod should either a table or a function." )
				return index_method
		end
	end
	local NormalizeMetaIndex = NormalizeMetaIndex

	local function require_metatable(object)
		local meta = getmetatable( object )
		if not meta then
			meta = {}
			setmetatable( object, meta )
		end
		return meta
	end

	local function metaindexes_accessor(t, k)
		local indexes = rawget(getmetatable(t), "__indexes")
		if not indexes then return end

		for i = #indexes, 1, -1 do
			local ind = indexes[i]
			local v
			if type(ind) == "function" then
				v = ind(t, k)
			else
				v = ind[k]
			end
			if v ~= nil then
				return v
			end
		end
	end

	function AttachMetaIndex(fn, object)
		local meta = require_metatable(object)

		local indexes = rawget(meta, "__indexes")
		if indexes then
			table.insert(indexes, fn)
		else
			local oldfn = meta.__index
			if oldfn then
				rawset(meta, "__indexes", {oldfn, fn})
				rawset(meta, "__index", metaindexes_accessor)
			else
				rawset(meta, "__index", fn)
			end
		end

		return object
	end
	local AttachMetaIndex = AttachMetaIndex

	
	local function lazy_var_index(object, k)
		local meta = getmetatable(object)
		local lazyhooks = meta and rawget(meta, "__lazy")
		local fn = lazyhooks and lazyhooks[k]
		if fn then
			local v = fn(k, object)
			if v ~= nil then
				lazyhooks[k] = nil
				object[k] = v
				return v
			end
			return object[k]
		end
	end

	function AddLazyVariableTo(object, k, fn)
		local meta = require_metatable(object)
		local lazyhooks = rawget(meta, "__lazy")
		if not lazyhooks then
			lazyhooks = {}
			rawset(meta, "__lazy", lazyhooks)
			AttachMetaIndex(lazy_var_index, object)
		end
		lazyhooks[k] = fn
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
