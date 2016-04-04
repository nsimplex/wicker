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


local FunctionQueue = wickerrequire 'gadgets.functionqueue'


local postloads = FunctionQueue()


local did_run = false
TheMod:AddGlobalClassPostConstruct("saveindex", "SaveIndex", function()
	if did_run then return end
	if _G.package.loaded.gamelogic then
		did_run = true
		postloads()
		postloads = nil
	end
end)


local function AddPostLoad(fn)
	if did_run then
		fn()
	else
		table.insert(postloads, fn)
	end
end


TheMod:EmbedHook("AddGameLogicPostLoad", AddPostLoad)
