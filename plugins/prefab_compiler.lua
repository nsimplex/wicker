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

-- What gets printed at the end of the prefab files.
local prefab_file_tail = [[
if getmetatable(ret) == Prefab then
	return ret
else
	return unpack(ret)
end
]]

-- Prefix of prefab file names.
local prefab_filename_prefix = MODROOT..table.concat({"scripts", "prefabs", ""}, package.config:sub(1, 1))

local function write_proxy_prefab_file(file_name)
	local full_name = prefab_filename_prefix..file_name..".lua"

	if _G.kleifileexists(full_name) then return end

	local importer = ("require(%q)"):format( GetModId()..".modrequire" )


	local fh = assert( io.open(full_name, "w") )

	fh:write( "local ret = ", importer, "(", ("%q"):format("prefabs."..file_name), ")", "\n" )
	fh:write( prefab_file_tail )

	fh:close()
end

local function do_compile(PrefabFiles)
	for _, prefab_file in ipairs(PrefabFiles) do
		write_proxy_prefab_file(prefab_file)
	end
end

TheMod:AddPostRun(function()
	if modenv.PrefabFiles then
		do_compile(modenv.PrefabFiles)
	end
end)
