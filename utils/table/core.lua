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

local Iterator = Lambda.iterator


ArraySlice = Iterator.ArraySlice

do
	local ipairs = ipairs
	function _M.ipairs(A, i, j)
		if i or j then
			return Iterator.ArraySlice(A, i, j)
		else
			-- We could always use ArraySlice.
			-- This is just for efficiency, since ipairs is implemented in C.
			return ipairs(A)
		end
	end
end


local syntax_refactoring_specs = {
	[""] = {pairs = pairs},
	["i"] = {pairs = _M.ipairs},
}

for prefix, spec in pairs(syntax_refactoring_specs) do
	spec.keys = Lambda.Compose( Iterator.RawComposeTo(Lambda.FirstOf), spec.pairs )
	
	spec.values = Lambda.Compose( Iterator.ComposeTo(Lambda.SecondOf), spec.pairs )
	
	spec.flippairs = Lambda.Compose( Iterator.ComposeTo(Lambda.FlipFirstTwo), spec.pairs )
	spec.flipairs = spec.flippairs

	for name, fn in pairs(spec) do
		_M[prefix .. name] = fn
	end
end

flipipairs = assert( iflippairs )

syntax_refactoring_specs = nil


function FilterTable(t, p)
	return Lambda.Filter(p, pairs(t))
end

function FilterTableInPlace(t, p)
	return MapIntoIf(Lambda.Not(p), Lambda.Nil, t, pairs(t))
end

TrimTable = FilterTableInPlace

function FilterArray(A, p)
	return Lambda.CompactlyFilter(p, ipairs(A))
end

function FilterArrayInPlace(A, p)
	local offset = 0
	local n = #A

	for i = 1, n do
		if not p(A[i], i) then
			offset = offset + 1
		elseif offset > 0 then
			A[i - offset] = A[i]
		end
	end
	for i = n - offset + 1, n do
		A[i] = nil
	end

	assert(#A == n - offset)

	return A
end

TrimArray = FilterArrayInPlace


function append(A, B)
	local n = #A
	for i, v in ipairs(B) do
		A[n + i] = v
	end
	return A
end

function prepend(A, B)
	local n, m = #A, #B
	if m == 0 then return end

	for i = n, 1, -1 do
		A[i + m] = A[i]
	end
	for i = 1, m do
		A[i] = B[i]
	end

	assert( #A == n + m )
	return A
end

return _M
