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

wickerrequire "plugins.addgamelogicpostload"


local FunctionQueue = wickerrequire 'gadgets.functionqueue'


local preinits = FunctionQueue()


local patched_populate = false
TheMod:AddGameLogicPostLoad(function()
	-- TODO: remove this file
	-- FIXME: remove this file
	error "This is broken in DST!"

	if patched_populate then return end
	assert( VarExists "PopulateWorld" )

	patched_populate = true

	local populate = _G.PopulateWorld
	_G.PopulateWorld = function(...)
		preinits(...)
		return populate(...)
	end
end)


local function AddPopulateWorldPreInit(fn)
	table.insert(preinits, fn)
end


TheMod:EmbedHook("AddPopulateWorldPreInit", AddPopulateWorldPreInit)
