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


return function()
	local table = assert( _G.table )

	do
		local mod_postinits = {}

		function RunModPostInits()
			if not TheMod then return end

			TheMod:DebugSay("Running mod post inits...")

			for _, f in ipairs(mod_postinits) do
				f(TheMod)
			end

			mod_postinits = {}
		end
		local RunModPostInits = RunModPostInits

		-- Runs after TheMod has been instantiated.
		function AddModPostInit(f)
			table.insert(mod_postinits, f)
			if TheMod then
				RunModPostInits()
			end
		end
	end
end
