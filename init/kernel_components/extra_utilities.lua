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
	local GetEnvironmentLayer = assert( GetEnvironmentLayer )
	local tostring = assert( _G.tostring )

	--[[
	-- Propagates the error point to the outer environment.
	--]]
	function OuterError(str, ...)
		local out_env, out_ind = GetEnvironmentLayer(1, true)

		return error(
			(str and tostring(str) or "ERROR"):format(...),
			out_ind
		)
	end
	local OuterError = OuterError

	--[[
	-- Propagates the assertion point to the outer environment.
	--]]
	function OuterAssert(cond, str, ...)
		if not cond then
			return OuterError(str or "assertion failed!", ...)
		end
	end
end
