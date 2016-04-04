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

IsFunctional = assert( IsFunctional )
local IsFunctional = IsFunctional

function Identity(...)
	return ...
end
local Identity = Identity
Id = Identity
id = Identity

function SimpleIdentity(x)
	return x
end
local SimpleIdentity = SimpleIdentity
SimpleId = SimpleIdentity
simpleid = SimpleIdentity

function Constant(x)
	return function()
		return x
	end
end
local Constant = Constant
const = Constant

function ConstantList(...)
	local L = {...}
	return function()
		return unpack(L)
	end
end
local ConstantList = ConstantList
ConstantTuple = ConstantList
constlist = ConstantList
consttuple = ConstantList

-- We do not define it as 'Constant()' to have 0 return values in a variadic
-- context.
Nil = function() end
local Nil = Nil

-- A function that returns a unique value each time it runs. Each of these
-- values is a universally unique id for the lua state.
IONil = function() return {} end
local IONil = IONil

True, False = Constant(true), Constant(false)
local True, False = True, False

Zero = Constant(0)
One = Constant(1)
Omega = Constant(math.huge)

EmptyString = Constant("")

function Table(...)
	return {...}
end
pack = Table

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

function Call(f, ...)
	return f(...)
end
local Call = Call
call = Call

function Compose(f, g)
	assert( IsFunctional(f) )
	assert( IsFunctional(g) )
	return function(...)
		return f(g(...))
	end
end
local Compose = Compose
compose = Compose

-- Fixed point operator.
local function fix(f)
	return function(...)
		return f (fix(f)) (...)
	end
end
_M.fix = fix
_M.Fix = fix

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
fst = FirstOf

function SecondOf(x, y)
	return y
end
snd = SecondOf

function ThirdOf(x, y, z)
	return z
end
trd = ThirdOf

function LastOf(...)
	local n = select('#', ...)
	if n > 0 then
		return select(n, ...)
	end
end
lst = LastOf

function Nth(n)
	return function(...)
		return ( select(n, ...) )
	end
end
nth = Nth

function NthOf(...)
	return Compose( EvaluationMap(...), Nth )
end
nthof = NthOf

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
flip = FlipFirstTwo

-- i and j are the positions to be flipped.
function GeneralFlip(i, j, ...)
	local t = {...}
	i, j = NormalizeIndices(i, j, #t)
	t[i], t[j] = t[j], t[i]
	return unpack(t)
end

Transpose = GeneralFlip


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
bindfst = BindFirst
Bind = BindFirst
bind = BindFirst

function BindSecond(f, y)
	return function(x, ...)
		return f(x, y, ...)
	end
end
bindsnd = BindSecond

function BindThird(f, z)
	return function(x, y, ...)
		return f(x, y, z, ...)
	end
end
bindtrd = BindThird

function BindLast(f, x)
	return function(...)
		return f(Append(x, ...))
	end
end
bindlst = BindLast

function BindAll(f, ...)
	local Args = {...}
	return function()
		return f(unpack(Args))
	end
end
bindall = BindAll


local function FullCurry(f, n)
	if n <= 0 then return f end
	return function(x)
		return FullCurry( BindFirst(f, x), n - 1 )
	end
end
_M.FullCurry = FullCurry

function BinaryCurry(f)
	return function(x)
		return function(y)
			return f(x, y)
		end
	end
end
local BinaryCurry = BinaryCurry
binarycurry = BinaryCurry

function Curry(f)
	return function(x)
		return function(...)
			return f(x, ...)
		end
	end
end
local Curry = Curry
curry = Curry

function FullUncurry(f)
	return function(...)
		local g = f
		for _, x in ipairs{...} do
			g = g(x)
		end
		return g
	end
end

function BinaryUncurry(f)
	return function(x, y)
		return f(x)(y)
	end
end
binaryuncurry = BinaryUncurry

function Uncurry(f)
	return function(x, ...)
		return f(x)(...)
	end
end
local Uncurry = Uncurry
uncurry = uncurry


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

---

Function = {
	__concat = Compose,
	__mod = BindFirst,

	-- Not actually executed since Lua only checks for it when the value isn't
	-- a function. It is here only for reflection.
 	__call = Call,
}
debug.setmetatable(Nil, Function)

---

-- 
-- The parameter is a variadic type constructor for the node tests.
--
-- The boolean algebra objects are tables representing an expression tree.
-- They can be called, taking a function performing a fold over nodes.
-- The return value of such call is a boolean representing if the test passed
-- or not, followed by the folded value.
--
-- Each leaf should be callable, returning a status boolean followed by an
-- optional extra return value to be folded over.
--
function NewBooleanAlgebra(make_node, defaults)
	local setmetatable = setmetatable
	local ipairs = ipairs

	assert(defaults)

	local f = assert(defaults.fold)

	local meta = {}

	local function bless(p)
		return setmetatable(p, meta)
	end

	local function foldl(f, z)
		return function(array)
			for _, v in ipairs(array) do
				z = f(z, v)
			end
			return z
		end
	end

	local function NOT(p)
		return bless {kind = "NOT", p}
	end

	local function AND(...)
		return bless {kind = "AND", ...}
	end

	local function OR(...)
		return bless {kind = "OR", ...}
	end

	local function internal_evaluate(r, ...)
		local kind = r.kind
		if kind == nil then
			-- atomic (i.e. leaf)
			return r[1](...)
		elseif kind == "NOT" then
			-- Note the flipped 'z's.
			local status, z = internal_evaluate(r[1], ...)
			return not status, z
		elseif kind == "AND" then
			local z = nil
			for _, v in ipairs(r) do
				local status, inner_z = internal_evaluate(v, ...)
				z = f(z, inner_z)
				if not status then
					return false, z
				end
			end
			return true, z
		elseif kind == "OR" then
			local z = nil
			for _, v in ipairs(r) do
				local status, inner_z = internal_evaluate(v, ...)
				z = f(z, inner_z)
				if status then
					return true, z
				end
			end
			return false, z
		else
			print(tostring(kind))
			return error "Logic error."
		end
	end

	local function evaluate(r, ...)
		return internal_evaluate(r, ...)
	end
	meta.__call = evaluate

	meta.__unm = NOT
	meta.__add = OR
	meta.__mul = AND

	return function(...)
		return bless { (make_node(...)) }
	end
end
