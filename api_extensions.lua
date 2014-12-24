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

--[[
local submodules = {
}
]]--

local function MakeLateAddPrefabPostInit()
	local FunctionQueue = wickerrequire "gadgets.functionqueue"

	local queue_set = {}

	_G.SpawnPrefab = (function()
		local SpawnPrefab = assert( _G.SpawnPrefab )

		return function(prefab)
			local inst = SpawnPrefab(prefab)
			
			local queue = queue_set[prefab]
			if queue ~= nil then
				queue(inst)
			end

			return inst
		end
	end)()

	return function(prefab, postinitfn)
		local queue = queue_set[prefab]
		
		if queue == nil then
			queue = FunctionQueue()
			queue_set[prefab] = queue
		end

		table.insert(queue, postinitfn)
	end
end

local function doextend()
	local basic_AddPrefabPostInit = assert( modenv.AddPrefabPostInit )
	local late_AddPrefabPostInit = nil

	local function AddPrefabPostInit(prefab, fn)
		if TheMod:IsRunning() then
			return basic_AddPrefabPostInit(prefab, fn)
		else
			if late_AddPrefabPostInit == nil then
				late_AddPrefabPostInit = assert( MakeLateAddPrefabPostInit() )
			end
			return late_AddPrefabPostInit(prefab, fn)
		end
	end

	TheMod:EmbedHook("PrefabPostInit", AddPrefabPostInit)
end

return function()
	doextend()
	doextend = function() end
end
