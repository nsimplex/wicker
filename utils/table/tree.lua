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


local Lambda = wickerrequire 'paradigms.functional'
local Logic = wickerrequire 'lib.logic'


InjectPackage 'tree.core'

dfs = pkgrequire 'tree.dfs'
Dfs = dfs

return setmetatable(_M, {__call = function(self, t, k, v) return New(t, k, v) end})
