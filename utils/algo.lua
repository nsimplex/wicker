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

--@@ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.booter') )

--@@END ENVIRONMENT BOOTUP


function LeastElementsOf(A, k, cmp)
	assert(k > 0)

	cmp = cmp or Pred.Less

	local n = #A
	local L = {}

	for i=1, math.min(k, n) do
		L[i] = A[i]
	end

	table.sort(L, cmp)

	for i=k+1, n do
		if cmp(A[i], L[k]) then
			table.remove(L)

			local pred_idx = k-1
			while pred_idx > 0 do
				if not cmp(A[i], L[pred_idx]) then break end
				pred_idx = pred_idx - 1
			end
			
			-- The case pred_idx == 0 isn't exceptional.
			table.insert(L, pred_idx + 1, A[i])
		end
	end

	return L
end

return _M
