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


return function(boot_params, wicker_stem)
	local assert = assert
	local modcode_root = assert( boot_params.modcode_root )
	local mod_id = assert( boot_params.id )


	function AssertEnvironmentValidity(env)
		assert( env.GetModKey == nil or env.GetModKey() == GetModKey(), env._NAME )
		assert( env.TheMod == nil or _M.TheMod == nil or env.TheMod == _M.TheMod, env._NAME )
		assert( modenv == nil or env.modname == nil or env.modname == modenv.modname, env._NAME )
	end


	-- Returns a unique key.
	GetModKey = (function()
		local k = {}
		return function()
			return k
		end
	end)()

	function GetWickerStem()
		return wicker_stem
	end

	function GetModDirectoryName()
		return modenv.modname
	end

	function GetModcodeRoot()
		return modcode_root
	end

	function GetModId()
		return mod_id
	end
end
