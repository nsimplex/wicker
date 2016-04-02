--[[
-- Iterator tools.
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


local Lambda = pkgrequire "common"


NormalizeIndices = Lambda.NormalizeIndices
NormaliseIndices = NormalizeIndices
NormalizeIndexes = NormalizeIndices
NormaliseIndexes = NormalizeIndices

local Iterator, StateManagedIterator
	, IsIterator, IsStateManagedIterator = (function()
	local getmetatable = assert( getmetatable )
	local setmetatable = assert( setmetatable )

	local rawget, rawset = assert( rawget ), assert( rawset )

	local Iterator = {}
	Iterator.__index = Iterator

	local StateManagedIterator = {}
	StateManagedIterator.__index = StateManagedIterator

	local function IsIterator(x)
		local mt = getmetatable(x)
		return mt == Iterator or mt == StateManagedIterator
	end

	local function IsBasicIterator(x)
		local mt = getmetatable(x)
		return mt == Iterator
	end

	local function IsStateManagedIterator(x)
		local mt = getmetatable(x)
		return mt == StateManagedIterator
	end

	local function make_pristine(f, s, var)
		return {f, s, var}
	end

	local function make_stateful_pristine(g, var)
		return {g, nil, var, var}
	end

	function Iterator.new(f, s, var)
		if IsIterator(f) then
			return f
		else
			return setmetatable(make_pristine(f, s, var), Iterator)
		end
	end
	local basic_new = Iterator.new

	function Iterator:bless(f, s, var)
		return setmetatable(basic_new(f, s, var), getmetatable(self))
	end

	local function update_state(self, var, ...)
		if var == nil then
			self[4] = self[3]
			return
		else
			self[4] = var
			return var, ...
		end
	end

	function StateManagedIterator:__call(s)
		return update_state(self, self[1](self[2], self[4]))
	end

	local function actual_StateManagedIterator_new(f, s, var)
		if IsStateManagedIterator(f) then
			return f
		elseif IsBasicIterator(f) then
			f, s, var = f:unpack()
		end

		local self

		local function g()
			return update_state(self, f(s, self[4]))
		end

		self = setmetatable(make_stateful_pristine(g, var), StateManagedIterator)

		return self
	end

	local function finish_inheritance()
		for k, v in pairs(Iterator) do
			if not StateManagedIterator[v] then
				StateManagedIterator[k] = v
			end
		end
	end

	function StateManagedIterator.new(...)
		finish_inheritance()
		StateManagedIterator.new = actual_StateManagedIterator_new
		return StateManagedIterator.new(...)
	end

	function Iterator:unpack()
		return self[1], self[2], self[3]
	end

	function StateManagedIterator:unpack()
		return self[1]
	end

	function Iterator:__call(s, var)
		if var == nil then
			var = self[3]
		end
		if s == nil then
			s = self[2]
		end
		return self[1](s, var)
	end

	function StateManagedIterator:__call(s)
		return self[1]()
	end

	local simpleclass_meta = {
		__call = function(class, f, s, var)
			return class.new(f, s, var)
		end,
	}
	
	setmetatable(Iterator, simpleclass_meta)
	setmetatable(StateManagedIterator, simpleclass_meta)

	return Iterator, StateManagedIterator, IsIterator, IsStateManagedIterator
end)()

---

metatable.setmetacall(_M, Iterator)

---

GetStateManaged = StateManagedIterator.new
local GetStateManaged = GetStateManaged

local function embedUnaryMethod(k)
	local v = assert( _M[k] )
	Iterator[k] = function(self, x)
		return self:bless( v(x, self:unpack()) )
	end
end

---

function RawCompose(g, f, s, var)
	return Lambda.Compose(g, f), s, var
end
local RawCompose = RawCompose

embedUnaryMethod "RawCompose"

-- Do not compose with a function that may return nil if its first argument is not nil.
-- If doing so, the iterator can't be reused (because it will not reset).
function Compose(g, f, s, var)
	return RawCompose( g, GetStateManaged(f, s, var) )
end
local Compose = Compose

function Iterator:Compose(g)
	return StateManagedIterator(self):RawCompose(g)
end

for _, pre in ipairs {'Raw', ''} do
	local primitive = assert( _M[pre .. 'Compose'] )
	_M[pre .. 'ComposeTo'] = function(g)
		return Lambda.BindHead( primitive, g )
	end
end

function Filter(p, f, s, var)
	local function g(s, var)
		local rets = {f(s, var)}
		if rets[1] == nil then return end
		if p(unpack(rets)) then
			return unpack(rets)
		else
			-- Tail call
			return g(s, rets[1])
		end
	end

	return g, s, var
end
local Filter = Filter

embedUnaryMethod "Filter"

-- Like 'Filter', but for iterators returning up to 2 values only, thus
-- eliminating temporary tables.
function SimpleFilter(p, f, s, var)
	local function g(s, var)
		local k, v = f(s, var)
		if k == nil then return end
		if p(k, v) then
			return k, v
		else
			-- Tail call
			return g(s, rets[1])
		end
	end

	return g, s, var
end
local SimpleFilter = SimpleFilter

embedUnaryMethod "SimpleFilter"

-- Skips nil-mapped values.
function MapValues(map, f, s, var)
	local function g(s, var)
		local k, v = f(s, var)
		if k == nil then return end
		v = map(v, k)
		if v ~= nil then
			return k, v
		else
			-- Tail call
			return g(s, rets[1])
		end
	end

	return g, s, var
end
local MapValues = MapValues

embedUnaryMethod "MapValues"

-- Appends the second to the first.
-- Semantically, it's like concatenation.
function Append(f, s_f, var_f, g, s_g, var_g)
	local s = {s_f, s_g}

	-- Current state transition function.
	local current_trans_func

	local f_wrap
	local g_wrap

	local function f_control_shifter(s, var, ...)
		if var == nil then
			current_trans_func = g_wrap
			return g_wrap(s, var_g)
		else
			return var, ...
		end
	end

	local function g_control_shifter(var, ...)
		if var == nil then
			current_trans_func = f_wrap
			return
		else
			return var, ...
		end
	end

	f_wrap = function(s, var)
		return f_control_shifter( s, f(s[1], var) )
	end

	g_wrap = function(s, var)
		return g_control_shifter( g(s[2], var) )
	end

	current_trans_func = f_wrap

	return function(s, var)
		return current_trans_func(s, var)
	end, s, var_f
end

function AppendTo(f, s, var)
	return function(g, s_g, var_g)
		return Append(f, s, var, g, s_g, var_g)
	end
end

function AppendFromGenerators(F, G)
	return function(...)
		local f, s_f, var_f = F(...)
		local g, s_g, var_g = G(...)

		return Append(f, s_f, var_f, g, s_g, var_g)
	end
end

function NestedAppend(ftable, gtable)
	local f, s_f, var_f = unpack(ftable)
	local g, s_g, var_g = unpack(gtable)

	return Append(f, s_f, var_f, g, s_g, var_g)
end

-- Returns an empty iterator when called.
Empty = Lambda.Constant( Lambda.Nil )

-- Nil produces an empty iterator.
function Singleton(x)
	return function(s, var)
		if var == nil then
			return s
		end
	end, x
end

function SingletonList(...)
	return function(s, var)
		if var == nil then
			return unpack(s)
		end
	end, {...}
end

-- Closed range.
-- Uses Lua conventions for negative numbers if a max is given.
function PositiveIntegralRange(a, b, max)
	a, b = NormalizeIndexes(a, b, max)

	return function(b, var)
		var = var + 1
		if var <= b then
			return var
		end
	end, b, a - 1
end

function ArraySlice(A, i, j)
	return RawCompose( function(k) return k, A[k] end, PositiveIntegralRange(i, j, #A) )
end

-- Removes an iterator's dependency on the `var' control variable.
-- This makes it a forward only iterator.
RemoveFirstDependency = GetStateManaged

-- Prevents the iterator from returning the first element in its return list (the `var' control variable).
ShiftLeft = ComposeTo(Lambda.ShiftLeft)

-- Swaps the first two elements of the return list of an iterator.
-- If such a list has less than two elements, nothing is done.
function FlipFirstTwo(f, s, var)
	local ret0 = {f(s, var)}
	var = ret0[1]

	if var == nil then return Empty() end

	if #ret0 == 1 then
		local g, s_g, var_g = Singleton(var)
		return Append( g, s_g, var_g, f, s, var )
	end

	local g, s_g, var_g = SingletonList( Lambda.FlipFirstTwo(unpack(ret0)) )

	local h, s_h, var_h = Compose( Lambda.FlipFirstTwo, f, s, var )

	return Append( g, s_g, var_g, h, s_h, var_h )
end


-- The term fiber is used in its set theoretic sense.
-- Valid for iterators with a return value list of length 2.
function Fiber(f, s, var)
	local fiber = {}

	for x, y in f, s, var do
		if y ~= nil then
			if fiber[y] then
				table.insert( fiber[y], x )
			else
				fiber[y] = {x}
			end
		end
	end

	return fiber
end
Lambda.IteratorFiber = Fiber

ArrayFiber = Compose( Fiber, ArraySlice )
Lambda.ArrayFiber = ArrayFiber

function TableFiber(f, i, j)
	if i or j then
		return ArrayFiber(f, i, j)
	else
		return IteratorFiber( pairs(f) )
	end
end
Lambda.TableFiber = TableFiber
