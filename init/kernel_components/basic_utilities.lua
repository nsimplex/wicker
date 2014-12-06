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

	local function memoize_0ary(f)
		local cached
		return function()
			if cached == nil then
				cached = f()
			end
			return cached
		end
	end

	IsWorldgen = memoize_0ary(function()
		return rawget(_G, "SEED") ~= nil
	end)
	IsWorldGen = IsWorldgen
	AtWorldgen = IsWorldgen
	AtWorldGen = IsWorldgen

	IsDST = memoize_0ary(function()
		return _G.kleifileexists("networking.lua") and true or false
	end)
	IsMultiplayer = IsDST

	function IsSingleplayer()
		return not IsMultiplayer()
	end

	IsMasterSimulation = memoize_0ary(function()
		if IsWorldgen() or not IsMultiplayer() then
			return true
		else
			return _G.TheNet:GetIsMasterSimulation()
		end
	end)
	IsMaster = IsMasterSimulation

	function AddNetwork(inst)
		if IsDST() then
			return inst.entity:AddNetwork()
		end
	end

	function SetPristine(inst)
		if IsDST() then
			inst.entity:SetPristine()
		end
		return inst
	end
	MakePristine = SetPristine
	
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

	function AttachMetaIndex(fn, object)
		local meta = require_metatable(object)

		local oldfn = meta.__index

		if oldfn then
			fn, oldfn = NormalizeMetaIndex(fn), NormalizeMetaIndex(oldfn)
			meta.__index = function(object, k)
				local v = fn(object, k)
				if v ~= nil then
					return v
				else
					return oldfn(object, k)
				end
			end
		else
			meta.__index = fn
		end

		return object
	end
	local AttachMetaIndex = AttachMetaIndex

	
	local function lazy_var_index(object, k)
		local meta = getmetatable(object)
		local lazyhooks = meta and rawget(meta, "__lazy")
		local fn = lazyhooks and lazyhooks[k]
		if fn then
			lazyhooks[k] = nil
			local v = fn(k, object)
			if v ~= nil then
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
