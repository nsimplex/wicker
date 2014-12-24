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

local function doextend(kernel)
	for _, subm in ipairs(submodules) do
		local extender = pkgrequire("kernel_extensions."..subm)
		setfenv(extender, kernel)
		extender(kernel)
	end
end

return function(kernel)
	doextend(kernel)
	doextend = function() end
end
