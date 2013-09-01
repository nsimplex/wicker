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

local DIR_SEP = package.config and package.config:sub(1,1) or '/'

--@@ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )

--@@END ENVIRONMENT BOOTUP

local Lambda = wickerrequire 'paradigms.functional'


_M.directorySeparator = DIR_SEP

function NewSayer(prefix)
	return function(...)
		local version = TheMod.modinfo.version
		if version then
			version = tostring(version)
			if #version > 0 then
				if version:match("^%d") then
					version = " v" .. version
				else
					version = " " .. version
				end
			end
		else
			version = ""
		end

		local actual_prefix
		if prefix then
			actual_prefix = tostring(prefix) .. ": "
		else
			actual_prefix = ""
		end

		nolineprint(table.concat(Lambda.CompactlyMapInto(
			tostring,
			{
				os.date("[%X]"),
				" (",
				tostring( TheMod.Modname ),
				" mod",
				version,
				") ",
				actual_prefix
			},
			ipairs {...}
		)))
	end
end

-- Trims the 'source' entry from the table returned by debug.getinfo()
function TrimSource(name)
	return name:gsub(
		"^@", ""
	):gsub(
		"^.-" .. directorySeparator .. "data" .. directorySeparator, ""
	):gsub(
		"^.-" .. directorySeparator .. "mods" .. directorySeparator, ""
	):gsub(
		"^.-" .. directorySeparator .. "scripts" .. directorySeparator, ""
	)
end

function NewNotifier(prefix, layer_offset)
	prefix = prefix or ""
	local layer_index = 1 + (layer_offset or 0)

	local Say = NewSayer(prefix)

	local function DoNotify(...)
		local env, i = GetEnvironmentLayer(layer_index)
		assert( i )

		local info = debug.getinfo(i, 'Sl')
		local filename = TrimSource(tostring(info.source))

		Say('@', filename, ':', info.currentline, ': ', ...)
	end

	return DoNotify, Say
end


if io then
	BindTable(io)
end

return _M
