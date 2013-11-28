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
	-- Returns the index (relative to the calling function) in the Lua stack of the last function with a different environment than the outer function.
	-- It uses the Lua side convention for indexes, which are nonnegative and count from top to bottom.
	--
	-- It defaults to 2 because it shouldn't be used directly from outside this module.
	--
	-- We should always reach the global environment, which prevents an infinite loop.
	-- Ignoring errors is needed to pass over tail calls (which trigger them).
	--
	-- This could be written much more cleanly and robustly at the C/C++ side.
	-- The real setback is that Lua doesn't tell us what the stack size is.
	function GetNextEnvironmentThreshold(i)
		assert( i == nil or (type(i) == "number" and i > 0 and i == math.floor(i)) )
		i = (i or 1) + 1
	
		local env
	
		local function get_first()
			local status
	
			status, env = pcall(getfenv, i + 2)
			if not status then
				return error('Unable to get the initial environment!')
			end
			i = i + 1
	
			return env
		end
	
		local function get_next()
			local status
			
			while not status do
				status, env = pcall(getfenv, i + 2)
				i = i + 1
			end
	
			return env
		end
	
		local first_env = get_first()
		if first_env == _G then
			return error('The initial environment is the global environment!')
		end
	
		assert( env == first_env )
	
		while env == first_env do
			env = get_next()
		end
		i = i - 1
	
		if env == _G then
			return error('Attempt to reach the global environment!')
		elseif env == _M then
			return error('Attempt to reach the kernel environment!')
		end
	
		-- No, this is not a typo. The index should be subtracted twice.
		-- The subtractions just have different meanings.
		return i - 1, env
	end
	local GetNextEnvironmentThreshold = GetNextEnvironmentThreshold
	
	-- Counts from 0 up, with 0 meaning the innermost environment different than the caller's.
	function GetEnvironmentLayer(n)
		assert( type(n) == "number" )
		assert( n >= 0 )
	
		local i, env = GetNextEnvironmentThreshold()
		for _ = 1, n do
			i, env = GetNextEnvironmentThreshold(i)
		end
	
		return env, i - 1
	end
	local GetEnvironmentLayer = GetEnvironmentLayer
	
	function GetOuterEnvironment()
		local env, i = GetEnvironmentLayer(0)
		return env, i - 1
	end
	local GetOuterEnvironment = GetOuterEnvironment


	AddVariableCleanup("GetNextEnvironmentThreshold")
end
