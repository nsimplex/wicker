-----
--[[ Wicker ]] VERSION="3.0"
--
-- Last updated: 2013-11-29
-----

--[[
-- Called by boot.lua after bootstrapping.
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

local function doextend()
	local FunctionQueue = wickerrequire "gadgets.functionqueue"

	local my_postinits = {}

	TheMod:AddPrefabPostInitAny(function(inst)
		local prefab = inst.prefab
		if prefab then
			local postinits = my_postinits[prefab]
			if postinits then
				postinits(inst)
			end
		end
	end)
	local basic_AddPrefabPostInit = assert( modenv.AddPrefabPostInit )
	local late_AddPrefabPostInit = nil

	local function AddPrefabPostInit(prefab, fn)
		local postinits = my_postinits[prefab]
		if not postinits then
			postinits = FunctionQueue()
		end
		table.insert(postinits, fn)
		return fn
	end

	TheMod:EmbedHook("GenericPrefabPostInit", AddPrefabPostInit)
	TheMod:EmbedHook("PrefabPostInit", AddPrefabPostInit)
end

return function()
	if not IsWorldgen() then
		doextend()
		doextend = function() end
	end
end
