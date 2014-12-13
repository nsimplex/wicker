--[[
-- Just a bunch of abstract nonsense.
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

local assert = assert
local error = error

local math = math

local table = table
local ipairs = ipairs
local pairs = pairs
local select = select
local unpack = unpack

local type = type
local tostring = tostring
local tonumber = tonumber

local getmetatable = getmetatable
local setmetatable = setmetatable
local getfenv = getfenv
local setfenv = setfenv


--module(...)
local Lambda = _M

function IsFunctional(x)
	return type(x) == "function" or getmetatable(x) and getmetatable(x).__call
end
local IsFunctional = IsFunctional

function Identity(...)
	return ...
end

function Constant(x)
	return function()
		return x
	end
end

function ConstantList(...)
	local L = {...}
	return function()
		return unpack(L)
	end
end

Nil = Constant()

True = Constant(true)
False = Constant(false)

Zero = Constant(0)
One = Constant(1)
Omega = Constant(math.huge)

EmptyString = Constant("")

-- Something that is different from everything else.
-- The name is a reference to the Alexandroff Compactification construction in Topology.
PointAtInfinity = Constant({})

function Table(...)
	return {...}
end

function IsEqualTo(a)
	return function(x)
		return x == a
	end
end

IsNil = IsEqualTo()


--[[
-- The functions that receive variadic lists will in general work correctly for empty lists.
-- With some of them, counting return values through select('#', ...) may not work, since they
-- may return a proper nil instead of returning nothing. Usual return checks work.
--]]


function Compose(f, g)
	assert( IsFunctional(f) )
	assert( IsFunctional(g) )
	return function(...)
		return f(g(...))
	end
end

---
-- Cartesian product of two functions of the same domain.
function CartesianProduct(f, g)
	return function(...)
		return f(...), g(...)
	end
end

function EvaluationMap(...)
	local L = {...}
	return function(f)
		f = f or Identity
		return f( unpack(L) )
	end
end

function IfThenElse(If, Then, Else)
	Then = Then or Nil
	Else = Else or Nil

	return function(...)
		if If(...) then
			return Then(...)
		else
			return Else(...)
		end
	end
end


function Head(x) -- (x, ...)
	return x
end

function Tail(x, ...)
	return ...
end


FirstOf = Head

function SecondOf(x, y)
	return y
end

function ThirdOf(x, y, z)
	return z
end

function LastOf(...)
	local n = select('#', ...)
	if n > 0 then
		return select(n, ...)
	end
end

function Nth(n)
	return function(...)
		return ( select(n, ...) )
	end
end

function NthOf(...)
	return Compose( EvaluationMap(...), Nth )
end

-- Normalizes indexes using the standard Lua convention for negative ones.
function NormalizeIndices(i, j, n)
	i = i or 1

	if n then
		j = j or n
		if i < 0 then
			i = n + i + 1
		end
		if j < 0 then
			j = n + j + 1
		end
		j = math.min(j, n)
	end

	return i, j
end
NormaliseIndices = NormalizeIndices
NormalizeIndexes = NormalizeIndices
NormaliseIndexes = NormalizeIndices

function ShiftLeft(x, ...)
	return ...
end

function ShiftRotateLeft(x, ...)
	local t = {...}
	table.insert(t, x)
	return unpack(t)
end

Append = ShiftRotateLeft

function RemoveLastOf(...)
	local t = {...}
	table.remove(t)
	return unpack(t)
end

function ShiftRotateRight(...)
	local t = {...}
	local last = table.remove(t)
	return last, unpack(t)
end

function ShiftRight(...)
	return nil, ...
end

function FlipFirstTwo(a, b, ...)
	return b, a, ...
end

-- i and j are the positions to be flipped.
function Flip(i, j, ...)
	local t = {...}
	i, j = NormalizeIndices(i, j, #t)
	t[i], t[j] = t[j], t[i]
	return unpack(t)
end

Transpose = Flip


local function BindHead(f, x)
	return function(...)
		return f(x, ...)
	end
end
_M.BindHead = BindHead

local function BindTail(f, ...)
	local Args = {...}
	return function(x)
		return f(x, unpack(Args))
	end
end
_M.BindTail = BindTail


BindFirst = BindHead

function BindSecond(f, y)
	return function(x, ...)
		return f(x, y, ...)
	end
end

function BindThird(f, z)
	return function(x, y, ...)
		return f(x, y, z, ...)
	end
end

function BindLast(f, x)
	return function(...)
		return f(Append(x, ...))
	end
end

function BindAll(f, ...)
	local Args = {...}
	return function()
		return f(unpack(Args))
	end
end


local function Curry(f, n)
	if n <= 0 then return f end
	return function(x)
		return Curry( BindHead(f, x), n - 1 )
	end
end
_M.Curry = Curry

function BinaryCurry(f)
	return function(x)
		return function(y)
			return f(x, y)
		end
	end
end

function Uncurry(f)
	return function(...)
		local g = f
		for _, x in ipairs{...} do
			g = g(x)
		end
		return g
	end
end


function Less(a, b)
	return a < b
end
IsLess = Less

GreaterThan = BinaryCurry(Less)
IsGreaterThan = GreaterThan

function Greater(a, b)
	return a > b
end
IsGreater = Greater

LessThan = BinaryCurry(Greater)
IsLessThan = LessThan

function LessOrEqual(a, b)
	return a <= b
end
IsLessOrEqual = LessOrEqual

GreaterOrEqualTo = BinaryCurry(LessOrEqual)
IsGreaterOrEqualTo = GreaterOrEqualTo

function GreaterOrEqual(a, b)
	return a >= b
end
IsGreaterOrEqual = GreaterOrEqual

LessOrEqualTo = BinaryCurry(GreaterOrEqual)
IsLessOrEqualTo = LessOrEqualTo


function Minimum(a, b)
	if a and b and b < a then
		return b
	else
		return a
	end
end

function Maximum(a, b)
	if a and b and b > a then
		return b
	else
		return a
	end
end


function Add(a, b)
	return (a or 0) + (b or 0)
end

function Multiply(a, b)
	return (a or 1) * (b or 1)
end

function NegateSign(a)
	return -a
end

UnaryMinus = NegateSign

function Invert(g)
	return 1/g
end


--[[
-- Table abstractions.
--]]

function Getter(t)
	return function(k)
		return t[k]
	end
end

function Setter(t)
	return function(k, v)
		if k ~= nil then
			t[k] = v
			return v
		end
	end
end

function StackPusher(s)
	return function(v)
		if v ~= nil then
			table.insert(s, v)
			return v
		end
	end
end

StackInserter = StackPusher

function StackPopper(s)
	return function()
		return table.remove(s)
	end
end

StackRemover = StackPopper
StackEraser = StackPopper

function StackGetter(s)
	return function()
		return s[#s]
	end
end

QueuePusher = StackPusher
QueueInserter = QueuePusher

function QueueRemover(q)
	return function()
		return table.remove(q, 1)
	end
end

QueuePopper = QueueRemover
QueueEraser = QueueRemover

function QueueGetter(q)
	return function()
		return q[1]
	end
end
