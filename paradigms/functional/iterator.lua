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


-- Builds an independent updater of iterator state, represented
-- by a table with at least the field var (the control variable value).
function NewStateManager(state, var0)
	state.var = var0
	return function(var, ...)
		if var == nil then
			state.var = var0
			return
		else
			state.var = var
			return var, ...
		end
	end
end

function GetStateManaged(f, s, var)
	local state = {}
	return Lambda.Compose( NewStateManager(state, var), function(s)
		return f(s, state.var)
	end ), s, var
end

function RawCompose(g, f, s, var)
	return Lambda.Compose(g, f), s, var
end

-- Do not compose with a function that may return nil if its first argument is not nil.
-- If doing so, the iterator can't be reused (because it will not reset).
function Compose(g, f, s, var)
	return RawCompose( g, GetStateManaged(f, s, var) )
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
