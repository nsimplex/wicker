-----
--[[ Wicker ]] VERSION="3.0"
--
-- Last updated: 2013-11-29
-----

--[[
-- Called by init.lua after bootstrapping.
--]]

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

local submodules = {
	"dst_abstraction",
}

---

local function traceback(start_level)
	local getinfo = debug.getinfo

	local pieces = {"stack traceback:"}

	for lvl = (start_level or 1) + 1, math.huge do
		local info = getinfo(lvl, "nSl")
		if info == nil then break end

		local is_C = (info.what == "C")
		local is_tailcall = (info.source == "=(tail call)")

		local src

		local primary_location
		if is_C then
			primary_location = "[C]"
		elseif is_tailcall then
			primary_location = "(tail call)"
		else
			src = info.source
			if src then
				src = src:gsub("^@", "")
			else
				src = "???"
			end
			primary_location = src..":"..(info.currentline or "???")
		end

		local secondary_location
		if is_C or is_tailcall then
			secondary_location = "?"
		elseif info.what == "main" then
			secondary_location = "in main chunk"
		else
			local name = info.name
			if name then
				name = "'"..name.."'"
			else
				name = "<"..(src or "???")..">"
			end
			local modifier = info.namewhat
			if modifier then
				modifier = modifier.." "
			else
				modifier = ""
			end
			secondary_location = "in "..modifier.."function "..name
		end

		local subpieces = {
			"\t",
			primary_location,
			": ",
			secondary_location,
		}

		table.insert(pieces, table.concat(subpieces))
	end

	return table.concat(pieces, "\n")
end

---

local function doextend(kernel)
	kernel.traceback = traceback

	for _, subm in ipairs(submodules) do
		local extender = pkgrequire("kernel_extensions."..subm)
		setfenv(extender, kernel)
		extender(kernel)
	end
end

---

return function(kernel)
	doextend(kernel)
	doextend = function() end
end
