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


--@@WICKER ENVIRONMENT BOOTUP
local _modname = assert( (assert(..., 'This file should be loaded through require.')):match('^[%a_][%w_%s]*') , 'Invalid path.' )
module( ..., require(_modname .. '.wicker.booter') )
--@@END ENVIRONMENT BOOTUP


local Lambda = wickerrequire 'paradigms.functional'

local Pred = wickerrequire 'lib.predicates'


local FunctionQueue = Class(function(self) end)

Pred.IsFunctionQueue = Pred.IsInstanceOf(FunctionQueue)


function FunctionQueue:__call(...)
	for _, f in ipairs(self) do
		f(...)
	end
end

function FunctionQueue:ToFunction()
	return function(...)
		return self(...)
	end
end


-- Appends an array of functions (possibly another FunctionQueue).
function FunctionQueue:AppendArray(A)
	local n = #self
	for i, f in ipairs(A) do
		self[n + i] = f
	end
	return self
end

function FunctionQueue:PrependArray(A)
	local n = #self
	local m = #A

	if m > 0 then
		for i = n, 1, -1 do
			self[i + m] = self[i]
		end
		for i = 1, m do
			self[i] = A[i]
		end
	end

	assert( #self == n + m )
	return self
end

-- For a single inclusion, table.insert is more efficient.
function FunctionQueue:Append(...)
	return self:AppendArray {...}
end

-- The same goes here.
function FunctionQueue:Prepend(...)
	return self:PrependArray {...}
end


function FunctionQueue:Copy()
	return FunctionQueue():AppendArray(self)
end


function FunctionQueue.__add(A, B)
	if not Pred.IsFunctionQueue(A) then
		A, B = B, A
	end
	assert( Pred.IsFunctionQueue(A) )
	assert( Pred.IsTable(B) )
	return A:Copy():AppendArray(B)
end

FunctionQueue.__concat = FunctionQueue.__add


return FunctionQueue
