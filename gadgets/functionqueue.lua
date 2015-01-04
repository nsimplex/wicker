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

local Pred = wickerrequire 'lib.predicates'

local assert = assert
local unpack = unpack
local pairs, ipairs = pairs, ipairs


local FunctionQueue = Class(function(self) end)

local IsFunctionQueue = Pred.IsInstanceOf(FunctionQueue)
Pred.IsFunctionQueue = IsFunctionQueue


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

--[[
function FunctionQueue.__add(A, B)
	if not IsFunctionQueue(A) then
		A, B = B, A
	end
	assert( Pred.IsFunctionQueue(A) )
	assert( Pred.IsTable(B) )
	return A:Copy():AppendArray(B)
end
]]--

function FunctionQueue:WrapFromLeft(f)
	return function(...)
		self(...)
		return f(...)
	end
end

function FunctionQueue:WrapFromRight(f)
	local unpack = unpack
	return function(...)
		local rets = {f(...)}
		self(...)
		return unpack(rets)
	end
end

function FunctionQueue.__concat(A, B)
	if IsFunctionQueue(A) then
		return A:WrapFromLeft(B)
	else
		return B:WrapFromRight(A)
	end
end


return FunctionQueue
