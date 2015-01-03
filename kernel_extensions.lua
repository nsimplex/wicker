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
	"uuids",
	"class",
	"dst_abstraction",
}

---

local function traceback(message, start_level)
	local getinfo = debug.getinfo

	if type(message) == "number" then
		start_level, message = message, nil
	end

	local pieces = {}
	if message ~= nil then
		table.insert(pieces, tostring(message))
	end
	table.insert(pieces, "stack traceback:")

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
			if modifier and #modifier > 0 then
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

local function dobasicextend(kernel)
	local Lambda = wickerrequire "paradigms.functional"

	kernel.Lambda = Lambda
	kernel.Nil = Lambda.Nil

	kernel.traceback = traceback

	kernel.ptraceback = function(message, lvl)
		TheMod:Say(traceback(message, (lvl or 1) + 1))
	end

	if VarExists("IsDLCEnabled") then
		kernel.IsDLCEnabled = _G.IsDLCEnabled
	else
		kernel.IsDLCEnabled = Lambda.False
	end
	if VarExists("IsDLCInstalled") then
		kernel.IsDLCInstalled = _G.IsDLCInstalled
	else
		kernel.IsDLCInstalled = kernel.IsDLCEnabled
	end
	if VarExists("REIGN_OF_GIANTS") then
		kernel.REIGN_OF_GIANTS = _G.REIGN_OF_GIANTS
	else
		kernel.REIGN_OF_GIANTS = 1
	end

	if VarExists("DONT_STARVE_APPID") then
		kernel.DONT_STARVE_APPID = _G.DONT_STARVE_APPID
	else
		kernel.DONT_STARVE_APPID = 219740
	end

	if VarExists("DONT_STARVE_TOGETHER_APPID") then
		kernel.DONT_STARVE_TOGETHER_APPID = _G.DONT_STARVE_TOGETHER_APPID
	else
		kernel.DONT_STARVE_TOGETHER_APPID = 322330
	end

	local GetSteamAppID
	local has_TheSim = VarExists("TheSim")
	if has_TheSim and _G.TheSim.GetSteamAppID then
		GetSteamAppID = function()
			return _G.TheSim:GetSteamAppID()
		end
	else
		GetSteamAppID = function()
			if IsDST() then
				return DONT_STARVE_TOGETHER_APPID
			else
				return DONT_STARVE_APPID
			end
		end
		if has_TheSim then
			getmetatable(_G.TheSim).__index.GetSteamAppID = GetSteamAppID
		end
	end
	kernel.GetSteamAppId = GetSteamAppID
end

local function doextend(kernel)
	local the_kernel = kernel

	local function get_the_kernel()
		return the_kernel
	end

	AddPropertyTo(kernel, "kernel", get_the_kernel)

	dobasicextend(kernel)

	for _, subm in ipairs(submodules) do
		local extender = pkgrequire("kernel_extensions."..subm)
		if type(extender) == "function" then
			extender(kernel)
		end
	end

	the_kernel = nil
end

---

return function(kernel)
	doextend(kernel)
	doextend = function() end
end
