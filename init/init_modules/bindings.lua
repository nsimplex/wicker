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


return function(primary_booter)
	local assert = assert


	local modrequire = assert( modrequire )
	local wickerrequire = assert( wickerrequire )
	local BindTable = assert( BindTable )


	local mod_id = assert( GetModId() )


	_G.package.loaded[mod_id..".modrequire"] = modrequire
	_G.package.loaded[mod_id..".wickerrequire"] = wickerrequire


	local SetWickerBooter, SetModBooter
	do
		local WickerBooter
		function GetWickerBooter()
			return WickerBooter
		end

		local ModBooter
		function GetModBooter()
			return ModBooter
		end

		SetWickerBooter = function(booter)
			WickerBooter = booter
		end

		SetModBooter = function(booter)
			ModBooter = booter
		end
	end


	function RegisterModEnvironment(E)
		SetModBooter(function(env)
			return BindTable(env, E)
		end)
	end

	
	SetWickerBooter(primary_booter)
	SetModBooter(primary_booter)

	AddVariableCleanup("GetWickerBooter", "GetModBooter")
end
