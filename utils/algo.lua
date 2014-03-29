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


local Lambda = wickerrequire "paradigms.functional"
local Pred = wickerrequire "lib.predicates"


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

---
-- Returns a function performing binary search on A. The returned function
-- takes an element and returns the index of the match (or nil) as a first
-- value, the greatest lower bound in A (if any) of the argument as a
-- second value and the index to this bound as a third value.
--
-- @param A The array to be searched.
-- @param cmp (optional) The strict comparison function. Defaults to the less operator.
-- @param presorted Boolean indicating whether A is already sorted.
-- @param copy_anyway Boolean indicating whether A should be copied even if it is presorted.
--
function BinarySearcher(A, cmp, presorted, copy_anyway)
	assert( Pred.IsTable(A) )
	cmp = cmp or Pred.Less
	assert( Pred.IsCallable(cmp) )

	local B
	if not presorted or copy_anyway then
		B = Lambda.InjectInto({}, ipairs(A))
		if not presorted then
			table.sort(B, cmp)
		end
	else
		B = A
	end

	return function(x)
		if B[1] == nil or cmp(x, B[1]) then
			return nil
		end

		local imin, imax = 1, #B

		while imin < imax do
			local i = math.ceil( (imin + imax)/2 )

			if cmp(x, B[i]) then
				imax = i - 1
			else
				imin = i
			end
		end

		local i
		if imin == imax and not cmp(B[imin], x) then
			i = imin
		end

		return i, B[imin], imin
	end
end

return _M
