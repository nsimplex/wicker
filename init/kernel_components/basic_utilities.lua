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


	function IsWorldgen()
		return rawget(_G, "SEED") ~= nil
	end
	IsWorldGen = IsWorldgen


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

	function AttachMetaIndex(fn, object)
		local meta = getmetatable( object )

		if not meta then
			meta = {}
			setmetatable( object, meta )
		end

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
