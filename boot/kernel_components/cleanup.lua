--[[
-- Avoid tail calls like hell.
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


return function()
	local table = _G.table
	local ipairs = _G.ipairs
	local unpack = _G.unpack

	local cleanup_fns = {}
	local final_cleanup_fns = {}


	local function AddCleanup(fn)
		table.insert(cleanup_fns, fn)
	end

	AddFinalCleanup = function(fn)
		table.insert(final_cleanup_fns, 1, fn)
	end

	local function NewVariableCleanupAdder(basic_adder)
		return function(...)
			local names = {...}
			basic_adder(function(env)
				for _, name in ipairs(names) do
					env[name] = nil
				end
			end)
		end
	end

	local AddVariableCleanup = NewVariableCleanupAdder(AddCleanup)
	local AddFinalVariableCleanup = NewVariableCleanupAdder(AddFinalCleanup)

	local function PerformCleanup()
		for _, fn in ipairs(cleanup_fns) do
			fn(_M)
		end
		for _, fn in ipairs(final_cleanup_fns) do
			fn(_M)
		end
		cleanup_fns = {}
		final_cleanup_fns = {}
	end

	
	_M.AddCleanup = AddCleanup
	_M.AddFinalCleanup = AddFinalCleanup
	_M.AddVariableCleanup = AddVariableCleanup
	_M.AddFinalVariableCleanup = AddFinalVariableCleanup
	_M.PerformCleanup = PerformCleanup

	AddFinalVariableCleanup(
		"AddCleanup",
		"AddFinalCleanup",
		"AddVariableCleanup",
		"AddFinalVariableCleanup",
		"PerformCleanup"
	)
end
