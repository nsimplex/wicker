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

local write_proxy_prefab_file = (function()
	local prefix = MODROOT.."scripts/prefabs/"
	local importer = ("require(%q)"):format( GetModId()..".modrequire" )

	return function(file_name)
		local full_name = prefix..file_name

		if _G.kleifileexists(full_name) then return end

		local fh = assert( io.open(full_name, "w") )

		fh:write( "local ret = ", importer, "(", ("%q"):format("prefabs."..file_name), ")", "\n" )
		fh:write( "return getmetatable(ret) == Prefab and ret or unpack(ret)", "\n" )

		fh:close()
	end
end)()

return function(PrefabFiles)
	for _, prefab_file in ipairs(PrefabFiles) do
		write_proxy_prefab_file(prefab_file)
	end
end
