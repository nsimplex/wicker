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


local Lambda = wickerrequire "paradigms.functional"

local Time = wickerrequire "utils.time"


local tostring = tostring


_M.directorySeparator = DIR_SEP


local get_pretty_time = Time.TimeFormatter "[%X]"

NewSayer = (function()
	local function put(chunks, v)
		local n = chunks.n + 1
		chunks[n] = v
		chunks.n = n
	end

	local function put_mod_name(chunks)
		put( chunks, "(" )
		put( chunks, modinfo.name )
		put( chunks, ")" )
	end

	local function put_time(chunks)
		put(chunks, get_pretty_time())
	end

	---

	return function(prefix)
		local static_chunks = {
			n = 0,

			nil, -- os.date("[%X]"),
			nil, --" (",
			nil, --tostring( TheMod.Modname ),
			nil, --") ",
			nil, -- actual_prefix
			nil,
			nil,
			nil,
		}

		local chunks_in_use = false

		local function put_prefix(chunks)
			if prefix then
				put( chunks, tostring(prefix) )
				put( chunks, ": " )
			end
		end

		---

		return function(...)
			local chunks
			if chunks_in_use then
				chunks = {}
			else
				chunks = static_chunks
				chunks_in_use = true
			end
			chunks.n = 0

			local actual_prefix
			if prefix then
				actual_prefix = tostring(prefix) .. ": "
			else
				actual_prefix = ""
			end

			local args = {...}
			local nargs = select("#", ...)

			put_time( chunks )
			put( chunks, " " )
			put_mod_name( chunks )
			put( chunks, " " )
			put_prefix( chunks )

			for i = 1, nargs do
				put(chunks, tostring(args[i]))
			end

			if chunks == static_chunks then
				for i = chunks.n + 1, #chunks do
					chunks[i] = nil
				end
				chunks_in_use = false
			end

			chunks.n = nil

			return nolineprint(table.concat(chunks))
		end
	end
end)()

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
		local env, i = GetEnvironmentLayer(layer_index, true)
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
